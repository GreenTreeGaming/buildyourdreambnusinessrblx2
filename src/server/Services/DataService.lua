local DataStoreService =
	game:GetService("DataStoreService")

local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MarketingConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("MarketingConfig")
)

local PlotConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("PlotConfig")
	)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local DATA_STORE_NAME = "PlayerData_v4"

-- Version 2 changed Businesses from one fixed stand
-- into a list of uniquely identified placed businesses.
--
-- Version 3 saves each placed business's physical model level.
-- Version 4 adds plot-wide marketing progression.
local CURRENT_DATA_VERSION = 5

local MAX_RETRIES = 3
local RETRY_DELAY_SECONDS = 2
local SAVE_LOCK_TIMEOUT_SECONDS = 15

local DEFAULT_UPGRADES = {
	ServingSpeed = 0,
	SaleValue = 0,
	QueueCapacity = 0,
}

local UPGRADE_LEVEL_ATTRIBUTES = {
	ServingSpeed = "ServingSpeedLevel",
	SaleValue = "SaleValueLevel",
	QueueCapacity = "QueueCapacityLevel",
}

local DEFAULT_PROFILE = {
	Version = CURRENT_DATA_VERSION,

	Cash = 0,

	-- Plot-wide marketing progression.
	MarketingLevel = 0,

	PlotLevel = 0,

	-- Every placed business receives a unique ID.
	PlacedBusinesses = {},

	-- Used when generating the next permanent business ID.
	NextBusinessNumber = 1,

	-- Keep this temporarily because the current UpgradeService
	-- still stores upgrades globally by business type.
	-- We will move these into individual stand entries later.
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

type UpgradeLevels = {
	[string]: number,
}

type SavedPlacedBusiness = {
	Id: string,
	Type: string,
	Level: number,

	Transform: SerializedCFrame?,
	TransformSpace: string,

	Upgrades: UpgradeLevels,

	TotalSales: number,
	LifetimeEarnings: number,
}

type PlayerProfile = {
	Version: number,
	Cash: number,
	MarketingLevel: number,

	PlotLevel: number,

	PlacedBusinesses: {
		SavedPlacedBusiness
	},

	NextBusinessNumber: number,

	-- Temporary compatibility field.
	Upgrades: {
		[string]: UpgradeLevels,
	},

	UnlockedBusinesses: {
		[string]: boolean,
	},
}

local playerDataStore =
	DataStoreService:GetDataStore(
		DATA_STORE_NAME
	)

local businessModels =
	ReplicatedStorage:WaitForChild(
		"BusinessModels"
	)

local plotsFolder =
	Workspace:WaitForChild("Plots")

local profiles: {
	[Player]: PlayerProfile
} = {}

local loadingPlayers: {
	[Player]: boolean
} = {}

local savingPlayers: {
	[Player]: boolean
} = {}

local DataService = {}

local function deepCopy<T>(
	value: T
): T
	if type(value) ~= "table" then
		return value
	end

	local copiedTable = {}

	for key, childValue in value do
		copiedTable[deepCopy(key)] =
			deepCopy(childValue)
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
			loaded[key] =
				deepCopy(defaultValue)

			continue
		end

		if type(defaultValue) == "table" then
			if type(loadedValue) ~= "table" then
				loaded[key] =
					deepCopy(defaultValue)
			else
				reconcileTable(
					loadedValue,
					defaultValue
				)
			end
		end
	end
end

local function serializeCFrame(
	cframe: CFrame
): SerializedCFrame
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
		local component =
			components[index]

		if type(component) ~= "number"
			or component ~= component
			or component == math.huge
			or component == -math.huge then

			return nil
		end

		validatedComponents[index] =
			component
	end

	return CFrame.new(
		table.unpack(
			validatedComponents
		)
	)
end

local function sanitizeUpgradeLevels(
	rawUpgrades: any
): UpgradeLevels
	local upgrades =
		deepCopy(DEFAULT_UPGRADES)

	if type(rawUpgrades) ~= "table" then
		return upgrades
	end

	for upgradeName, defaultLevel in
		DEFAULT_UPGRADES do

		local loadedLevel =
			rawUpgrades[upgradeName]

		if type(loadedLevel) == "number" then
			upgrades[upgradeName] =
				math.max(
					0,
					math.floor(loadedLevel)
				)
		else
			upgrades[upgradeName] =
				defaultLevel
		end
	end

	return upgrades
end

local function sanitizeStatistic(
	value: any
): number
	if type(value) ~= "number"
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

local function getMaximumMarketingLevel(): number
	local maximumLevel = 0

	for _, definition in
		MarketingConfig.Levels do

		if typeof(definition.Level) == "number" then
			maximumLevel =
				math.max(
					maximumLevel,
					math.floor(definition.Level)
				)
		end
	end

	return maximumLevel
end

local function getMaximumPlotLevel(): number
	local maximumLevel =
		0


	for _, definition in
		PlotConfig.Levels do

		if typeof(definition.Level)
			== "number" then

			maximumLevel =
				math.max(
					maximumLevel,
					math.floor(
						definition.Level
					)
				)
		end
	end


	return maximumLevel
end


local function sanitizePlotLevel(
	value: any
): number

	if typeof(value)
			~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end


	return math.clamp(
		math.floor(
			value
		),

		0,
		getMaximumPlotLevel()
	)
end

local function sanitizeMarketingLevel(
	value: any
): number
	if typeof(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge then

		return 0
	end

	return math.clamp(
		math.floor(value),
		0,
		getMaximumMarketingLevel()
	)
end

local function sanitizeBusinessLevel(
	businessType: string,
	value: any
): number
	local level = 1

	if type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge then

		level = math.max(
			1,
			math.floor(value)
		)
	end

	local businessConfig =
		BusinessConfig[businessType]

	if type(businessConfig) ~= "table"
		or type(businessConfig.StandLevels) ~= "table" then

		return level
	end

	if businessConfig.StandLevels[level] then
		return level
	end

	-- Invalid or no-longer-configured levels safely fall
	-- back to the base model.
	return 1
end

local function migrateVersionOneProfile(
	profile: {[any]: any}
)
	local oldBusinesses =
		profile.Businesses

	local oldStand =
		type(oldBusinesses) == "table"
		and oldBusinesses.LemonadeStand
		or nil

	profile.PlacedBusinesses = {}
	profile.NextBusinessNumber = 1

	if type(oldStand) ~= "table"
		or oldStand.Owned ~= true then

		return
	end

	local oldGlobalUpgrades =
		type(profile.Upgrades) == "table"
		and profile.Upgrades.LemonadeStand
		or nil

	table.insert(
		profile.PlacedBusinesses,
				{
			Id = "LemonadeStand_1",
			Type = "LemonadeStand",
			Level = 1,

			Transform =
				deepCopy(oldStand.Transform),

			-- Version 1 stored world-space CFrames.
			TransformSpace = "World",

			TotalSales = 0,
LifetimeEarnings = 0,

			Upgrades =
				sanitizeUpgradeLevels(
					oldGlobalUpgrades
				),
		}
	)

	profile.NextBusinessNumber = 2
end

local function sanitizePlacedBusinesses(
	profile: {[any]: any}
)
	if type(profile.PlacedBusinesses)
		~= "table" then

		profile.PlacedBusinesses = {}
	end

	local sanitized = {}
	local usedIds: {[string]: boolean} = {}

	local largestNumber = 0

	for _, rawBusiness in
		profile.PlacedBusinesses do

		if type(rawBusiness) ~= "table" then
			continue
		end

		local businessType =
			rawBusiness.Type

		if type(businessType) ~= "string"
			or businessType == "" then

			continue
		end

		local businessId =
			rawBusiness.Id

		if type(businessId) ~= "string"
			or businessId == ""
			or usedIds[businessId] then

			continue
		end

		local transform =
			deserializeCFrame(
				rawBusiness.Transform
			)

		if not transform then
			continue
		end

		local transformSpace =
			rawBusiness.TransformSpace

		if transformSpace ~= "Plot"
			and transformSpace ~= "World" then

			transformSpace = "World"
		end

		usedIds[businessId] = true

		local endingNumber =
			tonumber(
				string.match(
					businessId,
					"_(%d+)$"
				)
			)

		if endingNumber then
			largestNumber =
				math.max(
					largestNumber,
					endingNumber
				)
		end

		table.insert(
			sanitized,
						{
				Id = businessId,
				Type = businessType,

				Level =
					sanitizeBusinessLevel(
						businessType,
						rawBusiness.Level
					),

				Transform =
					serializeCFrame(transform),

				TransformSpace =
					transformSpace,

				Upgrades =
					sanitizeUpgradeLevels(
						rawBusiness.Upgrades
					),

				TotalSales =
	sanitizeStatistic(
		rawBusiness.TotalSales
	),

LifetimeEarnings =
	sanitizeStatistic(
		rawBusiness.LifetimeEarnings
	),
			}
		)
	end

	profile.PlacedBusinesses = sanitized

	local nextBusinessNumber =
		profile.NextBusinessNumber

	if type(nextBusinessNumber) ~= "number" then
		nextBusinessNumber =
			largestNumber + 1
	end

	profile.NextBusinessNumber =
		math.max(
			largestNumber + 1,
			math.floor(
				nextBusinessNumber
			),
			1
		)
end

local function migrateProfile(
	rawData: any
): PlayerProfile
	if type(rawData) ~= "table" then
		return deepCopy(DEFAULT_PROFILE)
	end

	local profile = deepCopy(rawData)

	local loadedVersion =
		profile.Version

	if type(loadedVersion) ~= "number" then
		loadedVersion = 0
	end

	if loadedVersion < 2 then
		migrateVersionOneProfile(profile)
		loadedVersion = 2
	end

	reconcileTable(
		profile,
		DEFAULT_PROFILE
	)

	if type(profile.Cash) ~= "number" then
		profile.Cash =
			DEFAULT_PROFILE.Cash
	end

	profile.Cash =
		math.max(
			0,
			math.floor(profile.Cash)
		)

	profile.MarketingLevel =
	sanitizeMarketingLevel(
		profile.MarketingLevel
	)

	profile.PlotLevel =
	sanitizePlotLevel(
		profile.PlotLevel
	)

	if type(profile.Upgrades) ~= "table" then
		profile.Upgrades = {}
	end

	profile.Upgrades.LemonadeStand =
		sanitizeUpgradeLevels(
			profile.Upgrades.LemonadeStand
		)

	sanitizePlacedBusinesses(profile)

	-- Remove the obsolete version-one field after migration.
	profile.Businesses = nil
	profile.Version = CURRENT_DATA_VERSION

	return profile :: PlayerProfile
end

local function getPlayerKey(
	player: Player
): string
	return `Player_{player.UserId}`
end

local function getPlayerPlot(
	player: Player
): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot =
			plotsFolder:FindFirstChild(
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

	for _, plot in
		plotsFolder:GetChildren() do

		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end

	return nil
end

local function findOwnedBusinessModel(
	player: Player,
	businessId: string
): Model?
	if type(businessId) ~= "string"
		or businessId == "" then

		return nil
	end

	local plot =
		getPlayerPlot(player)

	if not plot then
		return nil
	end

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return nil
	end

	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		local childId =
			child:GetAttribute(
				"BusinessId"
			)

		if childId ~= businessId
			and child.Name ~= businessId then

			continue
		end

		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			return nil
		end

		return child
	end

	return nil
end

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)

	if not leaderstats then
		return nil
	end

	local cash =
		leaderstats:FindFirstChild("Cash")

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
		player:FindFirstChild(
			"leaderstats"
		)

	if existingLeaderstats then
		existingLeaderstats:Destroy()
	end

	local leaderstats =
		Instance.new("Folder")

	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")

	cash.Name = "Cash"

	cash.Value =
		math.max(
			0,
			math.floor(startingCash)
		)

	cash.Parent = leaderstats
end

local function getBusinessType(
	business: Model
): string
	local businessType =
		business:GetAttribute(
			"BusinessType"
		)

	if typeof(businessType) == "string"
		and businessType ~= "" then

		return businessType
	end

	if string.match(
		business.Name,
		"^LemonadeStand"
	) then

		return "LemonadeStand"
	end

	return business.Name
end

local function generateBusinessId(
	profile: PlayerProfile,
	businessType: string
): string
	local businessNumber =
		profile.NextBusinessNumber

	profile.NextBusinessNumber += 1

	return `{businessType}_{businessNumber}`
end

local function ensureBusinessIdentity(
	profile: PlayerProfile,
	business: Model
): (string, string)
	local businessType =
		getBusinessType(business)

	local businessId =
		business:GetAttribute(
			"BusinessId"
		)

	if typeof(businessId) ~= "string"
		or businessId == "" then

		businessId =
			generateBusinessId(
				profile,
				businessType
			)

		business:SetAttribute(
			"BusinessId",
			businessId
		)
	end

	business:SetAttribute(
		"BusinessType",
		businessType
	)

	return businessId, businessType
end

local function getBusinessUpgradeSnapshot(
	profile: PlayerProfile,
	business: Model,
	businessType: string
): UpgradeLevels
	local savedUpgrades = {
		ServingSpeed =
			business:GetAttribute(
				"ServingSpeedLevel"
			),

		SaleValue =
			business:GetAttribute(
				"SaleValueLevel"
			),

		QueueCapacity =
			business:GetAttribute(
				"QueueCapacityLevel"
			),
	}

	for upgradeName in DEFAULT_UPGRADES do
	if type(savedUpgrades[upgradeName])
		~= "number" then

		savedUpgrades[upgradeName] = 0
	end
end

	return sanitizeUpgradeLevels(
		savedUpgrades
	)
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
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return
	end

	local savedBusinesses = {}

	for _, instance in
		placedBusinesses:GetChildren() do

		if not instance:IsA("Model") then
			continue
		end

		local businessId, businessType =
			ensureBusinessIdentity(
				profile,
				instance
			)

		local relativeCFrame =
			plot:GetPivot():ToObjectSpace(
				instance:GetPivot()
			)

		table.insert(
			savedBusinesses,
						{
				Id = businessId,
				Type = businessType,

				Level =
					sanitizeBusinessLevel(
						businessType,
						instance:GetAttribute("Level")
					),

				Transform =
					serializeCFrame(
						relativeCFrame
					),

				TransformSpace = "Plot",

				Upgrades =
					getBusinessUpgradeSnapshot(
						profile,
						instance,
						businessType
					),

				TotalSales =
	sanitizeStatistic(
		instance:GetAttribute(
			"TotalSales"
		)
	),

LifetimeEarnings =
	sanitizeStatistic(
		instance:GetAttribute(
			"LifetimeEarnings"
		)
	),
			}
		)
	end

	table.sort(
		savedBusinesses,
		function(first, second)
			return first.Id < second.Id
		end
	)

	profile.PlacedBusinesses =
		savedBusinesses
end

local function createSaveSnapshot(
	player: Player
): PlayerProfile?
	local currentProfile =
		profiles[player]

	if not currentProfile then
		return nil
	end

	local snapshot =
		deepCopy(currentProfile)

	local cash = getCashValue(player)

	if cash then
		snapshot.Cash =
			math.max(
				0,
				math.floor(cash.Value)
			)
	end

	captureBusinessState(
		player,
		snapshot
	)

	snapshot.Version =
		CURRENT_DATA_VERSION

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
				RETRY_DELAY_SECONDS
					* attempt
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

	local success, result =
		runWithRetries(function()
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

		if result == nil then
			print(
				`No existing data found for {player.Name}; using a new profile.`
			)
		else
			print(
				`Found saved data for {player.Name}: Cash={profile.Cash}, Businesses={#profile.PlacedBusinesses}`
			)
		end
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

	createLeaderstats(
		player,
		profile.Cash
	)

	player:SetAttribute(
		"DataLoaded",
		true
	)

	return true
end

function DataService.WaitForProfile(
	player: Player,
	timeout: number?
): PlayerProfile?
	local startedAt = time()
	local maximumWait = timeout or 15

	while player.Parent do
		local profile =
			profiles[player]

		if profile then
			return profile
		end

		if time() - startedAt
			>= maximumWait then

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

function DataService.GetMarketingLevel(
	player: Player
): number
	local profile =
		profiles[player]

	if not profile then
		return 0
	end

	return sanitizeMarketingLevel(
		profile.MarketingLevel
	)
end

function DataService.SetMarketingLevel(
	player: Player,
	level: number
): boolean
	local profile =
		profiles[player]

	if not profile then
		return false
	end

	if typeof(level) ~= "number" then
		return false
	end

	profile.MarketingLevel =
		sanitizeMarketingLevel(level)

	return true
end

function DataService.GetPlotLevel(
	player: Player
): number

	local profile =
		profiles[
			player
		]


	if not profile then
		return 0
	end


	return sanitizePlotLevel(
		profile.PlotLevel
	)
end


function DataService.SetPlotLevel(
	player: Player,
	level: number
): boolean

	local profile =
		profiles[
			player
		]


	if not profile then
		return false
	end


	if typeof(level)
		~= "number" then

		return false
	end


	profile.PlotLevel =
		sanitizePlotLevel(
			level
		)


	return true
end

function DataService.GetPlacedBusinesses(
	player: Player
): {SavedPlacedBusiness}
	local profile = profiles[player]

	if not profile then
		return {}
	end

	return deepCopy(
		profile.PlacedBusinesses
	)
end

function DataService.GenerateBusinessId(
	player: Player,
	businessType: string
): string?
	local profile = profiles[player]

	if not profile
		or type(businessType) ~= "string"
		or businessType == "" then

		return nil
	end

	return generateBusinessId(
		profile,
		businessType
	)
end

function DataService.SavePlayer(
	player: Player
): boolean
	local startedWaitingAt = time()

	while savingPlayers[player] do
		if time() - startedWaitingAt
			>= SAVE_LOCK_TIMEOUT_SECONDS then

			warn(
				`Timed out waiting for an existing save for {player.Name}.`
			)

			return false
		end

		task.wait(0.1)
	end

	local snapshot =
		createSaveSnapshot(player)

	if not snapshot then
		warn(
			`Could not create a save snapshot for {player.Name}; profile was unavailable.`
		)

		return false
	end

	savingPlayers[player] = true

	print(
		`Saving {player.Name}: Cash={snapshot.Cash}, Businesses={#snapshot.PlacedBusinesses}`
	)

	local success, result =
		runWithRetries(function()
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

	print(
		`Successfully saved data for {player.Name}.`
	)

	return true
end

function DataService.RestorePlot(
	player: Player,
	plot: Model
): boolean
	local profile =
		DataService.WaitForProfile(
			player,
			15
		)

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
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses
		or not placedBusinesses:IsA(
			"Folder"
		) then

		warn(
			`Plot "{plot.Name}" is missing PlacedBusinesses.`
		)

		return false
	end

	if #profile.PlacedBusinesses == 0 then
		plot:SetAttribute(
			"StarterBusinessPlaced",
			false
		)

		return true
	end

	local restoredCount = 0

	for _, savedBusiness in
		profile.PlacedBusinesses do

				local savedLevel =
			sanitizeBusinessLevel(
				savedBusiness.Type,
				savedBusiness.Level
			)

		local templateName =
			savedBusiness.Type

		local businessConfig =
			BusinessConfig[savedBusiness.Type]

		if type(businessConfig) == "table"
			and type(businessConfig.StandLevels) == "table" then

			local levelConfig =
				businessConfig.StandLevels[
					savedLevel
				]

			if type(levelConfig) == "table"
				and type(levelConfig.TemplateName)
					== "string"
				and levelConfig.TemplateName ~= "" then

				templateName =
					levelConfig.TemplateName
			end
		end

		local template =
			businessModels:FindFirstChild(
				templateName
			)

		if not template
			or not template:IsA("Model") then

			warn(
				`Business template "{templateName}" was not found for {savedBusiness.Id}.`
			)

			continue
		end

		local serializedTransform =
			deserializeCFrame(
				savedBusiness.Transform
			)

		if not serializedTransform then
			warn(
				`Saved transform for {savedBusiness.Id} was invalid.`
			)

			continue
		end

		local targetCFrame

		if savedBusiness.TransformSpace
			== "Plot" then

			targetCFrame =
				plot:GetPivot()
				* serializedTransform
		else
			-- Version-one compatibility.
			targetCFrame =
				serializedTransform
		end

		if placedBusinesses:FindFirstChild(
			savedBusiness.Id
		) then

			continue
		end

		local stand = template:Clone()

		-- Keep the first stand's old name temporarily so
		-- the current one-stand systems continue working.
		if restoredCount == 0
			and savedBusiness.Type
				== "LemonadeStand" then

			stand.Name = "LemonadeStand"
		else
			stand.Name =
				savedBusiness.Id
		end

		stand:SetAttribute(
			"BusinessId",
			savedBusiness.Id
		)

				stand:SetAttribute(
			"BusinessType",
			savedBusiness.Type
		)

		stand:SetAttribute(
			"Level",
			savedLevel
		)

		stand:SetAttribute(
			"TotalSales",
			sanitizeStatistic(
				savedBusiness.TotalSales
			)
		)

		stand:SetAttribute(
			"LifetimeEarnings",
			sanitizeStatistic(
				savedBusiness.LifetimeEarnings
			)
		)

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

				local upgrades =
			sanitizeUpgradeLevels(
				savedBusiness.Upgrades
			)

		stand:SetAttribute(
			"ServingSpeedLevel",
			upgrades.ServingSpeed or 0
		)

		stand:SetAttribute(
			"SaleValueLevel",
			upgrades.SaleValue or 0
		)

		stand:SetAttribute(
			"QueueCapacityLevel",
			upgrades.QueueCapacity or 0
		)

		for _, descendant in
			stand:GetDescendants() do

			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end

		stand.Parent = placedBusinesses
		stand:PivotTo(targetCFrame)

		restoredCount += 1
	end

	plot:SetAttribute(
		"StarterBusinessPlaced",
		restoredCount > 0
	)

	print(
		`Restored {restoredCount} business(es) for {player.Name}.`
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

	return math.max(
		0,
		math.floor(level)
	)
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
		profile.Upgrades[businessName]
		or {}

	profile.Upgrades[businessName][upgradeName] =
		math.max(
			0,
			math.floor(level)
		)

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

	return profile.UnlockedBusinesses[
		businessName
	] == true
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

	profile.UnlockedBusinesses[
		businessName
	] = true

	return true
end

function DataService.ReleasePlayer(
	player: Player
)
	profiles[player] = nil
	loadingPlayers[player] = nil
	savingPlayers[player] = nil
end

function DataService.SaveAllPlayers()
	local currentPlayers =
		Players:GetPlayers()

	if #currentPlayers == 0 then
		return
	end

	local remaining =
		#currentPlayers

	local completed =
		Instance.new("BindableEvent")

	for _, player in currentPlayers do
		task.spawn(function()
			DataService.SavePlayer(player)

			remaining -= 1

			if remaining <= 0 then
				completed:Fire()
			end
		end)
	end

	local finished = false

	task.spawn(function()
		completed.Event:Wait()
		finished = true
	end)

	local startedAt = time()

	while not finished
		and time() - startedAt < 25 do

		task.wait(0.1)
	end

	if not finished then
		warn(
			`Server shutdown save timed out with {remaining} player save(s) unfinished.`
		)
	end

	completed:Destroy()
end

function DataService.FindOwnedBusinessById(
	player: Player,
	businessId: string
): Model?
	return findOwnedBusinessModel(
		player,
		businessId
	)
end

function DataService.GetBusinessUpgradeLevel(
	player: Player,
	businessId: string,
	upgradeName: string
): number
	local attributeName =
		UPGRADE_LEVEL_ATTRIBUTES[
			upgradeName
		]

	if not attributeName then
		return 0
	end

	local business =
		findOwnedBusinessModel(
			player,
			businessId
		)

	if not business then
		return 0
	end

	local level =
		business:GetAttribute(
			attributeName
		)

	if typeof(level) ~= "number" then
		return 0
	end

	return math.max(
		0,
		math.floor(level)
	)
end

function DataService.SetBusinessUpgradeLevel(
	player: Player,
	businessId: string,
	upgradeName: string,
	level: number
): boolean
	if typeof(level) ~= "number" then
		return false
	end

	local attributeName =
		UPGRADE_LEVEL_ATTRIBUTES[
			upgradeName
		]

	if not attributeName then
		return false
	end

	local business =
		findOwnedBusinessModel(
			player,
			businessId
		)

	if not business then
		return false
	end

	local sanitizedLevel =
		math.max(
			0,
			math.floor(level)
		)

	business:SetAttribute(
		attributeName,
		sanitizedLevel
	)

	local profile =
		profiles[player]

	if profile then
		for _, savedBusiness in
			profile.PlacedBusinesses do

			if savedBusiness.Id
				~= businessId then

				continue
			end

			savedBusiness.Upgrades =
				savedBusiness.Upgrades
				or deepCopy(
					DEFAULT_UPGRADES
				)

			savedBusiness.Upgrades[
				upgradeName
			] = sanitizedLevel

			break
		end
	end

	return true
end

return DataService