local Players =
	game:GetService("Players")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

if not player then
	error(
		"Notification can only be required from the client."
	)
end


local playerGui =
	player:WaitForChild("PlayerGui")


local Notification = {}


type NotificationType =
	"Success"
	| "Warning"
	| "Error"
	| "Info"


type NotificationOptions = {
	Title: string?,
	Duration: number?,
}


type NotificationStyle = {
	Title: string,
	Icon: string,

	Color: Color3,
	DarkColor: Color3,

	Duration: number,
}


local FONT =
	Enum.Font.MPlusRounded1c


local MAX_NOTIFICATIONS =
	4

local ENTER_TIME =
	0.28

local EXIT_TIME =
	0.2


local CARD_BACKGROUND =
	Color3.fromRGB(
		24,
		30,
		43
	)

local CARD_BACKGROUND_BOTTOM =
	Color3.fromRGB(
		17,
		22,
		33
	)

local TEXT_COLOR =
	Color3.fromRGB(
		255,
		255,
		255
	)

local SUBTEXT_COLOR =
	Color3.fromRGB(
		207,
		215,
		229
	)


local STYLES: {
	[NotificationType]: NotificationStyle
} = {

	Success = {
		Title = "Success",
		Icon = "✓",

		Color =
			Color3.fromRGB(
				72,
				222,
				133
			),

		DarkColor =
			Color3.fromRGB(
				32,
				159,
				87
			),

		Duration = 3,
	},

	Warning = {
		Title = "Warning",
		Icon = "!",

		Color =
			Color3.fromRGB(
				255,
				194,
				74
			),

		DarkColor =
			Color3.fromRGB(
				213,
				133,
				34
			),

		Duration = 3.5,
	},

	Error = {
		Title = "Error",
		Icon = "×",

		Color =
			Color3.fromRGB(
				255,
				92,
				111
			),

		DarkColor =
			Color3.fromRGB(
				194,
				46,
				68
			),

		Duration = 4,
	},

	Info = {
		Title = "Notice",
		Icon = "i",

		Color =
			Color3.fromRGB(
				82,
				169,
				255
			),

		DarkColor =
			Color3.fromRGB(
				47,
				108,
				207
			),

		Duration = 3,
	},
}


local activeCards: {
	CanvasGroup
} = {}


local recentNotifications: {
	[string]: number
} = {}


local screenGui =
	playerGui:FindFirstChild(
		"Notifications"
	)


if screenGui
	and not screenGui:IsA(
		"ScreenGui"
	) then

	screenGui:Destroy()

	screenGui =
		nil
end


if not screenGui then

	screenGui =
		Instance.new(
			"ScreenGui"
		)

	screenGui.Name =
		"Notifications"

	screenGui.ResetOnSpawn =
		false

	screenGui.IgnoreGuiInset =
		false

	-- Keep notifications above the rest of the game's UI.
	screenGui.DisplayOrder =
		10000

	screenGui.ZIndexBehavior =
		Enum.ZIndexBehavior.Global

	screenGui.Parent =
		playerGui
end


screenGui =
	screenGui :: ScreenGui


local existingContainer =
	screenGui:FindFirstChild(
		"Container"
	)


if existingContainer then
	existingContainer:Destroy()
end


local container =
	Instance.new(
		"Frame"
	)

container.Name =
	"Container"

container.AnchorPoint =
	Vector2.new(
		0.5,
		0
	)

container.Position =
	UDim2.new(
		0.5,
		0,
		0,
		18
	)

container.Size =
	UDim2.new(
		1,
		-28,
		0,
		0
	)

container.AutomaticSize =
	Enum.AutomaticSize.Y

container.BackgroundTransparency =
	1

container.BorderSizePixel =
	0

container.ZIndex =
	1000

container.Parent =
	screenGui


local sizeConstraint =
	Instance.new(
		"UISizeConstraint"
	)

sizeConstraint.MaxSize =
	Vector2.new(
		540,
		10000
	)

sizeConstraint.Parent =
	container


local listLayout =
	Instance.new(
		"UIListLayout"
	)

listLayout.FillDirection =
	Enum.FillDirection.Vertical

listLayout.HorizontalAlignment =
	Enum.HorizontalAlignment.Center

listLayout.VerticalAlignment =
	Enum.VerticalAlignment.Top

listLayout.SortOrder =
	Enum.SortOrder.LayoutOrder

listLayout.Padding =
	UDim.new(
		0,
		9
	)

listLayout.Parent =
	container


local function addCorner(
	object: GuiObject,
	radius: number
): UICorner

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
		object

	return corner
end


local function addStroke(
	object: GuiObject,
	color: Color3,
	thickness: number,
	transparency: number
): UIStroke

	local stroke =
		Instance.new(
			"UIStroke"
		)

	stroke.Color =
		color

	stroke.Thickness =
		thickness

	stroke.Transparency =
		transparency

	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border

	stroke.Parent =
		object

	return stroke
end


local function addGradient(
	object: GuiObject,
	topColor: Color3,
	bottomColor: Color3
): UIGradient

	local gradient =
		Instance.new(
			"UIGradient"
		)

	gradient.Color =
		ColorSequence.new({
			ColorSequenceKeypoint.new(
				0,
				topColor
			),

			ColorSequenceKeypoint.new(
				1,
				bottomColor
			),
		})

	gradient.Rotation =
		90

	gradient.Parent =
		object

	return gradient
end


local function removeActiveCard(
	card: CanvasGroup
)
	local index =
		table.find(
			activeCards,
			card
		)

	if index then
		table.remove(
			activeCards,
			index
		)
	end
end


local function dismissCard(
	card: CanvasGroup
)
	if card:GetAttribute(
		"Dismissing"
	) == true then

		return
	end


	if not card.Parent then
		return
	end


	card:SetAttribute(
		"Dismissing",
		true
	)


	removeActiveCard(
		card
	)


	local scale =
		card:FindFirstChild(
			"AnimationScale"
		)


	local content =
		card:FindFirstChild(
			"Content"
		)


	local fadeTween =
		TweenService:Create(
			card,

			TweenInfo.new(
				EXIT_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				GroupTransparency = 1,
			}
		)


	local scaleTween: Tween? =
		nil


	if scale
		and scale:IsA(
			"UIScale"
		) then

		scaleTween =
			TweenService:Create(
				scale,

				TweenInfo.new(
					EXIT_TIME,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				),

				{
					Scale = 0.94,
				}
			)

		scaleTween:Play()
	end


	if content
		and content:IsA(
			"GuiObject"
		) then

		TweenService:Create(
			content,

			TweenInfo.new(
				EXIT_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Position =
					UDim2.fromOffset(
						0,
						-8
					),
			}
		):Play()
	end


	fadeTween.Completed:Once(
		function()

			if card.Parent then
				card:Destroy()
			end
		end
	)


	fadeTween:Play()
end


local function enforceLimit()
	while #activeCards
		> MAX_NOTIFICATIONS do

		local oldest =
			activeCards[1]

		if not oldest then
			break
		end

		dismissCard(
			oldest
		)
	end
end


local function createCard(
	notificationType: NotificationType,
	message: string,
	options: NotificationOptions?
): CanvasGroup

	local style =
		STYLES[
			notificationType
		]


	local titleText =
		options
		and options.Title
		or style.Title


	local card =
		Instance.new(
			"CanvasGroup"
		)

	card.Name =
		`{notificationType}Notification`

	card.Size =
		UDim2.new(
			1,
			0,
			0,
			82
		)

	card.BackgroundColor3 =
		CARD_BACKGROUND

	card.BackgroundTransparency =
		0.02

	card.BorderSizePixel =
		0

	card.GroupTransparency =
		1

	card.ZIndex =
		1001

	card.Parent =
		container


	addCorner(
		card,
		14
	)


	addStroke(
		card,
		style.Color,
		1.5,
		0.38
	)


	addGradient(
		card,
		CARD_BACKGROUND,
		CARD_BACKGROUND_BOTTOM
	)


	local scale =
		Instance.new(
			"UIScale"
		)

	scale.Name =
		"AnimationScale"

	scale.Scale =
		0.92

	scale.Parent =
		card


	local accent =
		Instance.new(
			"Frame"
		)

	accent.Name =
		"Accent"

	accent.AnchorPoint =
		Vector2.new(
			0,
			0.5
		)

	accent.Position =
		UDim2.new(
			0,
			0,
			0.5,
			0
		)

	accent.Size =
		UDim2.new(
			0,
			6,
			1,
			-18
		)

	accent.BackgroundColor3 =
		style.Color

	accent.BorderSizePixel =
		0

	accent.ZIndex =
		1003

	accent.Parent =
		card


	addCorner(
		accent,
		6
	)


	local content =
		Instance.new(
			"Frame"
		)

	content.Name =
		"Content"

	content.Position =
		UDim2.fromOffset(
			0,
			-10
		)

	content.Size =
		UDim2.fromScale(
			1,
			1
		)

	content.BackgroundTransparency =
		1

	content.ZIndex =
		1002

	content.Parent =
		card


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
			18,
			0.5,
			0
		)

	iconBackground.Size =
		UDim2.fromOffset(
			42,
			42
		)

	iconBackground.BackgroundColor3 =
		style.Color

	iconBackground.BackgroundTransparency =
		0.84

	iconBackground.BorderSizePixel =
		0

	iconBackground.ZIndex =
		1004

	iconBackground.Parent =
		content


	addCorner(
		iconBackground,
		21
	)


	addStroke(
		iconBackground,
		style.Color,
		1.5,
		0.42
	)


	local icon =
		Instance.new(
			"TextLabel"
		)

	icon.Name =
		"Icon"

	icon.Size =
		UDim2.fromScale(
			1,
			1
		)

	icon.BackgroundTransparency =
		1

	icon.Font =
		FONT

	icon.Text =
		style.Icon

	icon.TextColor3 =
		style.Color

	icon.TextScaled =
		true

	icon.ZIndex =
		1005

	icon.Parent =
		iconBackground


	local iconConstraint =
		Instance.new(
			"UITextSizeConstraint"
		)

	iconConstraint.MinTextSize =
		16

	iconConstraint.MaxTextSize =
		26

	iconConstraint.Parent =
		icon


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
			-13,
			0.5,
			0
		)

	closeButton.Size =
		UDim2.fromOffset(
			30,
			30
		)

	closeButton.BackgroundTransparency =
		1

	closeButton.AutoButtonColor =
		false

	closeButton.Font =
		FONT

	closeButton.Text =
		"×"

	closeButton.TextColor3 =
		Color3.fromRGB(
			169,
			181,
			201
		)

	closeButton.TextSize =
		24

	closeButton.ZIndex =
		1006

	closeButton.Parent =
		content


	local title =
		Instance.new(
			"TextLabel"
		)

	title.Name =
		"Title"

	title.Position =
		UDim2.new(
			0,
			73,
			0,
			14
		)

	title.Size =
		UDim2.new(
			1,
			-120,
			0,
			23
		)

	title.BackgroundTransparency =
		1

	title.Font =
		FONT

	title.Text =
		titleText

	title.TextColor3 =
		style.Color

	title.TextSize =
		18

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.TextYAlignment =
		Enum.TextYAlignment.Center

	title.TextTruncate =
		Enum.TextTruncate.AtEnd

	title.ZIndex =
		1005

	title.Parent =
		content


	local messageLabel =
		Instance.new(
			"TextLabel"
		)

	messageLabel.Name =
		"Message"

	messageLabel.Position =
		UDim2.new(
			0,
			73,
			0,
			37
		)

	messageLabel.Size =
		UDim2.new(
			1,
			-120,
			0,
			29
		)

	messageLabel.BackgroundTransparency =
		1

	messageLabel.Font =
		FONT

	messageLabel.Text =
		message

	messageLabel.TextColor3 =
		SUBTEXT_COLOR

	messageLabel.TextSize =
		14

	messageLabel.TextWrapped =
		true

	messageLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	messageLabel.TextYAlignment =
		Enum.TextYAlignment.Top

	messageLabel.ZIndex =
		1005

	messageLabel.Parent =
		content


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
			15,
			1,
			-7
		)

	progressBackground.Size =
		UDim2.new(
			1,
			-30,
			0,
			3
		)

	progressBackground.BackgroundColor3 =
		Color3.fromRGB(
			56,
			65,
			81
		)

	progressBackground.BackgroundTransparency =
		0.4

	progressBackground.BorderSizePixel =
		0

	progressBackground.ZIndex =
		1003

	progressBackground.Parent =
		card


	addCorner(
		progressBackground,
		3
	)


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

	progress.ZIndex =
		1004

	progress.Parent =
		progressBackground


	addCorner(
		progress,
		3
	)


	closeButton.Activated:Connect(
		function()
			dismissCard(
				card
			)
		end
	)


	return card
end


function Notification.Show(
	notificationType: NotificationType,
	message: string,
	options: NotificationOptions?
)
	if typeof(message)
		~= "string"
		or message == "" then

		return
	end


	local style =
		STYLES[
			notificationType
		]


	if not style then
		warn(
			`Unknown notification type: {notificationType}`
		)

		return
	end


	--
	-- Prevent accidental duplicate notifications when multiple
	-- UI systems happen to receive the same server result.
	--
	local duplicateKey =
		`{notificationType}:{message}`


	local now =
		os.clock()


	local previous =
		recentNotifications[
			duplicateKey
		]


	if previous
		and now - previous
			< 0.4 then

		return
	end


	recentNotifications[
		duplicateKey
	] =
		now


	local card =
		createCard(
			notificationType,
			message,
			options
		)


	table.insert(
		activeCards,
		card
	)


	enforceLimit()


	local scale =
		card:FindFirstChild(
			"AnimationScale"
		) :: UIScale


	local content =
		card:FindFirstChild(
			"Content"
		) :: Frame


	TweenService:Create(
		card,

		TweenInfo.new(
			ENTER_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			GroupTransparency = 0,
		}
	):Play()


	TweenService:Create(
		scale,

		TweenInfo.new(
			ENTER_TIME,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),

		{
			Scale = 1,
		}
	):Play()


	TweenService:Create(
		content,

		TweenInfo.new(
			ENTER_TIME,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		),

		{
			Position =
				UDim2.fromOffset(
					0,
					0
				),
		}
	):Play()


	local duration =
		style.Duration


	if options
		and typeof(
			options.Duration
		) == "number" then

		duration =
			math.clamp(
				options.Duration,
				1,
				15
			)
	end


	local progress =
		card
			:WaitForChild(
				"ProgressBackground"
			)
			:WaitForChild(
				"Progress"
			) :: Frame


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
				dismissCard(
					card
				)
			end
		end
	)
end


function Notification.Success(
	message: string,
	options: NotificationOptions?
)
	Notification.Show(
		"Success",
		message,
		options
	)
end


function Notification.Warning(
	message: string,
	options: NotificationOptions?
)
	Notification.Show(
		"Warning",
		message,
		options
	)
end


function Notification.Error(
	message: string,
	options: NotificationOptions?
)
	Notification.Show(
		"Error",
		message,
		options
	)
end


function Notification.Info(
	message: string,
	options: NotificationOptions?
)
	Notification.Show(
		"Info",
		message,
		options
	)
end


return Notification