local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(
	script.Parent
		:WaitForChild("Services")
		:WaitForChild("DataService")
)

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

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

local lemonadeConfig =
	BusinessConfig.LemonadeStand

local MAXIMUM_STANDS =
	lemonadeConfig.MaximumPlaced or 3

local ADDITIONAL_STAND_COST =
	lemonadeConfig.AdditionalStandCost or 750

local placementRequests: {
	[Player]: number
} = {}

local function getPlayerPlot(
	player: Player
): Model?
	for _, plot in plotsFolder:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end

		if plot:GetAttribute("OwnerUserId")
			== player.UserId then

			return plot
		end
	end

	return nil
end

local function getPlacedBusinesses(
	plot: Model
): Folder?
	local folder =
		plot:FindFirstChild("PlacedBusinesses")

	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function getBusinessType(
	business: Model
): string
	local businessType =
		business:GetAttribute("BusinessType")

	if typeof(businessType) == "string"
		and businessType ~= "" then

		return businessType
	end

	if string.match(
		business.Name,
		"^LemonadeStand"
	) then

		return BUSINESS_NAME
	end

	return business.Name
end

local function getLemonadeStands(
	plot: Model
): {Model}
	local folder =
		getPlacedBusinesses(plot)

	if not folder then
		return {}
	end

	local stands = {}

	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		if getBusinessType(child)
			== BUSINESS_NAME then

			table.insert(stands, child)
		end
	end

	return stands
end

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild("leaderstats")

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

local function isFiniteNumber(
	value: number
): boolean
	return value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function isValidCFrame(
	value: any
): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end

	local components = {
		value:GetComponents(),
	}

	for _, component in components do
		if not isFiniteNumber(component) then
			return false
		end
	end

	return true
end

local function getPlacementBoundsAtCFrame(
	template: Model,
	targetPivot: CFrame
): (CFrame?, Vector3?)
	local clone = template:Clone()

	clone:PivotTo(targetPivot)

	local placementBounds =
		clone:FindFirstChild(
			"PlacementBounds",
			true
		)

	if not placementBounds
		or not placementBounds:IsA("BasePart") then

		clone:Destroy()
		return nil, nil
	end

	local boundsCFrame =
		placementBounds.CFrame

	local boundsSize =
		placementBounds.Size

	clone:Destroy()

	return boundsCFrame, boundsSize
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
			boxCFrame:PointToWorldSpace(
				cornerOffset
			)

		local groundSpace =
			ground.CFrame:PointToObjectSpace(
				worldCorner
			)

		if math.abs(groundSpace.X)
				> groundHalfX
			or math.abs(groundSpace.Z)
				> groundHalfZ then

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
		ground.Position.Y
		+ ground.Size.Y / 2

	return math.abs(
		placementCFrame.Position.Y
			- groundTop
	) <= 0.5
end

local function rectanglesOverlapXZ(
	firstCFrame: CFrame,
	firstSize: Vector3,
	secondCFrame: CFrame,
	secondSize: Vector3
): boolean
	local firstRight =
		Vector3.new(
			firstCFrame.RightVector.X,
			0,
			firstCFrame.RightVector.Z
		).Unit

	local firstForward =
		Vector3.new(
			firstCFrame.LookVector.X,
			0,
			firstCFrame.LookVector.Z
		).Unit

	local secondRight =
		Vector3.new(
			secondCFrame.RightVector.X,
			0,
			secondCFrame.RightVector.Z
		).Unit

	local secondForward =
		Vector3.new(
			secondCFrame.LookVector.X,
			0,
			secondCFrame.LookVector.Z
		).Unit

	local offset =
		Vector3.new(
			secondCFrame.Position.X
				- firstCFrame.Position.X,
			0,
			secondCFrame.Position.Z
				- firstCFrame.Position.Z
		)

	local axes = {
		firstRight,
		firstForward,
		secondRight,
		secondForward,
	}

	local firstHalfX =
		firstSize.X / 2

	local firstHalfZ =
		firstSize.Z / 2

	local secondHalfX =
		secondSize.X / 2

	local secondHalfZ =
		secondSize.Z / 2

	for _, axis in axes do
		local distance =
			math.abs(
				offset:Dot(axis)
			)

		local firstRadius =
			math.abs(
				firstRight:Dot(axis)
			) * firstHalfX
			+ math.abs(
				firstForward:Dot(axis)
			) * firstHalfZ

		local secondRadius =
			math.abs(
				secondRight:Dot(axis)
			) * secondHalfX
			+ math.abs(
				secondForward:Dot(axis)
			) * secondHalfZ

		if distance >=
			firstRadius + secondRadius then

			return false
		end
	end

	return true
end

local function overlapsExistingBusiness(
	plot: Model,
	candidateCFrame: CFrame,
	candidateSize: Vector3,
	ignoredBusiness: Model?
): boolean
	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false
	end

	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA("Model")
			or business == ignoredBusiness then

			continue
		end

		local existingBounds =
			business:FindFirstChild(
				"PlacementBounds",
				true
			)

		if not existingBounds
			or not existingBounds:IsA(
				"BasePart"
			) then

			continue
		end

		if rectanglesOverlapXZ(
			candidateCFrame,
			candidateSize,
			existingBounds.CFrame,
			existingBounds.Size
		) then

			return true
		end
	end

	return false
end

local function setModelPlacedState(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function setPromptState(
	model: Model,
	enabled: boolean
)
	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end

		if descendant:GetAttribute(
			"IsLemonadePurchasePrompt"
		) == true then

			descendant.Enabled = false
			continue
		end

		descendant.Enabled = enabled
	end
end

local function canPlaceBusiness(
	player: Player,
	plot: Model,
	businessName: string,
	placementCFrame: CFrame,
	editedStand: Model?
): (boolean, string)
	if businessName ~= BUSINESS_NAME then
		return false, "Unknown business."
	end

	local ground =
		plot:FindFirstChild("Ground")

	if not ground
		or not ground:IsA("BasePart") then

		return false,
			"The plot is missing Ground."
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false,
			"The plot is missing PlacedBusinesses."
	end

	local currentStands =
		getLemonadeStands(plot)

	if not editedStand
		and #currentStands
			>= MAXIMUM_STANDS then

		return false,
			`You can only place {MAXIMUM_STANDS} Lemonade Stands.`
	end

	local template =
		businessModels:FindFirstChild(
			businessName
		)

	if not template
		or not template:IsA("Model") then

		return false,
			"The business model could not be found."
	end

	if not template.PrimaryPart then
		return false,
			"The LemonadeStand needs a PrimaryPart."
	end

	local character = player.Character

	local root =
		character
		and character:FindFirstChild(
			"HumanoidRootPart"
		)

	if root and root:IsA("BasePart") then
		local distance =
			(
				root.Position
				- placementCFrame.Position
			).Magnitude

		if distance
			> MAX_PLACEMENT_DISTANCE then

			return false,
				"The placement is too far away."
		end
	end

	local boxCFrame, boxSize =
		getPlacementBoundsAtCFrame(
			template,
			placementCFrame
		)

	if not boxCFrame or not boxSize then
		return false,
			"The stand is missing PlacementBounds."
	end

	if not isBoundingBoxInsideGround(
		ground,
		boxCFrame,
		boxSize
	) then
		return false,
			"The stand must be fully inside the plot."
	end

	if not isCorrectHeight(
		ground,
		placementCFrame
	) then
		return false,
			"The stand must be placed on the Ground."
	end

	if overlapsExistingBusiness(
	plot,
	boxCFrame,
	boxSize,
	editedStand
) then
	return false,
		"Businesses cannot overlap."
end

	return true, ""
end

placeBusinessRemote.OnServerEvent:Connect(
	function(
		player: Player,
		businessName: string,
		placementCFrame: CFrame
	)
		local currentTime = time()

		local previousRequest =
			placementRequests[player] or 0

		if currentTime - previousRequest
			< 0.25 then

			return
		end

		placementRequests[player] =
			currentTime

		if typeof(businessName) ~= "string"
			or not isValidCFrame(
				placementCFrame
			) then

			return
		end

		local plot =
			getPlayerPlot(player)

		if not plot then
			placeBusinessRemote:FireClient(
				player,
				false,
				"You do not own a plot."
			)

			return
		end

		local editStates =
			_G.BusinessEditStates

		local editState =
			typeof(editStates) == "table"
			and editStates[player]
			or nil

		local editedStand =
			editState
			and editState.stand
			or nil

		local valid, reason =
			canPlaceBusiness(
				player,
				plot,
				businessName,
				placementCFrame,
				editedStand
			)

		if not valid then
			placeBusinessRemote:FireClient(
				player,
				false,
				reason
			)

			return
		end

		if editState then
			local stand =
				editState.stand

			if getBusinessType(stand)
	~= businessName then

	placeBusinessRemote:FireClient(
		player,
		false,
		"The selected business does not match."
	)

	return
end

			if not stand
				or not stand.Parent
				or editState.plot ~= plot then

				placeBusinessRemote:FireClient(
					player,
					false,
					"The Lemonade Stand could not be moved."
				)

				return
			end

			stand:PivotTo(
				placementCFrame
			)

			stand:SetAttribute(
				"StandUnavailable",
				false
			)

			stand:SetAttribute(
				"IsBeingEdited",
				false
			)

			setPromptState(
				stand,
				true
			)

			editStates[player] = nil

			player:SetAttribute(
				"EditingBusiness",
				nil
			)

			placeBusinessRemote:FireClient(
				player,
				true,
				"Lemonade Stand moved!"
			)

			return
		end

		local currentStands =
			getLemonadeStands(plot)

		local standCost =
			#currentStands == 0
			and 0
			or ADDITIONAL_STAND_COST

		local cash = getCashValue(player)

		if not cash then
			placeBusinessRemote:FireClient(
				player,
				false,
				"Your cash could not be found."
			)

			return
		end

		if cash.Value < standCost then
			placeBusinessRemote:FireClient(
				player,
				false,
				`You need ${standCost - cash.Value} more to build another stand.`
			)

			return
		end

		local template =
			businessModels:FindFirstChild(
				businessName
			)

		if not template
			or not template:IsA("Model") then

			return
		end

		local placedBusinesses =
			getPlacedBusinesses(plot)

		if not placedBusinesses then
			return
		end

		local businessId =
			DataService.GenerateBusinessId(
				player,
				businessName
			)

		if not businessId then
			placeBusinessRemote:FireClient(
				player,
				false,
				"Your business data was not ready."
			)

			return
		end

		if standCost > 0 then
			cash.Value -= standCost
		end

		local stand = template:Clone()

		stand.Name = businessId

		stand:SetAttribute(
			"BusinessId",
			businessId
		)

		stand:SetAttribute(
			"BusinessType",
			businessName
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

		stand:SetAttribute(
			"ServingSpeedLevel",
			0
		)

		stand:SetAttribute(
	"TotalSales",
	0
)

stand:SetAttribute(
	"LifetimeEarnings",
	0
)

stand:SetAttribute(
	"CustomersWaiting",
	0
)

		stand:SetAttribute(
			"SaleValueLevel",
			0
		)

		stand:SetAttribute(
			"QueueCapacityLevel",
			0
		)

		stand:SetAttribute(
			"PurchaseCooldown",
			lemonadeConfig.BaseServingCooldown
		)

		stand:SetAttribute(
			"SaleValue",
			lemonadeConfig.BaseSaleValue
		)

		setModelPlacedState(stand)

		stand.Parent = placedBusinesses

		stand:PivotTo(
			placementCFrame
		)

		plot:SetAttribute(
			"StarterBusinessPlaced",
			true
		)

		local newCount =
			#currentStands + 1

		local message

		if standCost == 0 then
			message =
				"Lemonade Stand placed!"
		else
			message =
				`Lemonade Stand placed for ${standCost}!`
		end

		placeBusinessRemote:FireClient(
			player,
			true,
			message,
			newCount,
			MAXIMUM_STANDS
		)
	end
)

Players.PlayerRemoving:Connect(function(
	player
)
	placementRequests[player] = nil
end)