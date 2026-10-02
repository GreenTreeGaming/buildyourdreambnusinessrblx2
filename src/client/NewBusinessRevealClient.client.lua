local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")


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


local businessUnlockedRemote =
	remotes:WaitForChild(
		"BusinessUnlocked"
	) :: RemoteEvent


--==================================================
-- UI
--==================================================

local screenGui =
	playerGui:WaitForChild(
		"NewBusinessReveal"
	) :: ScreenGui


local frame =
	screenGui:WaitForChild(
		"Frame"
	) :: Frame


local viewportFrame =
	frame:WaitForChild(
		"ViewportFrame"
	) :: ViewportFrame


local closeButton =
	frame:WaitForChild(
		"Close"
	) :: TextButton


local sunrays =
	frame:WaitForChild(
		"ImageLabel"
	) :: ImageLabel


local businessNameLabel =
	frame:WaitForChild(
		"BusinessName"
	) :: TextLabel


local aboutBusinessLabel =
	frame:WaitForChild(
		"AboutBusiness"
	) :: TextLabel


--==================================================
-- SETTINGS
--==================================================

--
-- Overall pacing.
--
local INTRO_TIME =
	0.3

local SILHOUETTE_WAIT =
	1.15

local REVEAL_TIME =
	0.6

local CLOSE_TIME =
	0.2


--
-- Camera.
--
local CAMERA_FOV =
	28

--
-- How much of the ViewportFrame the model should fill.
--
-- Higher = bigger.
--
local MODEL_SCREEN_FILL =
	0.82

local CAMERA_DEPTH_PADDING =
	0.18


--
-- Starting orientation.
--
local START_BACK_ROTATION =
	math.rad(165)

local REVEAL_OVERSHOOT =
	math.rad(-7)


--
-- Sunrays.
--
local SUNRAY_SPEED =
	18


--==================================================
-- STATE
--==================================================

local revealToken =
	0

local revealActive =
	false


local activeWorld:
	WorldModel? =
	nil


local activeModel:
	Model? =
	nil


local activeCamera:
	Camera? =
	nil


local centeredModelPivot =
	CFrame.new()


local finalYaw =
	0


--
-- Stores the real appearance of the cloned model
-- while it is temporarily turned into a silhouette.
--
local appearanceCache:
	{[Instance]: {[string]: any}} =
	{}


--==================================================
-- ORIGINAL UI VALUES
--==================================================

local originalFrameTransparency =
	frame.BackgroundTransparency


local originalViewportPosition =
	viewportFrame.Position


local originalSunrayPosition =
	sunrays.Position


local originalSunrayTransparency =
	sunrays.ImageTransparency


local originalNameTransparency =
	businessNameLabel.TextTransparency


local originalAboutTransparency =
	aboutBusinessLabel.TextTransparency


--==================================================
-- UI SCALE
--==================================================

local function getScale(
	object: GuiObject
): UIScale

	local current =
		object:FindFirstChild(
			"RevealScale"
		)


	if current
		and current:IsA("UIScale") then

		return current
	end


	local scale =
		Instance.new("UIScale")

	scale.Name =
		"RevealScale"

	scale.Scale =
		1

	scale.Parent =
		object


	return scale
end


local viewportScale =
	getScale(
		viewportFrame
	)


local raysScale =
	getScale(
		sunrays
	)


local nameScale =
	getScale(
		businessNameLabel
	)


local aboutScale =
	getScale(
		aboutBusinessLabel
	)


local closeScale =
	getScale(
		closeButton
	)


--==================================================
-- Z-INDEX / INPUT SAFETY
--==================================================

closeButton.Active =
	true

closeButton.Selectable =
	true

closeButton.AutoButtonColor =
	true

closeButton.ZIndex =
	100


for _, descendant in
	closeButton:GetDescendants() do

	if descendant:IsA("GuiObject") then

		descendant.ZIndex =
			math.max(
				descendant.ZIndex,
				101
			)

		--
		-- The TextLabel/ImageLabel inside the button
		-- must not eat button input.
		--
		descendant.Active =
			false
	end
end


--==================================================
-- HELPER / NON-VISUAL PART DETECTION
--==================================================

local EXACT_HELPER_NAMES = {

	PlacementBounds = true,
	PlacementOrigin = true,

	CustomerFacingPosition = true,
	CustomerPosition = true,

	QueuePosition = true,
	QueueStartPosition = true,
	QueueEndPosition = true,

	InteractionPosition = true,

	EmployeePosition = true,

	SpawnPosition = true,
}


local function isHelperPart(
	part: BasePart
): boolean

	if EXACT_HELPER_NAMES[
		part.Name
	] then

		return true
	end


	local lowerName =
		string.lower(
			part.Name
		)


	--
	-- Catch numbered queue/customer markers too:
	--
	-- QueuePosition1
	-- QueuePosition2
	-- CustomerPosition3
	-- etc.
	--
	if string.find(
		lowerName,
		"placementbounds",
		1,
		true
	) then

		return true
	end


	if string.find(
		lowerName,
		"placementorigin",
		1,
		true
	) then

		return true
	end


	if string.find(
		lowerName,
		"customerfacingposition",
		1,
		true
	) then

		return true
	end


	if string.find(
		lowerName,
		"queueposition",
		1,
		true
	) then

		return true
	end


	return false
end


local function isVisibleModelPart(
	part: BasePart
): boolean

	if isHelperPart(part) then
		return false
	end


	--
	-- Anything already intentionally invisible should
	-- not influence viewport camera sizing.
	--
	if part.Transparency >= 0.95 then
		return false
	end


	return true
end


--==================================================
-- CLEANUP
--==================================================

local function clearViewport()

	appearanceCache =
		{}


	if activeWorld then

		activeWorld:Destroy()

		activeWorld =
			nil
	end


	if activeCamera then

		activeCamera:Destroy()

		activeCamera =
			nil
	end


	activeModel =
		nil


	viewportFrame.CurrentCamera =
		nil
end


--==================================================
-- PREPARE CLONE
--==================================================

local function prepareModel(
	model: Model
)

	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA("BasePart") then

			descendant.Anchored =
				true

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false


			--
			-- Helper parts should NEVER appear
			-- in this reveal.
			--
			if isHelperPart(
				descendant
			) then

				descendant.Transparency =
					1
			end


		elseif descendant:IsA("Script")
			or descendant:IsA("LocalScript") then

			descendant.Enabled =
				false


		elseif descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui") then

			descendant.Enabled =
				false


		elseif descendant:IsA(
			"ProximityPrompt"
		) then

			descendant.Enabled =
				false
		end
	end
end


--==================================================
-- CUSTOM VISUAL BOUNDS
--==================================================

local function getVisualBounds(
	model: Model
): (
	Vector3?,
	Vector3?
)

	local minimum:
		Vector3? =
		nil


	local maximum:
		Vector3? =
		nil


	for _, descendant in
		model:GetDescendants() do

		if not descendant:IsA(
			"BasePart"
		) then

			continue
		end


		if not isVisibleModelPart(
			descendant
		) then

			continue
		end


		local half =
			descendant.Size
				/ 2


		local corners = {

			Vector3.new(
				-half.X,
				-half.Y,
				-half.Z
			),

			Vector3.new(
				-half.X,
				-half.Y,
				half.Z
			),

			Vector3.new(
				-half.X,
				half.Y,
				-half.Z
			),

			Vector3.new(
				-half.X,
				half.Y,
				half.Z
			),

			Vector3.new(
				half.X,
				-half.Y,
				-half.Z
			),

			Vector3.new(
				half.X,
				-half.Y,
				half.Z
			),

			Vector3.new(
				half.X,
				half.Y,
				-half.Z
			),

			Vector3.new(
				half.X,
				half.Y,
				half.Z
			),
		}


		for _, corner in corners do

			local world =
				descendant.CFrame
					:PointToWorldSpace(
						corner
					)


			if not minimum then

				minimum =
					world

				maximum =
					world

			else

				minimum =
					Vector3.new(
						math.min(
							minimum.X,
							world.X
						),

						math.min(
							minimum.Y,
							world.Y
						),

						math.min(
							minimum.Z,
							world.Z
						)
					)


				maximum =
					Vector3.new(
						math.max(
							maximum.X,
							world.X
						),

						math.max(
							maximum.Y,
							world.Y
						),

						math.max(
							maximum.Z,
							world.Z
						)
					)
			end
		end
	end


	if not minimum
		or not maximum then

		return nil, nil
	end


	local center =
		(
			minimum
				+ maximum
		) / 2


	local size =
		maximum
			- minimum


	return center,
		size
end


--==================================================
-- CENTER MODEL AROUND ITS VISIBLE GEOMETRY
--==================================================

local function centerVisualModel(
	model: Model
): boolean

	--
	-- First normalize the actual model pivot.
	--
	model:PivotTo(
		CFrame.new()
	)


	local center =
		getVisualBounds(
			model
		)


	if not center then
		return false
	end


	--
	-- Translate the MODEL PIVOT so that the center of
	-- visible geometry sits at world origin.
	--
	model:PivotTo(
		CFrame.new(
			-center.X,
			-center.Y,
			-center.Z
		)
	)


	centeredModelPivot =
		model:GetPivot()


	return true
end


--==================================================
-- SILHOUETTE
--==================================================

local function makeSilhouette(
	model: Model
)

	appearanceCache =
		{}


	for _, descendant in
		model:GetDescendants() do

		if descendant:IsA(
			"BasePart"
		) then

			--
			-- Do not make invisible helper parts black.
			-- They remain invisible.
			--
			if not isVisibleModelPart(
				descendant
			) then

				continue
			end


			appearanceCache[
				descendant
			] = {

				Color =
					descendant.Color,

				Material =
					descendant.Material,

				Reflectance =
					descendant.Reflectance,
			}


			if descendant:IsA(
				"MeshPart"
			) then

				appearanceCache[
					descendant
				].TextureID =
					descendant.TextureID


				descendant.TextureID =
					""
			end


			descendant.Color =
				Color3.new(
					0,
					0,
					0
				)


			descendant.Material =
				Enum.Material.SmoothPlastic


			descendant.Reflectance =
				0


		elseif descendant:IsA("Decal")
			or descendant:IsA("Texture") then

			appearanceCache[
				descendant
			] = {

				Transparency =
					descendant.Transparency,
			}


			descendant.Transparency =
				1
		end
	end
end


local function restoreAppearance()

	for instance, properties in
		appearanceCache do

		if not instance.Parent then
			continue
		end


		if instance:IsA(
			"BasePart"
		) then

			if properties.Color then

				instance.Color =
					properties.Color
			end


			if properties.Material then

				instance.Material =
					properties.Material
			end


			if typeof(
				properties.Reflectance
			) == "number" then

				instance.Reflectance =
					properties.Reflectance
			end


			if instance:IsA(
				"MeshPart"
			)
				and typeof(
					properties.TextureID
				) == "string" then

				instance.TextureID =
					properties.TextureID
			end


		elseif instance:IsA("Decal")
			or instance:IsA("Texture") then

			if typeof(
				properties.Transparency
			) == "number" then

				instance.Transparency =
					properties.Transparency
			end
		end
	end
end


--==================================================
-- LIGHTING
--==================================================

local function useSilhouetteLighting()

	--
	-- Completely black.
	--
	viewportFrame.Ambient =
		Color3.new(
			0,
			0,
			0
		)


	viewportFrame.LightColor =
		Color3.new(
			0,
			0,
			0
		)


	viewportFrame.LightDirection =
		Vector3.new(
			0,
			-1,
			0
		)
end


local function useRevealLighting()

	--
	-- Bright neutral lighting after the reveal.
	--
	viewportFrame.Ambient =
		Color3.fromRGB(
			150,
			150,
			150
		)


	viewportFrame.LightColor =
		Color3.fromRGB(
			255,
			248,
			235
		)


	viewportFrame.LightDirection =
		Vector3.new(
			-1,
			-1,
			-0.65
		)
end


--==================================================
-- CAMERA FIT
--==================================================

local function fitCamera(
	model: Model
)

	if not activeCamera then
		return
	end


	local center,
		size =
		getVisualBounds(
			model
		)


	if not center
		or not size then

		return
	end


	local absoluteSize =
		viewportFrame.AbsoluteSize


	local aspect =
		absoluteSize.Y > 0
		and (
			absoluteSize.X
				/ absoluteSize.Y
		)
		or 1


	local verticalFov =
		math.rad(
			activeCamera.FieldOfView
		)


	local horizontalFov =
		2
		* math.atan(
			math.tan(
				verticalFov / 2
			)
				* aspect
		)


	local heightDistance =
		(size.Y / 2)
		/ (
			math.tan(
				verticalFov / 2
			)
			* MODEL_SCREEN_FILL
		)


	local widthDistance =
		(size.X / 2)
		/ (
			math.tan(
				horizontalFov / 2
			)
			* MODEL_SCREEN_FILL
		)


	local distance =
		math.max(
			heightDistance,
			widthDistance
		)


	distance +=
		size.Z
			* CAMERA_DEPTH_PADDING


	--
	-- Center is now basically zero because we centered
	-- the model around visible geometry, but use the
	-- calculated value anyway.
	--
	local focus =
		center
			+ Vector3.new(
				0,
				size.Y * 0.01,
				0
			)


	--
	-- Camera sits on -Z looking toward the stand.
	--
	local position =
		focus
			+ Vector3.new(
				0,
				size.Y * 0.015,
				-distance
			)


	activeCamera.CFrame =
		CFrame.lookAt(
			position,
			focus
		)
end


--==================================================
-- CREATE VIEWPORT BUSINESS
--==================================================

local function createViewportBusiness(
	businessName: string
): Model?

	clearViewport()


	local config =
		BusinessConfig[
			businessName
		]


	if type(config)
		~= "table" then

		warn(
			`Missing BusinessConfig for {businessName}.`
		)

		return nil
	end


	local standLevels =
		config.StandLevels


	if type(standLevels)
		~= "table" then

		return nil
	end


	local levelOne =
		standLevels[1]


	if type(levelOne)
		~= "table" then

		return nil
	end


	local templateName =
		levelOne.TemplateName
		or businessName


	local template =
		businessModels:FindFirstChild(
			templateName
		)


	if not template
		or not template:IsA(
			"Model"
		) then

		warn(
			`BusinessModels.{templateName} was not found.`
		)

		return nil
	end


	local worldModel =
		Instance.new(
			"WorldModel"
		)


	worldModel.Name =
		"RevealWorld"


	worldModel.Parent =
		viewportFrame


	local model =
		template:Clone()


	model.Name =
		"RevealBusiness"


	prepareModel(
		model
	)


	model.Parent =
		worldModel


	if not centerVisualModel(
		model
	) then

		worldModel:Destroy()

		return nil
	end


	local camera =
		Instance.new(
			"Camera"
		)


	camera.Name =
		"RevealCamera"


	camera.FieldOfView =
		CAMERA_FOV


	camera.Parent =
		viewportFrame


	activeWorld =
		worldModel


	activeModel =
		model


	activeCamera =
		camera


	viewportFrame.CurrentCamera =
		camera


	--
	-- Optional per-business correction if a future model
	-- was built facing another direction.
	--
	finalYaw =
		math.rad(
			typeof(
				config.RevealYaw
			) == "number"
				and config.RevealYaw
				or 0
		)


	RunService.RenderStepped:Wait()


	--
	-- Camera fitting happens ONLY with the actual visible
	-- business geometry.
	--
	fitCamera(
		model
	)


	return model
end


--==================================================
-- CLEAN IMPACT SHAKE
--==================================================

local function impactShake(
	token: number
)

	task.spawn(
		function()

			local started =
				os.clock()


			local duration =
				0.24


			while revealToken == token
				and revealActive do

				local elapsed =
					os.clock()
						- started


				if elapsed >= duration then
					break
				end


				local progress =
					elapsed / duration


				local strength =
					(1 - progress)
						* 7


				local x =
					math.random(
						-100,
						100
					)
					/ 100
					* strength


				local y =
					math.random(
						-100,
						100
					)
					/ 100
					* strength


				--
				-- Shake the viewport only.
				-- Much cleaner than shaking every label.
				--
				viewportFrame.Position =
					UDim2.new(
						originalViewportPosition.X.Scale,

						originalViewportPosition.X.Offset
							+ x,

						originalViewportPosition.Y.Scale,

						originalViewportPosition.Y.Offset
							+ y
					)


				RunService.RenderStepped:Wait()
			end


			if revealToken == token then

				viewportFrame.Position =
					originalViewportPosition
			end
		end
	)
end


--==================================================
-- MODEL ROTATION
--==================================================

local function setModelYaw(
	model: Model,
	yaw: number,
	yOffset: number?
)

	local rotation =
		CFrame.Angles(
			0,
			yaw,
			0
		)


	--
	-- PRE-MULTIPLY the centered pivot.
	--
	-- This rotates around the visible center of the
	-- stand, not around PlacementOrigin sitting off-center.
	--
	model:PivotTo(
		CFrame.new(
			0,
			yOffset or 0,
			0
		)
			* rotation
			* centeredModelPivot
	)
end


--==================================================
-- MODEL REVEAL
--==================================================

local function animateModelReveal(
	model: Model,
	token: number
)

	local started =
		os.clock()


	while revealToken == token
		and revealActive
		and activeModel == model do

		local elapsed =
			os.clock()
				- started


		local alpha =
			math.clamp(
				elapsed / REVEAL_TIME,
				0,
				1
			)


		local yaw


		--
		-- First 80%:
		-- whip slightly past the front.
		--
		if alpha < 0.8 then

			local localAlpha =
				alpha / 0.8


			local eased =
				1
					- math.pow(
						1 - localAlpha,
						4
					)


			local start =
				finalYaw
					+ START_BACK_ROTATION


			local target =
				finalYaw
					+ REVEAL_OVERSHOOT


			yaw =
				start
					+ (
						target - start
					)
					* eased


		else

			--
			-- Final 20%:
			-- settle back from the overshoot.
			--
			local settle =
				(
					alpha - 0.8
				) / 0.2


			local eased =
				1
					- math.pow(
						1 - settle,
						2
					)


			yaw =
				(
					finalYaw
						+ REVEAL_OVERSHOOT
				)
				+ (
					-finalYaw
						- REVEAL_OVERSHOOT
						+ finalYaw
				)
				* eased
		end


		--
		-- Small lift during the spin.
		--
		local lift =
			math.sin(
				alpha * math.pi
			)
			* 0.12


		setModelYaw(
			model,
			yaw,
			lift
		)


		--
		-- Controlled punch.
		--
		local punch =
			math.sin(
				alpha
					* math.pi
			)


		viewportScale.Scale =
			1
				+ punch
					* 0.08


		if alpha >= 1 then
			break
		end


		RunService.RenderStepped:Wait()
	end


	if revealToken == token
		and activeModel == model then

		setModelYaw(
			model,
			finalYaw,
			0
		)


		viewportScale.Scale =
			1
	end
end


--==================================================
-- RESET
--==================================================

local function resetUI()

	frame.BackgroundTransparency =
		originalFrameTransparency


	viewportFrame.Position =
		originalViewportPosition


	--
	-- IMAGE TRANSPARENCY IS NEVER CHANGED.
	--
	sunrays.ImageTransparency =
		originalSunrayTransparency


	sunrays.Position =
		originalSunrayPosition


	viewportScale.Scale =
		1


	raysScale.Scale =
		1


	nameScale.Scale =
		1


	aboutScale.Scale =
		1


	closeScale.Scale =
		1


	businessNameLabel.TextTransparency =
		originalNameTransparency


	aboutBusinessLabel.TextTransparency =
		originalAboutTransparency


	closeButton.Visible =
		true


	closeButton.Active =
		true
end


--==================================================
-- CLOSE
--==================================================

local function closeReveal()

	if not revealActive then
		return
	end


	revealActive =
		false


	revealToken +=
		1


	local token =
		revealToken


	closeButton.Active =
		false


	TweenService:Create(
		viewportScale,

		TweenInfo.new(
			CLOSE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),

		{
			Scale =
				0.82,
		}
	):Play()


	TweenService:Create(
		nameScale,

		TweenInfo.new(
			CLOSE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),

		{
			Scale =
				0.85,
		}
	):Play()


	TweenService:Create(
		frame,

		TweenInfo.new(
			CLOSE_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),

		{
			BackgroundTransparency =
				1,
		}
	):Play()


	TweenService:Create(
		businessNameLabel,

		TweenInfo.new(
			CLOSE_TIME
		),

		{
			TextTransparency =
				1,
		}
	):Play()


	TweenService:Create(
		aboutBusinessLabel,

		TweenInfo.new(
			CLOSE_TIME
		),

		{
			TextTransparency =
				1,
		}
	):Play()


	task.delay(
		CLOSE_TIME + 0.04,
		function()

			if revealToken ~= token then
				return
			end


			frame.Visible =
				false


			clearViewport()


			useSilhouetteLighting()


			resetUI()
		end
	)
end


--==================================================
-- MAIN REVEAL
--==================================================

local function revealBusiness(
	businessName: string,
	displayName: string
)

	local config =
		BusinessConfig[
			businessName
		]


	if type(config)
		~= "table" then

		warn(
			`NewBusinessReveal: no config for {businessName}`
		)

		return
	end


	revealToken +=
		1


	local token =
		revealToken


	revealActive =
		true


	clearViewport()


	resetUI()


	useSilhouetteLighting()


	businessNameLabel.Text =
		displayName


	aboutBusinessLabel.Text =
		config.RevealDescription
		or "A brand-new business is now available to build!"


	local model =
		createViewportBusiness(
			businessName
		)


	if not model then

		revealActive =
			false

		return
	end


	--==================================================
	-- BLACK SILHOUETTE
	--==================================================

	makeSilhouette(
		model
	)


	local startingYaw =
		finalYaw
			+ START_BACK_ROTATION


	setModelYaw(
		model,
		startingYaw,
		0
	)


	--==================================================
	-- INITIAL UI
	--==================================================

	frame.Visible =
		true


	frame.BackgroundTransparency =
		1


	--
	-- Do not animate ImageTransparency.
	--
	sunrays.ImageTransparency =
		originalSunrayTransparency


	viewportScale.Scale =
		0.88


	raysScale.Scale =
		0.88


	nameScale.Scale =
		0.7


	aboutScale.Scale =
		0.85


	businessNameLabel.TextTransparency =
		1


	aboutBusinessLabel.TextTransparency =
		1


	--
	-- Hide Close completely until the reveal has landed.
	-- This also prevents accidental early clicks.
	--
	closeButton.Visible =
		false


	closeButton.Active =
		false


	--==================================================
	-- INTRO
	--==================================================

	TweenService:Create(
		frame,

		TweenInfo.new(
			INTRO_TIME,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			BackgroundTransparency =
				originalFrameTransparency,
		}
	):Play()


	TweenService:Create(
		viewportScale,

		TweenInfo.new(
			0.4,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),

		{
			Scale =
				1,
		}
	):Play()


	TweenService:Create(
		raysScale,

		TweenInfo.new(
			0.45,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),

		{
			Scale =
				1,
		}
	):Play()


	--==================================================
	-- WAIT, THEN REVEAL
	--==================================================

	task.delay(
		SILHOUETTE_WAIT,
		function()

			if revealToken ~= token
				or not revealActive
				or activeModel ~= model then

				return
			end


			--==================================================
			-- IMPACT
			--==================================================

			impactShake(
				token
			)


			useRevealLighting()


			restoreAppearance()


			task.spawn(
				function()

					animateModelReveal(
						model,
						token
					)
				end
			)


			--==================================================
			-- BUSINESS NAME
			--==================================================

			nameScale.Scale =
				0.6


			TweenService:Create(
				nameScale,

				TweenInfo.new(
					0.4,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						1,
				}
			):Play()


			TweenService:Create(
				businessNameLabel,

				TweenInfo.new(
					0.15,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					TextTransparency =
						originalNameTransparency,
				}
			):Play()


			--==================================================
			-- DESCRIPTION
			--==================================================

			task.delay(
				0.18,
				function()

					if revealToken
						~= token then

						return
					end


					aboutScale.Scale =
						0.82


					TweenService:Create(
						aboutScale,

						TweenInfo.new(
							0.3,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out
						),

						{
							Scale =
								1,
						}
					):Play()


					TweenService:Create(
						aboutBusinessLabel,

						TweenInfo.new(
							0.18
						),

						{
							TextTransparency =
								originalAboutTransparency,
						}
					):Play()
				end
			)


			--==================================================
			-- CLOSE BUTTON
			--==================================================

			task.delay(
				REVEAL_TIME + 0.12,
				function()

					if revealToken
						~= token
						or not revealActive then

						return
					end


					closeButton.Visible =
						true


					closeButton.Active =
						true


					closeScale.Scale =
						0.7


					TweenService:Create(
						closeScale,

						TweenInfo.new(
							0.3,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out
						),

						{
							Scale =
								1,
						}
					):Play()
				end
			)
		end
	)
end


--==================================================
-- SUNRAYS
--==================================================

RunService.RenderStepped:Connect(
	function(
		deltaTime: number
	)

		if not revealActive
			or not frame.Visible then

			return
		end


		sunrays.Rotation =
			(
				sunrays.Rotation
					+ SUNRAY_SPEED
						* deltaTime
			) % 360


		--
		-- ImageTransparency is intentionally NEVER
		-- changed anywhere in the animation.
		--
	end
)


--==================================================
-- CLOSE BUTTON
--==================================================

closeButton.Activated:Connect(
	function()

		closeReveal()
	end
)


--==================================================
-- BUSINESS UNLOCK
--==================================================

businessUnlockedRemote.OnClientEvent:Connect(
	function(
		businessName: string,
		displayName: string
	)

		revealBusiness(
			businessName,
			displayName
		)
	end
)


--==================================================
-- INITIAL STATE
--==================================================

frame.Visible =
	false


useSilhouetteLighting()


resetUI()


clearViewport()


--==================================================
-- TEMPORARY TEST
--
-- Uncomment this while tuning the reveal.
-- DELETE IT when finished.
--==================================================

-- task.delay(
-- 	2,
-- 	function()

-- 		revealBusiness(
-- 			"HotdogStand",
-- 			"Hotdog Stand"
-- 		)
-- 	end
-- )
