local Players =
	game:GetService("Players")

local TweenService =
	game:GetService("TweenService")


local Notification = {}


--==================================================
-- CONFIG
--==================================================

local DESKTOP_MAX_NOTIFICATIONS =
	4

local MOBILE_MAX_NOTIFICATIONS =
	3

local DEFAULT_DURATION =
	3.5

local SUCCESS_DURATION =
	2.25

local WARNING_DURATION =
	3.5

local ERROR_DURATION =
	3.5

local INFO_DURATION =
	3.5

local CARD_WIDTH =
	410

local MOBILE_CARD_WIDTH =
	330

local MIN_CARD_HEIGHT =
	78

local MAX_CARD_HEIGHT =
	150

local CARD_GAP =
	10

local NOTIFICATION_TOP_OFFSET =
	115

local MOBILE_TOP_OFFSET =
	85

local MESSAGE_CHARS_PER_LINE =
	38

local MESSAGE_LINE_HEIGHT =
	17

local MESSAGE_TOP =
	39

local MESSAGE_BOTTOM_PADDING =
	18

local LONG_MESSAGE_EXTRA_DURATION =
	1.5

local LONG_MESSAGE_THRESHOLD =
	70

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
		238,
		250,
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

		Icon = "✓",
		Title = "Success",
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

		Icon = "!",
		Title = "Warning",
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

		Icon = "×",
		Title = "Error",
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

		Icon = "i",
		Title = "Info",
	},
}


--==================================================
-- STATE
--==================================================

local activeNotifications = {}

local nextId =
	0


--==================================================
-- HELPERS
--==================================================

local function getEstimatedLineCount(
	message: string
): number
	local lineCount =
		0


	-- Respect manually inserted line breaks too.
	for line in string.gmatch(
		message .. "\n",
		"(.-)\n"
	) do

		local lineLength =
			#line


		lineCount +=
			math.max(
				1,
				math.ceil(
					lineLength
						/ MESSAGE_CHARS_PER_LINE
				)
			)
	end


	return math.max(
		1,
		lineCount
	)
end


local function getCardHeight(
	message: string
): number

	local estimatedLines =
		getEstimatedLineCount(
			message
		)


	if estimatedLines <= 1 then
		return MIN_CARD_HEIGHT
	end


	-- The normal card already has room for one line,
	-- so only additional lines increase its height.
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
		24,
		cardHeight
			- MESSAGE_TOP
			- MESSAGE_BOTTOM_PADDING
	)
end


local function getDuration(
	notificationType: string,
	message: string,
	options
): number

	-- Explicit durations always take priority.
	if options
		and typeof(options.Duration)
			== "number" then

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


	-- Long notifications need a little more time,
	-- regardless of notification type.
	if #message
		>= LONG_MESSAGE_THRESHOLD then

		duration +=
			LONG_MESSAGE_EXTRA_DURATION
	end


	return duration
end

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

	holder.Position =
		UDim2.new(
			0.5,
			0,
			0,
			NOTIFICATION_TOP_OFFSET
		)

	holder.Size =
		UDim2.new(
			0,
			CARD_WIDTH,
			1,
			-NOTIFICATION_TOP_OFFSET
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


	-- Responsive sizing for smaller/mobile screens.
local responsiveScale =
	Instance.new("UIScale")

responsiveScale.Name =
	"ResponsiveScale"

responsiveScale.Scale =
	1

responsiveScale.Parent =
	holder


local camera =
	workspace.CurrentCamera


local function updateScale()
	if not camera then
		return
	end


	local viewport =
		camera.ViewportSize


	local isMobile =
		viewport.X <= 700


	if isMobile then

		-- Keep the notification comfortably inside
		-- the screen while still being easy to read.
		local targetWidth =
			math.min(
				MOBILE_CARD_WIDTH,
				viewport.X - 32
			)


		responsiveScale.Scale =
			math.clamp(
				targetWidth / CARD_WIDTH,
				0.72,
				0.88
			)


		holder.Position =
			UDim2.new(
				0.5,
				0,
				0,
				MOBILE_TOP_OFFSET
			)


		holder.Size =
			UDim2.new(
				0,
				CARD_WIDTH,
				1,
				-MOBILE_TOP_OFFSET
			)

	else

		responsiveScale.Scale =
			1


		holder.Position =
			UDim2.new(
				0.5,
				0,
				0,
				NOTIFICATION_TOP_OFFSET
			)


		holder.Size =
			UDim2.new(
				0,
				CARD_WIDTH,
				1,
				-NOTIFICATION_TOP_OFFSET
			)
	end
end


updateScale()


if camera then

	camera:GetPropertyChangedSignal(
		"ViewportSize"
	):Connect(
		updateScale
	)
end


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
				0.16,
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
				0.16,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					0.9,
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


	local cardHeight =
		getCardHeight(
			message
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

	card.Size =
		UDim2.fromOffset(
			CARD_WIDTH,
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
			11
		)

	title.Size =
		UDim2.new(
			1,
			-122,
			0,
			27
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
		20

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

	messageLabel.TextSize =
		14

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
		0.35
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
					0.12,
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
					0.12,
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
					0.06,
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
					0.08,
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
	-- OPEN/CLOSE SCALE
	--==================================================

	local scale =
		Instance.new(
			"UIScale"
		)

	scale.Name =
		"Scale"

	scale.Scale =
		0.84

	scale.Parent =
		card


	--==================================================
	-- OPEN ANIMATION
	--==================================================

	TweenService:Create(
		canvas,

		TweenInfo.new(
			0.16,
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
			0.28,
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

	if typeof(message) ~= "string"
		or message == "" then

		return
	end


	options =
		options
		or {}


	local camera =
	workspace.CurrentCamera

local viewportWidth =
	camera
	and camera.ViewportSize.X
	or 1920

local maxNotifications =
	viewportWidth <= 700
	and MOBILE_MAX_NOTIFICATIONS
	or DESKTOP_MAX_NOTIFICATIONS


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