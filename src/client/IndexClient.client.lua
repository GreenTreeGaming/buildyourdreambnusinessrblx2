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


type PreviewState = {
	Viewport: ViewportFrame,
	Camera: Camera,

	Target: Vector3,

	Radius: number,
	Height: number,

	Angle: number,
}


type CustomerEntry = {
	TypeName: string,
	DisplayName: string,
	Order: number,
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
	) :: GuiObject


local customerTemplate =
	customersFrame:WaitForChild(
		"Template"
	) :: Frame

--==================================================
-- INDEX UI LAYERING
--==================================================

-- Make ZIndex behave globally and predictably.
gui.ZIndexBehavior =
	Enum.ZIndexBehavior.Global


-- Content pages stay underneath the tab buttons.
businessesFrame.ZIndex =
	10

customersFrame.ZIndex =
	10


-- The tab bar must ALWAYS be above both scrolling frames.
buttons.ZIndex =
	100

businessesButton.ZIndex =
	101

customersButton.ZIndex =
	101


-- Text/icons inside the buttons should also stay above.
for _, descendant in
	buttons:GetDescendants() do

	if descendant:IsA(
		"GuiObject"
	) then

		descendant.ZIndex =
			math.max(
				descendant.ZIndex,
				102
			)
	end
end


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
	1 / MAX_SPIN_FPS


local LEVEL_TEXT_RESERVED_HEIGHT =
	22


local CUSTOMER_TEXT_RESERVED_HEIGHT =
	24


local CUSTOMER_ORDER = {
	"Regular",
	"Generous",
	"Rich",
	"VIP",
	"Celebrity",
	"Influencer",
	"Billionaire",
	"Golden",
}


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


local loading =
	false


local businessesBuilt =
	false


local customersBuilt =
	false


local previews: {
	[ViewportFrame]: PreviewState
} = {}


local spinAccumulator =
	0


businessTemplate.Visible =
	false


customerTemplate.Visible =
	false


--==================================================
-- GUI VISIBILITY
--==================================================

local function isGuiActuallyVisible(
	guiObject: GuiObject
): boolean

	local current: Instance? =
		guiObject


	while current do

		if current:IsA("GuiObject")
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
-- CAMERA ORBIT LOOP
--==================================================

RunService.RenderStepped:Connect(
	function(deltaTime: number)

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
					+ SPIN_SPEED
						* step
				)
				% (
					math.pi
					* 2
				)


			local angle =
				preview.Angle


			local cameraPosition =
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
					cameraPosition,
					preview.Target
				)
		end
	end
)


--==================================================
-- CLEAR GENERATED BUSINESSES
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


--==================================================
-- CLEAR GENERATED LEVELS
--==================================================

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


--==================================================
-- CLEAR GENERATED CUSTOMERS
--==================================================

local function clearGeneratedCustomers()

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
-- PREVIEW PART FILTER
--==================================================

local function isVisiblePreviewPart(
	part: BasePart
): boolean

	if part.Transparency
		>= 0.98 then

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
									halfSize.X
										* x,

									halfSize.Y
										* y,

									halfSize.Z
										* z
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

		local boundsCFrame,
			boundsSize =
			model:GetBoundingBox()


		return
			boundsCFrame.Position,
			boundsSize
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
-- PREPARE MODEL FOR VIEWPORT
--==================================================

local function prepareModelForViewport(
	model: Model,
	unlocked: boolean
)

	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"Script"
		)
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

			descendant.Enabled =
				false

			continue
		end


		if descendant:IsA(
			"Light"
		) then

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
-- CUSTOMER TYPE STYLE
--==================================================

local function createCustomerHighlight(
	model: Model,
	name: string,
	color: Color3,
	fillTransparency: number,
	outlineTransparency: number
)

	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		name


	highlight.Adornee =
		model


	highlight.FillColor =
		color


	highlight.FillTransparency =
		fillTransparency


	highlight.OutlineColor =
		color


	highlight.OutlineTransparency =
		outlineTransparency


	highlight.DepthMode =
		Enum.HighlightDepthMode
			.Occluded


	highlight.Parent =
		model
end


local function applyCustomerTypeStyle(
	model: Model,
	customerType: string
)

	local config =
		CustomerTypes.Types[
			customerType
		]


	if not config then
		return
	end


	if customerType
		== "Regular" then

		return
	end


	if customerType
		== "VIP" then

		createCustomerHighlight(
			model,
			"VIPHighlight",
			config.TextColor,
			0.9,
			0.35
		)


	elseif customerType
		== "Celebrity" then

		createCustomerHighlight(
			model,
			"CelebrityHighlight",
			config.TextColor,
			0.9,
			0.25
		)


	elseif customerType
		== "Influencer" then

		createCustomerHighlight(
			model,
			"InfluencerHighlight",
			config.TextColor,
			0.92,
			0.25
		)


	elseif customerType
		== "Billionaire" then

		createCustomerHighlight(
			model,
			"BillionaireHighlight",
			config.TextColor,
			0.92,
			0.2
		)


	elseif customerType
		== "Golden" then

		for _, descendant in
			model:GetDescendants() do

			if descendant:IsA(
				"BasePart"
			)
				and descendant.Name
					~= "HumanoidRootPart"
				and descendant.Transparency
					< 0.98 then

				descendant.Color =
					Color3.fromRGB(
						255,
						205,
						55
					)
			end
		end


		createCustomerHighlight(
			model,
			"GoldenAura",
			Color3.fromRGB(
				255,
				205,
				55
			),
			0.72,
			0.08
		)
	end
end


--==================================================
-- CAMERA DISTANCE
--==================================================

local function calculateCameraDistance(
	viewport: ViewportFrame,
	boundingSize: Vector3,
	padding: number
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
				verticalFov
					* 0.5
			)
			* aspectRatio
		)


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
		(
			horizontalDiameter
				* 0.5
		)
		/
		math.tan(
			horizontalFov
				* 0.5
		)


	local verticalDistance =
		(
			verticalDiameter
				* 0.5
		)
		/
		math.tan(
			verticalFov
				* 0.5
		)


	return
		math.max(
			horizontalDistance,
			verticalDistance
		)
		* padding
end


--==================================================
-- POPULATE GENERIC VIEWPORT
--==================================================

local function populateViewport(
	viewport: ViewportFrame,
	sourceModel: Model,
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


	local worldModel =
		Instance.new(
			"WorldModel"
		)


	worldModel.Name =
		"PreviewWorld"


	worldModel.Parent =
		viewport


	local model =
		sourceModel:Clone()


	model.Name =
		"PreviewModel"


	prepareModelForViewport(
		model,
		unlocked
	)


	if unlocked
		and customerType then

		applyCustomerTypeStyle(
			model,
			customerType
		)
	end


	model.Parent =
		worldModel


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
					boundingSize,
					padding
				)


			local lookTarget =
				visibleCenter
				+ Vector3.new(
					0,

					-boundingSize.Y
						* verticalOffset,

					0
				)


			local cameraHeight =
				boundingSize.Y
					* CAMERA_HEIGHT_RATIO


			local startingAngle =
				math.rad(
					25
				)


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


			previews[
				viewport
			] = {
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
-- BUSINESS VIEWPORT
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
			viewport.ZIndex + 2
		)


	levelCard.Parent =
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
-- BUILD BUSINESS INDEX
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


	businessesBuilt =
		true
end


--==================================================
-- CUSTOMER ENTRIES
--==================================================

local function getCustomerEntries(): {
	CustomerEntry
}

	local entries: {
		CustomerEntry
	} = {}


	for order, typeName in
		CUSTOMER_ORDER do

		local config =
			CustomerTypes.Types[
				typeName
			]


		if not config then
			continue
		end


		table.insert(
			entries,
			{
				TypeName =
					typeName,

				DisplayName =
					config.DisplayName
						or typeName,

				Order =
					order,
			}
		)
	end


	return entries
end


--==================================================
-- CUSTOMER CARD
--==================================================

local function createCustomerCard(
	entry: CustomerEntry
)

	local card =
		customerTemplate:Clone()


	card.Name =
		entry.TypeName


	card.Visible =
		true


	card.LayoutOrder =
		entry.Order


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


	customerType.Text =
		entry.DisplayName


	local config =
		CustomerTypes.Types[
			entry.TypeName
		]


	if config then

		customerType.TextColor3 =
			config.TextColor


		customerType.TextStrokeColor3 =
			config.StrokeColor
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


	card.Parent =
		customersFrame


	-- For now every customer type is visible.
	-- Later this can be replaced by saved discovery data.
	local discovered =
		true


	populateViewport(
		viewport,
		customerPreviewModel,
		discovered,
		CUSTOMER_CAMERA_PADDING,
		CUSTOMER_VERTICAL_OFFSET,
		entry.TypeName
	)
end


--==================================================
-- BUILD CUSTOMER INDEX
--==================================================

local function buildCustomerIndex()

	clearGeneratedCustomers()


	for _, entry in
		getCustomerEntries() do

		createCustomerCard(
			entry
		)
	end


	customersBuilt =
		true
end


--==================================================
-- REQUEST BUSINESS INDEX
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
-- BUSINESSES PAGE
--==================================================

local function showBusinesses()

	print("[Index] Businesses clicked")


	businessesFrame.Visible =
		true

	customersFrame.Visible =
		false


	businessesButton.BackgroundTransparency =
		0

	customersButton.BackgroundTransparency =
		0.2


	if not businessesBuilt then

		requestIndexState()
	end
end


--==================================================
-- CUSTOMERS PAGE
--==================================================

local function showCustomers()

	print("[Index] Customers clicked")


	-- Switch pages FIRST.
	businessesFrame.Visible =
		false

	customersFrame.Visible =
		true


	customersButton.BackgroundTransparency =
		0

	businessesButton.BackgroundTransparency =
		0.2


	-- Build after the page has already switched.
	task.defer(
		function()

			if not customersBuilt then

				buildCustomerIndex()
			end
		end
	)
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

			businessesBuilt =
				false


			if indexFrame.Visible
				and businessesFrame.Visible then

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

customerTemplate.Visible =
	false


businessesFrame.Visible =
	false

customersFrame.Visible =
	false


if indexFrame.Visible then

	showBusinesses()
end