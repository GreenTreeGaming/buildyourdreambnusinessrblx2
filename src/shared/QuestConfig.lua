local QuestConfig = {}


QuestConfig.Order = {
	"FirstSale",
	"Serve10",
	"Earn100",
	"BetterLemonade",
	"FasterService",
	"SecondStand",
	"ProfessionalStand",
	"Serve50",
}


QuestConfig.Quests = {
	FirstSale = {
		DisplayName = "FIRST CUSTOMER",

		Description =
			"Serve your first customer.",

		Type = "TotalSales",

		Required = 1,

		RewardCash = 25,
	},


	Serve10 = {
		DisplayName = "GETTING BUSY",

		Description =
			"Serve 10 customers.",

		Type = "TotalSales",

		Required = 10,

		RewardCash = 100,
	},


	Earn100 = {
		DisplayName = "FIRST $100",

		Description =
			"Earn $100 from your businesses.",

		Type = "LifetimeEarnings",

		Required = 100,

		RewardCash = 150,
	},


	BetterLemonade = {
		DisplayName = "BETTER RECIPE",

		Description =
			"Upgrade Better Lemonade once.",

		Type = "UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"SaleValue",

		Required = 1,

		RewardCash = 100,
	},


	FasterService = {
		DisplayName = "QUICK SERVICE",

		Description =
			"Upgrade Faster Service once.",

		Type = "UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"ServingSpeed",

		Required = 1,

		RewardCash = 100,
	},


	SecondStand = {
		DisplayName = "EXPANDING",

		Description =
			"Own 2 Lemonade Stands at once.",

		Type = "BusinessCount",

		BusinessType =
			"LemonadeStand",

		Required = 2,

		RewardCash = 250,
	},


	ProfessionalStand = {
		DisplayName = "LOOKING PROFESSIONAL",

		Description =
			"Upgrade a Lemonade Stand's appearance.",

		Type = "AppearanceLevel",

		BusinessType =
			"LemonadeStand",

		Required = 2,

		RewardCash = 300,
	},


	Serve50 = {
		DisplayName = "POPULAR BUSINESS",

		Description =
			"Serve 50 customers.",

		Type = "TotalSales",

		Required = 50,

		RewardCash = 500,
	},
}


return QuestConfig