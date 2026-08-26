local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",
		DisplayOrder = 1,

		RevealDescription =
			"Start small, serve refreshing lemonade, and build your business empire from the ground up.",

		UnlockRequirements = nil,

		FirstStandFree = true,

		-- Additional lemonade stands should be an investment,
		-- but still accessible during the early game.
		AdditionalStandCost = 750,

		MaximumPlaced = 15,

		BaseSaleValue = 8,
		BaseServingCooldown = 5,

		StandLevels = {
			[1] = {
				TemplateName = "LemonadeStand",
				UpgradeCost = 150,

				CustomerAttraction = 1.00,
				CustomerRateMultiplier = 1.00,

				-- Appearance levels now also improve income.
				SaleValueMultiplier = 1.00,

				-- Makes valuable customers increasingly prefer
				-- upgraded stands.
				PremiumCustomerAttraction = 1.00,
			},

			[2] = {
				TemplateName = "LemonadeStand2",
				UpgradeCost = 800,

				CustomerAttraction = 1.15,
				CustomerRateMultiplier = 1.10,

				SaleValueMultiplier = 1.20,
				PremiumCustomerAttraction = 1.10,
			},

			[3] = {
				TemplateName = "LemonadeStand3",
				UpgradeCost = 3500,

				CustomerAttraction = 1.35,
				CustomerRateMultiplier = 1.25,

				SaleValueMultiplier = 1.50,
				PremiumCustomerAttraction = 1.25,
			},

			[4] = {
				TemplateName = "LemonadeStand4",
				UpgradeCost = 12000,

				CustomerAttraction = 1.60,
				CustomerRateMultiplier = 1.45,

				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.45,
			},

			[5] = {
				TemplateName = "LemonadeStand5",
				UpgradeCost = nil,

				CustomerAttraction = 1.90,
				CustomerRateMultiplier = 1.70,

				SaleValueMultiplier = 2.40,
				PremiumCustomerAttraction = 1.75,
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
						Cost = 75,
						Cooldown = 4.4,
					},

					{
						Level = 2,
						Cost = 250,
						Cooldown = 3.8,
					},

					{
						Level = 3,
						Cost = 700,
						Cooldown = 3.2,
					},

					{
						Level = 4,
						Cost = 1800,
						Cooldown = 2.7,
					},

					{
						Level = 5,
						Cost = 4500,
						Cooldown = 2.2,
					},

					{
						Level = 6,
						Cost = 11000,
						Cooldown = 1.8,
					},

					{
						Level = 7,
						Cost = 26000,
						Cooldown = 1.5,
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
						Cost = 125,
						Capacity = 2,
					},

					{
						Level = 2,
						Cost = 550,
						Capacity = 3,
					},

					{
						Level = 3,
						Cost = 2200,
						Capacity = 4,
					},

					{
						Level = 4,
						Cost = 8500,
						Capacity = 5,
					},
				},
			},

			SaleValue = {
				DisplayName = "Better Lemonade",

				Description =
					"Improve your lemonade recipe and dramatically increase the value of every sale.",

				ValueType = "SaleValue",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						SaleValue = 8,
					},

					{
						Level = 1,
						Cost = 100,
						SaleValue = 12,
					},

					{
						Level = 2,
						Cost = 350,
						SaleValue = 18,
					},

					{
						Level = 3,
						Cost = 1000,
						SaleValue = 28,
					},

					{
						Level = 4,
						Cost = 3000,
						SaleValue = 42,
					},

					{
						Level = 5,
						Cost = 8000,
						SaleValue = 65,
					},

					{
						Level = 6,
						Cost = 20000,
						SaleValue = 100,
					},

					{
						Level = 7,
						Cost = 50000,
						SaleValue = 155,
					},

					{
						Level = 8,
						Cost = 125000,
						SaleValue = 240,
					},

					{
						Level = 9,
						Cost = 300000,
						SaleValue = 360,
					},

					{
						Level = 10,
						Cost = 700000,
						SaleValue = 500,
					},
				},
			},
		},
	},

	HotdogStand = {
		DisplayName = "Hotdog Stand",
		DisplayOrder = 2,

		RevealDescription =
			"Serve hungry customers faster and earn bigger profits with your new hotdog business.",

		UnlockRequirements = {
			ReputationLevel = 3,

			LifetimeEarnings = 500,

			BusinessLevel = {
				BusinessType = "LemonadeStand",
				Level = 2,
			},
		},

		FirstStandFree = false,

		-- Hotdogs now require a meaningful investment,
		-- because their earning ceiling is much higher.
		AdditionalStandCost = 3000,

		MaximumPlaced = 12,

		BaseSaleValue = 30,
		BaseServingCooldown = 5,

		StandLevels = {
			[1] = {
				TemplateName = "HotdogStand",
				UpgradeCost = 800,

				CustomerAttraction = 1.00,
				CustomerRateMultiplier = 1.00,

				SaleValueMultiplier = 1.00,
				PremiumCustomerAttraction = 1.00,
			},

			[2] = {
				TemplateName = "HotdogStand2",
				UpgradeCost = 3500,

				CustomerAttraction = 1.15,
				CustomerRateMultiplier = 1.10,

				SaleValueMultiplier = 1.20,
				PremiumCustomerAttraction = 1.10,
			},

			[3] = {
				TemplateName = "HotdogStand3",
				UpgradeCost = 14000,

				CustomerAttraction = 1.35,
				CustomerRateMultiplier = 1.25,

				SaleValueMultiplier = 1.50,
				PremiumCustomerAttraction = 1.25,
			},

			[4] = {
				TemplateName = "HotdogStand4",
				UpgradeCost = 50000,

				CustomerAttraction = 1.60,
				CustomerRateMultiplier = 1.45,

				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.45,
			},

			[5] = {
				TemplateName = "HotdogStand5",
				UpgradeCost = nil,

				CustomerAttraction = 1.90,
				CustomerRateMultiplier = 1.70,

				SaleValueMultiplier = 2.40,
				PremiumCustomerAttraction = 1.75,
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
						Cooldown = 5,
					},

					{
						Level = 1,
						Cost = 300,
						Cooldown = 4.4,
					},

					{
						Level = 2,
						Cost = 900,
						Cooldown = 3.8,
					},

					{
						Level = 3,
						Cost = 2600,
						Cooldown = 3.2,
					},

					{
						Level = 4,
						Cost = 7000,
						Cooldown = 2.7,
					},

					{
						Level = 5,
						Cost = 18000,
						Cooldown = 2.2,
					},

					{
						Level = 6,
						Cost = 45000,
						Cooldown = 1.8,
					},

					{
						Level = 7,
						Cost = 110000,
						Cooldown = 1.5,
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
						Cost = 500,
						Capacity = 2,
					},

					{
						Level = 2,
						Cost = 1800,
						Capacity = 3,
					},

					{
						Level = 3,
						Cost = 6500,
						Capacity = 4,
					},

					{
						Level = 4,
						Cost = 22000,
						Capacity = 5,
					},
				},
			},

			SaleValue = {
				DisplayName = "Better Hotdogs",

				Description =
					"Improve your hotdogs and dramatically increase the value of every sale.",

				ValueType = "SaleValue",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						SaleValue = 30,
					},

					{
						Level = 1,
						Cost = 400,
						SaleValue = 45,
					},

					{
						Level = 2,
						Cost = 1300,
						SaleValue = 68,
					},

					{
						Level = 3,
						Cost = 4000,
						SaleValue = 105,
					},

					{
						Level = 4,
						Cost = 12000,
						SaleValue = 160,
					},

					{
						Level = 5,
						Cost = 32000,
						SaleValue = 245,
					},

					{
						Level = 6,
						Cost = 80000,
						SaleValue = 375,
					},

					{
						Level = 7,
						Cost = 200000,
						SaleValue = 575,
					},

					{
						Level = 8,
						Cost = 500000,
						SaleValue = 875,
					},

					{
						Level = 9,
						Cost = 1200000,
						SaleValue = 1300,
					},

					{
						Level = 10,
						Cost = 2800000,
						SaleValue = 1800,
					},
				},
			},
		},
	},

	HaircutStand = {
		DisplayName = "Haircut Stand",
		DisplayOrder = 3,

		RevealDescription =
			"Cut hair, serve higher-paying customers, and grow your business into a professional barbershop.",

		UnlockRequirements = {
			ReputationLevel = 7,

			LifetimeEarnings = 10000,

			BusinessLevel = {
				BusinessType = "HotdogStand",
				Level = 3,
			},
		},

		FirstStandFree = false,

		AdditionalStandCost = 18000,

		MaximumPlaced = 10,

		BaseSaleValue = 120,
		BaseServingCooldown = 6,

		StandLevels = {
			[1] = {
				TemplateName = "HaircutStand",
				UpgradeCost = 5000,

				CustomerAttraction = 1.00,
				CustomerRateMultiplier = 1.00,

				SaleValueMultiplier = 1.00,
				PremiumCustomerAttraction = 1.00,
			},

			[2] = {
				TemplateName = "HaircutStand2",
				UpgradeCost = 20000,

				CustomerAttraction = 1.15,
				CustomerRateMultiplier = 1.10,

				SaleValueMultiplier = 1.20,
				PremiumCustomerAttraction = 1.10,
			},

			[3] = {
				TemplateName = "HaircutStand3",
				UpgradeCost = 75000,

				CustomerAttraction = 1.35,
				CustomerRateMultiplier = 1.25,

				SaleValueMultiplier = 1.50,
				PremiumCustomerAttraction = 1.25,
			},

			[4] = {
				TemplateName = "HaircutStand4",
				UpgradeCost = 275000,

				CustomerAttraction = 1.60,
				CustomerRateMultiplier = 1.45,

				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.45,
			},

			[5] = {
				TemplateName = "HaircutStand5",
				UpgradeCost = nil,

				CustomerAttraction = 1.90,
				CustomerRateMultiplier = 1.70,

				SaleValueMultiplier = 2.40,
				PremiumCustomerAttraction = 1.75,
			},
		},

		Upgrades = {
			ServingSpeed = {
				DisplayName = "Faster Haircuts",

				Description =
					"Improve your tools and technique to finish haircuts faster.",

				ValueType = "Cooldown",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						Cooldown = 6,
					},

					{
						Level = 1,
						Cost = 1500,
						Cooldown = 5.3,
					},

					{
						Level = 2,
						Cost = 5000,
						Cooldown = 4.6,
					},

					{
						Level = 3,
						Cost = 15000,
						Cooldown = 3.9,
					},

					{
						Level = 4,
						Cost = 45000,
						Cooldown = 3.3,
					},

					{
						Level = 5,
						Cost = 125000,
						Cooldown = 2.7,
					},

					{
						Level = 6,
						Cost = 325000,
						Cooldown = 2.2,
					},

					{
						Level = 7,
						Cost = 800000,
						Cooldown = 1.8,
					},
				},
			},

			QueueCapacity = {
				DisplayName = "Waiting Area",

				Description =
					"Add more seating so additional customers can wait for a haircut.",

				ValueType = "QueueCapacity",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						Capacity = 1,
					},

					{
						Level = 1,
						Cost = 2500,
						Capacity = 2,
					},

					{
						Level = 2,
						Cost = 9000,
						Capacity = 3,
					},

					{
						Level = 3,
						Cost = 32000,
						Capacity = 4,
					},

					{
						Level = 4,
						Cost = 110000,
						Capacity = 5,
					},
				},
			},

			SaleValue = {
				DisplayName = "Better Haircuts",

				Description =
					"Improve your service quality and dramatically increase what each haircut earns.",

				ValueType = "SaleValue",

				Levels = {
					{
						Level = 0,
						Cost = 0,
						SaleValue = 120,
					},

					{
						Level = 1,
						Cost = 2000,
						SaleValue = 180,
					},

					{
						Level = 2,
						Cost = 6500,
						SaleValue = 275,
					},

					{
						Level = 3,
						Cost = 20000,
						SaleValue = 420,
					},

					{
						Level = 4,
						Cost = 60000,
						SaleValue = 650,
					},

					{
						Level = 5,
						Cost = 160000,
						SaleValue = 1000,
					},

					{
						Level = 6,
						Cost = 400000,
						SaleValue = 1550,
					},

					{
						Level = 7,
						Cost = 1000000,
						SaleValue = 2400,
					},

					{
						Level = 8,
						Cost = 2500000,
						SaleValue = 3700,
					},

					{
						Level = 9,
						Cost = 6000000,
						SaleValue = 5600,
					},

					{
						Level = 10,
						Cost = 14000000,
						SaleValue = 8000,
					},
				},
			},
		},
	},
}

return BusinessConfig