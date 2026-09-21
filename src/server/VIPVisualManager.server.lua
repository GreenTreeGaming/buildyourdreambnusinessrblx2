local Players =
	game:GetService(
		"Players"
	)


--==================================================
-- CONSTANTS
--==================================================

local VISUAL_ROOT_NAME =
	"PlayerStatusVisuals"

local VIP_GOLD =
	Color3.fromRGB(
		255,
		210,
		45
	)

local VIP_LIGHT_GOLD =
	Color3.fromRGB(
		255,
		241,
		142
	)


--==================================================
-- REBIRTH TIERS
--==================================================

local REBIRTH_TIERS = {
	{
		Minimum = 20,

		Name = "MYTHIC EMPIRE",

		Color =
			Color3.fromRGB(
				255,
				86,
				225
			),

		Stroke =
			Color3.fromRGB(
				120,
				25,
				105
			),
	},

	{
		Minimum = 10,

		Name = "DIAMOND EMPIRE",

		Color =
			Color3.fromRGB(
				99,
				231,
				255
			),

		Stroke =
			Color3.fromRGB(
				24,
				104,
				140
			),
	},

	{
		Minimum = 5,

		Name = "GOLD EMPIRE",

		Color =
			Color3.fromRGB(
				255,
				205,
				49
			),

		Stroke =
			Color3.fromRGB(
				142,
				87,
				8
			),
	},

	{
		Minimum = 3,

		Name = "SILVER EMPIRE",

		Color =
			Color3.fromRGB(
				210,
				222,
				235
			),

		Stroke =
			Color3.fromRGB(
				89,
				102,
				120
			),
	},

	{
		Minimum = 1,

		Name = "BRONZE EMPIRE",

		Color =
			Color3.fromRGB(
				216,
				137,
				75
			),

		Stroke =
			Color3.fromRGB(
				105,
				53,
				22
			),
	},
}


local function getRebirthTier(
	rebirths: number
)

	for _, tier in
		REBIRTH_TIERS do

		if rebirths
			>= tier.Minimum then

			return tier
		end
	end


	return nil
end


--==================================================
-- CLEANUP
--==================================================

local function removeStatusVisuals(
	character: Model
)

	for _, descendant in
		character:GetDescendants() do

		if descendant.Name
			== VISUAL_ROOT_NAME then

			descendant:Destroy()
		end
	end
end


--==================================================
-- LABEL HELPER
--==================================================

local function createTagLabel(
	parent: Instance,
	text: string,
	color: Color3,
	strokeColor: Color3,
	position: UDim2,
	heightScale: number
)

	local label =
		Instance.new(
			"TextLabel"
		)

	label.Name =
		VISUAL_ROOT_NAME

	label.BackgroundTransparency =
		1

	label.Size =
		UDim2.new(
			1,
			0,
			heightScale,
			0
		)

	label.Position =
		position

	label.Text =
		text

	label.TextColor3 =
		color

	label.TextStrokeColor3 =
		strokeColor

	label.TextStrokeTransparency =
		0

	label.Font =
		Enum.Font.GothamBlack

	label.TextScaled =
		true

	label.Parent =
		parent


	local constraint =
		Instance.new(
			"UITextSizeConstraint"
		)

	constraint.MinTextSize =
		9

	constraint.MaxTextSize =
		18

	constraint.Parent =
		label
end


--==================================================
-- OVERHEAD STATUS
--==================================================

local function createOverheadTags(
	player: Player,
	character: Model
)

	local head =
		character:FindFirstChild(
			"Head"
		)


	if not head
		or not head:IsA(
			"BasePart"
		) then

		return
	end


	local hasVIP =
		player:GetAttribute(
			"HasVIP"
		) == true


	local rebirths =
		player:GetAttribute(
			"Rebirths"
		)


	if typeof(rebirths)
		~= "number" then

		rebirths =
			0
	end


	rebirths =
		math.max(
			0,
			math.floor(
				rebirths
			)
		)


	local rebirthTier =
		getRebirthTier(
			rebirths
		)


	if not hasVIP
		and not rebirthTier then

		return
	end


	local lineCount =
		0


	if hasVIP then

		lineCount +=
			1
	end


	if rebirthTier then

		lineCount +=
			1
	end


	local billboard =
		Instance.new(
			"BillboardGui"
		)

	billboard.Name =
		VISUAL_ROOT_NAME

	billboard.Adornee =
		head

	billboard.AlwaysOnTop =
		false

	billboard.MaxDistance =
		80

	billboard.Size =
		UDim2.fromOffset(
			180,
			lineCount == 2
				and 48
				or 26
		)

	billboard.StudsOffset =
		Vector3.new(
			0,
			lineCount == 2
				and 3.0
				or 2.75,
			0
		)

	billboard.Parent =
		head


	if hasVIP
		and rebirthTier then

		createTagLabel(
			billboard,

			"★ VIP ★",

			VIP_GOLD,

			Color3.fromRGB(
				92,
				60,
				0
			),

			UDim2.fromScale(
				0,
				0
			),

			0.5
		)


		createTagLabel(
			billboard,

			`◆ {rebirthTier.Name} ◆`,

			rebirthTier.Color,

			rebirthTier.Stroke,

			UDim2.fromScale(
				0,
				0.5
			),

			0.5
		)


	elseif hasVIP then

		createTagLabel(
			billboard,

			"★ VIP ★",

			VIP_GOLD,

			Color3.fromRGB(
				92,
				60,
				0
			),

			UDim2.fromScale(
				0,
				0
			),

			1
		)


	elseif rebirthTier then

		createTagLabel(
			billboard,

			`◆ {rebirthTier.Name} ◆`,

			rebirthTier.Color,

			rebirthTier.Stroke,

			UDim2.fromScale(
				0,
				0
			),

			1
		)
	end
end


--==================================================
-- VIP GOLD OUTLINE
--==================================================

local function createVIPHighlight(
	character: Model
)

	local highlight =
		Instance.new(
			"Highlight"
		)

	highlight.Name =
		VISUAL_ROOT_NAME

	highlight.Adornee =
		character

	highlight.FillTransparency =
		1

	highlight.OutlineTransparency =
		0.25

	highlight.OutlineColor =
		VIP_GOLD

	highlight.DepthMode =
		Enum.HighlightDepthMode.Occluded

	highlight.Parent =
		character
end


--==================================================
-- VIP SPARKLES
--==================================================

local function createVIPSparkles(
	character: Model
)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not root
		or not root:IsA(
			"BasePart"
		) then

		return
	end


	local attachment =
		Instance.new(
			"Attachment"
		)

	attachment.Name =
		VISUAL_ROOT_NAME

	attachment.Position =
		Vector3.new(
			0,
			0.4,
			0
		)

	attachment.Parent =
		root


	local particles =
		Instance.new(
			"ParticleEmitter"
		)

	particles.Name =
		VISUAL_ROOT_NAME

	particles.Texture =
		"rbxasset://textures/particles/sparkles_main.dds"

	particles.Color =
		ColorSequence.new(
			{
				ColorSequenceKeypoint.new(
					0,
					VIP_LIGHT_GOLD
				),

				ColorSequenceKeypoint.new(
					1,
					VIP_GOLD
				),
			}
		)

	particles.Transparency =
		NumberSequence.new(
			{
				NumberSequenceKeypoint.new(
					0,
					0.2
				),

				NumberSequenceKeypoint.new(
					0.7,
					0.35
				),

				NumberSequenceKeypoint.new(
					1,
					1
				),
			}
		)

	particles.Size =
		NumberSequence.new(
			{
				NumberSequenceKeypoint.new(
					0,
					0.22
				),

				NumberSequenceKeypoint.new(
					0.5,
					0.16
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			}
		)

	particles.Rate =
		3

	particles.Lifetime =
		NumberRange.new(
			0.9,
			1.5
		)

	particles.Speed =
		NumberRange.new(
			0.25,
			0.75
		)

	particles.SpreadAngle =
		Vector2.new(
			180,
			180
		)

	particles.Acceleration =
		Vector3.new(
			0,
			0.8,
			0
		)

	particles.RotSpeed =
		NumberRange.new(
			-30,
			30
		)

	particles.LightEmission =
		0.4

	particles.Parent =
		attachment
end


--==================================================
-- APPLY
--==================================================

local function applyStatusVisuals(
	player: Player,
	character: Model
)

	removeStatusVisuals(
		character
	)


	createOverheadTags(
		player,
		character
	)


	if player:GetAttribute(
		"HasVIP"
	) == true then

		createVIPHighlight(
			character
		)

		createVIPSparkles(
			character
		)
	end
end


--==================================================
-- PLAYER SETUP
--==================================================

local function setupPlayer(
	player: Player
)

	player.CharacterAdded:Connect(
		function(
			character: Model
		)

			character:WaitForChild(
				"Head",
				10
			)

			character:WaitForChild(
				"HumanoidRootPart",
				10
			)


			applyStatusVisuals(
				player,
				character
			)
		end
	)


	player:GetAttributeChangedSignal(
		"HasVIP"
	):Connect(
		function()

			local character =
				player.Character


			if character then

				applyStatusVisuals(
					player,
					character
				)
			end
		end
	)


	player:GetAttributeChangedSignal(
		"Rebirths"
	):Connect(
		function()

			local character =
				player.Character


			if character then

				applyStatusVisuals(
					player,
					character
				)
			end
		end
	)


	if player.Character then

		task.defer(
			applyStatusVisuals,
			player,
			player.Character
		)
	end
end


Players.PlayerAdded:Connect(
	setupPlayer
)


for _, player in
	Players:GetPlayers() do

	setupPlayer(
		player
	)
end