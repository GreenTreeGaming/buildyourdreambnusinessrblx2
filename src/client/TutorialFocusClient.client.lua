local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- TUTORIAL UI
--==================================================

local tutorialGui =
	playerGui:WaitForChild(
		"Tutorial"
	) :: ScreenGui


local tutorialFrame =
	tutorialGui:WaitForChild(
		"Frame"
	) :: GuiObject


--==================================================
-- CONFIG
--==================================================

--
-- 0 = completely black
-- 1 = invisible
--
local DIM_TRANSPARENCY =
	0.22


local FADE_TIME =
	0.22


local SPOTLIGHT_MOVE_TIME =
	0.25


local SPOTLIGHT_PADDING_X =
	10


local SPOTLIGHT_PADDING_Y =
	8


--
-- Slight overlap prevents 1px seams between
-- the four darkness panels.
--
local PANEL_OVERLAP =
	2


local OVERLAY_DISPLAY_ORDER =
	10000


local TUTORIAL_DISPLAY_ORDER =
	10001


--==================================================
-- FOCUS MODES
--==================================================
--
-- "Dim"
--     Dark background.
--     If a tutorial highlight exists, create spotlight.
--
-- "Clear"
--     No darkness at all.
--     Used for 3D world interaction.
--
--==================================================

local FOCUS_MODE_ATTRIBUTE =
	"TutorialFocusMode"


if typeof(
	tutorialGui:GetAttribute(
		FOCUS_MODE_ATTRIBUTE
	)
) ~= "string" then

	tutorialGui:SetAttribute(
		FOCUS_MODE_ATTRIBUTE,
		"Dim"
	)
end


--==================================================
-- HIGHLIGHT NAMES
--==================================================

local VALID_HIGHLIGHT_NAMES = {
	TutorialHighlight = true,
	ContextualTutorialHighlight = true,
}


--==================================================
-- REMOVE OLD OVERLAY
--==================================================

local oldOverlay =
	playerGui:FindFirstChild(
		"TutorialFocusOverlay"
	)


if oldOverlay then
	oldOverlay:Destroy()
end


--==================================================
-- SCREEN GUI
--==================================================

local overlayGui =
	Instance.new(
		"ScreenGui"
	)


overlayGui.Name =
	"TutorialFocusOverlay"

overlayGui.ResetOnSpawn =
	false

overlayGui.IgnoreGuiInset =
	tutorialGui.IgnoreGuiInset

overlayGui.DisplayOrder =
	OVERLAY_DISPLAY_ORDER

overlayGui.ZIndexBehavior =
	Enum.ZIndexBehavior.Global

overlayGui.Enabled =
	true

overlayGui.Parent =
	playerGui


--
-- Tutorial text ALWAYS stays above darkness.
--
tutorialGui.DisplayOrder =
	math.max(
		tutorialGui.DisplayOrder,
		TUTORIAL_DISPLAY_ORDER
	)


--==================================================
-- ROOT
--==================================================

local root =
	Instance.new(
		"Frame"
	)


root.Name =
	"Root"

root.BackgroundTransparency =
	1

root.BorderSizePixel =
	0

root.Position =
	UDim2.fromScale(
		0,
		0
	)

root.Size =
	UDim2.fromScale(
		1,
		1
	)

root.Visible =
	false


--
-- VERY IMPORTANT:
--
-- The focus overlay must NEVER eat 3D clicks.
--
root.Active =
	false

root.Selectable =
	false

root.ZIndex =
	1

root.Parent =
	overlayGui


--==================================================
-- PANELS
--==================================================

local function createPanel(
	name: string
): Frame

	local frame =
		Instance.new(
			"Frame"
		)


	frame.Name =
		name

	frame.BackgroundColor3 =
		Color3.new(
			0,
			0,
			0
		)

	frame.BackgroundTransparency =
		1

	frame.BorderSizePixel =
		0


	--
	-- CRITICAL:
	--
	-- Do NOT block mouse/touch input.
	--
	-- This fixes placement and all future
	-- world-interaction tutorial steps.
	--
	frame.Active =
		false

	frame.Selectable =
		false

	frame.ZIndex =
		1

	frame.Parent =
		root


	return frame
end


local topPanel =
	createPanel(
		"Top"
	)


local bottomPanel =
	createPanel(
		"Bottom"
	)


local leftPanel =
	createPanel(
		"Left"
	)


local rightPanel =
	createPanel(
		"Right"
	)


local panels = {
	topPanel,
	bottomPanel,
	leftPanel,
	rightPanel,
}


--==================================================
-- STATE
--==================================================

local currentMode =
	"Hidden"


local currentTarget:
	GuiObject? =
	nil


local activeTweens: {
	Tween
} = {}


local transitionVersion =
	0


local followingSpotlight =
	false


local refreshScheduled =
	false


--==================================================
-- TWEEN HELPERS
--==================================================

local function cancelTweens()

	for _, tween in
		activeTweens
	do

		tween:Cancel()
	end


	table.clear(
		activeTweens
	)
end


local function createTween(
	object: Instance,
	info: TweenInfo,
	properties: {
		[string]: any
	}
): Tween

	local tween =
		TweenService:Create(
			object,
			info,
			properties
		)


	table.insert(
		activeTweens,
		tween
	)


	tween:Play()


	return tween
end


--==================================================
-- FULL DIM GEOMETRY
--==================================================

local function applyFullDimGeometry()

	local width =
		root.AbsoluteSize.X

	local height =
		root.AbsoluteSize.Y


	topPanel.Position =
		UDim2.fromOffset(
			0,
			0
		)

	topPanel.Size =
		UDim2.fromOffset(
			width,
			height
		)


	bottomPanel.Position =
		UDim2.fromOffset(
			0,
			height
		)

	bottomPanel.Size =
		UDim2.fromOffset(
			width,
			0
		)


	leftPanel.Position =
		UDim2.fromOffset(
			0,
			0
		)

	leftPanel.Size =
		UDim2.fromOffset(
			0,
			0
		)


	rightPanel.Position =
		UDim2.fromOffset(
			width,
			0
		)

	rightPanel.Size =
		UDim2.fromOffset(
			0,
			0
		)
end


--==================================================
-- TARGET VISIBILITY
--==================================================

local function isTargetUsable(
	target: GuiObject?
): boolean

	if not target
		or not target.Parent then

		return false
	end


	if not target:IsDescendantOf(
		playerGui
	) then

		return false
	end


	if not target.Visible then
		return false
	end


	if target.AbsoluteSize.X <= 1
		or target.AbsoluteSize.Y <= 1 then

		return false
	end


	local ancestor =
		target.Parent


	while ancestor
		and ancestor ~= playerGui do

		if ancestor:IsA(
			"GuiObject"
		)
			and not ancestor.Visible then

			return false
		end


		if ancestor:IsA(
			"ScreenGui"
		)
			and not ancestor.Enabled then

			return false
		end


		ancestor =
			ancestor.Parent
	end


	return true
end


--==================================================
-- VISIBLE RECT
--==================================================
--
-- This intersects the target with clipping parents.
--
-- It fixes weird giant spotlight holes when a button
-- lives in a ScrollingFrame or clipped menu.
--
--==================================================

local function getVisibleRect(
	target: GuiObject
): (
	number,
	number,
	number,
	number
)

	local rootPosition =
		root.AbsolutePosition

	local rootSize =
		root.AbsoluteSize


	local left =
		target.AbsolutePosition.X

	local top =
		target.AbsolutePosition.Y

	local right =
		left
		+ target.AbsoluteSize.X

	local bottom =
		top
		+ target.AbsoluteSize.Y


	local ancestor =
		target.Parent


	while ancestor
		and ancestor ~= playerGui do

		if ancestor:IsA(
			"GuiObject"
		)
			and ancestor.ClipsDescendants then

			local ancestorLeft =
				ancestor.AbsolutePosition.X

			local ancestorTop =
				ancestor.AbsolutePosition.Y

			local ancestorRight =
				ancestorLeft
				+ ancestor.AbsoluteSize.X

			local ancestorBottom =
				ancestorTop
				+ ancestor.AbsoluteSize.Y


			left =
				math.max(
					left,
					ancestorLeft
				)

			top =
				math.max(
					top,
					ancestorTop
				)

			right =
				math.min(
					right,
					ancestorRight
				)

			bottom =
				math.min(
					bottom,
					ancestorBottom
				)
		end


		ancestor =
			ancestor.Parent
	end


	--
	-- Convert absolute screen position into
	-- overlay-root coordinates.
	--
	left -=
		rootPosition.X

	right -=
		rootPosition.X

	top -=
		rootPosition.Y

	bottom -=
		rootPosition.Y


	left -=
		SPOTLIGHT_PADDING_X

	right +=
		SPOTLIGHT_PADDING_X

	top -=
		SPOTLIGHT_PADDING_Y

	bottom +=
		SPOTLIGHT_PADDING_Y


	left =
		math.clamp(
			left,
			0,
			rootSize.X
		)

	right =
		math.clamp(
			right,
			0,
			rootSize.X
		)

	top =
		math.clamp(
			top,
			0,
			rootSize.Y
		)

	bottom =
		math.clamp(
			bottom,
			0,
			rootSize.Y
		)


	return left,
		top,
		right,
		bottom
end


--==================================================
-- SPOTLIGHT GEOMETRY
--==================================================

local function getSpotlightGeometry(
	target: GuiObject
)

	local screenWidth =
		root.AbsoluteSize.X

	local screenHeight =
		root.AbsoluteSize.Y


	local left,
		top,
		right,
		bottom =
		getVisibleRect(
			target
		)


	local holeHeight =
		math.max(
			0,
			bottom - top
		)


	return {
		TopPosition =
			UDim2.fromOffset(
				0,
				0
			),

		TopSize =
			UDim2.fromOffset(
				screenWidth,
				math.max(
					0,
					top + PANEL_OVERLAP
				)
			),


		BottomPosition =
			UDim2.fromOffset(
				0,
				math.max(
					0,
					bottom - PANEL_OVERLAP
				)
			),

		BottomSize =
			UDim2.fromOffset(
				screenWidth,
				math.max(
					0,
					screenHeight
						- bottom
						+ PANEL_OVERLAP
				)
			),


		LeftPosition =
			UDim2.fromOffset(
				0,
				math.max(
					0,
					top - PANEL_OVERLAP
				)
			),

		LeftSize =
			UDim2.fromOffset(
				math.max(
					0,
					left + PANEL_OVERLAP
				),

				holeHeight
					+ PANEL_OVERLAP * 2
			),


		RightPosition =
			UDim2.fromOffset(
				math.max(
					0,
					right - PANEL_OVERLAP
				),

				math.max(
					0,
					top - PANEL_OVERLAP
				)
			),

		RightSize =
			UDim2.fromOffset(
				math.max(
					0,
					screenWidth
						- right
						+ PANEL_OVERLAP
				),

				holeHeight
					+ PANEL_OVERLAP * 2
			),
	}
end


local function applySpotlightGeometry(
	target: GuiObject
)

	local geometry =
		getSpotlightGeometry(
			target
		)


	topPanel.Position =
		geometry.TopPosition

	topPanel.Size =
		geometry.TopSize


	bottomPanel.Position =
		geometry.BottomPosition

	bottomPanel.Size =
		geometry.BottomSize


	leftPanel.Position =
		geometry.LeftPosition

	leftPanel.Size =
		geometry.LeftSize


	rightPanel.Position =
		geometry.RightPosition

	rightPanel.Size =
		geometry.RightSize
end


--==================================================
-- FIND HIGHLIGHT
--==================================================

local function findHighlightTarget():
	GuiObject?

	for _, descendant in
		playerGui:GetDescendants()
	do

		if VALID_HIGHLIGHT_NAMES[
			descendant.Name
		] ~= true then

			continue
		end


		if not descendant:IsA(
			"GuiObject"
		) then

			continue
		end


		local parent =
			descendant.Parent


		if parent
			and parent:IsA(
				"GuiObject"
			)
			and isTargetUsable(
				parent
			) then

			return parent
		end
	end


	return nil
end


--==================================================
-- FULL DIM
--==================================================

local function showFullDim()

	if currentMode
		== "FullDim" then

		return
	end


	transitionVersion +=
		1


	currentMode =
		"FullDim"


	currentTarget =
		nil


	followingSpotlight =
		false


	cancelTweens()


	root.Visible =
		true


	local width =
		root.AbsoluteSize.X

	local height =
		root.AbsoluteSize.Y


	local info =
		TweenInfo.new(
			SPOTLIGHT_MOVE_TIME,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)


	createTween(
		topPanel,
		info,
		{
			Position =
				UDim2.fromOffset(
					0,
					0
				),

			Size =
				UDim2.fromOffset(
					width,
					height
				),

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	createTween(
		bottomPanel,
		info,
		{
			Position =
				UDim2.fromOffset(
					0,
					height
				),

			Size =
				UDim2.fromOffset(
					width,
					0
				),

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	createTween(
		leftPanel,
		info,
		{
			Size =
				UDim2.fromOffset(
					0,
					0
				),

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	createTween(
		rightPanel,
		info,
		{
			Position =
				UDim2.fromOffset(
					width,
					0
				),

			Size =
				UDim2.fromOffset(
					0,
					0
				),

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)
end


--==================================================
-- SPOTLIGHT
--==================================================

local function showSpotlight(
	target: GuiObject
)

	if not isTargetUsable(
		target
	) then

		showFullDim()

		return
	end


	if currentMode
			== "Spotlight"
		and currentTarget
			== target then

		return
	end


	transitionVersion +=
		1


	local thisVersion =
		transitionVersion


	currentMode =
		"Spotlight"


	currentTarget =
		target


	followingSpotlight =
		false


	cancelTweens()


	root.Visible =
		true


	local geometry =
		getSpotlightGeometry(
			target
		)


	local info =
		TweenInfo.new(
			SPOTLIGHT_MOVE_TIME,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)


	local tween =
		createTween(
			topPanel,
			info,
			{
				Position =
					geometry.TopPosition,

				Size =
					geometry.TopSize,

				BackgroundTransparency =
					DIM_TRANSPARENCY,
			}
		)


	createTween(
		bottomPanel,
		info,
		{
			Position =
				geometry.BottomPosition,

			Size =
				geometry.BottomSize,

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	createTween(
		leftPanel,
		info,
		{
			Position =
				geometry.LeftPosition,

			Size =
				geometry.LeftSize,

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	createTween(
		rightPanel,
		info,
		{
			Position =
				geometry.RightPosition,

			Size =
				geometry.RightSize,

			BackgroundTransparency =
				DIM_TRANSPARENCY,
		}
	)


	task.spawn(
		function()

			tween.Completed:Wait()


			if transitionVersion
					== thisVersion
				and currentMode
					== "Spotlight"
				and currentTarget
					== target then

				followingSpotlight =
					true
			end
		end
	)
end


--==================================================
-- HIDE
--==================================================

local function hideOverlay()

	if currentMode
		== "Hidden" then

		return
	end


	transitionVersion +=
		1


	local thisVersion =
		transitionVersion


	currentMode =
		"Hidden"


	currentTarget =
		nil


	followingSpotlight =
		false


	cancelTweens()


	local info =
		TweenInfo.new(
			FADE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)


	for _, panel in
		panels
	do

		createTween(
			panel,
			info,
			{
				BackgroundTransparency =
					1,
			}
		)
	end


	task.delay(
		FADE_TIME,
		function()

			if transitionVersion
					~= thisVersion
				or currentMode
					~= "Hidden" then

				return
			end


			root.Visible =
				false


			applyFullDimGeometry()
		end
	)
end


--==================================================
-- TUTORIAL STATE
--==================================================

local function tutorialShowing():
	boolean

	return tutorialGui.Enabled
		and tutorialFrame.Visible
end


local function getFocusMode():
	string

	local mode =
		tutorialGui:GetAttribute(
			FOCUS_MODE_ATTRIBUTE
		)


	if mode == "Clear" then
		return "Clear"
	end


	return "Dim"
end


--==================================================
-- REFRESH
--==================================================

local function refresh()

	refreshScheduled =
		false


	if not tutorialShowing() then

		hideOverlay()

		return
	end


	if getFocusMode()
		== "Clear" then

		hideOverlay()

		return
	end


	local target =
		findHighlightTarget()


	if target then

		showSpotlight(
			target
		)

	else

		showFullDim()
	end
end


local function scheduleRefresh()

	if refreshScheduled then
		return
	end


	refreshScheduled =
		true


	task.defer(
		refresh
	)
end


--==================================================
-- WATCH TUTORIAL
--==================================================

tutorialGui:
	GetPropertyChangedSignal(
		"Enabled"
	)
	:Connect(
		scheduleRefresh
	)


tutorialFrame:
	GetPropertyChangedSignal(
		"Visible"
	)
	:Connect(
		scheduleRefresh
	)


tutorialGui:
	GetAttributeChangedSignal(
		FOCUS_MODE_ATTRIBUTE
	)
	:Connect(
		scheduleRefresh
	)


--==================================================
-- WATCH HIGHLIGHTS
--==================================================

playerGui.DescendantAdded:Connect(
	function(
		descendant: Instance
	)

		if VALID_HIGHLIGHT_NAMES[
			descendant.Name
		] then

			scheduleRefresh()
		end
	end
)


playerGui.DescendantRemoving:Connect(
	function(
		descendant: Instance
	)

		if VALID_HIGHLIGHT_NAMES[
			descendant.Name
		] then

			task.defer(
				scheduleRefresh
			)
		end
	end
)


--==================================================
-- FOLLOW MOVING UI
--==================================================

RunService.RenderStepped:Connect(
	function()

		if currentMode
				~= "Spotlight"
			or not followingSpotlight then

			return
		end


		local target =
			currentTarget


		if not isTargetUsable(
			target
		) then

			scheduleRefresh()

			return
		end


		applySpotlightGeometry(
			target :: GuiObject
		)
	end
)


--==================================================
-- RESOLUTION CHANGES
--==================================================

root:
	GetPropertyChangedSignal(
		"AbsoluteSize"
	)
	:Connect(
		function()

			if currentMode
					== "Spotlight"
				and currentTarget then

				applySpotlightGeometry(
					currentTarget
				)

			elseif currentMode
				== "FullDim" then

				applyFullDimGeometry()
			end
		end
	)


--==================================================
-- INITIAL
--==================================================

applyFullDimGeometry()


for _, panel in
	panels
do

	panel.BackgroundTransparency =
		1
end


root.Visible =
	false


scheduleRefresh()