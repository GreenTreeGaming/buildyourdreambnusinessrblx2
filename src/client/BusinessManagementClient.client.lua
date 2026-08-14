local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)

local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local billboardsFolder =
	ReplicatedStorage:WaitForChild(
		"Billboards"
	)


local businessManagerTemplate =
	billboardsFolder:WaitForChild(
		"BusinessManager"
	) :: BillboardGui


local removeGui =
	playerGui:WaitForChild(
		"RemoveUI"
	) :: ScreenGui

local removeFrame =
	removeGui:WaitForChild(
		"Frame"
	) :: Frame

local removeOptions =
	removeFrame:WaitForChild(
		"Options"
	) :: Frame

local cancelRemoveButton =
	removeOptions:WaitForChild(
		"Cancel"
	) :: TextButton

local confirmRemoveButton =
	removeOptions:WaitForChild(
		"Remove"
	) :: TextButton


local requestEditRemote =
	remotes:WaitForChild(
		"RequestEditBusiness"
	)

local requestRemoveRemote =
	remotes:WaitForChild(
		"RequestRemoveBusiness"
	)

local interactionResultRemote =
	remotes:WaitForChild(
		"BusinessInteractionResult"
	)


local UITheme =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("UITheme")
	)

local Colors =
	UITheme.Colors


local BUSINESS_NAME =
	"LemonadeStand"

local MANAGEMENT_DISTANCE =
	22

local UPDATE_INTERVAL =
	0.1


--==================================================
-- REMOVE UI ANIMATION
--==================================================

local REMOVE_OPEN_SCALE =
	0.86

local REMOVE_CLOSE_SCALE =
	0.9

local REMOVE_OPEN_TIME =
	0.26

local REMOVE_CLOSE_TIME =
	0.16

local REMOVE_START_OFFSET =
	18

--==================================================
-- EDIT PROPERTIES MODE EVENTS
--==================================================

local editPropertiesModeEvent =
	playerGui:WaitForChild(
		"EditPropertiesModeChanged"
	) :: BindableEvent


local selectBusinessEvent =
	playerGui:WaitForChild(
		"SelectBusinessForManagement"
	) :: BindableEvent


local propertyEditMode =
	false


local propertySelectedBusinessId:
	string? =
	nil


local removeOriginalPosition =
	removeFrame.Position

local removeScale =
	removeFrame:FindFirstChild(
		"PopupScale"
	)

if removeScale
	and not removeScale:IsA(
		"UIScale"
	) then

	removeScale:Destroy()
	removeScale = nil
end

if not removeScale then
	removeScale =
		Instance.new(
			"UIScale"
		)

	removeScale.Name =
		"PopupScale"

	removeScale.Parent =
		removeFrame
end

removeScale =
	removeScale :: UIScale


local removeOpen =
	false

local removeAnimating =
	false

local removeAnimationVersion =
	0

local removeScaleTween:
	Tween? =
	nil

local removePositionTween:
	Tween? =
	nil


local function getOffsetPosition(
	position: UDim2,
	yOffset: number
): UDim2
	return UDim2.new(
		position.X.Scale,
		position.X.Offset,

		position.Y.Scale,
		position.Y.Offset
			+ yOffset
	)
end


local function stopRemoveTweens()
	if removeScaleTween then
		removeScaleTween:Cancel()

		removeScaleTween =
			nil
	end

	if removePositionTween then
		removePositionTween:Cancel()

		removePositionTween =
			nil
	end
end


local function applyRemoveHiddenPose()
	removeScale.Scale =
		REMOVE_OPEN_SCALE

	removeFrame.Position =
		getOffsetPosition(
			removeOriginalPosition,
			REMOVE_START_OFFSET
		)
end


-- Start completely hidden.
removeGui.Enabled =
	false

applyRemoveHiddenPose()


--==================================================
-- OPEN UPGRADE MENU EVENT
--==================================================

local function getOpenUpgradeMenuEvent():
	BindableEvent

	local existing =
		playerGui:FindFirstChild(
			"OpenUpgradeMenu"
		)

	if existing then
		if existing:IsA(
			"BindableEvent"
		) then

			return existing
		end

		existing:Destroy()
	end


	local event =
		Instance.new(
			"BindableEvent"
		)

	event.Name =
		"OpenUpgradeMenu"

	event.Parent =
		playerGui

	return event
end


local openUpgradeMenuEvent =
	getOpenUpgradeMenuEvent()

--==================================================
-- EDIT PROPERTIES MODE EVENTS
--==================================================

local function getOrCreateBindable(
	name: string
): BindableEvent

	local existing =
		playerGui:FindFirstChild(
			name
		)


	if existing then

		if existing:IsA(
			"BindableEvent"
		) then

			return existing
		end


		existing:Destroy()
	end


	local event =
		Instance.new(
			"BindableEvent"
		)


	event.Name =
		name


	event.Parent =
		playerGui


	return event
end


local editPropertiesModeEvent =
	getOrCreateBindable(
		"EditPropertiesModeChanged"
	)


local selectBusinessEvent =
	getOrCreateBindable(
		"SelectBusinessForManagement"
	)


local propertyEditMode =
	false


local propertySelectedBusinessId:
	string? =
	nil

--==================================================
-- MANAGEMENT STATE
--==================================================

local managementGui:
	BillboardGui? =
	nil

local managementStand:
	Model? =
	nil

local managementRoot:
	Frame? =
	nil

local managementRootPosition =
	UDim2.new()

local managementRootSize =
	UDim2.new()

local managementRestingOffset =
	Vector3.zero


local managementActiveRootTween:
	Tween? =
	nil

local managementActivePositionTween:
	Tween? =
	nil


local managementVisible =
	false

local managementVisibilityVersion =
	0

local managementCreationPending =
	false


local removeRequestPending =
	false

local pendingRemoveBusinessId:
	string? =
	nil


--==================================================
-- TOAST
--==================================================

local toastGui:
	ScreenGui? =
	nil

local toastLabel:
	TextLabel? =
	nil

local toastVersion =
	0


local function createToast()
	local existing =
		playerGui:FindFirstChild(
			"BusinessManagementToast"
		)

	if existing then
		existing:Destroy()
	end


	local gui =
		Instance.new(
			"ScreenGui"
		)

	gui.Name =
		"BusinessManagementToast"

	gui.ResetOnSpawn =
		false

	gui.IgnoreGuiInset =
		true

	gui.DisplayOrder =
		150

	gui.Parent =
		playerGui


	local label =
		Instance.new(
			"TextLabel"
		)

	label.Name =
		"Toast"

	label.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)

	label.Position =
		UDim2.new(
			0.5,
			0,
			0,
			18
		)

	label.Size =
		UDim2.fromOffset(
			560,
			50
		)

	label.BackgroundColor3 =
		Colors.Surface

	label.BackgroundTransparency =
		0.04

	label.BorderSizePixel =
		0

	label.TextScaled =
		true

	label.TextWrapped =
		true

	label.Visible =
		false

	label.Parent =
		gui


	UITheme.AddCorner(
		label,
		0.15
	)

	UITheme.AddStroke(
		label,
		Colors.Stroke,
		1.5,
		0.2
	)


	toastGui =
		gui

	toastLabel =
		label
end


local function showToast(
	message: string,
	isError: boolean?
)
	if not toastLabel then
		return
	end


	toastVersion += 1

	local version =
		toastVersion


	toastLabel.Text =
		message

	toastLabel.TextColor3 =
		isError
		and Colors.Danger
		or Colors.Success

	toastLabel.Visible =
		true


	task.delay(
		3,
		function()
			if version
				~= toastVersion then

				return
			end

			if toastLabel then
				toastLabel.Visible =
					false
			end
		end
	)
end


createToast()


--==================================================
-- PLOT HELPERS
--==================================================

local function getOwnedPlot():
	Model?

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
		plotsFolder:GetChildren()
	do
		if plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getCharacterRoot():
	BasePart?

	local character =
		player.Character

	if not character then
		return nil
	end


	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if root
		and root:IsA(
			"BasePart"
		) then

		return root
	end


	return nil
end


local function isLemonadeStand(
	instance: Instance
): boolean
	if not instance:IsA(
		"Model"
	) then

		return false
	end


	local businessType =
		instance:GetAttribute(
			"BusinessType"
		)

	if businessType
		== BUSINESS_NAME then

		return true
	end


	if instance.Name
		== BUSINESS_NAME then

		return true
	end


	return string.match(
		instance.Name,
		"^LemonadeStand_"
	) ~= nil
end


local function getClosestOwnedStand():
	Model?

	local plot =
		getOwnedPlot()

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


	local root =
		getCharacterRoot()

	if not root then
		return nil
	end


	local closestStand:
		Model? =
		nil

	local closestDistance =
		math.huge


	for _, child in
		placedBusinesses:GetChildren()
	do
		if not child:IsA(
			"Model"
		) then

			continue
		end


		if not isLemonadeStand(
			child
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		local position =
			child:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		local positionPart:
			BasePart? =
			nil


		if position
			and position:IsA(
				"BasePart"
			) then

			positionPart =
				position

		elseif child.PrimaryPart then
			positionPart =
				child.PrimaryPart
		end


		if not positionPart then
			continue
		end


		local distance =
			(
				root.Position
					- positionPart.Position
			).Magnitude


		if distance
			< closestDistance then

			closestDistance =
				distance

			closestStand =
				child
		end
	end


	return closestStand
end


local function getUIAdornee(
	stand: Model,
	waitForReplication: boolean?
): BasePart?

	local function findAdornee():
		BasePart?

		local managementPosition =
			stand:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		if managementPosition
			and managementPosition:IsA(
				"BasePart"
			) then

			return managementPosition
		end


		local cooldownPosition =
			stand:FindFirstChild(
				"CooldownUIPosition",
				true
			)

		if cooldownPosition
			and cooldownPosition:IsA(
				"BasePart"
			) then

			return cooldownPosition
		end


		local salePosition =
			stand:FindFirstChild(
				"SaleEffectPosition",
				true
			)

		if salePosition
			and salePosition:IsA(
				"BasePart"
			) then

			return salePosition
		end


		if stand.PrimaryPart then
			return stand.PrimaryPart
		end


		return nil
	end


	local existing =
		findAdornee()

	if existing
		or waitForReplication
			~= true then

		return existing
	end


	local startedAt =
		time()


	while stand.Parent
		and time() - startedAt
			< 10 do

		local adornee =
			findAdornee()

		if adornee then
			return adornee
		end

		task.wait(
			0.1
		)
	end


	return stand
		:FindFirstChildWhichIsA(
			"BasePart",
			true
		)
end


local function getBusinessId(
	stand: Model
): string

	local businessId =
		stand:GetAttribute(
			"BusinessId"
		)


	if typeof(businessId)
		== "string"
		and businessId ~= "" then

		return businessId
	end


	return stand.Name
end

local function findOwnedBusinessById(
	businessId: string
): Model?

	local plot =
		getOwnedPlot()


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

		if not child:IsA(
			"Model"
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		if getBusinessId(
			child
		) == businessId then

			return child
		end
	end


	return nil
end


local function getPropertySelectedStand():
	Model?

	if not propertyEditMode then
		return nil
	end


	if not propertySelectedBusinessId then
		return nil
	end


	return findOwnedBusinessById(
		propertySelectedBusinessId
	)
end


local function isCurrentManagementStand(
	stand: Model
): boolean

	if propertyEditMode then

		return getPropertySelectedStand()
			== stand
	end


	return getClosestOwnedStand()
		== stand
end

local function findOwnedBusinessById(
	businessId: string
): Model?

	local plot =
		getOwnedPlot()


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

		if not child:IsA(
			"Model"
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		local childId =
			getBusinessId(
				child
			)


		if childId
			== businessId then

			return child
		end
	end


	return nil
end


local function getPropertySelectedStand():
	Model?

	if not propertyEditMode then
		return nil
	end


	local businessId =
		propertySelectedBusinessId


	if not businessId then
		return nil
	end


	return findOwnedBusinessById(
		businessId
	)
end


local function isCurrentManagementStand(
	stand: Model
): boolean

	if propertyEditMode then

		return getPropertySelectedStand()
			== stand
	end


	return getClosestOwnedStand()
		== stand
end

--==================================================
-- BUTTON ANIMATION
--==================================================

local function prepareButton(
	button: TextButton
)
	button.Active =
		true

	button.Selectable =
		true

	button.AutoButtonColor =
		false


	-- The visible text is in the X label
	-- on your Studio-created buttons.
	local label =
		button:FindFirstChild(
			"X"
		)

	if label
		and label:IsA(
			"GuiObject"
		) then

		label.Active =
			false

		label.Selectable =
			false
	end


	local scale =
		button:FindFirstChild(
			"ButtonScale"
		)

	if scale
		and not scale:IsA(
			"UIScale"
		) then

		scale:Destroy()
		scale = nil
	end


	if not scale then
		scale =
			Instance.new(
				"UIScale"
			)

		scale.Name =
			"ButtonScale"

		scale.Parent =
			button
	end


	scale =
		scale :: UIScale

	scale.Scale =
		1


	local activeTween:
		Tween? =
		nil


	local function tweenTo(
		value: number,
		duration: number
	)
		if activeTween then
			activeTween:Cancel()
		end


		activeTween =
			TweenService:Create(
				scale,

				TweenInfo.new(
					duration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						value,
				}
			)

		activeTween:Play()
	end


	button.MouseEnter:Connect(
		function()
			if not button.Active then
				return
			end

			tweenTo(
				1.045,
				0.1
			)
		end
	)


	button.MouseLeave:Connect(
		function()
			tweenTo(
				1,
				0.1
			)
		end
	)


	button.MouseButton1Down:Connect(
		function()
			if not button.Active then
				return
			end

			tweenTo(
				0.94,
				0.06
			)
		end
	)


	button.MouseButton1Up:Connect(
		function()
			if not button.Active then
				return
			end

			tweenTo(
				1.045,
				0.08
			)
		end
	)
end


-- Apply hover/click animation to the new
-- StarterGui remove-confirmation buttons too.
prepareButton(
	cancelRemoveButton
)

prepareButton(
	confirmRemoveButton
)


--==================================================
-- REMOVE CONFIRMATION
--==================================================

local function hideRemoveConfirmation(
	clearPendingId: boolean?
)
	if not removeOpen then
		if clearPendingId
			~= false then

			removeRequestPending =
				false

			pendingRemoveBusinessId =
				nil
		end

		return
	end


	removeOpen =
		false

	removeAnimationVersion +=
		1

	local version =
		removeAnimationVersion


	stopRemoveTweens()

	removeAnimating =
		true


	removeScaleTween =
		TweenService:Create(
			removeScale,

			TweenInfo.new(
				REMOVE_CLOSE_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Scale =
					REMOVE_CLOSE_SCALE,
			}
		)


	removePositionTween =
		TweenService:Create(
			removeFrame,

			TweenInfo.new(
				REMOVE_CLOSE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Position =
					getOffsetPosition(
						removeOriginalPosition,
						12
					),
			}
		)


	removeScaleTween:Play()
	removePositionTween:Play()


	removeScaleTween.Completed:Once(
		function()
			if version
				~= removeAnimationVersion then

				return
			end


			removeAnimating =
				false

			if removeOpen then
				return
			end


			removeGui.Enabled =
				false

			applyRemoveHiddenPose()


			if clearPendingId
				~= false then

				removeRequestPending =
					false

				pendingRemoveBusinessId =
					nil
			end
		end
	)
end


local function showRemoveConfirmation()
	if removeOpen then
		return
	end


	removeAnimationVersion +=
		1

	local version =
		removeAnimationVersion


	stopRemoveTweens()


	removeOpen =
		true

	removeAnimating =
		true


	-- Important: place the UI in its hidden pose
	-- BEFORE enabling the ScreenGui. This prevents
	-- a one-frame flash at full size.
	removeGui.Enabled =
		false

	applyRemoveHiddenPose()

	removeGui.Enabled =
		true


	task.defer(
		function()
			if version
				~= removeAnimationVersion
				or not removeOpen then

				return
			end


			removeScaleTween =
				TweenService:Create(
					removeScale,

					TweenInfo.new(
						REMOVE_OPEN_TIME,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),

					{
						Scale =
							1,
					}
				)


			removePositionTween =
				TweenService:Create(
					removeFrame,

					TweenInfo.new(
						0.22,
						Enum.EasingStyle.Quart,
						Enum.EasingDirection.Out
					),

					{
						Position =
							removeOriginalPosition,
					}
				)


			removeScaleTween:Play()
			removePositionTween:Play()


			removeScaleTween.Completed:Once(
				function()
					if version
						~= removeAnimationVersion then

						return
					end

					removeAnimating =
						false
				end
			)
		end
	)
end


cancelRemoveButton.Activated:Connect(
	function()
		if removeAnimating then
			-- Closing during the entrance is safe;
			-- stop the entrance tween first.
			removeAnimating =
				false
		end

		hideRemoveConfirmation()
	end
)


confirmRemoveButton.Activated:Connect(
	function()
		if removeRequestPending then
			return
		end


		local businessId =
			pendingRemoveBusinessId

		if not businessId then
			hideRemoveConfirmation()

			return
		end


		removeRequestPending =
			true


		confirmRemoveButton.Active =
			false

		confirmRemoveButton.Selectable =
			false


		-- Keep the ID until the server answers.
		hideRemoveConfirmation(
			false
		)


		requestRemoveRemote:FireServer(
			true,
			businessId
		)


		task.delay(
			2,
			function()
				removeRequestPending =
					false

				confirmRemoveButton.Active =
					true

				confirmRemoveButton.Selectable =
					true
			end
		)
	end
)


--==================================================
-- MANAGEMENT VISIBILITY
--==================================================

local function scaleUDim2(
	value: UDim2,
	scale: number
): UDim2
	return UDim2.new(
		value.X.Scale
			* scale,

		value.X.Offset
			* scale,

		value.Y.Scale
			* scale,

		value.Y.Offset
			* scale
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


local MANAGEMENT_OPEN_SCALE =
	0.88


local function stopManagementTweens()
	if managementActiveRootTween then
		managementActiveRootTween:Cancel()

		managementActiveRootTween =
			nil
	end


	if managementActivePositionTween then
		managementActivePositionTween:Cancel()

		managementActivePositionTween =
			nil
	end
end


local function applyManagementHiddenPose()
	if not managementGui
		or not managementRoot then

		return
	end


	managementRoot.Size =
		scaleUDim2(
			managementRootSize,
			MANAGEMENT_OPEN_SCALE
		)


	managementRoot.Position =
		getCenteredScaledPosition(
			managementRootPosition,
			managementRootSize,
			managementRoot.AnchorPoint,
			MANAGEMENT_OPEN_SCALE
		)


	managementGui.StudsOffsetWorldSpace =
		managementRestingOffset
		+ Vector3.new(
			0,
			-0.22,
			0
		)
end


local function setManagementVisible(
	visible: boolean
)
	if not managementGui
		or not managementRoot then

		return
	end


	-- Do not show the management billboard behind
	-- the remove confirmation.
	if removeOpen then
		visible =
			false
	end


	if managementVisible
		== visible then

		return
	end


	managementVisible =
		visible

	managementVisibilityVersion +=
		1


	local version =
		managementVisibilityVersion


	stopManagementTweens()


	if visible then
		managementGui.Enabled =
			false

		applyManagementHiddenPose()

		managementGui.Enabled =
			true


		task.defer(
			function()
				if version
					~= managementVisibilityVersion
					or not managementVisible
					or not managementGui
					or not managementRoot then

					return
				end


				local rootTween =
					TweenService:Create(
						managementRoot,

						TweenInfo.new(
							0.38,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out
						),

						{
							Size =
								managementRootSize,

							Position =
								managementRootPosition,
						}
					)


				local positionTween =
					TweenService:Create(
						managementGui,

						TweenInfo.new(
							0.32,
							Enum.EasingStyle.Quart,
							Enum.EasingDirection.Out
						),

						{
							StudsOffsetWorldSpace =
								managementRestingOffset,
						}
					)


				managementActiveRootTween =
					rootTween

				managementActivePositionTween =
					positionTween


				rootTween:Play()
				positionTween:Play()
			end
		)

		return
	end


	-- CLOSE
	local closingScale =
		0.9

	local closingSize =
		scaleUDim2(
			managementRootSize,
			closingScale
		)

	local closingPosition =
		getCenteredScaledPosition(
			managementRootPosition,
			managementRootSize,
			managementRoot.AnchorPoint,
			closingScale
		)


	local rootTween =
		TweenService:Create(
			managementRoot,

			TweenInfo.new(
				0.24,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Size =
					closingSize,

				Position =
					closingPosition,
			}
		)


	local positionTween =
		TweenService:Create(
			managementGui,

			TweenInfo.new(
				0.24,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				StudsOffsetWorldSpace =
					managementRestingOffset
					+ Vector3.new(
						0,
						-0.2,
						0
					),
			}
		)


	managementActiveRootTween =
		rootTween

	managementActivePositionTween =
		positionTween


	rootTween:Play()
	positionTween:Play()


	rootTween.Completed:Once(
		function()
			if managementActiveRootTween
				~= rootTween then

				return
			end


			managementActiveRootTween =
				nil


			if version
				~= managementVisibilityVersion
				or managementVisible then

				return
			end


			if managementGui then
				managementGui.Enabled =
					false
			end


			if managementRoot
				and managementGui then

				applyManagementHiddenPose()
			end
		end
	)
end


local function destroyManagementUI()
	stopManagementTweens()


	managementVisibilityVersion +=
		1

	managementVisible =
		false


	if managementGui then
		managementGui:Destroy()

		managementGui =
			nil
	end


	managementRoot =
		nil

	managementStand =
		nil
end


--==================================================
-- CREATE MANAGEMENT UI
--==================================================

local function createManagementUI(
	stand: Model
)
	destroyManagementUI()


	local adornee =
		getUIAdornee(
			stand,
			true
		)

	if not adornee then
		warn(
			`{stand:GetFullName()} did not finish loading a management UI position.`
		)

		return
	end


	local billboard =
		businessManagerTemplate:Clone()


	managementRestingOffset =
		billboard.StudsOffsetWorldSpace


	billboard.Name =
		"BusinessManagementUI"

	billboard.Adornee =
		adornee

	billboard.Enabled =
		false

	billboard.Active =
		true

	billboard.ResetOnSpawn =
		false

	billboard.AlwaysOnTop =
		true

	billboard.LightInfluence =
		0

	if propertyEditMode then

	-- Overhead editor can be hundreds of studs away.
	billboard.MaxDistance =
		100000


	-- Force a readable screen-space size while viewing
	-- the business from high above.
	billboard.Size =
		UDim2.fromOffset(
			360,
			180
		)

else
	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 5
end

	billboard.Parent =
		playerGui


	local root =
		billboard:WaitForChild(
			"Frame"
		) :: Frame


	managementGui =
		billboard

	managementRoot =
		root

	managementStand =
		stand

	managementRootPosition =
		root.Position

	managementRootSize =
		root.Size


	local businessNameLabel =
		root:WaitForChild(
			"BusinessName"
		) :: TextLabel

	local subtitleLabel =
		root:WaitForChild(
			"Subtitle"
		) :: TextLabel

	local buttons =
		root:WaitForChild(
			"Buttons"
		) :: Frame

	local manageButton =
		buttons:WaitForChild(
			"Manage"
		) :: TextButton

	local moveButton =
		buttons:WaitForChild(
			"Move"
		) :: TextButton

	local removeButton =
		buttons:WaitForChild(
			"Remove"
		) :: TextButton


	businessNameLabel.Text =
		"Lemonade Stand"


	if subtitleLabel.Text == "" then
		subtitleLabel.Text =
			"Manage this location"
	end


	prepareButton(
		manageButton
	)

	prepareButton(
		moveButton
	)

	prepareButton(
		removeButton
	)


	-- MOVE
	moveButton.Activated:Connect(
		function()
			if not isCurrentManagementStand(
	stand
) then

				showToast(
					"Your lemonade stand could not be found.",
					true
				)

				return
			end


			if stand:GetAttribute(
				"IsBeingEdited"
			) == true then

				return
			end


			local businessId =
				getBusinessId(
					stand
				)


			setManagementVisible(
				false
			)


			requestEditRemote:FireServer(
				businessId
			)
		end
	)


	-- MANAGE
	manageButton.Activated:Connect(
		function()
			if not isCurrentManagementStand(
	stand
) then

				showToast(
					"Your lemonade stand could not be found.",
					true
				)

				return
			end


			if stand:GetAttribute(
				"IsBeingEdited"
			) == true then

				showToast(
					"Finish moving this stand first.",
					true
				)

				return
			end


			if stand:GetAttribute(
				"StandUnavailable"
			) == true then

				showToast(
					"This stand is currently unavailable.",
					true
				)

				return
			end


			local businessId =
				getBusinessId(
					stand
				)


			setManagementVisible(
				false
			)


			openUpgradeMenuEvent:Fire(
				businessId
			)
		end
	)


	-- REMOVE
	removeButton.Activated:Connect(
		function()
			if removeRequestPending then
				return
			end


			if not isCurrentManagementStand(
	stand
) then

				showToast(
					"Your lemonade stand could not be found.",
					true
				)

				return
			end


			pendingRemoveBusinessId =
				getBusinessId(
					stand
				)


			removeRequestPending =
				true


			-- Ask the server whether removal is
			-- currently allowed. The server responds
			-- with ShowRemoveConfirmation.
			requestRemoveRemote:FireServer(
				false,
				pendingRemoveBusinessId
			)


			task.delay(
				2,
				function()
					-- Only release this timeout lock if
					-- the confirmation never opened.
					if not removeOpen then
						removeRequestPending =
							false
					end
				end
			)
		end
	)


	managementVisible =
		false

	billboard.Enabled =
		false

	applyManagementHiddenPose()
end


--==================================================
-- REMOVE UI INPUT
--==================================================

UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		_gameProcessed: boolean
	)
		if not removeOpen then
			return
		end


		if input.KeyCode
				== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			hideRemoveConfirmation()
		end
	end
)


--==================================================
-- SERVER RESPONSES
--==================================================

interactionResultRemote.OnClientEvent:Connect(
	function(
		action: string,
		message: any
	)
		if action
			== "ShowRemoveConfirmation" then

			removeRequestPending =
				false


			setManagementVisible(
				false
			)


			showRemoveConfirmation()

			return
		end


		if action
			== "BeginEdit" then

			hideRemoveConfirmation()

			setManagementVisible(
				false
			)

			return
		end


		if action
			== "Removed" then

			hideRemoveConfirmation()

			destroyManagementUI()


			showToast(
				typeof(message)
					== "string"
					and message
					or "Lemonade stand removed."
			)

			return
		end


		if action
			== "RemoveFailed" then

			hideRemoveConfirmation()


			showToast(
				typeof(message)
					== "string"
					and message
					or "The stand could not be removed.",

				true
			)

			return
		end


		if action
			== "EditCancelled" then

			hideRemoveConfirmation()

			return
		end


		if action
			== "EditFailed" then

			setManagementVisible(
				false
			)


			showToast(
				typeof(message)
					== "string"
					and message
					or "The stand could not be edited.",

				true
			)
		end
	end
)


--==================================================
-- CHARACTER CLEANUP
--==================================================

player.CharacterRemoving:Connect(
	function()
		setManagementVisible(
			false
		)

		hideRemoveConfirmation()
	end
)

--==================================================
-- EDIT PROPERTIES MODE
--==================================================

editPropertiesModeEvent.Event:Connect(
	function(
		enabled: boolean
	)

		propertyEditMode =
			enabled == true


		propertySelectedBusinessId =
			nil


		hideRemoveConfirmation()


		destroyManagementUI()
	end
)


selectBusinessEvent.Event:Connect(
	function(
		stand: Model?
	)

		if not propertyEditMode then
			return
		end


		if stand == nil then

			propertySelectedBusinessId =
				nil


			destroyManagementUI()


			return
		end


		if not stand:IsA(
			"Model"
		) then

			return
		end


		if stand:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			return
		end


		propertySelectedBusinessId =
			getBusinessId(
				stand
			)


		createManagementUI(
			stand
		)


		if managementGui then

			managementGui.MaxDistance =
				10000
		end


		setManagementVisible(
			true
		)
	end
)

--==================================================
-- EDIT PROPERTIES MODE
--==================================================

editPropertiesModeEvent.Event:Connect(
	function(
		enabled: boolean
	)

		propertyEditMode =
			enabled == true


		propertySelectedBusinessId =
			nil


		hideRemoveConfirmation()


		destroyManagementUI()
	end
)


selectBusinessEvent.Event:Connect(
	function(
		stand: Model?
	)

		if not propertyEditMode then
			return
		end


		-- Clicking empty land.
		if stand == nil then

			propertySelectedBusinessId =
				nil


			destroyManagementUI()


			return
		end


		if not stand:IsA(
			"Model"
		) then

			return
		end


		if stand:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			return
		end


		propertySelectedBusinessId =
			getBusinessId(
				stand
			)


		createManagementUI(
			stand
		)


		if managementGui then

			managementGui.MaxDistance =
				100000
		end


		setManagementVisible(
			true
		)
	end
)

task.spawn(
	function()

		while true do

			--==================================================
			-- OVERHEAD PROPERTY EDITOR
			--==================================================

			if propertyEditMode then

				local stand =
					getPropertySelectedStand()


				if not stand then

					if managementGui then

						destroyManagementUI()
					end


					task.wait(
						UPDATE_INTERVAL
					)


					continue
				end


				-- If appearance upgrading replaced the Model
				-- instance but preserved BusinessId, rediscover
				-- and rebuild the billboard automatically.
				if stand
					~= managementStand then

					createManagementUI(
						stand
					)
				end


				if managementGui then

					managementGui.MaxDistance =
						100000
				end


				local shouldShow =
					not removeOpen


				-- If Move is currently active, hide the
				-- management billboard temporarily.
				if stand:GetAttribute(
					"IsBeingEdited"
				) == true then

					shouldShow =
						false
				end


				if stand:GetAttribute(
					"StandUnavailable"
				) == true then

					shouldShow =
						false
				end


				setManagementVisible(
					shouldShow
				)


				task.wait(
					UPDATE_INTERVAL
				)


				continue
			end


			--==================================================
			-- NORMAL PROXIMITY MODE
			--==================================================

			local stand =
				getClosestOwnedStand()


			local root =
				getCharacterRoot()


			if stand
				~= managementStand then

				if stand
					and not managementCreationPending then

					managementCreationPending =
						true


					task.spawn(
						function()

							createManagementUI(
								stand
							)


							managementCreationPending =
								false
						end
					)

				elseif not stand then

					destroyManagementUI()


					managementCreationPending =
						false
				end
			end


			local shouldShow =
				false


			if stand
				and root
				and managementGui
				and managementStand
					== stand
				and not removeOpen
				and stand:GetAttribute(
					"IsBeingEdited"
				) ~= true
				and stand:GetAttribute(
					"StandUnavailable"
				) ~= true then


				local adornee =
					getUIAdornee(
						stand
					)


				if adornee then

					local distance =
						(
							root.Position
								- adornee.Position
						).Magnitude


					shouldShow =
						distance
							<= MANAGEMENT_DISTANCE
				end
			end


			setManagementVisible(
				shouldShow
			)


			task.wait(
				UPDATE_INTERVAL
			)
		end
	end
)