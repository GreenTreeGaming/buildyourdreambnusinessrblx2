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

local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)

local Notification =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Notification")
	)


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local businessButtons: {
	[string]: TextButton
} = {}


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


local DEFAULT_BUSINESS_NAME =
	"LemonadeStand"

local placementGridFolder: Folder? =
	nil

local GRID_LINE_HEIGHT =
	0.035

local GRID_LINE_THICKNESS =
	0.025

local GRID_FREE_COLOR =
	Color3.fromRGB(255, 255, 255)

local GRID_OCCUPIED_COLOR =
	Color3.fromRGB(255, 80, 80)

local GRID_SELECTED_COLOR =
	Color3.fromRGB(90, 255, 120)


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
-- CUSTOM UI
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


local addButtons =
	screenGui:WaitForChild(
		"AddButtons"
	) :: Frame


local rotateButton =
	addButtons:WaitForChild(
		"Rotate"
	) :: TextButton


local placeButton =
	addButtons:WaitForChild(
		"Place"
	) :: TextButton


local cancelButton =
	addButtons:WaitForChild(
		"Cancel"
	) :: TextButton

local function preparePlacementButton(
	button: TextButton
)
	button.Active = true
	button.Selectable = true
	button.AutoButtonColor = false

	-- Make sure the button itself receives the input,
	-- not the text sitting inside of it.
	local text =
		button:FindFirstChild("X")

	if text
		and text:IsA("GuiObject") then

		text.Active = false
		text.Selectable = false
	end

	-- Keep these controls above the placement notice
	-- and other UI in this ScreenGui.
	button.ZIndex = 20

	for _, descendant in
		button:GetDescendants() do

		if descendant:IsA("GuiObject") then
			descendant.ZIndex =
				math.max(
					descendant.ZIndex,
					21
				)

			descendant.Active = false
		end
	end
end


addButtons.ZIndex = 19

preparePlacementButton(
	rotateButton
)

preparePlacementButton(
	placeButton
)

preparePlacementButton(
	cancelButton
)


local noticeWhilePlacing =
	screenGui:WaitForChild(
		"NoticeWhilePlacing"
	) :: Frame


local noticeText =
	noticeWhilePlacing:WaitForChild(
		"X"
	) :: TextLabel


--==================================================
-- STORED UI POSITIONS
--==================================================

local addFrameOpenPosition =
	addFrame.Position

local addFrameOpenSize =
	addFrame.Size


local addButtonsOpenPosition =
	addButtons.Position


local noticeOpenPosition =
	noticeWhilePlacing.Position


local addButtonsHiddenPosition =
	UDim2.new(
		addButtonsOpenPosition.X.Scale,
		addButtonsOpenPosition.X.Offset,
		addButtonsOpenPosition.Y.Scale,
		addButtonsOpenPosition.Y.Offset + 26
	)


local noticeHiddenPosition =
	UDim2.new(
		noticeOpenPosition.X.Scale,
		noticeOpenPosition.X.Offset,
		noticeOpenPosition.Y.Scale,
		noticeOpenPosition.Y.Offset - 18
	)


local businessMenuOpen =
	false


local activeAddFrameTween:
	Tween? =
	nil


local activeAddButtonsTween:
	Tween? =
	nil


local activeNoticeTween:
	Tween? =
	nil


--==================================================
-- BASIC BUSINESS HELPERS
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

local function getBusinessesOfType(
	businessName: string
): { Model }

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


	local businesses = {}


	for _, child in
		placedBusinesses:GetChildren() do

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


local function getBusinessCount(
	businessName: string
): number

	return #getBusinessesOfType(
		businessName
	)
end


local function canPlaceAnyBusiness(): boolean
	for businessName, config in
		BusinessConfig do

		if typeof(businessName) ~= "string"
			or type(config) ~= "table" then

			continue
		end


		local maximumPlaced =
			config.MaximumPlaced
			or math.huge


		if getBusinessCount(
			businessName
		) < maximumPlaced then

			return true
		end
	end


	return false
end

local function getBusinessButtonText(
	businessName: string,
	config: {[any]: any}
): string

	local displayName =
		config.DisplayName
		or businessName


	local businessCount =
		getBusinessCount(
			businessName
		)


	if config.FirstStandFree == true
		and businessCount == 0 then

		return `{displayName} - FREE`
	end


	local price =
		config.AdditionalStandCost
		or 0


	return `{displayName} - ${FormatNumber.Compact(price)}`
end

local function updateBusinessButtonTexts()
	for businessName, button in
		businessButtons do

		local config =
			BusinessConfig[businessName]

		if not config then
			continue
		end

		local title =
			button:FindFirstChild(
				"Title"
			)

		if title
			and title:IsA("TextLabel") then

			title.Text =
				getBusinessButtonText(
					businessName,
					config
				)
		end
	end
end

local function findStandByBusinessId(
	businessId: string
): Model?

	if not ownedPlot
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
-- ADD FRAME ANIMATION
--==================================================

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


	local xScaleDifference =
		size.X.Scale
		- scaledSize.X.Scale

	local xOffsetDifference =
		size.X.Offset
		- scaledSize.X.Offset


	local yScaleDifference =
		size.Y.Scale
		- scaledSize.Y.Scale

	local yOffsetDifference =
		size.Y.Offset
		- scaledSize.Y.Offset


	return UDim2.new(
		position.X.Scale
			+ (
				0.5
				- anchorPoint.X
			)
			* xScaleDifference,

		position.X.Offset
			+ (
				0.5
				- anchorPoint.X
			)
			* xOffsetDifference,

		position.Y.Scale
			+ (
				0.5
				- anchorPoint.Y
			)
			* yScaleDifference,

		position.Y.Offset
			+ (
				0.5
				- anchorPoint.Y
			)
			* yOffsetDifference
	)
end


local ADD_FRAME_CLOSED_SCALE =
	0.9


local addFrameClosedSize =
	scaleUDim2(
		addFrameOpenSize,
		ADD_FRAME_CLOSED_SCALE
	)


local addFrameClosedPosition =
	getCenteredScaledPosition(
		addFrameOpenPosition,
		addFrameOpenSize,
		addFrame.AnchorPoint,
		ADD_FRAME_CLOSED_SCALE
	)


local function stopAddFrameTween()
	if activeAddFrameTween then
		activeAddFrameTween:Cancel()

		activeAddFrameTween =
			nil
	end
end


local function openBusinessMenu()
	if businessMenuOpen
		or isPlacementActive then

		return
	end

	updateBusinessButtonTexts()

	businessMenuOpen =
		true


	stopAddFrameTween()


	addFrame.Position =
		addFrameClosedPosition

	addFrame.Size =
		addFrameClosedSize

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
					addFrameOpenPosition,

				Size =
					addFrameOpenSize,
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
	businessMenuOpen =
		false


	stopAddFrameTween()


	if immediate then
		addFrame.Visible =
			false

		addFrame.Position =
			addFrameOpenPosition

		addFrame.Size =
			addFrameOpenSize

		return
	end


	if not addFrame.Visible then
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
					addFrameClosedPosition,

				Size =
					addFrameClosedSize,
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
			addFrameOpenPosition

		addFrame.Size =
			addFrameOpenSize
	end)


	tween:Play()
end


--==================================================
-- PLACEMENT UI ANIMATIONS
--==================================================

local function stopPlacementUITweens()
	if activeAddButtonsTween then
		activeAddButtonsTween:Cancel()

		activeAddButtonsTween =
			nil
	end


	if activeNoticeTween then
		activeNoticeTween:Cancel()

		activeNoticeTween =
			nil
	end
end


local function showPlacementUI()
	stopPlacementUITweens()


	addButtons.Position =
		addButtonsHiddenPosition

	addButtons.Visible =
		true


	noticeWhilePlacing.Position =
		noticeHiddenPosition

	noticeWhilePlacing.Visible =
		true


	local buttonsTween =
		TweenService:Create(
			addButtons,
			TweenInfo.new(
				0.22,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Position =
					addButtonsOpenPosition,
			}
		)


	local noticeTween =
		TweenService:Create(
			noticeWhilePlacing,
			TweenInfo.new(
				0.2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Position =
					noticeOpenPosition,
			}
		)


	activeAddButtonsTween =
		buttonsTween

	activeNoticeTween =
		noticeTween


	buttonsTween:Play()
	noticeTween:Play()
end


local function hidePlacementUI(
	immediate: boolean?
)
	stopPlacementUITweens()


	if immediate then
		addButtons.Visible =
			false

		addButtons.Position =
			addButtonsOpenPosition


		noticeWhilePlacing.Visible =
			false

		noticeWhilePlacing.Position =
			noticeOpenPosition

		return
	end


	if not addButtons.Visible
		and not noticeWhilePlacing.Visible then

		return
	end


	local buttonsTween =
		TweenService:Create(
			addButtons,
			TweenInfo.new(
				0.14,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Position =
					addButtonsHiddenPosition,
			}
		)


	local noticeTween =
		TweenService:Create(
			noticeWhilePlacing,
			TweenInfo.new(
				0.12,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Position =
					noticeHiddenPosition,
			}
		)


	activeAddButtonsTween =
		buttonsTween

	activeNoticeTween =
		noticeTween


	buttonsTween:Play()
	noticeTween:Play()


	buttonsTween.Completed:Once(function()
		if activeAddButtonsTween
			~= buttonsTween then

			return
		end


		activeAddButtonsTween =
			nil


		if not isPlacementActive then
			addButtons.Visible =
				false

			addButtons.Position =
				addButtonsOpenPosition
		end
	end)


	noticeTween.Completed:Once(function()
		if activeNoticeTween
			~= noticeTween then

			return
		end


		activeNoticeTween =
			nil


		if not isPlacementActive then
			noticeWhilePlacing.Visible =
				false

			noticeWhilePlacing.Position =
				noticeOpenPosition
		end
	end)
end


--==================================================
-- BUTTON HOVER EFFECTS
--==================================================

local function setupButtonHover(
	button: TextButton
)
	local normalColor =
		button.BackgroundColor3


	local hoverColor =
		normalColor:Lerp(
			Color3.new(
				1,
				1,
				1
			),
			0.12
		)


	local pressedColor =
		normalColor:Lerp(
			Color3.new(
				0,
				0,
				0
			),
			0.12
		)


	local activeTween:
		Tween? =
		nil


	local function tweenColor(
		color: Color3,
		duration: number
	)
		if activeTween then
			activeTween:Cancel()
		end


		activeTween =
			TweenService:Create(
				button,
				TweenInfo.new(
					duration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					BackgroundColor3 =
						color,
				}
			)


		activeTween:Play()
	end


	button.MouseEnter:Connect(function()
		tweenColor(
			hoverColor,
			0.1
		)
	end)


	button.MouseLeave:Connect(function()
		tweenColor(
			normalColor,
			0.1
		)
	end)


	button.MouseButton1Down:Connect(function()
		tweenColor(
			pressedColor,
			0.06
		)
	end)


	button.MouseButton1Up:Connect(function()
		tweenColor(
			hoverColor,
			0.08
		)
	end)
end


setupButtonHover(
	rotateButton
)

setupButtonHover(
	placeButton
)

setupButtonHover(
	cancelButton
)


--==================================================
-- GENERAL UI VISIBILITY
--==================================================

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
-- NOTICE TEXT
--==================================================

local noticeVersion =
	0


local function getDefaultPlacementNotice(): string
	if IS_TOUCH_DEVICE then
		return "Move the business, then tap Place."
	end


	return "Click to place  •  R rotate  •  Esc cancel"
end


local function setPlacementNotice(
	message: string
)
	noticeVersion += 1


	noticeText.Text =
		message
end

--==================================================
-- PREVIEW APPEARANCE
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


local function makePreviewPartNonCollidable(
	part: BasePart
)
	part.Anchored =
		true

	part.CanCollide =
		false

	part.CanTouch =
		false

	part.CanQuery =
		false

	part.Massless =
		true


	part.AssemblyLinearVelocity =
		Vector3.zero

	part.AssemblyAngularVelocity =
		Vector3.zero


	part.Transparency =
		math.max(
			part.Transparency,
			0.45
		)
end


local function preparePreview(
	model: Model
)
	-- Disable everything already inside the preview.
	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			makePreviewPartNonCollidable(
				descendant
			)

		elseif descendant:IsA(
			"Script"
		)
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


	-- Safety net:
	-- if anything adds a new part to the preview while
	-- placement is active, it must also be non-collidable.
	model.DescendantAdded:Connect(
		function(
			descendant: Instance
		)
			if descendant:IsA(
				"BasePart"
			) then

				makePreviewPartNonCollidable(
					descendant
				)

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
	)


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
			firstRadius + secondRadius then

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

local function destroyPlacementGrid(
	immediate: boolean?
)
	if not placementGridFolder then
		return
	end


	local folder =
		placementGridFolder

	placementGridFolder =
		nil


	if immediate then
		folder:Destroy()

		return
	end


	local gridLines = {}
	local occupiedParts = {}


	for _, child in
		folder:GetChildren() do

		if not child:IsA("BasePart") then
			continue
		end


		if child.Name == "Occupied" then
			table.insert(
				occupiedParts,
				child
			)
		else
			table.insert(
				gridLines,
				child
			)
		end
	end


	--==================================================
	-- RETRACT GRID LINES
	--==================================================

	for _, part in
		gridLines do

		local targetSize


		-- Long on X = horizontal grid line.
		if part.Size.X > part.Size.Z then

			targetSize =
				Vector3.new(
					0.05,
					part.Size.Y,
					part.Size.Z
				)

		-- Long on Z = vertical grid line.
		else

			targetSize =
				Vector3.new(
					part.Size.X,
					part.Size.Y,
					0.05
				)
		end


		local tween =
			TweenService:Create(
				part,

				TweenInfo.new(
					0.28,
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.In
				),

				{
					Size =
						targetSize,

					Transparency =
						1,
				}
			)


		tween:Play()
	end


	--==================================================
	-- SHRINK OCCUPIED AREAS
	--==================================================

	for _, part in
		occupiedParts do

		local tween =
			TweenService:Create(
				part,

				TweenInfo.new(
					0.22,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.In
				),

				{
					Size =
						Vector3.new(
							0.1,
							part.Size.Y,
							0.1
						),

					Transparency =
						1,
				}
			)


		tween:Play()
	end


	-- Give the animation enough time to actually finish
	-- before destroying the local grid.
	task.delay(
		0.32,
		function()
			if folder.Parent then
				folder:Destroy()
			end
		end
	)
end

local function createGridPart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number
): Part

	local part =
		Instance.new("Part")


	part.Name =
		"Grid"

	part.Size =
		size

	part.CFrame =
		cframe

	part.Color =
		color

	part.Transparency =
		transparency

	part.Material =
		Enum.Material.Neon

	part.Anchored =
		true

	part.CanCollide =
		false

	part.CanTouch =
		false

	part.CanQuery =
		false

	part.CastShadow =
		false

	part.Parent =
		parent


	return part
end


local function createPlacementGrid()
	destroyPlacementGrid(
	true
)


	if not ownedPlot then
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

		return
	end


	local folder =
		Instance.new("Folder")

	folder.Name =
		"LocalPlacementGrid"

	folder.Parent =
		Workspace


	placementGridFolder =
		folder


	local halfX =
		ground.Size.X / 2

	local halfZ =
		ground.Size.Z / 2


	local topY =
		ground.Size.Y / 2
		+ GRID_LINE_HEIGHT


	local verticalLines = {}
	local horizontalLines = {}


	-- Vertical lines.
	for x =
		-halfX,
		halfX,
		GRID_SIZE do

		local part =
			createGridPart(
				folder,

				Vector3.new(
					GRID_LINE_THICKNESS,
					GRID_LINE_HEIGHT,
					ground.Size.Z
				),

				ground.CFrame
					* CFrame.new(
						x,
						topY,
						0
					),

				GRID_FREE_COLOR,
				1
			)


		table.insert(
			verticalLines,
			{
				Part = part,
				Coordinate = x,
			}
		)
	end


	-- Horizontal lines.
	for z =
		-halfZ,
		halfZ,
		GRID_SIZE do

		local part =
			createGridPart(
				folder,

				Vector3.new(
					ground.Size.X,
					GRID_LINE_HEIGHT,
					GRID_LINE_THICKNESS
				),

				ground.CFrame
					* CFrame.new(
						0,
						topY,
						z
					),

				GRID_FREE_COLOR,
				1
			)


		table.insert(
			horizontalLines,
			{
				Part = part,
				Coordinate = z,
			}
		)
	end


	-- Sort so the reveal travels cleanly
	-- from one side of the plot to the other.
	table.sort(
		verticalLines,
		function(a, b)
			return a.Coordinate
				< b.Coordinate
		end
	)


	table.sort(
		horizontalLines,
		function(a, b)
			return a.Coordinate
				< b.Coordinate
		end
	)


	local function animateLineGroup(
		lines: { any },
		stagger: number
	)
		for index, data in
			lines do

			task.delay(
				(index - 1) * stagger,
				function()
					if not placementGridFolder
						or data.Part.Parent
							~= placementGridFolder then

						return
					end


					data.Part.Transparency =
						1


					local tween =
						TweenService:Create(
							data.Part,

							TweenInfo.new(
								0.12,
								Enum.EasingStyle.Quad,
								Enum.EasingDirection.Out
							),

							{
								Transparency =
									0.68,
							}
						)


					tween:Play()
				end
			)
		end
	end


	-- First vertical sweep, then horizontal sweep.
	animateLineGroup(
		verticalLines,
		0.008
	)


	task.delay(
		0.08,
		function()
			if not placementGridFolder
				or placementGridFolder
					~= folder then

				return
			end


			animateLineGroup(
				horizontalLines,
				0.008
			)
		end
	)
end

local function addOccupiedGridAreas()
	if not placementGridFolder
		or not ownedPlot then

		return
	end


	local ground =
		ownedPlot:FindFirstChild(
			"Ground"
		)


	local placedBusinesses =
		ownedPlot:FindFirstChild(
			"PlacedBusinesses"
		)


	if not ground
		or not ground:IsA("BasePart")
		or not placedBusinesses then

		return
	end


	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA("Model")
			or business == originalStand then

			continue
		end


		local bounds =
			business:FindFirstChild(
				"PlacementBounds",
				true
			)


		if not bounds
			or not bounds:IsA(
				"BasePart"
			) then

			continue
		end


		local groundSpace =
			ground.CFrame
				:ToObjectSpace(
					bounds.CFrame
				)


		local finalSize =
	Vector3.new(
		bounds.Size.X,
		GRID_LINE_HEIGHT,
		bounds.Size.Z
	)


local occupiedPart =
	createGridPart(
		placementGridFolder,

		Vector3.new(
			math.max(
				0.1,
				bounds.Size.X * 0.85
			),

			GRID_LINE_HEIGHT,

			math.max(
				0.1,
				bounds.Size.Z * 0.85
			)
		),

		ground.CFrame
			* CFrame.new(
				groundSpace.Position.X,

				ground.Size.Y / 2
					+ GRID_LINE_HEIGHT
					+ 0.01,

				groundSpace.Position.Z
			)
			* CFrame.Angles(
				0,

				select(
					2,
					groundSpace
						:ToOrientation()
				),

				0
			),

		GRID_OCCUPIED_COLOR,
		1
	)


occupiedPart.Name =
	"Occupied"


TweenService:Create(
	occupiedPart,

	TweenInfo.new(
		0.22,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	),

	{
		Size =
			finalSize,

		Transparency =
			0.72,
	}
):Play()
	end
end


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

	destroyPlacementGrid(
	false
)


	setOriginalStandVisible(
		true
	)


	originalStand =
		nil

	isEditingExistingStand =
		false


	hidePlacementUI()
end

local function startPlacement(
	editingExisting: boolean,
	businessId: string?,
	businessName: string?
)
	if isPlacementActive then
		return
	end


	ownedPlot =
		getOwnedPlot()


	if not ownedPlot then
		Notification.Info(
	"Waiting for your plot..."
)

		showAddButton()

		return
	end


	local existingStand:
		Model? =
		nil


	local requestedBusiness =
		businessName
		or DEFAULT_BUSINESS_NAME


	-- When editing, determine the business type
	-- from the actual existing stand.
	if editingExisting then

		if typeof(businessId)
			~= "string"
			or businessId == "" then

			Notification.Error(
	"The selected business could not be identified."
)

			cancelEditRemote:FireServer()

			return
		end


		existingStand =
			findStandByBusinessId(
				businessId
			)


		if not existingStand then

			Notification.Error(
	"Your business could not be found."
)

			cancelEditRemote:FireServer()

			return
		end


		requestedBusiness =
			getBusinessType(
				existingStand
			)
	end


	local businessConfig =
		BusinessConfig[
			requestedBusiness
		]


	if not businessConfig then

		Notification.Error(
	"This business is not configured."
)

		if editingExisting then
			cancelEditRemote:FireServer()
		else
			showAddButton()
		end

		return
	end


	selectedBusinessName =
		requestedBusiness


	if not editingExisting then

		local maximumPlaced =
			businessConfig.MaximumPlaced
			or math.huge


		local currentCount =
			getBusinessCount(
				selectedBusinessName
			)


		if currentCount >= maximumPlaced then

			local displayName =
				businessConfig.DisplayName
				or selectedBusinessName


			Notification.Warning(
	`You can only place {maximumPlaced} {displayName}s.`
)

			showAddButton()

			return
		end
	end


	local previewSource:
		Model? =
		nil


	if editingExisting then

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
			cancelEditRemote:FireServer()
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
			cancelEditRemote:FireServer()
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


		for _, descendant in
			previewModel:GetDescendants() do

			if descendant:IsA(
				"BasePart"
			) then

				descendant.CanCollide =
					false
			end
		end


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


	createPlacementGrid()

	addOccupiedGridAreas()


	setBuildMenuVisible(
		false
	)


	setPlacementNotice(
		getDefaultPlacementNotice()
	)


	showPlacementUI()
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


	if wasEditing then
		cancelEditRemote:FireServer()
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

		Notification.Warning(
	"Keep the business inside your plot and away from other businesses.",
	{
		Title = "Can't Place Here",
	}
)

		return
	end


	waitingForServer =
		true


	placeBusinessRemote:FireServer(
		selectedBusinessName,
		currentPlacementCFrame
	)


	local config =
	BusinessConfig[
		selectedBusinessName
	]


local displayName =
	config
	and config.DisplayName
	or "Business"


setPlacementNotice(
	isEditingExistingStand
		and `Moving {displayName}...`
		or `Building {displayName}...`
)
end


--==================================================
-- BUSINESS LIST
--==================================================


local function clearBusinessButtons()
	for businessName, button in
		businessButtons do

		button:Destroy()

		businessButtons[
			businessName
		] = nil
	end
end


local function populateBusinessList()
	clearBusinessButtons()


	businessTemplate.Visible =
		false


	local names = {}


	for businessName, config in
		BusinessConfig do

		if typeof(businessName)
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
			BusinessConfig[first]

		local secondConfig =
			BusinessConfig[second]


		local firstPrice =
			firstConfig.AdditionalStandCost
			or 0

		local secondPrice =
			secondConfig.AdditionalStandCost
			or 0


		if firstPrice == secondPrice then
			return string.lower(
				firstConfig.DisplayName
					or first
			) < string.lower(
				secondConfig.DisplayName
					or second
			)
		end


		return firstPrice < secondPrice
	end
)


	for index, businessName in
		names do

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
		getBusinessButtonText(
			businessName,
			config
		)
end


		setupButtonHover(
			button
		)


		button.Activated:Connect(
			function()
				if isPlacementActive then
					return
				end


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


--==================================================
-- UI BUTTON CONNECTIONS
--==================================================

addButton.Activated:Connect(function()
	if isPlacementActive then
		return
	end


	if businessMenuOpen then
		closeBusinessMenu()
	else
		openBusinessMenu()
	end
end)


rotateButton.Activated:Connect(
	rotatePlacement
)


placeButton.Activated:Connect(
	requestCurrentPlacement
)


cancelButton.Activated:Connect(
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
		if not isPlacementActive then
			return
		end


		-- Keyboard shortcuts should still work even
		-- when Roblox has processed another UI input.
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


		if gameProcessed then
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


		local camera =
			Workspace.CurrentCamera


		if not camera then
			return
		end


		local pointerPosition =
			lastTouchPosition
			or UserInputService
				:GetMouseLocation()


		local ray =
			camera:ViewportPointToRay(
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


-- Safety check:
-- the placement preview must never collide
-- with the player or anything else.
for _, descendant in
	previewModel:GetDescendants() do

	if descendant:IsA(
		"BasePart"
	) then

		descendant.CanCollide =
			false

		descendant.CanTouch =
			false

		descendant.CanQuery =
			false
	end
end


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
	local wasEditing =
		isEditingExistingStand

	finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			task.defer(function()
				setBuildMenuVisible(
					canPlaceAnyBusiness()
				)
			end)


			Notification.Success(
	message ~= ""
		and message
		or (
			wasEditing
				and "Business moved successfully!"
				or "Business placed!"
		),
	{
		Title =
			wasEditing
				and "Moved!"
				or "Placed!",
	}
)


			return
		end


		Notification.Error(
	message ~= ""
		and message
		or "The stand could not be placed."
)

if isPlacementActive then
	setPlacementNotice(
		getDefaultPlacementNotice()
	)
end
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

			return
		end


		if action
			== "BeginEdit" then

			if typeof(businessId)
				~= "string"
				or businessId == "" then

				Notification.Error(
	"The selected business could not be identified."
)

				cancelEditRemote:FireServer()

				return
			end


			closeBusinessMenu(
				true
			)

			hideAddButton()


			startPlacement(
	true,
	businessId,
	nil
)


			return
		end


		if action
			== "Removed" then

			finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			task.defer(function()
				setBuildMenuVisible(
					canPlaceAnyBusiness()
				)
			end)


			return
		end


		if action
			== "RemoveFailed" then

			if typeof(message)
	== "string" then

	Notification.Error(
		message
	)
end


			return
		end


		if action
			== "EditCancelled" then

			finishPlacementMode()


			ownedPlot =
				getOwnedPlot()


			setBuildMenuVisible(
				canPlaceAnyBusiness()
			)
		end
	end
)


--==================================================
-- INITIAL STATE
--==================================================

businessTemplate.Visible =
	false


addFrame.Visible =
	false

addFrame.Position =
	addFrameOpenPosition

addFrame.Size =
	addFrameOpenSize


addButtons.Visible =
	false

addButtons.Position =
	addButtonsOpenPosition


noticeWhilePlacing.Visible =
	false

noticeWhilePlacing.Position =
	noticeOpenPosition


populateBusinessList()


ownedPlot =
	getOwnedPlot()


if ownedPlot then
	setBuildMenuVisible(
		canPlaceAnyBusiness()
	)
else
	setBuildMenuVisible(
		false
	)
end


--==================================================
-- KEEP ADD BUTTON IN SYNC
--==================================================

task.spawn(function()
	while screenGui.Parent do
		ownedPlot =
			getOwnedPlot()


		if ownedPlot
			and not isPlacementActive
			and not isEditingExistingStand then

			setBuildMenuVisible(
				canPlaceAnyBusiness()
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
end)

updateBusinessButtonTexts()