local Players =
	game:GetService("Players")

local TweenService =
	game:GetService("TweenService")


local Notification = {}


--==================================================
-- CONFIG
--==================================================

local MAX_NOTIFICATIONS =
	4

local DEFAULT_DURATION =
	3.5

local CARD_WIDTH =
	430

local CARD_HEIGHT =
	72

local CARD_GAP =
	10


local BACKGROUND_COLOR =
	Color3.fromRGB(
		28,
		30,
		36
	)

local TEXT_COLOR =
	Color3.fromRGB(
		245,
		245,
		248
	)

local SUBTEXT_COLOR =
	Color3.fromRGB(
		190,
		193,
		202
	)


local STYLES = {
	Success = {
		Color =
			Color3.fromRGB(
				74,
				210,
				125
			),

		Icon = "✓",
		Title = "Success",
	},

	Warning = {
		Color =
			Color3.fromRGB(
				255,
				190,
				65
			),

		Icon = "!",
		Title = "Warning",
	},

	Error = {
		Color =
			Color3.fromRGB(
				245,
				82,
				82
			),

		Icon = "×",
		Title = "Error",
	},

	Info = {
		Color =
			Color3.fromRGB(
				90,
				165,
				255
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
-- GUI
--==================================================

local function getGui():
	ScreenGui

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
			20
		)

	holder.Size =
		UDim2.new(
			0,
			CARD_WIDTH,
			1,
			-20
		)

	holder.BackgroundTransparency =
		1

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


	return gui
end


local function getHolder():
	Frame

	local gui =
		getGui()


	return gui:WaitForChild(
		"Holder"
	) :: Frame
end


--==================================================
-- HELPERS
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


	local canvasGroup =
		card:FindFirstChild(
			"Canvas"
		)


	local scale =
		card:FindFirstChild(
			"Scale"
		)


	if not canvasGroup
		or not canvasGroup:IsA(
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
			canvasGroup,

			TweenInfo.new(
				0.18,
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
				0.18,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					0.94,
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
): Frame

	local style =
		STYLES[
			notificationType
		]
		or STYLES.Info


	nextId +=
		1


	local holder =
		getHolder()


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
			CARD_HEIGHT
		)

	card.BackgroundColor3 =
		BACKGROUND_COLOR

	card.BackgroundTransparency =
		0.02

	card.BorderSizePixel =
		0

	card.ClipsDescendants =
		true

	card.Parent =
		holder


	addCorner(
		card,
		14
	)


	local stroke =
		Instance.new(
			"UIStroke"
		)

	stroke.Color =
		Color3.fromRGB(
			55,
			58,
			68
		)

	stroke.Thickness =
		1

	stroke.Transparency =
		0.2

	stroke.Parent =
		card


	-- CanvasGroup controls fade.
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

	canvas.Parent =
		card

	-- Icon.
	local icon =
		Instance.new(
			"TextLabel"
		)

	icon.Name =
		"Icon"

	icon.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)

	icon.Position =
		UDim2.new(
			0,
			18,
			0.5,
			0
		)

	icon.Size =
		UDim2.fromOffset(
			30,
			30
		)

	icon.BackgroundColor3 =
		style.Color

	icon.BackgroundTransparency =
		0.85

	icon.BorderSizePixel =
		0

	icon.Text =
		style.Icon

	icon.TextColor3 =
		style.Color

	icon.TextScaled =
		true

	icon.FontFace =
		Font.new(
			"rbxassetid://12188570269"
		)

	icon.Parent =
		canvas


	addCorner(
		icon,
		9
	)


	local iconConstraint =
		Instance.new(
			"UITextSizeConstraint"
		)

	iconConstraint.MinTextSize =
		12

	iconConstraint.MaxTextSize =
		19

	iconConstraint.Parent =
		icon


	-- Title.
	local title =
		Instance.new(
			"TextLabel"
		)

	title.Name =
		"Title"

	title.Position =
		UDim2.new(
			0,
			60,
			0,
			13
		)

	title.Size =
		UDim2.new(
			1,
			-105,
			0,
			21
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
		17

	title.FontFace =
		Font.new(
			"rbxassetid://12188570269",
			Enum.FontWeight.Bold
		)

	title.Parent =
		canvas


	-- Message.
	local messageLabel =
		Instance.new(
			"TextLabel"
		)

	messageLabel.Name =
		"Message"

	messageLabel.Position =
		UDim2.new(
			0,
			60,
			0,
			35
		)

	messageLabel.Size =
		UDim2.new(
			1,
			-82,
			0,
			25
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

	messageLabel.TextSize =
		14

	messageLabel.FontFace =
		Font.new(
			"rbxassetid://12188570269"
		)

	messageLabel.Parent =
		canvas


	-- Close button.
	local closeButton =
		Instance.new(
			"TextButton"
		)

	closeButton.Name =
		"Close"

	closeButton.AnchorPoint =
		Vector2.new(
			1,
			0
		)

	closeButton.Position =
		UDim2.new(
			1,
			-10,
			0,
			9
		)

	closeButton.Size =
		UDim2.fromOffset(
			26,
			26
		)

	closeButton.BackgroundTransparency =
		1

	closeButton.Text =
		"×"

	closeButton.TextColor3 =
		Color3.fromRGB(
			150,
			153,
			163
		)

	closeButton.TextSize =
		20

	closeButton.FontFace =
		Font.new(
			"rbxassetid://12188570269"
		)

	closeButton.AutoButtonColor =
		false

	closeButton.Parent =
		canvas


	closeButton.Activated:Connect(
		function()

			closeNotification(
				card
			)
		end
	)


	-- Timer bar.
	local progressBackground =
		Instance.new(
			"Frame"
		)

	progressBackground.Name =
		"ProgressBackground"

	progressBackground.AnchorPoint =
		Vector2.new(
			0,
			1
		)

	progressBackground.Position =
		UDim2.new(
			0,
			5,
			1,
			0
		)

	progressBackground.Size =
		UDim2.new(
			1,
			-5,
			0,
			3
		)

	progressBackground.BackgroundColor3 =
		Color3.fromRGB(
			45,
			47,
			55
		)

	progressBackground.BorderSizePixel =
		0

	progressBackground.Parent =
		canvas


	local progress =
		Instance.new(
			"Frame"
		)

	progress.Name =
		"Progress"

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


	-- Scale used for open/close.
	local scale =
		Instance.new(
			"UIScale"
		)

	scale.Name =
		"Scale"

	scale.Scale =
		0.94

	scale.Parent =
		card


	-- Open animation.
	TweenService:Create(
		canvas,

		TweenInfo.new(
			0.2,
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
			0.24,
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


	while #activeNotifications
		>= MAX_NOTIFICATIONS do

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
		options.Duration
		or DEFAULT_DURATION


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