local TweenService =
	game:GetService("TweenService")

local Workspace =
	game:GetService("Workspace")


local BusinessBuildAnimation = {}


--==================================================
-- CONFIG
--==================================================

local START_Y_OFFSET =
	-0.45

local POP_Y_OFFSET =
	0.12


local POP_TIME =
	0.18

local SETTLE_TIME =
	0.09


local FIRST_PULSE_TIME =
	0.24

local SECOND_PULSE_DELAY =
	0.055

local SECOND_PULSE_TIME =
	0.27


local PULSE_START_SCALE =
	0.35

local PULSE_END_SCALE =
	1.45


local PULSE_COLOR =
	Color3.fromRGB(
		255,
		210,
		70
	)


local FLASH_FILL_COLOR =
	Color3.fromRGB(
		255,
		225,
		105
	)


local FLASH_OUTLINE_COLOR =
	Color3.fromRGB(
		255,
		255,
		225
	)


--==================================================
-- HELPERS
--==================================================

local function getPlacementBounds(
	model: Model
): BasePart?

	local bounds =
		model:FindFirstChild(
			"PlacementBounds",
			true
		)


	if bounds
		and bounds:IsA(
			"BasePart"
		) then

		return bounds
	end


	return nil
end


local function createPulse(
	cframe: CFrame,
	size: Vector3,
	delayTime: number,
	duration: number
)
	task.delay(
		delayTime,

		function()

			local diameter =
				math.max(
					size.X,
					size.Z
				)


			local pulse =
				Instance.new(
					"Part"
				)


			pulse.Name =
				"BusinessBuildPulse"


			pulse.Shape =
				Enum.PartType.Cylinder


			pulse.Anchored =
				true


			pulse.CanCollide =
				false

			pulse.CanTouch =
				false

			pulse.CanQuery =
				false


			pulse.CastShadow =
				false


			pulse.Material =
				Enum.Material.Neon


			pulse.Color =
				PULSE_COLOR


			pulse.Transparency =
				0.38


			--
			-- Cylinder's long axis is X.
			-- Rotate it so that it lies flat on the ground.
			--
			pulse.CFrame =
				CFrame.new(
					cframe.Position
						+ Vector3.new(
							0,
							0.035,
							0
						)
				)
				* CFrame.Angles(
					0,
					0,
					math.rad(90)
				)


			local startDiameter =
				math.max(
					diameter
						* PULSE_START_SCALE,

					0.5
				)


			local endDiameter =
				math.max(
					diameter
						* PULSE_END_SCALE,

					1
				)


			pulse.Size =
				Vector3.new(
					0.055,
					startDiameter,
					startDiameter
				)


			pulse.Parent =
				Workspace


			local tween =
				TweenService:Create(
					pulse,

					TweenInfo.new(
						duration,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					),

					{
						Size =
							Vector3.new(
								0.025,
								endDiameter,
								endDiameter
							),

						Transparency =
							1,
					}
				)


			tween.Completed:Once(
				function()

					if pulse.Parent then
						pulse:Destroy()
					end
				end
			)


			tween:Play()
		end
	)
end


local function createCompletionFlash(
	model: Model
)
	local highlight =
		Instance.new(
			"Highlight"
		)


	highlight.Name =
		"BusinessBuildFlash"


	highlight.Adornee =
		model


	--
	-- Other objects can still occlude the highlight.
	-- It will not glow through the entire map.
	--
	highlight.DepthMode =
		Enum.HighlightDepthMode.Occluded


	highlight.FillColor =
		FLASH_FILL_COLOR


	highlight.OutlineColor =
		FLASH_OUTLINE_COLOR


	highlight.FillTransparency =
		0.58


	highlight.OutlineTransparency =
		0.08


	highlight.Parent =
		model


	local tween =
		TweenService:Create(
			highlight,

			TweenInfo.new(
				0.28,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				FillTransparency =
					1,

				OutlineTransparency =
					1,
			}
		)


	tween.Completed:Once(
		function()

			if highlight.Parent then
				highlight:Destroy()
			end
		end
	)


	tween:Play()
end


local function tweenModelPivot(
	model: Model,
	finalPivot: CFrame
)
	local yOffset =
		Instance.new(
			"NumberValue"
		)


	yOffset.Name =
		"BusinessBuildYOffset"


	yOffset.Value =
		START_Y_OFFSET


	local changedConnection =
		yOffset.Changed:Connect(
			function(
				value: number
			)

				if not model.Parent then
					return
				end


				model:PivotTo(
					finalPivot
						+ Vector3.new(
							0,
							value,
							0
						)
				)
			end
		)


	--
	-- Start slightly beneath the finished location.
	--
	model:PivotTo(
		finalPivot
			+ Vector3.new(
				0,
				START_Y_OFFSET,
				0
			)
	)


	--
	-- Fast upward pop with a little overshoot.
	--
	local popTween =
		TweenService:Create(
			yOffset,

			TweenInfo.new(
				POP_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Value =
					POP_Y_OFFSET,
			}
		)


	popTween:Play()

	popTween.Completed:Wait()


	if not model.Parent then

		changedConnection:Disconnect()
		yOffset:Destroy()

		return
	end


	--
	-- Short settle back into the exact placement.
	--
	local settleTween =
		TweenService:Create(
			yOffset,

			TweenInfo.new(
				SETTLE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),

			{
				Value =
					0,
			}
		)


	settleTween:Play()

	settleTween.Completed:Wait()


	changedConnection:Disconnect()

	yOffset:Destroy()


	if model.Parent then

		--
		-- Guarantee perfect final placement even if there
		-- was a frame hitch during either tween.
		--
		model:PivotTo(
			finalPivot
		)
	end
end


--==================================================
-- PUBLIC API
--==================================================

function BusinessBuildAnimation.Play(
	model: Model
)
	if not model
		or not model:IsA(
			"Model"
		)
		or not model.Parent then

		return
	end


	local finalPivot =
		model:GetPivot()


	local bounds =
		getPlacementBounds(
			model
		)


	local pulseCFrame: CFrame

	local pulseSize: Vector3


	if bounds then

		pulseCFrame =
			bounds.CFrame


		pulseSize =
			bounds.Size

	else

		local boxCFrame,
			boxSize =
			model:GetBoundingBox()


		pulseCFrame =
			boxCFrame


		pulseSize =
			boxSize
	end


	--
	-- VFX begin immediately while the stand pops upward.
	--
	createCompletionFlash(
		model
	)


	createPulse(
		pulseCFrame,
		pulseSize,
		0,
		FIRST_PULSE_TIME
	)


	createPulse(
		pulseCFrame,
		pulseSize,
		SECOND_PULSE_DELAY,
		SECOND_PULSE_TIME
	)


	local success,
		animationError =
		pcall(
			function()

				tweenModelPivot(
					model,
					finalPivot
				)
			end
		)


	--
	-- Animation should NEVER leave a business displaced.
	--
	if model.Parent then

		model:PivotTo(
			finalPivot
		)
	end


	if not success then

		warn(
			"Business build animation failed:",
			animationError
		)
	end
end


return BusinessBuildAnimation