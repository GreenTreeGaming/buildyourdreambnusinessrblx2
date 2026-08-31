local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",
		DisplayOrder = 1,

		RevealDescription =
			"Start small, serve refreshing lemonade, and build your business empire from the ground up.",

		UnlockRequirements = nil,

		FirstStandFree = true,

		AdditionalStandCost = 750,

		MaximumPlaced = 15,

		-- Base income is still modest so the beginning
		-- of the game does not become instant money.
		BaseSaleValue = 10,

		BaseServingCooldown = 5,

		StandLevels = {
	[1] = {
		TemplateName = "LemonadeStand",
		UpgradeCost = 150,

		-- Lemonade is a high-volume business.
		CustomerAttraction = 1.00,
		CustomerRateMultiplier = 1.00,

		SaleValueMultiplier = 1.00,

		-- Wealthy customers are only slightly more
		-- interested in upgraded Lemonade Stands.
		PremiumCustomerAttraction = 1.00,
	},

	[2] = {
		TemplateName = "LemonadeStand2",
		UpgradeCost = 800,

		CustomerAttraction = 1.10,
		CustomerRateMultiplier = 1.15,

		SaleValueMultiplier = 1.35,

		PremiumCustomerAttraction = 1.03,
	},

	[3] = {
		TemplateName = "LemonadeStand3",
		UpgradeCost = 3500,

		CustomerAttraction = 1.20,
		CustomerRateMultiplier = 1.35,

		SaleValueMultiplier = 1.90,

		PremiumCustomerAttraction = 1.07,
	},

	[4] = {
		TemplateName = "LemonadeStand4",
		UpgradeCost = 12000,

		CustomerAttraction = 1.35,
		CustomerRateMultiplier = 1.60,

		SaleValueMultiplier = 2.80,

		PremiumCustomerAttraction = 1.12,
	},

	[5] = {
		TemplateName = "LemonadeStand5",
		UpgradeCost = nil,

		CustomerAttraction = 1.50,
		CustomerRateMultiplier = 1.90,

		SaleValueMultiplier = 4.20,

		PremiumCustomerAttraction = 1.20,
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
						SaleValue = 10,
					},

					{
						Level = 1,
						Cost = 100,
						SaleValue = 16,
					},

					{
						Level = 2,
						Cost = 350,
						SaleValue = 26,
					},

					{
						Level = 3,
						Cost = 1000,
						SaleValue = 45,
					},

					{
						Level = 4,
						Cost = 3000,
						SaleValue = 80,
					},

					{
						Level = 5,
						Cost = 8000,
						SaleValue = 140,
					},

					{
						Level = 6,
						Cost = 20000,
						SaleValue = 240,
					},

					{
						Level = 7,
						Cost = 50000,
						SaleValue = 400,
					},

					{
						Level = 8,
						Cost = 125000,
						SaleValue = 650,
					},

					{
						Level = 9,
						Cost = 300000,
						SaleValue = 1050,
					},

					{
						Level = 10,
						Cost = 700000,
						SaleValue = 1700,
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

		AdditionalStandCost = 3000,

		MaximumPlaced = 12,

		BaseSaleValue = 35,

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

		SaleValueMultiplier = 1.35,

		PremiumCustomerAttraction = 1.10,
	},

	[3] = {
		TemplateName = "HotdogStand3",
		UpgradeCost = 14000,

		CustomerAttraction = 1.35,
		CustomerRateMultiplier = 1.25,

		SaleValueMultiplier = 1.90,

		PremiumCustomerAttraction = 1.25,
	},

	[4] = {
		TemplateName = "HotdogStand4",
		UpgradeCost = 50000,

		CustomerAttraction = 1.60,
		CustomerRateMultiplier = 1.45,

		SaleValueMultiplier = 2.80,

		PremiumCustomerAttraction = 1.50,
	},

	[5] = {
		TemplateName = "HotdogStand5",
		UpgradeCost = nil,

		CustomerAttraction = 1.90,
		CustomerRateMultiplier = 1.70,

		SaleValueMultiplier = 4.20,

		PremiumCustomerAttraction = 1.80,
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
						SaleValue = 35,
					},

					{
						Level = 1,
						Cost = 400,
						SaleValue = 60,
					},

					{
						Level = 2,
						Cost = 1300,
						SaleValue = 105,
					},

					{
						Level = 3,
						Cost = 4000,
						SaleValue = 180,
					},

					{
						Level = 4,
						Cost = 12000,
						SaleValue = 310,
					},

					{
						Level = 5,
						Cost = 32000,
						SaleValue = 525,
					},

					{
						Level = 6,
						Cost = 80000,
						SaleValue = 900,
					},

					{
						Level = 7,
						Cost = 200000,
						SaleValue = 1500,
					},

					{
						Level = 8,
						Cost = 500000,
						SaleValue = 2500,
					},

					{
						Level = 9,
						Cost = 1200000,
						SaleValue = 4000,
					},

					{
						Level = 10,
						Cost = 2800000,
						SaleValue = 6500,
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

		BaseSaleValue = 140,

		BaseServingCooldown = 6,

		StandLevels = {
	[1] = {
		TemplateName = "HaircutStand",
		UpgradeCost = 5000,

		-- Haircuts focus on valuable customers rather
		-- than generating massive customer volume.
		CustomerAttraction = 1.05,
		CustomerRateMultiplier = 1.00,

		SaleValueMultiplier = 1.00,

		PremiumCustomerAttraction = 1.10,
	},

	[2] = {
		TemplateName = "HaircutStand2",
		UpgradeCost = 20000,

		CustomerAttraction = 1.20,
		CustomerRateMultiplier = 1.05,

		SaleValueMultiplier = 1.35,

		PremiumCustomerAttraction = 1.35,
	},

	[3] = {
		TemplateName = "HaircutStand3",
		UpgradeCost = 75000,

		CustomerAttraction = 1.45,
		CustomerRateMultiplier = 1.10,

		SaleValueMultiplier = 1.90,

		PremiumCustomerAttraction = 1.70,
	},

	[4] = {
		TemplateName = "HaircutStand4",
		UpgradeCost = 275000,

		CustomerAttraction = 1.80,
		CustomerRateMultiplier = 1.18,

		SaleValueMultiplier = 2.80,

		PremiumCustomerAttraction = 2.20,
	},

	[5] = {
		TemplateName = "HaircutStand5",
		UpgradeCost = nil,

		CustomerAttraction = 2.30,
		CustomerRateMultiplier = 1.25,

		SaleValueMultiplier = 4.20,

		-- Rich customers should noticeably prefer a
		-- high-end barbershop.
		PremiumCustomerAttraction = 3.00,
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
						SaleValue = 140,
					},

					{
						Level = 1,
						Cost = 2000,
						SaleValue = 240,
					},

					{
						Level = 2,
						Cost = 6500,
						SaleValue = 410,
					},

					{
						Level = 3,
						Cost = 20000,
						SaleValue = 700,
					},

					{
						Level = 4,
						Cost = 60000,
						SaleValue = 1200,
					},

					{
						Level = 5,
						Cost = 160000,
						SaleValue = 2050,
					},

					{
						Level = 6,
						Cost = 400000,
						SaleValue = 3500,
					},

					{
						Level = 7,
						Cost = 1000000,
						SaleValue = 5900,
					},

					{
						Level = 8,
						Cost = 2500000,
						SaleValue = 9800,
					},

					{
						Level = 9,
						Cost = 6000000,
						SaleValue = 16000,
					},

					{
						Level = 10,
						Cost = 14000000,
						SaleValue = 26000,
					},
				},
			},
		},
	},
}

return BusinessConfig