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

		-- Lemonade Stand
		StockCapacityByLevel = {
			[1] = 45,
			[2] = 65,
			[3] = 90,
			[4] = 130,
			[5] = 180,
		},

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
					"Better lemonade, bigger profits!",
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

		-- Hotdog Stand
		StockCapacityByLevel = {
			[1] = 45,
			[2] = 70,
			[3] = 100,
			[4] = 145,
			[5] = 200,
		},

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
					"Tastier hotdogs, bigger profits!",
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

		-- Haircut Stand
		StockCapacityByLevel = {
			[1] = 40,
			[2] = 60,
			[3] = 85,
			[4] = 120,
			[5] = 165,
		},

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
					"Better haircuts, bigger profits!",
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

		-- Coffee Stand
		StockCapacityByLevel = {
			[1] = 45,
			[2] = 70,
			[3] = 100,
			[4] = 145,
			[5] = 200,
		},

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
					"Premium coffee, bigger profits!",
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

	IcecreamStand = {
		DisplayName = "Ice Cream Stand",
		DisplayOrder = 5,
	
		RevealDescription =
			"Open your own ice cream business, serve delicious frozen treats, and earn huge profits!",
	
		UnlockRequirements = {
			RebirthsRequired = 2,
	
			ReputationLevel = 25,
	
			LifetimeEarnings = 5_000_000,
	
			BusinessLevel = {
				BusinessType = "CoffeeStand",
				Level = 3,
			},
		},
	
		FirstStandFree = false,
	
		AdditionalStandCost = 400_000,
	
		StandCostGrowth = 1.38,
	
		MaximumPlaced = 8,
	
		BaseSaleValue = 4_000,
	
		BaseServingCooldown = 6,
	
		--==================================================
		-- STOCK CAPACITY
		--==================================================
	
		StockCapacityByLevel = {
			[1] = 50,
			[2] = 75,
			[3] = 110,
			[4] = 155,
			[5] = 215,
		},
	
		--==================================================
		-- STAND LEVELS
		--==================================================
	
		StandLevels = {
			[1] = {
				TemplateName = "IcecreamStand",
	
				UpgradeCost = 100_000,
	
				CustomerAttraction = 1.15,
	
				CustomerRateMultiplier = 1.00,
	
				SaleValueMultiplier = 1.00,
	
				PremiumCustomerAttraction = 1.30,
			},
	
			[2] = {
				TemplateName = "IcecreamStand2",
	
				UpgradeCost = 350_000,
	
				CustomerAttraction = 1.40,
	
				CustomerRateMultiplier = 1.10,
	
				SaleValueMultiplier = 1.35,
	
				PremiumCustomerAttraction = 1.60,
			},
	
			[3] = {
				TemplateName = "IcecreamStand3",
	
				UpgradeCost = 900_000,
	
				CustomerAttraction = 1.75,
	
				CustomerRateMultiplier = 1.20,
	
				SaleValueMultiplier = 1.90,
	
				PremiumCustomerAttraction = 2.00,
			},
	
			[4] = {
				TemplateName = "IcecreamStand4",
	
				UpgradeCost = 2_250_000,
	
				CustomerAttraction = 2.15,
	
				CustomerRateMultiplier = 1.32,
	
				SaleValueMultiplier = 2.80,
	
				PremiumCustomerAttraction = 2.65,
			},
	
			[5] = {
				TemplateName = "IcecreamStand5",
	
				UpgradeCost = nil,
	
				CustomerAttraction = 2.70,
	
				CustomerRateMultiplier = 1.45,
	
				SaleValueMultiplier = 4.20,
	
				PremiumCustomerAttraction = 3.50,
			},
		},
	
		--==================================================
		-- BUSINESS UPGRADES
		--==================================================
	
		Upgrades = {
	
			--==============================================
			-- SERVING SPEED
			--==============================================
	
			ServingSpeed = {
				DisplayName = "Faster Scooping",
	
				Description =
					"Upgrade your equipment to serve ice cream faster.",
	
				ValueType = "Cooldown",
	
				Levels = {
					{
						Level = 0,
						Cost = 0,
						Cooldown = 6,
					},
	
					{
						Level = 1,
						Cost = 25_000,
						Cooldown = 5.3,
					},
	
					{
						Level = 2,
						Cost = 80_000,
						Cooldown = 4.6,
					},
	
					{
						Level = 3,
						Cost = 220_000,
						Cooldown = 3.9,
					},
	
					{
						Level = 4,
						Cost = 500_000,
						Cooldown = 3.3,
					},
	
					{
						Level = 5,
						Cost = 1_100_000,
						Cooldown = 2.7,
					},
	
					{
						Level = 6,
						Cost = 2_250_000,
						Cooldown = 2.2,
					},
	
					{
						Level = 7,
						Cost = 4_500_000,
						Cooldown = 1.8,
					},
				},
			},
	
			--==============================================
			-- QUEUE CAPACITY
			--==============================================
	
			QueueCapacity = {
				DisplayName = "More Seating",
	
				Description =
					"Expand your seating area to serve more customers.",
	
				ValueType = "QueueCapacity",
	
				Levels = {
					{
						Level = 0,
						Cost = 0,
						Capacity = 1,
					},
	
					{
						Level = 1,
						Cost = 40_000,
						Capacity = 2,
					},
	
					{
						Level = 2,
						Cost = 120_000,
						Capacity = 3,
					},
	
					{
						Level = 3,
						Cost = 350_000,
						Capacity = 4,
					},
	
					{
						Level = 4,
						Cost = 900_000,
						Capacity = 5,
					},
				},
			},
	
			--==============================================
			-- SALE VALUE
			--==============================================
	
			SaleValue = {
				DisplayName = "Better Ice Cream",
	
				Description =
					"Create premium ice cream flavors for bigger profits!",
	
				ValueType = "SaleValue",
	
				Levels = {
					{
						Level = 0,
						Cost = 0,
						SaleValue = 4_000,
					},
	
					{
						Level = 1,
						Cost = 30_000,
						SaleValue = 6_400,
					},
	
					{
						Level = 2,
						Cost = 100_000,
						SaleValue = 10_000,
					},
	
					{
						Level = 3,
						Cost = 280_000,
						SaleValue = 15_200,
					},
	
					{
						Level = 4,
						Cost = 680_000,
						SaleValue = 23_200,
					},
	
					{
						Level = 5,
						Cost = 1_600_000,
						SaleValue = 34_000,
					},
	
					{
						Level = 6,
						Cost = 3_600_000,
						SaleValue = 50_000,
					},
	
					{
						Level = 7,
						Cost = 7_200_000,
						SaleValue = 72_000,
					},
	
					{
						Level = 8,
						Cost = 14_000_000,
						SaleValue = 104_000,
					},
	
					{
						Level = 9,
						Cost = 26_000_000,
						SaleValue = 152_000,
					},
	
					{
						Level = 10,
						Cost = 48_000_000,
						SaleValue = 220_000,
					},
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