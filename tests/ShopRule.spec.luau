--!strict
-- Тесты магазина косметики (задача 7.4): цены, покупка, надевание, названия.

local ShopRule = require("../src/shared/Util/ShopRule")
local ShopConfig = require("../src/shared/Config/ShopConfig")
local TextConfig = require("../src/shared/Config/TextConfig")
local TestKit = require("./TestKit")

local test, equal = TestKit.test, TestKit.equal

print("ShopRule")

test("все вещи: категория существует, цена 5 000 – 2 000 000, есть название", function()
	local count, maxPrice = 0, 0
	for id, item in ShopConfig.Items do
		count += 1
		equal(ShopConfig.Categories[item.Category] ~= nil, true, id)
		equal(item.Price >= 5_000 and item.Price <= 2_000_000, true, id)
		equal(type(TextConfig.ShopItemNames[id]) == "string", true, id .. " без названия")
		maxPrice = math.max(maxPrice, item.Price)
	end
	equal(count >= 30, true)
	equal(maxPrice >= 1_000_000, true, "самые дорогие — миллионы")
	for _, category in ipairs(ShopConfig.CategoryOrder) do
		equal(type(TextConfig.ShopCategoryNames[category]) == "string", true, category)
	end
end)

test("12 баннеров, 5 декора, 4 скина, 4 следа, 4 ауры, 6 титулов", function()
	local counts: { [string]: number } = {}
	for _, item in ShopConfig.Items do
		counts[item.Category] = (counts[item.Category] or 0) + 1
	end
	equal(counts.Banner, 12)
	equal(counts.Decor, 5)
	equal(counts.PedestalSkin, 4)
	equal(counts.Trail, 4)
	equal(counts.Aura, 4)
	equal(counts.Title, 6)
end)

test("покупка: неизвестная вещь, уже куплена, не хватает Aura, можно", function()
	local item = ShopConfig.Items.BannerStar
	equal(ShopRule.CanBuy(nil, false, 1e9), "unknown")
	equal(ShopRule.CanBuy(item, true, 1e9), "owned", "второй раз не продаётся")
	equal(ShopRule.CanBuy(item, false, item.Price - 1), "poor")
	equal(ShopRule.CanBuy(item, false, item.Price), "ok")
end)

test("баннеры: до 3 сразу, четвёртый — нет места, повторно — снять", function()
	local list = {}
	local result
	for _, id in ipairs({ "A", "B", "C" }) do
		list, result = ShopRule.ToggleEquip(list, id, 3, true)
		equal(result, "equipped")
	end
	list, result = ShopRule.ToggleEquip(list, "D", 3, true)
	equal(result, "full")
	equal(#list, 3)
	list, result = ShopRule.ToggleEquip(list, "B", 3, true)
	equal(result, "unequipped")
	equal(table.find(list, "B"), nil)
end)

test("один слот: новая вещь заменяет прежнюю; не купленную не надеть", function()
	local list, result = ShopRule.ToggleEquip({}, "TrailMint", 1, true)
	equal(result, "equipped")
	list, result = ShopRule.ToggleEquip(list, "TrailFire", 1, true)
	equal(result, "replaced")
	equal(list[1], "TrailFire")
	equal(#list, 1)
	local _, notOwned = ShopRule.ToggleEquip(list, "TrailRainbow", 1, false)
	equal(notOwned, "notOwned")
end)

test("список через запятую туда и обратно", function()
	equal(ShopRule.Join({ "A", "B" }), "A,B")
	local ids = ShopRule.Split("A,B,C")
	equal(#ids, 3)
	equal(ids[3], "C")
	equal(#ShopRule.Split(""), 0)
end)

return nil
