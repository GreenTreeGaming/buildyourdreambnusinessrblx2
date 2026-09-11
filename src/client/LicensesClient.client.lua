local Players =
	game:GetService(
		"Players"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local TweenService =
	game:GetService(
		"TweenService"
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local LicenseConfig =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"LicenseConfig"
			)
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getLicenseStateRemote =
	remotes:WaitForChild(
		"GetLicenseState"
	) :: RemoteFunction


local purchaseLicenseUpgradeRemote =
	remotes:WaitForChild(
		"PurchaseLicenseUpgrade"
	) :: RemoteFunction


local licenseStateUpdatedRemote =
	remotes:WaitForChild(
		"LicenseStateUpdated"
	) :: RemoteEvent


--==================================================
-- UI
--==================================================

local gui =
	playerGui:WaitForChild(
		"LicensesUI"
	) :: ScreenGui


local openButton =
	gui:WaitForChild(
		"OpenButton"
	) :: GuiButton


local main =
	gui:WaitForChild(
		"Main"
	) :: Frame


local closeButton =
	main:WaitForChild(
		"Close"
	) :: GuiButton


local contentFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame


local buttonsFrame =
	contentFrame:WaitForChild(
		"Buttons"
	) :: Frame


local howToEarnButton =
	buttonsFrame:WaitForChild(
		"HowToEarn"
	) :: GuiButton


local upgradesButton =
	buttonsFrame:WaitForChild(
		"Upgrades"
	) :: GuiButton


local howToEarnFrame =
	contentFrame:WaitForChild(
		"HowToEarnFrame"
	) :: ScrollingFrame


local upgradesFrame =
	contentFrame:WaitForChild(
		"UpgradesFrame"
	) :: Frame


local earnTemplate =
	howToEarnFrame:WaitForChild(
		"Template"
	) :: Frame


local upgradeTemplate =
	upgradesFrame:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- CONFIG
--==================================================

local MENU_TWEEN_TIME =
	0.22


local OPEN_START_SCALE =
	0.92


--==================================================
-- SETUP
--==================================================

earnTemplate.Visible =
	false

upgradeTemplate.Visible =
	false

howToEarnFrame.Visible =
	false

upgradesFrame.Visible =
	false

main.Visible =
	false


local menuScale =
	main:FindFirstChild(
		"LicensesMenuScale"
	)


if not menuScale then

	menuScale =
		Instance.new(
			"UIScale"
		)


	menuScale.Name =
		"LicensesMenuScale"


	menuScale.Scale =
		1


	menuScale.Parent =
		main
end


menuScale =
	menuScale :: UIScale


--==================================================
-- STATE
--==================================================

local currentState: any =
	nil


local currentTab =
	"HowToEarn"


local menuTween:
	Tween? =
	nil


local purchaseBusy =
	false


--==================================================
-- GENERAL HELPERS
--==================================================

local function clearGenerated(
	parent: Instance
)

	for _, child in
		parent:GetChildren()
	do

		if child:GetAttribute(
			"GeneratedLicenseItem"
		) == true then

			child:Destroy()
		end
	end
end


local function clampProgress(
	progress: number,
	goal: number
): number

	if goal <= 0 then
		return 0
	end


	return math.clamp(
		progress / goal,
		0,
		1
	)
end


--==================================================
-- TABS
--==================================================

local function showTab(
	tabName: string
)

	currentTab =
		tabName


	-- Always close BOTH first.
	howToEarnFrame.Visible =
		false

	upgradesFrame.Visible =
		false


	-- Then open only the selected tab.
	if tabName
		== "Upgrades" then

		upgradesFrame.Visible =
			true

	else

		howToEarnFrame.Visible =
			true
	end
end


--==================================================
-- EARN ITEMS
--==================================================

local function createEarnItem(
	definition: any,
	state: any
)

	local clone =
		earnTemplate:Clone()


	clone.Name =
		definition.Id


	clone:SetAttribute(
		"GeneratedLicenseItem",
		true
	)


	clone.LayoutOrder =
		definition.Order
		or 0


	local earnName =
		clone:WaitForChild(
			"EarnName"
		) :: TextLabel


	local earnDesc =
		clone:WaitForChild(
			"EarnDesc"
		) :: TextLabel


	local rewardFrame =
		clone:WaitForChild(
			"Reward"
		) :: Frame


	local rewardAmount =
		rewardFrame:WaitForChild(
			"Amount"
		) :: TextLabel


	local background =
		clone:WaitForChild(
			"Background"
		) :: Frame


	local bar =
		background:WaitForChild(
			"Bar"
		) :: Frame


	local percentCompleted =
		background:WaitForChild(
			"PercentCompleted"
		) :: TextLabel


	earnName.Text =
		definition.DisplayName


	earnDesc.Text =
		definition.Description


	rewardAmount.Text =
		`+{definition.Reward}`


	local progress =
		state
		and state.Progress
		or 0


	local goal =
		state
		and state.Goal
		or definition.Goal


	progress =
		math.max(
			0,
			math.floor(
				progress
			)
		)


	goal =
		math.max(
			1,
			math.floor(
				goal
			)
		)


	local alpha =
		clampProgress(
			progress,
			goal
		)


	-- ONLY the actual progress bar is resized.
	-- The Template itself is never resized.
	bar.Size =
		UDim2.new(
			alpha,
			0,

			bar.Size.Y.Scale,
			bar.Size.Y.Offset
		)


	if state
		and state.Claimed
			== true then

		percentCompleted.Text =
			"COMPLETED"

	elseif definition.Repeatable
		== true then

		percentCompleted.Text =
			`{progress}/{goal}`

	else

		percentCompleted.Text =
			`{math.min(progress, goal)}/{goal}`
	end


	clone.Visible =
		true


	clone.Parent =
		howToEarnFrame
end


local function renderEarnMethods()

	clearGenerated(
		howToEarnFrame
	)


	if not currentState then
		return
	end


	for _, definition in
		LicenseConfig.EarnMethods do

		local state =
			currentState.EarnMethods
			and currentState
				.EarnMethods[
					definition.Id
				]


		createEarnItem(
			definition,
			state
		)
	end
end


--==================================================
-- UPGRADE ITEMS
--==================================================

local function createUpgradeItem(
	definition: any,
	state: any
)

	local clone =
		upgradeTemplate:Clone()


	clone.Name =
		definition.Id


	clone:SetAttribute(
		"GeneratedLicenseItem",
		true
	)


	clone.LayoutOrder =
		definition.Order
		or 0


	local buyButton =
		clone:WaitForChild(
			"Buy"
		) :: GuiButton


	local upgradeName =
		clone:WaitForChild(
			"UpgradeName"
		) :: TextLabel


	local upgradeDesc =
		clone:WaitForChild(
			"UpgradeDesc"
		) :: TextLabel


	local levelLabel =
		clone:WaitForChild(
			"Level"
		) :: TextLabel


	local level =
		state
		and state.Level
		or 0


	local maxLevel =
		state
		and state.MaxLevel
		or #definition.Costs


	local maxed =
		level >= maxLevel


	local nextCost =
		state
		and state.NextCost
		or LicenseConfig.GetNextCost(
			definition.Id,
			level
		)


	upgradeName.Text =
		definition.DisplayName


	upgradeDesc.Text =
		definition.Description


	levelLabel.Text =
		`LVL. {level}`


	if maxed then

		buyButton.Text =
			"MAXED"


		buyButton.Active =
			false


		buyButton.AutoButtonColor =
			false

	else

		buyButton.Text =
			`BUY - {nextCost}`


		buyButton.Active =
			true


		buyButton.AutoButtonColor =
			true


		local upgradeId =
			definition.Id


		buyButton.Activated:Connect(
			function()

				if purchaseBusy then
					return
				end


				purchaseBusy =
					true


				buyButton.Active =
					false


				local success,
					purchased,
					_message,
					newState =
					pcall(
						function()

							return purchaseLicenseUpgradeRemote
								:InvokeServer(
									upgradeId
								)
						end
					)


				purchaseBusy =
					false


				if success
					and purchased
					and type(newState)
						== "table" then

					currentState =
						newState


					renderEarnMethods()


					-- Entire upgrade list is rebuilt
					-- so all costs/levels stay accurate.
					task.defer(
						function()

							clearGenerated(
								upgradesFrame
							)


							for _, upgradeDefinition in
								LicenseConfig.Upgrades do

								local upgradeState =
									currentState.Upgrades
									and currentState
										.Upgrades[
											upgradeDefinition.Id
										]


								createUpgradeItem(
									upgradeDefinition,
									upgradeState
								)
							end
						end
					)

				else

					buyButton.Active =
						true
				end
			end
		)
	end


	clone.Visible =
		true


	clone.Parent =
		upgradesFrame
end


local function renderUpgrades()

	clearGenerated(
		upgradesFrame
	)


	if not currentState then
		return
	end


	local definitions =
		{}


	for _, definition in
		LicenseConfig.Upgrades do

		table.insert(
			definitions,
			definition
		)
	end


	table.sort(
		definitions,
		function(
			a,
			b
		)

			return (
				a.Order
				or 0
			)
				< (
					b.Order
					or 0
				)
		end
	)


	for _, definition in
		definitions do

		local state =
			currentState.Upgrades
			and currentState
				.Upgrades[
					definition.Id
				]


		createUpgradeItem(
			definition,
			state
		)
	end
end


--==================================================
-- RENDER
--==================================================

local function renderAll()

	renderEarnMethods()

	renderUpgrades()

	showTab(
		currentTab
	)
end


--==================================================
-- STATE FETCH
--==================================================

local function refreshState()

	local success,
		state =
		pcall(
			function()

				return getLicenseStateRemote
					:InvokeServer()
			end
		)


	if not success
		or type(state)
			~= "table" then

		warn(
			"[Licenses] Could not load License state."
		)

		return
	end


	currentState =
		state


	renderAll()
end


--==================================================
-- OPEN / CLOSE
--==================================================

local function stopMenuTween()

	if menuTween then

		menuTween:Cancel()

		menuTween =
			nil
	end
end


local function openMenu()

	if main.Visible then
		return
	end


	stopMenuTween()


	main.Visible =
		true


	menuScale.Scale =
		OPEN_START_SCALE


	showTab(
		"HowToEarn"
	)


	refreshState()


	menuTween =
		TweenService:Create(
			menuScale,

			TweenInfo.new(
				MENU_TWEEN_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Scale = 1,
			}
		)


	menuTween:Play()
end


local function closeMenu()

	if not main.Visible then
		return
	end


	stopMenuTween()


	menuTween =
		TweenService:Create(
			menuScale,

			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					OPEN_START_SCALE,
			}
		)


	local tween =
		menuTween


	tween.Completed:Once(
		function()

			if menuTween
				~= tween then

				return
			end


			main.Visible =
				false


			menuScale.Scale =
				1


			menuTween =
				nil
		end
	)


	tween:Play()
end


--==================================================
-- BUTTONS
--==================================================

openButton.Activated:Connect(
	openMenu
)


closeButton.Activated:Connect(
	closeMenu
)


howToEarnButton.Activated:Connect(
	function()

		showTab(
			"HowToEarn"
		)
	end
)


upgradesButton.Activated:Connect(
	function()

		showTab(
			"Upgrades"
		)
	end
)


--==================================================
-- LIVE SERVER UPDATES
--==================================================

licenseStateUpdatedRemote.OnClientEvent:Connect(
	function(
		state
	)

		if type(state)
			~= "table" then

			return
		end


		currentState =
			state


		if main.Visible then

			renderAll()
		end
	end
)


--==================================================
-- INITIAL TAB
--==================================================

showTab(
	"HowToEarn"
)