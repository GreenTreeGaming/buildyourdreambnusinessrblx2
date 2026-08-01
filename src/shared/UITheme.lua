local TweenService = game:GetService("TweenService")

local UITheme = {}

UITheme.Colors = {
	Background = Color3.fromRGB(12, 18, 29),
	Surface = Color3.fromRGB(21, 31, 47),
	SurfaceRaised = Color3.fromRGB(31, 45, 65),
	SurfaceLight = Color3.fromRGB(42, 58, 81),

	Primary = Color3.fromRGB(255, 196, 72),
	PrimaryDark = Color3.fromRGB(232, 156, 42),

	Success = Color3.fromRGB(66, 211, 126),
	SuccessDark = Color3.fromRGB(33, 158, 90),

	Info = Color3.fromRGB(92, 157, 255),
	InfoDark = Color3.fromRGB(55, 105, 202),

	Danger = Color3.fromRGB(255, 91, 108),
	DangerDark = Color3.fromRGB(203, 54, 73),

	Text = Color3.fromRGB(248, 250, 255),
	TextMuted = Color3.fromRGB(176, 190, 211),
	TextDark = Color3.fromRGB(40, 32, 18),

	Stroke = Color3.fromRGB(74, 94, 124),
	Shadow = Color3.fromRGB(4, 7, 12),

	ProgressTrack = Color3.fromRGB(48, 61, 82),
}

UITheme.Fonts = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Semibold = Enum.Font.GothamSemibold,
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
}

function UITheme.AddCorner(
	parent: GuiObject,
	radiusScale: number?
): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(
		radiusScale or 0.16,
		0
	)
	corner.Parent = parent

	return corner
end

function UITheme.AddStroke(
	parent: GuiObject,
	color: Color3?,
	thickness: number?,
	transparency: number?
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UITheme.Colors.Stroke
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0.15
	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border

	stroke.Parent = parent

	return stroke
end

function UITheme.AddGradient(
	parent: GuiObject,
	topColor: Color3,
	bottomColor: Color3,
	rotation: number?
): UIGradient
	local gradient = Instance.new("UIGradient")

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(
			0,
			topColor
		),
		ColorSequenceKeypoint.new(
			1,
			bottomColor
		),
	})

	gradient.Rotation = rotation or 90
	gradient.Parent = parent

	return gradient
end

function UITheme.AddPadding(
	parent: GuiObject,
	left: number,
	right: number,
	top: number,
	bottom: number
): UIPadding
	local padding = Instance.new("UIPadding")

	padding.PaddingLeft = UDim.new(left, 0)
	padding.PaddingRight = UDim.new(right, 0)
	padding.PaddingTop = UDim.new(top, 0)
	padding.PaddingBottom = UDim.new(bottom, 0)

	padding.Parent = parent

	return padding
end

function UITheme.StyleText(
	textObject: TextLabel | TextButton,
	minimumSize: number,
	maximumSize: number,
	color: Color3?,
	font: Enum.Font?
)
	textObject.TextColor3 =
		color or UITheme.Colors.Text

	textObject.Font =
		font or UITheme.Fonts.Semibold

	textObject.TextScaled = true
	textObject.TextWrapped = true

	local constraint =
		Instance.new("UITextSizeConstraint")

	constraint.MinTextSize = minimumSize
	constraint.MaxTextSize = maximumSize
	constraint.Parent = textObject
end

function UITheme.AddButtonMotion(
	button: TextButton
): UIScale
	local existing =
		button:FindFirstChildOfClass("UIScale")

	local scale

	if existing then
		scale = existing
	else
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button
	end

	local activeTween: Tween? = nil

	local function tweenTo(
		targetScale: number,
		duration: number
	)
		if activeTween then
			activeTween:Cancel()
		end

		activeTween = TweenService:Create(
			scale,
			TweenInfo.new(
				duration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Scale = targetScale,
			}
		)

		activeTween:Play()
	end

	button.MouseEnter:Connect(function()
		if button.Active then
			tweenTo(1.035, 0.12)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenTo(1, 0.12)
	end)

	button.MouseButton1Down:Connect(function()
		if button.Active then
			tweenTo(0.965, 0.07)
		end
	end)

	button.MouseButton1Up:Connect(function()
		if button.Active then
			tweenTo(1.02, 0.08)
		end
	end)

	return scale
end

function UITheme.StyleButton(
	button: TextButton,
	topColor: Color3,
	bottomColor: Color3,
	textColor: Color3?
)
	button.BackgroundColor3 = topColor
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.TextColor3 =
		textColor or UITheme.Colors.Text

	UITheme.AddCorner(button, 0.22)

	UITheme.AddStroke(
		button,
		topColor:Lerp(Color3.new(1, 1, 1), 0.25),
		1.5,
		0.3
	)

	UITheme.AddGradient(
		button,
		topColor,
		bottomColor
	)

	UITheme.AddButtonMotion(button)
end

function UITheme.SetButtonEnabled(
	button: TextButton,
	enabled: boolean,
	enabledTop: Color3,
	enabledBottom: Color3
)
	button.Active = enabled
	button.Selectable = enabled
	button.TextColor3 = UITheme.Colors.Text
	button.TextTransparency = 0

	local gradient =
		button:FindFirstChildOfClass("UIGradient")

	if enabled then
		button.BackgroundColor3 = enabledTop

		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(
					0,
					enabledTop
				),
				ColorSequenceKeypoint.new(
					1,
					enabledBottom
				),
			})
		end
	else
		local disabledTop =
			Color3.fromRGB(74, 85, 101)

		local disabledBottom =
			Color3.fromRGB(51, 61, 75)

		button.BackgroundColor3 = disabledTop

		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(
					0,
					disabledTop
				),
				ColorSequenceKeypoint.new(
					1,
					disabledBottom
				),
			})
		end
	end
end

return UITheme