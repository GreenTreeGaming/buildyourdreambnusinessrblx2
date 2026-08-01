local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DATA_STORE_NAME = "PlayerData_v1"
local CURRENT_DATA_VERSION = 1

local MAX_RETRIES = 3
local RETRY_DELAY_SECONDS = 2

local DEFAULT_PROFILE = {
	Version = CURRENT_DATA_VERSION,

	Cash = 0,

	Businesses = {
		LemonadeStand = {
			Owned = false,
			Transform = nil,
		},
	},

	Upgrades = {
		LemonadeStand = {
			ServingSpeed = 0,
			SaleValue = 0,
			QueueCapacity = 0,
		},
	},

	UnlockedBusinesses = {
		LemonadeStand = true,
	},
}

type SerializedCFrame = {
	number
}

type SavedBusiness = {
	Owned: boolean,
	Transform: SerializedCFrame?,
}

type UpgradeLevels = {
	[string]: number,
}

type PlayerProfile = {
	Version: number,
	Cash: number,

	Businesses: {
		[string]: SavedBusiness,
	},

	Upgrades: {
		[string]: UpgradeLevels,
	},

	UnlockedBusinesses: {
		[string]: boolean,
	},
}

local playerDataStore =
	DataStoreService:GetDataStore(DATA_STORE_NAME)

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local profiles: {[Player]: PlayerProfile} = {}
local loadingPlayers: {[Player]: boolean} = {}
local savingPlayers: {[Player]: boolean} = {}

local DataService = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local copiedTable = {}

	for key, childValue in value do
		copiedTable[deepCopy(key)] = deepCopy(childValue)
	end

	return copiedTable :: any
end

local function reconcileTable(
	loaded: {[any]: any},
	template: {[any]: any}
)
	for key, defaultValue in template do
		local loadedValue = loaded[key]

		if loadedValue == nil then
			loaded[key] = deepCopy(defaultValue)
			continue
		end

		if type(defaultValue) == "table" then
			if type(loadedValue) ~= "table" then
				loaded[key] = deepCopy(defaultValue)
			else
				reconcileTable(loadedValue, defaultValue)
			end
		end
	end
end

local function migrateProfile(rawData: any): PlayerProfile
	if type(rawData) ~= "table" then
		return deepCopy(DEFAULT_PROFILE)
	end

	local profile = deepCopy(rawData)

	local loadedVersion = profile.Version

	if type(loadedVersion) ~= "number" then
		loadedVersion = 0
	end

	-- Future migrations go here.
	--
	-- Example:
	-- if loadedVersion < 2 then
	--     profile.NewField = "DefaultValue"
	--     loadedVersion = 2
	-- end

	profile.Version = CURRENT_DATA_VERSION

	reconcileTable(profile, DEFAULT_PROFILE)

	if type(profile.Cash) ~= "number" then
		profile.Cash = DEFAULT_PROFILE.Cash
	end

	profile.Cash = math.max(
		0,
		math.floor(profile.Cash)
	)

	return profile :: PlayerProfile
end

local function serializeCFrame(cframe: CFrame): SerializedCFrame
	return {
		cframe:GetComponents(),
	}
end

local function deserializeCFrame(
	components: any
): CFrame?
	if type(components) ~= "table"
		or #components ~= 12 then

		return nil
	end

	local validatedComponents = {}

	for index = 1, 12 do
		local component = components[index]

		if type(component) ~= "number"
			or component ~= component
			or component == math.huge
			or component == -math.huge then

			return nil
		end

		validatedComponents[index] = component
	end

	return CFrame.new(table.unpack(validatedComponents))
end

local function getPlayerKey(player: Player): string
	return `Player_{player.UserId}`
end

local function getPlayerPlot(player: Player): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot = plotsFolder:FindFirstChild(plotName)

		if plot
			and plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end

local function getCashValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash = leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function createLeaderstats(
	player: Player,
	startingCash: number
)
	local existingLeaderstats =
		player:FindFirstChild("leaderstats")

	if existingLeaderstats then
		existingLeaderstats:Destroy()
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.max(
		0,
		math.floor(startingCash)
	)
	cash.Parent = leaderstats
end

local function captureBusinessState(
	player: Player,
	profile: PlayerProfile
)
	local plot = getPlayerPlot(player)

	if not plot then
		return
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses then
		return
	end

	local lemonadeStand =
		placedBusinesses:FindFirstChild("LemonadeStand")

	local savedStand =
		profile.Businesses.LemonadeStand

	if lemonadeStand
		and lemonadeStand:IsA("Model") then

		savedStand.Owned = true
		savedStand.Transform =
			serializeCFrame(lemonadeStand:GetPivot())
	else
		savedStand.Owned = false
		savedStand.Transform = nil
	end
end

local function createSaveSnapshot(
	player: Player
): PlayerProfile?
	local currentProfile = profiles[player]

	if not currentProfile then
		return nil
	end

	local snapshot =
		deepCopy(currentProfile)

	local cash = getCashValue(player)

	if cash then
		snapshot.Cash = math.max(
			0,
			math.floor(cash.Value)
		)
	end

	captureBusinessState(player, snapshot)

	snapshot.Version = CURRENT_DATA_VERSION

	return snapshot
end

local function runWithRetries(
	callback: () -> any
): (boolean, any)
	local lastError

	for attempt = 1, MAX_RETRIES do
		local success, result =
			pcall(callback)

		if success then
			return true, result
		end

		lastError = result

		if attempt < MAX_RETRIES then
			task.wait(
				RETRY_DELAY_SECONDS * attempt
			)
		end
	end

	return false, lastError
end

function DataService.LoadPlayer(
	player: Player
): boolean
	if profiles[player] then
		return true
	end

	if loadingPlayers[player] then
		while loadingPlayers[player]
			and player.Parent do

			task.wait()
		end

		return profiles[player] ~= nil
	end

	loadingPlayers[player] = true

	local success, result = runWithRetries(function()
		return playerDataStore:GetAsync(
			getPlayerKey(player)
		)
	end)

	if not player.Parent then
		loadingPlayers[player] = nil
		return false
	end

	local profile

	if success then
		profile = migrateProfile(result)
	else
		warn(
			`Failed to load data for {player.Name}: {result}`
		)

		loadingPlayers[player] = nil

		player:Kick(
			"Your data could not be loaded. Please rejoin."
		)

		return false
	end

	profiles[player] = profile
	loadingPlayers[player] = nil

	createLeaderstats(player, profile.Cash)

	player:SetAttribute("DataLoaded", true)

	return true
end

function DataService.WaitForProfile(
	player: Player,
	timeout: number?
): PlayerProfile?
	local startedAt = time()
	local maximumWait = timeout or 15

	while player.Parent do
		local profile = profiles[player]

		if profile then
			return profile
		end

		if time() - startedAt >= maximumWait then
			return nil
		end

		task.wait()
	end

	return nil
end

function DataService.GetProfile(
	player: Player
): PlayerProfile?
	return profiles[player]
end

function DataService.SavePlayer(
	player: Player
): boolean
	if savingPlayers[player] then
		return false
	end

	local snapshot =
		createSaveSnapshot(player)

	if not snapshot then
		return false
	end

	savingPlayers[player] = true

	local success, result = runWithRetries(function()
		return playerDataStore:UpdateAsync(
			getPlayerKey(player),
			function(_oldData)
				return snapshot
			end
		)
	end)

	savingPlayers[player] = nil

	if not success then
		warn(
			`Failed to save data for {player.Name}: {result}`
		)

		return false
	end

	if profiles[player] then
		profiles[player] = snapshot
	end

	return true
end

function DataService.RestorePlot(
	player: Player,
	plot: Model
): boolean
	local profile =
		DataService.WaitForProfile(player, 15)

	if not profile then
		warn(
			`Could not restore {player.Name}'s plot because their profile was not loaded.`
		)

		return false
	end

	if plot:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if not placedBusinesses
		or not placedBusinesses:IsA("Folder") then

		warn(
			`Plot "{plot.Name}" is missing PlacedBusinesses.`
		)

		return false
	end

	local savedStand =
		profile.Businesses.LemonadeStand

	if not savedStand.Owned then
		plot:SetAttribute(
			"StarterBusinessPlaced",
			false
		)

		return true
	end

	local savedCFrame =
		deserializeCFrame(savedStand.Transform)

	if not savedCFrame then
		warn(
			`The saved LemonadeStand transform for {player.Name} was invalid.`
		)

		savedStand.Owned = false
		savedStand.Transform = nil

		return false
	end

	local template =
		businessModels:FindFirstChild(
			"LemonadeStand"
		)

	if not template or not template:IsA("Model") then
		warn(
			"ReplicatedStorage.BusinessModels.LemonadeStand was not found."
		)

		return false
	end

	if placedBusinesses:FindFirstChild(
		"LemonadeStand"
	) then

		return true
	end

	local stand = template:Clone()
	stand.Name = "LemonadeStand"

	stand:SetAttribute(
		"OwnerUserId",
		player.UserId
	)

	stand:SetAttribute(
		"PlotName",
		plot.Name
	)

	stand:SetAttribute(
		"StandUnavailable",
		false
	)

	stand:SetAttribute(
		"IsBeingEdited",
		false
	)

	for _, descendant in stand:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	stand.Parent = placedBusinesses
	stand:PivotTo(savedCFrame)

	plot:SetAttribute(
		"StarterBusinessPlaced",
		true
	)

	return true
end

function DataService.GetUpgradeLevel(
	player: Player,
	businessName: string,
	upgradeName: string
): number
	local profile = profiles[player]

	if not profile then
		return 0
	end

	local businessUpgrades =
		profile.Upgrades[businessName]

	if not businessUpgrades then
		return 0
	end

	local level =
		businessUpgrades[upgradeName]

	if type(level) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(level))
end

function DataService.SetUpgradeLevel(
	player: Player,
	businessName: string,
	upgradeName: string,
	level: number
): boolean
	local profile = profiles[player]

	if not profile then
		return false
	end

	if type(businessName) ~= "string"
		or type(upgradeName) ~= "string"
		or type(level) ~= "number" then

		return false
	end

	profile.Upgrades[businessName] =
		profile.Upgrades[businessName] or {}

	profile.Upgrades[businessName][upgradeName] =
		math.max(0, math.floor(level))

	return true
end

function DataService.IsBusinessUnlocked(
	player: Player,
	businessName: string
): boolean
	local profile = profiles[player]

	if not profile then
		return false
	end

	return profile.UnlockedBusinesses[businessName]
		== true
end

function DataService.UnlockBusiness(
	player: Player,
	businessName: string
): boolean
	local profile = profiles[player]

	if not profile
		or type(businessName) ~= "string" then

		return false
	end

	profile.UnlockedBusinesses[businessName] = true

	return true
end

function DataService.ReleasePlayer(player: Player)
	profiles[player] = nil
	loadingPlayers[player] = nil
	savingPlayers[player] = nil
end

function DataService.SaveAllPlayers()
	local players = Players:GetPlayers()
	local remaining = #players

	if remaining == 0 then
		return
	end

	local completed = Instance.new("BindableEvent")

	for _, player in players do
		task.spawn(function()
			DataService.SavePlayer(player)

			remaining -= 1

			if remaining == 0 then
				completed:Fire()
			end
		end)
	end

	if remaining > 0 then
		completed.Event:Wait()
	end

	completed:Destroy()
end

return DataService