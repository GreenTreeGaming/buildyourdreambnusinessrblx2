local Players =
	game:GetService(
		"Players"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local Workspace =
	game:GetService(
		"Workspace"
	)

local HttpService =
	game:GetService(
		"HttpService"
	)


local DataService =
	require(
		script.Parent
			:WaitForChild(
				"Services"
			)
			:WaitForChild(
				"DataService"
			)
	)


local LicenseService =
	require(
		script.Parent
			:WaitForChild(
				"Services"
			)
			:WaitForChild(
				"LicenseService"
			)
	)


local LicenseConfig =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"LicenseConfig"
			)
	)


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"BusinessConfig"
			)
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


--==================================================
-- REMOTES
--==================================================

local function getOrCreateRemote(
	name: string,
	className: string
): Instance

	local existing =
		remotes:FindFirstChild(
			name
		)


	if existing then

		if existing.ClassName
			== className then

			return existing
		end


		existing:Destroy()
	end


	local remote =
		Instance.new(
			className
		)


	remote.Name =
		name


	remote.Parent =
		remotes


	return remote
end


local getLicenseStateRemote =
	getOrCreateRemote(
		"GetLicenseState",
		"RemoteFunction"
	) :: RemoteFunction


local purchaseLicenseUpgradeRemote =
	getOrCreateRemote(
		"PurchaseLicenseUpgrade",
		"RemoteFunction"
	) :: RemoteFunction


local licenseStateUpdatedRemote =
	getOrCreateRemote(
		"LicenseStateUpdated",
		"RemoteEvent"
	) :: RemoteEvent


--==================================================
-- STATE
--==================================================

local playerLocks: {
	[Player]: boolean
} = {}


local lastSerializedStates: {
	[Player]: string
} = {}


local UPDATE_INTERVAL =
	1


local UPGRADE_ATTRIBUTES = {
	ServingSpeed =
		"ServingSpeedLevel",

	SaleValue =
		"SaleValueLevel",

	QueueCapacity =
		"QueueCapacityLevel",
}


--==================================================
-- BASIC HELPERS
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
		math.floor(
			value
		)
	)
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

	local attribute =
		business:GetAttribute(
			"BusinessType"
		)


	if typeof(attribute)
			== "string"
		and attribute ~= "" then

		return attribute
	end


	for businessType in
		BusinessConfig do

		if business.Name
				== businessType
			or string.match(
				business.Name,
				`^{businessType}_`
			) then

			return businessType
		end
	end


	return business.Name
end


--==================================================
-- FULL BUSINESS CHECK
--==================================================

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


	local maximum =
		1


	for level in
		config.StandLevels do

		if typeof(level)
			== "number" then

			maximum =
				math.max(
					maximum,
					math.floor(
						level
					)
				)
		end
	end


	return maximum
end


local function getMaximumUpgradeLevel(
	businessType: string,
	upgradeName: string
): number

	local business =
		BusinessConfig[
			businessType
		]


	if type(business)
			~= "table"
		or type(business.Upgrades)
			~= "table" then

		return 0
	end


	local upgrade =
		business.Upgrades[
			upgradeName
		]


	if type(upgrade)
			~= "table"
		or type(upgrade.Levels)
			~= "table" then

		return 0
	end


	local maximum =
		0


	for _, levelInfo in
		upgrade.Levels do

		if type(levelInfo)
			== "table" then

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


	if type(config)
		~= "table" then

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


	if type(config.Upgrades)
		== "table" then

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


local function hasFullyUpgradedBusiness(
	player: Player,
	businessType: string
): boolean

	local plot =
		getPlayerPlot(
			player
		)


	if not plot then
		return false
	end


	local folder =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not folder then
		return false
	end


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


		if getBusinessType(
			business
		) ~= businessType then

			continue
		end


		if isBusinessFullyUpgraded(
			business
		) then

			return true
		end
	end


	return false
end


--==================================================
-- ACHIEVEMENTS
--==================================================

local function getClaimedAchievementCount(
	player: Player
): number

	local profile: any =
		DataService.GetProfile(
			player
		)


	if not profile
		or type(profile.Achievements)
			~= "table"
		or type(
			profile.Achievements.Claimed
		) ~= "table" then

		return 0
	end


	local count =
		0


	for _, claimed in
		profile.Achievements.Claimed do

		if claimed == true then
			count += 1
		end
	end


	return count
end


--==================================================
-- EARN PROGRESS
--==================================================

local function getEarnProgress(
	player: Player,
	definition: any
): number

	if definition.Type
		== "DailyStreak" then

		return LicenseService
			.GetDailyStreak(
				player
			)
	end


	if definition.Type
		== "Reputation" then

		local plot =
			getPlayerPlot(
				player
			)


		if not plot then
			return 0
		end


		return sanitizeNumber(
			plot:GetAttribute(
				"ReputationLevel"
			)
		)
	end


	if definition.Type
		== "FullyUpgradedBusiness" then

		return hasFullyUpgradedBusiness(
			player,
			definition.BusinessType
		)
			and 1
			or 0
	end


	if definition.Type
		== "ClaimedAchievementTiers" then

		return getClaimedAchievementCount(
			player
		)
	end


	if definition.Type
		== "LicenseFragments" then

		return LicenseService
			.GetFragments(
				player
			)
	end


	return 0
end


--==================================================
-- SAVE
--==================================================

local function requestSave(
	player: Player
)

	task.spawn(
		function()

			if player.Parent then
				DataService.SavePlayer(
					player
				)
			end
		end
	)
end


--==================================================
-- AUTOMATIC LICENSE REWARDS
--==================================================

local function processEarnRewards(
	player: Player
): boolean

	if playerLocks[
		player
	] then

		return false
	end


	playerLocks[
		player
	] = true


	local changed =
		false


	--==============================================
	-- REPEATABLE FRAGMENTS
	--==============================================

	local fragments =
		LicenseService.GetFragments(
			player
		)


	local fragmentsPerLicense =
		LicenseConfig
			.FragmentsPerLicense


	if fragments
		>= fragmentsPerLicense then

		local licenseCount =
			math.floor(
				fragments
					/ fragmentsPerLicense
			)


		local remaining =
			fragments
				% fragmentsPerLicense


		LicenseService.SetFragments(
			player,
			remaining
		)


		if licenseCount > 0 then

			DataService.AddLicenses(
				player,
				licenseCount
			)


			changed =
				true
		end
	end


	--==============================================
	-- ONE-TIME MILESTONES
	--==============================================

	for _, definition in
		LicenseConfig.EarnMethods do

		if definition.Repeatable
			== true then

			continue
		end


		local alreadyClaimed =
			LicenseService
				.HasClaimedEarnReward(
					player,
					definition.Id
				)


		if alreadyClaimed then
			continue
		end


		local progress =
			getEarnProgress(
				player,
				definition
			)


		local goal =
			sanitizeNumber(
				definition.Goal
			)


		if goal <= 0
			or progress < goal then

			continue
		end


		local marked =
			LicenseService
				.MarkEarnRewardClaimed(
					player,
					definition.Id
				)


		if not marked then
			continue
		end


		local reward =
			sanitizeNumber(
				definition.Reward
			)


		if reward > 0 then

			DataService.AddLicenses(
				player,
				reward
			)
		end


		changed =
			true
	end


	playerLocks[
		player
	] = nil


	if changed then

		requestSave(
			player
		)
	end


	return changed
end


--==================================================
-- UPGRADE MODIFIERS
--==================================================

local function applyUpgradeAttributes(
	player: Player
)

	for upgradeId, definition in
		LicenseConfig.Upgrades do

		local level =
			LicenseService
				.GetUpgradeLevel(
					player,
					upgradeId
				)


		local attributeName =
			definition.AttributeName


		if type(attributeName)
			~= "string" then

			continue
		end


		if typeof(
			definition.FlatPerLevel
		) == "number" then

			player:SetAttribute(
				attributeName,

				level
					* definition
						.FlatPerLevel
			)

		else

			local bonusPerLevel =
				definition.BonusPerLevel
				or 0


			player:SetAttribute(
				attributeName,

				1
					+ level
						* bonusPerLevel
			)
		end
	end
end


--==================================================
-- CLIENT STATE
--==================================================

local function buildState(
	player: Player
)

	local earnMethods =
		{}


	for _, definition in
		LicenseConfig.EarnMethods do

		local progress =
			getEarnProgress(
				player,
				definition
			)


		local goal =
			sanitizeNumber(
				definition.Goal
			)


		local claimed =
			false


		if definition.Repeatable
			~= true then

			claimed =
				LicenseService
					.HasClaimedEarnReward(
						player,
						definition.Id
					)
		end


		earnMethods[
			definition.Id
		] = {
			Progress =
				progress,

			Goal =
				goal,

			Claimed =
				claimed,

			Completed =
				claimed
				or (
					goal > 0
					and progress >= goal
				),
		}
	end


	local upgrades =
		{}


	for upgradeId, definition in
		LicenseConfig.Upgrades do

		local level =
			LicenseService
				.GetUpgradeLevel(
					player,
					upgradeId
				)


		local maxLevel =
			LicenseConfig
				.GetMaximumLevel(
					upgradeId
				)


		local nextCost =
			LicenseConfig
				.GetNextCost(
					upgradeId,
					level
				)


		upgrades[
			upgradeId
		] = {
			Level =
				level,

			MaxLevel =
				maxLevel,

			Maxed =
				level >= maxLevel,

			NextCost =
				nextCost
				or 0,
		}
	end


	return {
		Licenses =
			DataService.GetLicenses(
				player
			),

		Fragments =
			LicenseService.GetFragments(
				player
			),

		EarnMethods =
			earnMethods,

		Upgrades =
			upgrades,
	}
end


local function pushStateIfChanged(
	player: Player,
	force: boolean?
)

	if not player.Parent
		or not DataService.GetProfile(
			player
		) then

		return
	end


	processEarnRewards(
		player
	)


	applyUpgradeAttributes(
		player
	)


	local state =
		buildState(
			player
		)


	local success,
		serialized =
		pcall(
			function()

				return HttpService
					:JSONEncode(
						state
					)
			end
		)


	if not success then
		return
	end


	if force
		or lastSerializedStates[
			player
		] ~= serialized then

		lastSerializedStates[
			player
		] = serialized


		licenseStateUpdatedRemote
			:FireClient(
				player,
				state
			)
	end
end


--==================================================
-- GET STATE
--==================================================

getLicenseStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		processEarnRewards(
			player
		)


		applyUpgradeAttributes(
			player
		)


		return buildState(
			player
		)
	end


--==================================================
-- PURCHASE UPGRADE
--==================================================

purchaseLicenseUpgradeRemote.OnServerInvoke =
	function(
		player: Player,
		upgradeId: any
	)

		if type(upgradeId)
			~= "string" then

			return false,
				"Invalid upgrade."
		end


		if playerLocks[
			player
		] then

			return false,
				"Please wait."
		end


		local definition =
			LicenseConfig.GetUpgrade(
				upgradeId
			)


		if not definition then

			return false,
				"That upgrade does not exist."
		end


		playerLocks[
			player
		] = true


		local currentLevel =
			LicenseService
				.GetUpgradeLevel(
					player,
					upgradeId
				)


		local maximumLevel =
			LicenseConfig
				.GetMaximumLevel(
					upgradeId
				)


		if currentLevel
			>= maximumLevel then

			playerLocks[
				player
			] = nil


			return false,
				"That upgrade is already maxed."
		end


		local cost =
			LicenseConfig
				.GetNextCost(
					upgradeId,
					currentLevel
				)


		if not cost
			or cost <= 0 then

			playerLocks[
				player
			] = nil


			return false,
				"Invalid upgrade cost."
		end


		local spent =
			DataService.SpendLicenses(
				player,
				cost
			)


		if not spent then

			playerLocks[
				player
			] = nil


			return false,
				"Not enough Licenses."
		end


		local saved =
			LicenseService.SetUpgradeLevel(
				player,
				upgradeId,
				currentLevel + 1
			)


		if not saved then

			DataService.AddLicenses(
				player,
				cost
			)


			playerLocks[
				player
			] = nil


			return false,
				"Could not purchase upgrade."
		end


		playerLocks[
			player
		] = nil


		applyUpgradeAttributes(
			player
		)


		requestSave(
			player
		)


		local state =
			buildState(
				player
			)


		licenseStateUpdatedRemote
			:FireClient(
				player,
				state
			)


		return true,
			"Purchased!",
			state
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


	if not profile then
		return
	end


	LicenseService.InitializePlayer(
		player
	)


	processEarnRewards(
		player
	)


	applyUpgradeAttributes(
		player
	)


	pushStateIfChanged(
		player,
		true
	)


	player:GetAttributeChangedSignal(
		"Licenses"
	):Connect(
		function()

			pushStateIfChanged(
				player,
				true
			)
		end
	)
end


for _, player in
	Players:GetPlayers()
do

	task.spawn(
		initializePlayer,
		player
	)
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


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)

		lastSerializedStates[
			player
		] = nil


		playerLocks[
			player
		] = nil
	end
)


--==================================================
-- PROGRESS WATCH
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

				pushStateIfChanged(
					player
				)
			end
		end
	end
)