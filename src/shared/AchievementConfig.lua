local AchievementConfig = {}

AchievementConfig.Categories = {
	{
		Id = "All",
		DisplayName = "All",
		Order = 1,
	},

	{
		Id = "Business",
		DisplayName = "Business",
		Order = 2,
	},

	{
		Id = "Customers",
		DisplayName = "Customers",
		Order = 3,
	},

	{
		Id = "Money",
		DisplayName = "Money",
		Order = 4,
	},

	{
		Id = "Rare",
		DisplayName = "Rare",
		Order = 5,
	},

	{
		Id = "Special",
		DisplayName = "Special",
		Order = 6,
	},
}

AchievementConfig.Achievements = {
	--==================================================
	-- CUSTOMERS
	--==================================================

	{
		Id = "CustomerMagnet",

		DisplayName = "Customer Magnet",

		Category = "Customers",

		Order = 1,

		Metric = {
			Type = "TotalCustomers",
		},

		Tiers = {
			{
				Goal = 100,
				Reward = 350,
				Description = "Serve 100 customers!",
			},

			{
				Goal = 500,
				Reward = 1750,
				Description = "Serve 500 customers!",
			},

			{
				Goal = 2500,
				Reward = 10000,
				Description = "Serve 2,500 customers!",
			},

			{
				Goal = 10000,
				Reward = 45000,
				Description = "Serve 10,000 customers!",
			},

			{
				Goal = 50000,
				Reward = 225000,
				Description = "Serve 50,000 customers!",
			},
		},
	},

	{
		Id = "CustomerCollector",

		DisplayName = "Customer Collector",

		Category = "Special",

		Order = 2,

		Metric = {
			Type = "CustomerTypesDiscovered",
		},

		Tiers = {
			{
				Goal = 3,
				Reward = 500,

				Description =
					"Discover 3 different customer types!",
			},

			{
				Goal = 5,
				Reward = 3000,

				Description =
					"Discover 5 different customer types!",
			},

			{
				Goal = 8,
				Reward = 30000,

				Description =
					"Discover every customer type!",
			},
		},
	},

	--==================================================
	-- RARE CUSTOMERS
	--==================================================

	{
		Id = "VIPHost",

		DisplayName = "VIP Host",

		Category = "Rare",

		Order = 10,

		Metric = {
			Type = "CustomerTypeVisits",
			CustomerType = "VIP",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 500,
				Description = "Serve your first VIP customer!",
			},

			{
				Goal = 10,
				Reward = 3000,
				Description = "Serve 10 VIP customers!",
			},

			{
				Goal = 50,
				Reward = 15000,
				Description = "Serve 50 VIP customers!",
			},

			{
				Goal = 250,
				Reward = 75000,
				Description = "Serve 250 VIP customers!",
			},

			{
				Goal = 1000,
				Reward = 350000,
				Description = "Serve 1,000 VIP customers!",
			},
		},
	},

	{
		Id = "CelebrityHost",

		DisplayName = "Celebrity Host",

		Category = "Rare",

		Order = 11,

		Metric = {
			Type = "CustomerTypeVisits",
			CustomerType = "Celebrity",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 1000,

				Description =
					"Serve your first Celebrity customer!",
			},

			{
				Goal = 10,
				Reward = 7500,

				Description =
					"Serve 10 Celebrity customers!",
			},

			{
				Goal = 50,
				Reward = 40000,

				Description =
					"Serve 50 Celebrity customers!",
			},

			{
				Goal = 250,
				Reward = 200000,

				Description =
					"Serve 250 Celebrity customers!",
			},
		},
	},

	{
		Id = "BillionaireHost",

		DisplayName = "Billionaire Host",

		Category = "Rare",

		Order = 12,

		Metric = {
			Type = "CustomerTypeVisits",
			CustomerType = "Billionaire",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 5000,

				Description =
					"Serve your first Billionaire customer!",
			},

			{
				Goal = 5,
				Reward = 25000,

				Description =
					"Serve 5 Billionaire customers!",
			},

			{
				Goal = 25,
				Reward = 125000,

				Description =
					"Serve 25 Billionaire customers!",
			},

			{
				Goal = 100,
				Reward = 500000,

				Description =
					"Serve 100 Billionaire customers!",
			},
		},
	},

	{
		Id = "GoldenMoment",

		DisplayName = "Golden Moment",

		Category = "Rare",

		Order = 13,

		Metric = {
			Type = "CustomerTypeVisits",
			CustomerType = "Golden",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 12500,

				Description =
					"Serve your first Golden customer!",
			},

			{
				Goal = 3,
				Reward = 50000,

				Description =
					"Serve 3 Golden customers!",
			},

			{
				Goal = 10,
				Reward = 200000,

				Description =
					"Serve 10 Golden customers!",
			},

			{
				Goal = 25,
				Reward = 500000,

				Description =
					"Serve 25 Golden customers!",
			},
		},
	},

	--==================================================
	-- BUSINESS
	--==================================================

	{
		Id = "LemonLegend",

		DisplayName = "Lemon Legend",

		Category = "Business",

		Order = 20,

		Metric = {
			Type = "BusinessLevel",
			BusinessType = "LemonadeStand",
		},

		Tiers = {
			{
				Goal = 2,
				Reward = 350,

				Description =
					"Upgrade a Lemonade Stand to Tier 2!",
			},

			{
				Goal = 3,
				Reward = 1500,

				Description =
					"Upgrade a Lemonade Stand to Tier 3!",
			},

			{
				Goal = 5,
				Reward = 10000,

				Description =
					"Upgrade a Lemonade Stand to Tier 5!",
			},
		},
	},

	{
		Id = "HotdogHustler",

		DisplayName = "Hotdog Hustler",

		Category = "Business",

		Order = 21,

		Metric = {
			Type = "OwnedBusinessCount",
			BusinessType = "HotdogStand",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 1000,

				Description =
					"Own your first Hotdog Stand!",
			},

			{
				Goal = 3,
				Reward = 5000,

				Description =
					"Own 3 Hotdog Stands!",
			},

			{
				Goal = 6,
				Reward = 20000,

				Description =
					"Own 6 Hotdog Stands!",
			},

			{
				Goal = 12,
				Reward = 90000,

				Description =
					"Own 12 Hotdog Stands!",
			},
		},
	},

	{
		Id = "HaircutEmpire",

		DisplayName = "Haircut Empire",

		Category = "Business",

		Order = 22,

		Metric = {
			Type = "BusinessUnlocked",
			BusinessType = "HaircutStand",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 7500,

				Description =
					"Unlock the Haircut Stand!",
			},
		},
	},

	{
		Id = "MaxedOut",

		DisplayName = "Maxed Out",

		Category = "Business",

		Order = 23,

		Metric = {
			Type = "FullyUpgradedBusinesses",
		},

		Tiers = {
			{
				Goal = 1,
				Reward = 15000,

				Description =
					"Fully upgrade one business!",
			},

			{
				Goal = 3,
				Reward = 65000,

				Description =
					"Fully upgrade 3 businesses!",
			},

			{
				Goal = 10,
				Reward = 275000,

				Description =
					"Fully upgrade 10 businesses!",
			},
		},
	},

	--==================================================
	-- MONEY
	--==================================================

	{
		Id = "BigMoney",

		DisplayName = "Big Money",

		Category = "Money",

		Order = 30,

		Metric = {
			Type = "LifetimeEarnings",
		},

		Tiers = {
			{
				Goal = 10000,
				Reward = 750,

				Description =
					"Earn $10,000 from your businesses!",
			},

			{
				Goal = 100000,
				Reward = 5000,

				Description =
					"Earn $100,000 from your businesses!",
			},

			{
				Goal = 1000000,
				Reward = 30000,

				Description =
					"Earn $1,000,000 from your businesses!",
			},

			{
				Goal = 10000000,
				Reward = 125000,

				Description =
					"Earn $10,000,000 from your businesses!",
			},

			{
				Goal = 100000000,
				Reward = 500000,

				Description =
					"Earn $100,000,000 from your businesses!",
			},
		},
	},
}

return AchievementConfig