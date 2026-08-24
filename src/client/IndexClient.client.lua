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

	Levels: {LevelState},
}


type SpinningPreview = {
	Model: Model,
	BasePivot: CFrame,
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


local VIEWPORT_FOV =
	32


-- Lower = larger previews.
local CAMERA_PADDING =
	1.18


-- Camera elevation.
local CAMERA_HEIGHT_RATIO =
	0.20


-- Keeps the business slightly above the
-- LevelName without modifying any UI.
local VERTICAL_VISUAL_OFFSET =
	0.08


-- Full rotation speed.
-- 18 degrees/sec = 20 seconds per full rotation.
local SPIN_SPEED =
	math.rad(
		18
	)


--==================================================
-- STATE
--==================================================

local currentIndexState: {
	BusinessState
} = {}


local loading =
	false


local spinningPreviews: {
	[Model]: SpinningPreview
} = {}


businessTemplate.Visible =
	false


--==================================================
-- SPIN LOOP
--==================================================

RunService.RenderStepped:Connect(
	function(
		deltaTime: number
	)

		for model,
			preview in
			spinningPreviews do

			if not model.Parent then

				spinningPreviews[
					model
				] = nil

				continue
			end


			preview.Angle +=
				SPIN_SPEED
					* deltaTime


			model:PivotTo(
				preview.BasePivot
					* CFrame.Angles(
						0,
						preview.Angle,
						0
					)
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

			child:Destroy()
		end
	end
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

			child:Destroy()
		end
	end
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


	local ignoredNames = {
		"position",
		"queue",
		"waypoint",
		"interaction",
		"customerfacing",
		"customer facing",
		"editposition",
		"customerposition",
		"spawnposition",
	}


	for _, ignoredName in
		ignoredNames do

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
-- GET VISIBLE PARTS
--==================================================

local function getVisibleParts(
	model: Model
): {BasePart}

	local parts: {BasePart} =
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

	local minimum:
		Vector3? =
		nil


	local maximum:
		Vector3? =
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


					if not minimum then

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


		return boundingCFrame.Position,
			boundingSize
	end


	return (
		minimum
			+ maximum
	) * 0.5,
		maximum
			- minimum
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


			elseif descendant:IsA(
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


			elseif descendant:IsA(
				"Light"
			) then

				descendant.Enabled =
					false
			end
		end
	end
end


--==================================================
-- CENTER MODEL FOR SPINNING
--==================================================

local function centerModelForPreview(
	model: Model
): Vector3

	local center,
		size =
		getVisibleBounds(
			model
		)


	local currentPivot =
		model:GetPivot()


	-- Move the visual center to the origin.
	local offset =
		-center


	model:PivotTo(
		CFrame.new(
			currentPivot.Position
				+ offset
		)
		* currentPivot.Rotation
	)


	-- Recalculate after moving.
	local newCenter =
		getVisibleBounds(
			model
		)


	-- Small corrective move in case the model
	-- pivot/orientation caused any tiny offset.
	model:PivotTo(
		CFrame.new(
			-newCenter
		)
		* model:GetPivot()
	)


	return size
end


--==================================================
-- CAMERA
--==================================================

local function positionCamera(
	viewport: ViewportFrame,
	model: Model,
	boundingSize: Vector3
)

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


	-- Since the model spins, camera distance must
	-- account for either X or Z becoming the width.
	local horizontalSize =
		math.sqrt(
			boundingSize.X
				* boundingSize.X
				+
				boundingSize.Z
					* boundingSize.Z
		)


	local verticalSize =
		math.max(
			boundingSize.Y,
			0.5
		)


	horizontalSize =
		math.max(
			horizontalSize,
			0.5
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


	local verticalDistance =
		(verticalSize * 0.5)
			/
			math.tan(
				verticalFov
					* 0.5
			)


	local horizontalDistance =
		(horizontalSize * 0.5)
			/
			math.tan(
				horizontalFov
					* 0.5
			)


	local distance =
		math.max(
			verticalDistance,
			horizontalDistance
		)
		* CAMERA_PADDING


	local height =
		boundingSize.Y
			* CAMERA_HEIGHT_RATIO


	local lookTarget =
		Vector3.new(
			0,

			-boundingSize.Y
				* VERTICAL_VISUAL_OFFSET,

			0
		)


	local camera =
		Instance.new(
			"Camera"
		)


	camera.Name =
		"IndexCamera"


	camera.FieldOfView =
		VIEWPORT_FOV


	-- Camera stays still.
	-- The business rotates instead.
	camera.CFrame =
		CFrame.lookAt(
			Vector3.new(
				0,
				height,
				distance
			),

			lookTarget
		)


	camera.Parent =
		viewport


	viewport.CurrentCamera =
		camera
end


--==================================================
-- START SPINNING
--==================================================

local function startSpinning(
	model: Model
)

	spinningPreviews[
		model
	] = {
		Model =
			model,

		BasePivot =
			model:GetPivot(),

		Angle =
			0,
	}
end


--==================================================
-- VIEWPORT
--==================================================

local function populateViewport(
	viewport: ViewportFrame,
	templateName: string,
	unlocked: boolean
)

	viewport:ClearAllChildren()


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


	local boundingSize =
		centerModelForPreview(
			model
		)


	task.defer(
		function()

			if not viewport.Parent
				or not model.Parent then

				return
			end


			positionCamera(
				viewport,
				model,
				boundingSize
			)


			startSpinning(
				model
			)
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
	state: {BusinessState}
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