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
-- 0 = solid black
-- 1 = invisible
--
-- 0.20 means the world is roughly 80% dark.
--
local DIM_TRANSPARENCY =
	0.20


local FADE_TIME =
	0.25


local SPOTLIGHT_MOVE_TIME =
	0.28


--
-- Extra room around the highlighted button.
--
local SPOTLIGHT_PADDING_X =
	12


local SPOTLIGHT_PADDING_Y =
	10


--
-- The overlay gets an extremely high DisplayOrder.
-- The Tutorial GUI sits one level ABOVE it.
--
local OVERLAY_DISPLAY_ORDER =
	10000


local TUTORIAL_DISPLAY_ORDER =
	10001


--==================================================
-- HIGHLIGHT NAMES
--==================================================

local VALID_HIGHLIGHT_NAMES = {
	TutorialHighlight = true,
	ContextualTutorialHighlight = true,
}


--==================================================
-- CREATE OVERLAY GUI
--==================================================

local oldOverlay =
	playerGui:FindFirstChild(
		"TutorialFocusOverlay"
	)


if oldOverlay then
	oldOverlay:Destroy()
end


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
-- Guarantee the tutorial text itself is always
-- above the darkness.
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


root.Size =
	UDim2.fromScale(
		1,
		1
	)


root.Position =
	UDim2.fromScale(
		0,
		0
	)


root.Visible =
	false


root.Active =
	false


root.ZIndex =
	1


root.Parent =
	overlayGui


--==================================================
-- DIM PANELS
--==================================================

local function createDimPanel(
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
	-- Important:
	-- this blocks input OUTSIDE the spotlight.
	--
	frame.Active =
		true


	frame.Selectable =
		false


	frame.ZIndex =
		1


	frame.Parent =
		root


	return frame
end


local topPanel =
	createDimPanel(
		"Top"
	)


local bottomPanel =
	createDimPanel(
		"Bottom"
	)


local leftPanel =
	createDimPanel(
		"Left"
	)


local rightPanel =
	createDimPanel(
		"Right"
	)


--==================================================
-- STATE
--==================================================

local currentTarget:
	GuiObject? =
	nil


local currentMode =
	"Hidden"


local activeTweens: {
	Tween
} = {}


local transitionVersion =
	0


local followingSpotlight =
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


local function tweenObject(
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
-- TRANSPARENCY
--==================================================

local function setPanelTransparency(
	transparency: number,
	animated: boolean
)

	local panels = {
		topPanel,
		bottomPanel,
		leftPanel,
		rightPanel,
	}


	if not animated then

		for _, panel in
			panels
		do

			panel.BackgroundTransparency =
				transparency
		end


		return
	end


	local tweenInfo =
		TweenInfo.new(
			FADE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)


	for _, panel in
		panels
	do

		tweenObject(
			panel,
			tweenInfo,
			{
				BackgroundTransparency =
					transparency,
			}
		)
	end
end


--==================================================
-- GEOMETRY
--==================================================

local function setFullDimGeometry()

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


local function getSpotlightBounds(
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


	local targetPosition =
		target.AbsolutePosition


	local targetSize =
		target.AbsoluteSize


	local left =
		targetPosition.X
		- rootPosition.X
		- SPOTLIGHT_PADDING_X


	local top =
		targetPosition.Y
		- rootPosition.Y
		- SPOTLIGHT_PADDING_Y


	local right =
		targetPosition.X
		- rootPosition.X
		+ targetSize.X
		+ SPOTLIGHT_PADDING_X


	local bottom =
		targetPosition.Y
		- rootPosition.Y
		+ targetSize.Y
		+ SPOTLIGHT_PADDING_Y


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


local function getSpotlightGeometry(
	target: GuiObject
)

	local rootSize =
		root.AbsoluteSize


	local width =
		rootSize.X


	local height =
		rootSize.Y


	local left,
		top,
		right,
		bottom =
		getSpotlightBounds(
			target
		)


	local holeWidth =
		math.max(
			0,
			right - left
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
				width,
				top
			),


		BottomPosition =
			UDim2.fromOffset(
				0,
				bottom
			),

		BottomSize =
			UDim2.fromOffset(
				width,
				math.max(
					0,
					height - bottom
				)
			),


		LeftPosition =
			UDim2.fromOffset(
				0,
				top
			),

		LeftSize =
			UDim2.fromOffset(
				left,
				holeHeight
			),


		RightPosition =
			UDim2.fromOffset(
				right,
				top
			),

		RightSize =
			UDim2.fromOffset(
				math.max(
					0,
					width - right
				),
				holeHeight
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
-- TARGET VALIDITY
--==================================================

local function isTargetUsable(
	target: GuiObject?
): boolean

	if not target then
		return false
	end


	if not target.Parent then
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


	--
	-- Make sure all GuiObject ancestors are visible.
	--
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
-- FULL DIM
--==================================================

local function showFullDim(
	animated: boolean
)

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


	if animated then

		--
		-- If we were hidden, start transparent.
		--
		if topPanel.BackgroundTransparency
			>= 0.99 then

			setFullDimGeometry()
		end


		local tweenInfo =
			TweenInfo.new(
				SPOTLIGHT_MOVE_TIME,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)


		local width =
			root.AbsoluteSize.X


		local height =
			root.AbsoluteSize.Y


		tweenObject(
			topPanel,
			tweenInfo,
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
			}
		)


		tweenObject(
			bottomPanel,
			tweenInfo,
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
			}
		)


		tweenObject(
			leftPanel,
			tweenInfo,
			{
				Size =
					UDim2.fromOffset(
						0,
						0
					),
			}
		)


		tweenObject(
			rightPanel,
			tweenInfo,
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
			}
		)


		setPanelTransparency(
			DIM_TRANSPARENCY,
			true
		)

	else

		setFullDimGeometry()


		setPanelTransparency(
			DIM_TRANSPARENCY,
			false
		)
	end
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

		showFullDim(
			true
		)

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


	--
	-- If we're appearing from completely hidden,
	-- begin as one dark full-screen layer and then
	-- open the spotlight.
	--
	if topPanel.BackgroundTransparency
		>= 0.99 then

		setFullDimGeometry()


		setPanelTransparency(
			DIM_TRANSPARENCY,
			false
		)
	end


	local geometry =
		getSpotlightGeometry(
			target
		)


	local tweenInfo =
		TweenInfo.new(
			SPOTLIGHT_MOVE_TIME,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)


	local tweens = {
		tweenObject(
			topPanel,
			tweenInfo,
			{
				Position =
					geometry.TopPosition,

				Size =
					geometry.TopSize,

				BackgroundTransparency =
					DIM_TRANSPARENCY,
			}
		),

		tweenObject(
			bottomPanel,
			tweenInfo,
			{
				Position =
					geometry.BottomPosition,

				Size =
					geometry.BottomSize,

				BackgroundTransparency =
					DIM_TRANSPARENCY,
			}
		),

		tweenObject(
			leftPanel,
			tweenInfo,
			{
				Position =
					geometry.LeftPosition,

				Size =
					geometry.LeftSize,

				BackgroundTransparency =
					DIM_TRANSPARENCY,
			}
		),

		tweenObject(
			rightPanel,
			tweenInfo,
			{
				Position =
					geometry.RightPosition,

				Size =
					geometry.RightSize,

				BackgroundTransparency =
					DIM_TRANSPARENCY,
			}
		),
	}


	task.spawn(
		function()

			tweens[1]
				.Completed
				:Wait()


			if transitionVersion
					== thisVersion
				and currentTarget
					== target
				and currentMode
					== "Spotlight" then

				followingSpotlight =
					true
			end
		end
	)
end


--==================================================
-- HIDE
--==================================================

local function hideOverlay(
	animated: boolean
)

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


	if not animated then

		setPanelTransparency(
			1,
			false
		)


		root.Visible =
			false


		return
	end


	local tweenInfo =
		TweenInfo.new(
			FADE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)


	for _, panel in {
		topPanel,
		bottomPanel,
		leftPanel,
		rightPanel,
	}
	do

		tweenObject(
			panel,
			tweenInfo,
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


			setFullDimGeometry()
		end
	)
end


--==================================================
-- FIND CURRENT TUTORIAL TARGET
--==================================================

local function findHighlightTarget():
	GuiObject?

	local found:
		GuiObject? =
		nil


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

			found =
				parent
		end
	end


	return found
end


--==================================================
-- TUTORIAL VISIBILITY
--==================================================

local function isTutorialShowing():
	boolean

	if tutorialGui:GetAttribute(
		"SuppressFocusOverlay"
	) == true then

		return false
	end


	return tutorialGui.Enabled
		and tutorialFrame.Visible
end


--==================================================
-- REFRESH
--==================================================

local refreshScheduled =
	false


local function refresh()

	refreshScheduled =
		false


	if not isTutorialShowing() then

		hideOverlay(
			true
		)

		return
	end


	local target =
		findHighlightTarget()


	if target then

		showSpotlight(
			target
		)

	else

		showFullDim(
			true
		)
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
-- WATCH TUTORIAL VISIBILITY
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
		"SuppressFocusOverlay"
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

			--
			-- Wait one frame so the old highlight has
			-- actually disappeared before searching.
			--
			task.defer(
				scheduleRefresh
			)
		end
	end
)


--==================================================
-- FOLLOW MOVING BUTTON
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


		--
		-- Buttons inside scrolling frames, animated
		-- menus, etc. can move after the spotlight
		-- initially opens.
		--
		-- Keep the cutout perfectly attached.
		--
		applySpotlightGeometry(
			target :: GuiObject
		)
	end
)


--==================================================
-- SCREEN SIZE CHANGES
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

				setFullDimGeometry()
			end
		end
	)


--==================================================
-- INITIAL STATE
--==================================================

setFullDimGeometry()


setPanelTransparency(
	1,
	false
)


root.Visible =
	false


scheduleRefresh()