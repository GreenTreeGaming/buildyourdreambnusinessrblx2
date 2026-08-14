local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")


local BusinessConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("BusinessConfig")
	)


local businessModels =
	ReplicatedStorage:WaitForChild(
		"BusinessModels"
	)


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


local BUSINESS_NAME =
	"LemonadeStand"


local REQUEST_COOLDOWN =
	0.5


local MANAGEMENT_DISTANCE =
	22


--==================================================
-- APPEARANCE CONSTRUCTION ANIMATION
--==================================================

-- The old animation started at 8% size and 2.25 studs
-- underground. That made larger stands feel slow and messy.
--
-- This animation is intentionally fast and subtle.

-- Parts start only slightly below their final position.
local CONSTRUCTION_START_OFFSET =
	Vector3.new(
		0,
		-0.45,
		0
	)


-- They overshoot upward by a tiny amount before settling.
local CONSTRUCTION_OVERSHOOT =
	Vector3.new(
		0,
		0.08,
		0
	)


-- Start fairly close to final size.
-- This creates a quick "materialize/build" effect instead
-- of every object growing from nothing.
local CONSTRUCTION_START_SCALE =
	0.78


local MINIMUM_PART_SIZE =
	0.05


-- Main expansion/fade.
local CONSTRUCTION_APPEAR_TIME =
	0.16


-- Tiny settle movement after the initial pop.
local CONSTRUCTION_SETTLE_TIME =
	0.055


-- IMPORTANT:
-- This is the TOTAL amount of stagger across the ENTIRE
-- stand, not stagger-per-part.
--
-- That means huge Level 5 stands don't animate slower
-- simply because they contain more pieces.
local CONSTRUCTION_TOTAL_STAGGER =
	0.11


-- Small random variation prevents everything from looking
-- mechanically synchronized.
local CONSTRUCTION_RANDOM_JITTER =
	0.012


-- Brief completed-build flash.
local COMPLETION_FLASH_TIME =
	0.18


local constructionRandom =
	Random.new()


--==================================================
-- REMOTES
--==================================================

local requestUpgradeRemote =
	remotes:FindFirstChild(
		"RequestBusinessUpgrade"
	)


if not requestUpgradeRemote then

	requestUpgradeRemote =
		Instance.new(
			"RemoteEvent"
		)

	requestUpgradeRemote.Name =
		"RequestBusinessUpgrade"

	requestUpgradeRemote.Parent =
		remotes
end


local upgradeResultRemote =
	remotes:FindFirstChild(
		"BusinessUpgradeResult"
	)


if not upgradeResultRemote then

	upgradeResultRemote =
		Instance.new(
			"RemoteEvent"
		)

	upgradeResultRemote.Name =
		"BusinessUpgradeResult"

	upgradeResultRemote.Parent =
		remotes
end


local lastRequests: {
	[Player]: number
} = {}


local activeUpgrades: {
	[Player]: boolean
} = {}


--==================================================
-- BASIC HELPERS
--==================================================

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


local function getPlayerPlot(
	player: Player
): Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	if typeof(plotName)
		== "string" then

		local namedPlot =
			plotsFolder:FindFirstChild(
				plotName
			)


		if namedPlot
			and namedPlot:IsA(
				"Model"
			)
			and namedPlot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return namedPlot
		end
	end


	for _, instance in
		plotsFolder:GetChildren() do

		if not instance:IsA(
			"Model"
		) then

			continue
		end


		if instance:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return instance
		end
	end


	return nil
end


local function getPlacedBusinesses(
	plot: Model
): Instance?

	return plot:FindFirstChild(
		"PlacedBusinesses"
	)
end


local function getCashValue(
	player: Player
): IntValue?

	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)


	if not leaderstats then
		return nil
	end


	local cash =
		leaderstats:FindFirstChild(
			"Cash"
		)


	if cash
		and cash:IsA(
			"IntValue"
		) then

		return cash
	end


	return nil
end


local function getCurrentLevel(
	stand: Model
): number

	local value =
		stand:GetAttribute(
			"Level"
		)


	if typeof(value)
		~= "number" then

		return 1
	end


	if value % 1 ~= 0
		or value < 1 then

		return 1
	end


	return value
end


local function getStandLevelConfig(
	level: number
): {[string]: any}?

	local lemonadeConfig =
		BusinessConfig.LemonadeStand


	if typeof(lemonadeConfig)
		~= "table" then

		return nil
	end


	local standLevels =
		lemonadeConfig.StandLevels


	if typeof(standLevels)
		~= "table" then

		return nil
	end


	local levelConfig =
		standLevels[
			level
		]


	if typeof(levelConfig)
		~= "table" then

		return nil
	end


	return levelConfig
end


local function playerOwnsStand(
	player: Player,
	stand: Model,
	plot: Model
): boolean

	if plot:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return false
	end


	if stand:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return false
	end


	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	if not placedBusinesses then
		return false
	end


	return stand.Parent
		== placedBusinesses
end


local function setModelPlacedState(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			descendant.Anchored =
				true
		end
	end
end


--==================================================
-- PROMPTS
--==================================================

local PROMPT_ENABLED_ATTRIBUTE =
	"EnabledBeforeAppearanceUpgrade"


local function disablePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end


		descendant:SetAttribute(
			PROMPT_ENABLED_ATTRIBUTE,
			descendant.Enabled
		)


		descendant.Enabled =
			false
	end
end


local function restorePrompts(
	model: Model
)
	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"ProximityPrompt"
		) then

			continue
		end


		local previousState =
			descendant:GetAttribute(
				PROMPT_ENABLED_ATTRIBUTE
			)


		if typeof(previousState)
			== "boolean" then

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
	for attributeName, value in
		source:GetAttributes() do

		target:SetAttribute(
			attributeName,
			value
		)
	end
end


--==================================================
-- TEMPLATE VALIDATION
--==================================================

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


	for _, instanceName in
		requiredInstances do

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
		stand:GetAttribute(
			"BusinessType"
		)


	if businessType
		== BUSINESS_NAME then

		return true
	end


	return stand.Name
			== BUSINESS_NAME
		or string.match(
			stand.Name,
			"^LemonadeStand_"
		) ~= nil
end


--==================================================
-- CONSTRUCTION ANIMATION
--==================================================

type ConstructionPartState = {
	Part: BasePart,

	FinalCFrame: CFrame,
	FinalSize: Vector3,
	FinalTransparency: number,

	NormalizedHeight: number,
}


local IGNORED_CONSTRUCTION_NAMES = {
	PlacementOrigin = true,
	PlacementBounds = true,

	ManagementUIPosition = true,
	CooldownUIPosition = true,
	SaleEffectPosition = true,
	CustomerFacingPosition = true,
}


local function isConstructionVisual(
	part: BasePart
): boolean

	-- Invisible gameplay/helper parts should never animate.
	if part.Transparency
		>= 1 then

		return false
	end


	if IGNORED_CONSTRUCTION_NAMES[
		part.Name
	] then

		return false
	end


	-- Anything inside QueuePositions is gameplay-only.
	local current: Instance? =
		part.Parent


	while current do

		if current.Name
			== "QueuePositions" then

			return false
		end


		current =
			current.Parent
	end


	return true
end


local function getConstructionParts(
	model: Model
): {ConstructionPartState}

	local rawParts: {
		BasePart
	} = {}


	local minimumY =
		math.huge

	local maximumY =
		-math.huge


	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"BasePart"
		) then

			continue
		end


		if not isConstructionVisual(
			descendant
		) then

			continue
		end


		table.insert(
			rawParts,
			descendant
		)


		local y =
			descendant.Position.Y


		minimumY =
			math.min(
				minimumY,
				y
			)


		maximumY =
			math.max(
				maximumY,
				y
			)
	end


	local heightRange =
		math.max(
			maximumY - minimumY,
			0.001
		)


	local states: {
		ConstructionPartState
	} = {}


	for _, part in
		rawParts do

		local normalizedHeight =
			math.clamp(
				(
					part.Position.Y
					- minimumY
				)
					/ heightRange,

				0,
				1
			)


		table.insert(
			states,
			{
				Part =
					part,

				FinalCFrame =
					part.CFrame,

				FinalSize =
					part.Size,

				FinalTransparency =
					part.Transparency,

				NormalizedHeight =
					normalizedHeight,
			}
		)
	end


	-- Stable bottom-to-top ordering.
	table.sort(
		states,

		function(
			first: ConstructionPartState,
			second: ConstructionPartState
		): boolean

			return first.NormalizedHeight
				< second.NormalizedHeight
		end
	)


	return states
end


local function getScaledStartingSize(
	size: Vector3
): Vector3

	return Vector3.new(
		math.max(
			size.X
				* CONSTRUCTION_START_SCALE,

			MINIMUM_PART_SIZE
		),

		math.max(
			size.Y
				* CONSTRUCTION_START_SCALE,

			MINIMUM_PART_SIZE
		),

		math.max(
			size.Z
				* CONSTRUCTION_START_SCALE,

			MINIMUM_PART_SIZE
		)
	)
end


local function prepareConstructionAnimation(
	states: {
		ConstructionPartState
	}
)
	for _, state in
		states do

		local part =
			state.Part


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


		part.Transparency =
			1
	end
end


local function animateConstructionPart(
	state: ConstructionPartState
)
	local part =
		state.Part


	if not part.Parent then
		return
	end


	local overshootCFrame =
		state.FinalCFrame
			+ CONSTRUCTION_OVERSHOOT


	-- Quick expansion + fade + upward snap.
	local appearTween =
		TweenService:Create(
			part,

			TweenInfo.new(
				CONSTRUCTION_APPEAR_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				CFrame =
					overshootCFrame,

				Size =
					state.FinalSize,

				Transparency =
					state.FinalTransparency,
			}
		)


	appearTween:Play()


	appearTween.Completed:Wait()


	if not part.Parent then
		return
	end


	-- Very small settle downward into the exact final pose.
	local settleTween =
		TweenService:Create(
			part,

			TweenInfo.new(
				CONSTRUCTION_SETTLE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				CFrame =
					state.FinalCFrame,
			}
		)


	settleTween:Play()
end


local function playCompletionFlash(
	model: Model
)
	if not model.Parent then
		return
	end


	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		"UpgradeCompletionFlash"

	highlight.Adornee =
		model


	highlight.DepthMode =
		Enum.HighlightDepthMode.Occluded


	highlight.FillColor =
		Color3.fromRGB(
			255,
			238,
			150
		)


	highlight.OutlineColor =
		Color3.fromRGB(
			255,
			255,
			225
		)


	-- Starts as a subtle flash.
	highlight.FillTransparency =
		0.72

	highlight.OutlineTransparency =
		0.35


	highlight.Parent =
		model


	local tween =
		TweenService:Create(
			highlight,

			TweenInfo.new(
				COMPLETION_FLASH_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				FillTransparency =
					1,

				OutlineTransparency =
					1,
			}
		)


	tween:Play()


	tween.Completed:Once(
		function()

			if highlight.Parent then
				highlight:Destroy()
			end
		end
	)
end


local function playConstructionAnimation(
	model: Model,
	states: {
		ConstructionPartState
	}?
)
	local constructionStates =
		states
		or getConstructionParts(
			model
		)


	if #constructionStates == 0 then

		playCompletionFlash(
			model
		)

		return
	end


	prepareConstructionAnimation(
		constructionStates
	)


	-- Build bottom → top, but use each part's normalized
	-- height to determine its delay.
	--
	-- Total duration stays nearly constant regardless of
	-- whether the model contains 20 parts or 200.
	for _, state in
		constructionStates do

		local jitter =
			constructionRandom:NextNumber(
				0,
				CONSTRUCTION_RANDOM_JITTER
			)


		local delay =
			state.NormalizedHeight
				* CONSTRUCTION_TOTAL_STAGGER
				+ jitter


		task.delay(
			delay,

			function()
				animateConstructionPart(
					state
				)
			end
		)
	end


	local totalAnimationTime =
		CONSTRUCTION_TOTAL_STAGGER
			+ CONSTRUCTION_RANDOM_JITTER
			+ CONSTRUCTION_APPEAR_TIME
			+ CONSTRUCTION_SETTLE_TIME
			+ 0.025


	task.wait(
		totalAnimationTime
	)


	-- Force the exact final state.
	-- This protects against lag or interrupted tweens.
	for _, state in
		constructionStates do

		if state.Part.Parent then

			state.Part.CFrame =
				state.FinalCFrame


			state.Part.Size =
				state.FinalSize


			state.Part.Transparency =
				state.FinalTransparency
		end
	end


	playCompletionFlash(
		model
	)
end


--==================================================
-- UPGRADE PLACEMENT VALIDATION
--==================================================

local UPGRADE_EDGE_PADDING =
	0.5


local function rectanglesOverlapXZ(
	firstCFrame: CFrame,
	firstSize: Vector3,
	secondCFrame: CFrame,
	secondSize: Vector3
): boolean

	local firstRight =
		Vector3.new(
			firstCFrame.RightVector.X,
			0,
			firstCFrame.RightVector.Z
		).Unit


	local firstForward =
		Vector3.new(
			firstCFrame.LookVector.X,
			0,
			firstCFrame.LookVector.Z
		).Unit


	local secondRight =
		Vector3.new(
			secondCFrame.RightVector.X,
			0,
			secondCFrame.RightVector.Z
		).Unit


	local secondForward =
		Vector3.new(
			secondCFrame.LookVector.X,
			0,
			secondCFrame.LookVector.Z
		).Unit


	local offset =
		Vector3.new(
			secondCFrame.Position.X
				- firstCFrame.Position.X,

			0,

			secondCFrame.Position.Z
				- firstCFrame.Position.Z
		)


	local axes = {
		firstRight,
		firstForward,
		secondRight,
		secondForward,
	}


	local firstHalfX =
		firstSize.X / 2

	local firstHalfZ =
		firstSize.Z / 2


	local secondHalfX =
		secondSize.X / 2

	local secondHalfZ =
		secondSize.Z / 2


	for _, axis in
		axes do

		local distance =
			math.abs(
				offset:Dot(
					axis
				)
			)


		local firstRadius =
			math.abs(
				firstRight:Dot(
					axis
				)
			)
				* firstHalfX

			+ math.abs(
				firstForward:Dot(
					axis
				)
			)
				* firstHalfZ


		local secondRadius =
			math.abs(
				secondRight:Dot(
					axis
				)
			)
				* secondHalfX

			+ math.abs(
				secondForward:Dot(
					axis
				)
			)
				* secondHalfZ


		if distance
			>= firstRadius
				+ secondRadius then

			return false
		end
	end


	return true
end


local function isBoundingBoxInsideGround(
	ground: BasePart,
	boxCFrame: CFrame,
	boxSize: Vector3
): boolean

	local halfX =
		boxSize.X / 2

	local halfZ =
		boxSize.Z / 2


	local corners = {
		Vector3.new(
			-halfX,
			0,
			-halfZ
		),

		Vector3.new(
			-halfX,
			0,
			halfZ
		),

		Vector3.new(
			halfX,
			0,
			-halfZ
		),

		Vector3.new(
			halfX,
			0,
			halfZ
		),
	}


	local groundHalfX =
		ground.Size.X / 2
			- UPGRADE_EDGE_PADDING


	local groundHalfZ =
		ground.Size.Z / 2
			- UPGRADE_EDGE_PADDING


	for _, cornerOffset in
		corners do

		local worldCorner =
			boxCFrame:PointToWorldSpace(
				cornerOffset
			)


		local groundSpace =
			ground.CFrame:PointToObjectSpace(
				worldCorner
			)


		if math.abs(
			groundSpace.X
		) > groundHalfX
			or math.abs(
				groundSpace.Z
			) > groundHalfZ then

			return false
		end
	end


	return true
end

local function alignModelToStand(
	model: Model,
	targetStand: Model
)
	local sourceOrigin =
		model:FindFirstChild(
			"PlacementOrigin",
			true
		)

	local targetOrigin =
		targetStand:FindFirstChild(
			"PlacementOrigin",
			true
		)


	if not sourceOrigin
		or not sourceOrigin:IsA("BasePart") then

		error(
			`${model.Name} is missing PlacementOrigin.`
		)
	end


	if not targetOrigin
		or not targetOrigin:IsA("BasePart") then

		error(
			`${targetStand.Name} is missing PlacementOrigin.`
		)
	end


	-- We intentionally keep ONLY horizontal rotation.
	-- Any accidental X/Z rotation in either template is ignored.
	local _, sourceYaw, _ =
		sourceOrigin.CFrame:ToOrientation()

	local _, targetYaw, _ =
		targetOrigin.CFrame:ToOrientation()


	local cleanSource =
		CFrame.new(
			sourceOrigin.Position
		)
		* CFrame.Angles(
			0,
			sourceYaw,
			0
		)


	local cleanTarget =
		CFrame.new(
			targetOrigin.Position
		)
		* CFrame.Angles(
			0,
			targetYaw,
			0
		)


	local transform =
		cleanTarget
		* cleanSource:Inverse()


	model:PivotTo(
		transform
		* model:GetPivot()
	)
end


local function canUpgradeFit(
	plot: Model,
	currentStand: Model,
	upgradeTemplate: Model
): (boolean, string)

	local placedBusinesses =
		getPlacedBusinesses(
			plot
		)


	if not placedBusinesses then

		return false,
			"The plot is missing PlacedBusinesses."
	end


	local ground =
		plot:FindFirstChild(
			"Ground"
		)


	if not ground
		or not ground:IsA(
			"BasePart"
		) then

		return false,
			"The plot is missing Ground."
	end


	local preview =
	upgradeTemplate:Clone()


alignModelToStand(
	preview,
	currentStand
)


	local candidateBounds =
		preview:FindFirstChild(
			"PlacementBounds",
			true
		)


	if not candidateBounds
		or not candidateBounds:IsA(
			"BasePart"
		) then

		preview:Destroy()


		return false,
			"The upgraded stand is missing PlacementBounds."
	end


	local candidateCFrame =
		candidateBounds.CFrame


	local candidateSize =
		candidateBounds.Size


	if not isBoundingBoxInsideGround(
		ground,
		candidateCFrame,
		candidateSize
	) then

		preview:Destroy()


		return false,
			"Not enough room to upgrade here. Move the stand farther from the edge first."
	end


	for _, business in
		placedBusinesses:GetChildren() do

		if not business:IsA(
			"Model"
		)
			or business
				== currentStand then

			continue
		end


		local existingBounds =
			business:FindFirstChild(
				"PlacementBounds",
				true
			)


		if not existingBounds
			or not existingBounds:IsA(
				"BasePart"
			) then

			continue
		end


		if rectanglesOverlapXZ(
			candidateCFrame,
			candidateSize,
			existingBounds.CFrame,
			existingBounds.Size
		) then

			preview:Destroy()


			return false,
				"Not enough room to upgrade this stand. Move nearby businesses first."
		end
	end


	preview:Destroy()


	return true, ""
end


--==================================================
-- PERFORM UPGRADE
--==================================================

local function performUpgrade(
	player: Player,
	stand: Model
)
	if activeUpgrades[
		player
	] then

		return
	end


	activeUpgrades[
		player
	] = true


	local function finish()
		activeUpgrades[
			player
		] = nil
	end


	if typeof(stand)
			~= "Instance"
		or not stand:IsA(
			"Model"
		) then

		finish()


		sendResult(
			player,
			false,
			"The selected lemonade stand is invalid."
		)


		return
	end


	local plot =
		getPlayerPlot(
			player
		)


	if not plot then

		finish()


		sendResult(
			player,
			false,
			"You do not own a plot."
		)


		return
	end


	if not isLemonadeStand(
		stand
	) then

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


	if player:GetAttribute(
		"EditingBusiness"
	) then

		finish()


		sendResult(
			player,
			false,
			"Finish editing the stand before upgrading it."
		)


		return
	end


	if stand:GetAttribute(
		"IsBeingEdited"
	) == true then

		finish()


		sendResult(
			player,
			false,
			"This stand is currently being edited."
		)


		return
	end


	if stand:GetAttribute(
		"StandUnavailable"
	) == true then

		finish()


		sendResult(
			player,
			false,
			"This stand is currently unavailable."
		)


		return
	end


	local currentLevel =
		getCurrentLevel(
			stand
		)


	local currentConfig =
		getStandLevelConfig(
			currentLevel
		)


	if not currentConfig then

		finish()


		sendResult(
			player,
			false,
			"The current stand level is not configured."
		)


		return
	end


	local nextLevel =
		currentLevel + 1


	local nextConfig =
		getStandLevelConfig(
			nextLevel
		)


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


	if typeof(upgradeCost)
			~= "number"
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


	if typeof(templateName)
		~= "string" then

		finish()


		sendResult(
			player,
			false,
			"The next stand model is not configured."
		)


		return
	end


	local template =
		businessModels:FindFirstChild(
			templateName
		)


	if not template
		or not template:IsA(
			"Model"
		) then

		finish()


		sendResult(
			player,
			false,
			`${templateName} could not be found in BusinessModels.`
		)


		return
	end


	local templateValid,
		templateReason =
		validateUpgradeTemplate(
			template
		)


	if not templateValid then

		finish()


		sendResult(
			player,
			false,
			templateReason
		)


		return
	end


	local fitsUpgrade,
		fitReason =
		canUpgradeFit(
			plot,
			stand,
			template
		)


	if not fitsUpgrade then

		finish()


		sendResult(
			player,
			false,
			fitReason,
			currentLevel
		)


		return
	end


	local cash =
		getCashValue(
			player
		)


	if not cash then

		finish()


		sendResult(
			player,
			false,
			"Your cash value could not be found."
		)


		return
	end


	if cash.Value
		< upgradeCost then

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
		getPlacedBusinesses(
			plot
		)


	if not placedBusinesses then

		finish()


		sendResult(
			player,
			false,
			"The plot is missing PlacedBusinesses."
		)


		return
	end


	local oldPivot =
		stand:GetPivot()


	-- Prevent customers and prompts from interacting
	-- during the very short replacement animation.
	stand:SetAttribute(
		"StandUnavailable",
		true
	)


	disablePrompts(
		stand
	)


	local upgradedStand =
		template:Clone()


	local success,
		upgradeError =
		pcall(function()

			local finalName =
				stand.Name


			upgradedStand.Name =
				finalName
					.. "_UpgradePending"


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
				true
			)


			upgradedStand:SetAttribute(
				"IsBeingEdited",
				false
			)


			setModelPlacedState(
				upgradedStand
			)


			disablePrompts(
				upgradedStand
			)


			upgradedStand.Parent =
				placedBusinesses


			alignModelToStand(
	upgradedStand,
	stand
)


			-- Capture final transforms after PivotTo.
			local constructionStates =
				getConstructionParts(
					upgradedStand
				)


			-- Hide/shrink the new visual BEFORE destroying
			-- the old model, so there is never a visible
			-- frame where both full stands overlap.
			prepareConstructionAnimation(
				constructionStates
			)


			stand:Destroy()


			upgradedStand.Name =
				finalName


			-- Fast polished build.
			playConstructionAnimation(
				upgradedStand,
				constructionStates
			)


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


		if stand.Parent then

			stand:SetAttribute(
				"StandUnavailable",
				false
			)


			restorePrompts(
				stand
			)
		end


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


	-- Charge only after replacement succeeds.
	cash.Value -=
		upgradeCost


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


--==================================================
-- REMOTE CONNECTION
--==================================================

requestUpgradeRemote.OnServerEvent:Connect(
	function(
		player: Player,
		stand: Model
	)
		local currentTime =
			time()


		local previousRequest =
			lastRequests[
				player
			] or 0


		if currentTime
				- previousRequest
			< REQUEST_COOLDOWN then

			return
		end


		lastRequests[
			player
		] = currentTime


		performUpgrade(
			player,
			stand
		)
	end
)


Players.PlayerRemoving:Connect(
	function(
		player: Player
	)
		lastRequests[
			player
		] = nil


		activeUpgrades[
			player
		] = nil
	end
)


print(
	"BusinessUpgradeManager started."
)