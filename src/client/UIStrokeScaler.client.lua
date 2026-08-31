local Players =
	game:GetService("Players")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


local camera =
	Workspace.CurrentCamera


--==================================================
-- SETTINGS
--==================================================

-- The resolution your UI was primarily designed around.
--
-- 1920x1080 is a good baseline if your UI currently
-- looks how you want it on a normal PC display.
local BASE_RESOLUTION =
	Vector2.new(
		1920,
		1080
	)


-- Never allow strokes to become ridiculously thin.
--
-- Example:
-- A 3px desktop stroke can become:
--
-- 3 * 0.55 = 1.65px
--
-- instead of becoming nearly invisible.
local MIN_SCALE =
	0.55


-- Prevent strokes from becoming enormous on
-- unusually large/high-resolution displays.
local MAX_SCALE =
	1.15


--==================================================
-- STATE
--==================================================

local registeredStrokes: {
	[UIStroke]: number
} = {}


local destroyingConnections: {
	[UIStroke]: RBXScriptConnection
} = {}


--==================================================
-- SCALE CALCULATION
--==================================================

local function getStrokeScale(): number

	local viewport =
		camera.ViewportSize


	if viewport.X <= 0
		or viewport.Y <= 0 then

		return 1
	end


	-- Compare both dimensions instead of just width.
	--
	-- Using the smaller ratio prevents weird behavior
	-- on very wide phones or unusual aspect ratios.
	local widthScale =
		viewport.X
		/ BASE_RESOLUTION.X


	local heightScale =
		viewport.Y
		/ BASE_RESOLUTION.Y


	local scale =
		math.min(
			widthScale,
			heightScale
		)


	return math.clamp(
		scale,
		MIN_SCALE,
		MAX_SCALE
	)
end


--==================================================
-- APPLY
--==================================================

local function updateStroke(
	stroke: UIStroke
)

	local originalThickness =
		registeredStrokes[
			stroke
		]


	if not originalThickness then
		return
	end


	-- Allow individual strokes to opt out.
	if stroke:GetAttribute(
		"DisableAutoStrokeScaling"
	) == true then

		stroke.Thickness =
			originalThickness


		return
	end


	local scale =
		getStrokeScale()


	stroke.Thickness =
		originalThickness
		* scale
end


local function updateAllStrokes()

	for stroke in
		registeredStrokes do

		if stroke.Parent then

			updateStroke(
				stroke
			)

		end
	end
end


--==================================================
-- REGISTRATION
--==================================================

local function unregisterStroke(
	stroke: UIStroke
)

	registeredStrokes[
		stroke
	] = nil


	local connection =
		destroyingConnections[
			stroke
		]


	if connection then

		connection:Disconnect()


		destroyingConnections[
			stroke
		] = nil

	end
end


local function registerStroke(
	stroke: UIStroke
)

	if registeredStrokes[
		stroke
	] then

		return
	end


	-- Remember the value YOU designed the UI with.
	--
	-- This is important because otherwise every
	-- viewport resize would scale an already-scaled
	-- value and slowly destroy the original thickness.
	local originalThickness =
		stroke:GetAttribute(
			"OriginalStrokeThickness"
		)


	if typeof(originalThickness)
		~= "number" then

		originalThickness =
			stroke.Thickness


		stroke:SetAttribute(
			"OriginalStrokeThickness",
			originalThickness
		)

	end


	registeredStrokes[
		stroke
	] =
		originalThickness


	destroyingConnections[
		stroke
	] =
		stroke.Destroying:Connect(
			function()

				unregisterStroke(
					stroke
				)

			end
		)


	updateStroke(
		stroke
	)
end


--==================================================
-- INITIAL UI
--==================================================

for _, descendant in
	playerGui:GetDescendants() do

	if descendant:IsA(
		"UIStroke"
	) then

		registerStroke(
			descendant
		)

	end
end


--==================================================
-- DYNAMIC UI
--==================================================

-- This handles:
--
-- cloned buttons
-- popup UIs
-- notifications
-- quest templates
-- management cards
-- business UIs
-- future systems
--
-- basically anything added to PlayerGui later.
playerGui.DescendantAdded:Connect(
	function(
		descendant: Instance
	)

		if descendant:IsA(
			"UIStroke"
		) then

			registerStroke(
				descendant
			)

		end
	end
)


--==================================================
-- SCREEN RESIZE
--==================================================

camera:GetPropertyChangedSignal(
	"ViewportSize"
):Connect(
	updateAllStrokes
)


-- CurrentCamera can theoretically change.
Workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(
	function()

		if Workspace.CurrentCamera then

			camera =
				Workspace.CurrentCamera


			updateAllStrokes()

		end
	end
)


updateAllStrokes()