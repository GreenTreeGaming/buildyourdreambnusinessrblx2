local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local businessModels =
	ReplicatedStorage:WaitForChild(
		"BusinessModels"
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local getBusinessIndexState =
	remotes:WaitForChild(
		"GetBusinessIndexState"
	) :: RemoteFunction


--==================================================
-- TYPES
--==================================================

type LevelState = {
	Level: number,
	TemplateName: string,
	Unlocked: boolean,
}

type BusinessState = {
	BusinessType: string,
	DisplayName: string,
	DisplayOrder: number,

	Unlocked: boolean,
	HighestLevel: number,

	Levels: { LevelState },
}

type SpinningPreview = {
	Viewport: ViewportFrame,
	Camera: Camera,

	Target: Vector3,

	Radius: number,
	Height: number,

	Angle: number,
}


--==================================================
-- GUI
--==================================================

local gui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui

local main =
	gui:WaitForChild(
		"Main"
	) :: Frame

local indexFrame =
	main:WaitForChild(
		"IndexFrame"
	) :: Frame

local buttons =
	indexFrame:WaitForChild(
		"Buttons"
	) :: Frame

local businessesButton =
	buttons:WaitForChild(
		"Businesses"
	) :: TextButton

local customersButton =
	buttons:WaitForChild(
		"Customers"
	) :: TextButton

local businessesFrame =
	indexFrame:WaitForChild(
		"BusinessesFrame"
	) :: ScrollingFrame

local businessTemplate =
	businessesFrame:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- CONSTANTS
--==================================================

local UNLOCKED_AMBIENT =
	Color3.fromRGB(
		150,
		150,
		150
	)

local UNLOCKED_LIGHT =
	Color3.fromRGB(
		255,
		255,
		255
	)

local LOCKED_COLOR =
	Color3.fromRGB(
		0,
		0,
		0
	)


-- Camera FOV.
local VIEWPORT_FOV =
	32


-- Extra room around the model.
local CAMERA_PADDING =
	1.16


-- Slightly elevated camera.
local CAMERA_HEIGHT_RATIO =
	0.16


-- Moves what the camera is looking at slightly downward,
-- which makes the model appear a little higher in the card.
local VERTICAL_VISUAL_OFFSET =
	0.04


-- 18 degrees/sec = one rotation every 20 seconds.
local SPIN_SPEED =
	math.rad(18)


-- We no longer move models every frame.
-- Only their tiny ViewportFrame cameras move.
--
-- 60 FPS keeps the rotation completely smooth while still
-- using only one shared RenderStepped connection.
local MAX_SPIN_FPS =
	60

local SPIN_INTERVAL =
	1 / MAX_SPIN_FPS


-- Reserve this much room at the bottom of each level card
-- exclusively for "Level X".
local LEVEL_TEXT_RESERVED_HEIGHT =
	22


--==================================================
-- STATE
--==================================================

local currentIndexState: {
	BusinessState
} = {}

local loading =
	false


-- Keying by ViewportFrame makes cleanup easier.
local spinningPreviews: {
	[ViewportFrame]: SpinningPreview
} = {}


local spinAccumulator =
	0


businessTemplate.Visible =
	false


--==================================================
-- PREVIEW REGISTRATION
--==================================================

local function stopPreview(
	viewport: ViewportFrame
)
	spinningPreviews[viewport] =
		nil
end


local function clearAllPreviewRegistrations()
	for viewport in spinningPreviews do
		if not viewport.Parent then
			spinningPreviews[viewport] =
				nil
		end
	end
end


--==================================================
-- CAMERA SPIN LOOP
--==================================================

RunService.RenderStepped:Connect(
	function(deltaTime: number)

		-- Don't spend time rotating previews while
		-- the index isn't even being shown.
		if not indexFrame.Visible
			or not businessesFrame.Visible then

			spinAccumulator =
				0

			return
		end


		spinAccumulator +=
			deltaTime


		-- Prevent unnecessarily updating faster than
		-- the chosen preview FPS.
		if spinAccumulator
			< SPIN_INTERVAL then

			return
		end


		local step =
			math.min(
				spinAccumulator,
				0.1
			)

		spinAccumulator =
			0


		for viewport, preview in
			spinningPreviews do

			if not viewport.Parent
				or not preview.Camera.Parent then

				spinningPreviews[viewport] =
					nil

				continue
			end


			-- Don't update previews which aren't currently
			-- visible in the UI hierarchy.
			if not viewport.Visible then
				continue
			end


			preview.Angle =
				(
					preview.Angle
					+ SPIN_SPEED * step
				)
				% (math.pi * 2)


			local angle =
				preview.Angle


			-- Constant-radius orbit.
			--
			-- THIS is the important difference from the old
			-- version. The model itself never moves, meaning
			-- weird PrimaryParts / pivots cannot make a model
			-- swing outward and inward.
			local cameraPosition =
				preview.Target
				+ Vector3.new(
					math.sin(angle)
						* preview.Radius,

					preview.Height,

					math.cos(angle)
						* preview.Radius
				)


			preview.Camera.CFrame =
				CFrame.lookAt(
					cameraPosition,
					preview.Target
				)
		end
	end
)


--==================================================
-- CLEAN GENERATED BUSINESSES
--==================================================

local function clearGeneratedBusinesses()

	for _, child in
		businessesFrame:GetChildren() do

		if child == businessTemplate then
			continue
		end


		if child:IsA("GuiObject")
			and child:GetAttribute(
				"IndexGenerated"
			) == true then

			-- Remove ViewportFrames from the spin table
			-- immediately rather than waiting for the next
			-- RenderStepped cleanup pass.
			for _, descendant in
				child:GetDescendants() do

				if descendant:IsA(
					"ViewportFrame"
				) then

					stopPreview(
						descendant
					)
				end
			end


			child:Destroy()
		end
	end


	clearAllPreviewRegistrations()
end


--==================================================
-- CLEAN GENERATED LEVELS
--==================================================

local function clearGeneratedLevels(
	levelsFrame: Frame,
	levelTemplate: Frame
)

	for _, child in
		levelsFrame:GetChildren() do

		if child == levelTemplate then
			continue
		end


		if child:IsA("GuiObject")
			and child:GetAttribute(
				"IndexGenerated"
			) == true then

			for _, descendant in
				child:GetDescendants() do

				if descendant:IsA(
					"ViewportFrame"
				) then

					stopPreview(
						descendant
					)
				end
			end


			child:Destroy()
		end
	end
end


--==================================================
-- PREVIEW PART FILTER
--==================================================

local IGNORED_PREVIEW_NAMES = {
	"position",
	"queue",
	"waypoint",
	"interaction",

	"customerfacing",
	"customer facing",

	"editposition",
	"customerposition",
	"spawnposition",

	"placementorigin",
	"placementbounds",

	"managementuiposition",
	"cooldownuiposition",
	"saleeffectposition",
}


local function isVisiblePreviewPart(
	part: BasePart
): boolean

	if part.Transparency >= 0.98 then
		return false
	end


	local lowerName =
		string.lower(
			part.Name
		)


	for _, ignoredName in
		IGNORED_PREVIEW_NAMES do

		if string.find(
			lowerName,
			ignoredName,
			1,
			true
		) then

			return false
		end
	end


	return true
end


--==================================================
-- VISIBLE PARTS
--==================================================

local function getVisibleParts(
	model: Model
): { BasePart }

	local parts: { BasePart } =
		{}


	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"BasePart"
		) then

			continue
		end


		if not isVisiblePreviewPart(
			descendant
		) then

			continue
		end


		table.insert(
			parts,
			descendant
		)
	end


	return parts
end


--==================================================
-- VISIBLE BOUNDS
--==================================================

local function getVisibleBounds(
	model: Model
): (
	Vector3,
	Vector3
)

	local minimum: Vector3? =
		nil

	local maximum: Vector3? =
		nil


	-- This runs ONCE when a preview is created.
	-- It does not run every frame.
	for _, part in
		getVisibleParts(model) do

		local halfSize =
			part.Size * 0.5


		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do

					local corner =
						part.CFrame
							:PointToWorldSpace(
								Vector3.new(
									halfSize.X * x,
									halfSize.Y * y,
									halfSize.Z * z
								)
							)


					if not minimum
						or not maximum then

						minimum =
							corner

						maximum =
							corner

					else

						minimum =
							Vector3.new(
								math.min(
									minimum.X,
									corner.X
								),

								math.min(
									minimum.Y,
									corner.Y
								),

								math.min(
									minimum.Z,
									corner.Z
								)
							)


						maximum =
							Vector3.new(
								math.max(
									maximum.X,
									corner.X
								),

								math.max(
									maximum.Y,
									corner.Y
								),

								math.max(
									maximum.Z,
									corner.Z
								)
							)
					end
				end
			end
		end
	end


	if not minimum
		or not maximum then

		local boundingCFrame,
			boundingSize =
			model:GetBoundingBox()


		return
			boundingCFrame.Position,
			boundingSize
	end


	return
		(minimum + maximum) * 0.5,
		maximum - minimum
end


--==================================================
-- PREPARE MODEL
--==================================================

local function prepareModelForViewport(
	model: Model,
	unlocked: boolean
)

	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("Script")
			or descendant:IsA(
				"LocalScript"
			) then

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"BillboardGui"
		)
			or descendant:IsA(
				"SurfaceGui"
			) then

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"BasePart"
		) then

			descendant.Anchored =
				true

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false


			if not unlocked
				and isVisiblePreviewPart(
					descendant
				) then

				descendant.Color =
					LOCKED_COLOR

				descendant.Material =
					Enum.Material.SmoothPlastic

				descendant.Reflectance =
					0


				if descendant:IsA(
					"MeshPart"
				) then

					descendant.TextureID =
						""
				end
			end


			continue
		end


		if descendant:IsA(
			"ParticleEmitter"
		)
			or descendant:IsA(
				"Trail"
			)
			or descendant:IsA(
				"Beam"
			) then

			-- These previews are tiny.
			-- There is no reason to spend rendering time on
			-- particles/trails/beams in the index.
			descendant.Enabled =
				false

			continue
		end


		if descendant:IsA(
			"Light"
		) then

			-- ViewportFrame already provides lighting.
			descendant.Enabled =
				false

			continue
		end


		if not unlocked then

			if descendant:IsA(
				"Decal"
			)
				or descendant:IsA(
					"Texture"
				) then

				descendant.Transparency =
					1


			elseif descendant:IsA(
				"SurfaceAppearance"
			) then

				descendant:Destroy()
			end
		end
	end
end


--==================================================
-- CAMERA MATH
--==================================================

local function calculateCameraDistance(
	viewport: ViewportFrame,
	boundingSize: Vector3
): number

	local viewportSize =
		viewport.AbsoluteSize


	local aspectRatio =
		1


	if viewportSize.Y > 0 then

		aspectRatio =
			viewportSize.X
				/ viewportSize.Y
	end


	aspectRatio =
		math.max(
			aspectRatio,
			0.1
		)


	local verticalFov =
		math.rad(
			VIEWPORT_FOV
		)


	local horizontalFov =
		2
		* math.atan(
			math.tan(
				verticalFov * 0.5
			)
			* aspectRatio
		)


	-- The model can face any direction while the camera
	-- orbits it, so use the diagonal of the X/Z footprint.
	--
	-- This prevents wide businesses from clipping or
	-- appearing to zoom in/out at different angles.
	local horizontalDiameter =
		math.sqrt(
			boundingSize.X
				* boundingSize.X
			+
			boundingSize.Z
				* boundingSize.Z
		)


	local verticalDiameter =
		math.max(
			boundingSize.Y,
			0.5
		)


	local horizontalDistance =
		(horizontalDiameter * 0.5)
		/
		math.tan(
			horizontalFov * 0.5
		)


	local verticalDistance =
		(verticalDiameter * 0.5)
		/
		math.tan(
			verticalFov * 0.5
		)


	return
		math.max(
			horizontalDistance,
			verticalDistance
		)
		* CAMERA_PADDING
end


--==================================================
-- VIEWPORT
--==================================================

local function populateViewport(
	viewport: ViewportFrame,
	templateName: string,
	unlocked: boolean
)

	stopPreview(
		viewport
	)


	viewport:ClearAllChildren()


	viewport.ClipsDescendants =
		true


	if unlocked then

		viewport.Ambient =
			UNLOCKED_AMBIENT

		viewport.LightColor =
			UNLOCKED_LIGHT

		viewport.LightDirection =
			Vector3.new(
				-1,
				-1,
				-1
			)

	else

		viewport.Ambient =
			Color3.new(
				0,
				0,
				0
			)

		viewport.LightColor =
			Color3.new(
				0,
				0,
				0
			)

		viewport.LightDirection =
			Vector3.zero
	end


	local template =
		businessModels:FindFirstChild(
			templateName
		)


	if not template
		or not template:IsA(
			"Model"
		) then

		warn(
			`[Index] Missing business model "{templateName}".`
		)

		return
	end


	local worldModel =
		Instance.new(
			"WorldModel"
		)

	worldModel.Name =
		"PreviewWorld"

	worldModel.Parent =
		viewport


	local model =
		template:Clone()

	model.Name =
		"PreviewModel"


	prepareModelForViewport(
		model,
		unlocked
	)


	model.Parent =
		worldModel


	-- IMPORTANT:
	--
	-- We do NOT move the model to its PrimaryPart/pivot.
	-- The camera simply rotates around the actual visible
	-- center of the model.
	--
	-- This means PlacementOrigin, PrimaryPart and imported
	-- model pivots cannot cause the preview to orbit wildly.
	local visibleCenter,
		boundingSize =
		getVisibleBounds(
			model
		)


	local camera =
		Instance.new(
			"Camera"
		)

	camera.Name =
		"IndexCamera"

	camera.FieldOfView =
		VIEWPORT_FOV

	camera.Parent =
		viewport

	viewport.CurrentCamera =
		camera


	task.defer(
		function()

			if not viewport.Parent
				or not model.Parent
				or not camera.Parent then

				return
			end


			local distance =
				calculateCameraDistance(
					viewport,
					boundingSize
				)


			local lookTarget =
				visibleCenter
				+ Vector3.new(
					0,

					-boundingSize.Y
						* VERTICAL_VISUAL_OFFSET,

					0
				)


			local cameraHeight =
				boundingSize.Y
					* CAMERA_HEIGHT_RATIO


			local startingAngle =
				math.rad(25)


			camera.CFrame =
				CFrame.lookAt(
					lookTarget
						+ Vector3.new(
							math.sin(
								startingAngle
							)
								* distance,

							cameraHeight,

							math.cos(
								startingAngle
							)
								* distance
						),

					lookTarget
				)


			spinningPreviews[viewport] = {
				Viewport =
					viewport,

				Camera =
					camera,

				Target =
					lookTarget,

				Radius =
					distance,

				Height =
					cameraHeight,

				Angle =
					startingAngle,
			}
		end
	)
end


--==================================================
-- LEVEL CARD
--==================================================

local function createLevelCard(
	levelsFrame: Frame,
	levelTemplate: Frame,
	levelState: LevelState
)

	local levelCard =
		levelTemplate:Clone()


	levelCard.Name =
		`Level{levelState.Level}`

	levelCard.Visible =
		true

	levelCard.LayoutOrder =
		levelState.Level

	levelCard:SetAttribute(
		"IndexGenerated",
		true
	)


	local levelName =
		levelCard:WaitForChild(
			"LevelName"
		) :: TextLabel


	local viewport =
		levelCard:WaitForChild(
			"ViewportFrame"
		) :: ViewportFrame


	levelName.Text =
		`Level {levelState.Level}`


	--==================================================
	-- KEEP VIEWPORT ABOVE TEXT AREA
	--==================================================

	-- The old viewport could extend underneath LevelName,
	-- making models overlap/cut through the text.
	--
	-- Reserve a fixed bottom strip for the label.
	viewport.AnchorPoint =
		Vector2.new(
			0,
			0
		)

	viewport.Position =
		UDim2.new(
			0,
			0,

			0,
			0
		)

	viewport.Size =
		UDim2.new(
			1,
			0,

			1,
			-LEVEL_TEXT_RESERVED_HEIGHT
		)

	viewport.ClipsDescendants =
		true


	-- Keep the label above anything else in the card.
	levelName.ZIndex =
		math.max(
			levelName.ZIndex,
			viewport.ZIndex + 2
		)


	levelCard.Parent =
		levelsFrame


	populateViewport(
		viewport,
		levelState.TemplateName,
		levelState.Unlocked
	)
end


--==================================================
-- BUSINESS CARD
--==================================================

local function createBusinessCard(
	businessState: BusinessState
)

	local card =
		businessTemplate:Clone()


	card.Name =
		businessState.BusinessType

	card.Visible =
		true

	card.LayoutOrder =
		businessState.DisplayOrder

	card:SetAttribute(
		"IndexGenerated",
		true
	)


	local businessName =
		card:WaitForChild(
			"BusinessName"
		) :: TextLabel


	local levelsFrame =
		card:WaitForChild(
			"Levels"
		) :: Frame


	local levelTemplate =
		levelsFrame:WaitForChild(
			"Template"
		) :: Frame


	businessName.Text =
		businessState.DisplayName


	levelTemplate.Visible =
		false


	clearGeneratedLevels(
		levelsFrame,
		levelTemplate
	)


	card.Parent =
		businessesFrame


	for _, levelState in
		businessState.Levels do

		createLevelCard(
			levelsFrame,
			levelTemplate,
			levelState
		)
	end
end


--==================================================
-- BUILD INDEX
--==================================================

local function buildBusinessIndex(
	state: { BusinessState }
)

	clearGeneratedBusinesses()


	for _, businessState in
		state do

		createBusinessCard(
			businessState
		)
	end
end


--==================================================
-- REQUEST STATE
--==================================================

local function requestIndexState()

	if loading then
		return
	end


	loading =
		true


	task.spawn(
		function()

			local success,
				result =
				pcall(
					function()

						return getBusinessIndexState
							:InvokeServer()
					end
				)


			loading =
				false


			if not success
				or typeof(result)
					~= "table" then

				warn(
					"[Index] Failed to load business index."
				)

				return
			end


			currentIndexState =
				result


			buildBusinessIndex(
				currentIndexState
			)
		end
	)
end


--==================================================
-- INDEX SUB-PAGES
--==================================================

local function showBusinesses()

	businessesFrame.Visible =
		true


	businessesButton.BackgroundTransparency =
		0


	customersButton.BackgroundTransparency =
		0.2


	requestIndexState()
end


local function showCustomers()

	-- CustomersFrame comes later.
end


--==================================================
-- BUTTONS
--==================================================

businessesButton.Activated:Connect(
	showBusinesses
)


customersButton.Activated:Connect(
	showCustomers
)


--==================================================
-- INDEX OPEN
--==================================================

indexFrame:GetPropertyChangedSignal(
	"Visible"
):Connect(
	function()

		if not indexFrame.Visible then

			-- No camera updates are performed while hidden.
			spinAccumulator =
				0

			return
		end


		showBusinesses()
	end
)


--==================================================
-- LIVE REFRESH
--==================================================

local businessUnlocked =
	remotes:FindFirstChild(
		"BusinessUnlocked"
	)


if businessUnlocked
	and businessUnlocked:IsA(
		"RemoteEvent"
	) then

	businessUnlocked.OnClientEvent:Connect(
		function()

			if indexFrame.Visible then

				requestIndexState()
			end
		end
	)
end


local upgradeResult =
	remotes:FindFirstChild(
		"BusinessUpgradeResult"
	)


if upgradeResult
	and upgradeResult:IsA(
		"RemoteEvent"
	) then

	upgradeResult.OnClientEvent:Connect(
		function()

			if indexFrame.Visible then

				requestIndexState()
			end
		end
	)
end


--==================================================
-- INITIAL
--==================================================

businessTemplate.Visible =
	false

businessesFrame.Visible =
	false