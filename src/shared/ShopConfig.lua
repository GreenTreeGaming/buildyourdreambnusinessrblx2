local ShopConfig = {}

ShopConfig.GamePasses = {
	x2Cash = {
		FrameName = "x2Cash",

		Id = 1947903714,
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

-- VIP should be useful without becoming mandatory.
ShopConfig.VIPCustomerMultiplier = 1.15

-- Permanent 2x Cash stays genuinely 2x because that is
-- what the gamepass promises.
ShopConfig.CashGamePassMultiplier = 2

-- Temporary boosts.
ShopConfig.CashBoostMultiplier = 2
ShopConfig.CustomerRushMultiplier = 2
ShopConfig.ReputationBoostMultiplier = 2

return ShopConfig