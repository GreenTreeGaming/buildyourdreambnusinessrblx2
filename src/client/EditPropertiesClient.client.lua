local Players =
	game:GetService("Players")

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
	player:WaitForChild(
		"PlayerGui"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local camera =
	Workspace.CurrentCamera


--==================================================
-- SETTINGS
--==================================================

local EDIT_FOV =
	50


local CAMERA_TRANSITION_TIME =
	0.55


local MIN_CAMERA_HEIGHT =
	42


local INITIAL_VIEW_PADDING =
	12


local MAX_ZOOM_OUT_MULTIPLIER =
	1.2


local MOUSE_ZOOM_SPEED =
	0.12


local PINCH_ZOOM_SPEED =
	1


local PAN_SENSITIVITY =
	1


local KEYBOARD_PAN_SPEED =
	100


local PAN_EDGE_PADDING =
	4


-- How far a finger/mouse may move before we stop
-- considering it a "tap".
local TAP_MOVEMENT_THRESHOLD =
	12


local TAP_TIME_THRESHOLD =
	0.35


--==================================================
-- UI
--==================================================

local manageGui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui


local main =
	manageGui:WaitForChild(
		"Main"
	) :: Frame


local openButton =
	manageGui:WaitForChild(
		"OpenButton"
	) :: TextButton


-- If your Studio object is named EditPropertiesButton,
-- change only this string.
local editPropertiesButton =
	main:WaitForChild(
		"EditProperties"
	) :: TextButton


local cancelEditButton =
	manageGui:WaitForChild(
		"CancelEditProperties"
	) :: TextButton

local instructionsLabel =
	manageGui:WaitForChild(
		"Instructions"
	) :: TextLabel


instructionsLabel.TextWrapped =
	true

instructionsLabel.TextXAlignment =
	Enum.TextXAlignment.Left

instructionsLabel.TextYAlignment =
	Enum.TextYAlignment.Top

instructionsLabel.Active =
	false

instructionsLabel.Selectable =
	false

local DESKTOP_INSTRUCTIONS =
	"• Left Click: Select a business\n"
	.. "• Right-Drag: Pan around your plot\n"
	.. "• Mouse Wheel: Zoom in/out\n"
	.. "• WASD / Arrow Keys: Pan\n"
	.. "• Esc: Exit bird's-eye view"


local MOBILE_INSTRUCTIONS =
	"• Tap: Select a business\n"
	.. "• Drag: Pan around your plot\n"
	.. "• Pinch: Zoom in/out\n"
	.. "• Cancel: Exit bird's-eye view"

local function updateInstructions()

	local useMobileInstructions =
		UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled


	if useMobileInstructions then

		instructionsLabel.Text =
			MOBILE_INSTRUCTIONS

	else

		instructionsLabel.Text =
			DESKTOP_INSTRUCTIONS
	end
end

--==================================================
-- SHARED EVENTS
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


--==================================================
-- STATE
--==================================================

local editingProperties =
	false


local transitionRunning =
	false


local ownedPlot:
	Model? =
	nil


local ground:
	BasePart? =
	nil


local selectedStand:
	Model? =
	nil


local selectionHighlight:
	Highlight? =
	nil


local cameraTarget =
	Vector3.zero


local cameraHeight =
	100


local minimumCameraHeight =
	MIN_CAMERA_HEIGHT


local maximumCameraHeight =
	200


local cameraTween:
	Tween? =
	nil


local groundSizeConnection:
	RBXScriptConnection? =
	nil


local groundCFrameConnection:
	RBXScriptConnection? =
	nil


--==================================================
-- NORMAL CAMERA STATE
--==================================================

local oldCameraType =
	camera.CameraType


local oldCameraSubject:
	Instance? =
	nil


local oldCameraCFrame =
	camera.CFrame


local oldCameraFieldOfView =
	camera.FieldOfView


local oldMouseBehavior =
	UserInputService.MouseBehavior


local previousMainVisible =
	false


local previousOpenVisible =
	true


local previousOpenActive =
	true


local previousOpenSelectable =
	true


--==================================================
-- DESKTOP INPUT STATE
--==================================================

local rightDragging =
	false


local lastMousePosition =
	Vector2.zero


--==================================================
-- TOUCH INPUT STATE
--==================================================

type TouchInformation = {
	StartPosition: Vector2,
	LastPosition: Vector2,
	StartedAt: number,
	Moved: boolean,
}


local touches: {
	[InputObject]: TouchInformation
} = {}


local pinchDistance:
	number? =
	nil


--==================================================
-- PLAYER CONTROLS
--==================================================

local playerControls =
	nil


local function getPlayerControls()

	if playerControls then
		return playerControls
	end


	local playerScripts =
		player:WaitForChild(
			"PlayerScripts"
		)


	local playerModule =
		playerScripts:FindFirstChild(
			"PlayerModule"
		)


	if not playerModule then
		return nil
	end


	local success,
		module =
		pcall(
			require,
			playerModule
		)


	if not success
		or type(module)
			~= "table" then

		return nil
	end


	local controlsSuccess,
		controls =
		pcall(
			function()

				return module:GetControls()
			end
		)


	if controlsSuccess then

		playerControls =
			controls


		return controls
	end


	return nil
end


local function setPlayerControlsEnabled(
	enabled: boolean
)

	local controls =
		getPlayerControls()


	if not controls then
		return
	end


	if enabled then

		pcall(
			function()

				controls:Enable()
			end
		)

	else

		pcall(
			function()

				controls:Disable()
			end
		)
	end
end


--==================================================
-- BUTTON SAFETY
--==================================================

local function prepareButton(
	button: TextButton
)

	button.Active =
		true


	button.Selectable =
		true


	for _, descendant in
		button:GetDescendants() do

		if descendant:IsA(
			"GuiObject"
		) then

			descendant.Active =
				false


			descendant.Selectable =
				false
		end
	end
end


prepareButton(
	editPropertiesButton
)


prepareButton(
	cancelEditButton
)


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
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plotsFolder:GetChildren() do

		if plot:IsA(
			"Model"
		)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	return nil
end


local function getGround(
	plot: Model
): BasePart?

	local candidate =
		plot:FindFirstChild(
			"Ground"
		)


	if candidate
		and candidate:IsA(
			"BasePart"
		) then

		return candidate
	end


	return nil
end


local function getPlacedBusinesses(
	plot: Model
): Instance?

	return plot:FindFirstChild(
		"PlacedBusinesses"
	)
end


local function getBusinessFromTarget(
	target: Instance?
): Model?

	if not target
		or not ownedPlot then

		return nil
	end


	local placedBusinesses =
		getPlacedBusinesses(
			ownedPlot
		)


	if not placedBusinesses then
		return nil
	end


	local current:
		Instance? =
		target


	while current
		and current ~= ownedPlot do

		if current:IsA(
			"Model"
		)
			and current.Parent
				== placedBusinesses then

			if current:GetAttribute(
				"OwnerUserId"
			) ~= player.UserId then

				return nil
			end


			return current
		end


		current =
			current.Parent
	end


	return nil
end


--==================================================
-- CAMERA ORIENTATION
--==================================================

local function getEntrancePosition():
	Vector3?

	if not ownedPlot then
		return nil
	end


	local customerSpawn =
		ownedPlot:FindFirstChild(
			"CustomerSpawn"
		)


	if customerSpawn
		and customerSpawn:IsA(
			"BasePart"
		) then

		return customerSpawn.Position
	end


	local playerSpawn =
		ownedPlot:FindFirstChild(
			"PlayerSpawn"
		)


	if playerSpawn
		and playerSpawn:IsA(
			"BasePart"
		) then

		return playerSpawn.Position
	end


	return nil
end


local function getScreenUpDirection():
	Vector3

	if not ground then

		return Vector3.new(
			0,
			0,
			1
		)
	end


	local entrancePosition =
		getEntrancePosition()


	if not entrancePosition then

		return ground.CFrame.LookVector
	end


	local towardEntrance =
		Vector3.new(
			entrancePosition.X
				- ground.Position.X,

			0,

			entrancePosition.Z
				- ground.Position.Z
		)


	if towardEntrance.Magnitude
		< 0.001 then

		return ground.CFrame.LookVector
	end


	-- Customer entrance stays at bottom of screen.
	return -towardEntrance.Unit
end


--==================================================
-- ZOOM LIMITS
--==================================================

local function calculateFullPlotHeight():
	number

	if not ground then
		return 100
	end


	local viewport =
		camera.ViewportSize


	local aspect =
		math.max(
			viewport.X
				/ math.max(
					viewport.Y,
					1
				),

			0.1
		)


	local halfVerticalFov =
		math.rad(
			EDIT_FOV
		) / 2


	local tangent =
		math.tan(
			halfVerticalFov
		)


	-- Since the plot is square this works well even
	-- when its orientation changes.
	local halfWidth =
		ground.Size.X / 2
			+ INITIAL_VIEW_PADDING


	local halfDepth =
		ground.Size.Z / 2
			+ INITIAL_VIEW_PADDING


	local heightForDepth =
		halfDepth
			/ tangent


	local heightForWidth =
		halfWidth
			/ (
				tangent
				* aspect
			)


	return math.max(
		heightForDepth,
		heightForWidth,
		MIN_CAMERA_HEIGHT
	)
end


local function updateZoomLimits()

	local fullPlotHeight =
		calculateFullPlotHeight()


	minimumCameraHeight =
		MIN_CAMERA_HEIGHT


	maximumCameraHeight =
		math.max(
			fullPlotHeight
				* MAX_ZOOM_OUT_MULTIPLIER,

			MIN_CAMERA_HEIGHT
				+ 20
		)


	cameraHeight =
		math.clamp(
			cameraHeight,
			minimumCameraHeight,
			maximumCameraHeight
		)
end


--==================================================
-- PAN BOUNDARIES
--==================================================

local function clampCameraTarget(
	position: Vector3
): Vector3

	if not ground then
		return position
	end


	local localPosition =
		ground.CFrame
			:PointToObjectSpace(
				position
			)


	local halfX =
		math.max(
			0,

			ground.Size.X / 2
				- PAN_EDGE_PADDING
		)


	local halfZ =
		math.max(
			0,

			ground.Size.Z / 2
				- PAN_EDGE_PADDING
		)


	localPosition =
		Vector3.new(
			math.clamp(
				localPosition.X,
				-halfX,
				halfX
			),

			0,

			math.clamp(
				localPosition.Z,
				-halfZ,
				halfZ
			)
		)


	local worldPosition =
		ground.CFrame
			:PointToWorldSpace(
				localPosition
			)


	return Vector3.new(
		worldPosition.X,
		ground.Position.Y,
		worldPosition.Z
	)
end


--==================================================
-- CAMERA
--==================================================

local function calculateCameraCFrame():
	CFrame

	local screenUp =
		getScreenUpDirection()


	local cameraPosition =
		cameraTarget
			+ Vector3.new(
				0,
				cameraHeight,
				0
			)


	return CFrame.lookAt(
		cameraPosition,
		cameraTarget,
		screenUp
	)
end


local function applyCamera()

	if not editingProperties then
		return
	end


	camera.CFrame =
		calculateCameraCFrame()


	camera.FieldOfView =
		EDIT_FOV
end


--==================================================
-- SELECTION
--==================================================

local function clearHighlight()

	if selectionHighlight then

		selectionHighlight:Destroy()


		selectionHighlight =
			nil
	end
end


local function clearSelection()

	selectedStand =
		nil


	clearHighlight()


	selectBusinessEvent:Fire(
		nil
	)
end


local function selectStand(
	stand: Model
)

	if not editingProperties then
		return
	end


	if stand:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return
	end


	selectedStand =
		stand


	clearHighlight()


	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		"EditPropertiesSelection"


	highlight.Adornee =
		stand


	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop


	highlight.FillTransparency =
		0.94


	highlight.OutlineTransparency =
		0.08


	highlight.Parent =
		stand


	selectionHighlight =
		highlight


	selectBusinessEvent:Fire(
		stand
	)
end


local function raycastBusiness(
	screenPosition: Vector2
): Model?

	if not ownedPlot then
		return nil
	end


	local ray =
		camera:ViewportPointToRay(
			screenPosition.X,
			screenPosition.Y
		)


	local params =
		RaycastParams.new()


	params.FilterType =
		Enum.RaycastFilterType.Exclude


	local excluded = {}


	if player.Character then

		table.insert(
			excluded,
			player.Character
		)
	end


	params.FilterDescendantsInstances =
		excluded


	params.IgnoreWater =
		true


	local result =
		Workspace:Raycast(
			ray.Origin,

			ray.Direction
				* 5000,

			params
		)


	if not result then
		return nil
	end


	return getBusinessFromTarget(
		result.Instance
	)
end


local function selectAtScreenPosition(
	position: Vector2
)

	if player:GetAttribute(
		"EditingBusiness"
	) then

		return
	end


	local stand =
		raycastBusiness(
			position
		)


	if stand then

		selectStand(
			stand
		)

	else
		clearSelection()
	end
end


--==================================================
-- PAN
--==================================================

local function getStudsPerPixel():
	number

	local viewportHeight =
		math.max(
			camera.ViewportSize.Y,
			1
		)


	local visibleWorldHeight =
		2
			* cameraHeight
			* math.tan(
				math.rad(
					EDIT_FOV
				) / 2
			)


	return visibleWorldHeight
		/ viewportHeight
end


local function panByScreenDelta(
	delta: Vector2
)

	local studsPerPixel =
		getStudsPerPixel()
			* PAN_SENSITIVITY


	local right =
		Vector3.new(
			camera.CFrame.RightVector.X,
			0,
			camera.CFrame.RightVector.Z
		)


	local up =
		Vector3.new(
			camera.CFrame.UpVector.X,
			0,
			camera.CFrame.UpVector.Z
		)


	if right.Magnitude > 0 then

		right =
			right.Unit
	end


	if up.Magnitude > 0 then

		up =
			up.Unit
	end


	local movement =
		-right
			* delta.X
			* studsPerPixel

		+ up
			* delta.Y
			* studsPerPixel


	cameraTarget =
		clampCameraTarget(
			cameraTarget
				+ movement
		)
end


--==================================================
-- ZOOM
--==================================================

local function zoomByMultiplier(
	multiplier: number
)

	cameraHeight =
		math.clamp(
			cameraHeight
				* multiplier,

			minimumCameraHeight,
			maximumCameraHeight
		)
end


local function zoomMouseWheel(
	wheelDelta: number
)

	local multiplier =
		math.exp(
			-wheelDelta
				* MOUSE_ZOOM_SPEED
		)


	zoomByMultiplier(
		multiplier
	)
end


--==================================================
-- TOUCH HELPERS
--==================================================

local function getActiveTouchCount():
	number

	local count =
		0


	for _ in touches do

		count +=
			1
	end


	return count
end


local function getTwoTouchPositions():
	(Vector2?, Vector2?)

	local first:
		Vector2? =
		nil


	local second:
		Vector2? =
		nil


	for _, info in touches do

		if not first then

			first =
				info.LastPosition

		else

			second =
				info.LastPosition


			break
		end
	end


	return first,
		second
end


local function updatePinch()

	if getActiveTouchCount()
		~= 2 then

		pinchDistance =
			nil


		return
	end


	local first,
		second =
		getTwoTouchPositions()


	if not first
		or not second then

		return
	end


	local distance =
		(first - second).Magnitude


	if distance <= 0 then
		return
	end


	if pinchDistance then

		local ratio =
			pinchDistance
				/ distance


		zoomByMultiplier(
			ratio
				^ PINCH_ZOOM_SPEED
		)
	end


	pinchDistance =
		distance
end


--==================================================
-- PLOT CONNECTIONS
--==================================================

local function disconnectPlotConnections()

	if groundSizeConnection then

		groundSizeConnection:Disconnect()


		groundSizeConnection =
			nil
	end


	if groundCFrameConnection then

		groundCFrameConnection:Disconnect()


		groundCFrameConnection =
			nil
	end
end


--==================================================
-- EDITOR CAMERA LOOP
--==================================================

local function startEditorCameraLoop()

	RunService:UnbindFromRenderStep(
		"EditPropertiesCamera"
	)


	RunService:BindToRenderStep(
		"EditPropertiesCamera",

		Enum.RenderPriority.Camera.Value
			+ 1,

		function(
			deltaTime: number
		)

			if not editingProperties
				or transitionRunning then

				return
			end


			-- Desktop keyboard panning.
			local horizontal =
				0


			local vertical =
				0


			if UserInputService:IsKeyDown(
				Enum.KeyCode.A
			)
				or UserInputService:IsKeyDown(
					Enum.KeyCode.Left
				) then

				horizontal -=
					1
			end


			if UserInputService:IsKeyDown(
				Enum.KeyCode.D
			)
				or UserInputService:IsKeyDown(
					Enum.KeyCode.Right
				) then

				horizontal +=
					1
			end


			if UserInputService:IsKeyDown(
				Enum.KeyCode.W
			)
				or UserInputService:IsKeyDown(
					Enum.KeyCode.Up
				) then

				vertical +=
					1
			end


			if UserInputService:IsKeyDown(
				Enum.KeyCode.S
			)
				or UserInputService:IsKeyDown(
					Enum.KeyCode.Down
				) then

				vertical -=
					1
			end


			if horizontal ~= 0
				or vertical ~= 0 then

				local right =
					Vector3.new(
						camera.CFrame.RightVector.X,
						0,
						camera.CFrame.RightVector.Z
					)


				local up =
					Vector3.new(
						camera.CFrame.UpVector.X,
						0,
						camera.CFrame.UpVector.Z
					)


				if right.Magnitude > 0 then

					right =
						right.Unit
				end


				if up.Magnitude > 0 then

					up =
						up.Unit
				end


				local direction =
					right * horizontal
						+ up * vertical


				if direction.Magnitude
					> 0 then

					direction =
						direction.Unit
				end


				local heightScale =
					math.max(
						cameraHeight
							/ 100,

						0.5
					)


				cameraTarget =
					clampCameraTarget(
						cameraTarget
							+ direction
								* KEYBOARD_PAN_SPEED
								* heightScale
								* deltaTime
					)
			end


			applyCamera()
		end
	)
end


--==================================================
-- EXIT EDIT MODE
--==================================================

local function exitEditMode()

	if not editingProperties
		or transitionRunning then

		return
	end


	transitionRunning =
		true


	rightDragging =
		false


	touches =
		{}


	pinchDistance =
		nil


	disconnectPlotConnections()


	clearSelection()


	editPropertiesModeEvent:Fire(
		false
	)


	RunService:UnbindFromRenderStep(
		"EditPropertiesCamera"
	)


	if cameraTween then

		cameraTween:Cancel()


		cameraTween =
			nil
	end


	-- Keep normal movement disabled until the
	-- camera has returned.
	setPlayerControlsEnabled(
		false
	)


	UserInputService.MouseBehavior =
		Enum.MouseBehavior.Default


	camera.CameraType =
		Enum.CameraType.Scriptable


	local returnTween =
		TweenService:Create(
			camera,

			TweenInfo.new(
				CAMERA_TRANSITION_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.InOut
			),

			{
				CFrame =
					oldCameraCFrame,

				FieldOfView =
					oldCameraFieldOfView,
			}
		)


	cameraTween =
		returnTween


	returnTween:Play()


	returnTween.Completed:Once(
		function()

			if cameraTween
				~= returnTween then

				return
			end


			cameraTween =
				nil


			camera.CameraType =
				oldCameraType


			camera.CameraSubject =
				oldCameraSubject


			camera.CFrame =
				oldCameraCFrame


			camera.FieldOfView =
				oldCameraFieldOfView


			UserInputService.MouseBehavior =
				oldMouseBehavior


			setPlayerControlsEnabled(
				true
			)


			main.Visible =
				previousMainVisible


			-- Keep original side-button state.
			openButton.Visible =
				previousOpenVisible


			openButton.Active =
				previousOpenActive


			openButton.Selectable =
				previousOpenSelectable


			openButton.AutoButtonColor =
				true


			cancelEditButton.Visible =
				false

			instructionsLabel.Visible =
	false


			ownedPlot =
				nil


			ground =
				nil


			editingProperties =
				false


			transitionRunning =
				false
		end
	)
end


--==================================================
-- ENTER EDIT MODE
--==================================================

local function enterEditMode()

	if editingProperties
		or transitionRunning then

		return
	end


	local plot =
		getOwnedPlot()


	if not plot then

		warn(
			"[EditProperties] Could not find owned plot."
		)


		return
	end


	local plotGround =
		getGround(
			plot
		)


	if not plotGround then

		warn(
			"[EditProperties] Plot is missing Ground."
		)


		return
	end


	editingProperties =
		true


	transitionRunning =
		true


	ownedPlot =
		plot


	ground =
		plotGround


	rightDragging =
		false


	touches =
		{}


	pinchDistance =
		nil


	--==================================================
	-- SAVE UI STATE
	--==================================================

	previousMainVisible =
		main.Visible


	previousOpenVisible =
		openButton.Visible


	previousOpenActive =
		openButton.Active


	previousOpenSelectable =
		openButton.Selectable


	--==================================================
	-- SAVE CAMERA STATE
	--==================================================

	oldCameraType =
		camera.CameraType


	oldCameraSubject =
		camera.CameraSubject


	oldCameraCFrame =
		camera.CFrame


	oldCameraFieldOfView =
		camera.FieldOfView


	oldMouseBehavior =
		UserInputService.MouseBehavior


	--==================================================
	-- EDITOR UI
	--==================================================

	main.Visible =
		false


	-- Keep side Manage button visible, but don't let
	-- it reopen the large menu while editing.
	openButton.Visible =
		true


	openButton.Active =
		false


	openButton.Selectable =
		false


	openButton.AutoButtonColor =
		false


	cancelEditButton.Visible =
		true

	updateInstructions()


instructionsLabel.Visible =
	true


	cancelEditButton.ZIndex =
		100


	clearSelection()


	editPropertiesModeEvent:Fire(
		true
	)


	--==================================================
	-- DISABLE CHARACTER
	--==================================================

	setPlayerControlsEnabled(
		false
	)


	UserInputService.MouseBehavior =
		Enum.MouseBehavior.Default


	--==================================================
	-- INITIAL EDITOR CAMERA
	--==================================================

	cameraTarget =
		Vector3.new(
			plotGround.Position.X,
			plotGround.Position.Y,
			plotGround.Position.Z
		)


	cameraHeight =
		calculateFullPlotHeight()


	updateZoomLimits()


	cameraHeight =
		math.clamp(
			cameraHeight,
			minimumCameraHeight,
			maximumCameraHeight
		)


	if cameraTween then

		cameraTween:Cancel()


		cameraTween =
			nil
	end


	RunService:UnbindFromRenderStep(
		"EditPropertiesCamera"
	)


	camera.CameraType =
		Enum.CameraType.Scriptable


	local targetCFrame =
		calculateCameraCFrame()


	local enterTween =
		TweenService:Create(
			camera,

			TweenInfo.new(
				CAMERA_TRANSITION_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.InOut
			),

			{
				CFrame =
					targetCFrame,

				FieldOfView =
					EDIT_FOV,
			}
		)


	cameraTween =
		enterTween


	enterTween:Play()


	enterTween.Completed:Once(
		function()

			if cameraTween
					~= enterTween
				or not editingProperties then

				return
			end


			cameraTween =
				nil


			transitionRunning =
				false


			startEditorCameraLoop()
		end
	)


	--==================================================
	-- PLOT RESIZE SUPPORT
	--==================================================

	disconnectPlotConnections()


	groundSizeConnection =
		plotGround:GetPropertyChangedSignal(
			"Size"
		):Connect(
			function()

				if not editingProperties then
					return
				end


				updateZoomLimits()


				cameraTarget =
					clampCameraTarget(
						cameraTarget
					)
			end
		)


	groundCFrameConnection =
		plotGround:GetPropertyChangedSignal(
			"CFrame"
		):Connect(
			function()

				if not editingProperties then
					return
				end


				updateZoomLimits()


				cameraTarget =
					clampCameraTarget(
						cameraTarget
					)
			end
		)
end


--==================================================
-- DESKTOP INPUT
--==================================================

UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		gameProcessed: boolean
	)

		if not editingProperties
			or transitionRunning then

			return
		end


		if input.KeyCode
				== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			exitEditMode()


			return
		end


		if gameProcessed then
			return
		end


		if input.UserInputType
			== Enum.UserInputType.MouseButton2 then

			rightDragging =
				true


			local position =
				UserInputService:GetMouseLocation()


			lastMousePosition =
				Vector2.new(
					position.X,
					position.Y
				)


			return
		end


		if input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			local position =
				UserInputService:GetMouseLocation()


			selectAtScreenPosition(
				Vector2.new(
					position.X,
					position.Y
				)
			)
		end
	end
)


UserInputService.InputChanged:Connect(
	function(
		input: InputObject
	)

		if not editingProperties
			or transitionRunning then

			return
		end


		if input.UserInputType
			== Enum.UserInputType.MouseWheel then

			zoomMouseWheel(
				input.Position.Z
			)


			return
		end


		if rightDragging
			and input.UserInputType
				== Enum.UserInputType.MouseMovement then

			local position =
				Vector2.new(
					input.Position.X,
					input.Position.Y
				)


			local delta =
				position
					- lastMousePosition


			lastMousePosition =
				position


			panByScreenDelta(
				delta
			)
		end
	end
)


UserInputService.InputEnded:Connect(
	function(
		input: InputObject
	)

		if input.UserInputType
			== Enum.UserInputType.MouseButton2 then

			rightDragging =
				false
		end
	end
)

--==================================================
-- MOBILE TOUCH INPUT
--==================================================

UserInputService.TouchStarted:Connect(
	function(
		input: InputObject,
		_gameProcessed: boolean
	)

		if not editingProperties
			or transitionRunning then

			return
		end


		local position =
			Vector2.new(
				input.Position.X,
				input.Position.Y
			)


		touches[input] = {
			StartPosition =
				position,

			LastPosition =
				position,

			StartedAt =
				time(),

			Moved =
				false,
		}


		if getActiveTouchCount()
			== 2 then

			local first,
				second =
				getTwoTouchPositions()


			if first
				and second then

				pinchDistance =
					(first - second).Magnitude
			end
		end
	end
)


UserInputService.TouchMoved:Connect(
	function(
		input: InputObject,
		_gameProcessed: boolean
	)

		if not editingProperties
			or transitionRunning then

			return
		end


		local info =
			touches[input]


		if not info then
			return
		end


		local newPosition =
			Vector2.new(
				input.Position.X,
				input.Position.Y
			)


		local delta =
			newPosition
				- info.LastPosition


		info.LastPosition =
			newPosition


		if (
			newPosition
				- info.StartPosition
		).Magnitude
			>= TAP_MOVEMENT_THRESHOLD then

			info.Moved =
				true
		end


		local touchCount =
			getActiveTouchCount()


		if touchCount >= 2 then

			-- Two fingers = zoom.
			updatePinch()


			-- Neither finger should later be
			-- interpreted as a selection tap.
			for _, touchInfo in touches do

				touchInfo.Moved =
					true
			end


			return
		end


		-- One finger = pan.
		panByScreenDelta(
			delta
		)
	end
)


UserInputService.TouchEnded:Connect(
	function(
		input: InputObject,
		_gameProcessed: boolean
	)

		local info =
			touches[input]


		touches[input] =
			nil


		if not editingProperties
			or transitionRunning then

			pinchDistance =
				nil

			return
		end


		if getActiveTouchCount()
			< 2 then

			pinchDistance =
				nil
		end


		if not info then
			return
		end


		local endPosition =
			Vector2.new(
				input.Position.X,
				input.Position.Y
			)


		info.LastPosition =
			endPosition


		local totalMovement =
			(
				endPosition
					- info.StartPosition
			).Magnitude


		local duration =
			time()
				- info.StartedAt


		-- A quick finger press with very little
		-- movement counts as selecting a business.
		if not info.Moved
			and totalMovement
				< TAP_MOVEMENT_THRESHOLD
			and duration
				<= TAP_TIME_THRESHOLD then

			selectAtScreenPosition(
				endPosition
			)
		end
	end
)

--==================================================
-- BUTTONS
--==================================================

editPropertiesButton.MouseButton1Click:Connect(
	enterEditMode
)


cancelEditButton.MouseButton1Click:Connect(
	exitEditMode
)


-- Activated also helps gamepad/touch accessibility.
editPropertiesButton.Activated:Connect(
	function()

		if UserInputService.GamepadEnabled then

			enterEditMode()
		end
	end
)


cancelEditButton.Activated:Connect(
	function()

		if UserInputService.GamepadEnabled then

			exitEditMode()
		end
	end
)


--==================================================
-- CLEANUP
--==================================================

player.CharacterRemoving:Connect(
	function()

		if editingProperties
			and not transitionRunning then

			exitEditMode()
		end
	end
)


player:GetAttributeChangedSignal(
	"PlotName"
):Connect(
	function()

		if editingProperties
			and not transitionRunning then

			exitEditMode()
		end
	end
)


cancelEditButton.Visible =
	false


instructionsLabel.Visible =
	false

print(
	"EditPropertiesClient started."
)