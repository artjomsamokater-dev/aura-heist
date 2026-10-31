# Проверка кода без Studio: типы Luau (luau-lsp), кодировка, тесты чистой логики (luau), сборка места (rojo).
# Запуск из корня проекта:  powershell -ExecutionPolicy Bypass -File scripts/check.ps1

$ErrorActionPreference = "Stop"
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Типы Roblox для luau-lsp: скачиваем один раз в .luau-lsp/ (папка в .gitignore)
$defsDir = Join-Path $root ".luau-lsp"
$defs = Join-Path $defsDir "globalTypes.d.luau"
if (-not (Test-Path $defs)) {
	New-Item -ItemType Directory -Force $defsDir | Out-Null
	$url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"
	Write-Host "Скачиваю типы Roblox: $url"
	Invoke-WebRequest -Uri $url -OutFile $defs -UseBasicParsing
}

Write-Host "== rojo sourcemap"
rojo sourcemap default.project.json --output sourcemap.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== luau-lsp analyze"
# Чужие библиотеки в src/server/Packages (ProfileStore) не проверяем: их код не правим
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json "--definitions=@roblox=$defs" "--ignore=**/Packages/**" src
$analyzeCode = $LASTEXITCODE

Write-Host "== кодировка файлов"
# Luau-файлы — UTF-8 без BOM; «Ð»/«Ñ» в тексте значит, что русский текст испортила неверная кодировка
$encodingCode = 0
foreach ($file in Get-ChildItem -Path src, tests -Recurse -Filter *.luau) {
	$bytes = [IO.File]::ReadAllBytes($file.FullName)
	$text = [Text.Encoding]::UTF8.GetString($bytes)
	if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
		Write-Host "  BOM в начале файла: $($file.FullName)"
		$encodingCode = 1
	}
	if ($text -match "[ÐÑ][\u0080-¿‘-›]") {
		Write-Host "  испорченная кодировка (кракозябры): $($file.FullName)"
		$encodingCode = 1
	}
	# Эмодзи на разных устройствах выглядят по-разному — в игре их нет (иконки рисуем, client/Ui/Icons)
	if ($text -match "[\uD83C-\uD83E][\uDC00-\uDFFF]|[☀-➿]") {
		Write-Host "  эмодзи в файле (замени на иконку или простой символ): $($file.FullName)"
		$encodingCode = 1
	}
}

Write-Host "== тесты (luau tests/run.luau)"
luau tests/run.luau
$testsCode = $LASTEXITCODE

Write-Host "== rojo build"
rojo build default.project.json --output test.rbxl
$buildCode = $LASTEXITCODE

if ($analyzeCode -ne 0 -or $encodingCode -ne 0 -or $testsCode -ne 0 -or $buildCode -ne 0) {
	Write-Host "ПРОВЕРКА НЕ ПРОШЛА (analyze: $analyzeCode, encoding: $encodingCode, tests: $testsCode, build: $buildCode)"
	exit 1
}
Write-Host "Всё чисто: типы в порядке, кодировка в порядке, тесты прошли, место собирается."
