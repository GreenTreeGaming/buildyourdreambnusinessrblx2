local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local DataService = require(
	script.Parent:WaitForChild(
		"DataService"
	)
)

local MarketingConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("MarketingConfig")
)

local plotsFolder =
	Workspace:WaitForChild("Plots")

type MarketingResult = {
	Success: boolean,
	Message: string,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,
	TemplateName: string?,

	CustomerLimit: number?,
	MinimumSpawnInterval: number?,
	MaximumSpawnInterval: number?,
}

local purchaseLocks: {
	[Player]: boolean
} = {}

local MarketingService = {}

local function getDefinition(
	level: number
)
	for _, definition in
		MarketingConfig.Levels do

		if definition.Level == level then
			return definition
		end
	end

	return nil
end

local function getMaximumLevel(): number
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
		leaderstats:FindFirstChild(
			"Cash"
		)

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getOwnedPlot(
	player: Player
): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local namedPlot =
			plotsFolder:FindFirstChild(
				plotName
			)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return namedPlot
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

local function createResult(
	success: boolean,
	message: string
): MarketingResult
	return {
		Success = success,
		Message = message,
	}
end

local function buildResult(
	success: boolean,
	message: string,
	currentLevel: number
): MarketingResult
	local maximumLevel =
		getMaximumLevel()

	local currentDefinition =
		getDefinition(currentLevel)

	local nextDefinition =
		getDefinition(currentLevel + 1)

	local result: MarketingResult = {
		Success = success,
		Message = message,

		CurrentLevel = currentLevel,
		MaximumLevel = maximumLevel,

		NextCost =
			nextDefinition
			and nextDefinition.Cost
			or nil,
	}

	if currentDefinition then
		result.DisplayName =
			currentDefinition.DisplayName

		result.Description =
			currentDefinition.Description

		result.TemplateName =
			currentDefinition.TemplateName

		result.CustomerLimit =
			currentDefinition.CustomerLimit

		result.MinimumSpawnInterval =
			currentDefinition
				.MinimumSpawnInterval

		result.MaximumSpawnInterval =
			currentDefinition
				.MaximumSpawnInterval
	end

	return result
end

function MarketingService.ApplyToPlot(
	player: Player,
	plot: Model
): boolean
	if not plot
		or not plot:IsA("Model")
		or plot:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

		return false
	end

	local currentLevel =
		DataService.GetMarketingLevel(
			player
		)

	currentLevel =
		math.clamp(
			currentLevel,
			0,
			getMaximumLevel()
		)

	local definition =
		getDefinition(currentLevel)

	if not definition then
		return false
	end

	plot:SetAttribute(
		"MarketingLevel",
		currentLevel
	)

	plot:SetAttribute(
		"CustomerLimit",
		definition.CustomerLimit
	)

	plot:SetAttribute(
		"MinimumCustomerSpawnInterval",
		definition.MinimumSpawnInterval
	)

	plot:SetAttribute(
		"MaximumCustomerSpawnInterval",
		definition.MaximumSpawnInterval
	)

	plot:SetAttribute(
		"MarketingDisplayName",
		definition.DisplayName
	)

	if typeof(definition.TemplateName)
		== "string" then

		plot:SetAttribute(
			"MarketingTemplateName",
			definition.TemplateName
		)
	else
		plot:SetAttribute(
			"MarketingTemplateName",
			nil
		)
	end

	return true
end

function MarketingService.GetState(
	player: Player
): MarketingResult
	if not DataService.GetProfile(player) then
		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end

	local currentLevel =
		DataService.GetMarketingLevel(
			player
		)

	currentLevel =
		math.clamp(
			currentLevel,
			0,
			getMaximumLevel()
		)

	return buildResult(
		true,
		currentLevel >= getMaximumLevel()
			and "Maximum marketing level reached."
			or "Marketing upgrade available.",
		currentLevel
	)
end

function MarketingService.Purchase(
	player: Player
): MarketingResult
	if purchaseLocks[player] then
		return createResult(
			false,
			"Please wait before purchasing again."
		)
	end

	purchaseLocks[player] = true

	local function finish(
		result: MarketingResult
	): MarketingResult
		purchaseLocks[player] = nil
		return result
	end

	if not DataService.GetProfile(player) then
		return finish(
			createResult(
				false,
				"Your data has not loaded yet."
			)
		)
	end

	local plot =
		getOwnedPlot(player)

	if not plot then
		return finish(
			createResult(
				false,
				"Your plot could not be found."
			)
		)
	end

	local maximumLevel =
		getMaximumLevel()

	local currentLevel =
		math.clamp(
			DataService.GetMarketingLevel(
				player
			),
			0,
			maximumLevel
		)

	if currentLevel >= maximumLevel then
		return finish(
			buildResult(
				false,
				"Marketing is already at maximum level.",
				currentLevel
			)
		)
	end

	local nextLevel =
		currentLevel + 1

	local nextDefinition =
		getDefinition(nextLevel)

	if not nextDefinition then
		return finish(
			createResult(
				false,
				"The next marketing level is not configured."
			)
		)
	end

	local cost =
		nextDefinition.Cost

	if typeof(cost) ~= "number"
		or cost < 0 then

		return finish(
			createResult(
				false,
				"The marketing cost is invalid."
			)
		)
	end

	local cash =
		getCashValue(player)

	if not cash then
		return finish(
			createResult(
				false,
				"Your cash value could not be found."
			)
		)
	end

	if cash.Value < cost then
		return finish(
			buildResult(
				false,
				`You need ${cost - cash.Value} more.`,
				currentLevel
			)
		)
	end

	cash.Value -= cost

	local saved =
		DataService.SetMarketingLevel(
			player,
			nextLevel
		)

	if not saved then
		cash.Value += cost

		return finish(
			createResult(
				false,
				"The marketing upgrade could not be saved."
			)
		)
	end

	local applied =
		MarketingService.ApplyToPlot(
			player,
			plot
		)

	if not applied then
		DataService.SetMarketingLevel(
			player,
			currentLevel
		)

		cash.Value += cost

		return finish(
			buildResult(
				false,
				"The marketing upgrade could not be applied.",
				currentLevel
			)
		)
	end

	return finish(
		buildResult(
			true,
			`Marketing upgraded to {nextDefinition.DisplayName}!`,
			nextLevel
		)
	)
end

Players.PlayerRemoving:Connect(
	function(player)
		purchaseLocks[player] = nil
	end
)

return MarketingService