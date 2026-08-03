local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",

		FirstStandFree = true,
		AdditionalStandCost = 750,
		MaximumPlaced = 15,

		BaseSaleValue = 2,
		BaseServingCooldown = 5,

		-- Controls the physical appearance of the stand.
		StandLevels = {
			[1] = {
				TemplateName = "LemonadeStand",
				UpgradeCost = 50,
			},

			[2] = {
				TemplateName = "LemonadeStand2",

				-- Cost to upgrade from Level 2 to Level 3 later.
				UpgradeCost = 250,
			},

			-- Add these when the models are ready.
			--[[
			[3] = {
				TemplateName = "LemonadeStand3",
				UpgradeCost = 1000,
			},

			[4] = {
				TemplateName = "LemonadeStand4",
				UpgradeCost = 4000,
			},

			[5] = {
				TemplateName = "LemonadeStand5",
				UpgradeCost = nil,
			},
			]]
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
						Cost = 75,
						Cooldown = 3.5,
					},
					{
						Level = 3,
						Cost = 175,
						Cooldown = 2.75,
					},
					{
						Level = 4,
						Cost = 400,
						Cooldown = 2,
					},
					{
						Level = 5,
						Cost = 900,
						Cooldown = 1.25,
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
						SaleValue = 2,
					},
					{
						Level = 1,
						Cost = 50,
						SaleValue = 3,
					},
					{
						Level = 2,
						Cost = 150,
						SaleValue = 5,
					},
					{
						Level = 3,
						Cost = 400,
						SaleValue = 8,
					},
					{
						Level = 4,
						Cost = 1000,
						SaleValue = 12,
					},
					{
						Level = 5,
						Cost = 2500,
						SaleValue = 18,
					},
				},
			},
		},
	},
}

return BusinessConfig