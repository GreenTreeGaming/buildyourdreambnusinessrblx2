task.wait(3)


local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)


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
	) :: RemoteFunction


local purchaseMarketingRemote =
	remotes:WaitForChild(
		"PurchaseMarketingRequest"
	) :: RemoteFunction


local getPlotStateRemote =
	remotes:WaitForChild(
		"GetPlotExpansionState"
	) :: RemoteFunction


local purchasePlotRemote =
	remotes:WaitForChild(
		"PurchasePlotExpansion"
	) :: RemoteFunction


local getReputationStateRemote =
	remotes:WaitForChild(
		"GetReputationState"
	) :: RemoteFunction


type MarketingState = {
	Success: boolean,
	Message: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,

	CustomerLimit: number?,
	MinimumSpawnInterval: number?,
	MaximumSpawnInterval: number?,
}


type PlotState = {
	Success: boolean,
	Message: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	DisplayName: string?,
	Description: string?,

	CurrentSize: number?,
	NextSize: number?,
}


type ReputationState = {
	Success: boolean,
	Message: string?,

	Rating: number?,
	ReputationLevel: number?,

	CurrentProgress: number?,
	RequiredProgress: number?,

	CustomerRateBonus: number?,

	RecentReview: string?,

	NextUnlockTitle: string?,
	NextUnlockSubtitle: string?,
}


type PanelRefs = {
	Root: Frame,

	Buy: TextButton,
	BuyText: TextLabel,

	StatOneTitle: TextLabel,
	StatOneSubtitle: TextLabel,

	StatTwoTitle: TextLabel,
	StatTwoSubtitle: TextLabel,

	Level: TextLabel,
	Name: TextLabel,
	Description: TextLabel,

	ProgressTitle: TextLabel,
	ProgressSubtitle: TextLabel,
	ProgressBar: Frame,
}


type ReputationRefs = {
	Root: Frame,

	Rating: TextLabel,

	Stars: {
		ImageLabel
	},

	Review: TextLabel,

	CurrentBenefitsTitle: TextLabel,
	CurrentBenefitsSubtitle: TextLabel,

	NextUnlockTitle: TextLabel,
	NextUnlockSubtitle: TextLabel,

	ProgressTitle: TextLabel,
	ProgressSubtitle: TextLabel,
	ProgressBar: Frame,
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


local mainTitle =
	main:WaitForChild(
		"Title"
	) :: TextLabel


local mainSubtitle =
	main:WaitForChild(
		"Subtitle"
	) :: TextLabel


local marketingButton =
	main:WaitForChild(
		"MarketingButton"
	) :: TextButton


local plotButton =
	main:WaitForChild(
		"PlotButton"
	) :: TextButton


local reputationButton =
	main:WaitForChild(
		"ReputationButton"
	) :: TextButton


local marketingButtonText =
	marketingButton:WaitForChild(
		"InText"
	) :: TextLabel


local plotButtonText =
	plotButton:WaitForChild(
		"InText"
	) :: TextLabel


local reputationButtonText =
	reputationButton:WaitForChild(
		"InText"
	) :: TextLabel


local marketingFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame


local plotFrame =
	main:WaitForChild(
		"PlotFrame"
	) :: Frame


local reputationFrame =
	main:WaitForChild(
		"ReputationFrame"
	) :: Frame


main.ClipsDescendants =
	false


local function setPageZIndex(
	page: Frame,
	baseZIndex: number
)

	page.ZIndex =
		baseZIndex


	for _, descendant in
		page:GetDescendants() do

		if descendant:IsA(
			"GuiObject"
		) then

			descendant.ZIndex =
				baseZIndex
		end
	end
end


setPageZIndex(
	marketingFrame,
	1
)

setPageZIndex(
	plotFrame,
	1
)

setPageZIndex(
	reputationFrame,
	1
)


marketingButton.ZIndex = 10
plotButton.ZIndex = 10
reputationButton.ZIndex = 10

marketingButtonText.ZIndex = 11
plotButtonText.ZIndex = 11
reputationButtonText.ZIndex = 11

closeButton.ZIndex = 20


local closeX =
	closeButton:FindFirstChild(
		"X"
	)


if closeX
	and closeX:IsA("GuiObject") then

	closeX.ZIndex = 21
	closeX.Active = false
end


marketingButton.Active = true
marketingButton.Selectable = true

plotButton.Active = true
plotButton.Selectable = true

reputationButton.Active = true
reputationButton.Selectable = true

closeButton.Active = true
closeButton.Selectable = true


marketingButtonText.Active = false
plotButtonText.Active = false
reputationButtonText.Active = false


local function getPanel(
	root: Frame
): PanelRefs

	local buy =
		root:WaitForChild(
			"Buy"
		) :: TextButton


	buy.Text = ""


	local buyText =
		buy:WaitForChild(
			"InText"
		) :: TextLabel


	buyText.Active = false
	buyText.Selectable = false


	local customerLimit =
		root:WaitForChild(
			"CustomerLimit"
		) :: Frame


	local spawnTime =
		root:WaitForChild(
			"SpawnTime"
		) :: Frame


	local levels =
		root:WaitForChild(
			"Levels"
		) :: Frame


	local progress =
		root:WaitForChild(
			"Progress"
		) :: Frame


	local progressBackground =
		progress:WaitForChild(
			"Background"
		) :: Frame


	return {
		Root = root,

		Buy = buy,
		BuyText = buyText,

		StatOneTitle =
			customerLimit:WaitForChild(
				"Title"
			) :: TextLabel,

		StatOneSubtitle =
			customerLimit:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		StatTwoTitle =
			spawnTime:WaitForChild(
				"Title"
			) :: TextLabel,

		StatTwoSubtitle =
			spawnTime:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		Level =
			levels:WaitForChild(
				"Level"
			) :: TextLabel,

		Name =
			levels:WaitForChild(
				"Title"
			) :: TextLabel,

		Description =
			levels:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		ProgressTitle =
			progress:WaitForChild(
				"Title"
			) :: TextLabel,

		ProgressSubtitle =
			progress:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		ProgressBar =
			progressBackground:WaitForChild(
				"Bar"
			) :: Frame,
	}
end


local function getReputationPanel(
	root: Frame
): ReputationRefs

	local starsPanel =
		root:WaitForChild(
			"Stars"
		) :: Frame


	local starsFrame =
		starsPanel:WaitForChild(
			"Frame"
		) :: Frame


	local stars = {}


	for index = 1, 5 do

		stars[index] =
			starsFrame:WaitForChild(
				`Star{index}`
			) :: ImageLabel
	end


	local recentReviews =
		root:WaitForChild(
			"RecentReviews"
		) :: Frame


	local currentBenefits =
		root:WaitForChild(
			"CurrentBenefits"
		) :: Frame


	local nextUnlock =
		root:WaitForChild(
			"NextUnlock"
		) :: Frame


	local progress =
		root:WaitForChild(
			"Progress"
		) :: Frame


	local progressBackground =
		progress:WaitForChild(
			"Background"
		) :: Frame


	return {
		Root = root,

		Rating =
			starsPanel:WaitForChild(
				"Rating"
			) :: TextLabel,

		Stars = stars,

		Review =
			recentReviews:WaitForChild(
				"Reviews"
			) :: TextLabel,

		CurrentBenefitsTitle =
			currentBenefits:WaitForChild(
				"Title"
			) :: TextLabel,

		CurrentBenefitsSubtitle =
			currentBenefits:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		NextUnlockTitle =
			nextUnlock:WaitForChild(
				"Title"
			) :: TextLabel,

		NextUnlockSubtitle =
			nextUnlock:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		ProgressTitle =
			progress:WaitForChild(
				"Title"
			) :: TextLabel,

		ProgressSubtitle =
			progress:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		ProgressBar =
			progressBackground:WaitForChild(
				"Bar"
			) :: Frame,
	}
end


local marketingPanel =
	getPanel(
		marketingFrame
	)


local plotPanel =
	getPanel(
		plotFrame
	)


local reputationPanel =
	getReputationPanel(
		reputationFrame
	)


local currentTab =
	"Marketing"


local menuOpen =
	false


local marketingPending =
	false


local plotPending =
	false


local reputationPending =
	false


local marketingRequestId =
	0


local plotRequestId =
	0


local currentMarketingState:
	MarketingState? =
	nil


local currentPlotState:
	PlotState? =
	nil


local mainScale =
	main:FindFirstChildOfClass(
		"UIScale"
	)


if not mainScale then

	mainScale =
		Instance.new(
			"UIScale"
		)


	mainScale.Name =
		"MenuScale"


	mainScale.Scale =
		1


	mainScale.Parent =
		main
end


local activeMenuTween:
	Tween? =
	nil


local function formatCurrency(
	value: number
): string

	return FormatNumber.Compact(
		math.floor(value)
	)
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


local function setButtonEnabled(
	panel: PanelRefs,
	enabled: boolean
)

	panel.Buy.Active =
		enabled


	panel.Buy.Selectable =
		enabled


	panel.Buy.AutoButtonColor =
		enabled


	panel.Buy.BackgroundTransparency =
		enabled
			and 0
			or 0.35
end


local function tweenProgressBar(
	bar: Frame,
	progress: number
)

	progress =
		math.clamp(
			progress,
			0,
			1
		)


	TweenService:Create(
		bar,

		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			Size =
				UDim2.new(
					progress,
					0,

					bar.Size.Y.Scale,
					bar.Size.Y.Offset
				),
		}
	):Play()
end


local function setProgress(
	panel: PanelRefs,
	currentLevel: number,
	maximumLevel: number
)

	local progress = 0


	if maximumLevel > 0 then

		progress =
			currentLevel
				/ maximumLevel
	end


	tweenProgressBar(
		panel.ProgressBar,
		progress
	)
end


local function updateMarketingInterface(
	state: MarketingState
)

	currentMarketingState =
		state


	local currentLevel =
		typeof(state.CurrentLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.CurrentLevel
				)
			)
			or 0


	local maximumLevel =
		typeof(state.MaximumLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.MaximumLevel
				)
			)
			or 0


	marketingPanel.Level.Text =
		`Level {currentLevel}/{maximumLevel}`


	marketingPanel.Name.Text =
		state.DisplayName
		or "Marketing"


	marketingPanel.Description.Text =
		state.Description
		or "Bring more customers to your businesses."


	marketingPanel.StatOneTitle.Text =
		"Customer Limit"


	marketingPanel.StatOneSubtitle.Text =
		typeof(state.CustomerLimit)
				== "number"
			and FormatNumber.Compact(
				state.CustomerLimit
			)
			or "--"


	marketingPanel.StatTwoTitle.Text =
		"Spawn Time"


	marketingPanel.StatTwoSubtitle.Text =
		formatSpawnTime(
			state.MinimumSpawnInterval,
			state.MaximumSpawnInterval
		)


	marketingPanel.ProgressTitle.Text =
		"Marketing Progress"


	marketingPanel.ProgressSubtitle.Text =
		`{currentLevel}/{maximumLevel}`


	setProgress(
		marketingPanel,
		currentLevel,
		maximumLevel
	)


	if maximumLevel > 0
		and currentLevel >= maximumLevel then

		marketingPanel.BuyText.Text =
			"Max Marketing Level"


		setButtonEnabled(
			marketingPanel,
			false
		)


		return
	end


	if typeof(state.NextCost)
		== "number" then

		marketingPanel.BuyText.Text =
			`Upgrade Marketing - ${formatCurrency(state.NextCost)}`


		setButtonEnabled(
			marketingPanel,
			not marketingPending
		)

	else

		marketingPanel.BuyText.Text =
			"Upgrade Unavailable"


		setButtonEnabled(
			marketingPanel,
			false
		)
	end
end


local function updatePlotInterface(
	state: PlotState
)

	currentPlotState =
		state


	local currentLevel =
		typeof(state.CurrentLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.CurrentLevel
				)
			)
			or 0


	local maximumLevel =
		typeof(state.MaximumLevel)
				== "number"
			and math.max(
				0,
				math.floor(
					state.MaximumLevel
				)
			)
			or 0


	plotPanel.Level.Text =
		`Level {currentLevel}/{maximumLevel}`


	plotPanel.Name.Text =
		state.DisplayName
		or "Business Plot"


	plotPanel.Description.Text =
		state.Description
		or "Expand your business property."


	plotPanel.StatOneTitle.Text =
		"Current Size"


	if typeof(state.CurrentSize)
		== "number" then

		plotPanel.StatOneSubtitle.Text =
			`{state.CurrentSize} x {state.CurrentSize}`

	else

		plotPanel.StatOneSubtitle.Text =
			"--"
	end


	plotPanel.StatTwoTitle.Text =
		"Next Size"


	if typeof(state.NextSize)
		== "number" then

		plotPanel.StatTwoSubtitle.Text =
			`{state.NextSize} x {state.NextSize}`

	else

		plotPanel.StatTwoSubtitle.Text =
			"MAX"
	end


	plotPanel.ProgressTitle.Text =
		"Plot Progress"


	plotPanel.ProgressSubtitle.Text =
		`{currentLevel}/{maximumLevel}`


	setProgress(
		plotPanel,
		currentLevel,
		maximumLevel
	)


	if maximumLevel > 0
		and currentLevel >= maximumLevel then

		plotPanel.BuyText.Text =
			"Maximum Plot Size"


		setButtonEnabled(
			plotPanel,
			false
		)


		return
	end


	if typeof(state.NextCost)
		== "number" then

		plotPanel.BuyText.Text =
			`Expand Plot - ${formatCurrency(state.NextCost)}`


		setButtonEnabled(
			plotPanel,
			not plotPending
		)

	else

		plotPanel.BuyText.Text =
			"Expansion Unavailable"


		setButtonEnabled(
			plotPanel,
			false
		)
	end
end


local function setStars(
	rating: number
)

	local roundedStars =
		math.clamp(
			math.floor(
				rating + 0.5
			),

			0,
			5
		)


	for index, star in
		reputationPanel.Stars do

		local filled =
			index <= roundedStars


		TweenService:Create(
			star,

			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				ImageColor3 =
					filled
						and Color3.fromRGB(
							255,
							255,
							255
						)
						or Color3.fromRGB(
							95,
							95,
							95
						),

				ImageTransparency =
					filled
						and 0
						or 0.35,
			}
		):Play()
	end
end


local function updateReputationInterface(
	state: ReputationState
)

	local rating =
		typeof(state.Rating)
				== "number"
			and math.clamp(
				state.Rating,
				0,
				5
			)
			or 0


	local reputationLevel =
		typeof(state.ReputationLevel)
				== "number"
			and math.max(
				1,
				math.floor(
					state.ReputationLevel
				)
			)
			or 1


	local currentProgress =
		typeof(state.CurrentProgress)
				== "number"
			and math.max(
				0,
				state.CurrentProgress
			)
			or 0


	local requiredProgress =
		typeof(state.RequiredProgress)
				== "number"
			and math.max(
				1,
				state.RequiredProgress
			)
			or 1


	local customerRateBonus =
		typeof(state.CustomerRateBonus)
				== "number"
			and math.max(
				0,
				state.CustomerRateBonus
			)
			or 0


	reputationPanel.Rating.Text =
		string.format(
			"%.1f",
			rating
		)


	setStars(
		rating
	)


	reputationPanel.Review.Text =
		state.RecentReview
		or "No recent reviews yet."


	reputationPanel.CurrentBenefitsTitle.Text =
		"Current Benefits"


	reputationPanel.CurrentBenefitsSubtitle.Text =
		`+{math.round(customerRateBonus * 100)}% Customers`


	reputationPanel.NextUnlockTitle.Text =
		state.NextUnlockTitle
		or "Next Unlock"


	reputationPanel.NextUnlockSubtitle.Text =
		state.NextUnlockSubtitle
		or "--"


	reputationPanel.ProgressTitle.Text =
		"Reputation Level"


	reputationPanel.ProgressSubtitle.Text =
		`Level {reputationLevel}  •  {math.floor(currentProgress)}/{math.floor(requiredProgress)}`


	tweenProgressBar(
		reputationPanel.ProgressBar,

		currentProgress
			/ requiredProgress
	)
end


local function requestMarketingState()

	if marketingPending then
		return
	end


	marketingPending = true


	marketingPanel.BuyText.Text =
		"Loading..."


	setButtonEnabled(
		marketingPanel,
		false
	)


	task.spawn(
		function()

			local success,
				result =
				pcall(
					function()

						return getMarketingStateRemote
							:InvokeServer()
					end
				)


			marketingPending = false


			if not success
				or type(result) ~= "table" then

				marketingPanel.BuyText.Text =
					"Try Again"


				setButtonEnabled(
					marketingPanel,
					true
				)


				warn(
					"[ManageUI] Failed to load marketing state."
				)


				return
			end


			updateMarketingInterface(
				result :: MarketingState
			)
		end
	)
end


local function requestPlotState()

	if plotPending then
		return
	end


	plotPending = true


	plotPanel.BuyText.Text =
		"Loading..."


	setButtonEnabled(
		plotPanel,
		false
	)


	task.spawn(
		function()

			local success,
				result =
				pcall(
					function()

						return getPlotStateRemote
							:InvokeServer()
					end
				)


			plotPending = false


			if not success
				or type(result) ~= "table" then

				plotPanel.BuyText.Text =
					"Try Again"


				setButtonEnabled(
					plotPanel,
					true
				)


				warn(
					"[ManageUI] Failed to load plot state."
				)


				return
			end


			updatePlotInterface(
				result :: PlotState
			)
		end
	)
end


local function requestReputationState()

	if reputationPending then
		return
	end


	reputationPending = true


	reputationPanel.Rating.Text =
		"..."


	task.spawn(
		function()

			local success,
				result =
				pcall(
					function()

						return getReputationStateRemote
							:InvokeServer()
					end
				)


			reputationPending = false


			if not success
				or type(result) ~= "table"
				or result.Success ~= true then

				reputationPanel.Rating.Text =
					"--"


				warn(
					"[ManageUI] Failed to load reputation state."
				)


				return
			end


			updateReputationInterface(
				result :: ReputationState
			)
		end
	)
end


local function showTab(
	tabName: string
)

	if tabName ~= "Marketing"
		and tabName ~= "Plot"
		and tabName ~= "Reputation" then

		return
	end


	currentTab =
		tabName


	marketingFrame.Visible =
		tabName == "Marketing"


	plotFrame.Visible =
		tabName == "Plot"


	reputationFrame.Visible =
		tabName == "Reputation"


	marketingButton.BackgroundTransparency =
		tabName == "Marketing"
			and 0
			or 0.2


	plotButton.BackgroundTransparency =
		tabName == "Plot"
			and 0
			or 0.2


	reputationButton.BackgroundTransparency =
		tabName == "Reputation"
			and 0
			or 0.2


	if tabName == "Marketing" then

		mainTitle.Text =
			"Manage - Marketing"


		mainSubtitle.Text =
			"Bring more customers to your business!"


		requestMarketingState()


	elseif tabName == "Plot" then

		mainTitle.Text =
			"Manage - Plot"


		mainSubtitle.Text =
			"Expand your land and grow your business!"


		requestPlotState()


	else

		mainTitle.Text =
			"Manage - Reputation"


		mainSubtitle.Text =
			"Keep customers happy and grow your reputation!"


		requestReputationState()
	end
end


local function stopMenuTween()

	if activeMenuTween then

		activeMenuTween:Cancel()

		activeMenuTween =
			nil
	end
end


local function openMenu()

	if menuOpen then
		return
	end


	menuOpen = true


	stopMenuTween()


	main.Visible =
		true


	-- Keep the side Manage button visible.
	openButton.Visible =
		true


	mainScale.Scale =
		0.92


	local tween =
		TweenService:Create(
			mainScale,

			TweenInfo.new(
				0.2,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Scale = 1,
			}
		)


	activeMenuTween =
		tween


	tween.Completed:Once(
		function()

			if activeMenuTween == tween then
				activeMenuTween =
					nil
			end
		end
	)


	tween:Play()


	showTab(
		currentTab
	)
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
				0.13,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale = 0.92,
			}
		)


	activeMenuTween =
		tween


	tween.Completed:Once(
		function()

			if activeMenuTween ~= tween then
				return
			end


			activeMenuTween =
				nil


			if not menuOpen then

				main.Visible =
					false


				mainScale.Scale =
					1
			end
		end
	)


	tween:Play()
end


marketingPanel.Buy.Activated:Connect(
	function()

		if marketingPending then
			return
		end


		local state =
			currentMarketingState


		if not state
			or typeof(state.NextCost)
				~= "number" then

			requestMarketingState()

			return
		end


		marketingPending =
			true


		marketingRequestId += 1


		local requestId =
			marketingRequestId


		marketingPanel.BuyText.Text =
			"Purchasing..."


		setButtonEnabled(
			marketingPanel,
			false
		)


		task.spawn(
			function()

				local success,
					result =
					pcall(
						function()

							return purchaseMarketingRemote
								:InvokeServer()
						end
					)


				if requestId
					~= marketingRequestId then

					return
				end


				marketingPending =
					false


				if not success
					or type(result)
						~= "table" then

					marketingPanel.BuyText.Text =
						"Try Again"


					setButtonEnabled(
						marketingPanel,
						true
					)


					return
				end


				if result.Success then

					updateMarketingInterface(
						result
					)

				else

					requestMarketingState()
				end
			end
		)
	end
)


plotPanel.Buy.Activated:Connect(
	function()

		if plotPending then
			return
		end


		local state =
			currentPlotState


		if not state
			or typeof(state.NextCost)
				~= "number" then

			requestPlotState()

			return
		end


		plotPending =
			true


		plotRequestId += 1


		local requestId =
			plotRequestId


		plotPanel.BuyText.Text =
			"Expanding..."


		setButtonEnabled(
			plotPanel,
			false
		)


		task.spawn(
			function()

				local success,
					result =
					pcall(
						function()

							return purchasePlotRemote
								:InvokeServer()
						end
					)


				if requestId
					~= plotRequestId then

					return
				end


				plotPending =
					false


				if not success
					or type(result)
						~= "table" then

					plotPanel.BuyText.Text =
						"Try Again"


					setButtonEnabled(
						plotPanel,
						true
					)


					return
				end


				if result.Success then

					updatePlotInterface(
						result
					)

				else

					requestPlotState()
				end
			end
		)
	end
)


marketingButton.Activated:Connect(
	function()

		showTab(
			"Marketing"
		)
	end
)


plotButton.Activated:Connect(
	function()

		showTab(
			"Plot"
		)
	end
)


reputationButton.Activated:Connect(
	function()

		showTab(
			"Reputation"
		)
	end
)


openButton.Activated:Connect(
	openMenu
)


closeButton.Activated:Connect(
	closeMenu
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


		if input.KeyCode
				== Enum.KeyCode.Escape
			or input.KeyCode
				== Enum.KeyCode.ButtonB then

			closeMenu()
		end
	end
)


player:GetAttributeChangedSignal(
	"DataLoaded"
):Connect(
	function()

		if player:GetAttribute(
			"DataLoaded"
		) ~= true
			or not menuOpen then

			return
		end


		showTab(
			currentTab
		)
	end
)


-- Refresh reputation while that page is open so
-- sales and upgrades visibly update without reopening it.
task.spawn(
	function()

		while true do

			task.wait(3)


			if menuOpen
				and currentTab
					== "Reputation" then

				requestReputationState()
			end
		end
	end
)


marketingButtonText.Text =
	"Marketing"


plotButtonText.Text =
	"Plot"


reputationButtonText.Text =
	"Reputation"


marketingPanel.ProgressBar.Size =
	UDim2.new(
		0,
		0,

		marketingPanel.ProgressBar.Size.Y.Scale,
		marketingPanel.ProgressBar.Size.Y.Offset
	)


plotPanel.ProgressBar.Size =
	UDim2.new(
		0,
		0,

		plotPanel.ProgressBar.Size.Y.Scale,
		plotPanel.ProgressBar.Size.Y.Offset
	)


reputationPanel.ProgressBar.Size =
	UDim2.new(
		0,
		0,

		reputationPanel.ProgressBar.Size.Y.Scale,
		reputationPanel.ProgressBar.Size.Y.Offset
	)


currentTab =
	"Marketing"


marketingFrame.Visible =
	true


plotFrame.Visible =
	false


reputationFrame.Visible =
	false


mainTitle.Text =
	"Manage - Marketing"


mainSubtitle.Text =
	"Bring more customers to your business!"


main.Visible =
	false


openButton.Visible =
	true