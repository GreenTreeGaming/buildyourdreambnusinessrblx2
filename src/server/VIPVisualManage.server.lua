local Players =
	game:GetService("Players")


--==================================================
-- CONSTANTS
--==================================================

local VIP_VISUAL_NAME =
	"VIPVisuals"

local GOLD =
	Color3.fromRGB(
		255,
		210,
		45
	)

local LIGHT_GOLD =
	Color3.fromRGB(
		255,
		241,
		142
	)


--==================================================
-- CLEANUP
--==================================================

local function removeVIPVisuals(
	character: Model
)
	for _, descendant in
		character:GetDescendants() do

		if descendant.Name
			== VIP_VISUAL_NAME then

			descendant:Destroy()
		end
	end
end


--==================================================
-- OVERHEAD TAG
--==================================================

local function createVIPTag(
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


	local billboard =
		Instance.new(
			"BillboardGui"
		)

	billboard.Name =
		VIP_VISUAL_NAME

	billboard.Adornee =
		head

	billboard.Size =
		UDim2.fromOffset(
			120,
			30
		)

	billboard.StudsOffset =
		Vector3.new(
			0,
			2.6,
			0
		)

	billboard.AlwaysOnTop =
		false

	billboard.MaxDistance =
		75

	billboard.Parent =
		head


	local label =
		Instance.new(
			"TextLabel"
		)

	label.Name =
		"VIP"

	label.Size =
		UDim2.fromScale(
			1,
			1
		)

	label.BackgroundTransparency =
		1

	label.Text =
		"★ VIP ★"

	label.TextColor3 =
		GOLD

	label.TextStrokeColor3 =
		Color3.fromRGB(
			92,
			60,
			0
		)

	label.TextStrokeTransparency =
		0

	label.Font =
		Enum.Font.GothamBlack

	label.TextScaled =
		true

	label.Parent =
		billboard


	local constraint =
		Instance.new(
			"UITextSizeConstraint"
		)

	constraint.MinTextSize =
		10

	constraint.MaxTextSize =
		20

	constraint.Parent =
		label
end


--==================================================
-- GOLD OUTLINE
--==================================================

local function createVIPHighlight(
	character: Model
)
	local highlight =
		Instance.new(
			"Highlight"
		)

	highlight.Name =
		VIP_VISUAL_NAME

	highlight.Adornee =
		character

	-- Outline only.
	highlight.FillTransparency =
		1

	highlight.OutlineTransparency =
		0.25

	highlight.OutlineColor =
		GOLD

	-- Do not show through walls.
	highlight.DepthMode =
		Enum.HighlightDepthMode.Occluded

	highlight.Parent =
		character
end


--==================================================
-- GOLD SPARKLES
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
		VIP_VISUAL_NAME

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
		VIP_VISUAL_NAME

	particles.Texture =
		"rbxasset://textures/particles/sparkles_main.dds"

	particles.Color =
		ColorSequence.new(
			{
				ColorSequenceKeypoint.new(
					0,
					LIGHT_GOLD
				),

				ColorSequenceKeypoint.new(
					1,
					GOLD
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

	-- Intentionally subtle.
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

local function applyVIPVisuals(
	player: Player,
	character: Model
)
	removeVIPVisuals(
		character
	)


	if player:GetAttribute(
		"HasVIP"
	) ~= true then

		return
	end


	createVIPTag(
		character
	)

	createVIPHighlight(
		character
	)

	createVIPSparkles(
		character
	)
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

			applyVIPVisuals(
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

				applyVIPVisuals(
					player,
					character
				)
			end
		end
	)


	if player.Character then

		task.defer(
			applyVIPVisuals,
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