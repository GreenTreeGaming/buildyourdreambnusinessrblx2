local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local UserInputService =
	game:GetService("UserInputService")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")


local purchaseUpgradeRemote =
	remotes:WaitForChild("PurchaseUpgrade")

local upgradeResultRemote =
	remotes:WaitForChild("UpgradeResult")

local getUpgradeStateRemote =
	remotes:WaitForChild("GetUpgradeState")

local requestAppearanceUpgradeRemote =
	remotes:WaitForChild("RequestBusinessUpgrade")

local appearanceUpgradeResultRemote =
	remotes:WaitForChild("BusinessUpgradeResult")


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)

local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local BUSINESS_NAME =
	"LemonadeStand"


local GAMEPLAY_UPGRADE_ORDER = {
	"QueueCapacity",
	"SaleValue",
	"ServingSpeed",
}


local OPEN_START_SCALE =
	0.88

local OPEN_START_OFFSET =
	16

local OPEN_TIME =
	0.28

local CLOSE_SCALE =
	0.92

local CLOSE_OFFSET =
	12

local CLOSE_TIME =
	0.17


type GameplayUpgradeState = {
	Success: boolean,
	Message: string,

	BusinessId: string?,
	BusinessName: string?,

	UpgradeName: string?,
	DisplayName: string?,

	CurrentLevel: number?,
	MaximumLevel: number?,
	NextCost: number?,

	CurrentCooldown: number?,
	CurrentSaleValue: number?,
	CurrentQueueCapacity: number?,
}


type UpgradeCard = {
	Root: Frame,

	Title: TextLabel,
	Subtitle: TextLabel,

	CurrentTitle: TextLabel,
	CurrentAmount: TextLabel,

	AfterTitle: TextLabel,
	AfterAmount: TextLabel,

	ProgressBar: Frame,

	BuyButton: TextButton,
	BuyText: TextLabel,
}


--==================================================
-- STARTERGUI UI
--==================================================

local manageGui =
	playerGui:WaitForChild(
		"ManageStand"
	) :: ScreenGui

local main =
	manageGui:WaitForChild(
		"Main"
	) :: Frame

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

local contentFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame

local currentStats =
	contentFrame:WaitForChild(
		"CurrentStats"
	) :: Frame

local scrollingFrame =
	contentFrame:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame

local template =
	scrollingFrame:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- CURRENT STATS REFERENCES
--==================================================

local cashSaleFrame =
	currentStats:WaitForChild(
		"CashSale"
	) :: Frame

local waitingFrame =
	currentStats:WaitForChild(
		"Waiting"
	) :: Frame

local lifetimeCashFrame =
	currentStats:WaitForChild(
		"LifetimeCash"
	) :: Frame

local serviceTimeFrame =
	currentStats:WaitForChild(
		"ServiceTime"
	) :: Frame

local totalSalesFrame =
	currentStats:WaitForChild(
		"TotalSales"
	) :: Frame


local cashSaleAmount =
	cashSaleFrame:WaitForChild(
		"Amount"
	) :: TextLabel

local waitingAmount =
	waitingFrame:WaitForChild(
		"Amount"
	) :: TextLabel

local lifetimeCashAmount =
	lifetimeCashFrame:WaitForChild(
		"Amount"
	) :: TextLabel

local serviceTimeAmount =
	serviceTimeFrame:WaitForChild(
		"Amount"
	) :: TextLabel

local totalSalesAmount =
	totalSalesFrame:WaitForChild(
		"Amount"
	) :: TextLabel


--==================================================
-- IMPORTANT UI STATE
--==================================================

--
-- Your ScreenGui should remain enabled.
-- Only Main is shown/hidden.
--
manageGui.Enabled =
	true

main.Visible =
	false

template.Visible =
	false

--==================================================
-- REMOVE OLD GENERATED UI IF IT EXISTS
--==================================================

local oldUpgradeGui =
	playerGui:FindFirstChild(
		"UpgradeMenu"
	)

if oldUpgradeGui then
	oldUpgradeGui:Destroy()
end


--==================================================
-- MENU ANIMATION
--==================================================

local originalMainPosition =
	main.Position


local menuScale =
	main:FindFirstChild(
		"MenuScale"
	)

if menuScale
	and not menuScale:IsA(
		"UIScale"
	) then

	menuScale:Destroy()

	menuScale =
		nil
end


if not menuScale then
	menuScale =
		Instance.new(
			"UIScale"
		)

	menuScale.Name =
		"MenuScale"

	menuScale.Parent =
		main
end

menuScale =
	menuScale :: UIScale


local scaleTween:
	Tween? =
	nil

local positionTween:
	Tween? =
	nil

local animationVersion =
	0


local function offsetPosition(
	position: UDim2,
	yOffset: number
): UDim2

	return UDim2.new(
		position.X.Scale,
		position.X.Offset,

		position.Y.Scale,
		position.Y.Offset + yOffset
	)
end


local function stopMenuTweens()
	if scaleTween then
		scaleTween:Cancel()

		scaleTween =
			nil
	end

	if positionTween then
		positionTween:Cancel()

		positionTween =
			nil
	end
end


local function setHiddenPose()
	menuScale.Scale =
		OPEN_START_SCALE

	main.Position =
		offsetPosition(
			originalMainPosition,
			OPEN_START_OFFSET
		)
end


setHiddenPose()


--==================================================
-- STATE
--==================================================

local menuOpen =
	false

local selectedBusinessId:
	string? =
	nil

local selectedStand:
	Model? =
	nil

local requestPending:
	string? =
	nil

local cards: {
	[string]: UpgradeCard
} = {}

local statusVersion =
	0


--==================================================
-- OPEN UPGRADE MENU EVENT
--==================================================

local function getOpenUpgradeMenuEvent():
	BindableEvent

	local existing =
		playerGui:FindFirstChild(
			"OpenUpgradeMenu"
		)

	if existing then
		if existing:IsA(
			"BindableEvent"
		) then

			return existing
		end

		existing:Destroy()
	end


	local event =
		Instance.new(
			"BindableEvent"
		)

	event.Name =
		"OpenUpgradeMenu"

	event.Parent =
		playerGui

	return event
end


local openUpgradeMenuEvent =
	getOpenUpgradeMenuEvent()


--==================================================
-- PLOT HELPERS
--==================================================

local function getOwnedPlot():
	Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)

	if typeof(plotName)
		== "string" then

		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)

		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	for _, plot in
		plotsFolder:GetChildren()
	do
		if not plot:IsA(
			"Model"
		) then

			continue
		end


		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return plot
		end
	end


	return nil
end


local function isLemonadeStand(
	instance: Instance
): boolean

	if not instance:IsA(
		"Model"
	) then

		return false
	end


	if instance:GetAttribute(
		"BusinessType"
	) == BUSINESS_NAME then

		return true
	end


	if instance.Name
		== BUSINESS_NAME then

		return true
	end


	return string.match(
		instance.Name,
		"^LemonadeStand_"
	) ~= nil
end


local function getStandBusinessId(
	stand: Model
): string

	local businessId =
		stand:GetAttribute(
			"BusinessId"
		)

	if typeof(businessId)
			== "string"
		and businessId ~= "" then

		return businessId
	end


	return stand.Name
end


local function findOwnedStandByBusinessId(
	businessId: string
): Model?

	local plot =
		getOwnedPlot()

	if not plot then
		return nil
	end


	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return nil
	end


	for _, child in
		placedBusinesses:GetChildren()
	do
		if not child:IsA(
			"Model"
		) then

			continue
		end


		if not isLemonadeStand(
			child
		) then

			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) ~= player.UserId then

			continue
		end


		local childBusinessId =
			getStandBusinessId(
				child
			)


		if childBusinessId
				== businessId
			or child.Name
				== businessId then

			return child
		end
	end


	return nil
end


local function selectStandByBusinessId(
	businessId: string
): boolean

	local stand =
		findOwnedStandByBusinessId(
			businessId
		)

	if not stand then
		selectedStand =
			nil

		selectedBusinessId =
			nil

		return false
	end


	selectedStand =
		stand

	selectedBusinessId =
		getStandBusinessId(
			stand
		)


	return true
end


local function reconnectSelectedStand():
	boolean

	if not selectedBusinessId then
		return false
	end


	local stand =
		findOwnedStandByBusinessId(
			selectedBusinessId
		)

	if not stand then
		return false
	end


	selectedStand =
		stand


	return true
end


local function getStandNumber(
	businessId: string
): string

	return string.match(
		businessId,
		"_(%d+)$"
	) or businessId
end


local function getNumericAttribute(
	instance: Instance,
	attributeName: string,
	defaultValue: number?
): number

	local value =
		instance:GetAttribute(
			attributeName
		)


	if typeof(value)
		~= "number" then

		return defaultValue
			or 0
	end


	return math.max(
		0,
		value
	)
end


--==================================================
-- NUMBER FORMATTING
--==================================================

local function formatNumber(
	value: number
): string

	return FormatNumber.Compact(
		math.floor(value)
	)
end


local function formatCurrency(
	value: number
): string

	return FormatNumber.Currency(
		math.floor(value)
	)
end


--==================================================
-- STATUS
--==================================================

local DEFAULT_SUBTITLE =
	"Manage your stand and its appearance here!"


local function resetSubtitle()
	mainSubtitle.Text =
		DEFAULT_SUBTITLE
end


local function showStatus(
	message: string,
	isError: boolean?
)
	statusVersion +=
		1

	local version =
		statusVersion


	if message == "" then
		resetSubtitle()

		return
	end


	if isError then
		mainSubtitle.Text =
			"⚠ " .. message
	else
		mainSubtitle.Text =
			message
	end


	task.delay(
		2.5,
		function()
			if statusVersion
				~= version then

				return
			end

			if menuOpen then
				resetSubtitle()
			end
		end
	)
end


--==================================================
-- CARD REFERENCES
--==================================================

local function getCard(
	root: Frame
): UpgradeCard

	local currentBox =
		root:WaitForChild(
			"CurrentBox"
		) :: Frame

	local afterBox =
		root:WaitForChild(
			"AfterUpgradeBox"
		) :: Frame

	local background =
		root:WaitForChild(
			"Background"
		) :: Frame

	local buy =
		root:WaitForChild(
			"Buy"
		) :: TextButton


	local card: UpgradeCard = {
		Root =
			root,

		Title =
			root:WaitForChild(
				"Title"
			) :: TextLabel,

		Subtitle =
			root:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		CurrentTitle =
			currentBox:WaitForChild(
				"Title"
			) :: TextLabel,

		CurrentAmount =
			currentBox:WaitForChild(
				"Amount"
			) :: TextLabel,

		AfterTitle =
			afterBox:WaitForChild(
				"Title"
			) :: TextLabel,

		AfterAmount =
			afterBox:WaitForChild(
				"Amount"
			) :: TextLabel,

		ProgressBar =
			background:WaitForChild(
				"Bar"
			) :: Frame,

		BuyButton =
			buy,

		BuyText =
			buy:WaitForChild(
				"InText"
			) :: TextLabel,
	}


	card.BuyButton.Text =
		""

	card.BuyText.Active =
		false

	card.BuyText.Selectable =
		false


	return card
end


local function createCard(
	name: string,
	layoutOrder: number
): UpgradeCard

	local clone =
		template:Clone()

	clone.Name =
		name

	clone.LayoutOrder =
		layoutOrder

	clone.Visible =
		true

	clone.Parent =
		scrollingFrame


	return getCard(
		clone
	)
end

-- Remove any clones left behind from a previous
-- script run in Studio.
for _, child in
	scrollingFrame:GetChildren()
do
	if child:IsA("Frame")
		and child ~= template then

		child:Destroy()
	end
end


cards.StandAppearance =
	createCard(
		"StandAppearance",
		1
	)

cards.QueueCapacity =
	createCard(
		"QueueCapacity",
		2
	)

cards.SaleValue =
	createCard(
		"SaleValue",
		3
	)

cards.ServingSpeed =
	createCard(
		"ServingSpeed",
		4
	)


--==================================================
-- BUTTON HELPERS
--==================================================

local function setButton(
	card: UpgradeCard,
	text: string,
	enabled: boolean
)
	card.BuyText.Text =
		text

	card.BuyButton.Active =
		enabled

	card.BuyButton.Selectable =
		enabled

	card.BuyButton.AutoButtonColor =
		enabled


	card.BuyText.TextTransparency =
		enabled
			and 0
			or 0.18
end


local function disableAllButtons()
	for _, card in cards do
		card.BuyButton.Active =
			false

		card.BuyButton.Selectable =
			false

		card.BuyButton.AutoButtonColor =
			false
	end
end


local function setProgress(
	card: UpgradeCard,
	currentLevel: number,
	maximumLevel: number
)
	local progress =
		0

	if maximumLevel > 0 then
		progress =
			math.clamp(
				currentLevel
					/ maximumLevel,
				0,
				1
			)
	end


	TweenService:Create(
		card.ProgressBar,

		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			Size =
				UDim2.fromScale(
					progress,
					1
				),
		}
	):Play()
end


--==================================================
-- CONFIG
--==================================================

local function getLemonadeConfig()
	return BusinessConfig.LemonadeStand
end


local function getGameplayConfig(
	upgradeName: string
)
	local businessConfig =
		getLemonadeConfig()


	if typeof(businessConfig)
			~= "table"
		or typeof(
			businessConfig.Upgrades
		) ~= "table" then

		return nil
	end


	return businessConfig.Upgrades[
		upgradeName
	]
end


local function getDefinition(
	upgradeName: string,
	level: number
)
	local config =
		getGameplayConfig(
			upgradeName
		)


	if not config
		or typeof(config.Levels)
			~= "table" then

		return nil
	end


	for _, definition in
		config.Levels
	do
		if definition.Level
			== level then

			return definition
		end
	end


	return nil
end


local function getMaximumAppearanceLevel():
	number

	local config =
		getLemonadeConfig()


	if typeof(config)
			~= "table"
		or typeof(config.StandLevels)
			~= "table" then

		return 1
	end


	local maximum =
		1


	for level, definition in
		config.StandLevels
	do
		if typeof(level)
				== "number"
			and typeof(definition)
				== "table" then

			maximum =
				math.max(
					maximum,
					level
				)
		end
	end


	return maximum
end


local function getAppearanceConfig(
	level: number
)
	local config =
		getLemonadeConfig()


	if typeof(config)
			~= "table"
		or typeof(config.StandLevels)
			~= "table" then

		return nil
	end


	return config.StandLevels[
		level
	]
end


--==================================================
-- STATISTICS
--==================================================

local function clearStatistics()
	cashSaleAmount.Text =
		"--"

	waitingAmount.Text =
		"--"

	lifetimeCashAmount.Text =
		"--"

	serviceTimeAmount.Text =
		"--"

	totalSalesAmount.Text =
		"--"
end


local function updateStatistics()
	if not selectedStand
		or not selectedStand.Parent then

		clearStatistics()

		return
	end


	local saleValue =
		getNumericAttribute(
			selectedStand,
			"SaleValue",
			2
		)

	local waiting =
		getNumericAttribute(
			selectedStand,
			"CustomersWaiting",
			0
		)

	local lifetimeCash =
		getNumericAttribute(
			selectedStand,
			"LifetimeEarnings",
			0
		)

	local serviceTime =
		getNumericAttribute(
			selectedStand,
			"PurchaseCooldown",
			5
		)

	local totalSales =
		getNumericAttribute(
			selectedStand,
			"TotalSales",
			0
		)


	cashSaleAmount.Text =
		formatCurrency(
			saleValue
		)

	waitingAmount.Text =
		formatNumber(
			waiting
		)

	lifetimeCashAmount.Text =
		formatCurrency(
			lifetimeCash
		)

	serviceTimeAmount.Text =
		string.format(
			"%.2fs",
			serviceTime
		)

	totalSalesAmount.Text =
		formatNumber(
			totalSales
		)
end


--==================================================
-- APPEARANCE CARD
--==================================================

local function updateAppearanceCard()
	local card =
		cards.StandAppearance


	card.Title.Text =
		"Stand Appearance"

	card.Subtitle.Text =
		"Upgrade your stand with a bigger and better design."

	card.CurrentTitle.Text =
		"Current Level"

	card.AfterTitle.Text =
		"After Upgrade"


	if not selectedStand
		or not selectedStand.Parent then

		card.CurrentAmount.Text =
			"--"

		card.AfterAmount.Text =
			"--"

		setProgress(
			card,
			0,
			1
		)

		setButton(
			card,
			"Unavailable",
			false
		)

		return
	end


	local currentLevel =
		math.max(
			1,
			math.floor(
				getNumericAttribute(
					selectedStand,
					"Level",
					1
				)
			)
		)

	local maximumLevel =
		getMaximumAppearanceLevel()

	local currentConfig =
		getAppearanceConfig(
			currentLevel
		)

	local nextConfig =
		getAppearanceConfig(
			currentLevel + 1
		)


	card.CurrentAmount.Text =
		`{currentLevel} / {maximumLevel}`


	setProgress(
		card,
		currentLevel,
		maximumLevel
	)


	if currentLevel >= maximumLevel
		or not nextConfig then

		card.AfterTitle.Text =
			"Status"

		card.AfterAmount.Text =
			"Max Level"

		setButton(
			card,
			"Maximum Level",
			false
		)

		return
	end


	card.AfterTitle.Text =
		"Next Design"

	card.AfterAmount.Text =
		`Level {currentLevel + 1}`


	local cost =
		currentConfig
		and currentConfig.UpgradeCost


	if typeof(cost)
		~= "number" then

		setButton(
			card,
			"Unavailable",
			false
		)

		return
	end


	setButton(
		card,
		`Upgrade - {formatCurrency(cost)}`,
		requestPending == nil
	)
end


--==================================================
-- GAMEPLAY CARD VALUES
--==================================================

local function getNextValueText(
	upgradeName: string,
	currentLevel: number
): string

	local nextDefinition =
		getDefinition(
			upgradeName,
			currentLevel + 1
		)


	if not nextDefinition then
		return "Max Level"
	end


	if upgradeName
		== "QueueCapacity" then

		local capacity =
			nextDefinition.Capacity


		if typeof(capacity)
			~= "number" then

			return "--"
		end


		local rounded =
			math.floor(
				capacity
			)


		if rounded == 1 then
			return "1 Customer"
		end


		return `{rounded} Customers`
	end


	if upgradeName
		== "SaleValue" then

		if typeof(
			nextDefinition.SaleValue
		) ~= "number" then

			return "--"
		end


		return formatCurrency(
			nextDefinition.SaleValue
		)
	end


	if upgradeName
		== "ServingSpeed" then

		if typeof(
			nextDefinition.Cooldown
		) ~= "number" then

			return "--"
		end


		return string.format(
			"%.2fs",
			nextDefinition.Cooldown
		)
	end


	return "--"
end


local function configureCardText(
	upgradeName: string,
	card: UpgradeCard
)
	local config =
		getGameplayConfig(
			upgradeName
		)


	if config
		and typeof(config.DisplayName)
			== "string" then

		card.Title.Text =
			config.DisplayName
	else
		card.Title.Text =
			upgradeName
	end


	if config
		and typeof(config.Description)
			== "string" then

		card.Subtitle.Text =
			config.Description
	else
		card.Subtitle.Text =
			""
	end


	card.CurrentTitle.Text =
		"Current Level"

	card.AfterTitle.Text =
		"After Upgrade"
end


local function updateGameplayCard(
	state: GameplayUpgradeState
)
	local upgradeName =
		state.UpgradeName


	if not upgradeName then
		return
	end


	local card =
		cards[
			upgradeName
		]


	if not card then
		return
	end


	configureCardText(
		upgradeName,
		card
	)


	if not state.Success
		and state.CurrentLevel == nil then

		card.CurrentAmount.Text =
			"--"

		card.AfterAmount.Text =
			"--"

		setProgress(
			card,
			0,
			1
		)

		setButton(
			card,
			"Unavailable",
			false
		)

		return
	end


	local currentLevel =
		state.CurrentLevel
		or 0

	local maximumLevel =
		state.MaximumLevel
		or 0


	card.CurrentAmount.Text =
		`{currentLevel} / {maximumLevel}`


	setProgress(
		card,
		currentLevel,
		maximumLevel
	)


	if currentLevel
		>= maximumLevel then

		card.AfterTitle.Text =
			"Status"

		card.AfterAmount.Text =
			"Max Level"

		setButton(
			card,
			"Maximum Level",
			false
		)

		return
	end


	card.AfterTitle.Text =
		"After Upgrade"

	card.AfterAmount.Text =
		getNextValueText(
			upgradeName,
			currentLevel
		)


	if typeof(state.NextCost)
		~= "number" then

		setButton(
			card,
			"Unavailable",
			false
		)

		return
	end


	setButton(
		card,

		`Upgrade - {formatCurrency(
			state.NextCost
		)}`,

		requestPending == nil
	)
end


--==================================================
-- REQUEST GAMEPLAY STATES
--==================================================

local function requestGameplayState(
	upgradeName: string
)
	if not selectedBusinessId then
		return
	end


	local requestedBusinessId =
		selectedBusinessId


	local success, result =
		pcall(
			function()
				return getUpgradeStateRemote
					:InvokeServer(
						requestedBusinessId,
						upgradeName
					)
			end
		)


	if selectedBusinessId
		~= requestedBusinessId then

		return
	end


	if not success
		or type(result)
			~= "table" then

		updateGameplayCard({
			Success =
				false,

			Message =
				"Unable to load upgrade.",

			UpgradeName =
				upgradeName,
		})

		return
	end


	if result.BusinessId
		and result.BusinessId
			~= requestedBusinessId then

		return
	end


	if not result.UpgradeName then
		result.UpgradeName =
			upgradeName
	end


	updateGameplayCard(
		result
	)
end


local function refreshGameplayCards()
	for _, upgradeName in
		GAMEPLAY_UPGRADE_ORDER
	do
		requestGameplayState(
			upgradeName
		)
	end
end


local function refreshAllCards()
	updateAppearanceCard()

	refreshGameplayCards()
end


--==================================================
-- BUTTON ANIMATIONS
--==================================================

local function prepareButton(
	button: TextButton
)
	button.Active =
		true

	button.Selectable =
		true

	button.AutoButtonColor =
		false


	for _, child in
		button:GetDescendants()
	do
		if child:IsA("GuiObject") then
			child.Active =
				false

			child.Selectable =
				false
		end
	end


	local scale =
		button:FindFirstChild(
			"ButtonScale"
		)


	if scale
		and not scale:IsA(
			"UIScale"
		) then

		scale:Destroy()

		scale =
			nil
	end


	if not scale then
		scale =
			Instance.new(
				"UIScale"
			)

		scale.Name =
			"ButtonScale"

		scale.Parent =
			button
	end


	scale =
		scale :: UIScale


	local tween:
		Tween? =
		nil


	local function tweenTo(
		value: number,
		duration: number
	)
		if tween then
			tween:Cancel()
		end


		tween =
			TweenService:Create(
				scale,

				TweenInfo.new(
					duration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						value,
				}
			)


		tween:Play()
	end


	button.MouseEnter:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				1.04,
				0.1
			)
		end
	)


	button.MouseLeave:Connect(
		function()
			tweenTo(
				1,
				0.1
			)
		end
	)


	button.MouseButton1Down:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				0.95,
				0.06
			)
		end
	)


	button.MouseButton1Up:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				1.04,
				0.07
			)
		end
	)
end


prepareButton(
	closeButton
)


for _, card in cards do
	prepareButton(
		card.BuyButton
	)
end


--==================================================
-- OPEN / CLOSE
--==================================================

local function closeMenu()
	if not menuOpen then
		return
	end


	menuOpen =
		false

	requestPending =
		nil

	animationVersion +=
		1


	local version =
		animationVersion


	stopMenuTweens()


	scaleTween =
		TweenService:Create(
			menuScale,

			TweenInfo.new(
				CLOSE_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Scale =
					CLOSE_SCALE,
			}
		)


	positionTween =
		TweenService:Create(
			main,

			TweenInfo.new(
				CLOSE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Position =
					offsetPosition(
						originalMainPosition,
						CLOSE_OFFSET
					),
			}
		)


	scaleTween:Play()
	positionTween:Play()


	scaleTween.Completed:Once(
		function()
			if version
					~= animationVersion
				or menuOpen then

				return
			end


			--
			-- IMPORTANT:
			-- ScreenGui stays enabled.
			-- Only the Main frame disappears.
			--
			main.Visible =
				false


			selectedStand =
				nil

			selectedBusinessId =
				nil


			setHiddenPose()
		end
	)
end


local function openMenuForStand(
	businessId: string
)
	if type(businessId)
			~= "string"
		or businessId == "" then

		warn(
			"ManageStand was opened without a valid BusinessId."
		)

		return
	end


	if not selectStandByBusinessId(
		businessId
	) then

		warn(
			`Could not find lemonade stand "{businessId}".`
		)

		return
	end


	if not selectedBusinessId then
		return
	end


	local standNumber =
		getStandNumber(
			selectedBusinessId
		)


	mainTitle.Text =
		`Manage Lemonade Stand #{standNumber}`

	resetSubtitle()


	requestPending =
		nil


	updateStatistics()

	refreshAllCards()


	animationVersion +=
		1


	local version =
		animationVersion


	stopMenuTweens()


	menuOpen =
		true


	--
	-- CRITICAL FIX:
	--
	-- ManageStand is already enabled.
	-- Main itself was invisible in Studio, therefore
	-- Main must explicitly become visible here.
	--
	manageGui.Enabled =
		true

	main.Visible =
		true


	menuScale.Scale =
		OPEN_START_SCALE

	main.Position =
		offsetPosition(
			originalMainPosition,
			OPEN_START_OFFSET
		)


	task.defer(
		function()
			if version
					~= animationVersion
				or not menuOpen
				or not main.Visible then

				return
			end


			scaleTween =
				TweenService:Create(
					menuScale,

					TweenInfo.new(
						OPEN_TIME,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),

					{
						Scale =
							1,
					}
				)


			positionTween =
				TweenService:Create(
					main,

					TweenInfo.new(
						OPEN_TIME - 0.03,
						Enum.EasingStyle.Quart,
						Enum.EasingDirection.Out
					),

					{
						Position =
							originalMainPosition,
					}
				)


			scaleTween:Play()
			positionTween:Play()
		end
	)
end


--==================================================
-- APPEARANCE PURCHASE
--==================================================

cards.StandAppearance
	.BuyButton
	.Activated:Connect(
		function()
			local card =
				cards.StandAppearance


			if requestPending
				or not card.BuyButton.Active
				or not selectedStand
				or not selectedStand.Parent then

				return
			end


			requestPending =
				"StandAppearance"


			disableAllButtons()


			setButton(
				card,
				"Upgrading...",
				false
			)


			requestAppearanceUpgradeRemote
				:FireServer(
					selectedStand
				)
		end
	)


--==================================================
-- GAMEPLAY PURCHASES
--==================================================

for _, upgradeName in
	GAMEPLAY_UPGRADE_ORDER
do
	local card =
		cards[
			upgradeName
		]


	card.BuyButton.Activated:Connect(
		function()
			if requestPending
				or not card.BuyButton.Active
				or not selectedBusinessId then

				return
			end


			requestPending =
				upgradeName


			disableAllButtons()


			setButton(
				card,
				"Purchasing...",
				false
			)


			purchaseUpgradeRemote
				:FireServer(
					selectedBusinessId,
					upgradeName
				)
		end
	)
end


--==================================================
-- GAMEPLAY RESULT
--==================================================

upgradeResultRemote.OnClientEvent:Connect(
	function(
		result: GameplayUpgradeState
	)
		if type(result)
			~= "table" then

			return
		end


		if result.BusinessId
			and selectedBusinessId
			and result.BusinessId
				~= selectedBusinessId then

			return
		end


		requestPending =
			nil


		showStatus(
			result.Message
				or (
					result.Success
					and "Upgrade purchased!"
					or "Upgrade failed."
				),

			not result.Success
		)


		updateStatistics()

		refreshAllCards()
	end
)


--==================================================
-- APPEARANCE RESULT
--==================================================

appearanceUpgradeResultRemote
	.OnClientEvent:Connect(
		function(
			success: boolean,
			message: string,
			_level: number?
		)
			if requestPending
				~= "StandAppearance" then

				return
			end


			requestPending =
				nil


			showStatus(
				message,
				not success
			)


			if not success then
				refreshAllCards()

				return
			end


			--
			-- Appearance upgrades replace the stand
			-- model. Reconnect using its BusinessId.
			--
			task.spawn(
				function()
					local startedAt =
						time()


					while menuOpen
						and time()
							- startedAt < 4 do

						if reconnectSelectedStand() then
							updateStatistics()

							refreshAllCards()

							return
						end


						task.wait(
							0.05
						)
					end


					if menuOpen then
						showStatus(
							"The upgraded stand could not be found.",
							true
						)

						closeMenu()
					end
				end
			)
		end
	)


--==================================================
-- CLOSE BUTTON
--==================================================

closeButton.MouseButton1Click:Connect(
	function()
		closeMenu()
	end
)

--==================================================
-- MANAGEMENT BUTTON EVENT
--==================================================

openUpgradeMenuEvent.Event:Connect(
	function(
		businessId: string
	)
		openMenuForStand(
			businessId
		)
	end
)


--==================================================
-- ESCAPE / CONTROLLER B
--==================================================

UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		gameProcessed: boolean
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


--==================================================
-- CASH CHANGES
--==================================================

local leaderstats =
	player:WaitForChild(
		"leaderstats"
	)

local cash =
	leaderstats:WaitForChild(
		"Cash"
	)


cash:GetPropertyChangedSignal(
	"Value"
):Connect(
	function()
		if not menuOpen
			or requestPending then

			return
		end


		refreshAllCards()
	end
)


--==================================================
-- LIVE STATISTICS
--==================================================

task.spawn(
	function()
		while true do
			if menuOpen
				and main.Visible then

				if selectedStand
					and selectedStand.Parent then

					updateStatistics()

				elseif requestPending
						~= "StandAppearance" then

					if not reconnectSelectedStand() then
						closeMenu()
					end
				end
			end


			task.wait(
				0.25
			)
		end
	end
)