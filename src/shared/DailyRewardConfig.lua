local DailyRewardConfig = {}

DailyRewardConfig.Images = {
	Cash = "rbxassetid://78301368966596",
	CashBoost = "rbxassetid://78301368966596",
	CustomerRush = "rbxassetid://77595754464398",
}

DailyRewardConfig.Rewards = {
	[1] = {
		Name = "DAY 1",
		Cash = 5_000,
	},

	[2] = {
		Name = "DAY 2",
		Cash = 15_000,
	},

	[3] = {
		Name = "DAY 3",
		Cash = 35_000,

		Boost = {
			Name = "CashBoost",
			DisplayName = "2X CASH",
			Duration = 10 * 60,
		},
	},

	[4] = {
		Name = "DAY 4",
		Cash = 100_000,
	},

	[5] = {
		Name = "DAY 5",
		Cash = 250_000,

		Boost = {
			Name = "CustomerRush",
			DisplayName = "CUSTOMER RUSH",
			Duration = 15 * 60,
		},
	},

	[6] = {
		Name = "DAY 6",
		Cash = 500_000,
	},

	[7] = {
		Name = "DAY 7",
		Cash = 1_500_000,

		Boost = {
			Name = "CashBoost",
			DisplayName = "2X CASH",
			Duration = 30 * 60,
		},
	},
}

return DailyRewardConfig