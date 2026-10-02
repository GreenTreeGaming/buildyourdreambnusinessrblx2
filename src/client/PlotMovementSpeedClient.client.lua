local Players =
	game:GetService("Players")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer


local plotsFolder =
	Workspace:WaitForChild(
		"Plots"
	)


--==================================================
-- CONFIG
--==================================================

local NORMAL_SPEED =
	16


local OUTSIDE_PLOT_SPEED =
	45


local CHECK_INTERVAL =
	0.1


--
-- Small tolerance so the player does not rapidly
-- switch speed while standing exactly on the edge.
--
local EDGE_PADDING =
	1


--==================================================
-- STATE
--==================================================

local character: Model? =
	nil


local humanoid: Humanoid? =
	nil


local rootPart: BasePart? =
	nil


local currentSpeed: number? =
	nil


--==================================================
-- CHARACTER
--==================================================

local function setCharacter(
	newCharacter: Model
)

	character =
		newCharacter


	humanoid =
		newCharacter:WaitForChild(
			"Humanoid"
		) :: Humanoid


	rootPart =
		newCharacter:WaitForChild(
			"HumanoidRootPart"
		) :: BasePart


	currentSpeed =
		nil
end


if player.Character then

	setCharacter(
		player.Character
	)
end


player.CharacterAdded:Connect(
	setCharacter
)


player.CharacterRemoving:Connect(
	function()

		character =
			nil


		humanoid =
			nil


		rootPart =
			nil


		currentSpeed =
			nil
	end
)


--==================================================
-- PLAYER PLOT
--==================================================

local function getPlayerPlot():
	Model?

	local plotName =
		player:GetAttribute(
			"PlotName"
		)


	--
	-- Fast path:
	-- use the plot name already assigned to the player.
	--
	if typeof(plotName)
		== "string"
		and plotName ~= "" then

		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)


		if plot
			and plot:IsA(
				"Model"
			)
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end


	--
	-- Safety fallback in case PlotName has not replicated yet.
	--
	for _, plot in
		plotsFolder:GetChildren() do

		if not plot:IsA(
			"Model"
		) then

			continue
		end


		if plot:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return plot
		end
	end


	return nil
end


--==================================================
-- BOUNDING BOX CHECK
--==================================================

local function isPositionInsidePartXZ(
	worldPosition: Vector3,
	part: BasePart
): boolean

	--
	-- Convert the player's world position into
	-- the Ground part's local coordinate space.
	--
	-- This means this still works if the Ground
	-- is rotated.
	--
	local localPosition =
		part.CFrame:PointToObjectSpace(
			worldPosition
		)


	local halfWidth =
		part.Size.X / 2


	local halfDepth =
		part.Size.Z / 2


	return math.abs(
		localPosition.X
	) <= halfWidth
		+ EDGE_PADDING

		and math.abs(
			localPosition.Z
		) <= halfDepth
		+ EDGE_PADDING
end


local function isPlayerInsideOwnPlot():
	boolean

	if not rootPart
		or not rootPart.Parent then

		return true
	end


	local plot =
		getPlayerPlot()


	--
	-- If their plot has not loaded yet, don't give
	-- them the speed boost accidentally.
	--
	if not plot then

		return true
	end


	local ground =
		plot:FindFirstChild(
			"Ground"
		)


	if not ground
		or not ground:IsA(
			"BasePart"
		) then

		warn(
			`[PlotMovementSpeed] {plot:GetFullName()} is missing a Ground BasePart.`
		)


		return true
	end


	return isPositionInsidePartXZ(
		rootPart.Position,
		ground
	)
end


--==================================================
-- SPEED
--==================================================

local function setMovementSpeed(
	speed: number
)

	if not humanoid
		or not humanoid.Parent then

		return
	end


	if currentSpeed
		== speed
		and humanoid.WalkSpeed
			== speed then

		return
	end


	humanoid.WalkSpeed =
		speed


	currentSpeed =
		speed
end


local function updateMovementSpeed()

	if not humanoid
		or not rootPart
		or humanoid.Health <= 0 then

		return
	end


	if isPlayerInsideOwnPlot() then

		setMovementSpeed(
			NORMAL_SPEED
		)

	else

		setMovementSpeed(
			OUTSIDE_PLOT_SPEED
		)
	end
end


--==================================================
-- LOOP
--==================================================

task.spawn(
	function()

		while player.Parent do

			updateMovementSpeed()


			task.wait(
				CHECK_INTERVAL
			)
		end
	end
)