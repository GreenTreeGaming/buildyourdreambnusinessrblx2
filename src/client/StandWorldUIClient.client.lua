local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local RunService =
	game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Debris = game:GetService("Debris")
local TweenService =
	game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
ReplicatedStorage:WaitForChild("Remotes")

local manualSaleResultRemote =
	remotes:WaitForChild(
		"ManualLemonadeSaleResult"
	)

local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors = UITheme.Colors
local Fonts = UITheme.Fonts

type StandUIState = {
	Stand: Model,
	Billboard: BillboardGui,

	TimerLabel: TextLabel, 
	StatusLabel: TextLabel,
	ProgressFill: Frame,

	PositionPart: BasePart,
}

local standStates: {
	[Model]: StandUIState
} = {}

local watchedFolders: {
	[Instance]: boolean
} = {}

local BUSINESS_NAME = "LemonadeStand"

local function isLemonadeStand(
	stand: Instance
): boolean
	if not stand:IsA("Model") then
		return false
	end

	local businessType =
		stand:GetAttribute("BusinessType")

	if businessType == BUSINESS_NAME then
		return true
	end

	return stand.Name == BUSINESS_NAME
		or string.match(
			stand.Name,
			"^LemonadeStand_"
		) ~= nil
end

local function disableLegacyWorldUI(
	instance: Instance
)
	if not instance:IsA("BillboardGui") then
		return
	end

	if instance.Name == "ResponsiveServiceTimer"
		or instance.Name == "CashPopup" then

		return
	end

	-- Prevent an older timer embedded in the place model
	-- from appearing over the responsive timer.
	instance.Enabled = false
end

local function getTimerPosition(
	stand: Model,
	waitForReplication: boolean?
): BasePart?
	local function findPosition(): BasePart?
		local timerPosition =
			stand:FindFirstChild(
				"CooldownUIPosition",
				true
			)

		if timerPosition
			and timerPosition:IsA("BasePart") then

			return timerPosition
		end

		local salePosition =
			stand:FindFirstChild(
				"SaleEffectPosition",
				true
			)

		if salePosition
			and salePosition:IsA("BasePart") then

			return salePosition
		end

		local managementPosition =
			stand:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		if managementPosition
			and managementPosition:IsA("BasePart") then

			return managementPosition
		end

		if stand.PrimaryPart then
			return stand.PrimaryPart
		end

		return nil
	end

	local existing = findPosition()

	if existing or waitForReplication ~= true then
		return existing
	end

	-- The model may replicate before all of its parts.
	local startedAt = time()

	while stand.Parent
		and time() - startedAt < 10 do

		local position = findPosition()

		if position then
			return position
		end

		task.wait(0.1)
	end

	return stand:FindFirstChildWhichIsA(
		"BasePart",
		true
	)
end

local function removeStandUI(
	stand: Model
)
	local state = standStates[stand]

	if not state then
		return
	end

	state.Billboard:Destroy()
	standStates[stand] = nil
end

local function createStandUI(
	stand: Model
)
	if standStates[stand]
	or not isLemonadeStand(stand) then

	return
end

	local positionPart =
	getTimerPosition(
		stand,
		true
	)

	if not positionPart then
		warn(
	`{stand:GetFullName()} did not finish loading a UI position.`
)

		return
	end

	for _, child in
		positionPart:GetChildren() do

		disableLegacyWorldUI(child)
	end

	positionPart.ChildAdded:Connect(
		disableLegacyWorldUI
	)

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name =
		"ResponsiveServiceTimer"

	billboard.Adornee = positionPart

	-- Scale values are world-space studs.
	billboard.Size =
		UDim2.fromScale(5.8, 1.8)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 2.5, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Enabled = false
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint =
		Vector2.new(0.5, 0.5)

	shadow.Position =
		UDim2.fromScale(0.52, 0.56)

	shadow.Size =
		UDim2.fromScale(0.96, 0.9)

	shadow.BackgroundColor3 =
		Colors.Shadow

	shadow.BackgroundTransparency = 0.28
	shadow.BorderSizePixel = 0
	shadow.Parent = billboard

	UITheme.AddCorner(shadow, 0.14)

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint =
		Vector2.new(0.5, 0.5)

	container.Position =
		UDim2.fromScale(0.5, 0.5)

	container.Size =
		UDim2.fromScale(0.96, 0.9)

	container.BackgroundColor3 =
		Colors.Surface

	container.BorderSizePixel = 0
	container.Parent = billboard

	UITheme.AddCorner(container, 0.14)

	UITheme.AddStroke(
		container,
		Colors.Primary,
		2,
		0.2
	)

	UITheme.AddGradient(
		container,
		Colors.SurfaceRaised,
		Colors.Background
	)

	local statusLabel =
		Instance.new("TextLabel")

	statusLabel.Name = "StatusLabel"
	statusLabel.Position =
	UDim2.fromScale(0.07, 0.12)

statusLabel.Size =
	UDim2.fromScale(0.62, 0.22)

	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "READY"
	statusLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	statusLabel.Parent = container

	UITheme.StyleText(
		statusLabel,
		9,
		14,
		Colors.TextMuted,
		Fonts.Bold
	)

	local timerLabel =
		Instance.new("TextLabel")

	timerLabel.Name = "TimerLabel"
	timerLabel.Position =
		UDim2.fromScale(0.72, 0.1)

	timerLabel.Size =
		UDim2.fromScale(0.23, 0.32)

	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "OPEN"
	timerLabel.TextXAlignment =
		Enum.TextXAlignment.Right

	timerLabel.Parent = container

	UITheme.StyleText(
		timerLabel,
		13,
		22,
		Colors.Primary,
		Fonts.Black
	)

	local progressTrack =
		Instance.new("Frame")

	progressTrack.Name = "ProgressTrack"
	progressTrack.Position =
	UDim2.fromScale(0.07, 0.55)

progressTrack.Size =
	UDim2.fromScale(0.88, 0.19)

	progressTrack.BackgroundColor3 =
		Colors.ProgressTrack

	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.Parent = container

	UITheme.AddCorner(progressTrack, 0.5)

	local progressFill =
		Instance.new("Frame")

	progressFill.Name = "ProgressFill"
	progressFill.Size =
		UDim2.fromScale(0, 1)

	progressFill.BackgroundColor3 =
		Colors.Primary

	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack

	UITheme.AddCorner(progressFill, 0.5)

	UITheme.AddGradient(
		progressFill,
		Colors.Primary,
		Colors.Success,
		0
	)

	standStates[stand] = {
		Stand = stand,
		Billboard = billboard,

		TimerLabel = timerLabel,
		StatusLabel = statusLabel,
		ProgressFill = progressFill,

		PositionPart = positionPart,
	}

	stand.Destroying:Connect(function()
		removeStandUI(stand)
	end)
end

local function showSalePopup(
	stand: Model,
	amount: number
)
	local positionPart =
		stand:FindFirstChild(
			"SaleEffectPosition",
			true
		)
		or stand:FindFirstChild(
			"CooldownUIPosition",
			true
		)

	if not positionPart
		or not positionPart:IsA(
			"BasePart"
		) then

		return
	end

	local existing =
		playerGui:FindFirstChild(
			"ResponsiveSalePopup"
		)

	if existing then
		existing:Destroy()
	end

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name =
		"ResponsiveSalePopup"

	billboard.Adornee = positionPart
	billboard.Size =
		UDim2.fromScale(4.4, 1.25)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(0, 2, 0)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint =
		Vector2.new(0.5, 0.5)

	container.Position =
		UDim2.fromScale(0.5, 0.5)

	container.Size =
		UDim2.fromScale(0.96, 0.88)

	container.BackgroundColor3 =
		Colors.Success

	container.BorderSizePixel = 0
	container.Parent = billboard

	UITheme.AddCorner(
		container,
		0.23
	)

	local stroke = UITheme.AddStroke(
		container,
		Color3.fromRGB(
			120,
			255,
			175
		),
		2,
		0.1
	)

	UITheme.AddGradient(
		container,
		Colors.Success,
		Colors.SuccessDark
	)

	local amountLabel =
		Instance.new("TextLabel")

	amountLabel.Name = "Amount"
	amountLabel.Position =
		UDim2.fromScale(0.05, 0.08)

	amountLabel.Size =
		UDim2.fromScale(0.9, 0.55)

	amountLabel.BackgroundTransparency = 1

	amountLabel.Text =
		string.format(
			"+$%d",
			amount
		)

	amountLabel.TextColor3 =
		Colors.Text

	amountLabel.TextTransparency = 0
	amountLabel.Parent = container

	UITheme.StyleText(
		amountLabel,
		16,
		28,
		Colors.Text,
		Fonts.Black
	)

	local caption =
		Instance.new("TextLabel")

	caption.Name = "Caption"
	caption.Position =
		UDim2.fromScale(0.05, 0.62)

	caption.Size =
		UDim2.fromScale(0.9, 0.22)

	caption.BackgroundTransparency = 1
	caption.Text = "SALE COMPLETE"
	caption.TextColor3 = Colors.Text
	caption.TextTransparency = 0
	caption.Parent = container

	UITheme.StyleText(
		caption,
		9,
		13,
		Colors.Text,
		Fonts.Bold
	)

	local moveTween =
		TweenService:Create(
			billboard,
			TweenInfo.new(
				1,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				StudsOffsetWorldSpace =
					Vector3.new(
						0,
						4.3,
						0
					),
			}
		)

	local amountFade =
		TweenService:Create(
			amountLabel,
			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.7
			),
			{
				TextTransparency = 1,
			}
		)

	local captionFade =
		TweenService:Create(
			caption,
			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.7
			),
			{
				TextTransparency = 1,
			}
		)

	local containerFade =
		TweenService:Create(
			container,
			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.7
			),
			{
				BackgroundTransparency = 1,
			}
		)

	local strokeFade =
		TweenService:Create(
			stroke,
			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				0,
				false,
				0.7
			),
			{
				Transparency = 1,
			}
		)

	moveTween:Play()
	amountFade:Play()
	captionFade:Play()
	containerFade:Play()
	strokeFade:Play()

	Debris:AddItem(
		billboard,
		1.15
	)
end

local function watchPlacedBusinesses(
	folder: Instance
)
	if watchedFolders[folder] then
		return
	end

	watchedFolders[folder] = true

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			createStandUI(child)
		end
	end

	folder.ChildAdded:Connect(function(child)
	if not child:IsA("Model") then
		return
	end

	task.spawn(function()
		createStandUI(child)
	end)
end)

	folder.Destroying:Connect(function()
		watchedFolders[folder] = nil
	end)
end

local function watchPlot(plot: Model)
	local placedBusinesses =
		plot:FindFirstChild("PlacedBusinesses")

	if placedBusinesses then
		watchPlacedBusinesses(
			placedBusinesses
		)

		return
	end

	task.spawn(function()
		local folder =
			plot:WaitForChild(
				"PlacedBusinesses",
				15
			)

		if folder then
			watchPlacedBusinesses(folder)
		end
	end)
end

for _, plot in plotsFolder:GetChildren() do
	if plot:IsA("Model") then
		watchPlot(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		watchPlot(child)
	end
end)

manualSaleResultRemote.OnClientEvent:Connect(
	function(
		stand: Model,
		amount: number
	)
		if typeof(stand) ~= "Instance"
			or not stand:IsA("Model")
			or stand.Name
			~= "LemonadeStand" then

			return
		end

		if typeof(amount) ~= "number" then
			return
		end

		showSalePopup(
			stand,
			math.max(
				0,
				math.floor(amount)
			)
		)
	end
)

RunService.RenderStepped:Connect(function()
	local serverTime =
		Workspace:GetServerTimeNow()

	for stand, state in standStates do
		if not stand.Parent
			or not state.PositionPart.Parent then

			removeStandUI(stand)
			continue
		end

		local unavailable =
			stand:GetAttribute(
				"StandUnavailable"
			) == true

		local beingEdited =
			stand:GetAttribute(
				"IsBeingEdited"
			) == true

		if unavailable or beingEdited then
			state.Billboard.Enabled = false
			continue
		end

		local manualActive =
			stand:GetAttribute(
				"ManualPurchaseActive"
			) == true

		local customerActive =
			stand:GetAttribute(
				"IsServingCustomer"
			) == true

		if not manualActive
			and not customerActive then

			state.Billboard.Enabled = false
			continue
		end

		local startedAt
		local duration
		local statusText

		if manualActive then
			startedAt =
				stand:GetAttribute(
					"ManualPurchaseStartedAt"
				)

			duration =
				stand:GetAttribute(
					"ManualPurchaseDuration"
				)

			statusText =
				"PREPARING LEMONADE"
		else
			startedAt =
				stand:GetAttribute(
					"ServiceStartedAt"
				)

			duration =
				stand:GetAttribute(
					"ServiceDuration"
				)

			statusText =
				"SERVING CUSTOMER"
		end

		if typeof(startedAt) ~= "number"
			or typeof(duration) ~= "number"
			or duration <= 0 then

			state.Billboard.Enabled = false
			continue
		end

		local elapsed =
			math.max(
				0,
				serverTime - startedAt
			)

		local progress =
			math.clamp(
				elapsed / duration,
				0,
				1
			)

		local remaining =
			math.max(
				0,
				duration - elapsed
			)

		state.ProgressFill.Size =
			UDim2.fromScale(
				progress,
				1
			)

		state.TimerLabel.Text =
			string.format(
				"%.1fs",
				remaining
			)

		state.TimerLabel.TextColor3 =
			Colors.Primary

		state.StatusLabel.Text =
			progress >= 1
			and "FINISHING SALE"
			or statusText

		state.StatusLabel.TextColor3 =
			Colors.Text

		state.Billboard.Enabled = true
	end
end)