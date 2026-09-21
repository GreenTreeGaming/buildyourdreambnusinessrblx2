local QuestConfig = {}


QuestConfig.MaxVisible =
	5


--==================================================
-- QUEST CHAINS
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
		"Serve25000",
		"Serve50000",
		"Serve100000",
		"Serve250000",
		"Serve500000",
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
		"Earn1000000",
		"Earn5000000",
		"Earn25000000",
		"Earn100000000",
		"Earn500000000",
	},

	Recipe = {
		"BetterLemonade1",
		"BetterLemonade3",
		"BetterLemonade5",

		"BetterHotdogs1",
		"BetterHotdogs3",
		"BetterHotdogs5",

		"BetterHaircuts1",
		"BetterHaircuts3",
		"BetterHaircuts5",

		"BetterCoffee1",
		"BetterCoffee3",
		"BetterCoffee5",
	},

	Service = {
		"FasterService1",
		"LongerQueue2",
		"FasterService3",
		"FasterService5",

		"HotdogService1",
		"HotdogQueue2",
		"HotdogService3",
		"HotdogService5",

		"HaircutService1",
		"HaircutQueue2",
		"HaircutService3",
		"HaircutService5",

		"CoffeeService1",
		"CoffeeQueue2",
		"CoffeeService3",
		"CoffeeService5",
	},

	Growth = {
		"SecondStand",
		"ProfessionalStand",
		"FiveStands",
		"MaxLemonadeAppearance",

		"FirstHotdogStand",
		"ThreeHotdogStands",
		"ProfessionalHotdogStand",
		"MaxHotdogAppearance",

		"FirstHaircutStand",
		"ThreeHaircutStands",
		"ProfessionalHaircutStand",
		"MaxHaircutAppearance",

		"FirstCoffeeStand",
		"ThreeCoffeeStands",
		"ProfessionalCoffeeStand",
		"MaxCoffeeAppearance",
	},
}


--==================================================
-- QUEST DEFINITIONS
--==================================================

QuestConfig.Quests = {

	--==================================================
	-- SALES
	--==================================================

	FirstSale = {
		DisplayName = "FIRST CUSTOMER",
		Description = "Serve your first customer.",
		Type = "TotalSales",
		Required = 1,
		RewardCash = 40,
	},

	Serve10 = {
		DisplayName = "GETTING BUSY",
		Description = "Serve 10 customers.",
		Type = "TotalSales",
		Required = 10,
		RewardCash = 125,
	},

	Serve100 = {
		DisplayName = "POPULAR STAND",
		Description = "Serve 100 customers.",
		Type = "TotalSales",
		Required = 100,
		RewardCash = 500,
	},

	Serve500 = {
		DisplayName = "LOCAL FAVORITE",
		Description = "Serve 500 customers.",
		Type = "TotalSales",
		Required = 500,
		RewardCash = 2500,
	},

	Serve1000 = {
		DisplayName = "THOUSAND SERVED",
		Description = "Serve 1,000 customers.",
		Type = "TotalSales",
		Required = 1000,
		RewardCash = 5_000,
	},

	Serve2500 = {
		DisplayName = "ALWAYS BUSY",
		Description = "Serve 2,500 customers.",
		Type = "TotalSales",
		Required = 2500,
		RewardCash = 15_000,
	},

	Serve5000 = {
		DisplayName = "CROWD PLEASER",
		Description = "Serve 5,000 customers.",
		Type = "TotalSales",
		Required = 5000,
		RewardCash = 35_000,
	},

	Serve10000 = {
		DisplayName = "BUSINESS LEGEND",
		Description = "Serve 10,000 customers.",
		Type = "TotalSales",
		Required = 10_000,
		RewardCash = 75_000,
	},

	Serve25000 = {
		DisplayName = "CITY FAVORITE",
		Description = "Serve 25,000 customers.",
		Type = "TotalSales",
		Required = 25_000,
		RewardCash = 150_000,
	},

	Serve50000 = {
		DisplayName = "NONSTOP BUSINESS",
		Description = "Serve 50,000 customers.",
		Type = "TotalSales",
		Required = 50_000,
		RewardCash = 350_000,
	},

	Serve100000 = {
		DisplayName = "CUSTOMER KING",
		Description = "Serve 100,000 customers.",
		Type = "TotalSales",
		Required = 100_000,
		RewardCash = 750_000,
	},

	Serve250000 = {
		DisplayName = "BUSINESS ICON",
		Description = "Serve 250,000 customers.",
		Type = "TotalSales",
		Required = 250_000,
		RewardCash = 2_000_000,
	},

	Serve500000 = {
		DisplayName = "EMPIRE LEGEND",
		Description = "Serve 500,000 customers.",
		Type = "TotalSales",
		Required = 500_000,
		RewardCash = 5_000_000,
	},


	--==================================================
	-- EARNINGS
	--==================================================

	Earn100 = {
		DisplayName = "FIRST ",
		Description = "Earn  from your businesses.",
		Type = "LifetimeEarnings",
		Required = 100,
		RewardCash = 100,
	},

	Earn1000 = {
		DisplayName = "FOUR FIGURES",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 1000,
		RewardCash = 300,
	},

	Earn5000 = {
		DisplayName = "GROWING PROFITS",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 5000,
		RewardCash = 750,
	},

	Earn10000 = {
		DisplayName = "SERIOUS BUSINESS",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 10_000,
		RewardCash = 1500,
	},

	Earn25000 = {
		DisplayName = "BIG PROFITS",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 25_000,
		RewardCash = 3_000,
	},

	Earn50000 = {
		DisplayName = "ENTREPRENEUR",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 50_000,
		RewardCash = 7_500,
	},

	Earn100000 = {
		DisplayName = "SIX FIGURES",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 100_000,
		RewardCash = 15_000,
	},

	Earn250000 = {
		DisplayName = "BUSINESS MOGUL",
		Description = "Earn ,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 250_000,
		RewardCash = 35_000,
	},

	Earn1000000 = {
		DisplayName = "MILLIONAIRE",
		Description = "Earn ,000,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 1_000_000,
		RewardCash = 75_000,
	},

	Earn5000000 = {
		DisplayName = "MULTI-MILLIONAIRE",
		Description = "Earn ,000,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 5_000_000,
		RewardCash = 200_000,
	},

	Earn25000000 = {
		DisplayName = "BUSINESS TYCOON",
		Description = "Earn ,000,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 25_000_000,
		RewardCash = 600_000,
	},

	Earn100000000 = {
		DisplayName = "MEGA MOGUL",
		Description = "Earn ,000,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 100_000_000,
		RewardCash = 1_500_000,
	},

	Earn500000000 = {
		DisplayName = "EMPIRE BUILDER",
		Description = "Earn ,000,000 from your businesses.",
		Type = "LifetimeEarnings",
		Required = 500_000_000,
		RewardCash = 5_000_000,
	},


	--==================================================
	-- RECIPE: LEMONADE
	--==================================================

	BetterLemonade1 = {
		DisplayName = "BETTER RECIPE",
		Description = "Upgrade Better Lemonade once.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "SaleValue",
		Required = 1,
		RewardCash = 100,
	},

	BetterLemonade3 = {
		DisplayName = "GREAT LEMONADE",
		Description = "Reach Better Lemonade Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "SaleValue",
		Required = 3,
		RewardCash = 400,
	},

	BetterLemonade5 = {
		DisplayName = "PERFECT RECIPE",
		Description = "Reach Better Lemonade Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "SaleValue",
		Required = 5,
		RewardCash = 1000,
	},


	--==================================================
	-- RECIPE: HOTDOG
	--==================================================

	BetterHotdogs1 = {
		DisplayName = "BETTER HOTDOGS",
		Description = "Upgrade Better Hotdogs once.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "SaleValue",
		Required = 1,
		RewardCash = 400,
	},

	BetterHotdogs3 = {
		DisplayName = "QUALITY HOTDOGS",
		Description = "Reach Better Hotdogs Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "SaleValue",
		Required = 3,
		RewardCash = 1200,
	},

	BetterHotdogs5 = {
		DisplayName = "PERFECT HOTDOGS",
		Description = "Reach Better Hotdogs Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "SaleValue",
		Required = 5,
		RewardCash = 3000,
	},


	--==================================================
	-- RECIPE: HAIRCUT
	--==================================================

	BetterHaircuts1 = {
		DisplayName = "BETTER HAIRCUTS",
		Description = "Upgrade Better Haircuts once.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "SaleValue",
		Required = 1,
		RewardCash = 1000,
	},

	BetterHaircuts3 = {
		DisplayName = "QUALITY CUTS",
		Description = "Reach Better Haircuts Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "SaleValue",
		Required = 3,
		RewardCash = 3500,
	},

	BetterHaircuts5 = {
		DisplayName = "MASTER BARBER",
		Description = "Reach Better Haircuts Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "SaleValue",
		Required = 5,
		RewardCash = 8000,
	},


	--==================================================
	-- RECIPE: COFFEE
	--==================================================

	BetterCoffee1 = {
		DisplayName = "BETTER BEANS",
		Description = "Upgrade Better Coffee once.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "SaleValue",
		Required = 1,
		RewardCash = 5000,
	},

	BetterCoffee3 = {
		DisplayName = "PREMIUM COFFEE",
		Description = "Reach Better Coffee Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "SaleValue",
		Required = 3,
		RewardCash = 15_000,
	},

	BetterCoffee5 = {
		DisplayName = "MASTER BARISTA",
		Description = "Reach Better Coffee Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "SaleValue",
		Required = 5,
		RewardCash = 40_000,
	},


	--==================================================
	-- SERVICE: LEMONADE
	--==================================================

	FasterService1 = {
		DisplayName = "QUICK SERVICE",
		Description = "Upgrade Faster Service once.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "ServingSpeed",
		Required = 1,
		RewardCash = 100,
	},

	LongerQueue2 = {
		DisplayName = "ROOM FOR MORE",
		Description = "Reach Longer Queue Level 2.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "QueueCapacity",
		Required = 2,
		RewardCash = 250,
	},

	FasterService3 = {
		DisplayName = "SPEEDY SERVICE",
		Description = "Reach Faster Service Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "ServingSpeed",
		Required = 3,
		RewardCash = 400,
	},

	FasterService5 = {
		DisplayName = "LIGHTNING FAST",
		Description = "Reach Faster Service Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "LemonadeStand",
		UpgradeName = "ServingSpeed",
		Required = 5,
		RewardCash = 1000,
	},


	--==================================================
	-- SERVICE: HOTDOG
	--==================================================

	HotdogService1 = {
		DisplayName = "FASTER HOTDOGS",
		Description = "Upgrade Hotdog Faster Service once.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "ServingSpeed",
		Required = 1,
		RewardCash = 350,
	},

	HotdogQueue2 = {
		DisplayName = "BUSY LUNCH RUSH",
		Description = "Reach Hotdog Longer Queue Level 2.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "QueueCapacity",
		Required = 2,
		RewardCash = 750,
	},

	HotdogService3 = {
		DisplayName = "FAST FOOD",
		Description = "Reach Hotdog Faster Service Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "ServingSpeed",
		Required = 3,
		RewardCash = 1250,
	},

	HotdogService5 = {
		DisplayName = "EXPRESS SERVICE",
		Description = "Reach Hotdog Faster Service Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "HotdogStand",
		UpgradeName = "ServingSpeed",
		Required = 5,
		RewardCash = 3000,
	},


	--==================================================
	-- SERVICE: HAIRCUT
	--==================================================

	HaircutService1 = {
		DisplayName = "QUICK TRIM",
		Description = "Upgrade Faster Haircuts once.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "ServingSpeed",
		Required = 1,
		RewardCash = 900,
	},

	HaircutQueue2 = {
		DisplayName = "FULL WAITING ROOM",
		Description = "Reach Waiting Area Level 2.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "QueueCapacity",
		Required = 2,
		RewardCash = 1800,
	},

	HaircutService3 = {
		DisplayName = "EFFICIENT BARBER",
		Description = "Reach Faster Haircuts Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "ServingSpeed",
		Required = 3,
		RewardCash = 3500,
	},

	HaircutService5 = {
		DisplayName = "LIGHTNING CUTS",
		Description = "Reach Faster Haircuts Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "HaircutStand",
		UpgradeName = "ServingSpeed",
		Required = 5,
		RewardCash = 7500,
	},


	--==================================================
	-- SERVICE: COFFEE
	--==================================================

	CoffeeService1 = {
		DisplayName = "QUICK BREW",
		Description = "Upgrade Faster Brewing once.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "ServingSpeed",
		Required = 1,
		RewardCash = 5000,
	},

	CoffeeQueue2 = {
		DisplayName = "BUSY CAFE",
		Description = "Reach More Seating Level 2.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "QueueCapacity",
		Required = 2,
		RewardCash = 12_500,
	},

	CoffeeService3 = {
		DisplayName = "EXPERT BARISTA",
		Description = "Reach Faster Brewing Level 3.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "ServingSpeed",
		Required = 3,
		RewardCash = 30_000,
	},

	CoffeeService5 = {
		DisplayName = "COFFEE EXPRESS",
		Description = "Reach Faster Brewing Level 5.",
		Type = "UpgradeLevel",
		BusinessType = "CoffeeStand",
		UpgradeName = "ServingSpeed",
		Required = 5,
		RewardCash = 75_000,
	},


	--==================================================
	-- GROWTH: LEMONADE
	--==================================================

	SecondStand = {
		DisplayName = "EXPANDING",
		Description = "Own 2 Lemonade Stands at once.",
		Type = "BusinessCount",
		BusinessType = "LemonadeStand",
		Required = 2,
		RewardCash = 250,
	},

	ProfessionalStand = {
		DisplayName = "LOOKING PROFESSIONAL",
		Description = "Reach Lemonade Stand appearance Level 2.",
		Type = "AppearanceLevel",
		BusinessType = "LemonadeStand",
		Required = 2,
		RewardCash = 300,
	},

	FiveStands = {
		DisplayName = "BUSINESS EMPIRE",
		Description = "Own 5 Lemonade Stands at once.",
		Type = "BusinessCount",
		BusinessType = "LemonadeStand",
		Required = 5,
		RewardCash = 1500,
	},

	MaxLemonadeAppearance = {
		DisplayName = "LEMONADE LANDMARK",
		Description = "Reach Lemonade Stand appearance Level 5.",
		Type = "AppearanceLevel",
		BusinessType = "LemonadeStand",
		Required = 5,
		RewardCash = 2000,
	},


	--==================================================
	-- GROWTH: HOTDOG
	--==================================================

	FirstHotdogStand = {
		DisplayName = "NEW BUSINESS",
		Description = "Place your first Hotdog Stand.",
		Type = "BusinessCount",
		BusinessType = "HotdogStand",
		Required = 1,
		RewardCash = 500,
	},

	ThreeHotdogStands = {
		DisplayName = "HOTDOG EMPIRE",
		Description = "Own 3 Hotdog Stands at once.",
		Type = "BusinessCount",
		BusinessType = "HotdogStand",
		Required = 3,
		RewardCash = 1500,
	},

	ProfessionalHotdogStand = {
		DisplayName = "PRO HOTDOG STAND",
		Description = "Reach Hotdog Stand appearance Level 3.",
		Type = "AppearanceLevel",
		BusinessType = "HotdogStand",
		Required = 3,
		RewardCash = 2000,
	},

	MaxHotdogAppearance = {
		DisplayName = "HOTDOG HEADQUARTERS",
		Description = "Reach Hotdog Stand appearance Level 5.",
		Type = "AppearanceLevel",
		BusinessType = "HotdogStand",
		Required = 5,
		RewardCash = 4500,
	},


	--==================================================
	-- GROWTH: HAIRCUT
	--==================================================

	FirstHaircutStand = {
		DisplayName = "OPEN FOR HAIRCUTS",
		Description = "Place your first Haircut Stand.",
		Type = "BusinessCount",
		BusinessType = "HaircutStand",
		Required = 1,
		RewardCash = 1500,
	},

	ThreeHaircutStands = {
		DisplayName = "BARBER EMPIRE",
		Description = "Own 3 Haircut Stands at once.",
		Type = "BusinessCount",
		BusinessType = "HaircutStand",
		Required = 3,
		RewardCash = 4000,
	},

	ProfessionalHaircutStand = {
		DisplayName = "PRO BARBERSHOP",
		Description = "Reach Haircut Stand appearance Level 3.",
		Type = "AppearanceLevel",
		BusinessType = "HaircutStand",
		Required = 3,
		RewardCash = 5000,
	},

	MaxHaircutAppearance = {
		DisplayName = "LUXURY BARBERSHOP",
		Description = "Reach Haircut Stand appearance Level 5.",
		Type = "AppearanceLevel",
		BusinessType = "HaircutStand",
		Required = 5,
		RewardCash = 10000,
	},


	--==================================================
	-- GROWTH: COFFEE
	--==================================================

	FirstCoffeeStand = {
		DisplayName = "OPEN THE CAFE",
		Description = "Place your first Coffee Stand.",
		Type = "BusinessCount",
		BusinessType = "CoffeeStand",
		Required = 1,
		RewardCash = 15_000,
	},

	ThreeCoffeeStands = {
		DisplayName = "CAFE EMPIRE",
		Description = "Own 3 Coffee Stands at once.",
		Type = "BusinessCount",
		BusinessType = "CoffeeStand",
		Required = 3,
		RewardCash = 40_000,
	},

	ProfessionalCoffeeStand = {
		DisplayName = "PREMIUM CAFE",
		Description = "Reach Coffee Stand appearance Level 3.",
		Type = "AppearanceLevel",
		BusinessType = "CoffeeStand",
		Required = 3,
		RewardCash = 75_000,
	},

	MaxCoffeeAppearance = {
		DisplayName = "COFFEE LANDMARK",
		Description = "Reach Coffee Stand appearance Level 5.",
		Type = "AppearanceLevel",
		BusinessType = "CoffeeStand",
		Required = 5,
		RewardCash = 200_000,
	},
}


return QuestConfig