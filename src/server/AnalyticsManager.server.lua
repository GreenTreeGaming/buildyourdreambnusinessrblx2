local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local Services =
	script.Parent:WaitForChild(
		"Services"
	)


local AnalyticsTracker =
	require(
		Services:WaitForChild(
			"AnalyticsService"
		)
	)


local DataService =
	require(
		Services:WaitForChild(
			"DataService"
		)
	)


local Shared =
	ReplicatedStorage:WaitForChild(
		"Shared"
	)


local BusinessConfig =
	require(
		Shared:WaitForChild(
			"BusinessConfig"
		)
	)


local ReputationConfig =
	require(
		Shared:WaitForChild(
			"ReputationConfig"
		)
	)


local PlotConfig =
	require(
		Shared:WaitForChild(
			"PlotConfig"
		)
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


--==================================================
-- REMOTE
--==================================================

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new(
			"Folder"
		)

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage
end


local analyticsEvent =
	remotes:FindFirstChild(
		"AnalyticsEvent"
	)


if analyticsEvent
	and not analyticsEvent:IsA(
		"RemoteEvent"
	) then

	analyticsEvent:Destroy()

	analyticsEvent =
		nil
end


if not analyticsEvent then

	analyticsEvent =
		Instance.new(
			"RemoteEvent"
		)

	analyticsEvent.Name =
		"AnalyticsEvent"

	analyticsEvent.Parent =
		remotes
end


analyticsEvent =
	analyticsEvent :: RemoteEvent


--==================================================
-- CONSTANTS
--==================================================

local UPDATE_INTERVAL =
	0.5


local HIGHER_RARE_CUSTOMERS = {
	Celebrity = true,
	Influencer = true,
	Billionaire = true,
	Golden = true,
}


local RARE_CUSTOMERS = {
	VIP = true,
	Celebrity = true,
	Influencer = true,
	Billionaire = true,
	Golden = true,
}


local UPGRADE_ATTRIBUTES = {
	ServingSpeed =
		"ServingSpeedLevel",

	SaleValue =
		"SaleValueLevel",

	QueueCapacity =
		"QueueCapacityLevel",
}


--==================================================
-- TYPES
--==================================================

type Snapshot = {
	BusinessIds: {
		[string]: boolean
	},

	BusinessTypeCounts: {
		[string]: number
	},

	BusinessLevels: {
		[string]: number
	},

	UpgradeLevels: {
		[string]: number
	},

	TotalSales: number,

	ReputationLevel: number,

	UnlockedBusinesses: {
		[string]: boolean
	},

	PlotLevel: number,

	PlotEligible: boolean,

	CustomerVisits: {
		[string]: number
	},

	QuestCompleted: number,
	QuestClaimed: number,

	AchievementClaimed: number,

	DailyNextClaimAt: number,
	DailyLastClaimDay: number,

	TutorialCompleted: boolean,

	BoughtFirstUpgrade: boolean,

	EarlyReached: {
		[number]: boolean
	},

	EarlyLoggedThrough: number,
}


local snapshots: {
	[Player]: Snapshot
} = {}


--==================================================
-- HELPERS
--==================================================

local function sanitizeNumber(
	value: any
): number

	if typeof(value)
			~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end


	return math.max(
		0,
		math.floor(
			value
		)
	)
end


local function countTrueValues(
	map: any
): number

	if type(map)
		~= "table" then

		return 0
	end


	local count =
		0


	for _, value in map do

		if value == true then

			count +=
				1
		end
	end


	return count
end


local function copyBooleanMap(
	value: any
): {[string]: boolean}

	local result: {
		[string]: boolean
	} = {}


	if type(value)
		~= "table" then

		return result
	end


	for key,
		enabled in value do

		if typeof(key)
				== "string"
			and enabled == true then

			result[
				key
			] = true
		end
	end


	return result
end


local function copyNumberMap(
	value: any
): {[string]: number}

	local result: {
		[string]: number
	} = {}


	if type(value)
		~= "table" then

		return result
	end


	for key,
		amount in value do

		if typeof(key)
				== "string" then

			result[
				key
			] =
				sanitizeNumber(
					amount
				)
		end
	end


	return result
end


local function getPlayerPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)


		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plotsFolder:GetChildren()
	do

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getBusinessType(
	business: Model
): string

	local businessType =
		business:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType)
			== "string"
		and businessType ~= "" then

		return businessType
	end


	for configuredType in
		BusinessConfig do

		if business.Name
				== configuredType
			or string.match(
				business.Name,
				`^{configuredType}_`
			) then

			return configuredType
		end
	end


	return business.Name
end


local function getBusinessId(
	business: Model
): string

	local businessId =
		business:GetAttribute(
			"BusinessId"
		)


	if typeof(businessId)
			== "string"
		and businessId ~= "" then

		return businessId
	end


	return business.Name
end


local function getCash(
	player: Player
): number

	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)


	local cash =
		leaderstats
		and leaderstats:FindFirstChild(
			"Cash"
		)


	if cash
		and cash:IsA(
			"IntValue"
		) then

		return sanitizeNumber(
			cash.Value
		)
	end


	return 0
end


local function getNextPlotCost(
	currentLevel: number
): number?

	for _, definition in
		PlotConfig.Levels
	do

		if type(definition)
				== "table"
			and definition.Level
				== currentLevel + 1
			and typeof(
				definition.Cost
			) == "number" then

			return definition.Cost
		end
	end


	return nil
end


local function getStarterPlotSize():
	number

	for _, definition in
		PlotConfig.Levels
	do

		if type(definition)
				== "table"
			and definition.Level
				== 0
			and typeof(
				definition.Size
			) == "number" then

			return definition.Size
		end
	end


	return 180
end


local STARTER_PLOT_SIZE =
	getStarterPlotSize()


local function getSavedReputationLevel(
	player: Player,
	profile: any
): number

	local totalSales =
		0


	if type(
		profile.PlacedBusinesses
	) == "table" then

		for _, business in
			profile.PlacedBusinesses
		do

			if type(business)
				== "table" then

				totalSales +=
					sanitizeNumber(
						business.TotalSales
					)
			end
		end
	end


	totalSales +=
		sanitizeNumber(
			DataService.GetReputationBonusSales(
				player
			)
		)


	local reputationLevel =
		ReputationConfig
			.GetStateFromSales(
				totalSales
			)


	return math.max(
		1,
		sanitizeNumber(
			reputationLevel
		)
	)
end


local EARLY_STEP_NAMES = {
	[1] = "First Lemonade Stand",
	[2] = "First Appearance Upgrade",
	[3] = "Second Stand Placed",
	[4] = "Reputation Level 2",
	[5] = "Hotdog Stand Unlocked",
	[6] = "First Hotdog Stand Placed",
	[7] = "First Plot Expansion",
	[8] = "Next Business Unlocked",
}


local function flushEarlyProgression(
	player: Player,
	snapshot: Snapshot
)

	while snapshot.EarlyReached[
		snapshot.EarlyLoggedThrough
			+ 1
	] == true do

		local nextStep =
			snapshot.EarlyLoggedThrough
			+ 1


		AnalyticsTracker.LogFunnel(
			player,
			"EarlyProgression",
			nextStep,
			EARLY_STEP_NAMES[
				nextStep
			]
		)


		snapshot.EarlyLoggedThrough =
			nextStep
	end
end


local function markEarlyStep(
	player: Player,
	snapshot: Snapshot,
	step: number
)

	snapshot.EarlyReached[
		step
	] =
		true


	flushEarlyProgression(
		player,
		snapshot
	)
end


--==================================================
-- INITIAL SNAPSHOT
--==================================================

local function createSnapshot(
	player: Player,
	profile: any
): Snapshot

	local snapshot: Snapshot = {
		BusinessIds = {},
		BusinessTypeCounts = {},
		BusinessLevels = {},
		UpgradeLevels = {},

		TotalSales = 0,

		ReputationLevel =
			getSavedReputationLevel(
				player,
				profile
			),

		UnlockedBusinesses =
			copyBooleanMap(
				profile.UnlockedBusinesses
			),

		PlotLevel =
			sanitizeNumber(
				profile.PlotLevel
			),

		PlotEligible = false,

		CustomerVisits =
			copyNumberMap(
				DataService.GetCustomerVisits(
					player
				)
			),

		QuestCompleted = 0,
		QuestClaimed = 0,

		AchievementClaimed = 0,

		DailyNextClaimAt = 0,
		DailyLastClaimDay = 0,

		TutorialCompleted =
			DataService.GetTutorialCompleted(
				player
			),

		BoughtFirstUpgrade = false,

		EarlyReached = {},

		EarlyLoggedThrough = 0,
	}


	if type(
		profile.PlacedBusinesses
	) == "table" then

		for _, business in
			profile.PlacedBusinesses
		do

			if type(business)
				~= "table" then

				continue
			end


			local id =
				business.Id


			local businessType =
				business.Type


			if typeof(id)
					~= "string"
				or typeof(businessType)
					~= "string" then

				continue
			end


			snapshot.BusinessIds[
				id
			] = true


			snapshot.BusinessTypeCounts[
				businessType
			] =
				(
					snapshot.BusinessTypeCounts[
						businessType
					]
					or 0
				) + 1


			snapshot.BusinessLevels[
				id
			] =
				math.max(
					1,
					sanitizeNumber(
						business.Level
					)
				)


			snapshot.TotalSales +=
				sanitizeNumber(
					business.TotalSales
				)


			if snapshot.BusinessLevels[
				id
			] > 1 then

				snapshot.BoughtFirstUpgrade =
					true
			end


			if type(
				business.Upgrades
			) == "table" then

				for upgradeName,
					level in
					business.Upgrades
				do

					local sanitizedLevel =
						sanitizeNumber(
							level
						)


					snapshot.UpgradeLevels[
						`{id}:{upgradeName}`
					] =
						sanitizedLevel


					if sanitizedLevel > 0 then

						snapshot.BoughtFirstUpgrade =
							true
					end
				end
			end
		end
	end


	local quests =
		profile.Quests


	if type(quests)
		== "table" then

		snapshot.QuestCompleted =
			countTrueValues(
				quests.Completed
			)


		snapshot.QuestClaimed =
			countTrueValues(
				quests.Claimed
			)
	end


	local achievements =
		profile.Achievements


	if type(achievements)
		== "table" then

		snapshot.AchievementClaimed =
			countTrueValues(
				achievements.Claimed
			)
	end


	local dailyData =
		DataService.GetDailyRewardData(
			player
		)


	if dailyData then

		snapshot.DailyNextClaimAt =
			sanitizeNumber(
				dailyData.NextClaimAt
			)


		snapshot.DailyLastClaimDay =
			sanitizeNumber(
				dailyData.LastClaimRewardDay
			)
	end


	--
	-- Reconstruct already-achieved early milestones so
	-- the funnel can continue correctly after a rejoin.
	--

	if (
		snapshot.BusinessTypeCounts
			.LemonadeStand
			or 0
	) >= 1 then

		snapshot.EarlyReached[1] =
			true
	end


	for _, level in
		snapshot.BusinessLevels
	do

		if level >= 2 then

			snapshot.EarlyReached[2] =
				true

			break
		end
	end


	if countTrueValues(
		snapshot.BusinessIds
	) >= 2 then

		snapshot.EarlyReached[3] =
			true
	end


	if snapshot.ReputationLevel
		>= 2 then

		snapshot.EarlyReached[4] =
			true
	end


	if snapshot.UnlockedBusinesses
		.HotdogStand == true then

		snapshot.EarlyReached[5] =
			true
	end


	if (
		snapshot.BusinessTypeCounts
			.HotdogStand
			or 0
	) >= 1 then

		snapshot.EarlyReached[6] =
			true
	end


	if snapshot.PlotLevel
		>= 1 then

		snapshot.EarlyReached[7] =
			true
	end


	for businessType,
		unlocked in
		snapshot.UnlockedBusinesses
	do

		local config =
			BusinessConfig[
				businessType
			]


		if unlocked
			and type(config)
				== "table"
			and typeof(
				config.DisplayOrder
			) == "number"
			and config.DisplayOrder
				>= 3 then

			snapshot.EarlyReached[8] =
				true

			break
		end
	end


	return snapshot
end


--==================================================
-- BUSINESS TRACKING
--==================================================

local function updateBusinesses(
	player: Player,
	snapshot: Snapshot,
	plot: Model
)

	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not folder then
		return
	end


	local currentIds: {
		[string]: boolean
	} = {}


	local currentTotalSales =
		0


	for _, business in
		folder:GetChildren()
	do

		if not business:IsA(
			"Model"
		) then

			continue
		end


		if business:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		local businessId =
			getBusinessId(
				business
			)


		local businessType =
			getBusinessType(
				business
			)


		currentIds[
			businessId
		] = true


		local wasKnown =
			snapshot.BusinessIds[
				businessId
			] == true


		if not wasKnown then

			snapshot.BusinessIds[
				businessId
			] =
				true


			local previousTypeCount =
				snapshot.BusinessTypeCounts[
					businessType
				] or 0


			snapshot.BusinessTypeCounts[
				businessType
			] =
				previousTypeCount
				+ 1


			if businessType
					== "LemonadeStand"
				and previousTypeCount
					== 0 then

				AnalyticsTracker.LogOnboarding(
					player,
					AnalyticsTracker
						.Onboarding
						.PlacedFirstLemonadeStand,
					"Placed First Lemonade Stand"
				)


				markEarlyStep(
					player,
					snapshot,
					1
				)
			end


			if countTrueValues(
				snapshot.BusinessIds
			) >= 2 then

				markEarlyStep(
					player,
					snapshot,
					3
				)
			end


			if businessType
					== "HotdogStand"
				and previousTypeCount
					== 0 then

				markEarlyStep(
					player,
					snapshot,
					6
				)
			end


			if previousTypeCount
				== 0 then

				local config =
					BusinessConfig[
						businessType
					]


				local displayOrder =
					config
					and config.DisplayOrder


				local displayName =
					config
					and config.DisplayName
					or businessType


				if typeof(displayOrder)
						== "number"
					and displayOrder > 0 then

					AnalyticsTracker.LogProgression(
						player,
						"BusinessProgression",
						displayOrder,
						displayName
					)
				end
			end
		end


		local level =
			math.max(
				1,
				sanitizeNumber(
					business:GetAttribute(
						"Level"
					)
				)
			)


		local previousLevel =
			snapshot.BusinessLevels[
				businessId
			] or level


		if level > previousLevel then

			snapshot.BoughtFirstUpgrade =
				true


			AnalyticsTracker.LogOnboarding(
				player,
				AnalyticsTracker
					.Onboarding
					.BoughtFirstUpgrade,
				"Bought First Upgrade"
			)


			AnalyticsTracker.LogFunnel(
				player,
				"Upgrade",
				3,
				"Purchased Upgrade"
			)


			if previousLevel < 2
				and level >= 2 then

				markEarlyStep(
					player,
					snapshot,
					2
				)
			end


			for reachedLevel =
				previousLevel + 1,
				level
			do

				local funnelStep =
					reachedLevel + 2


				if reachedLevel >= 2
					and reachedLevel <= 5 then

					AnalyticsTracker.LogFunnel(
						player,
						"Upgrade",
						funnelStep,
						`Reached Tier {reachedLevel}`
					)
				end
			end
		end


		snapshot.BusinessLevels[
			businessId
		] =
			math.max(
				previousLevel,
				level
			)


		for upgradeName,
			attributeName in
			UPGRADE_ATTRIBUTES
		do

			local key =
				`{businessId}:{upgradeName}`


			local currentLevel =
				sanitizeNumber(
					business:GetAttribute(
						attributeName
					)
				)


			local previousUpgrade =
				snapshot.UpgradeLevels[
					key
				] or 0


			if currentLevel
				> previousUpgrade then

				snapshot.BoughtFirstUpgrade =
					true


				AnalyticsTracker.LogOnboarding(
					player,
					AnalyticsTracker
						.Onboarding
						.BoughtFirstUpgrade,
					"Bought First Upgrade"
				)


				AnalyticsTracker.LogFunnel(
					player,
					"Upgrade",
					3,
					"Purchased Upgrade"
				)
			end


			snapshot.UpgradeLevels[
				key
			] =
				math.max(
					previousUpgrade,
					currentLevel
				)
		end


		currentTotalSales +=
			sanitizeNumber(
				business:GetAttribute(
					"TotalSales"
				)
			)
	end


	if currentTotalSales
		> snapshot.TotalSales then

		if snapshot.TotalSales
			<= 0 then
		
			AnalyticsTracker.LogOnboarding(
				player,
				AnalyticsTracker
					.Onboarding
					.ServedFirstCustomer,
				"Served First Customer"
			)
		end


		snapshot.TotalSales =
			currentTotalSales
	end
end


--==================================================
-- USED EXPANDED SPACE
--==================================================

local function checkExpandedSpaceUsed(
	player: Player,
	snapshot: Snapshot,
	plot: Model
)

	if snapshot.PlotLevel
		< 1 then

		return
	end


	local ground =
		plot:FindFirstChild(
			"Ground"
		)


	local businesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not ground
		or not ground:IsA(
			"BasePart"
		)
		or not businesses then

		return
	end


	local starterHalfSize =
		STARTER_PLOT_SIZE
			/ 2


	for _, business in
		businesses:GetChildren()
	do

		if not business:IsA(
			"Model"
		) then

			continue
		end


		local origin =
			business:FindFirstChild(
				"PlacementOrigin",
				true
			)


		if not origin
			or not origin:IsA(
				"BasePart"
			) then

			continue
		end


		local localPosition =
			ground.CFrame:
				PointToObjectSpace(
					origin.Position
				)


		if math.abs(
				localPosition.X
			) > starterHalfSize
			or math.abs(
				localPosition.Z
			) > starterHalfSize then

			AnalyticsTracker.LogFunnel(
				player,
				"PlotExpansion",
				4,
				"Used New Space"
			)


			return
		end
	end
end


--==================================================
-- REPUTATION
--==================================================

local function updateReputation(
	player: Player,
	snapshot: Snapshot,
	plot: Model
)

	local currentLevel =
		plot:GetAttribute(
			"ReputationLevel"
		)


	if typeof(currentLevel)
		~= "number" then

		return
	end


	currentLevel =
		math.max(
			1,
			math.floor(
				currentLevel
			)
		)


	if currentLevel
		<= snapshot.ReputationLevel then

		return
	end


	for level =
		snapshot.ReputationLevel + 1,
		currentLevel
	do

		AnalyticsTracker.LogProgression(
			player,
			"Reputation",
			level,
			`Reputation Level {level}`
		)
	end


	if snapshot.ReputationLevel
			< 2
		and currentLevel >= 2 then

		markEarlyStep(
			player,
			snapshot,
			4
		)
	end


	snapshot.ReputationLevel =
		currentLevel
end


--==================================================
-- BUSINESS UNLOCKS
--==================================================

local function updateBusinessUnlocks(
	player: Player,
	snapshot: Snapshot,
	profile: any
)

	local current =
		profile.UnlockedBusinesses


	if type(current)
		~= "table" then

		return
	end


	for businessType,
		unlocked in current
	do

		if unlocked ~= true
			or snapshot.UnlockedBusinesses[
				businessType
			] == true then

			continue
		end


		snapshot.UnlockedBusinesses[
			businessType
		] =
			true


		if businessType
			== "HotdogStand" then

			markEarlyStep(
				player,
				snapshot,
				5
			)


		else

			local config =
				BusinessConfig[
					businessType
				]


			if type(config)
					== "table"
				and typeof(
					config.DisplayOrder
				) == "number"
				and config.DisplayOrder
					>= 3 then

				markEarlyStep(
					player,
					snapshot,
					8
				)
			end
		end
	end
end


--==================================================
-- PLOT EXPANSION
--==================================================

local function updatePlotExpansion(
	player: Player,
	snapshot: Snapshot,
	profile: any
)

	local currentLevel =
		sanitizeNumber(
			profile.PlotLevel
		)


	local nextCost =
		getNextPlotCost(
			currentLevel
		)


	local eligible =
		nextCost ~= nil
			and getCash(
				player
			) >= nextCost


	if eligible
		and not snapshot.PlotEligible then

		AnalyticsTracker.LogFunnel(
			player,
			"PlotExpansion",
			1,
			"Became Eligible"
		)
	end


	snapshot.PlotEligible =
		eligible


	if currentLevel
		> snapshot.PlotLevel then

		AnalyticsTracker.LogFunnel(
			player,
			"PlotExpansion",
			3,
			"Purchased Expansion"
		)


		markEarlyStep(
			player,
			snapshot,
			7
		)


		snapshot.PlotLevel =
			currentLevel
	end
end


--==================================================
-- QUESTS
--==================================================

local function updateQuests(
	player: Player,
	snapshot: Snapshot,
	profile: any
)

	local quests =
		profile.Quests


	if type(quests)
		~= "table" then

		return
	end


	local completed =
		countTrueValues(
			quests.Completed
		)


	local claimed =
		countTrueValues(
			quests.Claimed
		)


	if completed
		> snapshot.QuestCompleted then

		AnalyticsTracker.LogFunnel(
			player,
			"QuestAchievement",
			2,
			"First Quest Completed"
		)


		if completed >= 2 then

			AnalyticsTracker.LogFunnel(
				player,
				"QuestAchievement",
				4,
				"Multiple Quests Completed"
			)
		end


		snapshot.QuestCompleted =
			completed
	end


	if claimed
		> snapshot.QuestClaimed then

		AnalyticsTracker.LogFunnel(
			player,
			"QuestAchievement",
			3,
			"First Reward Claimed"
		)


		snapshot.QuestClaimed =
			claimed
	end
end


--==================================================
-- ACHIEVEMENTS
--==================================================

local function updateAchievements(
	player: Player,
	snapshot: Snapshot,
	profile: any
)

	local achievements =
		profile.Achievements


	if type(achievements)
			~= "table"
		or type(
			achievements.Claimed
		) ~= "table" then

		return
	end


	local claimed =
		countTrueValues(
			achievements.Claimed
		)


	if claimed
		<= snapshot.AchievementClaimed then

		return
	end


	AnalyticsTracker.LogFunnel(
		player,
		"QuestAchievement",
		5,
		"Achievement Claimed"
	)


	snapshot.AchievementClaimed =
		claimed
end


--==================================================
-- DAILY REWARDS
--==================================================

local function updateDailyRewards(
	player: Player,
	snapshot: Snapshot
)

	local dailyData =
		DataService.GetDailyRewardData(
			player
		)


	if not dailyData then
		return
	end


	local nextClaimAt =
		sanitizeNumber(
			dailyData.NextClaimAt
		)


	local lastClaimDay =
		sanitizeNumber(
			dailyData.LastClaimRewardDay
		)


	--
	-- NextClaimAt changes after a successful claim,
	-- making it safer than simply watching LastClaimDay.
	--
	if nextClaimAt
			~= snapshot.DailyNextClaimAt
		and nextClaimAt > 0 then

		if lastClaimDay == 1 then

			AnalyticsTracker.LogFunnel(
				player,
				"DailyRewards",
				2,
				"Claimed Day 1"
			)


		elseif lastClaimDay == 2 then

			AnalyticsTracker.LogFunnel(
				player,
				"DailyRewards",
				3,
				"Returned for Day 2"
			)


		elseif lastClaimDay == 3 then

			AnalyticsTracker.LogFunnel(
				player,
				"DailyRewards",
				4,
				"Returned for Day 3"
			)


		elseif lastClaimDay == 7 then

			AnalyticsTracker.LogFunnel(
				player,
				"DailyRewards",
				5,
				"Returned for Day 7"
			)
		end
	end


	snapshot.DailyNextClaimAt =
		nextClaimAt


	snapshot.DailyLastClaimDay =
		lastClaimDay
end


--==================================================
-- RARE CUSTOMERS
--==================================================

local function updateRareCustomers(
	player: Player,
	snapshot: Snapshot
)

	local currentVisits =
		DataService.GetCustomerVisits(
			player
		)


	if type(currentVisits)
		~= "table" then

		return
	end


	for customerType,
		amount in currentVisits
	do

		local current =
			sanitizeNumber(
				amount
			)


		local previous =
			snapshot.CustomerVisits[
				customerType
			] or 0


		if current
			<= previous then

			continue
		end


		if customerType == "VIP" then

			AnalyticsTracker.LogFunnel(
				player,
				"RareCustomer",
				2,
				"First VIP Served"
			)


		elseif HIGHER_RARE_CUSTOMERS[
			customerType
		] == true then

			local vipVisits =
				sanitizeNumber(
					currentVisits.VIP
				)


			--
			-- Don't let Roblox auto-fill the VIP step
			-- simply because a Golden customer happened
			-- to spawn before the player's first VIP.
			--
			if vipVisits > 0 then

				AnalyticsTracker.LogFunnel(
					player,
					"RareCustomer",
					3,
					"Higher Tier Rare Customer Served"
				)


				AnalyticsTracker.LogFunnel(
					player,
					"RareCustomer",
					4,
					"Rare Customer Reward Received"
				)
			end
		end


		snapshot.CustomerVisits[
			customerType
		] =
			current
	end
end


--==================================================
-- TUTORIAL COMPLETION
--==================================================

local function updateTutorial(
	player: Player,
	snapshot: Snapshot
)

	local completed =
		DataService.GetTutorialCompleted(
			player
		)


	if completed
		and not snapshot.TutorialCompleted
		and snapshot.BoughtFirstUpgrade then

		AnalyticsTracker.LogOnboarding(
			player,
			AnalyticsTracker
				.Onboarding
				.TutorialCompleted,
			"Tutorial Completed"
		)
	end


	snapshot.TutorialCompleted =
		completed
end


--==================================================
-- PLAYER UPDATE
--==================================================

local function updatePlayer(
	player: Player
)

	local snapshot =
		snapshots[
			player
		]


	if not snapshot then
		return
	end


	local profile =
		DataService.GetProfile(
			player
		)


	if not profile then
		return
	end


	local plot =
		getPlayerPlot(
			player
		)


	if plot then

		updateBusinesses(
			player,
			snapshot,
			plot
		)


		updateReputation(
			player,
			snapshot,
			plot
		)


		checkExpandedSpaceUsed(
			player,
			snapshot,
			plot
		)
	end


	updateBusinessUnlocks(
		player,
		snapshot,
		profile
	)


	updatePlotExpansion(
		player,
		snapshot,
		profile
	)


	updateQuests(
		player,
		snapshot,
		profile
	)


	updateAchievements(
		player,
		snapshot,
		profile
	)


	updateDailyRewards(
		player,
		snapshot
	)


	updateRareCustomers(
		player,
		snapshot
	)


	updateTutorial(
		player,
		snapshot
	)


	flushEarlyProgression(
		player,
		snapshot
	)
end


--==================================================
-- PLAYER INITIALIZATION
--==================================================

local function initializePlayer(
	player: Player
)

	local profile =
		DataService.WaitForProfile(
			player,
			20
		)


	if not profile
		or not player.Parent then

		return
	end


	local snapshot =
		createSnapshot(
			player,
			profile
		)


	snapshots[
		player
	] =
		snapshot


	--
	-- Only players who haven't completed onboarding
	-- belong in the onboarding funnel.
	--
	if not snapshot.TutorialCompleted then

		AnalyticsTracker.LogOnboarding(
			player,
			AnalyticsTracker
				.Onboarding
				.JoinedGame,
			"Joined Game"
		)
	end
end


Players.PlayerAdded:Connect(
	function(
		player: Player
	)

		task.spawn(
			initializePlayer,
			player
		)
	end
)


for _, player in
	Players:GetPlayers()
do

	task.spawn(
		initializePlayer,
		player
	)
end


--==================================================
-- CLIENT EVENTS
--==================================================

local ALLOWED_CLIENT_EVENTS = {
	TutorialStarted = true,
	EnteredPlacementMode = true,

	OpenedManageStand = true,
	ViewedUpgrade = true,

	OpenedExpansionUI = true,

	FirstQuestViewed = true,

	OpenedDailyRewards = true,

	FirstRareCustomerSeen = true,

	ShopOpened = true,
	ProductViewed = true,
	PurchasePromptOpened = true,
}


analyticsEvent.OnServerEvent:Connect(
	function(
		player: Player,
		eventName: any,
		data: any
	)

		if typeof(eventName)
				~= "string"
			or ALLOWED_CLIENT_EVENTS[
				eventName
			] ~= true then

			return
		end


		if not AnalyticsTracker
			.CanAcceptClientEvent(
				player,
				eventName
			) then

			return
		end


		if type(data)
		~= "table" then

			data = {}
		end


		if eventName
			== "TutorialStarted" then

			if not DataService
				.GetTutorialCompleted(
					player
				) then

				AnalyticsTracker.LogOnboarding(
					player,
					AnalyticsTracker
						.Onboarding
						.TutorialStarted,
					"Tutorial Started"
				)
			end


			return
		end


		if eventName
			== "EnteredPlacementMode" then

			if not DataService
				.GetTutorialCompleted(
					player
				) then

				AnalyticsTracker.LogOnboarding(
					player,
					AnalyticsTracker
						.Onboarding
						.EnteredPlacementMode,
					"Entered Placement Mode"
				)
			end


			return
		end


		if eventName
			== "OpenedManageStand" then

			AnalyticsTracker.LogFunnel(
				player,
				"Upgrade",
				1,
				"Opened Manage Stand"
			)


			return
		end


		if eventName
			== "ViewedUpgrade" then

			AnalyticsTracker.LogFunnel(
				player,
				"Upgrade",
				2,
				"Viewed Upgrade"
			)


			return
		end


		if eventName
			== "OpenedExpansionUI" then

			AnalyticsTracker.LogFunnel(
				player,
				"PlotExpansion",
				2,
				"Opened Expansion UI"
			)


			return
		end


		if eventName
			== "FirstQuestViewed" then

			AnalyticsTracker.LogFunnel(
				player,
				"QuestAchievement",
				1,
				"First Quest Viewed"
			)


			return
		end


		if eventName
			== "OpenedDailyRewards" then

			AnalyticsTracker.LogFunnel(
				player,
				"DailyRewards",
				1,
				"Opened Daily Rewards"
			)


			return
		end


		if eventName
			== "FirstRareCustomerSeen" then

			local customerType =
				tostring(
					data.CustomerType
					or "Unknown"
				)


			if RARE_CUSTOMERS[
				customerType
			] ~= true then

				return
			end


			AnalyticsTracker.LogFunnel(
				player,
				"RareCustomer",
				1,
				"First Rare Customer Seen",

				AnalyticsTracker.MakeFields(
					customerType
				)
			)


			return
		end


		if eventName
			== "ShopOpened" then
		
			local sessionId =
				AnalyticsTracker.StartFunnelSession(
					player,
					"Monetization"
				)
		
		
			AnalyticsTracker.LogFunnel(
				player,
				"Monetization",
				1,
				"Shop Opened",
				nil,
				sessionId
			)
		
		
			return
		end


		if eventName
			== "ProductViewed" then
		
			local sessionId =
				AnalyticsTracker.GetActiveFunnelSession(
					player,
					"Monetization"
				)
		
			if not sessionId then
				return
			end
		
		
			AnalyticsTracker.LogFunnel(
				player,
				"Monetization",
				2,
				"Product Viewed",
		
				AnalyticsTracker.MakeFields(
					data.Product,
					data.ProductType
				),
		
				sessionId
			)
		
		
			return
		end


		if eventName
			== "PurchasePromptOpened" then
		
			local sessionId =
				AnalyticsTracker.GetActiveFunnelSession(
					player,
					"Monetization"
				)
		
			if not sessionId then
				return
			end
		
		
			AnalyticsTracker.LogFunnel(
				player,
				"Monetization",
				3,
				"Purchase Prompt Opened",
		
				AnalyticsTracker.MakeFields(
					data.Product,
					data.ProductType
				),
		
				sessionId
			)
		
		
			return
		end
	end
)


--==================================================
-- UPDATE LOOP
--==================================================

task.spawn(
	function()

		while true do

			task.wait(
				UPDATE_INTERVAL
			)


			for _, player in
				Players:GetPlayers()
			do

				updatePlayer(
					player
				)
			end
		end
	end
)


--==================================================
-- CLEANUP
--==================================================

Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		snapshots[
			player
		] = nil
	end
)


print(
	"AnalyticsManager started."
)