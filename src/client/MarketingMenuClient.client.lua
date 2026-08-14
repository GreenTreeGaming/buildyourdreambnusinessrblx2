task.wait(3)

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getMarketingStateRemote =
	remotes:WaitForChild(
		"GetMarketingState"
	)

local purchaseMarketingRemote =
	remotes:WaitForChild(
		"PurchaseMarketing"
	)

local marketingResultRemote =
	remotes:WaitForChild(
		"MarketingResult"
	)


type MarketingState = {
	Success: boolean,
	Message: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,
	TemplateName: string?,

	CustomerLimit: number?,
	MinimumSpawnInterval: number?,
	MaximumSpawnInterval: number?,
}


local gui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui


local main =
	gui:WaitForChild(
		"Main"
	) :: Frame


local openButton =
	gui:WaitForChild(
		"OpenButton"
	) :: TextButton


local closeButton =
	main:WaitForChild(
		"Close"
	) :: TextButton


local content =
	main:WaitForChild(
		"Frame"
	) :: Frame


local buyButton =
	content:WaitForChild(
		"Buy"
	) :: TextButton


local buyText =
	buyButton:WaitForChild(
		"InText"
	) :: TextLabel


local customerLimitFrame =
	content:WaitForChild(
		"CustomerLimit"
	) :: Frame


local customerLimitTitle =
	customerLimitFrame:WaitForChild(
		"Title"
	) :: TextLabel


local customerLimitSubtitle =
	customerLimitFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


local spawnTimeFrame =
	content:WaitForChild(
		"SpawnTime"
	) :: Frame


local spawnTimeTitle =
	spawnTimeFrame:WaitForChild(
		"Title"
	) :: TextLabel


local spawnTimeSubtitle =
	spawnTimeFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


local levelsFrame =
	content:WaitForChild(
		"Levels"
	) :: Frame


local levelLabel =
	levelsFrame:WaitForChild(
		"Level"
	) :: TextLabel


local marketingNameLabel =
	levelsFrame:WaitForChild(
		"Title"
	) :: TextLabel


local marketingDescriptionLabel =
	levelsFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


local progressFrame =
	content:WaitForChild(
		"Progress"
	) :: Frame


local progressTitle =
	progressFrame:WaitForChild(
		"Title"
	) :: TextLabel


local progressSubtitle =
	progressFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


local progressBackground =
	progressFrame:WaitForChild(
		"Background"
	) :: Frame


local progressBar =
	progressBackground:WaitForChild(
		"Bar"
	) :: Frame


local menuOpen =
	false

local requestPending =
	false

local currentState:
	MarketingState? =
	nil


local MAIN_OPEN_POSITION =
	main.Position

local MAIN_OPEN_SIZE =
	main.Size


local mainScale =
	main:FindFirstChildOfClass(
		"UIScale"
	)

if not mainScale then
	mainScale =
		Instance.new("UIScale")

	mainScale.Name =
		"MenuScale"

	mainScale.Scale =
		1

	mainScale.Parent =
		main
end


local function formatSpawnTime(
	minimum: number?,
	maximum: number?
): string
	if typeof(minimum) ~= "number"
		or typeof(maximum) ~= "number" then

		return "--"
	end

	local average =
		(minimum + maximum) / 2

	return string.format(
		"%.1fs",
		average
	)
end


local function setBuyEnabled(
	enabled: boolean
)
	buyButton.Active =
		enabled

	buyButton.Selectable =
		enabled

	buyButton.AutoButtonColor =
		enabled

	buyButton.BackgroundTransparency =
		enabled
			and 0
			or 0.35
end


local function updateProgress(
	currentLevel: number,
	maximumLevel: number
)
	local progress =
		0

	if maximumLevel > 0 then
		progress =
			math.clamp(
				currentLevel / maximumLevel,
				0,
				1
			)
	end


	TweenService:Create(
		progressBar,
		TweenInfo.new(
			0.22,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size =
				UDim2.new(
					progress,
					0,
					progressBar.Size.Y.Scale,
					progressBar.Size.Y.Offset
				),
		}
	):Play()
end


local function updateInterface(
	state: MarketingState
)
	currentState =
		state


	local currentLevel =
		typeof(state.CurrentLevel) == "number"
			and math.max(
				0,
				math.floor(
					state.CurrentLevel
				)
			)
			or 0


	local maximumLevel =
		typeof(state.MaximumLevel) == "number"
			and math.max(
				0,
				math.floor(
					state.MaximumLevel
				)
			)
			or 0


	-- Top information card.
	levelLabel.Text =
		`Level {currentLevel}/{maximumLevel}`

	marketingNameLabel.Text =
		state.DisplayName
		or "Marketing"

	marketingDescriptionLabel.Text =
		state.Description
		or "Bring more customers to your business!"


	-- Customer limit card.
	customerLimitTitle.Text =
		"Customer Limit"

	if typeof(state.CustomerLimit) == "number" then
		customerLimitSubtitle.Text =
	FormatNumber.Compact(
		state.CustomerLimit
	)
	else
		customerLimitSubtitle.Text =
			"--"
	end


	-- Spawn time card.
	spawnTimeTitle.Text =
		"Spawn Time"

	spawnTimeSubtitle.Text =
		formatSpawnTime(
			state.MinimumSpawnInterval,
			state.MaximumSpawnInterval
		)


	-- Progress card.
	progressTitle.Text =
		"Marketing Progress"

	progressSubtitle.Text =
		`{currentLevel}/{maximumLevel}`

	updateProgress(
		currentLevel,
		maximumLevel
	)


	-- Maximum level.
	if maximumLevel > 0
		and currentLevel >= maximumLevel then

		buyText.Text =
			"Max Marketing Level"

		setBuyEnabled(
			false
		)

		return
	end


	-- Upgrade button.
	if typeof(state.NextCost) == "number" then
		buyText.Text =
	`Upgrade Marketing - ${FormatNumber.Compact(state.NextCost)}`

		setBuyEnabled(
			not requestPending
		)
	else
		buyText.Text =
			"Upgrade Unavailable"

		setBuyEnabled(
			false
		)
	end
end


local function requestState()
	if requestPending then
		return
	end


	requestPending =
		true

	buyText.Text =
		"Loading..."

	setBuyEnabled(
		false
	)


	local success, result =
		pcall(function()
			return getMarketingStateRemote
				:InvokeServer()
		end)


	requestPending =
		false


	if not success
		or type(result) ~= "table" then

		warn(
			"[MarketingMenu] Failed to load marketing state."
		)

		buyText.Text =
			"Try Again"

		setBuyEnabled(
			true
		)

		return
	end


	updateInterface(
		result :: MarketingState
	)
end


local activeMenuTween:
	Tween? =
	nil


local function stopMenuTween()
	if activeMenuTween then
		activeMenuTween:Cancel()
		activeMenuTween = nil
	end
end


local function openMenu()
	if menuOpen then
		return
	end

	menuOpen = true

	stopMenuTween()

	main.Visible = true

	-- Keep the side Manage button visible
	-- while the marketing menu is open.
	openButton.Visible = true

	mainScale.Scale = 0.92

	local tween =
		TweenService:Create(
			mainScale,
			TweenInfo.new(
				0.22,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Scale = 1,
			}
		)

	activeMenuTween = tween

	tween.Completed:Once(function()
		if activeMenuTween == tween then
			activeMenuTween = nil
		end
	end)

	tween:Play()

	requestState()
end

local function closeMenu()
	if not menuOpen then
		return
	end

	menuOpen = false

	stopMenuTween()

	local tween =
		TweenService:Create(
			mainScale,
			TweenInfo.new(
				0.14,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{
				Scale = 0.92,
			}
		)

	activeMenuTween = tween

	tween.Completed:Once(function()
		if activeMenuTween ~= tween then
			return
		end

		activeMenuTween = nil

		if not menuOpen then
			main.Visible = false
			openButton.Visible = true
			mainScale.Scale = 1
		end
	end)

	tween:Play()
end

openButton.Activated:Connect(function()
	openMenu()
end)


closeButton.Active = true
closeButton.Selectable = true

closeButton.Activated:Connect(function()
	print("CLOSE BUTTON CLICKED")
	closeMenu()
end)


buyButton.Activated:Connect(function()
	if requestPending then
		return
	end


	local state =
		currentState

	if not state then
		requestState()
		return
	end


	local currentLevel =
		typeof(state.CurrentLevel) == "number"
			and state.CurrentLevel
			or 0

	local maximumLevel =
		typeof(state.MaximumLevel) == "number"
			and state.MaximumLevel
			or 0


	if maximumLevel > 0
		and currentLevel >= maximumLevel then

		return
	end


	if typeof(state.NextCost) ~= "number" then
		return
	end


	requestPending =
		true

	buyText.Text =
		"Purchasing..."

	setBuyEnabled(
		false
	)


	purchaseMarketingRemote
		:FireServer()
end)


marketingResultRemote.OnClientEvent:Connect(
	function(result)
		requestPending =
			false


		if type(result) ~= "table" then
			warn(
				"[MarketingMenu] Invalid marketing result."
			)

			requestState()

			return
		end


		updateInterface(
			result :: MarketingState
		)
	end
)


UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)
		if gameProcessed
			or not menuOpen then

			return
		end


		if input.KeyCode == Enum.KeyCode.Escape
			or input.KeyCode == Enum.KeyCode.ButtonB then

			closeMenu()
		end
	end
)


player:GetAttributeChangedSignal(
	"DataLoaded"
):Connect(function()
	if player:GetAttribute(
		"DataLoaded"
	) == true
		and menuOpen then

		requestState()
	end
end)


-- Initial UI state.
main.Position =
	MAIN_OPEN_POSITION

main.Size =
	MAIN_OPEN_SIZE

main.Visible =
	false

openButton.Visible =
	true

progressBar.Size =
	UDim2.new(
		0,
		0,
		progressBar.Size.Y.Scale,
		progressBar.Size.Y.Offset
	)