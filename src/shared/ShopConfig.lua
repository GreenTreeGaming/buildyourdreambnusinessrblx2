local ShopConfig = {}

ShopConfig.GamePasses = {
	x2Cash = {
		FrameName = "x2Cash",

		-- REPLACE WITH YOUR ACTUAL GAMEPASS ID
		Id = 1947903714,
	},

	VIP = {
		FrameName = "VIP",

		-- REPLACE WITH YOUR ACTUAL GAMEPASS ID
		Id = 1947879804,
	},
}

ShopConfig.DeveloperProducts = {
	SmallFunding = {
		FrameName = "SmallFunding",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663397,

		RewardType = "Cash",
		Amount = 5_000,
	},

	MediumFunding = {
		FrameName = "MediumFunding",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663411,

		RewardType = "Cash",
		Amount = 25_000,
	},

	LargeFunding = {
		FrameName = "LargeFunding",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663422,

		RewardType = "Cash",
		Amount = 100_000,
	},

	CustomerRush = {
		FrameName = "CustomerRush",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663468,

		RewardType = "Boost",
		BoostName = "CustomerRush",
		Duration = 15 * 60,
	},

	ReputationBoost = {
		FrameName = "ReputationBoost",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663484,

		RewardType = "Boost",
		BoostName = "ReputationBoost",
		Duration = 15 * 60,
	},

	x2CashBoost = {
		FrameName = "x2CashBoost",

		-- REPLACE WITH YOUR ACTUAL DEV PRODUCT ID
		Id = 3708663498,

		RewardType = "Boost",
		BoostName = "CashBoost",
		Duration = 15 * 60,
	},
}

-- VIP is intentionally not another huge cash multiplier.
-- It gives a permanent customer-attraction benefit,
-- and exposes HasVIP for future VIP cosmetics/features.
ShopConfig.VIPCustomerMultiplier = 1.15

ShopConfig.CashGamePassMultiplier = 2
ShopConfig.CashBoostMultiplier = 2
ShopConfig.CustomerRushMultiplier = 2
ShopConfig.ReputationBoostMultiplier = 2

return ShopConfig