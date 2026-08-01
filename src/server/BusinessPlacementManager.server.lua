local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local placeBusinessRemote =
	remotes:WaitForChild("PlaceBusiness")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local BUSINESS_NAME = "LemonadeStand"

local MAX_PLACEMENT_DISTANCE = 250
local EDGE_PADDING = 0.5

local placementRequests: {[Player]: number} = {}

local function getPlayerPlot(player: Player): Model?
	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end

	return nil
end

local function getPlacedBusinesses(plot: Model): Folder?
	local folder = plot:FindFirstChild("PlacedBusinesses")

	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function isFiniteNumber(value: number): boolean
	return value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function isValidCFrame(value: any): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end

	local components = {value:GetComponents()}

	for _, component in components do
		if not isFiniteNumber(component) then
			return false
		end
	end

	return true
end

local function getBoundingBoxAtCFrame(
	template: Model,
	targetPivot: CFrame
): (CFrame, Vector3)
	local clone = template:Clone()

	clone:PivotTo(targetPivot)

	local boundingBoxCFrame, boundingBoxSize =
		clone:GetBoundingBox()

	clone:Destroy()

	return boundingBoxCFrame, boundingBoxSize
end

local function isBoundingBoxInsideGround(
	ground: BasePart,
	boxCFrame: CFrame,
	boxSize: Vector3
): boolean
	local halfX = boxSize.X / 2
	local halfZ = boxSize.Z / 2

	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	local groundHalfX =
		ground.Size.X / 2 - EDGE_PADDING

	local groundHalfZ =
		ground.Size.Z / 2 - EDGE_PADDING

	for _, cornerOffset in corners do
		local worldCorner =
			boxCFrame:PointToWorldSpace(cornerOffset)

		local groundSpace =
			ground.CFrame:PointToObjectSpace(worldCorner)

		if math.abs(groundSpace.X) > groundHalfX
			or math.abs(groundSpace.Z) > groundHalfZ then

			return false
		end
	end

	return true
end

local function isCorrectHeight(
	ground: BasePart,
	placementCFrame: CFrame
): boolean
	local groundTop =
		ground.Position.Y + ground.Size.Y / 2

	return math.abs(
		placementCFrame.Position.Y - groundTop
	) <= 0.5
end

local function setModelPlacedState(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function getPlacementBoundsAtCFrame(
	template: Model,
	targetPivot: CFrame
): (CFrame?, Vector3?)
	local clone = template:Clone()
	clone:PivotTo(targetPivot)

	local placementBounds =
		clone:FindFirstChild("PlacementBounds", true)

	if not placementBounds
		or not placementBounds:IsA("BasePart") then

		clone:Destroy()
		return nil, nil
	end

	local boundsCFrame = placementBounds.CFrame
	local boundsSize = placementBounds.Size

	clone:Destroy()

	return boundsCFrame, boundsSize
end

local function canPlaceBusiness(
	player: Player,
	plot: Model,
	businessName: string,
	placementCFrame: CFrame,
	isEditing: boolean
): (boolean, string)
	if businessName ~= BUSINESS_NAME then
		return false, "Unknown business."
	end

	local ground = plot:FindFirstChild("Ground")

	if not ground or not ground:IsA("BasePart") then
		return false, "The plot is missing Ground."
	end

	local placedBusinesses = getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false, "The plot is missing PlacedBusinesses."
	end

	if placedBusinesses:FindFirstChild(BUSINESS_NAME)
		and not isEditing then

		return false, "The lemonade stand is already placed."
	end

	local template = businessModels:FindFirstChild(businessName)

	if not template or not template:IsA("Model") then
		return false, "The business model could not be found."
	end

	if not template.PrimaryPart then
		return false, "The LemonadeStand needs a PrimaryPart."
	end

	local playerCharacter = player.Character
	local playerRoot =
		playerCharacter
		and playerCharacter:FindFirstChild("HumanoidRootPart")

	if playerRoot and playerRoot:IsA("BasePart") then
		local distance =
			(playerRoot.Position - placementCFrame.Position).Magnitude

		if distance > MAX_PLACEMENT_DISTANCE then
			return false, "The placement is too far away."
		end
	end

	local boxCFrame, boxSize =
		getPlacementBoundsAtCFrame(
			template,
			placementCFrame
		)

	if not boxCFrame or not boxSize then
		return false, "The stand is missing PlacementBounds."
	end

	if not isBoundingBoxInsideGround(
		ground,
		boxCFrame,
		boxSize
		) then
		return false, "The stand must be fully inside the plot."
	end

	if not isCorrectHeight(
		ground,
		placementCFrame
		) then
		return false, "The stand must be placed on the Ground."
	end

	return true, ""
end

placeBusinessRemote.OnServerEvent:Connect(function(
	player: Player,
	businessName: string,
	placementCFrame: CFrame
)
	local currentTime = time()
	local previousRequest = placementRequests[player] or 0

	if currentTime - previousRequest < 0.25 then
		return
	end

	placementRequests[player] = currentTime

	if typeof(businessName) ~= "string"
		or not isValidCFrame(placementCFrame) then

		return
	end

	local plot = getPlayerPlot(player)

	if not plot then
		placeBusinessRemote:FireClient(
			player,
			false,
			"You do not own a plot."
		)

		return
	end

	local editStates = _G.BusinessEditStates

	local editState =
		typeof(editStates) == "table"
		and editStates[player]
		or nil

	local valid, reason = canPlaceBusiness(
		player,
		plot,
		businessName,
		placementCFrame,
		editState ~= nil
	)

	if not valid then
		placeBusinessRemote:FireClient(
			player,
			false,
			reason
		)

		return
	end

	-- Move the existing stand when the player is editing.
	if editState then
		local stand = editState.stand

		if not stand
			or not stand.Parent
			or editState.plot ~= plot then

			placeBusinessRemote:FireClient(
				player,
				false,
				"The lemonade stand could not be moved."
			)

			return
		end

		stand:PivotTo(placementCFrame)

		stand:SetAttribute(
			"StandUnavailable",
			false
		)

		stand:SetAttribute(
			"IsBeingEdited",
			false
		)

		for _, descendant in stand:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				descendant.Enabled = true
			end
		end

		editStates[player] = nil
		player:SetAttribute("EditingBusiness", nil)

		placeBusinessRemote:FireClient(
			player,
			true,
			"Lemonade stand moved!"
		)

		return
	end

	-- Everything below this point is only for building a new stand.
	local template =
		businessModels:FindFirstChild(businessName)

	if not template or not template:IsA("Model") then
		return
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return
	end

	local stand = template:Clone()
	stand.Name = businessName

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

	setModelPlacedState(stand)

	stand.Parent = placedBusinesses
	stand:PivotTo(placementCFrame)

	plot:SetAttribute(
		"StarterBusinessPlaced",
		true
	)

	placeBusinessRemote:FireClient(
		player,
		true,
		"Lemonade stand placed!"
	)
end)

Players.PlayerRemoving:Connect(function(player)
	placementRequests[player] = nil
end)