local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local Workspace =
	game:GetService("Workspace")


local player =
	Players.LocalPlayer


local customersFolder =
	Workspace:WaitForChild("Customers")


-- Always animate customers near the camera.
local NEAR_DISTANCE =
	55

-- At medium range, animate only when actually visible.
local MAX_VISIBLE_DISTANCE =
	180

local UPDATE_INTERVAL =
	0.35

local SCREEN_MARGIN =
	60


type CustomerState = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Animator: Animator?,

	AnimationsEnabled: boolean,

	-- The movement animation that WE stopped while
	-- culling. Keeping the reference means we can
	-- explicitly restart it when the NPC becomes visible.
	SuppressedMovementTrack: AnimationTrack?,
}


local customerStates: {
	[Model]: CustomerState
} = {}


local function getCharacter(): Model?
	return player.Character
end


local function isMovementTrack(
	track: AnimationTrack
): boolean

	if track.Priority
		== Enum.AnimationPriority.Movement then

		return true
	end


	local trackName =
		string.lower(
			track.Name
		)


	if string.find(
		trackName,
		"walk",
		1,
		true
	) then

		return true
	end


	if string.find(
		trackName,
		"run",
		1,
		true
	) then

		return true
	end


	local animation =
		track.Animation


	if animation then
		local animationName =
			string.lower(
				animation.Name
			)


		if string.find(
			animationName,
			"walk",
			1,
			true
		) then

			return true
		end


		if string.find(
			animationName,
			"run",
			1,
			true
		) then

			return true
		end
	end


	return false
end


local function getAnimator(
	state: CustomerState
): Animator?

	local animator =
		state.Animator


	if animator
		and animator.Parent then

		return animator
	end


	local foundAnimator =
		state.Humanoid
			:FindFirstChildOfClass(
				"Animator"
			)


	if foundAnimator then
		state.Animator =
			foundAnimator

		return foundAnimator
	end


	return nil
end


local function stopMovementAnimations(
	state: CustomerState
)
	local animator =
		getAnimator(state)


	if not animator then
		return
	end


	for _, track in
		animator:GetPlayingAnimationTracks() do

		if not isMovementTrack(
			track
		) then

			continue
		end


		-- Remember the exact movement track that was
		-- interrupted by our culling system.
		state.SuppressedMovementTrack =
			track


		track:Stop(0)
	end
end


local function restartMovementAnimation(
	state: CustomerState
)
	if state.Humanoid.Health <= 0 then
		return
	end


	-- Don't play a walking animation if the NPC
	-- isn't actually trying to move.
	if state.Humanoid.MoveDirection.Magnitude
		<= 0.01 then

		return
	end


	local suppressedTrack =
		state.SuppressedMovementTrack


	if not suppressedTrack then
		return
	end


	local success =
		pcall(function()
			if not suppressedTrack.IsPlaying then

				suppressedTrack:Play(
					0.08,
					1,
					1
				)
			end
		end)


	if success then
		state.SuppressedMovementTrack =
			nil
	end
end


local function setMovementAnimationsEnabled(
	state: CustomerState,
	enabled: boolean
)
	local wasEnabled =
		state.AnimationsEnabled


	state.AnimationsEnabled =
		enabled


	if not enabled then
		-- Apply this every update. That prevents a new
		-- walk animation from appearing while culled.
		stopMovementAnimations(
			state
		)

		return
	end


	-- Important:
	-- Roblox's Animate script does not necessarily
	-- restart a walk track if the humanoid was already
	-- moving while we stopped that track.
	if not wasEnabled then
		restartMovementAnimation(
			state
		)
	end
end


local function isPointOnScreen(
	camera: Camera,
	worldPosition: Vector3
): boolean

	local screenPosition, visible =
		camera:WorldToViewportPoint(
			worldPosition
		)


	if not visible
		or screenPosition.Z <= 0 then

		return false
	end


	local viewport =
		camera.ViewportSize


	return screenPosition.X
			>= -SCREEN_MARGIN

		and screenPosition.X
			<= viewport.X
				+ SCREEN_MARGIN

		and screenPosition.Y
			>= -SCREEN_MARGIN

		and screenPosition.Y
			<= viewport.Y
				+ SCREEN_MARGIN
end


local function hasLineOfSight(
	camera: Camera,
	customer: Model,
	rootPart: BasePart
): boolean

	local cameraPosition =
		camera.CFrame.Position


	local targetPosition =
		rootPart.Position
			+ Vector3.new(
				0,
				1.5,
				0
			)


	local direction =
		targetPosition
			- cameraPosition


	local raycastParams =
		RaycastParams.new()


	raycastParams.FilterType =
		Enum.RaycastFilterType.Exclude

	raycastParams.IgnoreWater =
		true


	local excludedInstances: {
		Instance
	} = {
		customer,
	}


	local character =
		getCharacter()


	if character then
		table.insert(
			excludedInstances,
			character
		)
	end


	raycastParams.FilterDescendantsInstances =
		excludedInstances


	local result =
		Workspace:Raycast(
			cameraPosition,
			direction,
			raycastParams
		)


	return result == nil
end


local function shouldAnimateCustomer(
	state: CustomerState,
	camera: Camera
): boolean

	if not state.Model.Parent
		or not state.RootPart.Parent
		or state.Humanoid.Health <= 0 then

		return false
	end


	local cameraPosition =
		camera.CFrame.Position


	local customerPosition =
		state.RootPart.Position


	local distance =
		(
			cameraPosition
				- customerPosition
		).Magnitude


	if distance <= NEAR_DISTANCE then
		return true
	end


	if distance
		> MAX_VISIBLE_DISTANCE then

		return false
	end


	if not isPointOnScreen(
		camera,
		customerPosition
	) then

		return false
	end


	return hasLineOfSight(
		camera,
		state.Model,
		state.RootPart
	)
end


local function connectAnimator(
	state: CustomerState,
	animator: Animator
)
	state.Animator =
		animator


	animator.AnimationPlayed:Connect(
		function(
			track: AnimationTrack
		)
			if not isMovementTrack(
				track
			) then

				return
			end


			if state.AnimationsEnabled then
				return
			end


			-- A movement track attempted to start while
			-- the NPC was culled. Remember it so we can
			-- restore it later.
			state.SuppressedMovementTrack =
				track


			task.defer(function()
				if track.IsPlaying
					and not state.AnimationsEnabled then

					track:Stop(0)
				end
			end)
		end
	)
end


local function registerCustomer(
	customer: Model
)
	if customerStates[customer] then
		return
	end


	task.spawn(function()
		local humanoid =
			customer:FindFirstChildOfClass(
				"Humanoid"
			)


		if not humanoid then
			local humanoidInstance =
				customer:WaitForChild(
					"Humanoid",
					5
				)


			if humanoidInstance
				and humanoidInstance:IsA(
					"Humanoid"
				) then

				humanoid =
					humanoidInstance
			end
		end


		local rootPart =
			customer:FindFirstChild(
				"HumanoidRootPart"
			)


		if not rootPart then
			rootPart =
				customer:WaitForChild(
					"HumanoidRootPart",
					5
				)
		end


		if not customer.Parent
			or not humanoid
			or not rootPart
			or not rootPart:IsA(
				"BasePart"
			) then

			return
		end


		if customerStates[customer] then
			return
		end


		local state: CustomerState = {
			Model = customer,
			Humanoid = humanoid,
			RootPart = rootPart,
			Animator = nil,

			AnimationsEnabled = true,

			SuppressedMovementTrack = nil,
		}


		customerStates[customer] =
			state


		local animator =
			humanoid
				:FindFirstChildOfClass(
					"Animator"
				)


		if animator then
			connectAnimator(
				state,
				animator
			)
		else
			humanoid.ChildAdded:Connect(
				function(
					child: Instance
				)
					if child:IsA(
						"Animator"
					)
						and not state.Animator then

						connectAnimator(
							state,
							child
						)
					end
				end
			)
		end


		customer.Destroying:Connect(
			function()
				customerStates[
					customer
				] = nil
			end
		)
	end)
end


local function unregisterCustomer(
	customer: Model
)
	customerStates[
		customer
	] = nil
end


for _, customer in
	customersFolder:GetChildren() do

	if customer:IsA("Model") then
		registerCustomer(
			customer
		)
	end
end


customersFolder.ChildAdded:Connect(
	function(
		child: Instance
	)
		if child:IsA("Model") then
			registerCustomer(
				child
			)
		end
	end
)


customersFolder.ChildRemoved:Connect(
	function(
		child: Instance
	)
		if child:IsA("Model") then
			unregisterCustomer(
				child
			)
		end
	end
)


local elapsedTime =
	0


RunService.Heartbeat:Connect(
	function(
		deltaTime: number
	)
		elapsedTime +=
			deltaTime


		if elapsedTime
			< UPDATE_INTERVAL then

			return
		end


		elapsedTime =
			0


		local camera =
			Workspace.CurrentCamera


		if not camera then
			return
		end


		for customer, state in
			customerStates do

			if not customer.Parent
				or not state.Humanoid.Parent
				or not state.RootPart.Parent then

				customerStates[
					customer
				] = nil

				continue
			end


			local shouldAnimate =
				shouldAnimateCustomer(
					state,
					camera
				)


			setMovementAnimationsEnabled(
				state,
				shouldAnimate
			)
		end
	end
)


print(
	"Customer animation culling started."
)