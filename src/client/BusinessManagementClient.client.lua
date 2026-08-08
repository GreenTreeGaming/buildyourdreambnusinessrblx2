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

local Fonts =
	UITheme.Fonts


local BUSINESS_NAME =
	"LemonadeStand"


local MANAGEMENT_DISTANCE =
	22


local UPDATE_INTERVAL =
	0.1


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
-- CURRENT MANAGEMENT BILLBOARD
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
-- REMOVE CONFIRMATION
--==================================================

local confirmationScreen:
	ScreenGui? =
	nil


local confirmationOverlay:
	Frame? =
	nil


local confirmationWindow:
	Frame? =
	nil


local confirmationScale:
	UIScale? =
	nil


local confirmationOpen =
	false


local confirmationAnimating =
	false


local confirmRemoveButton:
	TextButton? =
	nil


local toastLabel:
	TextLabel? =
	nil


local toastVersion =
	0


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
		placedBusinesses:GetChildren() do

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


--==================================================
-- TOAST
--==================================================

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
			if toastVersion
				~= version then

				return
			end


			if toastLabel then
				toastLabel.Visible =
					false
			end
		end
	)
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


	for _, descendant in
		button:GetDescendants() do

		if descendant:IsA(
			"GuiObject"
		) then

			descendant.Active =
				false
		end
	end


	local scale =
		button:FindFirstChildOfClass(
			"UIScale"
		)


	if not scale then
		scale =
			Instance.new(
				"UIScale"
			)

		scale.Scale =
			1

		scale.Parent =
			button
	end


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


	button.MouseEnter:Connect(function()
		if button.Active then
			tweenTo(
				1.045,
				0.1
			)
		end
	end)


	button.MouseLeave:Connect(function()
		tweenTo(
			1,
			0.1
		)
	end)


	button.MouseButton1Down:Connect(function()
		if button.Active then
			tweenTo(
				0.94,
				0.06
			)
		end
	end)


	button.MouseButton1Up:Connect(function()
		if button.Active then
			tweenTo(
				1.045,
				0.08
			)
		end
	end)
end


--==================================================
-- MANAGEMENT VISIBILITY
--==================================================

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

local MANAGEMENT_OPEN_SCALE =
	0.88


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


	if managementVisible
		== visible then

		return
	end


	managementVisible =
		visible


	managementVisibilityVersion += 1


	local version =
		managementVisibilityVersion


	stopManagementTweens()


	if visible then
		-- IMPORTANT:
		-- Put the GUI into its hidden pose BEFORE
		-- Roblox is allowed to render it.
		managementGui.Enabled =
			false


		applyManagementHiddenPose()


		-- Now enable it. The first visible frame will
		-- already be in the small/lowered position.
		managementGui.Enabled =
			true


		-- Starting the tween on the next task gives
		-- Roblox a chance to render the initial pose.
		task.defer(function()
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


			rootTween.Completed:Once(function()
				if managementActiveRootTween
					== rootTween then

					managementActiveRootTween =
						nil
				end
			end)


			positionTween.Completed:Once(function()
				if managementActivePositionTween
					== positionTween then

					managementActivePositionTween =
						nil
				end
			end)


			rootTween:Play()
			positionTween:Play()
		end)


		return
	end


	--==================================================
	-- CLOSE
	--==================================================

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


	rootTween.Completed:Once(function()
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


		-- Keep it in the hidden pose while invisible.
		-- That way the next approach ALWAYS starts
		-- correctly.
		if managementRoot
			and managementGui then

			applyManagementHiddenPose()
		end
	end)
end

local function destroyManagementUI()
	stopManagementTweens()


	managementVisibilityVersion += 1

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
-- CREATE MANAGEMENT UI FROM REPLICATEDSTORAGE
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


	-- Clone YOUR Studio-built billboard.
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


	-- Keep all of the Size / StudsOffset / styling
	-- exactly how you designed it in Studio.


	local root =
		billboard:WaitForChild(
			"Frame"
		) :: Frame

	managementRoot =
	root


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


	-- You can change this text in Studio if you want.
	-- We only provide a fallback when it is blank.
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

	--==================================================
	-- MOVE
	--==================================================

	moveButton.Activated:Connect(function()
		if stand
			~= getClosestOwnedStand() then

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
	end)


	--==================================================
	-- MANAGE
	--==================================================

	manageButton.Activated:Connect(function()
		if stand
			~= getClosestOwnedStand() then

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
	end)


	--==================================================
	-- REMOVE
	--==================================================

	removeButton.Activated:Connect(function()
		if removeRequestPending then
			return
		end


		if stand
			~= getClosestOwnedStand() then

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


		requestRemoveRemote:FireServer(
			false,
			pendingRemoveBusinessId
		)


		task.delay(
			2,
			function()
				removeRequestPending =
					false
			end
		)
	end)


	managementGui =
	billboard


managementStand =
	stand


managementVisible =
	false


-- A newly created billboard should already be
-- prepared for its first entrance animation.
managementGui.Enabled =
	false


applyManagementHiddenPose()
end


--==================================================
-- REMOVE CONFIRMATION UI
--==================================================

local function hideRemoveConfirmation(
	clearPendingId: boolean?
)
	if not confirmationOverlay
		or not confirmationScale then

		return
	end


	if not confirmationOpen then
		if clearPendingId
			~= false then

			removeRequestPending =
				false

			pendingRemoveBusinessId =
				nil
		end

		return
	end


	if confirmationAnimating then
		return
	end


	confirmationOpen =
		false


	confirmationAnimating =
		true


	local overlayTween =
		TweenService:Create(
			confirmationOverlay,

			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				BackgroundTransparency =
					1,
			}
		)


	local windowTween =
		TweenService:Create(
			confirmationScale,

			TweenInfo.new(
				0.14,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					0.92,
			}
		)


	overlayTween:Play()
	windowTween:Play()


	windowTween.Completed:Once(function()
		confirmationAnimating =
			false


		if confirmationOpen then
			return
		end


		if confirmationOverlay then
			confirmationOverlay.Visible =
				false
		end


		if clearPendingId
			~= false then

			removeRequestPending =
				false

			pendingRemoveBusinessId =
				nil
		end
	end)
end


local function showRemoveConfirmation()
	if not confirmationOverlay
		or not confirmationScale
		or confirmationOpen then

		return
	end


	confirmationOpen =
		true


	confirmationAnimating =
		false


	confirmationOverlay.Visible =
		true


	confirmationOverlay.BackgroundTransparency =
		1


	confirmationScale.Scale =
		0.88


	TweenService:Create(
		confirmationOverlay,

		TweenInfo.new(
			0.18,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			BackgroundTransparency =
				0.3,
		}
	):Play()


	TweenService:Create(
		confirmationScale,

		TweenInfo.new(
			0.22,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),

		{
			Scale =
				1,
		}
	):Play()
end


local function createConfirmationUI()
	local old =
		playerGui:FindFirstChild(
			"RemoveBusinessConfirmation"
		)


	if old then
		old:Destroy()
	end


	local screenGui =
		Instance.new(
			"ScreenGui"
		)


	screenGui.Name =
		"RemoveBusinessConfirmation"


	screenGui.IgnoreGuiInset =
		true


	screenGui.ResetOnSpawn =
		false


	screenGui.DisplayOrder =
		100


	screenGui.Parent =
		playerGui


	local overlay =
		Instance.new(
			"Frame"
		)


	overlay.Name =
		"Overlay"


	overlay.Size =
		UDim2.fromScale(
			1,
			1
		)


	overlay.BackgroundColor3 =
		Color3.new(
			0,
			0,
			0
		)


	overlay.BackgroundTransparency =
		1


	overlay.BorderSizePixel =
		0


	overlay.Visible =
		false


	overlay.Active =
		true


	overlay.Parent =
		screenGui


	local window =
		Instance.new(
			"Frame"
		)


	window.Name =
		"Window"


	window.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	window.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)


	window.Size =
		UDim2.fromOffset(
			520,
			280
		)


	window.BackgroundColor3 =
		Colors.Surface


	window.BorderSizePixel =
		0


	window.Parent =
		overlay


	UITheme.AddCorner(
		window,
		0.06
	)


	UITheme.AddStroke(
		window,
		Colors.Stroke,
		2,
		0.15
	)


	local scale =
		Instance.new(
			"UIScale"
		)


	scale.Scale =
		1


	scale.Parent =
		window


	local title =
		Instance.new(
			"TextLabel"
		)


	title.Name =
		"Title"


	title.Position =
		UDim2.fromOffset(
			26,
			24
		)


	title.Size =
		UDim2.new(
			1,
			-52,
			0,
			48
		)


	title.BackgroundTransparency =
		1


	title.Text =
		"Remove Lemonade Stand?"


	title.TextXAlignment =
		Enum.TextXAlignment.Left


	title.Parent =
		window


	UITheme.StyleText(
		title,
		18,
		26,
		Colors.Text,
		Fonts.Black
	)


	local description =
		Instance.new(
			"TextLabel"
		)


	description.Position =
		UDim2.fromOffset(
			26,
			82
		)


	description.Size =
		UDim2.new(
			1,
			-52,
			0,
			82
		)


	description.BackgroundTransparency =
		1


	description.Text =
		"Customers waiting at this stand will leave. Your other stands will continue operating normally."


	description.TextWrapped =
		true


	description.TextXAlignment =
		Enum.TextXAlignment.Left


	description.TextYAlignment =
		Enum.TextYAlignment.Top


	description.Parent =
		window


	UITheme.StyleText(
		description,
		10,
		16,
		Colors.TextMuted,
		Fonts.Medium
	)


	local buttons =
		Instance.new(
			"Frame"
		)


	buttons.Position =
		UDim2.new(
			0,
			26,
			1,
			-82
		)


	buttons.Size =
		UDim2.new(
			1,
			-52,
			0,
			56
		)


	buttons.BackgroundTransparency =
		1


	buttons.Parent =
		window


	local layout =
		Instance.new(
			"UIListLayout"
		)


	layout.FillDirection =
		Enum.FillDirection.Horizontal


	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center


	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center


	layout.Padding =
		UDim.new(
			0,
			12
		)


	layout.Parent =
		buttons


	local keepButton =
		Instance.new(
			"TextButton"
		)


	keepButton.Name =
		"Keep"


	keepButton.Size =
		UDim2.new(
			0.5,
			-6,
			1,
			0
		)


	keepButton.Text =
		"KEEP STAND"


	keepButton.BackgroundColor3 =
		Colors.SurfaceRaised


	keepButton.TextColor3 =
		Colors.Text


	keepButton.Parent =
		buttons


	UITheme.AddCorner(
		keepButton,
		0.12
	)


	UITheme.AddStroke(
		keepButton,
		Colors.Stroke,
		1.5,
		0.25
	)


	UITheme.StyleText(
		keepButton,
		11,
		18,
		Colors.Text,
		Fonts.Black
	)


	local removeButton =
		Instance.new(
			"TextButton"
		)


	removeButton.Name =
		"Remove"


	removeButton.Size =
		UDim2.new(
			0.5,
			-6,
			1,
			0
		)


	removeButton.Text =
		"REMOVE STAND"


	removeButton.BackgroundColor3 =
		Colors.Danger


	removeButton.TextColor3 =
		Colors.Text


	removeButton.Parent =
		buttons


	UITheme.AddCorner(
		removeButton,
		0.12
	)


	UITheme.AddStroke(
		removeButton,
		Colors.DangerDark,
		1.5,
		0.15
	)


	UITheme.StyleText(
		removeButton,
		11,
		18,
		Colors.Text,
		Fonts.Black
	)


	prepareButton(
		keepButton
	)


	prepareButton(
		removeButton
	)


	keepButton.Activated:Connect(function()
		hideRemoveConfirmation()
	end)


	removeButton.Activated:Connect(function()
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


		removeButton.Active =
			false


		removeButton.Selectable =
			false


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


				if removeButton then
					removeButton.Active =
						true


					removeButton.Selectable =
						true
				end
			end
		)
	end)


	local toast =
		Instance.new(
			"TextLabel"
		)


	toast.Name =
		"Toast"


	toast.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)


	toast.Position =
		UDim2.new(
			0.5,
			0,
			0,
			18
		)


	toast.Size =
		UDim2.fromOffset(
			560,
			50
		)


	toast.BackgroundColor3 =
		Colors.Surface


	toast.BackgroundTransparency =
		0.04


	toast.BorderSizePixel =
		0


	toast.Visible =
		false


	toast.Parent =
		screenGui


	UITheme.AddCorner(
		toast,
		0.15
	)


	UITheme.AddStroke(
		toast,
		Colors.Stroke,
		1.5,
		0.2
	)


	UITheme.StyleText(
		toast,
		10,
		16,
		Colors.Text,
		Fonts.Bold
	)


	confirmationScreen =
		screenGui


	confirmationOverlay =
		overlay


	confirmationWindow =
		window


	confirmationScale =
		scale


	confirmRemoveButton =
		removeButton


	toastLabel =
		toast
end


createConfirmationUI()


--==================================================
-- INPUT
--==================================================

UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		gameProcessed: boolean
	)
		if not confirmationOpen then
			return
		end


		if input.KeyCode
			== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			hideRemoveConfirmation()

			return
		end


		if gameProcessed then
			return
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

player.CharacterRemoving:Connect(function()
	setManagementVisible(
		false
	)


	hideRemoveConfirmation()
end)


--==================================================
-- MANAGEMENT UPDATE LOOP
--==================================================

task.spawn(function()
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


				task.spawn(function()
					createManagementUI(
						stand
					)


					managementCreationPending =
						false
				end)

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
end)