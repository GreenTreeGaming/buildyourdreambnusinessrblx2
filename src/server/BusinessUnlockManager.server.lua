local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local DataService =
	require(
		script.Parent
			:WaitForChild("Services")
			:WaitForChild("DataService")
	)


local remotes =
	ReplicatedStorage:WaitForChild("Remotes")


--==================================================
-- REMOTES
--==================================================

local getBusinessUnlockStateRemote =
	remotes:FindFirstChild(
		"GetBusinessUnlockState"
	)

if not getBusinessUnlockStateRemote then
	getBusinessUnlockStateRemote =
		Instance.new("RemoteFunction")

	getBusinessUnlockStateRemote.Name =
		"GetBusinessUnlockState"

	getBusinessUnlockStateRemote.Parent =
		remotes
end


local businessUnlockedRemote =
	remotes:FindFirstChild(
		"BusinessUnlocked"
	)

if not businessUnlockedRemote then
	businessUnlockedRemote =
		Instance.new("RemoteEvent")

	businessUnlockedRemote.Name =
		"BusinessUnlocked"

	businessUnlockedRemote.Parent =
		remotes
end


--==================================================
-- CONSTANTS
--==================================================

-- Keep this synchronized with ReputationManager.
local SALES_PER_REPUTATION_LEVEL =
	25

local MAX_REPUTATION_LEVEL =
	50

local CHECK_INTERVAL =
	1


--==================================================
-- HELPERS
--==================================================

local function getPlayerPlot(
	player: Player
): Model?

	for _, plot in
		Workspace
			:WaitForChild("Plots")
			:GetChildren() do

		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return plot
		end
	end

	return nil
end


local function getTotalSales(
	player: Player
): number

	local totalSales =
		0

	local profile =
		DataService.GetProfile(
			player
		)

	if not profile then
		return 0
	end


	for _, business in
		profile.PlacedBusinesses or {} do

		local sales =
			business.TotalSales

		if typeof(sales) == "number" then
			totalSales +=
				math.max(
					0,
					math.floor(sales)
				)
		end
	end


	-- Reputation boosts can contribute bonus sales
	-- in the existing reputation system.
	totalSales +=
		DataService.GetReputationBonusSales(
			player
		)


	return totalSales
end


local function getReputationLevel(
	player: Player
): number

	local totalSales =
		getTotalSales(
			player
		)


	return math.clamp(
		math.floor(
			totalSales
				/ SALES_PER_REPUTATION_LEVEL
		) + 1,

		1,
		MAX_REPUTATION_LEVEL
	)
end


local function getLifetimeEarnings(
	player: Player
): number

	local profile =
		DataService.GetProfile(
			player
		)

	if not profile then
		return 0
	end


	local total =
		0


	for _, business in
		profile.PlacedBusinesses or {} do

		local earnings =
			business.LifetimeEarnings

		if typeof(earnings) == "number" then
			total +=
				math.max(
					0,
					earnings
				)
		end
	end


	return math.floor(total)
end


local function getHighestBusinessLevel(
	player: Player,
	businessType: string
): number

	local highestLevel =
		0


	local plot =
		getPlayerPlot(
			player
		)

	if not plot then
		return highestLevel
	end


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return highestLevel
	end


	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA("Model") then
			continue
		end


		local currentType =
			business:GetAttribute(
				"BusinessType"
			)


		if currentType
			~= businessType then

			continue
		end


		local level =
			business:GetAttribute(
				"Level"
			)


		if typeof(level)
			~= "number" then

			level = 1
		end


		highestLevel =
			math.max(
				highestLevel,
				math.floor(level)
			)
	end


	return highestLevel
end


local function buildRequirementState(
	player: Player,
	businessName: string
): {[any]: any}

	local config =
		BusinessConfig[
			businessName
		]


	if type(config)
		~= "table" then

		return {
			Unlocked = false,

			CanUnlock = false,

			Requirements = {},

			MissingRequirements = {
				"Business is not configured.",
			},
		}
	end


	if DataService.IsBusinessUnlocked(
		player,
		businessName
	) then

		return {
			Unlocked = true,

			CanUnlock = true,

			Requirements = {},

			MissingRequirements = {},
		}
	end


	local requirements =
		config.UnlockRequirements


	-- No requirements means the business should
	-- always be available.
	if type(requirements)
		~= "table" then

		return {
			Unlocked = false,

			CanUnlock = true,

			Requirements = {},

			MissingRequirements = {},
		}
	end


	local requirementStates =
		{}

	local missingRequirements =
		{}


	--==================================================
	-- REPUTATION
	--==================================================

	local requiredReputation =
		requirements.ReputationLevel


	if typeof(requiredReputation)
		== "number" then

		local currentReputation =
			getReputationLevel(
				player
			)

		local completed =
			currentReputation
				>= requiredReputation


		table.insert(
			requirementStates,
			{
				Type =
					"ReputationLevel",

				Current =
					currentReputation,

				Required =
					requiredReputation,

				Completed =
					completed,
			}
		)


		if not completed then
			table.insert(
				missingRequirements,

				`Reputation Level {requiredReputation}`
			)
		end
	end


	--==================================================
	-- LIFETIME EARNINGS
	--==================================================

	local requiredEarnings =
		requirements.LifetimeEarnings


	if typeof(requiredEarnings)
		== "number" then

		local currentEarnings =
			getLifetimeEarnings(
				player
			)

		local completed =
			currentEarnings
				>= requiredEarnings


		table.insert(
			requirementStates,
			{
				Type =
					"LifetimeEarnings",

				Current =
					currentEarnings,

				Required =
					requiredEarnings,

				Completed =
					completed,
			}
		)


		if not completed then
			table.insert(
				missingRequirements,

				`${requiredEarnings} lifetime earnings`
			)
		end
	end


	--==================================================
	-- BUSINESS LEVEL
	--==================================================

	local businessLevelRequirement =
		requirements.BusinessLevel


	if type(businessLevelRequirement)
		== "table" then

		local requiredBusinessType =
			businessLevelRequirement.BusinessType

		local requiredLevel =
			businessLevelRequirement.Level


		if typeof(requiredBusinessType)
				== "string"
			and typeof(requiredLevel)
				== "number" then

			local currentLevel =
				getHighestBusinessLevel(
					player,
					requiredBusinessType
				)


			local completed =
				currentLevel
					>= requiredLevel


			table.insert(
				requirementStates,
				{
					Type =
						"BusinessLevel",

					BusinessType =
						requiredBusinessType,

					Current =
						currentLevel,

					Required =
						requiredLevel,

					Completed =
						completed,
				}
			)


			if not completed then

				local requiredConfig =
					BusinessConfig[
						requiredBusinessType
					]


				local displayName =
					requiredConfig
					and requiredConfig.DisplayName
					or requiredBusinessType


				table.insert(
					missingRequirements,

					`Level {requiredLevel} {displayName}`
				)
			end
		end
	end


	return {
		Unlocked = false,

		CanUnlock =
			#missingRequirements
				== 0,

		Requirements =
			requirementStates,

		MissingRequirements =
			missingRequirements,
	}
end


local function tryUnlockBusiness(
	player: Player,
	businessName: string
): boolean

	if DataService.IsBusinessUnlocked(
		player,
		businessName
	) then

		return false
	end


	local state =
		buildRequirementState(
			player,
			businessName
		)


	if not state.CanUnlock then
		return false
	end


	local unlocked =
		DataService.UnlockBusiness(
			player,
			businessName
		)


	if not unlocked then
		return false
	end


	local config =
		BusinessConfig[
			businessName
		]


	local displayName =
		config
		and config.DisplayName
		or businessName


	businessUnlockedRemote:FireClient(
		player,
		businessName,
		displayName
	)


	return true
end


local function evaluatePlayer(
	player: Player
)

	if player:GetAttribute(
		"DataLoaded"
	) ~= true then

		return
	end


	for businessName, config in
		BusinessConfig do

		if type(config)
			~= "table" then

			continue
		end


		if DataService.IsBusinessUnlocked(
			player,
			businessName
		) then

			continue
		end


		tryUnlockBusiness(
			player,
			businessName
		)
	end
end


--==================================================
-- CLIENT STATE REQUEST
--==================================================

getBusinessUnlockStateRemote.OnServerInvoke =
	function(
		player: Player
	)

		local result =
			{}


		for businessName, config in
			BusinessConfig do

			if type(config)
				~= "table" then

				continue
			end


			result[
				businessName
			] =
				buildRequirementState(
					player,
					businessName
				)
		end


		return result
	end


--==================================================
-- CHECK LOOP
--==================================================

task.spawn(
	function()

		while true do

			task.wait(
				CHECK_INTERVAL
			)


			for _, player in
				Players:GetPlayers() do

				evaluatePlayer(
					player
				)
			end
		end
	end
)