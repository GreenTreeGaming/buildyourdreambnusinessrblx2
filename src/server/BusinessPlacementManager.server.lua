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

local MAX_PLACEMENT_DISTANCE = 250
local EDGE_PADDING = 0.5

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

local function getBusinessConfig(
	businessName: string
): {[any]: any}?

	local config =
		BusinessConfig[
			businessName
		]

	if type(config) ~= "table" then
		return nil
	end

	return config
end


local function getBusinessDisplayName(
	businessName: string
): string

	local config =
		getBusinessConfig(
			businessName
		)

	if not config then
		return businessName
	end

	return config.DisplayName
		or businessName
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

	for businessName in BusinessConfig do

		if business.Name == businessName
			or string.match(
				business.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end

	return business.Name
end

local function getBusinessesOfType(
	plot: Model,
	businessName: string
): {Model}

	local folder =
		getPlacedBusinesses(plot)

	if not folder then
		return {}
	end

	local businesses = {}

	for _, child in
		folder:GetChildren() do

		if not child:IsA("Model") then
			continue
		end

		if getBusinessType(child)
			== businessName then

			table.insert(
				businesses,
				child
			)
		end
	end

	return businesses
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

local PROMPT_ENABLED_ATTRIBUTE =
	"EnabledBeforeBusinessEdit"

local function disablePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants()
	do
		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end

		-- Remember the prompt's original state.
		descendant:SetAttribute(
			PROMPT_ENABLED_ATTRIBUTE,
			descendant.Enabled
		)

		descendant.Enabled = false
	end
end

local function restorePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants()
	do
		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end

		local previousState =
			descendant:GetAttribute(
				PROMPT_ENABLED_ATTRIBUTE
			)

		if typeof(previousState) == "boolean" then
			descendant.Enabled =
				previousState

			descendant:SetAttribute(
				PROMPT_ENABLED_ATTRIBUTE,
				nil
			)
		end
	end
end

local function canPlaceBusiness(
	player: Player,
	plot: Model,
	businessName: string,
	placementCFrame: CFrame,
	editedStand: Model?
): (boolean, string)
	local config =
	getBusinessConfig(
		businessName
	)

if not config then
	return false,
		"Unknown business."
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

	local currentBusinesses =
	getBusinessesOfType(
		plot,
		businessName
	)

local maximumPlaced =
	config.MaximumPlaced
	or 1

if not editedStand
	and #currentBusinesses
		>= maximumPlaced then

	local displayName =
		getBusinessDisplayName(
			businessName
		)

	return false,
		`You can only place {maximumPlaced} {displayName}s.`
end

	local template: Model?

if editedStand then
	-- Validate the actual stand being moved so upgraded
	-- stand dimensions and PlacementBounds are respected.
	template = editedStand
else
	local baseTemplate =
		businessModels:FindFirstChild(
			businessName
		)

	if baseTemplate
		and baseTemplate:IsA("Model") then

		template = baseTemplate
	end
end

if not template then
	return false,
		"The business model could not be found."
end

	if not template.PrimaryPart then
		return false,
			`{businessName} needs a PrimaryPart.`
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


	if not stand
		or not stand.Parent
		or editState.plot ~= plot then

		placeBusinessRemote:FireClient(
			player,
			false,
			"The business could not be moved."
		)

		return
	end


	if getBusinessType(stand)
		~= businessName then

		placeBusinessRemote:FireClient(
			player,
			false,
			"The selected business does not match."
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

	restorePrompts(
		stand
	)

	editStates[player] = nil

	player:SetAttribute(
		"EditingBusiness",
		nil
	)

	placeBusinessRemote:FireClient(
		player,
		true,
		`${getBusinessDisplayName(businessName)} moved!`
	)

	return
end

		local config =
	getBusinessConfig(
		businessName
	)

if not config then
	placeBusinessRemote:FireClient(
		player,
		false,
		"Unknown business."
	)

	return
end


local currentBusinesses =
	getBusinessesOfType(
		plot,
		businessName
	)


local standCost =
	config.AdditionalStandCost
	or 0


if config.FirstStandFree == true
	and #currentBusinesses == 0 then

	standCost = 0
end

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
	"Level",
	1
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
			"QueueCapacity",
			1
		)

		stand:SetAttribute(
	"PurchaseCooldown",
	config.BaseServingCooldown
)

stand:SetAttribute(
	"SaleValue",
	config.BaseSaleValue
)

		setModelPlacedState(stand)

		stand.Parent = placedBusinesses

		stand:PivotTo(
			placementCFrame
		)

		if businessName == "LemonadeStand" then
	plot:SetAttribute(
		"StarterBusinessPlaced",
		true
	)
end

		local newCount =
	#currentBusinesses + 1

		local displayName =
	getBusinessDisplayName(
		businessName
	)

local message

if standCost == 0 then
	message =
		`${displayName} placed!`
else
	message =
		`${displayName} placed for $${standCost}!`
end

		placeBusinessRemote:FireClient(
	player,
	true,
	message,
	newCount,
	config.MaximumPlaced or 1
)
	end
)

Players.PlayerRemoving:Connect(function(
	player
)
	placementRequests[player] = nil
end)