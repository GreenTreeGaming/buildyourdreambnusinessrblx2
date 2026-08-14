local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")


local DataService =
	require(
		script.Parent:WaitForChild(
			"DataService"
		)
	)


local PlotConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("PlotConfig")
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local EXPANSION_TWEEN_TIME =
	0.4


type BasePlotState = {
	Ground: BasePart,

	CFrame: CFrame,
	Size: Vector3,

	FrontAxis: string,
	FrontSign: number,
}


type PlotResult = {
	Success: boolean,
	Message: string,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,

	CurrentSize: number?,
	NextSize: number?,
}


local PlotService = {}


local basePlotStates: {
	[Model]: BasePlotState
} = {}


local purchaseLocks: {
	[Player]: boolean
} = {}


local function getDefinition(
	level: number
)
	for _, definition in
		PlotConfig.Levels do

		if definition.Level
			== level then

			return definition
		end
	end

	return nil
end


local function getMaximumLevel(): number
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


local function findOwnedPlot(
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


	if cash
		and cash:IsA(
			"IntValue"
		) then

		return cash
	end


	return nil
end


local function getEntranceReference(
	plot: Model
): BasePart?

	local playerSpawn =
		plot:FindFirstChild(
			"PlayerSpawn"
		)


	if playerSpawn
		and playerSpawn:IsA(
			"BasePart"
		) then

		return playerSpawn
	end


	local customerSpawn =
		plot:FindFirstChild(
			"CustomerSpawn"
		)


	if customerSpawn
		and customerSpawn:IsA(
			"BasePart"
		) then

		return customerSpawn
	end


	return nil
end


local function captureBasePlotState(
	plot: Model
): BasePlotState?

	local existing =
		basePlotStates[
			plot
		]


	if existing then
		return existing
	end


	local ground =
		plot:FindFirstChild(
			"Ground"
		)


	if not ground
		or not ground:IsA(
			"BasePart"
		) then

		warn(
			`{plot:GetFullName()} is missing Ground.`
		)

		return nil
	end


	local entrance =
		getEntranceReference(
			plot
		)


	local frontAxis =
		"Z"

	local frontSign =
		1


	if entrance then

		local localPosition =
			ground.CFrame
				:PointToObjectSpace(
					entrance.Position
				)


		-- Determine which side of the square
		-- the entrance is closest to.
		if math.abs(
			localPosition.X
		) > math.abs(
			localPosition.Z
		) then

			frontAxis =
				"X"

			frontSign =
				localPosition.X >= 0
					and 1
					or -1
		else
			frontAxis =
				"Z"

			frontSign =
				localPosition.Z >= 0
					and 1
					or -1
		end
	else
		warn(
			`{plot:GetFullName()} has no PlayerSpawn or CustomerSpawn. Assuming +Z is the front edge.`
		)
	end


	local state: BasePlotState = {
		Ground =
			ground,

		CFrame =
			ground.CFrame,

		Size =
			ground.Size,

		FrontAxis =
			frontAxis,

		FrontSign =
			frontSign,
	}


	basePlotStates[
		plot
	] = state


	return state
end


local function calculateGroundTransform(
	baseState: BasePlotState,
	newSize: number
): (CFrame, Vector3)

	local baseSize =
		baseState.Size


	local localOffset =
		Vector3.zero


	if baseState.FrontAxis
		== "X" then

		localOffset =
			Vector3.new(
				baseState.FrontSign
					* (
						baseSize.X
						- newSize
					)
					/ 2,

				0,
				0
			)

	else
		localOffset =
			Vector3.new(
				0,
				0,

				baseState.FrontSign
					* (
						baseSize.Z
						- newSize
					)
					/ 2
			)
	end


	local targetCFrame =
		baseState.CFrame
			* CFrame.new(
				localOffset
			)


	local targetSize =
		Vector3.new(
			newSize,
			baseSize.Y,
			newSize
		)


	return targetCFrame,
		targetSize
end


local function applySize(
	plot: Model,
	size: number,
	animate: boolean
): boolean

	local baseState =
		captureBasePlotState(
			plot
		)


	if not baseState then
		return false
	end


	local ground =
		baseState.Ground


	if not ground.Parent then
		return false
	end


	local targetCFrame,
		targetSize =
		calculateGroundTransform(
			baseState,
			size
		)


	if animate then

		local tween =
			TweenService:Create(
				ground,

				TweenInfo.new(
					EXPANSION_TWEEN_TIME,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					CFrame =
						targetCFrame,

					Size =
						targetSize,
				}
			)


		tween:Play()
		tween.Completed:Wait()

	else
		ground.CFrame =
			targetCFrame

		ground.Size =
			targetSize
	end


	plot:SetAttribute(
		"PlotSize",
		size
	)


	return true
end


local function createResult(
	success: boolean,
	message: string
): PlotResult

	return {
		Success =
			success,

		Message =
			message,
	}
end


local function buildResult(
	success: boolean,
	message: string,
	currentLevel: number
): PlotResult

	local maximumLevel =
		getMaximumLevel()


	local currentDefinition =
		getDefinition(
			currentLevel
		)


	local nextDefinition =
		getDefinition(
			currentLevel + 1
		)


	return {
		Success =
			success,

		Message =
			message,

		CurrentLevel =
			currentLevel,

		MaximumLevel =
			maximumLevel,

		NextCost =
			nextDefinition
				and nextDefinition.Cost
				or nil,

		DisplayName =
			currentDefinition
				and currentDefinition.DisplayName
				or "Plot",

		Description =
			currentDefinition
				and currentDefinition.Description
				or "Expand your business property.",

		CurrentSize =
			currentDefinition
				and currentDefinition.Size
				or 180,

		NextSize =
			nextDefinition
				and nextDefinition.Size
				or nil,
	}
end


function PlotService.ResetPlot(
	plot: Model
): boolean

	local definition =
		getDefinition(
			0
		)


	if not definition then
		return false
	end


	local applied =
		applySize(
			plot,
			definition.Size,
			false
		)


	if applied then

		plot:SetAttribute(
			"PlotLevel",
			0
		)
	end


	return applied
end


function PlotService.ApplyToPlot(
	player: Player,
	plot: Model,
	animate: boolean?
): boolean

	if not plot
		or not plot:IsA(
			"Model"
		)
		or plot:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

		return false
	end


	local currentLevel =
		DataService.GetPlotLevel(
			player
		)


	currentLevel =
		math.clamp(
			currentLevel,
			0,
			getMaximumLevel()
		)


	local definition =
		getDefinition(
			currentLevel
		)


	if not definition then
		return false
	end


	local applied =
		applySize(
			plot,
			definition.Size,
			animate == true
		)


	if not applied then
		return false
	end


	plot:SetAttribute(
		"PlotLevel",
		currentLevel
	)


	return true
end


function PlotService.GetState(
	player: Player
): PlotResult

	if not DataService.GetProfile(
		player
	) then

		return createResult(
			false,
			"Your data has not loaded yet."
		)
	end


	local currentLevel =
		math.clamp(
			DataService.GetPlotLevel(
				player
			),

			0,
			getMaximumLevel()
		)


	return buildResult(
		true,

		currentLevel
				>= getMaximumLevel()
			and "Maximum plot size reached."
			or "Plot expansion available.",

		currentLevel
	)
end


function PlotService.Purchase(
	player: Player
): PlotResult

	if purchaseLocks[
		player
	] then

		return createResult(
			false,
			"Please wait before purchasing again."
		)
	end


	purchaseLocks[
		player
	] = true


	local function finish(
		result: PlotResult
	): PlotResult

		purchaseLocks[
			player
		] = nil

		return result
	end


	if not DataService.GetProfile(
		player
	) then

		return finish(
			createResult(
				false,
				"Your data has not loaded yet."
			)
		)
	end


	local plot =
		findOwnedPlot(
			player
		)


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
			DataService.GetPlotLevel(
				player
			),

			0,
			maximumLevel
		)


	if currentLevel
		>= maximumLevel then

		return finish(
			buildResult(
				false,
				"Your plot is already at maximum size.",
				currentLevel
			)
		)
	end


	local nextLevel =
		currentLevel + 1


	local nextDefinition =
		getDefinition(
			nextLevel
		)


	if not nextDefinition then

		return finish(
			createResult(
				false,
				"The next plot level is not configured."
			)
		)
	end


	local cost =
		nextDefinition.Cost


	if typeof(cost)
			~= "number"
		or cost < 0 then

		return finish(
			createResult(
				false,
				"The plot expansion cost is invalid."
			)
		)
	end


	local cash =
		getCashValue(
			player
		)


	if not cash then

		return finish(
			createResult(
				false,
				"Your cash value could not be found."
			)
		)
	end


	if cash.Value
		< cost then

		return finish(
			buildResult(
				false,

				`You need ${cost - cash.Value} more.`,

				currentLevel
			)
		)
	end


	cash.Value -=
		cost


	local saved =
		DataService.SetPlotLevel(
			player,
			nextLevel
		)


	if not saved then

		cash.Value +=
			cost


		return finish(
			buildResult(
				false,
				"The plot expansion could not be saved.",
				currentLevel
			)
		)
	end


	local applied =
		PlotService.ApplyToPlot(
			player,
			plot,
			true
		)


	if not applied then

		DataService.SetPlotLevel(
			player,
			currentLevel
		)


		cash.Value +=
			cost


		PlotService.ApplyToPlot(
			player,
			plot,
			false
		)


		return finish(
			buildResult(
				false,
				"The plot expansion could not be applied.",
				currentLevel
			)
		)
	end


	return finish(
		buildResult(
			true,

			`Plot expanded to {nextDefinition.Size} x {nextDefinition.Size}!`,

			nextLevel
		)
	)
end


for _, plot in
	plotsFolder:GetChildren() do

	if plot:IsA(
		"Model"
	) then

		captureBasePlotState(
			plot
		)
	end
end


plotsFolder.ChildAdded:Connect(
	function(
		child: Instance
	)
		if child:IsA(
			"Model"
		) then

			task.defer(
				captureBasePlotState,
				child
			)
		end
	end
)


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)
		purchaseLocks[
			player
		] = nil
	end
)


return PlotService