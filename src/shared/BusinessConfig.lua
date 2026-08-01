local BusinessConfig = {
	LemonadeStand = {
		DisplayName = "Lemonade Stand",

		BaseSaleValue = 2,
		BaseServingCooldown = 5,

		Upgrades = {
			ServingSpeed = {
				DisplayName = "Faster Service",
				Description = "Serve each customer faster.",

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
		},
	},
}

return BusinessConfig