local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


local UITheme =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("UITheme")
	)


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local Colors =
	UITheme.Colors

local Fonts =
	UITheme.Fonts


local IS_TOUCH_DEVICE =
	UserInputService.TouchEnabled


local businessModels =
	ReplicatedStorage:WaitForChild(
		"BusinessModels"
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local placeBusinessRemote =
	remotes:WaitForChild(
		"PlaceBusiness"
	)

local interactionResultRemote =
	remotes:WaitForChild(
		"BusinessInteractionResult"
	)

local cancelEditRemote =
	remotes:WaitForChild(
		"CancelBusinessEdit"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


-- The server currently only supports LemonadeStand.
-- The selection menu itself is already data-driven so
-- future businesses will automatically appear.
local DEFAULT_BUSINESS_NAME =
	"LemonadeStand"


local lemonadeConfig =
	BusinessConfig.LemonadeStand


local MAXIMUM_STANDS =
	lemonadeConfig.MaximumPlaced
	or 3


local ROTATION_INCREMENT =
	90

local GRID_SIZE =
	1


local previewModel: Model? =
	nil

local ownedPlot: Model? =
	nil

local originalStand: Model? =
	nil


local currentPlacementCFrame: CFrame? =
	nil

local lastTouchPosition: Vector2? =
	nil


local rotationY =
	0


local isPlacementActive =
	false

local isEditingExistingStand =
	false

local placementValid =
	false

local waitingForServer =
	false


local selectedBusinessName =
	DEFAULT_BUSINESS_NAME


--==================================================
-- PLOT / BUSINESS HELPERS
--==================================================

local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute(
			"PlotName"
		)


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

		return DEFAULT_BUSINESS_NAME
	end


	return business.Name
end


local function getLemonadeStands(): { Model }
	if not ownedPlot then
		return {}
	end


	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return {}
	end


	local stands = {}


	for _, child in
		placedBusinesses:GetChildren() do

		if not child:IsA("Model") then
			continue
		end


		if getBusinessType(child)
			== DEFAULT_BUSINESS_NAME then

			table.insert(
				stands,
				child
			)
		end
	end


	return stands
end


local function getStandCount(): number
	return #getLemonadeStands()
end


local function findStandByBusinessId(
	businessId: string
): Model?

	if not ownedPlot
		or type(businessId) ~= "string"
		or businessId == "" then

		return nil
	end


	local placedBusinesses =
		ownedPlot:FindFirstChild(
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


		if getBusinessType(child)
			~= DEFAULT_BUSINESS_NAME then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		local childBusinessId =
			child:GetAttribute(
				"BusinessId"
			)


		if childBusinessId == businessId
			or child.Name == businessId then

			return child
		end
	end


	return nil
end


--==================================================
-- CUSTOM ADD BUSINESS UI
--==================================================

local screenGui =
	playerGui:WaitForChild(
		"AddBusiness"
	) :: ScreenGui


local addButton =
	screenGui:WaitForChild(
		"Add"
	) :: TextButton


local addFrame =
	screenGui:WaitForChild(
		"AddFrame"
	) :: Frame


local scrollingFrame =
	addFrame:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame


local businessTemplate =
	scrollingFrame:WaitForChild(
		"Template"
	) :: TextButton


local businessMenuOpen =
	false


local originalAddFramePosition =
	addFrame.Position

local originalAddFrameSize =
	addFrame.Size


local activeAddFrameTween:
	Tween? =
	nil


local function scaleUDim2(
	value: UDim2,
	scale: number
): UDim2

	return UDim2.new(
		value.X.Scale * scale,
		value.X.Offset * scale,

		value.Y.Scale * scale,
		value.Y.Offset * scale
	)
end


local function getCenteredScaledPosition(
	position: UDim2,
	size: UDim2,
	anchorPoint: Vector2,
	scale: number
): UDim2

	local scaledSize =
		scaleUDim2(
			size,
			scale
		)


	local differenceXScale =
		size.X.Scale
		- scaledSize.X.Scale

	local differenceXOffset =
		size.X.Offset
		- scaledSize.X.Offset

	local differenceYScale =
		size.Y.Scale
		- scaledSize.Y.Scale

	local differenceYOffset =
		size.Y.Offset
		- scaledSize.Y.Offset


	return UDim2.new(
		position.X.Scale
			+ (
				0.5
				- anchorPoint.X
			)
			* differenceXScale,

		position.X.Offset
			+ (
				0.5
				- anchorPoint.X
			)
			* differenceXOffset,

		position.Y.Scale
			+ (
				0.5
				- anchorPoint.Y
			)
			* differenceYScale,

		position.Y.Offset
			+ (
				0.5
				- anchorPoint.Y
			)
			* differenceYOffset
	)
end


local CLOSED_MENU_SCALE =
	0.9


local closedAddFrameSize =
	scaleUDim2(
		originalAddFrameSize,
		CLOSED_MENU_SCALE
	)


local closedAddFramePosition =
	getCenteredScaledPosition(
		originalAddFramePosition,
		originalAddFrameSize,
		addFrame.AnchorPoint,
		CLOSED_MENU_SCALE
	)


local function stopAddFrameTween()
	if activeAddFrameTween then
		activeAddFrameTween:Cancel()

		activeAddFrameTween =
			nil
	end
end


local function showAddButton()
	if isPlacementActive
		or isEditingExistingStand then

		return
	end


	addButton.Visible =
		true
end


local function hideAddButton()
	addButton.Visible =
		false
end


local function openBusinessMenu()
	if businessMenuOpen
		or isPlacementActive then

		return
	end


	businessMenuOpen =
		true


	stopAddFrameTween()


	addFrame.Position =
		closedAddFramePosition

	addFrame.Size =
		closedAddFrameSize

	addFrame.Visible =
		true


	local tween =
		TweenService:Create(
			addFrame,
			TweenInfo.new(
				0.22,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Position =
					originalAddFramePosition,

				Size =
					originalAddFrameSize,
			}
		)


	activeAddFrameTween =
		tween


	tween.Completed:Once(function()
		if activeAddFrameTween
			== tween then

			activeAddFrameTween =
				nil
		end
	end)


	tween:Play()
end


local function closeBusinessMenu(
	immediate: boolean?
)
	if not businessMenuOpen
		and not addFrame.Visible then

		return
	end


	businessMenuOpen =
		false


	stopAddFrameTween()


	if immediate then
		addFrame.Visible =
			false

		addFrame.Position =
			originalAddFramePosition

		addFrame.Size =
			originalAddFrameSize

		return
	end


	local tween =
		TweenService:Create(
			addFrame,
			TweenInfo.new(
				0.13,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Position =
					closedAddFramePosition,

				Size =
					closedAddFrameSize,
			}
		)


	activeAddFrameTween =
		tween


	tween.Completed:Once(function()
		if activeAddFrameTween
			~= tween then

			return
		end


		activeAddFrameTween =
			nil


		if businessMenuOpen then
			return
		end


		addFrame.Visible =
			false

		addFrame.Position =
			originalAddFramePosition

		addFrame.Size =
			originalAddFrameSize
	end)


	tween:Play()
end


local function setBuildMenuVisible(
	visible: boolean
)
	if visible then
		showAddButton()

		return
	end


	hideAddButton()

	closeBusinessMenu(
		true
	)
end


--==================================================
-- PLACEMENT STATUS + CONTROLS
--==================================================

local statusLabel =
	Instance.new(
		"TextLabel"
	)

statusLabel.Name =
	"PlacementStatus"

statusLabel.AnchorPoint =
	Vector2.new(
		0.5,
		0
	)

statusLabel.Position =
	UDim2.fromScale(
		0.5,
		0.055
	)

statusLabel.Size =
	UDim2.fromScale(
		0.52,
		0.075
	)

statusLabel.BackgroundColor3 =
	Colors.Surface

statusLabel.BackgroundTransparency =
	0.03

statusLabel.BorderSizePixel =
	0

statusLabel.Text =
	""

statusLabel.Visible =
	false

statusLabel.ZIndex =
	15

statusLabel.Parent =
	screenGui


UITheme.AddCorner(
	statusLabel,
	0.25
)


UITheme.AddStroke(
	statusLabel,
	Colors.Stroke,
	1.5,
	0.2
)


UITheme.StyleText(
	statusLabel,
	11,
	17,
	Colors.Text,
	Fonts.Bold
)


local placementControls =
	Instance.new(
		"Frame"
	)

placementControls.Name =
	"PlacementControls"

placementControls.AnchorPoint =
	Vector2.new(
		0.5,
		1
	)

placementControls.Position =
	UDim2.fromScale(
		0.5,
		0.96
	)

placementControls.Size =
	UDim2.fromScale(
		0.5,
		0.095
	)

placementControls.BackgroundColor3 =
	Colors.Surface

placementControls.BackgroundTransparency =
	0.02

placementControls.BorderSizePixel =
	0

placementControls.Visible =
	false

placementControls.ZIndex =
	20

placementControls.Parent =
	screenGui


UITheme.AddCorner(
	placementControls,
	0.18
)


UITheme.AddStroke(
	placementControls,
	Colors.Primary,
	1.5,
	0.25
)


UITheme.AddPadding(
	placementControls,
	0.035,
	0.035,
	0.14,
	0.14
)


local controlLayout =
	Instance.new(
		"UIListLayout"
	)

controlLayout.FillDirection =
	Enum.FillDirection.Horizontal

controlLayout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

controlLayout.VerticalAlignment =
	Enum.VerticalAlignment.Center

controlLayout.Padding =
	UDim.new(
		0.035,
		0
	)

controlLayout.Parent =
	placementControls


local function createControlButton(
	name: string,
	text: string,
	topColor: Color3,
	bottomColor: Color3
): TextButton

	local button =
		Instance.new(
			"TextButton"
		)


	button.Name =
		name

	button.Size =
		UDim2.fromScale(
			0.31,
			1
		)

	button.Text =
		text

	button.ZIndex =
		21

	button.Parent =
		placementControls


	UITheme.StyleText(
		button,
		10,
		16,
		Colors.Text,
		Fonts.Black
	)


	UITheme.StyleButton(
		button,
		topColor,
		bottomColor
	)


	button.TextColor3 =
		Colors.Text

	button.TextTransparency =
		0


	return button
end


local rotateButton =
	createControlButton(
		"RotateButton",
		"ROTATE",
		Colors.Info,
		Colors.InfoDark
	)


local placeButton =
	createControlButton(
		"PlaceButton",
		"PLACE",
		Colors.Success,
		Colors.SuccessDark
	)


local cancelPlacementButton =
	createControlButton(
		"CancelButton",
		"CANCEL",
		Colors.Danger,
		Colors.DangerDark
	)


local function updateResponsiveLayout()
	local camera =
		Workspace.CurrentCamera


	if not camera then
		return
	end


	local viewport =
		camera.ViewportSize


	local portrait =
		viewport.Y
		> viewport.X


	local compact =
		viewport.X < 800
		or viewport.Y < 550


	if portrait then
		placementControls.Size =
			UDim2.fromScale(
				0.94,
				0.1
			)

		statusLabel.Size =
			UDim2.fromScale(
				0.9,
				0.07
			)

	elseif compact then

		placementControls.Size =
			UDim2.fromScale(
				0.68,
				0.13
			)

		statusLabel.Size =
			UDim2.fromScale(
				0.65,
				0.1
			)

	else

		placementControls.Size =
			UDim2.fromScale(
				0.5,
				0.095
			)

		statusLabel.Size =
			UDim2.fromScale(
				0.52,
				0.075
			)
	end
end


updateResponsiveLayout()


local camera =
	Workspace.CurrentCamera


if camera then
	camera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(
		updateResponsiveLayout
	)
end


Workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(function()
	local newCamera =
		Workspace.CurrentCamera


	if not newCamera then
		return
	end


	updateResponsiveLayout()


	newCamera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(
		updateResponsiveLayout
	)
end)


--==================================================
-- STATUS
--==================================================

local statusVersion =
	0


local function showStatus(
	message: string,
	duration: number?
)
	statusVersion += 1


	local version =
		statusVersion


	statusLabel.Text =
		message

	statusLabel.Visible =
		true


	if duration then
		task.delay(
			duration,
			function()
				if statusVersion
					== version then

					statusLabel.Visible =
						false
				end
			end
		)
	end
end


--==================================================
-- PREVIEW
--==================================================

local function setOriginalStandVisible(
	visible: boolean
)
	if not originalStand then
		return
	end


	for _, descendant in
		originalStand:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			descendant.LocalTransparencyModifier =
				visible
					and 0
					or 1

		elseif descendant:IsA(
			"BillboardGui"
		) then

			descendant.Enabled =
				visible
		end
	end
end


local function createPlacementBox(
	model: Model
)
	local placementBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)


	if not placementBounds
		or not placementBounds:IsA(
			"BasePart"
		) then

		warn(
			`${model.Name} preview is missing PlacementBounds.`
		)

		return
	end


	local selectionBox =
		Instance.new(
			"SelectionBox"
		)


	selectionBox.Name =
		"PlacementBox"

	selectionBox.Adornee =
		placementBounds

	selectionBox.LineThickness =
		0.08

	selectionBox.SurfaceTransparency =
		0.82

	selectionBox.Color3 =
		Colors.Success

	selectionBox.SurfaceColor3 =
		Colors.Success

	selectionBox.Parent =
		model
end


local function preparePreview(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			descendant.Anchored =
				true

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false

			descendant.Transparency =
				math.max(
					descendant.Transparency,
					0.45
				)

		elseif descendant:IsA("Script")
			or descendant:IsA(
				"LocalScript"
			) then

			descendant.Enabled =
				false

		elseif descendant:IsA(
			"ProximityPrompt"
		) then

			descendant.Enabled =
				false

		elseif descendant:IsA(
			"BillboardGui"
		) then

			descendant.Enabled =
				false
		end
	end


	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		"PlacementHighlight"

	highlight.FillTransparency =
		0.7

	highlight.OutlineTransparency =
		0

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.Parent =
		model


	createPlacementBox(
		model
	)
end


local function setPreviewColor(
	valid: boolean
)
	if not previewModel then
		return
	end


	local highlight =
		previewModel:FindFirstChild(
			"PlacementHighlight"
		)


	local placementBox =
		previewModel:FindFirstChild(
			"PlacementBox"
		)


	local fillColor:
		Color3

	local outlineColor:
		Color3


	if valid then
		fillColor =
			Colors.Success

		outlineColor =
			Colors.SuccessDark
	else
		fillColor =
			Colors.Danger

		outlineColor =
			Colors.DangerDark
	end


	if highlight
		and highlight:IsA(
			"Highlight"
		) then

		highlight.FillColor =
			fillColor

		highlight.OutlineColor =
			outlineColor
	end


	if placementBox
		and placementBox:IsA(
			"SelectionBox"
		) then

		placementBox.Color3 =
			fillColor

		placementBox.SurfaceColor3 =
			fillColor
	end
end


--==================================================
-- PLACEMENT MATH
--==================================================

local function snapToGrid(
	value: number
): number

	return math.round(
		value / GRID_SIZE
	) * GRID_SIZE
end


local function getPlacementCFrame(
	hitPosition: Vector3,
	ground: BasePart
): CFrame

	local groundPosition =
		ground.CFrame
			:PointToObjectSpace(
				hitPosition
			)


	local localX =
		snapToGrid(
			groundPosition.X
		)


	local localZ =
		snapToGrid(
			groundPosition.Z
		)


	return ground.CFrame
		* CFrame.new(
			localX,
			ground.Size.Y / 2,
			localZ
		)
		* CFrame.Angles(
			0,
			math.rad(rotationY),
			0
		)
end


local function isPreviewInsideGround(
	model: Model,
	ground: BasePart
): boolean

	local placementBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)


	if not placementBounds
		or not placementBounds:IsA(
			"BasePart"
		) then

		return false
	end


	local halfX =
		placementBounds.Size.X / 2

	local halfZ =
		placementBounds.Size.Z / 2


	local corners = {
		Vector3.new(
			-halfX,
			0,
			-halfZ
		),

		Vector3.new(
			-halfX,
			0,
			halfZ
		),

		Vector3.new(
			halfX,
			0,
			-halfZ
		),

		Vector3.new(
			halfX,
			0,
			halfZ
		),
	}


	for _, cornerOffset in
		corners do

		local worldCorner =
			placementBounds.CFrame
				:PointToWorldSpace(
					cornerOffset
				)


		local groundSpace =
			ground.CFrame
				:PointToObjectSpace(
					worldCorner
				)


		if math.abs(
			groundSpace.X
		) > ground.Size.X / 2
			or math.abs(
				groundSpace.Z
			) > ground.Size.Z / 2 then

			return false
		end
	end


	return true
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
				offset:Dot(
					axis
				)
			)


		local firstRadius =
			math.abs(
				firstRight:Dot(
					axis
				)
			) * firstHalfX

			+ math.abs(
				firstForward:Dot(
					axis
				)
			) * firstHalfZ


		local secondRadius =
			math.abs(
				secondRight:Dot(
					axis
				)
			) * secondHalfX

			+ math.abs(
				secondForward:Dot(
					axis
				)
			) * secondHalfZ


		if distance >=
			firstRadius
				+ secondRadius then

			return false
		end
	end


	return true
end


local function isPreviewOverlappingBusiness(
	model: Model
): boolean

	if not ownedPlot then
		return false
	end


	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not placedBusinesses then
		return false
	end


	local previewBounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)


	if not previewBounds
		or not previewBounds:IsA(
			"BasePart"
		) then

		return true
	end


	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA(
			"Model"
		)
			or business
				== originalStand then

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
			previewBounds.CFrame,
			previewBounds.Size,
			existingBounds.CFrame,
			existingBounds.Size
		) then

			return true
		end
	end


	return false
end


--==================================================
-- PLACEMENT STATE
--==================================================

local function destroyPreview()
	if previewModel then
		previewModel:Destroy()

		previewModel =
			nil
	end


	currentPlacementCFrame =
		nil

	placementValid =
		false

	waitingForServer =
		false

	isPlacementActive =
		false
end


local function finishPlacementMode()
	destroyPreview()


	setOriginalStandVisible(
		true
	)


	originalStand =
		nil

	isEditingExistingStand =
		false


	placementControls.Visible =
		false
end


local function startPlacement(
	editingExisting: boolean,
	businessId: string?,
	businessName: string?
)
	if isPlacementActive then
		return
	end


	local requestedBusiness =
		businessName
		or DEFAULT_BUSINESS_NAME


	-- IMPORTANT:
	-- BusinessPlacementManager currently accepts
	-- LemonadeStand only.
	if requestedBusiness
		~= DEFAULT_BUSINESS_NAME then

		showStatus(
			"This business cannot be placed yet.",
			2
		)

		showAddButton()

		return
	end


	selectedBusinessName =
		requestedBusiness


	ownedPlot =
		getOwnedPlot()


	if not ownedPlot then
		showStatus(
			"Waiting for your plot...",
			2
		)

		showAddButton()

		return
	end


	local existingStand:
		Model? =
		nil


	if editingExisting then
		if type(businessId)
			~= "string"
			or businessId == "" then

			showStatus(
				"The selected lemonade stand could not be identified.",
				2
			)

			cancelEditRemote
				:FireServer()

			return
		end


		existingStand =
			findStandByBusinessId(
				businessId
			)
	end


	if not editingExisting
		and getStandCount()
			>= MAXIMUM_STANDS then

		showStatus(
			`You can only place {MAXIMUM_STANDS} Lemonade Stands.`,
			2
		)

		showAddButton()

		return
	end


	if editingExisting
		and not existingStand then

		showStatus(
			"Your lemonade stand could not be found.",
			2
		)

		cancelEditRemote
			:FireServer()

		return
	end


	local previewSource:
		Model? =
		nil


	if editingExisting then
		-- Use the actual placed stand while editing so
		-- appearance upgrades and dimensions are preserved.
		previewSource =
			existingStand

	else
		local baseTemplate =
			businessModels:FindFirstChild(
				selectedBusinessName
			)


		if baseTemplate
			and baseTemplate:IsA(
				"Model"
			) then

			previewSource =
				baseTemplate
		end
	end


	if not previewSource then
		warn(
			`The {selectedBusinessName} preview source could not be found.`
		)


		if editingExisting then
			cancelEditRemote
				:FireServer()
		else
			showAddButton()
		end


		return
	end


	if not previewSource.PrimaryPart then
		warn(
			`${previewSource:GetFullName()} needs PlacementOrigin set as its PrimaryPart.`
		)


		if editingExisting then
			cancelEditRemote
				:FireServer()
		else
			showAddButton()
		end


		return
	end


	previewModel =
		previewSource:Clone()


	previewModel.Name =
		`${selectedBusinessName}Preview`


	preparePreview(
		previewModel
	)


	previewModel.Parent =
		Workspace


	isEditingExistingStand =
		editingExisting


	if editingExisting then
		originalStand =
			existingStand


		setOriginalStandVisible(
			false
		)


		rotationY =
			math.deg(
				select(
					2,
					existingStand
						:GetPivot()
						:ToOrientation()
				)
			)


		previewModel:PivotTo(
			existingStand:GetPivot()
		)

	else
		originalStand =
			nil

		rotationY =
			0
	end


	isPlacementActive =
		true

	waitingForServer =
		false

	placementValid =
		false


	setBuildMenuVisible(
		false
	)


	placementControls.Visible =
		true


	showStatus(
		IS_TOUCH_DEVICE
			and "Move the preview, then tap Place."
			or "Click to place  •  R rotate  •  Esc cancel"
	)
end


local function rotatePlacement()
	if not isPlacementActive then
		return
	end


	rotationY =
		(
			rotationY
				+ ROTATION_INCREMENT
		) % 360
end


local function cancelPlacement()
	if not isPlacementActive then
		return
	end


	local wasEditing =
		isEditingExistingStand


	finishPlacementMode()


	statusLabel.Visible =
		false


	if wasEditing then
		cancelEditRemote
			:FireServer()
	else
		setBuildMenuVisible(
			true
		)
	end
end


local function requestCurrentPlacement()
	if not isPlacementActive
		or waitingForServer then

		return
	end


	if not placementValid
		or not currentPlacementCFrame then

		showStatus(
			"The stand must be inside your plot and cannot overlap another business.",
			1.75
		)

		return
	end


	waitingForServer =
		true


	placeBusinessRemote:FireServer(
		selectedBusinessName,
		currentPlacementCFrame
	)


	showStatus(
		isEditingExistingStand
			and "Moving lemonade stand..."
			or "Building lemonade stand..."
	)
end


--==================================================
-- BUSINESS SELECTOR
--==================================================

local businessButtons: {
	[string]: TextButton
} = {}


local function clearBusinessButtons()
	for businessName, button in
		businessButtons do

		if button.Parent then
			button:Destroy()
		end


		businessButtons[
			businessName
		] = nil
	end
end


local function getBusinessNames(): { string }
	local names = {}


	for businessName, config in
		BusinessConfig do

		if type(businessName)
			~= "string"
			or type(config)
				~= "table" then

			continue
		end


		table.insert(
			names,
			businessName
		)
	end


	table.sort(
		names,
		function(
			first: string,
			second: string
		): boolean

			local firstConfig =
				BusinessConfig[
					first
				]

			local secondConfig =
				BusinessConfig[
					second
				]


			local firstName =
				firstConfig.DisplayName
				or first

			local secondName =
				secondConfig.DisplayName
				or second


			return string.lower(
				firstName
			) < string.lower(
				secondName
			)
		end
	)


	return names
end


local function populateBusinessList()
	clearBusinessButtons()


	businessTemplate.Visible =
		false


	local businessNames =
		getBusinessNames()


	for index, businessName in
		businessNames do

		local config =
			BusinessConfig[
				businessName
			]


		local button =
			businessTemplate:Clone()


		button.Name =
			businessName

		button.LayoutOrder =
			index

		button.Visible =
			true

		button.Active =
			true

		button.Selectable =
			true

		button.Parent =
			scrollingFrame


		local title =
			button:FindFirstChild(
				"Title"
			)


		if title
			and title:IsA(
				"TextLabel"
			) then

			title.Text =
				config.DisplayName
				or businessName
		end


		button.Activated:Connect(
			function()
				if isPlacementActive then
					return
				end


				-- Hide the selection UI immediately so
				-- placement feels responsive.
				closeBusinessMenu(
					true
				)

				hideAddButton()


				startPlacement(
					false,
					nil,
					businessName
				)
			end
		)


		businessButtons[
			businessName
		] = button
	end
end


addButton.Activated:Connect(
	function()
		if isPlacementActive then
			return
		end


		if businessMenuOpen then
			closeBusinessMenu()
		else
			openBusinessMenu()
		end
	end
)


--==================================================
-- PLACEMENT BUTTONS
--==================================================

rotateButton.Activated:Connect(
	rotatePlacement
)


placeButton.Activated:Connect(
	requestCurrentPlacement
)


cancelPlacementButton.Activated:Connect(
	cancelPlacement
)


--==================================================
-- INPUT
--==================================================

UserInputService.InputChanged:Connect(
	function(
		input: InputObject
	)
		if input.UserInputType
			== Enum.UserInputType.Touch then

			lastTouchPosition =
				Vector2.new(
					input.Position.X,
					input.Position.Y
				)
		end
	end
)


UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		gameProcessed: boolean
	)
		if gameProcessed
			or not isPlacementActive then

			return
		end


		if input.UserInputType
			== Enum.UserInputType.Touch then

			lastTouchPosition =
				Vector2.new(
					input.Position.X,
					input.Position.Y
				)

			return
		end


		if input.KeyCode
			== Enum.KeyCode.R then

			rotatePlacement()

			return
		end


		if input.KeyCode
			== Enum.KeyCode.Escape then

			cancelPlacement()

			return
		end


		if input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			requestCurrentPlacement()
		end
	end
)


--==================================================
-- PREVIEW MOVEMENT
--==================================================

RunService.RenderStepped:Connect(
	function()
		if not isPlacementActive
			or not previewModel
			or not ownedPlot then

			return
		end


		local ground =
			ownedPlot:FindFirstChild(
				"Ground"
			)


		if not ground
			or not ground:IsA(
				"BasePart"
			) then

			placementValid =
				false

			setPreviewColor(
				false
			)

			return
		end


		local currentCamera =
			Workspace.CurrentCamera


		if not currentCamera then
			return
		end


		local pointerPosition =
			lastTouchPosition
			or UserInputService
				:GetMouseLocation()


		local ray =
			currentCamera
				:ViewportPointToRay(
					pointerPosition.X,
					pointerPosition.Y
				)


		local raycastParams =
			RaycastParams.new()


		raycastParams.FilterType =
			Enum.RaycastFilterType.Include


		raycastParams.FilterDescendantsInstances = {
			ground,
		}


		local result =
			Workspace:Raycast(
				ray.Origin,
				ray.Direction * 1000,
				raycastParams
			)


		if not result then
			placementValid =
				false

			setPreviewColor(
				false
			)

			return
		end


		currentPlacementCFrame =
			getPlacementCFrame(
				result.Position,
				ground
			)


		previewModel:PivotTo(
			currentPlacementCFrame
		)


		local insideGround =
			isPreviewInsideGround(
				previewModel,
				ground
			)


		local overlapping =
			isPreviewOverlappingBusiness(
				previewModel
			)


		placementValid =
			insideGround
			and not overlapping


		setPreviewColor(
			placementValid
		)
	end
)


--==================================================
-- SERVER PLACEMENT RESULT
--==================================================

placeBusinessRemote.OnClientEvent:Connect(
	function(
		success: boolean,
		message: string
	)
		waitingForServer =
			false


		if success then
			finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			task.defer(
				function()
					setBuildMenuVisible(
						getStandCount()
							< MAXIMUM_STANDS
					)
				end
			)


			showStatus(
				message ~= ""
					and message
					or "Lemonade stand placed!",
				2
			)


			return
		end


		showStatus(
			message ~= ""
				and message
				or "The stand could not be placed.",
			2
		)
	end
)


--==================================================
-- BUSINESS MANAGEMENT EVENTS
--==================================================

interactionResultRemote.OnClientEvent:Connect(
	function(
		action: string,
		message: any,
		businessId: any
	)
		if action
			== "ShowRemoveConfirmation" then

			-- BusinessManagementClient owns
			-- this interface.
			return
		end


		if action
			== "BeginEdit" then

			if typeof(businessId)
				~= "string"
				or businessId == "" then

				showStatus(
					"The selected lemonade stand could not be identified.",
					2
				)

				cancelEditRemote
					:FireServer()

				return
			end


			closeBusinessMenu(
				true
			)

			hideAddButton()


			startPlacement(
				true,
				businessId,
				DEFAULT_BUSINESS_NAME
			)


			return
		end


		if action
			== "Removed" then

			finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			task.defer(
				function()
					setBuildMenuVisible(
						getStandCount()
							< MAXIMUM_STANDS
					)
				end
			)


			showStatus(
				typeof(message)
					== "string"
					and message
					or "Lemonade stand removed.",
				2
			)


			return
		end


		if action
			== "RemoveFailed" then

			showStatus(
				typeof(message)
					== "string"
					and message
					or "The stand could not be removed.",
				2
			)


			return
		end


		if action
			== "EditCancelled" then

			finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			setBuildMenuVisible(
				getStandCount()
					< MAXIMUM_STANDS
			)


			showStatus(
				typeof(message)
					== "string"
					and message
					or "Editing cancelled.",
				2
			)
		end
	end
)


--==================================================
-- INITIALIZATION
--==================================================

businessTemplate.Visible =
	false

addFrame.Visible =
	false

addFrame.Position =
	originalAddFramePosition

addFrame.Size =
	originalAddFrameSize


populateBusinessList()


ownedPlot =
	getOwnedPlot()


if ownedPlot then
	setBuildMenuVisible(
		getStandCount()
			< MAXIMUM_STANDS
	)
else
	setBuildMenuVisible(
		false
	)
end


-- Keep the button synchronized as the player's
-- plot/business state changes.
task.spawn(
	function()
		while screenGui.Parent do
			ownedPlot =
				getOwnedPlot()


			if ownedPlot
				and not isPlacementActive
				and not isEditingExistingStand then

				setBuildMenuVisible(
					getStandCount()
						< MAXIMUM_STANDS
				)
			else
				setBuildMenuVisible(
					false
				)
			end


			task.wait(
				0.5
			)
		end
	end
)