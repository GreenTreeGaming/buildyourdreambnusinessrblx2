local QuestConfig = {}


QuestConfig.MaxVisible =
	5


--==================================================
-- QUEST CHAINS
--==================================================

--
-- Only ONE quest from each chain is shown.
--
-- After the current quest is claimed,
-- the next one replaces it.
--

QuestConfig.ChainOrder = {
	"Sales",
	"Earnings",
	"Recipe",
	"Service",
	"Growth",
}


QuestConfig.Chains = {
	Sales = {
		"FirstSale",
		"Serve10",
		"Serve100",
		"Serve500",
	},

	Earnings = {
		"Earn100",
		"Earn1000",
		"Earn10000",
	},

	Recipe = {
		"BetterLemonade1",
		"BetterLemonade3",
		"BetterLemonade5",
	},

	Service = {
		"FasterService1",
		"FasterService3",
		"FasterService5",
	},

	Growth = {
		"SecondStand",
		"ProfessionalStand",
		"FiveStands",
	},
}


--==================================================
-- QUEST DEFINITIONS
--==================================================

QuestConfig.Quests = {

	--==================================================
	-- SALES CHAIN
	--==================================================

	FirstSale = {
		DisplayName =
			"FIRST CUSTOMER",

		Description =
			"Serve your first customer.",

		Type =
			"TotalSales",

		Required =
			1,

		RewardCash =
			25,
	},


	Serve10 = {
		DisplayName =
			"GETTING BUSY",

		Description =
			"Serve 10 customers.",

		Type =
			"TotalSales",

		Required =
			10,

		RewardCash =
			100,
	},


	Serve100 = {
		DisplayName =
			"POPULAR STAND",

		Description =
			"Serve 100 customers.",

		Type =
			"TotalSales",

		Required =
			100,

		RewardCash =
			500,
	},


	Serve500 = {
		DisplayName =
			"LOCAL FAVORITE",

		Description =
			"Serve 500 customers.",

		Type =
			"TotalSales",

		Required =
			500,

		RewardCash =
			2500,
	},


	--==================================================
	-- EARNINGS CHAIN
	--==================================================

	Earn100 = {
		DisplayName =
			"FIRST $100",

		Description =
			"Earn $100 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			100,

		RewardCash =
			100,
	},


	Earn1000 = {
		DisplayName =
			"FOUR FIGURES",

		Description =
			"Earn $1,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			1000,

		RewardCash =
			300,
	},


	Earn10000 = {
		DisplayName =
			"SERIOUS BUSINESS",

		Description =
			"Earn $10,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			10000,

		RewardCash =
			1500,
	},


	--==================================================
	-- RECIPE CHAIN
	--==================================================

	BetterLemonade1 = {
		DisplayName =
			"BETTER RECIPE",

		Description =
			"Upgrade Better Lemonade once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"SaleValue",

		Required =
			1,

		RewardCash =
			100,
	},


	BetterLemonade3 = {
		DisplayName =
			"GREAT LEMONADE",

		Description =
			"Reach Better Lemonade Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"SaleValue",

		Required =
			3,

		RewardCash =
			400,
	},


	BetterLemonade5 = {
		DisplayName =
			"PERFECT RECIPE",

		Description =
			"Max out Better Lemonade.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"SaleValue",

		Required =
			5,

		RewardCash =
			1000,
	},


	--==================================================
	-- SERVICE CHAIN
	--==================================================

	FasterService1 = {
		DisplayName =
			"QUICK SERVICE",

		Description =
			"Upgrade Faster Service once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			1,

		RewardCash =
			100,
	},


	FasterService3 = {
		DisplayName =
			"SPEEDY SERVICE",

		Description =
			"Reach Faster Service Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			3,

		RewardCash =
			400,
	},


	FasterService5 = {
		DisplayName =
			"LIGHTNING FAST",

		Description =
			"Max out Faster Service.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			5,

		RewardCash =
			1000,
	},


	--==================================================
	-- GROWTH CHAIN
	--==================================================

	SecondStand = {
		DisplayName =
			"EXPANDING",

		Description =
			"Own 2 Lemonade Stands at once.",

		Type =
			"BusinessCount",

		BusinessType =
			"LemonadeStand",

		Required =
			2,

		RewardCash =
			250,
	},


	ProfessionalStand = {
		DisplayName =
			"LOOKING PROFESSIONAL",

		Description =
			"Upgrade a Lemonade Stand's appearance.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"LemonadeStand",

		Required =
			2,

		RewardCash =
			300,
	},


	FiveStands = {
		DisplayName =
			"BUSINESS EMPIRE",

		Description =
			"Own 5 Lemonade Stands at once.",

		Type =
			"BusinessCount",

		BusinessType =
			"LemonadeStand",

		Required =
			5,

		RewardCash =
			1500,
	},
}


return QuestConfig