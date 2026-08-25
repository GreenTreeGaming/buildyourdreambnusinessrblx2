local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",

		DisplayOrder = 1,

		RevealDescription =
			"Start small, serve refreshing lemonade, and build your business empire from the ground up.",

		UnlockRequirements = nil,

		FirstStandFree = true,

		AdditionalStandCost = 450,

		MaximumPlaced = 15,

		BaseSaleValue = 4,
BaseServingCooldown = 5,

		StandLevels = {
	[1] = {
		TemplateName = "LemonadeStand",
		UpgradeCost = 35,

		CustomerAttraction = 1.00,
		CustomerRateMultiplier = 1.00,
	},

	[2] = {
		TemplateName = "LemonadeStand2",
		UpgradeCost = 175,

		CustomerAttraction = 1.15,
		CustomerRateMultiplier = 1.10,
	},

	[3] = {
		TemplateName = "LemonadeStand3",
		UpgradeCost = 650,

		CustomerAttraction = 1.35,
		CustomerRateMultiplier = 1.25,
	},

	[4] = {
		TemplateName = "LemonadeStand4",
		UpgradeCost = 2500,

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
		SaleValue = 4,
	},

	{
		Level = 1,
		Cost = 35,
		SaleValue = 5,
	},

	{
		Level = 2,
		Cost = 110,
		SaleValue = 7,
	},

	{
		Level = 3,
		Cost = 280,
		SaleValue = 10,
	},

	{
		Level = 4,
		Cost = 650,
		SaleValue = 15,
	},

	{
		Level = 5,
		Cost = 1500,
		SaleValue = 22,
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

		LifetimeEarnings = 250,

		BusinessLevel = {
			BusinessType = "LemonadeStand",
			Level = 2,
		},
	},

	FirstStandFree = false,

	-- Cheap enough that unlocking Hotdogs encourages the
	-- player to actually branch into the new business.
	AdditionalStandCost = 900,

	MaximumPlaced = 12,

	-- Hotdogs should immediately feel more valuable than
	-- lemonade without invalidating upgraded lemonade stands.
	BaseSaleValue = 15,

	BaseServingCooldown = 5,

	StandLevels = {
		[1] = {
			TemplateName = "HotdogStand",
			UpgradeCost = 200,

			CustomerAttraction = 1.00,
			CustomerRateMultiplier = 1.00,
		},

		[2] = {
			TemplateName = "HotdogStand2",
			UpgradeCost = 700,

			CustomerAttraction = 1.15,
			CustomerRateMultiplier = 1.10,
		},

		[3] = {
			TemplateName = "HotdogStand3",
			UpgradeCost = 2250,

			CustomerAttraction = 1.35,
			CustomerRateMultiplier = 1.25,
		},

		[4] = {
			TemplateName = "HotdogStand4",
			UpgradeCost = 7000,

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
					Cooldown = 5,
				},

				{
					Level = 1,
					Cost = 80,
					Cooldown = 4.25,
				},

				{
					Level = 2,
					Cost = 225,
					Cooldown = 3.5,
				},

				{
					Level = 3,
					Cost = 525,
					Cooldown = 2.8,
				},

				{
					Level = 4,
					Cost = 1200,
					Cooldown = 2.15,
				},

				{
					Level = 5,
					Cost = 2800,
					Cooldown = 1.6,
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
					Cost = 160,
					Capacity = 2,
				},

				{
					Level = 2,
					Cost = 500,
					Capacity = 3,
				},

				{
					Level = 3,
					Cost = 1400,
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
					SaleValue = 15,
				},

				{
					Level = 1,
					Cost = 120,
					SaleValue = 20,
				},

				{
					Level = 2,
					Cost = 350,
					SaleValue = 27,
				},

				{
					Level = 3,
					Cost = 900,
					SaleValue = 36,
				},

				{
					Level = 4,
					Cost = 2200,
					SaleValue = 48,
				},

				{
					Level = 5,
					Cost = 5000,
					SaleValue = 64,
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

		LifetimeEarnings = 3000,

		BusinessLevel = {
			BusinessType = "HotdogStand",
			Level = 3,
		},
	},

	FirstStandFree = false,

	AdditionalStandCost = 4500,

	MaximumPlaced = 10,

	BaseSaleValue = 40,
	BaseServingCooldown = 6,

	StandLevels = {
		[1] = {
			TemplateName = "HaircutStand",
			UpgradeCost = 900,

			CustomerAttraction = 1.00,
			CustomerRateMultiplier = 1.00,
		},

		[2] = {
			TemplateName = "HaircutStand2",
			UpgradeCost = 3200,

			CustomerAttraction = 1.15,
			CustomerRateMultiplier = 1.10,
		},

		[3] = {
			TemplateName = "HaircutStand3",
			UpgradeCost = 10000,

			CustomerAttraction = 1.35,
			CustomerRateMultiplier = 1.25,
		},

		[4] = {
			TemplateName = "HaircutStand4",
			UpgradeCost = 30000,

			CustomerAttraction = 1.60,
			CustomerRateMultiplier = 1.45,
		},

		[5] = {
			TemplateName = "HaircutStand5",
			UpgradeCost = nil,

			CustomerAttraction = 1.90,
			CustomerRateMultiplier = 1.70,
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
					Cost = 350,
					Cooldown = 5.1,
				},

				{
					Level = 2,
					Cost = 1000,
					Cooldown = 4.3,
				},

				{
					Level = 3,
					Cost = 2600,
					Cooldown = 3.5,
				},

				{
					Level = 4,
					Cost = 6500,
					Cooldown = 2.8,
				},

				{
					Level = 5,
					Cost = 14500,
					Cooldown = 2.1,
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
					Cost = 650,
					Capacity = 2,
				},

				{
					Level = 2,
					Cost = 2100,
					Capacity = 3,
				},

				{
					Level = 3,
					Cost = 6000,
					Capacity = 4,
				},
			},
		},

		SaleValue = {
			DisplayName = "Better Haircuts",

			Description =
				"Improve your haircut quality and charge more for every customer.",

			ValueType = "SaleValue",

			Levels = {
				{
					Level = 0,
					Cost = 0,
					SaleValue = 40,
				},

				{
					Level = 1,
					Cost = 550,
					SaleValue = 52,
				},

				{
					Level = 2,
					Cost = 1600,
					SaleValue = 68,
				},

				{
					Level = 3,
					Cost = 4200,
					SaleValue = 90,
				},

				{
					Level = 4,
					Cost = 10500,
					SaleValue = 120,
				},

				{
					Level = 5,
					Cost = 24000,
					SaleValue = 160,
				},
			},
		},
	},
},
}

return BusinessConfig