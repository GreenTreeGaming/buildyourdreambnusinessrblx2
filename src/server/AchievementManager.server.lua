local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local HttpService =
	game:GetService("HttpService")

local Workspace =
	game:GetService("Workspace")


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local AchievementConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("AchievementConfig")
	)


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--==================================================
-- REMOTES
--==================================================

local function getOrCreateRemote(
	name: string,
	className: string
): Instance

	local existing =
		remotes:FindFirstChild(name)

	if existing then
		if existing.ClassName == className then
			return existing
		end

		existing:Destroy()
	end


	local remote =
		Instance.new(className)

	remote.Name = name
	remote.Parent = remotes

	return remote
end


local getAchievementState =
	getOrCreateRemote(
		"GetAchievementState",
		"RemoteFunction"
	) :: RemoteFunction


local claimAchievement =
	getOrCreateRemote(
		"ClaimAchievement",
		"RemoteFunction"
	) :: RemoteFunction


local achievementStateUpdated =
	getOrCreateRemote(
		"AchievementStateUpdated",
		"RemoteEvent"
	) :: RemoteEvent


--==================================================
-- STATE
--==================================================

local UPDATE_INTERVAL = 1


local lastSerializedStates: {
	[Player]: string
} = {}


local claimLocks: {
	[Player]: boolean
} = {}


--==================================================
-- HELPERS
--==================================================

local function sanitizeNumber(
	value: any
): number

	if typeof(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end


	return math.max(
		0,
		math.floor(value)
	)
end


local function getPlayerPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName) == "string" then
		local plots =
			Workspace:FindFirstChild(
				"Plots"
			)

		if plots then
			local plot =
				plots:FindFirstChild(
					plotName
				)

			if plot
				and plot:IsA("Model")
				and plot:GetAttribute(
					"OwnerUserId"
				) == player.UserId then

				return plot
			end
		end
	end


	local plots =
		Workspace:FindFirstChild(
			"Plots"
		)

	if not plots then
		return nil
	end


	for _, plot in
		plots:GetChildren() do

		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getOwnedBusinesses(
	player: Player
): {Model}

	local result = {}


	local plot =
		getPlayerPlot(player)

	if not plot then
		return result
	end


	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not folder then
		return result
	end


	for _, instance in
		folder:GetChildren() do

		if not instance:IsA("Model") then
			continue
		end


		if instance:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		table.insert(
			result,
			instance
		)
	end


	return result
end


local function getBusinessType(
	business: Model
): string

	local attribute =
		business:GetAttribute(
			"BusinessType"
		)


	if typeof(attribute) == "string"
		and attribute ~= "" then

		return attribute
	end


	for businessType in
		BusinessConfig do

		if business.Name == businessType
			or string.match(
				business.Name,
				`^{businessType}_`
			) then

			return businessType
		end
	end


	return business.Name
end


local function getAchievementStorage(
	player: Player
): any?

	local profile: any =
		DataService.GetProfile(
			player
		)

	if not profile then
		return nil
	end


	if type(profile.Achievements)
		~= "table" then

		profile.Achievements = {}
	end


	local achievements =
		profile.Achievements


	if type(achievements.Claimed)
		~= "table" then

		achievements.Claimed = {}
	end


	if type(achievements.MetricHighs)
		~= "table" then

		achievements.MetricHighs = {}
	end


	return achievements
end


local function getClaimKey(
	achievementId: string,
	tier: number
): string

	return `{achievementId}:{tier}`
end


local function isClaimed(
	player: Player,
	achievementId: string,
	tier: number
): boolean

	local storage =
		getAchievementStorage(
			player
		)

	if not storage then
		return false
	end


	return storage.Claimed[
		getClaimKey(
			achievementId,
			tier
		)
	] == true
end


local function setClaimed(
	player: Player,
	achievementId: string,
	tier: number
)

	local storage =
		getAchievementStorage(
			player
		)

	if not storage then
		return
	end


	storage.Claimed[
		getClaimKey(
			achievementId,
			tier
		)
	] = true
end


local function getTotalCustomers(
	player: Player
): number

	local visits =
		DataService.GetCustomerVisits(
			player
		)


	local total = 0


	for _, amount in visits do
		total +=
			sanitizeNumber(
				amount
			)
	end


	return total
end


local function getCustomerTypesDiscovered(
	player: Player
): number

	local visits =
		DataService.GetCustomerVisits(
			player
		)


	local discovered = 0


	for _, amount in visits do
		if sanitizeNumber(amount) > 0 then
			discovered += 1
		end
	end


	return discovered
end


local function getOwnedBusinessCount(
	player: Player,
	businessType: string
): number

	local count = 0


	for _, business in
		getOwnedBusinesses(player) do

		if getBusinessType(
			business
		) == businessType then

			count += 1
		end
	end


	return count
end


local function getHighestBusinessLevel(
	player: Player,
	businessType: string
): number

	local highest = 0


	for _, business in
		getOwnedBusinesses(player) do

		if getBusinessType(
			business
		) ~= businessType then

			continue
		end


		local level =
			sanitizeNumber(
				business:GetAttribute(
					"Level"
				)
			)


		highest =
			math.max(
				highest,
				level
			)
	end


	return highest
end


local function getMaximumStandLevel(
	businessType: string
): number

	local config =
		BusinessConfig[
			businessType
		]

	if type(config) ~= "table"
		or type(config.StandLevels)
			~= "table" then

		return 1
	end


	local maximum = 1


	for level in config.StandLevels do

		if typeof(level) == "number" then
			maximum =
				math.max(
					maximum,
					level
				)
		end
	end


	return maximum
end


local UPGRADE_ATTRIBUTES = {
	ServingSpeed =
		"ServingSpeedLevel",

	SaleValue =
		"SaleValueLevel",

	QueueCapacity =
		"QueueCapacityLevel",
}


local function getMaximumUpgradeLevel(
	businessType: string,
	upgradeName: string
): number

	local business =
		BusinessConfig[
			businessType
		]

	if type(business) ~= "table"
		or type(business.Upgrades)
			~= "table" then

		return 0
	end


	local upgrade =
		business.Upgrades[
			upgradeName
		]

	if type(upgrade) ~= "table"
		or type(upgrade.Levels)
			~= "table" then

		return 0
	end


	local maximum = 0


	for _, levelInfo in
		upgrade.Levels do

		if type(levelInfo) == "table" then
			maximum =
				math.max(
					maximum,
					sanitizeNumber(
						levelInfo.Level
					)
				)
		end
	end


	return maximum
end


local function isBusinessFullyUpgraded(
	business: Model
): boolean

	local businessType =
		getBusinessType(
			business
		)


	local config =
		BusinessConfig[
			businessType
		]

	if type(config) ~= "table" then
		return false
	end


	local currentStandLevel =
		sanitizeNumber(
			business:GetAttribute(
				"Level"
			)
		)


	if currentStandLevel
		< getMaximumStandLevel(
			businessType
		) then

		return false
	end


	if type(config.Upgrades) == "table" then

		for upgradeName in
			config.Upgrades do

			local attributeName =
				UPGRADE_ATTRIBUTES[
					upgradeName
				]

			if not attributeName then
				continue
			end


			local currentLevel =
				sanitizeNumber(
					business:GetAttribute(
						attributeName
					)
				)


			local maximumLevel =
				getMaximumUpgradeLevel(
					businessType,
					upgradeName
				)


			if currentLevel
				< maximumLevel then

				return false
			end
		end
	end


	return true
end


local function getFullyUpgradedBusinessCount(
	player: Player
): number

	local count = 0


	for _, business in
		getOwnedBusinesses(player) do

		if isBusinessFullyUpgraded(
			business
		) then

			count += 1
		end
	end


	return count
end


local function calculateCurrentLifetimeEarnings(
	player: Player
): number

	local businesses =
		getOwnedBusinesses(
			player
		)


	local total = 0


	if #businesses > 0 then

		for _, business in businesses do

			total +=
				sanitizeNumber(
					business:GetAttribute(
						"LifetimeEarnings"
					)
				)
		end

		return total
	end


	-- Fallback for the short period before
	-- the player's plot finishes restoring.

	local profile: any =
		DataService.GetProfile(
			player
		)

	if not profile
		or type(profile.PlacedBusinesses)
			~= "table" then

		return 0
	end


	for _, business in
		profile.PlacedBusinesses do

		if type(business) == "table" then

			total +=
				sanitizeNumber(
					business.LifetimeEarnings
				)
		end
	end


	return total
end


local function getLifetimeEarnings(
	player: Player
): number

	local current =
		calculateCurrentLifetimeEarnings(
			player
		)


	local storage =
		getAchievementStorage(
			player
		)

	if not storage then
		return current
	end


	local previousHigh =
		sanitizeNumber(
			storage.MetricHighs
				.LifetimeEarnings
		)


	local highest =
		math.max(
			current,
			previousHigh
		)


	storage.MetricHighs
		.LifetimeEarnings =
		highest


	return highest
end


local function getMetricValue(
	player: Player,
	metric: any
): number

	if type(metric) ~= "table" then
		return 0
	end


	local metricType =
		metric.Type


	if metricType ==
		"TotalCustomers" then

		return getTotalCustomers(
			player
		)
	end


	if metricType ==
		"CustomerTypesDiscovered" then

		return getCustomerTypesDiscovered(
			player
		)
	end


	if metricType ==
		"CustomerTypeVisits" then

		return DataService
			.GetCustomerVisitCount(
				player,
				metric.CustomerType
			)
	end


	if metricType ==
		"OwnedBusinessCount" then

		return getOwnedBusinessCount(
			player,
			metric.BusinessType
		)
	end


	if metricType ==
		"BusinessLevel" then

		return getHighestBusinessLevel(
			player,
			metric.BusinessType
		)
	end


	if metricType ==
		"BusinessUnlocked" then

		return DataService
			.IsBusinessUnlocked(
				player,
				metric.BusinessType
			)
			and 1
			or 0
	end


	if metricType ==
		"FullyUpgradedBusinesses" then

		return getFullyUpgradedBusinessCount(
			player
		)
	end


	if metricType ==
		"LifetimeEarnings" then

		return getLifetimeEarnings(
			player
		)
	end


	warn(
		`[Achievements] Unknown metric type: {tostring(metricType)}`
	)


	return 0
end


local function findAchievement(
	achievementId: string
): any?

	for _, achievement in
		AchievementConfig.Achievements do

		if achievement.Id ==
			achievementId then

			return achievement
		end
	end


	return nil
end


local function countTotalTiers(): number

	local total = 0


	for _, achievement in
		AchievementConfig.Achievements do

		total +=
			#achievement.Tiers
	end


	return total
end


local TOTAL_TIERS =
	countTotalTiers()


local function countClaimedTiers(
	player: Player
): number

	local count = 0


	for _, achievement in
		AchievementConfig.Achievements do

		for tierIndex = 1,
			#achievement.Tiers do

			if isClaimed(
				player,
				achievement.Id,
				tierIndex
			) then

				count += 1
			end
		end
	end


	return count
end


local function getCurrentTierIndex(
	player: Player,
	achievement: any
): (number, boolean)

	for tierIndex = 1,
		#achievement.Tiers do

		if not isClaimed(
			player,
			achievement.Id,
			tierIndex
		) then

			return tierIndex, false
		end
	end


	return #achievement.Tiers, true
end


local function buildAchievementEntry(
	player: Player,
	achievement: any
): any

	local tierIndex, maxed =
		getCurrentTierIndex(
			player,
			achievement
		)


	local tier =
		achievement.Tiers[
			tierIndex
		]


	local progress =
		getMetricValue(
			player,
			achievement.Metric
		)


	local goal =
		sanitizeNumber(
			tier.Goal
		)


	local claimable =
		not maxed
		and progress >= goal


	local nextTier = nil


	if tierIndex <
		#achievement.Tiers then

		local nextTierInfo =
			achievement.Tiers[
				tierIndex + 1
			]


		nextTier = {
			Tier =
				tierIndex + 1,

			Description =
				nextTierInfo.Description,

			Goal =
				nextTierInfo.Goal,

			Reward =
				nextTierInfo.Reward,
		}
	end


	return {
		Id =
			achievement.Id,

		DisplayName =
			achievement.DisplayName,

		Category =
			achievement.Category,

		Order =
			achievement.Order
			or 0,

		Tier =
			tierIndex,

		Description =
			tier.Description,

		Progress =
			progress,

		Goal =
			goal,

		Reward =
			sanitizeNumber(
				tier.Reward
			),

		Claimable =
			claimable,

		Maxed =
			maxed,

		NextTier =
			nextTier,
	}
end


local function buildState(
	player: Player
): any

	local claimed =
		countClaimedTiers(
			player
		)


	local percent = 0


	if TOTAL_TIERS > 0 then

		percent =
			math.clamp(
				claimed
					/ TOTAL_TIERS,
				0,
				1
			)
	end


	local entries = {}


	for _, achievement in
		AchievementConfig.Achievements do

		table.insert(
			entries,
			buildAchievementEntry(
				player,
				achievement
			)
		)
	end


	table.sort(
		entries,

		function(
			first,
			second
		)

			if first.Order ==
				second.Order then

				return first.Id
					< second.Id
			end


			return first.Order
				< second.Order
		end
	)


	local claimableCount = 0


	for _, entry in entries do

		if entry.Claimable then
			claimableCount += 1
		end
	end


	return {
		Completed =
			claimed,

		Total =
			TOTAL_TIERS,

		Percent =
			percent,

		ClaimableCount =
			claimableCount,

		Achievements =
			entries,
	}
end


local function pushStateIfChanged(
	player: Player
)

	if not player.Parent then
		return
	end


	local profile =
		DataService.GetProfile(
			player
		)

	if not profile then
		return
	end


	local state =
		buildState(
			player
		)


	local success, serialized =
		pcall(
			HttpService.JSONEncode,
			HttpService,
			state
		)


	if not success then
		return
	end


	if lastSerializedStates[player]
		== serialized then

		return
	end


	lastSerializedStates[player] =
		serialized


	achievementStateUpdated:FireClient(
		player,
		state
	)
end


--==================================================
-- REMOTE HANDLERS
--==================================================

getAchievementState.OnServerInvoke =
	function(
		player: Player
	)

		local profile =
			DataService.WaitForProfile(
				player,
				10
			)

		if not profile then
			return nil
		end


		return buildState(
			player
		)
	end


claimAchievement.OnServerInvoke =
	function(
		player: Player,
		achievementId: string
	)

		if typeof(achievementId)
			~= "string"
			or achievementId == "" then

			return {
				Success = false,
				Message =
					"Invalid achievement.",
			}
		end


		if claimLocks[player] then

			return {
				Success = false,
				Message =
					"Please wait.",
			}
		end


		claimLocks[player] = true


		local function finish(
			result: any
		): any

			claimLocks[player] = nil

			return result
		end


		local profile =
			DataService.GetProfile(
				player
			)

		if not profile then

			return finish({
				Success = false,

				Message =
					"Your data is not ready yet.",
			})
		end


		local achievement =
			findAchievement(
				achievementId
			)

		if not achievement then

			return finish({
				Success = false,

				Message =
					"Achievement not found.",
			})
		end


		local tierIndex, maxed =
			getCurrentTierIndex(
				player,
				achievement
			)


		if maxed then

			return finish({
				Success = false,

				Message =
					"This achievement is already complete.",
			})
		end


		local tier =
			achievement.Tiers[
				tierIndex
			]


		local progress =
			getMetricValue(
				player,
				achievement.Metric
			)


		local goal =
			sanitizeNumber(
				tier.Goal
			)


		if progress < goal then

			return finish({
				Success = false,

				Message =
					"This milestone is not complete yet.",
			})
		end


		if isClaimed(
			player,
			achievement.Id,
			tierIndex
		) then

			return finish({
				Success = false,

				Message =
					"This reward was already claimed.",
			})
		end


		local reward =
			sanitizeNumber(
				tier.Reward
			)


		if reward <= 0 then

			return finish({
				Success = false,

				Message =
					"This achievement has an invalid reward.",
			})
		end


		local addedCash =
			DataService.AddCash(
				player,
				reward
			)


		if not addedCash then

			return finish({
				Success = false,

				Message =
					"The reward could not be added.",
			})
		end


		setClaimed(
			player,
			achievement.Id,
			tierIndex
		)


		lastSerializedStates[player] =
			nil


		local newState =
			buildState(
				player
			)


		achievementStateUpdated:FireClient(
			player,
			newState
		)


		return finish({
			Success = true,

			Reward =
				reward,

			AchievementName =
				achievement.DisplayName,

			Tier =
				tierIndex,

			State =
				newState,
		})
	end


--==================================================
-- LIVE UPDATE LOOP
--==================================================

task.spawn(
	function()

		while true do

			for _, player in
				Players:GetPlayers() do

				pushStateIfChanged(
					player
				)
			end


			task.wait(
				UPDATE_INTERVAL
			)
		end
	end
)


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		lastSerializedStates[player] =
			nil

		claimLocks[player] =
			nil
	end
)