local ShopConfig = {}

ShopConfig.GamePasses = {
	x2Cash = {
		FrameName = "x2Cash",

		Id = 1947903714,
	},

	x2Customers = {
		FrameName = "x2Customers",

		Id = 1988012265,
	},

	VIP = {
		FrameName = "VIP",

		Id = 1947879804,
	},
}

ShopConfig.DeveloperProducts = {
	SmallFunding = {
		FrameName = "SmallFunding",

		Id = 3708663397,

		RewardType = "Cash",
		Amount = 5_000,
	},

	MediumFunding = {
		FrameName = "MediumFunding",

		Id = 3708663411,

		RewardType = "Cash",
		Amount = 25_000,
	},

	LargeFunding = {
		FrameName = "LargeFunding",

		Id = 3708663422,

		RewardType = "Cash",
		Amount = 100_000,
	},

	CustomerRush = {
		FrameName = "CustomerRush",

		Id = 3708663468,

		RewardType = "Boost",
		BoostName = "CustomerRush",
		Duration = 15 * 60,
	},

	ReputationBoost = {
		FrameName = "ReputationBoost",

		Id = 3708663484,

		RewardType = "Boost",
		BoostName = "ReputationBoost",
		Duration = 15 * 60,
	},

	x2CashBoost = {
		FrameName = "x2CashBoost",

		Id = 3708663498,

		RewardType = "Boost",
		BoostName = "CashBoost",
		Duration = 15 * 60,
	},

		GoldenCustomer = {
		FrameName = "Only9Robux",

		Id = 3713917157,

		RewardType = "GoldenCustomer",
	},
}


--==================================================
-- VIP GAMEPASS
--==================================================

-- 20% faster customer spawning.
ShopConfig.VIPCustomerMultiplier =
	1.20

-- 10% more cash from every completed sale.
ShopConfig.VIPCashMultiplier =
	1.10

-- 25% better rare-customer odds.
ShopConfig.VIPRareCustomerMultiplier =
	1.25

-- One additional stand for every business type.
ShopConfig.VIPPlacementBonus =
	1


--==================================================
-- X2 CASH GAMEPASS
--==================================================

ShopConfig.CashGamePassMultiplier =
	2


--==================================================
-- X2 CUSTOMERS GAMEPASS
--==================================================

-- Doubles the maximum number of customers
-- allowed on the player's plot.
--
-- Example:
-- Marketing limit 20 -> 40
-- Marketing limit 75 -> 150
ShopConfig.CustomerLimitGamePassMultiplier =
	2


--==================================================
-- TEMPORARY BOOSTS
--==================================================

ShopConfig.CashBoostMultiplier =
	2

ShopConfig.CustomerRushMultiplier =
	2

ShopConfig.ReputationBoostMultiplier =
	2


return ShopConfig