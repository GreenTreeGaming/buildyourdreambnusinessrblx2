local DataService =
	require(
		script.Parent
			:WaitForChild(
				"DataService"
			)
	)


local LicenseService = {}


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
		math.floor(
			value
		)
	)
end


local function getStorage(
	player: Player
): any?

	local profile: any =
		DataService.GetProfile(
			player
		)


	if not profile then
		return nil
	end


	if type(profile.LicenseSystem)
		~= "table" then

		profile.LicenseSystem = {}
	end


	local storage =
		profile.LicenseSystem


	if type(storage.ClaimedEarnRewards)
		~= "table" then

		storage.ClaimedEarnRewards = {}
	end


	if type(storage.UpgradeLevels)
		~= "table" then

		storage.UpgradeLevels = {}
	end


	storage.DailyStreak =
		sanitizeNumber(
			storage.DailyStreak
		)


	storage.Fragments =
		sanitizeNumber(
			storage.Fragments
		)


	return storage
end


--==================================================
-- DAILY STREAK
--==================================================

function LicenseService.GetDailyStreak(
	player: Player
): number

	local storage =
		getStorage(
			player
		)


	if not storage then
		return 0
	end


	return sanitizeNumber(
		storage.DailyStreak
	)
end


function LicenseService.SetDailyStreak(
	player: Player,
	amount: number
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	storage.DailyStreak =
		sanitizeNumber(
			amount
		)


	return true
end


--==================================================
-- FRAGMENTS
--==================================================

function LicenseService.GetFragments(
	player: Player
): number

	local storage =
		getStorage(
			player
		)


	if not storage then
		return 0
	end


	return sanitizeNumber(
		storage.Fragments
	)
end


function LicenseService.SetFragments(
	player: Player,
	amount: number
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	storage.Fragments =
		sanitizeNumber(
			amount
		)


	player:SetAttribute(
		"LicenseFragments",
		storage.Fragments
	)


	return true
end


function LicenseService.AddFragments(
	player: Player,
	amount: number
): number

	local storage =
		getStorage(
			player
		)


	if not storage then
		return 0
	end


	amount =
		sanitizeNumber(
			amount
		)


	if amount <= 0 then
		return storage.Fragments
	end


	storage.Fragments +=
		amount


	player:SetAttribute(
		"LicenseFragments",
		storage.Fragments
	)


	return storage.Fragments
end


--==================================================
-- EARN REWARDS
--==================================================

function LicenseService.HasClaimedEarnReward(
	player: Player,
	rewardId: string
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	return storage.ClaimedEarnRewards[
		rewardId
	] == true
end


function LicenseService.MarkEarnRewardClaimed(
	player: Player,
	rewardId: string
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	if type(rewardId) ~= "string"
		or rewardId == "" then

		return false
	end


	if storage.ClaimedEarnRewards[
		rewardId
	] == true then

		return false
	end


	storage.ClaimedEarnRewards[
		rewardId
	] = true


	return true
end


--==================================================
-- UPGRADE LEVELS
--==================================================

function LicenseService.GetUpgradeLevel(
	player: Player,
	upgradeId: string
): number

	local storage =
		getStorage(
			player
		)


	if not storage then
		return 0
	end


	return sanitizeNumber(
		storage.UpgradeLevels[
			upgradeId
		]
	)
end


function LicenseService.SetUpgradeLevel(
	player: Player,
	upgradeId: string,
	level: number
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	if type(upgradeId) ~= "string"
		or upgradeId == "" then

		return false
	end


	storage.UpgradeLevels[
		upgradeId
	] = sanitizeNumber(
		level
	)


	return true
end


--==================================================
-- INITIALIZE
--==================================================

function LicenseService.InitializePlayer(
	player: Player
): boolean

	local storage =
		getStorage(
			player
		)


	if not storage then
		return false
	end


	player:SetAttribute(
		"LicenseFragments",
		storage.Fragments
	)


	return true
end


return LicenseService