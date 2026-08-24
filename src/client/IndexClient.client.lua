local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local businessModels =
	ReplicatedStorage:WaitForChild(
		"BusinessModels"
	)


local CustomerTypes =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("CustomerTypes")
	)


local customerPreviewModel =
	ReplicatedStorage:WaitForChild(
		"CustomerPreviewModel"
	) :: Model


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getBusinessIndexState =
	remotes:WaitForChild(
		"GetBusinessIndexState"
	) :: RemoteFunction


local getCustomerIndexState =
	remotes:WaitForChild(
		"GetCustomerIndexState"
	) :: RemoteFunction


local customerVisitUpdated =
	remotes:WaitForChild(
		"CustomerVisitUpdated"
	) :: RemoteEvent


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

	Levels: {LevelState},
}


type CustomerState = {
	TypeName: string,
	DisplayName: string,
	Order: number,

	Visits: number,
	Discovered: boolean,
}


type PreviewState = {
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


local customersFrame =
	indexFrame:WaitForChild(
		"CustomersFrame"
	) :: ScrollingFrame


local customerTemplate =
	customersFrame:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- LAYERING
--==================================================

gui.ZIndexBehavior =
	Enum.ZIndexBehavior.Global


businessesFrame.ZIndex =
	10


customersFrame.ZIndex =
	10


buttons.ZIndex =
	100


businessesButton.ZIndex =
	101


customersButton.ZIndex =
	101


businessesButton.Active =
	true


customersButton.Active =
	true


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


local VIEWPORT_FOV =
	32


local BUSINESS_CAMERA_PADDING =
	1.16


local CUSTOMER_CAMERA_PADDING =
	1.32


local CAMERA_HEIGHT_RATIO =
	0.16


local BUSINESS_VERTICAL_OFFSET =
	0.04


local CUSTOMER_VERTICAL_OFFSET =
	0


local SPIN_SPEED =
	math.rad(
		18
	)


local MAX_SPIN_FPS =
	60


local SPIN_INTERVAL =
	1
	/ MAX_SPIN_FPS


local LEVEL_TEXT_RESERVED_HEIGHT =
	22


local CUSTOMER_TEXT_RESERVED_HEIGHT =
	42


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

	"humanoidrootpart",
}


--==================================================
-- STATE
--==================================================

local currentIndexState: {
	BusinessState
} = {}


local currentCustomerState: {
	CustomerState
} = {}


local loadingBusinesses =
	false


local loadingCustomers =
	false


local businessesBuilt =
	false


local customersBuilt =
	false


local previews: {
	[ViewportFrame]: PreviewState
} = {}


local customerCards: {
	[string]: Frame
} = {}


local spinAccumulator =
	0


businessTemplate.Visible =
	false


customerTemplate.Visible =
	false


--==================================================
-- ACTUAL GUI VISIBILITY
--==================================================

local function isGuiActuallyVisible(
	guiObject: GuiObject
): boolean

	local current: Instance? =
		guiObject


	while current do

		if current:IsA(
			"GuiObject"
		)
			and not current.Visible then

			return false
		end


		current =
			current.Parent
	end


	return true
end


--==================================================
-- PREVIEW REGISTRATION
--==================================================

local function stopPreview(
	viewport: ViewportFrame
)

	previews[
		viewport
	] = nil
end


local function unregisterPreviewsUnder(
	parent: Instance
)

	for _, descendant in
		parent:GetDescendants() do

		if descendant:IsA(
			"ViewportFrame"
		) then

			stopPreview(
				descendant
			)
		end
	end
end


local function cleanPreviewRegistrations()

	for viewport in previews do

		if not viewport.Parent then

			previews[
				viewport
			] = nil
		end
	end
end


--==================================================
-- CAMERA ORBIT
--==================================================

RunService.RenderStepped:Connect(
	function(
		deltaTime: number
	)

		if not indexFrame.Visible then

			spinAccumulator =
				0

			return
		end


		spinAccumulator +=
			deltaTime


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
			previews do

			if not viewport.Parent
				or not preview.Camera.Parent then

				previews[
					viewport
				] = nil

				continue
			end


			if not isGuiActuallyVisible(
				viewport
			) then

				continue
			end


			preview.Angle =
				(
					preview.Angle
					+
					SPIN_SPEED
						* step
				)
				%
				(
					math.pi
					* 2
				)


			local angle =
				preview.Angle


			local position =
				preview.Target
				+ Vector3.new(
					math.sin(
						angle
					)
						* preview.Radius,

					preview.Height,

					math.cos(
						angle
					)
						* preview.Radius
				)


			preview.Camera.CFrame =
				CFrame.lookAt(
					position,
					preview.Target
				)
		end
	end
)


--==================================================
-- CLEAN UI
--==================================================

local function clearGeneratedBusinesses()

	for _, child in
		businessesFrame:GetChildren() do

		if child
			== businessTemplate then

			continue
		end


		if child:IsA(
			"GuiObject"
		)
			and child:GetAttribute(
				"IndexGenerated"
			) == true then

			unregisterPreviewsUnder(
				child
			)

			child:Destroy()
		end
	end


	cleanPreviewRegistrations()
end


local function clearGeneratedLevels(
	levelsFrame: Frame,
	levelTemplate: Frame
)

	for _, child in
		levelsFrame:GetChildren() do

		if child
			== levelTemplate then

			continue
		end


		if child:IsA(
			"GuiObject"
		)
			and child:GetAttribute(
				"IndexGenerated"
			) == true then

			unregisterPreviewsUnder(
				child
			)

			child:Destroy()
		end
	end
end


local function clearGeneratedCustomers()

	table.clear(
		customerCards
	)


	for _, child in
		customersFrame:GetChildren() do

		if child
			== customerTemplate then

			continue
		end


		if child:IsA(
			"GuiObject"
		)
			and child:GetAttribute(
				"IndexGenerated"
			) == true then

			unregisterPreviewsUnder(
				child
			)

			child:Destroy()
		end
	end


	cleanPreviewRegistrations()
end


--==================================================
-- PART FILTER
--==================================================

local function isVisiblePreviewPart(
	part: BasePart
): boolean

	if part.Transparency
		>= 0.98 then

		return false
	end


	local name =
		string.lower(
			part.Name
		)


	for _, ignoredName in
		IGNORED_PREVIEW_NAMES do

		if string.find(
			name,
			ignoredName,
			1,
			true
		) then

			return false
		end
	end


	return true
end


local function getVisibleParts(
	model: Model
): {BasePart}

	local parts = {}


	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		)
			and isVisiblePreviewPart(
				descendant
			) then

			table.insert(
				parts,
				descendant
			)
		end
	end


	return parts
end


--==================================================
-- BOUNDS
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


	for _, part in
		getVisibleParts(
			model
		) do

		local halfSize =
			part.Size
				* 0.5


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

		local cf,
			size =
			model:GetBoundingBox()


		return
			cf.Position,
			size
	end


	return
		(
			minimum
			+ maximum
		)
			* 0.5,

		maximum
			- minimum
end


--==================================================
-- PREPARE PREVIEW MODEL
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
			)
			or descendant:IsA(
				"BillboardGui"
			)
			or descendant:IsA(
				"SurfaceGui"
			) then

			descendant:Destroy()

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

			descendant:Destroy()

			continue
		end


		if descendant:IsA(
			"Light"
		) then

			descendant.Enabled =
				false

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
					Enum.Material
						.SmoothPlastic

				descendant.Reflectance =
					0


				if descendant:IsA(
					"MeshPart"
				) then

					descendant.TextureID =
						""
				end
			end
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
-- CUSTOMER EFFECT HELPERS
--==================================================

local function createParticleEmitter(
	parent: BasePart,
	name: string,
	color: Color3,
	rate: number,
	lifetime: NumberRange,
	speed: NumberRange,
	size: NumberSequence
): ParticleEmitter

	local emitter =
		Instance.new(
			"ParticleEmitter"
		)


	emitter.Name =
		name


	emitter.Texture =
		"rbxasset://textures/particles/sparkles_main.dds"


	emitter.Color =
		ColorSequence.new(
			color
		)


	emitter.Rate =
		rate


	emitter.Lifetime =
		lifetime


	emitter.Speed =
		speed


	emitter.Size =
		size


	emitter.LightEmission =
		0.35


	emitter.SpreadAngle =
		Vector2.new(
			180,
			180
		)


	emitter.Rotation =
		NumberRange.new(
			0,
			360
		)


	emitter.RotSpeed =
		NumberRange.new(
			-35,
			35
		)


	emitter.Parent =
		parent


	return emitter
end


local function addCustomerEffects(
	model: Model,
	customerType: string
)

	local root =
		model:FindFirstChild(
			"HumanoidRootPart",
			true
		)


	local head =
		model:FindFirstChild(
			"Head",
			true
		)


	if not root
		or not root:IsA(
			"BasePart"
		)
		or not head
		or not head:IsA(
			"BasePart"
		) then

		return
	end


	if customerType
		== "VIP" then

		createParticleEmitter(
			head,
			"VIPSparkles",

			Color3.fromRGB(
				255,
				222,
				73
			),

			4,

			NumberRange.new(
				0.45,
				0.8
			),

			NumberRange.new(
				0.2,
				0.7
			),

			NumberSequence.new({
				NumberSequenceKeypoint.new(
					0,
					0.16
				),

				NumberSequenceKeypoint.new(
					0.5,
					0.22
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			})
		)


	elseif customerType
		== "Celebrity" then

		createParticleEmitter(
			head,
			"CelebrityStars",

			Color3.fromRGB(
				255,
				102,
				213
			),

			7,

			NumberRange.new(
				0.55,
				0.95
			),

			NumberRange.new(
				0.3,
				0.9
			),

			NumberSequence.new({
				NumberSequenceKeypoint.new(
					0,
					0.2
				),

				NumberSequenceKeypoint.new(
					0.5,
					0.28
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			})
		)


	elseif customerType
		== "Billionaire" then

		local emitter =
			createParticleEmitter(
				root,
				"BillionaireCash",

				Color3.fromRGB(
					77,
					255,
					126
				),

				6,

				NumberRange.new(
					0.7,
					1.1
				),

				NumberRange.new(
					0.6,
					1.2
				),

				NumberSequence.new({
					NumberSequenceKeypoint.new(
						0,
						0.22
					),

					NumberSequenceKeypoint.new(
						0.7,
						0.3
					),

					NumberSequenceKeypoint.new(
						1,
						0
					),
				})
			)


		emitter.Acceleration =
			Vector3.new(
				0,
				2.2,
				0
			)


	elseif customerType
		== "Golden" then

		local highlight =
			Instance.new(
				"Highlight"
			)


		highlight.Name =
			"GoldenAura"


		highlight.Adornee =
			model


		highlight.FillColor =
			Color3.fromRGB(
				255,
				196,
				42
			)


		highlight.FillTransparency =
			0.78


		highlight.OutlineColor =
			Color3.fromRGB(
				255,
				226,
				105
			)


		highlight.OutlineTransparency =
			0.15


		highlight.DepthMode =
			Enum.HighlightDepthMode
				.Occluded


		highlight.Parent =
			model


		local sparkles =
			createParticleEmitter(
				head,
				"GoldenSparkles",

				Color3.fromRGB(
					255,
					214,
					65
				),

				9,

				NumberRange.new(
					0.55,
					0.9
				),

				NumberRange.new(
					0.25,
					0.75
				),

				NumberSequence.new({
					NumberSequenceKeypoint.new(
						0,
						0.18
					),

					NumberSequenceKeypoint.new(
						0.5,
						0.3
					),

					NumberSequenceKeypoint.new(
						1,
						0
					),
				})
			)


		sparkles.LightEmission =
			0.65
	end
end


--==================================================
-- CAMERA DISTANCE
--==================================================

local function calculateCameraDistance(
	viewport: ViewportFrame,
	size: Vector3,
	padding: number
): number

	local viewportSize =
		viewport.AbsoluteSize


	local aspect =
		1


	if viewportSize.Y > 0 then

		aspect =
			viewportSize.X
				/ viewportSize.Y
	end


	aspect =
		math.max(
			aspect,
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
				verticalFov
					* 0.5
			)
			* aspect
		)


	local horizontalDiameter =
		math.sqrt(
			size.X * size.X
			+
			size.Z * size.Z
		)


	local verticalDiameter =
		math.max(
			size.Y,
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
		* padding
end


--==================================================
-- GENERIC VIEWPORT
--==================================================

local function populateViewport(
	viewport: ViewportFrame,
	source: Model,
	unlocked: boolean,
	padding: number,
	verticalOffset: number,
	customerType: string?
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
			Color3.zero

		viewport.LightColor =
			Color3.zero

		viewport.LightDirection =
			Vector3.zero
	end


	local world =
		Instance.new(
			"WorldModel"
		)


	world.Name =
		"PreviewWorld"


	world.Parent =
		viewport


	local model =
		source:Clone()


	model.Name =
		"PreviewModel"


	prepareModelForViewport(
		model,
		unlocked
	)


	model.Parent =
		world


	if unlocked
		and customerType then

		addCustomerEffects(
			model,
			customerType
		)
	end


	local center,
		size =
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
					size,
					padding
				)


			local target =
				center
				+ Vector3.new(
					0,
					-size.Y
						* verticalOffset,
					0
				)


			local height =
				size.Y
					* CAMERA_HEIGHT_RATIO


			local startingAngle =
				math.rad(
					25
				)


			camera.CFrame =
				CFrame.lookAt(
					target
						+ Vector3.new(
							math.sin(
								startingAngle
							)
								* distance,

							height,

							math.cos(
								startingAngle
							)
								* distance
						),

					target
				)


			previews[
				viewport
			] = {
				Viewport =
					viewport,

				Camera =
					camera,

				Target =
					target,

				Radius =
					distance,

				Height =
					height,

				Angle =
					startingAngle,
			}
		end
	)
end


--==================================================
-- BUSINESS PREVIEW
--==================================================

local function populateBusinessViewport(
	viewport: ViewportFrame,
	templateName: string,
	unlocked: boolean
)

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


	populateViewport(
		viewport,
		template,
		unlocked,
		BUSINESS_CAMERA_PADDING,
		BUSINESS_VERTICAL_OFFSET,
		nil
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

	local card =
		levelTemplate:Clone()


	card.Name =
		`Level{levelState.Level}`


	card.Visible =
		true


	card.LayoutOrder =
		levelState.Level


	card:SetAttribute(
		"IndexGenerated",
		true
	)


	local levelName =
		card:WaitForChild(
			"LevelName"
		) :: TextLabel


	local viewport =
		card:WaitForChild(
			"ViewportFrame"
		) :: ViewportFrame


	levelName.Text =
		`Level {levelState.Level}`


	viewport.AnchorPoint =
		Vector2.zero


	viewport.Position =
		UDim2.fromOffset(
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


	levelName.ZIndex =
		math.max(
			levelName.ZIndex,
			viewport.ZIndex
				+ 2
		)


	card.Parent =
		levelsFrame


	populateBusinessViewport(
		viewport,
		levelState.TemplateName,
		levelState.Unlocked
	)
end


--==================================================
-- BUSINESS CARD
--==================================================

local function createBusinessCard(
	state: BusinessState
)

	local card =
		businessTemplate:Clone()


	card.Name =
		state.BusinessType


	card.Visible =
		true


	card.LayoutOrder =
		state.DisplayOrder


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
		state.DisplayName


	levelTemplate.Visible =
		false


	clearGeneratedLevels(
		levelsFrame,
		levelTemplate
	)


	card.Parent =
		businessesFrame


	for _, levelState in
		state.Levels do

		createLevelCard(
			levelsFrame,
			levelTemplate,
			levelState
		)
	end
end


local function buildBusinessIndex(
	state: {BusinessState}
)

	clearGeneratedBusinesses()


	for _, business in state do

		createBusinessCard(
			business
		)
	end


	businessesBuilt =
		true
end


--==================================================
-- CUSTOMER CARD
--==================================================

local function createCustomerCard(
	state: CustomerState
)

	local card =
		customerTemplate:Clone()


	card.Name =
		state.TypeName


	card.LayoutOrder =
		state.Order


	card.Visible =
		true


	card:SetAttribute(
		"IndexGenerated",
		true
	)


	local viewport =
		card:WaitForChild(
			"ViewportFrame"
		) :: ViewportFrame


	local customerType =
		card:WaitForChild(
			"CustomerType"
		) :: TextLabel


	local customerAmount =
		card:WaitForChild(
			"CustomerAmount"
		) :: TextLabel


	local config =
		CustomerTypes.Types[
			state.TypeName
		]


	if state.Discovered then

		customerType.Text =
			state.DisplayName


		customerAmount.Text =
			`Visits: {state.Visits}`


		if config then

			customerType.TextColor3 =
				config.TextColor


			customerType.TextStrokeColor3 =
				config.StrokeColor
		end

	else

		customerType.Text =
			"???"


		customerAmount.Text =
			"Visits: 0"
	end


	viewport.AnchorPoint =
		Vector2.zero


	viewport.Position =
		UDim2.fromOffset(
			0,
			0
		)


	viewport.Size =
		UDim2.new(
			1,
			0,

			1,
			-CUSTOMER_TEXT_RESERVED_HEIGHT
		)


	viewport.ClipsDescendants =
		true


	customerType.ZIndex =
		math.max(
			customerType.ZIndex,
			viewport.ZIndex + 2
		)


	customerAmount.ZIndex =
		math.max(
			customerAmount.ZIndex,
			viewport.ZIndex + 2
		)


	card.Parent =
		customersFrame


	customerCards[
		state.TypeName
	] = card


	populateViewport(
		viewport,
		customerPreviewModel,
		state.Discovered,
		CUSTOMER_CAMERA_PADDING,
		CUSTOMER_VERTICAL_OFFSET,
		state.Discovered
			and state.TypeName
			or nil
	)
end


local function buildCustomerIndex(
	state: {CustomerState}
)

	clearGeneratedCustomers()


	table.sort(
		state,
		function(
			first: CustomerState,
			second: CustomerState
		)

			return first.Order
				< second.Order
		end
	)


	for _, customerState in
		state do

		createCustomerCard(
			customerState
		)
	end


	customersBuilt =
		true
end


--==================================================
-- BUSINESS STATE
--==================================================

local function requestBusinessState()

	if loadingBusinesses then
		return
	end


	loadingBusinesses =
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


			loadingBusinesses =
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
-- CUSTOMER STATE
--==================================================

local function requestCustomerState()

	if loadingCustomers then
		return
	end


	loadingCustomers =
		true


	task.spawn(
		function()

			local success,
				result =
				pcall(
					function()

						return getCustomerIndexState
							:InvokeServer()
					end
				)


			loadingCustomers =
				false


			if not success
				or typeof(result)
					~= "table" then

				warn(
					"[Index] Failed to load customer index."
				)

				return
			end


			currentCustomerState =
				result


			buildCustomerIndex(
				currentCustomerState
			)
		end
	)
end


--==================================================
-- PAGE SWITCHING
--==================================================

local function showBusinesses()

	businessesFrame.Visible =
		true


	customersFrame.Visible =
		false


	businessesButton.BackgroundTransparency =
		0


	customersButton.BackgroundTransparency =
		0.2


	if not businessesBuilt then

		requestBusinessState()
	end
end


local function showCustomers()

	businessesFrame.Visible =
		false


	customersFrame.Visible =
		true


	customersButton.BackgroundTransparency =
		0


	businessesButton.BackgroundTransparency =
		0.2


	if not customersBuilt then

		requestCustomerState()
	end
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
-- LIVE CUSTOMER VISITS
--==================================================

customerVisitUpdated.OnClientEvent:Connect(
	function(
		customerType: string,
		newAmount: number
	)

		if typeof(customerType)
			~= "string"
			or typeof(newAmount)
				~= "number" then

			return
		end


		-- Rebuild when first discovered so the
		-- silhouette becomes its full model/effects.
		local wasDiscovered =
			false


		for _, state in
			currentCustomerState do

			if state.TypeName
				~= customerType then

				continue
			end


			wasDiscovered =
				state.Discovered


			state.Visits =
				newAmount


			state.Discovered =
				newAmount > 0


			break
		end


		if not customersBuilt then
			return
		end


		if not wasDiscovered
			and newAmount > 0 then

			requestCustomerState()

			return
		end


		local card =
			customerCards[
				customerType
			]


		if not card then
			return
		end


		local amount =
			card:FindFirstChild(
				"CustomerAmount"
			)


		if amount
			and amount:IsA(
				"TextLabel"
			) then

			amount.Text =
				`Visits: {math.max(
					0,
					math.floor(
						newAmount
					)
				)}`
		end
	end
)


--==================================================
-- INDEX OPEN
--==================================================

indexFrame:GetPropertyChangedSignal(
	"Visible"
):Connect(
	function()

		if not indexFrame.Visible then

			spinAccumulator =
				0

			return
		end


		showBusinesses()
	end
)


--==================================================
-- LIVE BUSINESS REFRESH
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

			businessesBuilt =
				false


			if indexFrame.Visible
				and businessesFrame.Visible then

				requestBusinessState()
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

			businessesBuilt =
				false


			if indexFrame.Visible
				and businessesFrame.Visible then

				requestBusinessState()
			end
		end
	)
end


--==================================================
-- INITIAL
--==================================================

businessTemplate.Visible =
	false


customerTemplate.Visible =
	false


businessesFrame.Visible =
	false


customersFrame.Visible =
	false


if indexFrame.Visible then

	showBusinesses()
end