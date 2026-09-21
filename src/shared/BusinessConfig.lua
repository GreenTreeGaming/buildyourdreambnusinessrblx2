local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",
		DisplayOrder = 1,

		RevealDescription =
			"Start small, serve refreshing lemonade, and build your business empire from the ground up.",

		UnlockRequirements = nil,

		FirstStandFree = true,

		AdditionalStandCost = 750,

		StandCostGrowth = 1.25,

		MaximumPlaced = 15,

		BaseSaleValue = 10,

		BaseServingCooldown = 5,

		StandLevels = {
			[1] = {
				TemplateName = "LemonadeStand",
				UpgradeCost = 150,
				CustomerAttraction = 1.00,
				CustomerRateMultiplier = 1.00,
				SaleValueMultiplier = 1.00,
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
				UpgradeCost = 3200,
				CustomerAttraction = 1.20,
				CustomerRateMultiplier = 1.35,
				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.07,
			},

			[4] = {
				TemplateName = "LemonadeStand4",
				UpgradeCost = 10500,
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
					{ Level = 0, Cost = 0, Cooldown = 5 },
					{ Level = 1, Cost = 75, Cooldown = 4.4 },
					{ Level = 2, Cost = 250, Cooldown = 3.8 },
					{ Level = 3, Cost = 700, Cooldown = 3.2 },
					{ Level = 4, Cost = 1800, Cooldown = 2.7 },
					{ Level = 5, Cost = 4000, Cooldown = 2.2 },
					{ Level = 6, Cost = 8000, Cooldown = 1.8 },
					{ Level = 7, Cost = 15000, Cooldown = 1.5 },
				},
			},

			QueueCapacity = {
				DisplayName = "Longer Queue",
				Description =
					"Allow more customers to wait at this stand.",
				ValueType = "QueueCapacity",

				Levels = {
					{ Level = 0, Cost = 0, Capacity = 1 },
					{ Level = 1, Cost = 125, Capacity = 2 },
					{ Level = 2, Cost = 500, Capacity = 3 },
					{ Level = 3, Cost = 1800, Capacity = 4 },
					{ Level = 4, Cost = 5000, Capacity = 5 },
				},
			},

			SaleValue = {
				DisplayName = "Better Lemonade",
				Description =
					"Improve your lemonade recipe and dramatically increase the value of every sale.",
				ValueType = "SaleValue",

				Levels = {
					{ Level = 0, Cost = 0, SaleValue = 10 },
					{ Level = 1, Cost = 100, SaleValue = 16 },
					{ Level = 2, Cost = 350, SaleValue = 26 },
					{ Level = 3, Cost = 1000, SaleValue = 45 },
					{ Level = 4, Cost = 2800, SaleValue = 80 },
					{ Level = 5, Cost = 6500, SaleValue = 140 },
					{ Level = 6, Cost = 15000, SaleValue = 240 },
					{ Level = 7, Cost = 30000, SaleValue = 400 },
					{ Level = 8, Cost = 55000, SaleValue = 650 },
					{ Level = 9, Cost = 100000, SaleValue = 1050 },
					{ Level = 10, Cost = 180000, SaleValue = 1700 },
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
			ReputationLevel = 4,
			LifetimeEarnings = 2500,

			BusinessLevel = {
				BusinessType = "LemonadeStand",
				Level = 2,
			},
		},

		FirstStandFree = false,

		AdditionalStandCost = 3000,

		StandCostGrowth = 1.30,

		MaximumPlaced = 12,

		BaseSaleValue = 45,

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
				UpgradeCost = 11000,
				CustomerAttraction = 1.35,
				CustomerRateMultiplier = 1.25,
				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.25,
			},

			[4] = {
				TemplateName = "HotdogStand4",
				UpgradeCost = 30000,
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
					{ Level = 0, Cost = 0, Cooldown = 5 },
					{ Level = 1, Cost = 300, Cooldown = 4.4 },
					{ Level = 2, Cost = 900, Cooldown = 3.8 },
					{ Level = 3, Cost = 2600, Cooldown = 3.2 },
					{ Level = 4, Cost = 7000, Cooldown = 2.7 },
					{ Level = 5, Cost = 15000, Cooldown = 2.2 },
					{ Level = 6, Cost = 28000, Cooldown = 1.8 },
					{ Level = 7, Cost = 60000, Cooldown = 1.5 },
				},
			},

			QueueCapacity = {
				DisplayName = "Longer Queue",
				Description =
					"Allow more customers to wait at this stand.",
				ValueType = "QueueCapacity",

				Levels = {
					{ Level = 0, Cost = 0, Capacity = 1 },
					{ Level = 1, Cost = 500, Capacity = 2 },
					{ Level = 2, Cost = 1600, Capacity = 3 },
					{ Level = 3, Cost = 5000, Capacity = 4 },
					{ Level = 4, Cost = 12000, Capacity = 5 },
				},
			},

			SaleValue = {
				DisplayName = "Better Hotdogs",
				Description =
					"Improve your hotdogs and dramatically increase the value of every sale.",
				ValueType = "SaleValue",

				Levels = {
					{ Level = 0, Cost = 0, SaleValue = 45 },
					{ Level = 1, Cost = 400, SaleValue = 70 },
					{ Level = 2, Cost = 1300, SaleValue = 115 },
					{ Level = 3, Cost = 4000, SaleValue = 180 },
					{ Level = 4, Cost = 11000, SaleValue = 310 },
					{ Level = 5, Cost = 30000, SaleValue = 525 },
					{ Level = 6, Cost = 75000, SaleValue = 900 },
					{ Level = 7, Cost = 140000, SaleValue = 1500 },
					{ Level = 8, Cost = 300000, SaleValue = 2500 },
					{ Level = 9, Cost = 625000, SaleValue = 4000 },
					{ Level = 10, Cost = 1300000, SaleValue = 6500 },
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
			ReputationLevel = 10,
			LifetimeEarnings = 75000,

			BusinessLevel = {
				BusinessType = "HotdogStand",
				Level = 3,
			},
		},

		FirstStandFree = false,

		AdditionalStandCost = 18000,

		StandCostGrowth = 1.32,

		MaximumPlaced = 10,

		BaseSaleValue = 250,

		BaseServingCooldown = 6,

		StandLevels = {
			[1] = {
				TemplateName = "HaircutStand",
				UpgradeCost = 5000,
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
				UpgradeCost = 55000,
				CustomerAttraction = 1.45,
				CustomerRateMultiplier = 1.10,
				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.70,
			},

			[4] = {
				TemplateName = "HaircutStand4",
				UpgradeCost = 155000,
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
					{ Level = 0, Cost = 0, Cooldown = 6 },
					{ Level = 1, Cost = 1500, Cooldown = 5.3 },
					{ Level = 2, Cost = 5000, Cooldown = 4.6 },
					{ Level = 3, Cost = 15000, Cooldown = 3.9 },
					{ Level = 4, Cost = 35000, Cooldown = 3.3 },
					{ Level = 5, Cost = 75000, Cooldown = 2.7 },
					{ Level = 6, Cost = 175000, Cooldown = 2.2 },
					{ Level = 7, Cost = 375000, Cooldown = 1.8 },
				},
			},

			QueueCapacity = {
				DisplayName = "Waiting Area",
				Description =
					"Add more seating so additional customers can wait for a haircut.",
				ValueType = "QueueCapacity",

				Levels = {
					{ Level = 0, Cost = 0, Capacity = 1 },
					{ Level = 1, Cost = 2500, Capacity = 2 },
					{ Level = 2, Cost = 8000, Capacity = 3 },
					{ Level = 3, Cost = 20000, Capacity = 4 },
					{ Level = 4, Cost = 55000, Capacity = 5 },
				},
			},

			SaleValue = {
				DisplayName = "Better Haircuts",
				Description =
					"Improve your service quality and dramatically increase what each haircut earns.",
				ValueType = "SaleValue",

				Levels = {
					{ Level = 0, Cost = 0, SaleValue = 250 },
					{ Level = 1, Cost = 2000, SaleValue = 400 },
					{ Level = 2, Cost = 6500, SaleValue = 600 },
					{ Level = 3, Cost = 20000, SaleValue = 900 },
					{ Level = 4, Cost = 55000, SaleValue = 1300 },
					{ Level = 5, Cost = 110000, SaleValue = 2050 },
					{ Level = 6, Cost = 250000, SaleValue = 3500 },
					{ Level = 7, Cost = 550000, SaleValue = 5900 },
					{ Level = 8, Cost = 1150000, SaleValue = 9800 },
					{ Level = 9, Cost = 2400000, SaleValue = 16000 },
					{ Level = 10, Cost = 5000000, SaleValue = 26000 },
				},
			},
		},
	},

	CoffeeStand = {
		DisplayName = "Coffee Stand",
		DisplayOrder = 4,

		RevealDescription =
			"Serve premium coffee, attract wealthier customers, and turn your stand into a bustling café.",

		UnlockRequirements = {
			RebirthsRequired = 1,
			ReputationLevel = 18,
			LifetimeEarnings = 1_000_000,

			BusinessLevel = {
				BusinessType = "HaircutStand",
				Level = 4,
			},
		},

		FirstStandFree = false,

		AdditionalStandCost = 90000,

		StandCostGrowth = 1.35,

		MaximumPlaced = 8,

		BaseSaleValue = 1000,

		BaseServingCooldown = 6,

		StandLevels = {
			[1] = {
				TemplateName = "CoffeeStand",
				UpgradeCost = 25000,
				CustomerAttraction = 1.10,
				CustomerRateMultiplier = 1.00,
				SaleValueMultiplier = 1.00,
				PremiumCustomerAttraction = 1.20,
			},

			[2] = {
				TemplateName = "CoffeeStand2",
				UpgradeCost = 90000,
				CustomerAttraction = 1.30,
				CustomerRateMultiplier = 1.08,
				SaleValueMultiplier = 1.35,
				PremiumCustomerAttraction = 1.45,
			},

			[3] = {
				TemplateName = "CoffeeStand3",
				UpgradeCost = 225000,
				CustomerAttraction = 1.60,
				CustomerRateMultiplier = 1.16,
				SaleValueMultiplier = 1.90,
				PremiumCustomerAttraction = 1.85,
			},

			[4] = {
				TemplateName = "CoffeeStand4",
				UpgradeCost = 550000,
				CustomerAttraction = 2.00,
				CustomerRateMultiplier = 1.26,
				SaleValueMultiplier = 2.80,
				PremiumCustomerAttraction = 2.45,
			},

			[5] = {
				TemplateName = "CoffeeStand5",
				UpgradeCost = nil,
				CustomerAttraction = 2.50,
				CustomerRateMultiplier = 1.38,
				SaleValueMultiplier = 4.20,
				PremiumCustomerAttraction = 3.20,
			},
		},

		Upgrades = {
			ServingSpeed = {
				DisplayName = "Faster Brewing",
				Description =
					"Upgrade your equipment to prepare coffee faster.",
				ValueType = "Cooldown",

				Levels = {
					{ Level = 0, Cost = 0, Cooldown = 6 },
					{ Level = 1, Cost = 6000, Cooldown = 5.3 },
					{ Level = 2, Cost = 20000, Cooldown = 4.6 },
					{ Level = 3, Cost = 60000, Cooldown = 3.9 },
					{ Level = 4, Cost = 125000, Cooldown = 3.3 },
					{ Level = 5, Cost = 275000, Cooldown = 2.7 },
					{ Level = 6, Cost = 550000, Cooldown = 2.2 },
					{ Level = 7, Cost = 1100000, Cooldown = 1.8 },
				},
			},

			QueueCapacity = {
				DisplayName = "More Seating",
				Description =
					"Add more seating so additional customers can wait for their coffee.",
				ValueType = "QueueCapacity",

				Levels = {
					{ Level = 0, Cost = 0, Capacity = 1 },
					{ Level = 1, Cost = 10000, Capacity = 2 },
					{ Level = 2, Cost = 30000, Capacity = 3 },
					{ Level = 3, Cost = 75000, Capacity = 4 },
					{ Level = 4, Cost = 180000, Capacity = 5 },
				},
			},

			SaleValue = {
				DisplayName = "Better Coffee",
				Description =
					"Use higher-quality ingredients and dramatically increase the value of every order.",
				ValueType = "SaleValue",

				Levels = {
					{ Level = 0, Cost = 0, SaleValue = 1000 },

					{ Level = 1, Cost = 7500, SaleValue = 1600 },

					{ Level = 2, Cost = 25000, SaleValue = 2500 },

					{ Level = 3, Cost = 70000, SaleValue = 3800 },

					{ Level = 4, Cost = 170000, SaleValue = 5800 },

					{ Level = 5, Cost = 400000, SaleValue = 8500 },

					{ Level = 6, Cost = 900000, SaleValue = 12500 },

					{ Level = 7, Cost = 1800000, SaleValue = 18000 },

					{ Level = 8, Cost = 3500000, SaleValue = 26000 },

					{ Level = 9, Cost = 6500000, SaleValue = 38000 },

					{ Level = 10, Cost = 12000000, SaleValue = 55000 },
				},
			},
		},
	},
}


--==================================================
-- STAND PURCHASE PRICING
--==================================================

function BusinessConfig.GetStandPurchaseCost(
	businessType: string,
	currentOwned: number
): number

	local config =
		BusinessConfig[
			businessType
		]


	if type(config) ~= "table" then
		return 0
	end


	currentOwned =
		math.max(
			0,
			math.floor(
				tonumber(currentOwned)
					or 0
			)
		)


	if config.FirstStandFree == true
		and currentOwned == 0 then

		return 0
	end


	local baseCost =
		tonumber(
			config.AdditionalStandCost
		) or 0


	if baseCost <= 0 then
		return 0
	end


	local growth =
		tonumber(
			config.StandCostGrowth
		) or 1


	growth =
		math.max(
			1,
			growth
		)


	local growthSteps


	if config.FirstStandFree == true then

		growthSteps =
			math.max(
				0,
				currentOwned - 1
			)

	else

		growthSteps =
			currentOwned
	end


	local calculatedCost =
		baseCost
		* (
			growth
			^ growthSteps
		)


	return math.max(
		0,
		math.floor(
			calculatedCost
				+ 0.5
		)
	)
end


return BusinessConfig