local Players =
	game:GetService("Players")

local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")


local Notification = {}


--==================================================
-- CONFIG
--==================================================

-- Keep the screen clean.
local DESKTOP_MAX_NOTIFICATIONS =
	3

local MOBILE_MAX_NOTIFICATIONS =
	2


-- Ordinary notifications should disappear quickly.
local DEFAULT_DURATION =
	2.25

local SUCCESS_DURATION =
	1.8

local WARNING_DURATION =
	2.4

local ERROR_DURATION =
	2.7

local INFO_DURATION =
	2.3


-- Explicit Duration values passed by another script
-- still override these defaults.


--==================================================
-- CARD SIZING
--==================================================

local DESKTOP_CARD_WIDTH =
	470

local MOBILE_MAX_CARD_WIDTH =
	420

local MOBILE_SIDE_PADDING =
	18


local MIN_CARD_HEIGHT =
	96

local MAX_CARD_HEIGHT =
	190


local CARD_GAP =
	9


local NOTIFICATION_TOP_OFFSET =
	24

local MOBILE_TOP_OFFSET =
	16


-- Base wrapping estimate at desktop width.
local BASE_MESSAGE_CHARS_PER_LINE =
	40

local MESSAGE_LINE_HEIGHT =
	22

local MESSAGE_TOP =
	44

local MESSAGE_BOTTOM_PADDING =
	18


-- Long notifications get only a small amount of
-- additional reading time so they don't clog the HUD.
local LONG_MESSAGE_EXTRA_DURATION =
	0.65

local LONG_MESSAGE_THRESHOLD =
	80


--==================================================
-- COLORS
--==================================================

local CARD_COLOR =
	Color3.fromRGB(
		20,
		181,
		230
	)


local CARD_STROKE_COLOR =
	Color3.fromRGB(
		10,
		112,
		166
	)


local TEXT_COLOR =
	Color3.fromRGB(
		255,
		255,
		255
	)


local TEXT_STROKE_COLOR =
	Color3.fromRGB(
		18,
		70,
		102
	)


local SUBTEXT_COLOR =
	Color3.fromRGB(
		245,
		253,
		255
	)


local TIMER_BACKGROUND_COLOR =
	Color3.fromRGB(
		11,
		139,
		194
	)


local STYLES = {
	Success = {
		Color =
			Color3.fromRGB(
				78,
				235,
				42
			),

		DarkColor =
			Color3.fromRGB(
				34,
				153,
				21
			),

		Icon =
			"✓",

		Title =
			"Success",
	},

	Warning = {
		Color =
			Color3.fromRGB(
				255,
				208,
				42
			),

		DarkColor =
			Color3.fromRGB(
				194,
				132,
				18
			),

		Icon =
			"!",

		Title =
			"Warning",
	},

	Error = {
		Color =
			Color3.fromRGB(
				255,
				79,
				79
			),

		DarkColor =
			Color3.fromRGB(
				178,
				38,
				47
			),

		Icon =
			"×",

		Title =
			"Error",
	},

	Info = {
		Color =
			Color3.fromRGB(
				80,
				218,
				255
			),

		DarkColor =
			Color3.fromRGB(
				21,
				126,
				181
			),

		Icon =
			"i",

		Title =
			"Info",
	},
}


--==================================================
-- STATE
--==================================================

local activeNotifications: {Frame} =
	{}


local nextId =
	0


--==================================================
-- VIEWPORT
--==================================================

local function getViewportWidth(): number

	local camera =
		Workspace.CurrentCamera


	if not camera then
		return 1920
	end


	return camera.ViewportSize.X
end


local function isMobileViewport(): boolean

	return getViewportWidth()
		<= 700
end


local function getCurrentCardWidth(): number

	local viewportWidth =
		getViewportWidth()


	if viewportWidth <= 700 then

		return math.max(
			280,

			math.min(
				MOBILE_MAX_CARD_WIDTH,
				viewportWidth
					- MOBILE_SIDE_PADDING * 2
			)
		)
	end


	return DESKTOP_CARD_WIDTH
end


--==================================================
-- TEXT / CARD SIZING
--==================================================

local function getEstimatedCharactersPerLine(
	cardWidth: number
): number

	local ratio =
		cardWidth
			/ DESKTOP_CARD_WIDTH


	return math.max(
		24,

		math.floor(
			BASE_MESSAGE_CHARS_PER_LINE
				* ratio
		)
	)
end


local function getEstimatedLineCount(
	message: string,
	cardWidth: number
): number

	local charactersPerLine =
		getEstimatedCharactersPerLine(
			cardWidth
		)


	local lineCount =
		0


	-- Respect manually inserted new lines.
	for line in string.gmatch(
		message .. "\n",
		"(.-)\n"
	) do

		lineCount +=
			math.max(
				1,

				math.ceil(
					#line
						/ charactersPerLine
				)
			)
	end


	return math.max(
		1,
		lineCount
	)
end


local function getCardHeight(
	message: string,
	cardWidth: number
): number

	local estimatedLines =
		getEstimatedLineCount(
			message,
			cardWidth
		)


	if estimatedLines <= 1 then
		return MIN_CARD_HEIGHT
	end


	local extraLines =
		estimatedLines - 1


	return math.clamp(
		MIN_CARD_HEIGHT
			+ extraLines
				* MESSAGE_LINE_HEIGHT,

		MIN_CARD_HEIGHT,
		MAX_CARD_HEIGHT
	)
end


local function getMessageHeight(
	cardHeight: number
): number

	return math.max(
		30,

		cardHeight
			- MESSAGE_TOP
			- MESSAGE_BOTTOM_PADDING
	)
end


--==================================================
-- DURATION
--==================================================

local function getDuration(
	notificationType: string,
	message: string,
	options
): number

	-- Specific notifications are still allowed to
	-- choose their own duration.
	if options
		and typeof(
			options.Duration
		) == "number" then

		return math.max(
			0.5,
			options.Duration
		)
	end


	local duration =
		DEFAULT_DURATION


	if notificationType
		== "Success" then

		duration =
			SUCCESS_DURATION

	elseif notificationType
		== "Warning" then

		duration =
			WARNING_DURATION

	elseif notificationType
		== "Error" then

		duration =
			ERROR_DURATION

	elseif notificationType
		== "Info" then

		duration =
			INFO_DURATION
	end


	if #message
		>= LONG_MESSAGE_THRESHOLD then

		duration +=
			LONG_MESSAGE_EXTRA_DURATION
	end


	return duration
end


--==================================================
-- UI HELPERS
--==================================================

local function addCorner(
	instance: GuiObject,
	radius: number
)

	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0,
			radius
		)


	corner.Parent =
		instance


	return corner
end


local function addStroke(
	instance: GuiObject,
	color: Color3,
	thickness: number
)

	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Color =
		color


	stroke.Thickness =
		thickness


	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border


	stroke.LineJoinMode =
		Enum.LineJoinMode.Round


	stroke.Parent =
		instance


	return stroke
end


local function addTextStroke(
	textObject: TextLabel | TextButton,
	color: Color3,
	transparency: number?
)

	textObject.TextStrokeColor3 =
		color


	textObject.TextStrokeTransparency =
		transparency
			or 0
end


local function removeFromActive(
	card: Frame
)

	for index, notification in
		activeNotifications do

		if notification == card then

			table.remove(
				activeNotifications,
				index
			)


			return
		end
	end
end


--==================================================
-- GUI
--==================================================

local function getGui(): ScreenGui

	local player =
		Players.LocalPlayer


	if not player then

		error(
			"Notification can only be used from the client."
		)
	end


	local playerGui =
		player:WaitForChild(
			"PlayerGui"
		)


	local existing =
		playerGui:FindFirstChild(
			"Notifications"
		)


	if existing
		and existing:IsA(
			"ScreenGui"
		)
		and existing:FindFirstChild(
			"Holder"
		) then

		return existing
	end


	if existing then
		existing:Destroy()
	end


	local gui =
		Instance.new(
			"ScreenGui"
		)


	gui.Name =
		"Notifications"


	gui.ResetOnSpawn =
		false


	gui.IgnoreGuiInset =
		true


	gui.DisplayOrder =
		10000


	gui.ZIndexBehavior =
		Enum.ZIndexBehavior.Global


	gui.Parent =
		playerGui


	--==================================================
	-- HOLDER
	--==================================================

	local holder =
		Instance.new(
			"Frame"
		)


	holder.Name =
		"Holder"


	holder.AnchorPoint =
		Vector2.new(
			0.5,
			0
		)


	holder.BackgroundTransparency =
		1


	holder.BorderSizePixel =
		0


	holder.Parent =
		gui


	local layout =
		Instance.new(
			"UIListLayout"
		)


	layout.Padding =
		UDim.new(
			0,
			CARD_GAP
		)


	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center


	layout.VerticalAlignment =
		Enum.VerticalAlignment.Top


	layout.SortOrder =
		Enum.SortOrder.LayoutOrder


	layout.Parent =
		holder


	--==================================================
	-- RESPONSIVE HOLDER
	--==================================================

	local function updateHolder()

		local mobile =
			isMobileViewport()


		local cardWidth =
			getCurrentCardWidth()


		local topOffset =
			if mobile
			then MOBILE_TOP_OFFSET
			else NOTIFICATION_TOP_OFFSET


		holder.Position =
			UDim2.new(
				0.5,
				0,
				0,
				topOffset
			)


		holder.Size =
			UDim2.new(
				0,
				cardWidth,
				1,
				-topOffset
			)
	end


	updateHolder()


	local function connectCamera(
		camera: Camera?
	)

		if not camera then
			return
		end


		camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(
			updateHolder
		)
	end


	connectCamera(
		Workspace.CurrentCamera
	)


	Workspace:GetPropertyChangedSignal(
		"CurrentCamera"
	):Connect(
		function()

			updateHolder()


			connectCamera(
				Workspace.CurrentCamera
			)
		end
	)


	return gui
end


local function getHolder(): Frame

	local gui =
		getGui()


	return gui:WaitForChild(
		"Holder"
	) :: Frame
end


--==================================================
-- CLOSE
--==================================================

local function closeNotification(
	card: Frame
)

	if card:GetAttribute(
		"Closing"
	) == true then

		return
	end


	card:SetAttribute(
		"Closing",
		true
	)


	removeFromActive(
		card
	)


	local canvas =
		card:FindFirstChild(
			"Canvas"
		)


	local scale =
		card:FindFirstChild(
			"Scale"
		)


	if not canvas
		or not canvas:IsA(
			"CanvasGroup"
		)
		or not scale
		or not scale:IsA(
			"UIScale"
		) then

		card:Destroy()

		return
	end


	local fadeTween =
		TweenService:Create(
			canvas,

			TweenInfo.new(
				0.12,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				GroupTransparency =
					1,
			}
		)


	local scaleTween =
		TweenService:Create(
			scale,

			TweenInfo.new(
				0.12,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					0.92,
			}
		)


	fadeTween:Play()

	scaleTween:Play()


	fadeTween.Completed:Once(
		function()

			if card.Parent then
				card:Destroy()
			end
		end
	)
end


--==================================================
-- CREATE CARD
--==================================================

local function createCard(
	notificationType: string,
	message: string,
	options
): (Frame, Frame)

	local style =
		STYLES[
			notificationType
		]
		or STYLES.Info


	nextId +=
		1


	local holder =
		getHolder()


	local cardWidth =
		getCurrentCardWidth()


	local cardHeight =
		getCardHeight(
			message,
			cardWidth
		)


	local messageHeight =
		getMessageHeight(
			cardHeight
		)


	--==================================================
	-- CARD
	--==================================================

	local card =
		Instance.new(
			"Frame"
		)


	card.Name =
		"Notification"


	card.LayoutOrder =
		nextId


	-- Width follows the holder automatically.
	card.Size =
		UDim2.new(
			1,
			0,
			0,
			cardHeight
		)


	card.BackgroundColor3 =
		CARD_COLOR


	card.BorderSizePixel =
		0


	card.ClipsDescendants =
		false


	card.Parent =
		holder


	addCorner(
		card,
		23
	)


	addStroke(
		card,
		CARD_STROKE_COLOR,
		4
	)


	--==================================================
	-- CANVAS
	--==================================================

	local canvas =
		Instance.new(
			"CanvasGroup"
		)


	canvas.Name =
		"Canvas"


	canvas.Size =
		UDim2.fromScale(
			1,
			1
		)


	canvas.BackgroundTransparency =
		1


	canvas.GroupTransparency =
		1


	canvas.ClipsDescendants =
		true


	canvas.Parent =
		card


	addCorner(
		canvas,
		20
	)


	--==================================================
	-- ICON SHADOW
	--==================================================

	local iconShadow =
		Instance.new(
			"Frame"
		)


	iconShadow.Name =
		"IconShadow"


	iconShadow.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)


	iconShadow.Position =
		UDim2.new(
			0,
			16,
			0.5,
			2
		)


	iconShadow.Size =
		UDim2.fromOffset(
			48,
			48
		)


	iconShadow.BackgroundColor3 =
		style.DarkColor


	iconShadow.BorderSizePixel =
		0


	iconShadow.Parent =
		canvas


	addCorner(
		iconShadow,
		15
	)


	--==================================================
	-- ICON BACKGROUND
	--==================================================

	local iconBackground =
		Instance.new(
			"Frame"
		)


	iconBackground.Name =
		"IconBackground"


	iconBackground.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)


	iconBackground.Position =
		UDim2.new(
			0,
			16,
			0.5,
			-1
		)


	iconBackground.Size =
		UDim2.fromOffset(
			48,
			48
		)


	iconBackground.BackgroundColor3 =
		style.Color


	iconBackground.BorderSizePixel =
		0


	iconBackground.Parent =
		canvas


	addCorner(
		iconBackground,
		15
	)


	addStroke(
		iconBackground,
		style.DarkColor,
		3
	)


	--==================================================
	-- ICON
	--==================================================

	local icon =
		Instance.new(
			"TextLabel"
		)


	icon.Name =
		"Icon"


	icon.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)


	icon.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)


	icon.Size =
		UDim2.new(
			1,
			-11,
			1,
			-11
		)


	icon.BackgroundTransparency =
		1


	icon.Text =
		style.Icon


	icon.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	icon.TextScaled =
		true


	icon.FontFace =
		Font.new(
			"rbxassetid://12188570269",
			Enum.FontWeight.Bold
		)


	icon.Parent =
		iconBackground


	addTextStroke(
		icon,
		style.DarkColor,
		0.1
	)


	local iconConstraint =
		Instance.new(
			"UITextSizeConstraint"
		)


	iconConstraint.MinTextSize =
		15


	iconConstraint.MaxTextSize =
		27


	iconConstraint.Parent =
		icon


	--==================================================
	-- TITLE
	--==================================================

	local title =
		Instance.new(
			"TextLabel"
		)


	title.Name =
		"Title"


	title.Position =
		UDim2.new(
			0,
			78,
			0,
			10
		)


	title.Size =
		UDim2.new(
			1,
			-122,
			0,
			29
		)


	title.BackgroundTransparency =
		1


	title.Text =
		options.Title
			or style.Title


	title.TextColor3 =
		TEXT_COLOR


	title.TextXAlignment =
		Enum.TextXAlignment.Left


	title.TextYAlignment =
		Enum.TextYAlignment.Center


	title.TextSize =
		21


	title.TextTruncate =
		Enum.TextTruncate.AtEnd


	title.FontFace =
		Font.new(
			"rbxassetid://12188570269",
			Enum.FontWeight.Bold
		)


	title.Parent =
		canvas


	addTextStroke(
		title,
		TEXT_STROKE_COLOR,
		0.05
	)


	--==================================================
	-- MESSAGE
	--==================================================

	local messageLabel =
		Instance.new(
			"TextLabel"
		)


	messageLabel.Name =
		"Message"


	messageLabel.Position =
		UDim2.new(
			0,
			79,
			0,
			MESSAGE_TOP
		)


	messageLabel.Size =
		UDim2.new(
			1,
			-128,
			0,
			messageHeight
		)


	messageLabel.BackgroundTransparency =
		1


	messageLabel.Text =
		message


	messageLabel.TextColor3 =
		SUBTEXT_COLOR


	messageLabel.TextXAlignment =
		Enum.TextXAlignment.Left


	messageLabel.TextYAlignment =
		Enum.TextYAlignment.Top


	messageLabel.TextWrapped =
		true


	messageLabel.TextTruncate =
		Enum.TextTruncate.None


	-- MUCH easier to read than the old 14px.
	messageLabel.TextSize =
		17


	messageLabel.FontFace =
		Font.new(
			"rbxassetid://12188570269",
			Enum.FontWeight.SemiBold
		)


	messageLabel.Parent =
		canvas


	addTextStroke(
		messageLabel,
		TEXT_STROKE_COLOR,
		0.28
	)


	--==================================================
	-- CLOSE SHADOW
	--==================================================

	local closeShadow =
		Instance.new(
			"Frame"
		)


	closeShadow.Name =
		"CloseShadow"


	closeShadow.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)


	closeShadow.Position =
		UDim2.new(
			1,
			-14,
			0.5,
			2
		)


	closeShadow.Size =
		UDim2.fromOffset(
			32,
			32
		)


	closeShadow.BackgroundColor3 =
		Color3.fromRGB(
			8,
			105,
			153
		)


	closeShadow.BorderSizePixel =
		0


	closeShadow.Parent =
		canvas


	addCorner(
		closeShadow,
		11
	)


	--==================================================
	-- CLOSE BUTTON
	--==================================================

	local closeButton =
		Instance.new(
			"TextButton"
		)


	closeButton.Name =
		"Close"


	closeButton.AnchorPoint =
		Vector2.new(
			1,
			0.5
		)


	closeButton.Position =
		UDim2.new(
			1,
			-14,
			0.5,
			-1
		)


	closeButton.Size =
		UDim2.fromOffset(
			32,
			32
		)


	closeButton.BackgroundColor3 =
		Color3.fromRGB(
			41,
			196,
			235
		)


	closeButton.BorderSizePixel =
		0


	closeButton.Text =
		"×"


	closeButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	closeButton.TextSize =
		21


	closeButton.FontFace =
		Font.new(
			"rbxassetid://12188570269",
			Enum.FontWeight.Bold
		)


	closeButton.AutoButtonColor =
		false


	closeButton.Parent =
		canvas


	addCorner(
		closeButton,
		11
	)


	addStroke(
		closeButton,

		Color3.fromRGB(
			8,
			119,
			169
		),

		2
	)


	addTextStroke(
		closeButton,
		TEXT_STROKE_COLOR,
		0.2
	)


	--==================================================
	-- CLOSE BUTTON ANIMATION
	--==================================================

	local closeScale =
		Instance.new(
			"UIScale"
		)


	closeScale.Scale =
		1


	closeScale.Parent =
		closeButton


	closeButton.MouseEnter:Connect(
		function()

			TweenService:Create(
				closeScale,

				TweenInfo.new(
					0.1,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						1.07,
				}
			):Play()
		end
	)


	closeButton.MouseLeave:Connect(
		function()

			TweenService:Create(
				closeScale,

				TweenInfo.new(
					0.1,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						1,
				}
			):Play()
		end
	)


	closeButton.MouseButton1Down:Connect(
		function()

			TweenService:Create(
				closeScale,

				TweenInfo.new(
					0.05,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						0.92,
				}
			):Play()
		end
	)


	closeButton.MouseButton1Up:Connect(
		function()

			TweenService:Create(
				closeScale,

				TweenInfo.new(
					0.07,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						1.07,
				}
			):Play()
		end
	)


	closeButton.Activated:Connect(
		function()

			closeNotification(
				card
			)
		end
	)


	--==================================================
	-- TIMER BAR
	--==================================================

	local progressBackground =
		Instance.new(
			"Frame"
		)


	progressBackground.Name =
		"ProgressBackground"


	progressBackground.AnchorPoint =
		Vector2.new(
			0.5,
			1
		)


	progressBackground.Position =
		UDim2.new(
			0.5,
			0,
			1,
			-5
		)


	progressBackground.Size =
		UDim2.new(
			1,
			-26,
			0,
			4
		)


	progressBackground.BackgroundColor3 =
		TIMER_BACKGROUND_COLOR


	progressBackground.BackgroundTransparency =
		0.2


	progressBackground.BorderSizePixel =
		0


	progressBackground.ClipsDescendants =
		true


	progressBackground.Parent =
		canvas


	addCorner(
		progressBackground,
		4
	)


	local progress =
		Instance.new(
			"Frame"
		)


	progress.Name =
		"Progress"


	progress.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)


	progress.Position =
		UDim2.fromScale(
			0,
			0.5
		)


	progress.Size =
		UDim2.fromScale(
			1,
			1
		)


	progress.BackgroundColor3 =
		style.Color


	progress.BorderSizePixel =
		0


	progress.Parent =
		progressBackground


	addCorner(
		progress,
		4
	)


	--==================================================
	-- OPEN / CLOSE SCALE
	--==================================================

	local scale =
		Instance.new(
			"UIScale"
		)


	scale.Name =
		"Scale"


	scale.Scale =
		0.88


	scale.Parent =
		card


	--==================================================
	-- OPEN ANIMATION
	--==================================================

	TweenService:Create(
		canvas,

		TweenInfo.new(
			0.12,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			GroupTransparency =
				0,
		}
	):Play()


	TweenService:Create(
		scale,

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


	return card,
		progress
end


--==================================================
-- SHOW
--==================================================

function Notification.Show(
	notificationType: string,
	message: string,
	options
)

	if typeof(message)
			~= "string"
		or message == "" then

		return
	end


	options =
		options
			or {}


	local maxNotifications =
		if isMobileViewport()
		then MOBILE_MAX_NOTIFICATIONS
		else DESKTOP_MAX_NOTIFICATIONS


	-- Immediately remove the oldest notification when
	-- the screen already has enough cards.
	while #activeNotifications
		>= maxNotifications do

		local oldest =
			activeNotifications[1]


		if not oldest then
			break
		end


		closeNotification(
			oldest
		)
	end


	local card,
		progress =
		createCard(
			notificationType,
			message,
			options
		)


	table.insert(
		activeNotifications,
		card
	)


	local duration =
		getDuration(
			notificationType,
			message,
			options
		)


	if duration <= 0 then
		return
	end


	TweenService:Create(
		progress,

		TweenInfo.new(
			duration,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		),

		{
			Size =
				UDim2.new(
					0,
					0,
					1,
					0
				),
		}
	):Play()


	task.delay(
		duration,

		function()

			if card.Parent then

				closeNotification(
					card
				)
			end
		end
	)
end


--==================================================
-- SHORTCUTS
--==================================================

function Notification.Success(
	message: string,
	options
)

	Notification.Show(
		"Success",
		message,
		options
	)
end


function Notification.Warning(
	message: string,
	options
)

	Notification.Show(
		"Warning",
		message,
		options
	)
end


function Notification.Error(
	message: string,
	options
)

	Notification.Show(
		"Error",
		message,
		options
	)
end


function Notification.Info(
	message: string,
	options
)

	Notification.Show(
		"Info",
		message,
		options
	)
end


return Notification