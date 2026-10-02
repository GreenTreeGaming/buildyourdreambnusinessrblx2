local LicenseConfig = {}

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


	--==================================================
	-- TIERED / REPEATABLE TRACKS
	--==================================================

	{
		Id = "CustomersServedTrack",

		DisplayName =
			"Customer Service",

		Description =
			"Serve {GOAL} total customers.",

		Order = 10,

		Type =
			"TotalCustomers",

		Stages = {
			{
				Goal = 100,
				Reward = 1,
			},

			{
				Goal = 500,
				Reward = 1,
			},

			{
				Goal = 2000,
				Reward = 1,
			},

			{
				Goal = 5000,
				Reward = 2,
			},

			{
				Goal = 15000,
				Reward = 2,
			},
		},

		Endless = true,

		EndlessGoalMultiplier =
			2,

		EndlessReward =
			2,
	},


	{
		Id = "LifetimeEarningsTrack",

		DisplayName =
			"Business Earnings",

		Description =
			"Earn ${GOAL} total from your businesses.",

		Order = 11,

		Type =
			"LifetimeEarnings",

		Stages = {
			{
				Goal = 10000,
				Reward = 1,
			},

			{
				Goal = 100000,
				Reward = 1,
			},

			{
				Goal = 1000000,
				Reward = 1,
			},

			{
				Goal = 10000000,
				Reward = 2,
			},

			{
				Goal = 100000000,
				Reward = 2,
			},
		},

		Endless = true,

		EndlessGoalMultiplier =
			5,

		EndlessReward =
			2,
	},


	{
		Id = "RareCustomersTrack",

		DisplayName =
			"VIP Treatment",

		Description =
			"Serve {GOAL} VIP or rarer customers.",

		Order = 12,

		Type =
			"RareCustomers",

		Stages = {
			{
				Goal = 1,
				Reward = 1,
			},

			{
				Goal = 10,
				Reward = 1,
			},

			{
				Goal = 50,
				Reward = 1,
			},

			{
				Goal = 200,
				Reward = 2,
			},

			{
				Goal = 500,
				Reward = 2,
			},
		},

		Endless = true,

		EndlessGoalMultiplier =
			2,

		EndlessReward =
			2,
	},


	{
		Id = "BusinessOwnerTrack",

		DisplayName =
			"Growing Empire",

		Description =
			"Own {GOAL} businesses at once.",

		Order = 13,

		Type =
			"OwnedBusinesses",

		Stages = {
			{
				Goal = 3,
				Reward = 1,
			},

			{
				Goal = 8,
				Reward = 1,
			},

			{
				Goal = 15,
				Reward = 1,
			},

			{
				Goal = 25,
				Reward = 2,
			},
		},
	},


	{
		Id = "BusinessVarietyTrack",

		DisplayName =
			"Business Collector",

		Description =
			"Own {GOAL} different types of businesses.",

		Order = 14,

		Type =
			"UniqueBusinessTypes",

		Stages = {
			{
				Goal = 2,
				Reward = 1,
			},

			{
				Goal = 3,
				Reward = 1,
			},

			{
				Goal = 4,
				Reward = 2,
			},
		},
	},


	{
		Id = "GoldenCustomersTrack",

		DisplayName =
			"Golden Customer Hunter",

		Description =
			"Serve {GOAL} Golden customers.",

		Order = 15,

		Type =
			"CustomerTypeVisits",

		CustomerType =
			"Golden",

		Stages = {
			{
				Goal = 1,
				Reward = 2,
			},

			{
				Goal = 3,
				Reward = 2,
			},

			{
				Goal = 10,
				Reward = 3,
			},

			{
				Goal = 25,
				Reward = 3,
			},
		},

		Endless = true,

		EndlessGoalMultiplier =
			2,

		EndlessReward =
			3,
	},
}

function LicenseConfig.GetEarnStage(
	definition: any,
	completedStages: number
): (number?, number?, number, boolean)

	if type(definition.Stages)
		~= "table" then

		return
			definition.Goal,
			definition.Reward,
			1,
			false
	end


	completedStages =
		math.max(
			0,
			math.floor(
				completedStages
			)
		)


	local stageNumber =
		completedStages + 1


	local stage =
		definition.Stages[
			stageNumber
		]


	if stage then

		return
			stage.Goal,
			stage.Reward,
			stageNumber,
			false
	end


	if definition.Endless
		~= true then

		return
			nil,
			nil,
			stageNumber,
			true
	end


	local lastStage =
		definition.Stages[
			#definition.Stages
		]


	if not lastStage then

		return
			nil,
			nil,
			stageNumber,
			true
	end


	local extraStage =
		stageNumber
			- #definition.Stages


	local multiplier =
		tonumber(
			definition
				.EndlessGoalMultiplier
		)
		or 2


	multiplier =
		math.max(
			1.01,
			multiplier
		)


	local goal =
		math.floor(
			lastStage.Goal
				* (
					multiplier
					^ extraStage
				)
		)


	-- Avoid absurd floating point values if someone
	-- somehow reaches thousands of repeatable tiers.
	goal =
		math.clamp(
			goal,
			1,
			9e15
		)


	local reward =
		tonumber(
			definition
				.EndlessReward
		)
		or lastStage.Reward
		or 1


	return
		goal,
		reward,
		stageNumber,
		false
end


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