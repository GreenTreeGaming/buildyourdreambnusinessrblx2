local LicenseConfig = {}


--==================================================
-- GENERAL
--==================================================

LicenseConfig.FragmentsPerLicense =
	10


--==================================================
-- WAYS TO EARN
--==================================================

LicenseConfig.EarnMethods = {
	{
		Id = "DailyStreak7",

		DisplayName =
			"7-Day Streak",

		Description =
			"Complete a full 7-day Daily Rewards streak.",

		Order = 1,

		Type =
			"DailyStreak",

		Goal = 7,

		Reward = 1,
	},


	{
		Id = "Reputation25",

		DisplayName =
			"Established Business",

		Description =
			"Reach Reputation Level 25.",

		Order = 2,

		Type =
			"Reputation",

		Goal = 25,

		Reward = 1,
	},


	{
		Id = "Reputation50",

		DisplayName =
			"Business Legend",

		Description =
			"Reach Reputation Level 50.",

		Order = 3,

		Type =
			"Reputation",

		Goal = 50,

		Reward = 2,
	},


	{
		Id = "MaxLemonade",

		DisplayName =
			"Lemonade Master",

		Description =
			"Fully max out one Lemonade Stand.",

		Order = 4,

		Type =
			"FullyUpgradedBusiness",

		BusinessType =
			"LemonadeStand",

		Goal = 1,

		Reward = 1,
	},


	{
		Id = "MaxHotdog",

		DisplayName =
			"Hotdog Master",

		Description =
			"Fully max out one Hotdog Stand.",

		Order = 5,

		Type =
			"FullyUpgradedBusiness",

		BusinessType =
			"HotdogStand",

		Goal = 1,

		Reward = 1,
	},


	{
		Id = "MaxHaircut",

		DisplayName =
			"Barber Master",

		Description =
			"Fully max out one Haircut business.",

		Order = 6,

		Type =
			"FullyUpgradedBusiness",

		BusinessType =
			"HaircutStand",

		Goal = 1,

		Reward = 1,
	},


	{
		Id = "MaxCoffee",

		DisplayName =
			"Coffee Master",

		Description =
			"Fully max out one Coffee business.",

		Order = 7,

		Type =
			"FullyUpgradedBusiness",

		BusinessType =
			"CoffeeStand",

		Goal = 1,

		Reward = 1,
	},


	{
		Id = "AchievementHunter",

		DisplayName =
			"Achievement Hunter",

		Description =
			"Claim 10 achievement rewards.",

		Order = 8,

		Type =
			"ClaimedAchievementTiers",

		Goal = 10,

		Reward = 1,
	},


	{
		Id = "LicenseFragments",

		DisplayName =
			"License Fragments",

		Description =
			"Collect 10 License Fragments to automatically create a License.",

		Order = 9,

		Type =
			"LicenseFragments",

		Goal =
			LicenseConfig.FragmentsPerLicense,

		Reward = 1,

		Repeatable = true,
	},
}


--==================================================
-- LICENSE UPGRADES
--==================================================
--
-- Costs[n] = cost to purchase level n.
--
-- Example:
-- Costs = {1, 2, 3}
--
-- Level 0 -> 1 costs 1
-- Level 1 -> 2 costs 2
-- Level 2 -> 3 costs 3
--==================================================

LicenseConfig.Upgrades = {
	Operations = {
		Id =
			"Operations",

		DisplayName =
			"Operations License",

		Description =
			"Serve customers 4% faster per level.",

		Order = 1,

		Costs = {
			1,
			2,
			3,
			4,
			5,
		},

		AttributeName =
			"LicenseServiceSpeedMultiplier",

		BonusPerLevel =
			0.04,
	},


	Advertising = {
		Id =
			"Advertising",

		DisplayName =
			"Advertising License",

		Description =
			"Bring in 5% more customers per level.",

		Order = 2,

		Costs = {
			1,
			2,
			3,
			4,
			5,
		},

		AttributeName =
			"LicenseCustomerRateMultiplier",

		BonusPerLevel =
			0.05,
	},


	Expansion = {
		Id =
			"Expansion",

		DisplayName =
			"Expansion License",

		Description =
			"Place 1 additional business of each type per level.",

		Order = 3,

		Costs = {
			3,
			5,
			7,
		},

		AttributeName =
			"LicensePlacementBonus",

		FlatPerLevel =
			1,
	},


	Executive = {
		Id =
			"Executive",

		DisplayName =
			"Executive License",

		Description =
			"Earn 5% more cash from every sale per level.",

		Order = 4,

		Costs = {
			2,
			3,
			4,
			5,
			6,
		},

		AttributeName =
			"LicenseCashMultiplier",

		BonusPerLevel =
			0.05,
	},


	EliteNetwork = {
		Id =
			"EliteNetwork",

		DisplayName =
			"Elite Network License",

		Description =
			"Increase the odds of VIP and rarer customers by 10% per level.",

		Order = 5,

		Costs = {
			4,
			6,
			8,
		},

		AttributeName =
			"LicenseRareCustomerMultiplier",

		BonusPerLevel =
			0.10,
	},
}


--==================================================
-- HELPERS
--==================================================

function LicenseConfig.GetUpgrade(
	upgradeId: string
)
	return LicenseConfig.Upgrades[
		upgradeId
	]
end


function LicenseConfig.GetMaximumLevel(
	upgradeId: string
): number

	local upgrade =
		LicenseConfig.GetUpgrade(
			upgradeId
		)


	if not upgrade
		or type(upgrade.Costs)
			~= "table" then

		return 0
	end


	return #upgrade.Costs
end


function LicenseConfig.GetNextCost(
	upgradeId: string,
	currentLevel: number
): number?

	local upgrade =
		LicenseConfig.GetUpgrade(
			upgradeId
		)


	if not upgrade
		or type(upgrade.Costs)
			~= "table" then

		return nil
	end


	return upgrade.Costs[
		currentLevel + 1
	]
end


return LicenseConfig