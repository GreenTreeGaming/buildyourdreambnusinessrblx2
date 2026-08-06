local MarketingConfig = {
	DisplayName = "Marketing",

	Levels = {
		{
			Level = 0,
			Cost = 0,

			DisplayName = "Word of Mouth",
			Description =
				"Customers discover your businesses naturally.",

			-- Future physical model.
			TemplateName = nil,

			CustomerLimit = 6,
			MinimumSpawnInterval = 1.8,
			MaximumSpawnInterval = 3.4,
		},

		{
			Level = 1,
			Cost = 500,

			DisplayName = "Flyer Stand",
			Description =
				"Put out simple flyers to attract more customers.",

			-- Add this model later.
			TemplateName = "MarketingFlyerStand",

			CustomerLimit = 8,
			MinimumSpawnInterval = 1.6,
			MaximumSpawnInterval = 3,
		},

		{
			Level = 2,
			Cost = 1500,

			DisplayName = "Sidewalk Board",
			Description =
				"Advertise your businesses with a visible sidewalk sign.",

			TemplateName = "MarketingSidewalkBoard",

			CustomerLimit = 10,
			MinimumSpawnInterval = 1.4,
			MaximumSpawnInterval = 2.6,
		},

		{
			Level = 3,
			Cost = 4000,

			DisplayName = "Large Billboard",
			Description =
				"Reach customers across the area with a large billboard.",

			TemplateName = "MarketingBillboard",

			CustomerLimit = 12,
			MinimumSpawnInterval = 1.2,
			MaximumSpawnInterval = 2.2,
		},
	},
}

return MarketingConfig