local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local Workspace =
	game:GetService("Workspace")

local Debris =
	game:GetService("Debris")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local billboardsFolder =
	ReplicatedStorage:WaitForChild("Billboards")

local servingCustomerTemplate =
	billboardsFolder:WaitForChild(
		"ServingCustomer"
	)

if not servingCustomerTemplate:IsA(
	"BillboardGui"
) then
	error(
		"ReplicatedStorage.Billboards.ServingCustomer must be a BillboardGui."
	)
end


local manualSaleResultRemote =
	remotes:WaitForChild(
		"ManualLemonadeSaleResult"
	)


local UITheme = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("UITheme")
)

local Colors =
	UITheme.Colors

local Fonts =
	UITheme.Fonts


local BUSINESS_NAME =
	"LemonadeStand"


type StandUIState = {
	Stand: Model,

	Billboard: BillboardGui,

	TimerLabel: TextLabel,
	StatusLabel: TextLabel,

	ProgressFill: Frame,
	ProgressFullSize: UDim2,

	PositionPart: BasePart,
}


local standStates:
	{[Model]: StandUIState} = {}

local watchedFolders:
	{[Instance]: boolean} = {}


local function isLemonadeStand(
	stand: Instance
): boolean
	if not stand:IsA("Model") then
		return false
	end

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)

	if businessType == BUSINESS_NAME then
		return true
	end

	if stand.Name == BUSINESS_NAME then
		return true
	end

	return string.match(
		stand.Name,
		"^LemonadeStand_"
	) ~= nil
end


local function disableLegacyWorldUI(
	instance: Instance
)
	if not instance:IsA(
		"BillboardGui"
	) then
		return
	end

	if instance.Name
			== "ResponsiveServiceTimer"
		or instance.Name
			== "CashPopup" then

		return
	end

	-- Prevent old timers embedded directly in
	-- stand models from appearing at the same
	-- time as the new replicated template.
	instance.Enabled = false
end


local function getTimerPosition(
	stand: Model,
	waitForReplication: boolean?
): BasePart?

	local function findPosition():
		BasePart?

		local timerPosition =
			stand:FindFirstChild(
				"CooldownUIPosition",
				true
			)

		if timerPosition
			and timerPosition:IsA(
				"BasePart"
			) then

			return timerPosition
		end


		local salePosition =
			stand:FindFirstChild(
				"SaleEffectPosition",
				true
			)

		if salePosition
			and salePosition:IsA(
				"BasePart"
			) then

			return salePosition
		end


		local managementPosition =
			stand:FindFirstChild(
				"ManagementUIPosition",
				true
			)

		if managementPosition
			and managementPosition:IsA(
				"BasePart"
			) then

			return managementPosition
		end


		if stand.PrimaryPart then
			return stand.PrimaryPart
		end

		return nil
	end


	local existing =
		findPosition()

	if existing
		or waitForReplication ~= true then

		return existing
	end


	-- A newly placed/upgraded stand can replicate
	-- before every helper part has arrived.
	local startedAt =
		time()

	while stand.Parent
		and time() - startedAt < 10 do

		local position =
			findPosition()

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


local function getServingTemplateObjects(
	billboard: BillboardGui
): (
	Frame?,
	TextLabel?,
	TextLabel?,
	Frame?,
	Frame?
)
	local frame =
		billboard:FindFirstChild(
			"Frame"
		)

	if not frame
		or not frame:IsA("Frame") then

		return nil,
			nil,
			nil,
			nil,
			nil
	end


	local title =
		frame:FindFirstChild(
			"Title"
		)

	if not title
		or not title:IsA(
			"TextLabel"
		) then

		return nil,
			nil,
			nil,
			nil,
			nil
	end


	local timer =
		frame:FindFirstChild(
			"Time"
		)

	if not timer
		or not timer:IsA(
			"TextLabel"
		) then

		return nil,
			nil,
			nil,
			nil,
			nil
	end


	local background =
		frame:FindFirstChild(
			"Background"
		)

	if not background
		or not background:IsA(
			"Frame"
		) then

		return nil,
			nil,
			nil,
			nil,
			nil
	end


	local bar =
		background:FindFirstChild(
			"Bar"
		)

	if not bar
		or not bar:IsA("Frame") then

		return nil,
			nil,
			nil,
			nil,
			nil
	end


	return frame,
		title,
		timer,
		background,
		bar
end


local function removeStandUI(
	stand: Model
)
	local state =
		standStates[stand]

	if not state then
		return
	end

	if state.Billboard.Parent then
		state.Billboard:Destroy()
	end

	standStates[stand] = nil
end


local function setProgress(
	state: StandUIState,
	progress: number
)
	progress =
		math.clamp(
			progress,
			0,
			1
		)

	local fullSize =
		state.ProgressFullSize

	-- Preserve the exact Y sizing and the intended
	-- maximum X sizing from the Studio template.
	--
	-- This means you can redesign ServingCustomer
	-- without needing to change this script.
	state.ProgressFill.Size =
		UDim2.new(
			fullSize.X.Scale
				* progress,

			math.round(
				fullSize.X.Offset
					* progress
			),

			fullSize.Y.Scale,
			fullSize.Y.Offset
		)
end


local function createStandUI(
	stand: Model
)
	if standStates[stand]
		or not isLemonadeStand(
			stand
		) then

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
		positionPart:GetChildren()
	do
		disableLegacyWorldUI(
			child
		)
	end


	positionPart.ChildAdded:Connect(
		disableLegacyWorldUI
	)


	-- Clone the UI designed in Studio instead of
	-- constructing the service timer in Lua.
	local billboard =
		servingCustomerTemplate:Clone()

	billboard.Name =
		"ResponsiveServiceTimer"

	billboard.Adornee =
		positionPart

	billboard.Enabled =
		false

	billboard.ResetOnSpawn =
		false

	billboard.Parent =
		playerGui


	local frame,
		statusLabel,
		timerLabel,
		background,
		progressFill =
		getServingTemplateObjects(
			billboard
		)


	if not frame
		or not statusLabel
		or not timerLabel
		or not background
		or not progressFill then

		billboard:Destroy()

		warn(
			"ServingCustomer BillboardGui has an invalid hierarchy. "
				.. "Expected Frame.Title, Frame.Time, "
				.. "Frame.Background, and Frame.Background.Bar."
		)

		return
	end


	-- Stop the bar from drawing outside of its
	-- progress-track background.
	background.ClipsDescendants =
		true


	local progressFullSize =
		progressFill.Size


	standStates[stand] = {
		Stand = stand,

		Billboard = billboard,

		TimerLabel = timerLabel,
		StatusLabel = statusLabel,

		ProgressFill = progressFill,
		ProgressFullSize =
			progressFullSize,

		PositionPart =
			positionPart,
	}


	local state =
		standStates[stand]

	setProgress(
		state,
		0
	)


	stand.Destroying:Connect(
		function()
			removeStandUI(
				stand
			)
		end
	)
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
		Instance.new(
			"BillboardGui"
		)

	billboard.Name =
		"ResponsiveSalePopup"

	billboard.Adornee =
		positionPart

	billboard.Size =
		UDim2.fromScale(
			4.4,
			1.25
		)

	billboard.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			2,
			0
		)

	billboard.AlwaysOnTop =
		true

	billboard.LightInfluence =
		0

	billboard.MaxDistance =
		80

	billboard.ResetOnSpawn =
		false

	billboard.Parent =
		playerGui


	local container =
		Instance.new("Frame")

	container.Name =
		"Container"

	container.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	container.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	container.Size =
		UDim2.fromScale(
			0.96,
			0.88
		)

	container.BackgroundColor3 =
		Colors.Success

	container.BorderSizePixel =
		0

	container.Parent =
		billboard


	UITheme.AddCorner(
		container,
		0.23
	)


	local stroke =
		UITheme.AddStroke(
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
		Instance.new(
			"TextLabel"
		)

	amountLabel.Name =
		"Amount"

	amountLabel.Position =
		UDim2.fromScale(
			0.05,
			0.08
		)

	amountLabel.Size =
		UDim2.fromScale(
			0.9,
			0.55
		)

	amountLabel.BackgroundTransparency =
		1

	amountLabel.Text =
		string.format(
			"+$%d",
			amount
		)

	amountLabel.TextColor3 =
		Colors.Text

	amountLabel.TextTransparency =
		0

	amountLabel.Parent =
		container


	UITheme.StyleText(
		amountLabel,
		16,
		28,
		Colors.Text,
		Fonts.Black
	)


	local caption =
		Instance.new(
			"TextLabel"
		)

	caption.Name =
		"Caption"

	caption.Position =
		UDim2.fromScale(
			0.05,
			0.62
		)

	caption.Size =
		UDim2.fromScale(
			0.9,
			0.22
		)

	caption.BackgroundTransparency =
		1

	caption.Text =
		"SALE COMPLETE"

	caption.TextColor3 =
		Colors.Text

	caption.TextTransparency =
		0

	caption.Parent =
		container


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
				BackgroundTransparency =
					1,
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

	watchedFolders[folder] =
		true


	for _, child in
		folder:GetChildren()
	do
		if child:IsA("Model") then
			task.spawn(
				createStandUI,
				child
			)
		end
	end


	folder.ChildAdded:Connect(
		function(
			child: Instance
		)
			if not child:IsA(
				"Model"
			) then

				return
			end

			task.spawn(
				createStandUI,
				child
			)
		end
	)


	folder.Destroying:Connect(
		function()
			watchedFolders[folder] =
				nil
		end
	)
end


local function watchPlot(
	plot: Model
)
	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if placedBusinesses then
		watchPlacedBusinesses(
			placedBusinesses
		)

		return
	end


	task.spawn(
		function()
			local folder =
				plot:WaitForChild(
					"PlacedBusinesses",
					15
				)

			if folder then
				watchPlacedBusinesses(
					folder
				)
			end
		end
	)
end


for _, plot in
	plotsFolder:GetChildren()
do
	if plot:IsA("Model") then
		watchPlot(
			plot
		)
	end
end


plotsFolder.ChildAdded:Connect(
	function(
		child: Instance
	)
		if child:IsA("Model") then
			watchPlot(
				child
			)
		end
	end
)


manualSaleResultRemote.OnClientEvent:Connect(
	function(
		stand: Model,
		amount: number
	)
		if typeof(stand) ~= "Instance"
			or not stand:IsA(
				"Model"
			)
			or not isLemonadeStand(
				stand
			) then

			return
		end


		if typeof(amount)
			~= "number" then

			return
		end


		showSalePopup(
			stand,

			math.max(
				0,
				math.floor(
					amount
				)
			)
		)
	end
)


RunService.RenderStepped:Connect(
	function()
		local serverTime =
			Workspace:GetServerTimeNow()


		for stand, state in
			standStates
		do
			if not stand.Parent
				or not state.PositionPart.Parent then

				removeStandUI(
					stand
				)

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


			if unavailable
				or beingEdited then

				state.Billboard.Enabled =
					false

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

				state.Billboard.Enabled =
					false

				continue
			end


			local startedAt:
				number?

			local duration:
				number?

			local statusText:
				string


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
					"Preparing Lemonade"
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
					"Serving Customer"
			end


			if typeof(startedAt)
					~= "number"
				or typeof(duration)
					~= "number"
				or duration <= 0 then

				state.Billboard.Enabled =
					false

				continue
			end


			local elapsed =
				math.max(
					0,
					serverTime
						- startedAt
				)


			local progress =
				math.clamp(
					elapsed
						/ duration,

					0,
					1
				)


			local remaining =
				math.max(
					0,
					duration
						- elapsed
				)


			setProgress(
				state,
				progress
			)


			state.TimerLabel.Text =
				string.format(
					"%.1fs",
					remaining
				)


			if progress >= 1 then
				state.StatusLabel.Text =
					"Finishing Sale"
			else
				state.StatusLabel.Text =
					statusText
			end


			state.Billboard.Enabled =
				true
		end
	end
)