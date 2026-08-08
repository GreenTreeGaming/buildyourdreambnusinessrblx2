local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")

local BusinessConfig = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("BusinessConfig")
)

local businessModels =
	ReplicatedStorage:WaitForChild("BusinessModels")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local BUSINESS_NAME = "LemonadeStand"
local REQUEST_COOLDOWN = 0.5
local MANAGEMENT_DISTANCE = 22

-- Appearance upgrade construction animation.
local CONSTRUCTION_START_OFFSET =
	Vector3.new(0, -2.25, 0)

local CONSTRUCTION_MIN_STAGGER = 0.008
local CONSTRUCTION_MAX_STAGGER = 0.018

local CONSTRUCTION_MOVE_TIME = 0.20
local CONSTRUCTION_SETTLE_TIME = 0.07

local CONSTRUCTION_START_SCALE = 0.08

local constructionRandom = Random.new()

local CONSTRUCTION_OVERSHOOT =
	Vector3.new(0, 0.15, 0)

local MINIMUM_PART_SIZE = 0.05

local requestUpgradeRemote =
	remotes:FindFirstChild("RequestBusinessUpgrade")

if not requestUpgradeRemote then
	requestUpgradeRemote = Instance.new("RemoteEvent")
	requestUpgradeRemote.Name = "RequestBusinessUpgrade"
	requestUpgradeRemote.Parent = remotes
end

local upgradeResultRemote =
	remotes:FindFirstChild("BusinessUpgradeResult")

if not upgradeResultRemote then
	upgradeResultRemote = Instance.new("RemoteEvent")
	upgradeResultRemote.Name = "BusinessUpgradeResult"
	upgradeResultRemote.Parent = remotes
end

local lastRequests: {[Player]: number} = {}
local activeUpgrades: {[Player]: boolean} = {}

local function sendResult(
	player: Player,
	success: boolean,
	message: string,
	level: number?
)
	upgradeResultRemote:FireClient(
		player,
		success,
		message,
		level
	)
end

local function getPlayerPlot(player: Player): Model?
	local plotName = player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local namedPlot = plotsFolder:FindFirstChild(plotName)

		if namedPlot
			and namedPlot:IsA("Model")
			and namedPlot:GetAttribute("OwnerUserId")
				== player.UserId then

			return namedPlot
		end
	end

	for _, instance in plotsFolder:GetChildren() do
		if not instance:IsA("Model") then
			continue
		end

		if instance:GetAttribute("OwnerUserId")
			== player.UserId then

			return instance
		end
	end

	return nil
end

local function getPlacedBusinesses(
	plot: Model
): Instance?
	return plot:FindFirstChild("PlacedBusinesses")
end

local function getCashValue(
	player: Player
): IntValue?
	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then
		return nil
	end

	local cash = leaderstats:FindFirstChild("Cash")

	if cash and cash:IsA("IntValue") then
		return cash
	end

	return nil
end

local function getCurrentLevel(
	stand: Model
): number
	local value = stand:GetAttribute("Level")

	if typeof(value) ~= "number" then
		return 1
	end

	if value % 1 ~= 0 or value < 1 then
		return 1
	end

	return value
end

local function getStandLevelConfig(
	level: number
): {[string]: any}?
	local lemonadeConfig =
		BusinessConfig.LemonadeStand

	if typeof(lemonadeConfig) ~= "table" then
		return nil
	end

	local standLevels =
		lemonadeConfig.StandLevels

	if typeof(standLevels) ~= "table" then
		return nil
	end

	local levelConfig =
		standLevels[level]

	if typeof(levelConfig) ~= "table" then
		return nil
	end

	return levelConfig
end

local function playerOwnsStand(
	player: Player,
	stand: Model,
	plot: Model
): boolean
	if plot:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	if stand:GetAttribute("OwnerUserId")
		~= player.UserId then

		return false
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		return false
	end

	return stand.Parent == placedBusinesses
end

local function setModelPlacedState(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local PROMPT_ENABLED_ATTRIBUTE =
	"EnabledBeforeAppearanceUpgrade"

local function disablePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants()
	do
		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end

		descendant:SetAttribute(
			PROMPT_ENABLED_ATTRIBUTE,
			descendant.Enabled
		)

		descendant.Enabled = false
	end
end

local function restorePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants()
	do
		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end

		local previousState =
			descendant:GetAttribute(
				PROMPT_ENABLED_ATTRIBUTE
			)

		if typeof(previousState) == "boolean" then
			descendant.Enabled =
				previousState

			descendant:SetAttribute(
				PROMPT_ENABLED_ATTRIBUTE,
				nil
			)
		end
	end
end

local function copyAttributes(
	source: Model,
	target: Model
)
	for attributeName, value in source:GetAttributes() do
		target:SetAttribute(attributeName, value)
	end
end

local function validateUpgradeTemplate(
	template: Model
): (boolean, string)
	if not template.PrimaryPart then
		return false,
			`${template.Name} does not have a PrimaryPart.`
	end

	local requiredInstances = {
		"PlacementOrigin",
		"PlacementBounds",
		"ManagementUIPosition",
		"CooldownUIPosition",
		"SaleEffectPosition",
		"CustomerFacingPosition",
		"QueuePositions",
	}

	for _, instanceName in requiredInstances do
		if not template:FindFirstChild(
			instanceName,
			true
		) then
			return false,
				`${template.Name} is missing {instanceName}.`
		end
	end

	return true, ""
end

local function isLemonadeStand(
	stand: Model
): boolean
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

type ConstructionPartState = {
	Part: BasePart,
	FinalCFrame: CFrame,
	FinalSize: Vector3,
	FinalTransparency: number,
}

local function isConstructionVisual(
	part: BasePart
): boolean
	-- Completely invisible parts are generally placement,
	-- interaction, queue, or other gameplay helpers.
	if part.Transparency >= 1 then
		return false
	end

	-- Never animate the model's gameplay helper pieces,
	-- even if one is accidentally made visible later.
	local ignoredNames = {
		PlacementOrigin = true,
		PlacementBounds = true,
		ManagementUIPosition = true,
		CooldownUIPosition = true,
		SaleEffectPosition = true,
		CustomerFacingPosition = true,
	}

	if ignoredNames[part.Name] then
		return false
	end

	-- Queue position parts are descendants of this folder/model.
	local current: Instance? = part.Parent

	while current do
		if current.Name == "QueuePositions" then
			return false
		end

		current = current.Parent
	end

	return true
end

local function getConstructionParts(
	model: Model
): {ConstructionPartState}
	local parts: {ConstructionPartState} = {}

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		if not isConstructionVisual(descendant) then
			continue
		end

		table.insert(
			parts,
			{
				Part = descendant,
				FinalCFrame = descendant.CFrame,
				FinalSize = descendant.Size,
				FinalTransparency =
					descendant.Transparency,
			}
		)
	end

	-- Construct from the bottom upward.
	--
	-- This makes legs/base pieces appear first, followed
	-- naturally by counters, walls, signs, roofs, etc.
	table.sort(
		parts,
		function(
			a: ConstructionPartState,
			b: ConstructionPartState
		): boolean
			return a.FinalCFrame.Position.Y
				< b.FinalCFrame.Position.Y
		end
	)

	return parts
end

local function getScaledStartingSize(
	size: Vector3
): Vector3
	return Vector3.new(
		math.max(
			size.X * CONSTRUCTION_START_SCALE,
			MINIMUM_PART_SIZE
		),

		math.max(
			size.Y * CONSTRUCTION_START_SCALE,
			MINIMUM_PART_SIZE
		),

		math.max(
			size.Z * CONSTRUCTION_START_SCALE,
			MINIMUM_PART_SIZE
		)
	)
end

local function prepareConstructionAnimation(
	states: {ConstructionPartState}
)
	for _, state in states do
		local part = state.Part

		if not part.Parent then
			continue
		end

		part.Size =
			getScaledStartingSize(
				state.FinalSize
			)

		part.CFrame =
			state.FinalCFrame
			+ CONSTRUCTION_START_OFFSET

		part.Transparency = 1
	end
end

local function animateConstructionPart(
	state: ConstructionPartState
)
	local part = state.Part

	if not part.Parent then
		return
	end

	-- First movement goes just slightly above the final
	-- position, giving each piece a satisfying pop.
	local overshootCFrame =
		state.FinalCFrame
		+ CONSTRUCTION_OVERSHOOT

	local appearTween =
		TweenService:Create(
			part,
			TweenInfo.new(
				CONSTRUCTION_MOVE_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				CFrame = overshootCFrame,
				Size = state.FinalSize,
				Transparency =
					state.FinalTransparency,
			}
		)

	appearTween:Play()
	appearTween.Completed:Wait()

	if not part.Parent then
		return
	end

	local settleTween =
		TweenService:Create(
			part,
			TweenInfo.new(
				CONSTRUCTION_SETTLE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				CFrame = state.FinalCFrame,
			}
		)

	settleTween:Play()
	settleTween.Completed:Wait()
end

local function playConstructionAnimation(
	model: Model
)
	local states =
		getConstructionParts(model)

	if #states == 0 then
		return
	end

	prepareConstructionAnimation(states)

	for index, state in states do
		task.delay(
			(index - 1)
				* constructionRandom:NextNumber(
	CONSTRUCTION_MIN_STAGGER,
	CONSTRUCTION_MAX_STAGGER
),
			function()
				animateConstructionPart(state)
			end
		)
	end

	-- Determine approximately when the last piece has
	-- completed both its construction and settling tween.
	local maximumStagger =
		(#states - 1)
		* CONSTRUCTION_MAX_STAGGER

	task.wait(
		maximumStagger
			+ CONSTRUCTION_MOVE_TIME
			+ CONSTRUCTION_SETTLE_TIME
			+ 0.05
	)

	-- Force exact final state in case a tween was interrupted
	-- by lag or some other system touching the stand.
	for _, state in states do
		if state.Part.Parent then
			state.Part.CFrame =
				state.FinalCFrame

			state.Part.Size =
				state.FinalSize

			state.Part.Transparency =
				state.FinalTransparency
		end
	end
end

local function performUpgrade(player: Player, stand: Model)
	if activeUpgrades[player] then
		return
	end

	activeUpgrades[player] = true

	local function finish()
		activeUpgrades[player] = nil
	end

	if typeof(stand) ~= "Instance"
	or not stand:IsA("Model") then

	finish()

	sendResult(
		player,
		false,
		"The selected lemonade stand is invalid."
	)

	return
end

local plot =
	getPlayerPlot(player)

if not plot then
	finish()

	sendResult(
		player,
		false,
		"You do not own a plot."
	)

	return
end

if not isLemonadeStand(stand) then
	finish()

	sendResult(
		player,
		false,
		"The selected business is not a lemonade stand."
	)

	return
end

	if not playerOwnsStand(
		player,
		stand,
		plot
	) then
		finish()

		sendResult(
			player,
			false,
			"You do not own this lemonade stand."
		)

		return
	end

	if player:GetAttribute("EditingBusiness") then
		finish()

		sendResult(
			player,
			false,
			"Finish editing the stand before upgrading it."
		)

		return
	end

	if stand:GetAttribute("IsBeingEdited") == true then
		finish()

		sendResult(
			player,
			false,
			"This stand is currently being edited."
		)

		return
	end

	if stand:GetAttribute("StandUnavailable") == true then
		finish()

		sendResult(
			player,
			false,
			"This stand is currently unavailable."
		)

		return
	end

	local currentLevel =
		getCurrentLevel(stand)

	local currentConfig =
	getStandLevelConfig(currentLevel)

	if not currentConfig then
		finish()

		sendResult(
			player,
			false,
			"The current stand level is not configured."
		)

		return
	end

	local nextLevel = currentLevel + 1

	local nextConfig =
	getStandLevelConfig(nextLevel)

	if not nextConfig then
		finish()

		sendResult(
			player,
			false,
			"Your lemonade stand is already at the maximum level.",
			currentLevel
		)

		return
	end

	local upgradeCost =
		currentConfig.UpgradeCost

	if typeof(upgradeCost) ~= "number"
		or upgradeCost < 0
		or upgradeCost % 1 ~= 0 then

		finish()

		sendResult(
			player,
			false,
			"The upgrade cost is not configured correctly."
		)

		return
	end

	local templateName =
		nextConfig.TemplateName

	if typeof(templateName) ~= "string" then
		finish()

		sendResult(
			player,
			false,
			"The next stand model is not configured."
		)

		return
	end

	local template =
		businessModels:FindFirstChild(templateName)

	if not template or not template:IsA("Model") then
		finish()

		sendResult(
			player,
			false,
			`${templateName} could not be found in BusinessModels.`
		)

		return
	end

	local templateValid, templateReason =
		validateUpgradeTemplate(template)

	if not templateValid then
		finish()

		sendResult(
			player,
			false,
			templateReason
		)

		return
	end

	local cash = getCashValue(player)

	if not cash then
		finish()

		sendResult(
			player,
			false,
			"Your cash value could not be found."
		)

		return
	end

	if cash.Value < upgradeCost then
		finish()

		sendResult(
			player,
			false,
			`You need ${upgradeCost} to upgrade this stand.`,
			currentLevel
		)

		return
	end

	local placedBusinesses =
		getPlacedBusinesses(plot)

	if not placedBusinesses then
		finish()

		sendResult(
			player,
			false,
			"The plot is missing PlacedBusinesses."
		)

		return
	end

	local oldPivot = stand:GetPivot()

	-- Stop new customers from using the old stand during replacement.
	stand:SetAttribute("StandUnavailable", true)
	disablePrompts(stand)

	local upgradedStand = template:Clone()

	local success, upgradeError =
		pcall(function()
			upgradedStand.Name = stand.Name

			copyAttributes(
				stand,
				upgradedStand
			)

			upgradedStand:SetAttribute(
				"BusinessType",
				BUSINESS_NAME
			)

			upgradedStand:SetAttribute(
				"Level",
				nextLevel
			)

			upgradedStand:SetAttribute(
				"OwnerUserId",
				player.UserId
			)

			upgradedStand:SetAttribute(
				"PlotName",
				plot.Name
			)

			upgradedStand:SetAttribute(
				"StandUnavailable",
				false
			)

			upgradedStand:SetAttribute(
				"IsBeingEdited",
				false
			)

			setModelPlacedState(upgradedStand)

			local finalName = stand.Name

upgradedStand.Name =
	finalName .. "_UpgradePending"

upgradedStand:SetAttribute(
	"StandUnavailable",
	true
)

disablePrompts(
	upgradedStand
)

upgradedStand.Parent =
	placedBusinesses

upgradedStand:PivotTo(oldPivot)

-- Capture all final transforms AFTER PivotTo().
--
-- This is important because the construction animation
-- needs the world-space destination of every piece.
local constructionStates =
	getConstructionParts(upgradedStand)

prepareConstructionAnimation(
	constructionStates
)

-- Remove the old appearance only once the replacement is
-- fully prepared. That prevents a visible empty gap if
-- anything above fails.
stand:Destroy()

-- Give the replacement its real identity immediately.
-- Systems looking for this business can find the model,
-- while StandUnavailable keeps customers out.
upgradedStand.Name = finalName

-- Build the new appearance in place.
do
	local states =
		constructionStates

	for index, state in states do
		local stagger =
			constructionRandom:NextNumber(
				CONSTRUCTION_MIN_STAGGER,
				CONSTRUCTION_MAX_STAGGER
			)

		task.delay(
			(index - 1) * stagger,
			function()
				animateConstructionPart(
					state
				)
			end
		)
	end

	local maximumStagger =
		(#states - 1)
		* CONSTRUCTION_MAX_STAGGER

	task.wait(
		maximumStagger
			+ CONSTRUCTION_MOVE_TIME
			+ CONSTRUCTION_SETTLE_TIME
			+ 0.05
	)

	for _, state in states do
		if state.Part.Parent then
			state.Part.CFrame =
				state.FinalCFrame

			state.Part.Size =
				state.FinalSize

			state.Part.Transparency =
				state.FinalTransparency
		end
	end
end

-- The new stand becomes usable only after construction.
upgradedStand:SetAttribute(
	"StandUnavailable",
	false
)

restorePrompts(
	upgradedStand
)
		end)

	if not success then
		if upgradedStand.Parent then
			upgradedStand:Destroy()
		end

		stand:SetAttribute(
			"StandUnavailable",
			false
		)

		restorePrompts(stand)

		finish()

		warn(
			`Failed to upgrade {player.Name}'s stand: {upgradeError}`
		)

		sendResult(
			player,
			false,
			"The lemonade stand upgrade failed."
		)

		return
	end

	-- Charge only after the replacement model was created successfully.
	cash.Value -= upgradeCost

	if stand.Parent then
		stand:Destroy()
	end

	finish()

	sendResult(
		player,
		true,
		`Lemonade stand upgraded to Level {nextLevel}!`,
		nextLevel
	)
end

requestUpgradeRemote.OnServerEvent:Connect(
	function(
		player: Player,
		stand: Model
	)
		local currentTime = time()

		local previousRequest =
			lastRequests[player] or 0

		if currentTime - previousRequest
			< REQUEST_COOLDOWN then

			return
		end

		lastRequests[player] = currentTime

		performUpgrade(
			player,
			stand
		)
	end
)

Players.PlayerRemoving:Connect(function(player)
	lastRequests[player] = nil
	activeUpgrades[player] = nil
end)

print("BusinessUpgradeManager started.")