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


--==================================================
-- STARTER PACK
--==================================================

ShopConfig.StarterPack = {
	Id = 1998116571,

	-- The offer remains available for 30 minutes
	-- of actual in-game playtime after the tutorial.
	OfferDuration = 30 * 60,

	Cash = 5_000,

	CashBoostDuration = 10 * 60,

	GoldenCustomers = 1,
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

ShopConfig.VIPCustomerMultiplier =
	1.20

ShopConfig.VIPCashMultiplier =
	1.10

ShopConfig.VIPRareCustomerMultiplier =
	1.25

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