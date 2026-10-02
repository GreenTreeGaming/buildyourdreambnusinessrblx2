local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local UserInputService =
	game:GetService("UserInputService")

local GuiService =
	game:GetService("GuiService")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild("PlayerGui")


--==================================================
-- UI
--==================================================

local boostsGui =
	playerGui:WaitForChild(
		"BoostsBottom"
	) :: ScreenGui


local mainFrame =
	boostsGui:WaitForChild(
		"MainFrame"
	) :: Frame


local template =
	mainFrame:WaitForChild(
		"Template"
	) :: ImageLabel


local hoverFrame =
	boostsGui:WaitForChild(
		"HoverFrame"
	) :: Frame


local hoverTitle =
	hoverFrame:WaitForChild(
		"Title"
	) :: TextLabel


local hoverSubtitle =
	hoverFrame:WaitForChild(
		"Subtitle"
	) :: TextLabel


--==================================================
-- CONFIG
--==================================================

type BoostDefinition = {
	Key: string,
	DisplayName: string,
	Description: string,
	Image: string,

	PermanentAttribute: string?,
	ExpiryAttribute: string?,

	TemporaryCashBoost: boolean?,
}


local BOOSTS: {BoostDefinition} = {
	{
		Key = "VIP",

		DisplayName =
			"VIP",

		Description =
			"+15% customer attraction and access to VIP benefits.",

		Image =
			"rbxassetid://76437883098812",

		PermanentAttribute =
			"HasVIP",
	},

	{
		Key = "Permanent2xCash",

		DisplayName =
			"2x Cash",

		Description =
			"All cash you earn is permanently doubled.",

		Image =
			"rbxassetid://78301368966596",

		PermanentAttribute =
			"Has2xCash",
	},

	{
		Key = "CashBoost",

		DisplayName =
			"2x Cash Boost",

		Description =
			"All cash you earn is doubled while this boost is active.",

		Image =
			"rbxassetid://78301368966596",

		ExpiryAttribute =
			"CashBoostUntil",

		TemporaryCashBoost =
			true,
	},

	{
		Key = "CustomerRush",

		DisplayName =
			"Customer Rush",

		Description =
			"Customers arrive twice as fast while this boost is active.",

		Image =
			"rbxassetid://77595754464398",

		ExpiryAttribute =
			"CustomerRushUntil",
	},

	{
		Key = "ReputationBoost",

		DisplayName =
			"2x Reputation",

		Description =
			"Earn twice as much reputation while this boost is active.",

		Image =
			"rbxassetid://110084344245608",

		ExpiryAttribute =
			"ReputationBoostUntil",
	},
}


--==================================================
-- STATE
--==================================================

type BoostIconData = {
	Definition: BoostDefinition,
	Icon: ImageLabel,
	TimerLabel: TextLabel,
}


local activeIcons:
	{[string]: BoostIconData} =
	{}


local hoveredIcon:
	ImageLabel? =
	nil


local hoveredDefinition:
	BoostDefinition? =
	nil


--==================================================
-- INITIAL SETUP
--==================================================

boostsGui.Enabled =
	true


template.Visible =
	false


hoverFrame.Visible =
	false


-- Template should never participate in the grid.
-- We DO NOT change its size.
template.LayoutOrder =
	999999


--==================================================
-- TIME
--==================================================

local function getServerTime(): number

	-- Using server time keeps countdowns accurate
	-- and prevents the player's local clock from
	-- affecting boost timers.
	return workspace:GetServerTimeNow()
end


local function formatTime(
	seconds: number
): string

	seconds =
		math.max(
			0,
			math.ceil(seconds)
		)


	local hours =
		math.floor(
			seconds / 3600
		)


	local minutes =
		math.floor(
			(seconds % 3600) / 60
		)


	local remainingSeconds =
		seconds % 60


	return string.format(
		"%02d:%02d:%02d",
		hours,
		minutes,
		remainingSeconds
	)
end


--==================================================
-- BOOST STATE
--==================================================

local function isBoostActive(
	definition: BoostDefinition
): boolean

	if definition.PermanentAttribute then

		return player:GetAttribute(
			definition.PermanentAttribute
		) == true
	end


	if definition.ExpiryAttribute then

		local expiry =
			player:GetAttribute(
				definition.ExpiryAttribute
			)


		if typeof(expiry)
			~= "number" then

			return false
		end


		return expiry
			> getServerTime()
	end


	return false
end


local function getRemainingTime(
	definition: BoostDefinition
): number

	if not definition.ExpiryAttribute then
		return 0
	end


	local expiry =
		player:GetAttribute(
			definition.ExpiryAttribute
		)


	if typeof(expiry)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		expiry
			- getServerTime()
	)
end


--==================================================
-- HOVER
--==================================================

local function hideHover()

	hoveredIcon =
		nil

	hoveredDefinition =
		nil

	hoverFrame.Visible =
		false
end


local function showHover(
	icon: ImageLabel,
	definition: BoostDefinition
)

	hoveredIcon =
		icon

	hoveredDefinition =
		definition


	hoverTitle.Text =
		definition.DisplayName


	hoverSubtitle.Text =
		definition.Description


	hoverFrame.Visible =
		true
end


local function updateHoverPosition()

	if not hoverFrame.Visible then
		return
	end


	if not hoveredIcon
		or not hoveredIcon.Parent then

		hideHover()

		return
	end


	local mousePosition =
		UserInputService:GetMouseLocation()


	-- GetMouseLocation includes the Roblox GUI inset.
	-- Normal ScreenGuis do not, so compensate for it.
	if not boostsGui.IgnoreGuiInset then

		local topLeftInset =
			GuiService:GetGuiInset()


		mousePosition -=
			topLeftInset
	end


	-- HoverFrame's AnchorPoint is (0, 1).
	--
	-- This places the mouse near the BOTTOM-LEFT
	-- corner of HoverFrame, so the tooltip grows
	-- upward and to the right.
	local paddingX = 14
	local paddingY = 10


	local targetX =
		mousePosition.X
			+ paddingX


	local targetY =
		mousePosition.Y
			- paddingY


	-- Keep it from leaving the screen.
	local camera =
		workspace.CurrentCamera


	if camera then

		local viewport =
			camera.ViewportSize


		local width =
			hoverFrame.AbsoluteSize.X


		local height =
			hoverFrame.AbsoluteSize.Y


		targetX =
			math.clamp(
				targetX,
				0,
				math.max(
					0,
					viewport.X
						- width
				)
			)


		-- Because AnchorPoint.Y == 1,
		-- targetY represents the bottom edge.
		targetY =
			math.clamp(
				targetY,
				height,
				viewport.Y
			)
	end


	hoverFrame.Position =
		UDim2.fromOffset(
			targetX,
			targetY
		)
end


--==================================================
-- TEMPORARY 2X CASH VISUAL
--==================================================

local function addTemporaryCashMarker(
	icon: ImageLabel
)

	-- Same artwork as permanent 2x Cash, so this
	-- little BOOST badge makes the temporary
	-- version immediately distinguishable.
	--
	-- Does NOT alter Template.Size.
	local badge =
		Instance.new(
			"TextLabel"
		)


	badge.Name =
		"TemporaryBadge"


	badge.AnchorPoint =
		Vector2.new(
			1,
			0
		)


	badge.Position =
		UDim2.new(
			1,
			-2,
			0,
			2
		)


	badge.Size =
		UDim2.new(
			0.45,
			0,
			0.2,
			0
		)


	badge.BackgroundColor3 =
		Color3.fromRGB(
			255,
			203,
			47
		)


	badge.BorderSizePixel =
		0


	badge.Text =
		"BOOST"


	badge.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)


	badge.TextScaled =
		true


	badge.FontFace = Font.new("rbxassetid://12188570269")


	badge.ZIndex =
		icon.ZIndex
			+ 3


	badge.Parent =
		icon


	local corner =
		Instance.new(
			"UICorner"
		)


	corner.CornerRadius =
		UDim.new(
			0.3,
			0
		)


	corner.Parent =
		badge


	local stroke =
		Instance.new(
			"UIStroke"
		)


	stroke.Thickness =
		1.5


	stroke.Color =
		Color3.fromRGB(
			128,
			88,
			0
		)


	stroke.Parent =
		badge
end


--==================================================
-- ICON CREATION
--==================================================

local function connectHover(
	icon: ImageLabel,
	definition: BoostDefinition
)

	icon.Active =
		true


	icon.MouseEnter:Connect(
		function()

			if UserInputService.TouchEnabled then
				return
			end


			showHover(
				icon,
				definition
			)
		end
	)


	icon.MouseLeave:Connect(
		function()

			if UserInputService.TouchEnabled then
				return
			end


			if hoveredIcon
				== icon then

				hideHover()
			end
		end
	)


	icon.InputBegan:Connect(
		function(input)

			if input.UserInputType
				~= Enum.UserInputType.Touch then

				return
			end


			if hoveredIcon
				== icon
				and hoverFrame.Visible then

				hideHover()

				return
			end


			showHover(
				icon,
				definition
			)


			-- Place the tooltip beside the tapped icon
			-- instead of following the player's finger.
			local iconPosition =
				icon.AbsolutePosition


			local iconSize =
				icon.AbsoluteSize


			local x =
				iconPosition.X
					+ iconSize.X
					+ 12


			local y =
				iconPosition.Y
					+ iconSize.Y


			local camera =
				workspace.CurrentCamera


			if camera then

				local viewport =
					camera.ViewportSize


				local hoverSize =
					hoverFrame.AbsoluteSize


				x =
					math.clamp(
						x,
						0,
						math.max(
							0,
							viewport.X
								- hoverSize.X
						)
					)


				y =
					math.clamp(
						y,
						hoverSize.Y,
						viewport.Y
					)
			end


			hoverFrame.Position =
				UDim2.fromOffset(
					x,
					y
				)
		end
	)
end

local function createBoostIcon(
	definition: BoostDefinition
)

	if activeIcons[
		definition.Key
	] then

		return
	end


	local icon =
		template:Clone()


	icon.Name =
		definition.Key


	icon.Image =
		definition.Image


	icon.Visible =
		true


	-- IMPORTANT:
	-- Do not modify icon.Size.
	--
	-- It keeps the exact Template size so your
	-- UIGridLayout continues controlling everything.


	local timerLabel =
		icon:WaitForChild(
			"Title"
		) :: TextLabel


	if definition.PermanentAttribute then

		timerLabel.Text =
			"PERMANENT"

	else

		timerLabel.Text =
			formatTime(
				getRemainingTime(
					definition
				)
			)
	end


	-- Since temporary 2x Cash uses the same image
	-- as permanent 2x Cash, give it a distinct badge.
	if definition.TemporaryCashBoost then

		addTemporaryCashMarker(
			icon
		)
	end


	-- Preserve the order from BOOSTS.
	for index,
		entry in BOOSTS do

		if entry
			== definition then

			icon.LayoutOrder =
				index

			break
		end
	end


	connectHover(
		icon,
		definition
	)


	activeIcons[
		definition.Key
	] = {
		Definition =
			definition,

		Icon =
			icon,

		TimerLabel =
			timerLabel,
	}


	icon.Parent =
		mainFrame
end


local function removeBoostIcon(
	key: string
)

	local data =
		activeIcons[key]


	if not data then
		return
	end


	if hoveredIcon
		== data.Icon then

		hideHover()
	end


	activeIcons[key] =
		nil


	data.Icon:Destroy()
end


--==================================================
-- REFRESH
--==================================================

local function refreshBoost(
	definition: BoostDefinition
)

	local active =
		isBoostActive(
			definition
		)


	local existing =
		activeIcons[
			definition.Key
		]


	if active then

		if not existing then

			createBoostIcon(
				definition
			)
		end

	else

		if existing then

			removeBoostIcon(
				definition.Key
			)
		end
	end
end


local function refreshAllBoosts()

	for _,
		definition in BOOSTS do

		refreshBoost(
			definition
		)
	end
end


--==================================================
-- ATTRIBUTE LISTENERS
--==================================================

for _,
	definition in BOOSTS do

	local attributeName =
		definition.PermanentAttribute
			or definition.ExpiryAttribute


	if attributeName then

		player:GetAttributeChangedSignal(
			attributeName
		):Connect(
			function()

				refreshBoost(
					definition
				)
			end
		)
	end
end


--==================================================
-- TIMER LOOP
--==================================================

task.spawn(
	function()

		while boostsGui.Parent do

			for key,
				data in activeIcons do

				local definition =
					data.Definition


				if definition.ExpiryAttribute then

					local remaining =
						getRemainingTime(
							definition
						)


					if remaining <= 0 then

						removeBoostIcon(
							key
						)

					else

						data.TimerLabel.Text =
							formatTime(
								remaining
							)
					end
				end
			end


			task.wait(
				0.25
			)
		end
	end
)

--==================================================
-- MOBILE CLICK-AWAY
--==================================================

UserInputService.InputBegan:Connect(
	function(
		input: InputObject,
		gameProcessed: boolean
	)

		if not UserInputService.TouchEnabled then
			return
		end


		if input.UserInputType
			~= Enum.UserInputType.Touch then

			return
		end


		if not hoverFrame.Visible then
			return
		end


		local position =
			input.Position


		local function isInside(
			guiObject: GuiObject
		): boolean

			local absolutePosition =
				guiObject.AbsolutePosition


			local absoluteSize =
				guiObject.AbsoluteSize


			return position.X
					>= absolutePosition.X
				and position.X
					<= absolutePosition.X
						+ absoluteSize.X
				and position.Y
					>= absolutePosition.Y
				and position.Y
					<= absolutePosition.Y
						+ absoluteSize.Y
		end


		-- Keep it open if the player tapped
		-- the currently selected boost icon.
		if hoveredIcon
			and hoveredIcon.Parent
			and isInside(
				hoveredIcon
			) then

			return
		end


		-- Keep it open if they tap the tooltip itself.
		if isInside(
			hoverFrame
		) then

			return
		end


		hideHover()
	end
)


--==================================================
-- TOOLTIP FOLLOW
--==================================================

RunService.RenderStepped:Connect(
	function()

		if hoverFrame.Visible
			and not UserInputService.TouchEnabled then

			updateHoverPosition()
		end
	end
)

--==================================================
-- INITIAL REFRESH
--==================================================

refreshAllBoosts()