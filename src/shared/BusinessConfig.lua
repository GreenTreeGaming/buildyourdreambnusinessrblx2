local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",

		FirstStandFree = true,

		-- Faster early expansion.
		AdditionalStandCost = 500,

		MaximumPlaced = 15,

		-- Faster early income.
		BaseSaleValue = 3,

		BaseServingCooldown = 5,

		-- Controls the physical appearance of the stand.
		StandLevels = {
			[1] = {
				TemplateName = "LemonadeStand",
				UpgradeCost = 40,

				CustomerAttraction = 1.00,
				CustomerRateMultiplier = 1.00,
			},

			[2] = {
				TemplateName = "LemonadeStand2",
				UpgradeCost = 200,

				CustomerAttraction = 1.15,
				CustomerRateMultiplier = 1.10,
			},

			[3] = {
				TemplateName = "LemonadeStand3",
				UpgradeCost = 750,

				CustomerAttraction = 1.35,
				CustomerRateMultiplier = 1.25,
			},

			[4] = {
				TemplateName = "LemonadeStand4",
				UpgradeCost = 3000,

				CustomerAttraction = 1.60,
				CustomerRateMultiplier = 1.45,
			},

			[5] = {
				TemplateName = "LemonadeStand5",
				UpgradeCost = nil,

				CustomerAttraction = 1.90,
				CustomerRateMultiplier = 1.70,
			},
		},

		Upgrades = {
			ServingSpeed = {
				DisplayName = "Faster Service",

				Description =
					"Reduce how long each customer waits at the counter.",

				ValueType = "Cooldown",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						Cooldown = 5,
					},

					{
						Level = 1,
						Cost = 25,
						Cooldown = 4.25,
					},

					{
						Level = 2,
						Cost = 65,
						Cooldown = 3.5,
					},

					{
						Level = 3,
						Cost = 150,
						Cooldown = 2.75,
					},

					{
						Level = 4,
						Cost = 325,
						Cooldown = 2,
					},

					{
						Level = 5,
						Cost = 700,
						Cooldown = 1.25,
					},
				},
			},

			QueueCapacity = {
				DisplayName = "Longer Queue",

				Description =
					"Allow more customers to wait at this stand.",

				ValueType = "QueueCapacity",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						Capacity = 1,
					},

					{
						Level = 1,
						Cost = 60,
						Capacity = 2,
					},

					{
						Level = 2,
						Cost = 175,
						Capacity = 3,
					},

					{
						Level = 3,
						Cost = 450,
						Capacity = 4,
					},
				},
			},

			SaleValue = {
				DisplayName = "Better Lemonade",

				Description =
					"Improve the recipe and earn more from every sale.",

				ValueType = "SaleValue",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						SaleValue = 3,
					},

					{
						Level = 1,
						Cost = 40,
						SaleValue = 4,
					},

					{
						Level = 2,
						Cost = 125,
						SaleValue = 6,
					},

					{
						Level = 3,
						Cost = 325,
						SaleValue = 9,
					},

					{
						Level = 4,
						Cost = 800,
						SaleValue = 13,
					},

					{
						Level = 5,
						Cost = 1900,
						SaleValue = 19,
					},
				},
			},
		},
	},

	HotdogStand = {
	DisplayName = "Hotdog Stand",

	-- Hotdog Stand is a second-tier business.
	-- The player must actually purchase their first one.
	FirstStandFree = false,

	AdditionalStandCost = 1250,

	MaximumPlaced = 12,

	BaseSaleValue = 7,
	BaseServingCooldown = 5.5,

	-- Add HotdogStand2, HotdogStand3, etc. here later.
	StandLevels = {
	[1] = {
		TemplateName = "HotdogStand",
		UpgradeCost = 250,

		CustomerAttraction = 1.00,
		CustomerRateMultiplier = 1.00,
	},

	[2] = {
		TemplateName = "HotdogStand2",
		UpgradeCost = 900,

		CustomerAttraction = 1.15,
		CustomerRateMultiplier = 1.10,
	},

	[3] = {
		TemplateName = "HotdogStand3",
		UpgradeCost = 3000,

		CustomerAttraction = 1.35,
		CustomerRateMultiplier = 1.25,
	},

	[4] = {
		TemplateName = "HotdogStand4",
		UpgradeCost = 9500,

		CustomerAttraction = 1.60,
		CustomerRateMultiplier = 1.45,
	},

	[5] = {
		TemplateName = "HotdogStand5",
		UpgradeCost = nil,

		CustomerAttraction = 1.90,
		CustomerRateMultiplier = 1.70,
	},
},

	Upgrades = {
		ServingSpeed = {
			DisplayName = "Faster Service",

			Description =
				"Serve hotdogs faster and keep the line moving.",

			ValueType = "Cooldown",

			Levels = {
				{
					Level = 0,
					Cost = 0,
					Cooldown = 5.5,
				},

				{
					Level = 1,
					Cost = 100,
					Cooldown = 4.75,
				},

				{
					Level = 2,
					Cost = 275,
					Cooldown = 4,
				},

				{
					Level = 3,
					Cost = 650,
					Cooldown = 3.25,
				},

				{
					Level = 4,
					Cost = 1500,
					Cooldown = 2.5,
				},

				{
					Level = 5,
					Cost = 3500,
					Cooldown = 1.75,
				},
			},
		},

		QueueCapacity = {
			DisplayName = "Longer Queue",

			Description =
				"Allow more customers to wait at this stand.",

			ValueType = "QueueCapacity",

			Levels = {
				{
					Level = 0,
					Cost = 0,
					Capacity = 1,
				},

				{
					Level = 1,
					Cost = 200,
					Capacity = 2,
				},

				{
					Level = 2,
					Cost = 650,
					Capacity = 3,
				},

				{
					Level = 3,
					Cost = 1800,
					Capacity = 4,
				},
			},
		},

		SaleValue = {
			DisplayName = "Better Hotdogs",

			Description =
				"Improve your hotdogs and earn more from every sale.",

			ValueType = "SaleValue",

			Levels = {
				{
					Level = 0,
					Cost = 0,
					SaleValue = 7,
				},

				{
					Level = 1,
					Cost = 150,
					SaleValue = 9,
				},

				{
					Level = 2,
					Cost = 450,
					SaleValue = 12,
				},

				{
					Level = 3,
					Cost = 1200,
					SaleValue = 16,
				},

				{
					Level = 4,
					Cost = 3000,
					SaleValue = 22,
				},

				{
					Level = 5,
					Cost = 7000,
					SaleValue = 30,
				},
			},
		},
	},
},
}

return BusinessConfig