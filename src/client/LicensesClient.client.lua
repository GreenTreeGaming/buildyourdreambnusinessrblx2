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

local Notification =
	require(
		ReplicatedStorage
			:WaitForChild(
				"Shared"
			)
			:WaitForChild(
				"Notification"
			)
	)

local licenseEarnedRemote =
	remotes:WaitForChild(
		"LicenseEarned"
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

local INTERACTION_ZINDEX =
	50

local function makeClickable(
	object: GuiObject
): GuiButton

	local button: GuiButton?


	-- Use the object itself when it is already a button.
	if object:IsA("GuiButton") then
		button =
			object
	else

		-- Prefer an actual button already inside the UI object.
		button =
			object:FindFirstChildWhichIsA(
				"GuiButton",
				true
			)


		-- Otherwise create a transparent click layer.
		if not button then

			local existing =
				object:FindFirstChild(
					"ClickArea"
				)


			if existing
				and existing:IsA(
					"GuiButton"
				) then

				button =
					existing
			else

				local clickArea =
					Instance.new(
						"TextButton"
					)


				clickArea.Name =
					"ClickArea"

				clickArea.BackgroundTransparency =
					1

				clickArea.Text =
					""

				clickArea.Size =
					UDim2.fromScale(
						1,
						1
					)

				clickArea.Position =
					UDim2.fromScale(
						0,
						0
					)

				clickArea.AnchorPoint =
					Vector2.zero

				clickArea.AutoButtonColor =
					false

				clickArea.Parent =
					object


				button =
					clickArea
			end
		end
	end


	button.Active =
		true

	button.Selectable =
		true

	button.ZIndex =
		math.max(
			button.ZIndex,
			INTERACTION_ZINDEX
		)


	return button
end

local closeObject =
	main:WaitForChild(
		"Close"
	) :: GuiObject



local contentFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame

local buttonsFrame =
	contentFrame:WaitForChild(
		"Buttons"
	) :: Frame


local howToEarnObject =
	buttonsFrame:WaitForChild(
		"HowToEarn"
	) :: GuiObject


local upgradesObject =
	buttonsFrame:WaitForChild(
		"Upgrades"
	) :: GuiObject


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

local closeButton =
	makeClickable(
		closeObject
	)


local howToEarnButton =
	makeClickable(
		howToEarnObject
	)


local upgradesButton =
	makeClickable(
		upgradesObject
	)

-- Keep interactive controls above the tab content so that
-- HowToEarnFrame / UpgradesFrame cannot swallow their clicks.

closeObject.ZIndex =
	math.max(
		closeObject.ZIndex,
		40
	)

buttonsFrame.ZIndex =
	math.max(
		buttonsFrame.ZIndex,
		40
	)

howToEarnObject.ZIndex =
	math.max(
		howToEarnObject.ZIndex,
		41
	)

upgradesObject.ZIndex =
	math.max(
		upgradesObject.ZIndex,
		41
	)

howToEarnFrame.ZIndex =
	math.min(
		howToEarnFrame.ZIndex,
		20
	)

upgradesFrame.ZIndex =
	math.min(
		upgradesFrame.ZIndex,
		20
	)


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

	if tabName ~= "HowToEarn"
		and tabName ~= "Upgrades" then

		warn(
			`[Licenses] Unknown tab: {tabName}`
		)

		return
	end


	currentTab =
		tabName


	local showingHowToEarn =
		tabName == "HowToEarn"


	howToEarnFrame.Visible =
		showingHowToEarn

	upgradesFrame.Visible =
		not showingHowToEarn
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
	state
	and state.DisplayName
	or definition.DisplayName


earnDesc.Text =
	state
	and state.Description
	or definition.Description


local reward =
	state
	and state.Reward
	or definition.Reward
	or 0


rewardAmount.Text =
	`+{reward}`


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

local LICENSE_IMAGES = {
	Operations =
		"rbxassetid://97437298073596",

	Advertising =
		"rbxassetid://101633672564115",

	Expansion =
		"rbxassetid://124922347182163",

	Executive =
		"rbxassetid://135369033657696",

	EliteNetwork =
		"rbxassetid://123493899128226",
}


--==================================================
-- UPGRADE ITEMS
--==================================================

local function createUpgradeItem(
	definition: any,
	state: any
)

	local clone =
		upgradeTemplate:Clone()

	local imageLabel =
	clone:WaitForChild(
		"ImageLabel"
	) :: ImageLabel


local imageId =
	LICENSE_IMAGES[
		definition.Id
	]


if imageId then

	imageLabel.Image =
		imageId
end


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


local buyText =
	buyButton:WaitForChild(
		"InText"
	) :: TextLabel


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


	-- The button itself should never render text.
buyButton.Text =
	""


if maxed then

	buyText.Text =
		"MAXED"


	buyButton.Active =
		false


	buyButton.AutoButtonColor =
		false

else

	buyText.Text =
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

licenseEarnedRemote.OnClientEvent:Connect(
	function(
		amount: number,
		sourceName: string
	)

		amount =
			math.max(
				1,
				math.floor(
					tonumber(amount)
					or 1
				)
			)


		if type(sourceName)
			~= "string"
			or sourceName == "" then

			sourceName =
				"License Reward"
		end


		local licenseWord =
			amount == 1
			and "License"
			or "Licenses"


		Notification.Success(
			`You earned {amount} {licenseWord}! — {sourceName}`,
			{
				Duration = 4,
			}
		)
	end
)