local StockPurchaseConfig = {

	LemonadeStand = {
		UnitPrice = 4,

		Buy1 = 25,
		Buy2 = 75,
	},

	HotdogStand = {
		UnitPrice = 16,

		Buy1 = 25,
		Buy2 = 75,
	},

	HaircutStand = {
		UnitPrice = 90,

		Buy1 = 20,
		Buy2 = 60,
	},

	CoffeeStand = {
		UnitPrice = 350,

		Buy1 = 20,
		Buy2 = 60,
	},
}


--==================================================
-- STOCK PRICE SCALING
--==================================================

local LEVEL_PRICE_MULTIPLIERS = {
	[1] = 1.00,
	[2] = 1.35,
	[3] = 1.90,
	[4] = 2.70,
	[5] = 3.80,
}


function StockPurchaseConfig.GetUnitPrice(
	businessType: string,
	level: number
): number

	local definition =
		StockPurchaseConfig[businessType]

	if type(definition) ~= "table" then
		return 0
	end

	local basePrice =
		definition.UnitPrice

	if typeof(basePrice) ~= "number"
		or basePrice < 0 then

		return 0
	end

	if typeof(level) ~= "number"
		or level ~= level
		or level == math.huge
		or level == -math.huge then

		level = 1
	end

	level = math.clamp(
		math.floor(level),
		1,
		5
	)

	local multiplier =
		LEVEL_PRICE_MULTIPLIERS[level]

	return math.max(
		1,
		math.floor(
			basePrice * multiplier + 0.5
		)
	)
end


function StockPurchaseConfig.GetHighestStandLevel(
	stands: {Model}
): number

	local highestLevel = 1

	for _, stand in stands do

		local level =
			stand:GetAttribute("Level")

		if typeof(level) == "number"
			and level == level
			and level ~= math.huge
			and level ~= -math.huge then

			highestLevel = math.max(
				highestLevel,
				math.floor(level)
			)
		end
	end

	return math.clamp(
		highestLevel,
		1,
		5
	)
end


return StockPurchaseConfig