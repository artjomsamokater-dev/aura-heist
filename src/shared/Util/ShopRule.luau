--!strict
-- ShopRule: правила магазина косметики (задача 7.4). Чистые функции — их проверяют тесты.

local ShopRule = {}

export type BuyResult = "ok" | "unknown" | "owned" | "poor"

-- Можно ли купить: вещь есть в ShopConfig, ещё не куплена, Aura хватает
function ShopRule.CanBuy(item: { Price: number }?, owned: boolean, balance: number): BuyResult
	if item == nil then
		return "unknown"
	end
	if owned then
		return "owned"
	end
	if balance < item.Price then
		return "poor"
	end
	return "ok"
end

export type EquipResult = "equipped" | "unequipped" | "replaced" | "full" | "notOwned"

-- Надеть/снять вещь в категории (переключатель). equipped — что надето сейчас (список Id), max — сколько можно.
-- Уже надета — снимаем. max = 1 — новая заменяет прежнюю. max > 1 — добавляем, пока есть место, иначе "full".
-- Вернёт новый список (старый не меняется) и что произошло
function ShopRule.ToggleEquip(equipped: { string }, itemId: string, max: number, owned: boolean): ({ string }, EquipResult)
	local list = table.clone(equipped)
	local index = table.find(list, itemId)
	if index then
		table.remove(list, index)
		return list, "unequipped"
	end
	if not owned then
		return list, "notOwned"
	end
	if max <= 1 then
		return { itemId }, if #list > 0 then "replaced" else "equipped"
	end
	if #list >= max then
		return list, "full"
	end
	table.insert(list, itemId)
	return list, "equipped"
end

-- Список Id через запятую (атрибуты игрока для клиента) и обратно
function ShopRule.Join(ids: { string }): string
	return table.concat(ids, ",")
end

function ShopRule.Split(text: string): { string }
	local ids = {}
	for id in string.gmatch(text, "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end

return ShopRule
