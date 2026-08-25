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
-- The goal is for quests to continuously guide
-- progression without becoming the player's
-- primary source of income.
--==================================================


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
		"Serve1000",
		"Serve2500",
		"Serve5000",
		"Serve10000",
	},

	Earnings = {
		"Earn100",
		"Earn1000",
		"Earn5000",
		"Earn10000",
		"Earn25000",
		"Earn50000",
		"Earn100000",
		"Earn250000",
	},

	Recipe = {
		-- Lemonade
		"BetterLemonade1",
		"BetterLemonade3",
		"BetterLemonade5",

		-- Hotdogs
		"BetterHotdogs1",
		"BetterHotdogs3",
		"BetterHotdogs5",

		-- Haircuts
		"BetterHaircuts1",
		"BetterHaircuts3",
		"BetterHaircuts5",
	},

	Service = {
		-- Lemonade
		"FasterService1",
		"LongerQueue2",
		"FasterService3",
		"FasterService5",

		-- Hotdogs
		"HotdogService1",
		"HotdogQueue2",
		"HotdogService3",
		"HotdogService5",

		-- Haircuts
		"HaircutService1",
		"HaircutQueue2",
		"HaircutService3",
		"HaircutService5",
	},

	Growth = {
		-- Lemonade era
		"SecondStand",
		"ProfessionalStand",
		"FiveStands",
		"MaxLemonadeAppearance",

		-- Hotdog era
		"FirstHotdogStand",
		"ThreeHotdogStands",
		"ProfessionalHotdogStand",
		"MaxHotdogAppearance",

		-- Haircut era
		"FirstHaircutStand",
		"ThreeHaircutStands",
		"ProfessionalHaircutStand",
		"MaxHaircutAppearance",
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
			40,
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
			125,
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


	Serve1000 = {
		DisplayName =
			"THOUSAND SERVED",

		Description =
			"Serve 1,000 customers.",

		Type =
			"TotalSales",

		Required =
			1000,

		RewardCash =
			3500,
	},


	Serve2500 = {
		DisplayName =
			"ALWAYS BUSY",

		Description =
			"Serve 2,500 customers.",

		Type =
			"TotalSales",

		Required =
			2500,

		RewardCash =
			6000,
	},


	Serve5000 = {
		DisplayName =
			"CROWD PLEASER",

		Description =
			"Serve 5,000 customers.",

		Type =
			"TotalSales",

		Required =
			5000,

		RewardCash =
			10000,
	},


	Serve10000 = {
		DisplayName =
			"BUSINESS LEGEND",

		Description =
			"Serve 10,000 customers.",

		Type =
			"TotalSales",

		Required =
			10000,

		RewardCash =
			17500,
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


	Earn5000 = {
		DisplayName =
			"GROWING PROFITS",

		Description =
			"Earn $5,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			5000,

		RewardCash =
			750,
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


	Earn25000 = {
		DisplayName =
			"BIG PROFITS",

		Description =
			"Earn $25,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			25000,

		RewardCash =
			2500,
	},


	Earn50000 = {
		DisplayName =
			"ENTREPRENEUR",

		Description =
			"Earn $50,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			50000,

		RewardCash =
			4000,
	},


	Earn100000 = {
		DisplayName =
			"SIX FIGURES",

		Description =
			"Earn $100,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			100000,

		RewardCash =
			7500,
	},


	Earn250000 = {
		DisplayName =
			"BUSINESS MOGUL",

		Description =
			"Earn $250,000 from your businesses.",

		Type =
			"LifetimeEarnings",

		Required =
			250000,

		RewardCash =
			15000,
	},


	--==================================================
	-- RECIPE / SALE VALUE CHAIN
	--==================================================

	--==================================================
	-- LEMONADE
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
	-- HOTDOGS
	--==================================================

	BetterHotdogs1 = {
		DisplayName =
			"BETTER HOTDOGS",

		Description =
			"Upgrade Better Hotdogs once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"SaleValue",

		Required =
			1,

		RewardCash =
			400,
	},


	BetterHotdogs3 = {
		DisplayName =
			"QUALITY HOTDOGS",

		Description =
			"Reach Better Hotdogs Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"SaleValue",

		Required =
			3,

		RewardCash =
			1200,
	},


	BetterHotdogs5 = {
		DisplayName =
			"PERFECT HOTDOGS",

		Description =
			"Max out Better Hotdogs.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"SaleValue",

		Required =
			5,

		RewardCash =
			3000,
	},


	--==================================================
	-- HAIRCUTS
	--==================================================

	BetterHaircuts1 = {
		DisplayName =
			"BETTER HAIRCUTS",

		Description =
			"Upgrade Better Haircuts once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"SaleValue",

		Required =
			1,

		RewardCash =
			1000,
	},


	BetterHaircuts3 = {
		DisplayName =
			"QUALITY CUTS",

		Description =
			"Reach Better Haircuts Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"SaleValue",

		Required =
			3,

		RewardCash =
			3500,
	},


	BetterHaircuts5 = {
		DisplayName =
			"MASTER BARBER",

		Description =
			"Max out Better Haircuts.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"SaleValue",

		Required =
			5,

		RewardCash =
			8000,
	},


	--==================================================
	-- SERVICE CHAIN
	--==================================================

	--==================================================
	-- LEMONADE SERVICE
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


	LongerQueue2 = {
		DisplayName =
			"ROOM FOR MORE",

		Description =
			"Reach Longer Queue Level 2.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"LemonadeStand",

		UpgradeName =
			"QueueCapacity",

		Required =
			2,

		RewardCash =
			250,
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
	-- HOTDOG SERVICE
	--==================================================

	HotdogService1 = {
		DisplayName =
			"FASTER HOTDOGS",

		Description =
			"Upgrade Hotdog Faster Service once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			1,

		RewardCash =
			350,
	},


	HotdogQueue2 = {
		DisplayName =
			"BUSY LUNCH RUSH",

		Description =
			"Reach Hotdog Longer Queue Level 2.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"QueueCapacity",

		Required =
			2,

		RewardCash =
			750,
	},


	HotdogService3 = {
		DisplayName =
			"FAST FOOD",

		Description =
			"Reach Hotdog Faster Service Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			3,

		RewardCash =
			1250,
	},


	HotdogService5 = {
		DisplayName =
			"EXPRESS SERVICE",

		Description =
			"Max out Hotdog Faster Service.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HotdogStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			5,

		RewardCash =
			3000,
	},


	--==================================================
	-- HAIRCUT SERVICE
	--==================================================

	HaircutService1 = {
		DisplayName =
			"QUICK TRIM",

		Description =
			"Upgrade Faster Haircuts once.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			1,

		RewardCash =
			900,
	},


	HaircutQueue2 = {
		DisplayName =
			"FULL WAITING ROOM",

		Description =
			"Reach Waiting Area Level 2.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"QueueCapacity",

		Required =
			2,

		RewardCash =
			1800,
	},


	HaircutService3 = {
		DisplayName =
			"EFFICIENT BARBER",

		Description =
			"Reach Faster Haircuts Level 3.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			3,

		RewardCash =
			3500,
	},


	HaircutService5 = {
		DisplayName =
			"LIGHTNING CUTS",

		Description =
			"Max out Faster Haircuts.",

		Type =
			"UpgradeLevel",

		BusinessType =
			"HaircutStand",

		UpgradeName =
			"ServingSpeed",

		Required =
			5,

		RewardCash =
			7500,
	},


	--==================================================
	-- GROWTH CHAIN
	--==================================================

	--==================================================
	-- LEMONADE ERA
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
			"Reach Lemonade Stand appearance Level 2.",

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


	MaxLemonadeAppearance = {
		DisplayName =
			"LEMONADE LANDMARK",

		Description =
			"Reach Lemonade Stand appearance Level 5.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"LemonadeStand",

		Required =
			5,

		RewardCash =
			2000,
	},


	--==================================================
	-- HOTDOG ERA
	--==================================================

	FirstHotdogStand = {
		DisplayName =
			"NEW BUSINESS",

		Description =
			"Place your first Hotdog Stand.",

		Type =
			"BusinessCount",

		BusinessType =
			"HotdogStand",

		Required =
			1,

		RewardCash =
			500,
	},


	ThreeHotdogStands = {
		DisplayName =
			"HOTDOG EMPIRE",

		Description =
			"Own 3 Hotdog Stands at once.",

		Type =
			"BusinessCount",

		BusinessType =
			"HotdogStand",

		Required =
			3,

		RewardCash =
			1500,
	},


	ProfessionalHotdogStand = {
		DisplayName =
			"PRO HOTDOG STAND",

		Description =
			"Reach Hotdog Stand appearance Level 3.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"HotdogStand",

		Required =
			3,

		RewardCash =
			2000,
	},


	MaxHotdogAppearance = {
		DisplayName =
			"HOTDOG HEADQUARTERS",

		Description =
			"Reach Hotdog Stand appearance Level 5.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"HotdogStand",

		Required =
			5,

		RewardCash =
			4500,
	},


	--==================================================
	-- HAIRCUT ERA
	--==================================================

	FirstHaircutStand = {
		DisplayName =
			"OPEN FOR HAIRCUTS",

		Description =
			"Place your first Haircut Stand.",

		Type =
			"BusinessCount",

		BusinessType =
			"HaircutStand",

		Required =
			1,

		RewardCash =
			1500,
	},


	ThreeHaircutStands = {
		DisplayName =
			"BARBER EMPIRE",

		Description =
			"Own 3 Haircut Stands at once.",

		Type =
			"BusinessCount",

		BusinessType =
			"HaircutStand",

		Required =
			3,

		RewardCash =
			4000,
	},


	ProfessionalHaircutStand = {
		DisplayName =
			"PRO BARBERSHOP",

		Description =
			"Reach Haircut Stand appearance Level 3.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"HaircutStand",

		Required =
			3,

		RewardCash =
			5000,
	},


	MaxHaircutAppearance = {
		DisplayName =
			"LUXURY BARBERSHOP",

		Description =
			"Reach Haircut Stand appearance Level 5.",

		Type =
			"AppearanceLevel",

		BusinessType =
			"HaircutStand",

		Required =
			5,

		RewardCash =
			10000,
	},
}


return QuestConfig