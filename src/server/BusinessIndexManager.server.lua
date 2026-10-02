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
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


--==================================================
-- REMOTE
--==================================================

local getBusinessIndexState =
	remotes:FindFirstChild(
		"GetBusinessIndexState"
	)


if not getBusinessIndexState then

	getBusinessIndexState =
		Instance.new(
			"RemoteFunction"
		)

	getBusinessIndexState.Name =
		"GetBusinessIndexState"

	getBusinessIndexState.Parent =
		remotes
end


--==================================================
-- TYPES
--==================================================

type LevelState = {
	Level: number,
	TemplateName: string,
	Unlocked: boolean,
}


type BusinessState = {
	BusinessType: string,
	DisplayName: string,
	DisplayOrder: number,

	Unlocked: boolean,
	HighestLevel: number,

	Levels: {LevelState},
}


--==================================================
-- PLOT
--==================================================

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
		plotsFolder:GetChildren() do

		if not plot:IsA(
			"Model"
		) then

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


--==================================================
-- BUSINESS TYPE
--==================================================

local function getBusinessType(
	business: Model
): string?

	local businessType =
		business:GetAttribute(
			"BusinessType"
		)


	if typeof(businessType)
			== "string"
		and BusinessConfig[
			businessType
		] then

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


	return nil
end


--==================================================
-- HIGHEST LEVEL
--==================================================

local function getHighestSavedLevel(
	player: Player,
	businessType: string
): number

	local profile =
		DataService.GetProfile(
			player
		)


	if not profile then
		return 0
	end


	local highestLevel =
		0


	if typeof(
		profile.PlacedBusinesses
	) ~= "table" then

		return highestLevel
	end


	for _, businessData in
		profile.PlacedBusinesses do

		if typeof(businessData)
			~= "table" then

			continue
		end


		if businessData.Type
			~= businessType then

			continue
		end


		local level =
			businessData.Level


		if typeof(level)
			~= "number" then

			continue
		end


		highestLevel =
			math.max(
				highestLevel,
				math.floor(level)
			)
	end


	return highestLevel
end


local function getHighestLiveLevel(
	player: Player,
	businessType: string
): number

	local plot =
		getPlayerPlot(
			player
		)


	if not plot then
		return 0
	end


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return 0
	end


	local highestLevel =
		0


	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA(
			"Model"
		) then

			continue
		end


		if getBusinessType(
			business
		) ~= businessType then

			continue
		end


		local level =
			business:GetAttribute(
				"Level"
			)


		if typeof(level)
			~= "number" then

			level =
				1
		end


		highestLevel =
			math.max(
				highestLevel,
				math.floor(level)
			)
	end


	return highestLevel
end


local function getHighestUnlockedLevel(
	player: Player,
	businessType: string,
	businessUnlocked: boolean
): number

	if not businessUnlocked then
		return 0
	end


	-- Once the actual business is unlocked,
	-- its Level 1 appearance is automatically known.
	local highestLevel =
		1


	highestLevel =
		math.max(
			highestLevel,

			getHighestSavedLevel(
				player,
				businessType
			),

			getHighestLiveLevel(
				player,
				businessType
			)
		)


	return highestLevel
end


--==================================================
-- BUILD STATE
--==================================================

local function buildBusinessState(
	player: Player,
	businessType: string,
	config
): BusinessState

	local unlocked =
		DataService.IsBusinessUnlocked(
			player,
			businessType
		)


	local highestLevel =
		getHighestUnlockedLevel(
			player,
			businessType,
			unlocked
		)


	local levels: {LevelState} =
		{}


	if typeof(config.StandLevels)
		== "table" then

		local levelNumbers = {}


		for levelNumber in
			config.StandLevels do

			if typeof(levelNumber)
				== "number" then

				table.insert(
					levelNumbers,
					levelNumber
				)
			end
		end


		table.sort(
			levelNumbers
		)


		for _, levelNumber in
			levelNumbers do

			local levelConfig =
				config.StandLevels[
					levelNumber
				]


			if typeof(levelConfig)
				~= "table" then

				continue
			end


			local templateName =
				levelConfig.TemplateName


			if typeof(templateName)
				~= "string" then

				continue
			end


			table.insert(
				levels,

				{
					Level =
						levelNumber,

					TemplateName =
						templateName,

					Unlocked =
						unlocked
						and levelNumber
							<= highestLevel,
				}
			)
		end
	end


	return {
		BusinessType =
			businessType,

		DisplayName =
			typeof(config.DisplayName)
					== "string"
				and config.DisplayName
				or businessType,

		DisplayOrder =
			typeof(config.DisplayOrder)
					== "number"
				and config.DisplayOrder
				or 999999,

		Unlocked =
			unlocked,

		HighestLevel =
			highestLevel,

		Levels =
			levels,
	}
end


local function getIndexState(
	player: Player
): {BusinessState}

	local state: {BusinessState} =
		{}


	for businessType, config in
		BusinessConfig do

		if typeof(config)
			~= "table" then

			continue
		end


		table.insert(
			state,

			buildBusinessState(
				player,
				businessType,
				config
			)
		)
	end


	table.sort(
		state,

		function(
			first: BusinessState,
			second: BusinessState
		): boolean

			if first.DisplayOrder
				== second.DisplayOrder then

				return first.DisplayName
					< second.DisplayName
			end


			return first.DisplayOrder
				< second.DisplayOrder
		end
	)


	return state
end


--==================================================
-- REMOTE
--==================================================

(
	getBusinessIndexState
		:: RemoteFunction
).OnServerInvoke =
	function(
		player: Player
	)

		if not Players:FindFirstChild(
			player.Name
		) then

			return {}
		end


		return getIndexState(
			player
		)
	end