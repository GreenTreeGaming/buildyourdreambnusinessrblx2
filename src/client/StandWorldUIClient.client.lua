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

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local billboardsFolder =
	ReplicatedStorage:WaitForChild("Billboards")


local businessManagerTemplate =
	billboardsFolder:WaitForChild(
		"BusinessManager"
	) :: BillboardGui


--==================================================
-- REMOVE UI FROM STARTERGUI / PLAYERGUI
--==================================================

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


-- Keep the ScreenGui itself enabled.
-- Visibility is controlled through Frame.Visible.
removeGui.Enabled =
	true

removeGui.ResetOnSpawn =
	false


--==================================================
-- REMOTES
--==================================================

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


--==================================================
-- THEME
--==================================================

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


--==================================================
-- CONSTANTS
--==================================================

local MANAGEMENT_DISTANCE =
	22

local UPDATE_INTERVAL =
	0.1


-- Remove confirmation animation.
local REMOVE_OPEN_SCALE =
	0.86

local REMOVE_CLOSE_SCALE =
	0.9

local REMOVE_OPEN_TIME =
	0.26

local REMOVE_CLOSE_TIME =
	0.16

local REMOVE_START_Y_OFFSET =
	18

local REMOVE_CLOSE_Y_OFFSET =
	12


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


--==================================================
-- REMOVE STATE
--==================================================

local removeRequestPending =
	false

local pendingRemoveBusinessId:
	string? =
	nil


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

	removeScale =
		nil
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

removeScale.Scale =
	1

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


local function getBusinessType(
	instance: Model
): string?

	local businessType =
		instance:GetAttribute(
			"BusinessType"
		)

	if typeof(businessType) == "string"
		and BusinessConfig[businessType] then

		return businessType
	end

	for businessName in BusinessConfig do

		if instance.Name == businessName
			or string.match(
				instance.Name,
				`^{businessName}_`
			) then

			return businessName
		end
	end

	return nil
end


local function isSupportedBusiness(
	instance: Instance
): boolean

	if not instance:IsA(
		"Model"
	) then

		return false
	end

	return getBusinessType(
		instance
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


		if not isSupportedBusiness(
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


--==================================================
-- BUTTON HELPERS
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

		scale =
			nil
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


prepareButton(
	cancelRemoveButton
)

prepareButton(
	confirmRemoveButton
)


--==================================================
-- REMOVE CONFIRMATION ANIMATION
--==================================================

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
			REMOVE_START_Y_OFFSET
		)
end


-- IMPORTANT:
-- ScreenGui stays enabled.
-- Only the actual Frame starts hidden.
removeGui.Enabled =
	true

removeFrame.Visible =
	false

applyRemoveHiddenPose()


local function hideRemoveConfirmation(
	clearPendingId: boolean?
)
	if not removeOpen then
		removeFrame.Visible =
			false


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
						REMOVE_CLOSE_Y_OFFSET
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


			-- THIS is what actually hides the popup.
			-- We do not disable the ScreenGui.
			removeFrame.Visible =
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


	-- Set the starting pose while invisible.
	removeFrame.Visible =
		false

	applyRemoveHiddenPose()


	-- Make the actual Frame visible.
	removeFrame.Visible =
		true


	task.defer(
		function()
			if version
				~= removeAnimationVersion
				or not removeOpen
				or not removeFrame.Visible then

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


		-- Close visually, but keep the business ID
		-- until the server finishes the removal.
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
-- MANAGEMENT VISIBILITY HELPERS
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


	-- Don't put the world management UI behind
	-- the confirmation popup.
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

	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 5

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


	local businessType =
	getBusinessType(
		stand
	)

local businessConfig =
	businessType
	and BusinessConfig[
		businessType
	]

businessNameLabel.Text =
	businessConfig
	and businessConfig.DisplayName
	or businessType
	or "Business"


	if subtitleLabel.Text
		== "" then

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


	--==================================================
	-- MOVE
	--==================================================

	moveButton.Activated:Connect(
		function()
			if stand
				~= getClosestOwnedStand() then

				Notification.Error(
	"Your business could not be found."
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


	--==================================================
	-- MANAGE
	--==================================================

	manageButton.Activated:Connect(
		function()
			if stand
				~= getClosestOwnedStand() then

				Notification.Error(
	"Your business could not be found."
)

				return
			end


			if stand:GetAttribute(
				"IsBeingEdited"
			) == true then

				Notification.Warning(
	"Finish moving this stand first."
)

				return
			end


			if stand:GetAttribute(
				"StandUnavailable"
			) == true then

				Notification.Warning(
	"This stand is currently unavailable."
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


	--==================================================
	-- REMOVE
	--==================================================

	removeButton.Activated:Connect(
		function()
			if removeRequestPending then
				return
			end


			if stand
				~= getClosestOwnedStand() then

				Notification.Error(
	"Your business could not be found."
)

				return
			end


			pendingRemoveBusinessId =
				getBusinessId(
					stand
				)


			removeRequestPending =
				true


			-- First request asks the server whether the
			-- business can currently be removed.
			requestRemoveRemote:FireServer(
				false,
				pendingRemoveBusinessId
			)


			task.delay(
				2,
				function()
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
-- INPUT
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


			Notification.Success(
	typeof(message)
		== "string"
		and message
		or "Business removed."
)
			return
		end


		if action
			== "RemoveFailed" then

			hideRemoveConfirmation()


			Notification.Error(
	typeof(message)
		== "string"
		and message
		or "The stand could not be removed."
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


			Notification.Error(
	typeof(message)
		== "string"
		and message
		or "The stand could not be edited."
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
-- MANAGEMENT UPDATE LOOP
--==================================================

task.spawn(
	function()
		while true do
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