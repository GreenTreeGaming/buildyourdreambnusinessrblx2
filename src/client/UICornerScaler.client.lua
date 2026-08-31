local Players =
	game:GetService("Players")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- SETTINGS
--==================================================

local TARGET_BUTTON_NAME =
	"OpenButton"


local CONSTRAINT_NAME =
	"AutoOpenButtonAspectRatio"


--==================================================
-- SETUP
--==================================================

local function setupOpenButton(
	instance: Instance
)

	if instance.Name
		~= TARGET_BUTTON_NAME then

		return
	end


	if not instance:IsA(
		"GuiObject"
	) then

		return
	end


	-- Only apply this when the button actually uses
	-- a heavily rounded UICorner.
	local corner =
		instance:FindFirstChildOfClass(
			"UICorner"
		)


	if not corner then
		return
	end


	if corner.CornerRadius.Scale
		< 0.95 then

		return
	end


	-- Don't add duplicates.
	local existingConstraint =
		instance:FindFirstChild(
			CONSTRAINT_NAME
		)


	if existingConstraint then

		if existingConstraint:IsA(
			"UIAspectRatioConstraint"
		) then

			existingConstraint.AspectRatio =
				1


			existingConstraint.DominantAxis =
				Enum.DominantAxis.Height


			return
		end


		existingConstraint:Destroy()
	end


	local constraint =
		Instance.new(
			"UIAspectRatioConstraint"
		)


	constraint.Name =
		CONSTRAINT_NAME


	constraint.AspectRatio =
		1


	-- Your height already scales nicely.
	-- Force width to follow the height.
	constraint.DominantAxis =
		Enum.DominantAxis.Height


	constraint.Parent =
		instance
end


--==================================================
-- EXISTING UI
--==================================================

for _, descendant in
	playerGui:GetDescendants() do

	setupOpenButton(
		descendant
	)
end


--==================================================
-- FUTURE / CLONED UI
--==================================================

playerGui.DescendantAdded:Connect(
	function(
		descendant: Instance
	)

		if descendant.Name
			== TARGET_BUTTON_NAME then

			-- Let its UICorner clone in first.
			task.defer(
				setupOpenButton,
				descendant
			)

			return
		end


		-- Handles the case where the OpenButton exists
		-- first and its UICorner is added afterward.
		if descendant:IsA(
			"UICorner"
		) then

			local parent =
				descendant.Parent


			if parent
				and parent.Name
					== TARGET_BUTTON_NAME then

				task.defer(
					setupOpenButton,
					parent
				)
			end
		end
	end
)


print(
	"OpenButton aspect ratio fixer started."
)