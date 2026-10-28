# Проверка кода без Studio: типы Luau (luau-lsp) + сборка места (rojo).
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

Write-Host "== rojo build"
rojo build default.project.json --output test.rbxl
$buildCode = $LASTEXITCODE

if ($analyzeCode -ne 0 -or $buildCode -ne 0) {
	Write-Host "ПРОВЕРКА НЕ ПРОШЛА (analyze: $analyzeCode, build: $buildCode)"
	exit 1
}
Write-Host "Всё чисто: типы в порядке, место собирается."
