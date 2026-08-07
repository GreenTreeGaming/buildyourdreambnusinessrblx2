local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Workspace =
	game:GetService("Workspace")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local plotsFolder =
	Workspace:WaitForChild("Plots")

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local requestUpgradeRemote =
	remotes:WaitForChild(
		"RequestBusinessUpgrade"
	)

local upgradeResultRemote =
	remotes:WaitForChild(
		"BusinessUpgradeResult"
	)

local BUSINESS_NAME =
	"LemonadeStand"

local MANAGEMENT_DISTANCE = 22
local UPDATE_INTERVAL = 0.1

-- Display-only information.
--
-- The server remains authoritative for the actual
-- upgrade cost and whether an upgrade is allowed.
local DISPLAY_LEVELS = {
	[1] = {
		UpgradeCost = 50,
		Description =
			"Upgrade the stand's appearance.",
	},

	[2] = {
		Description =
			"Level 2 appearance unlocked.",
	},
}

type StandUiState = {
	Gui: BillboardGui,
	Refresh: () -> (),
}

local standUis:
	{[Model]: StandUiState} = {}

-- The server only processes one appearance upgrade
-- for this player at once, so keep this global.
local pendingStand: Model? = nil


local function getOwnedPlot(): Model?
	local plotName =
		player:GetAttribute("PlotName")

	if typeof(plotName) == "string" then
		local plot =
			plotsFolder:FindFirstChild(
				plotName
			)

		if plot
			and plot:IsA("Model")
			and plot:GetAttribute(
				"OwnerUserId"
			) == player.UserId then

			return plot
		end
	end

	for _, instance in
		plotsFolder:GetChildren()
	do
		if not instance:IsA("Model") then
			continue
		end

		if instance:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return instance
		end
	end

	return nil
end


local function isOwnedLemonadeStand(
	stand: Instance
): boolean
	if not stand:IsA("Model") then
		return false
	end

	if stand:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return false
	end

	local businessType =
		stand:GetAttribute(
			"BusinessType"
		)

	if businessType == BUSINESS_NAME then
		return true
	end

	-- Backwards compatibility with stands that may
	-- not have BusinessType yet.
	if stand.Name == BUSINESS_NAME then
		return true
	end

	return string.match(
		stand.Name,
		"^LemonadeStand_"
	) ~= nil
end


local function getOwnedStands(): {Model}
	local plot =
		getOwnedPlot()

	if not plot then
		return {}
	end

	local placedBusinesses =
		plot:FindFirstChild(
			"PlacedBusinesses"
		)

	if not placedBusinesses then
		return {}
	end

	local stands: {Model} = {}

	for _, instance in
		placedBusinesses:GetChildren()
	do
		if isOwnedLemonadeStand(
			instance
		) then
			table.insert(
				stands,
				instance
			)
		end
	end

	return stands
end


local function getCharacterRoot(): BasePart?
	local character =
		player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if root
		and root:IsA("BasePart") then

		return root
	end

	return nil
end


local function getAdornee(
	stand: Model
): BasePart?
	local position =
		stand:FindFirstChild(
			"ManagementUIPosition",
			true
		)

	if position
		and position:IsA(
			"BasePart"
		) then

		return position
	end

	if stand.PrimaryPart then
		return stand.PrimaryPart
	end

	return stand:FindFirstChildWhichIsA(
		"BasePart",
		true
	)
end


local function addCorner(
	parent: Instance,
	radius: number
)
	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(
			0,
			radius
		)

	corner.Parent = parent
end


local function addStroke(
	parent: Instance,
	thickness: number
)
	local stroke =
		Instance.new("UIStroke")

	stroke.Color =
		Color3.fromRGB(
			25,
			28,
			32
		)

	stroke.Thickness =
		thickness

	stroke.Transparency =
		0.15

	stroke.Parent = parent
end


local function getLevel(
	stand: Model
): number
	local value =
		stand:GetAttribute(
			"Level"
		)

	if typeof(value) ~= "number" then
		return 1
	end

	return math.max(
		1,
		math.floor(value)
	)
end


local function refreshAllStandUis()
	for _, state in standUis do
		state.Refresh()
	end
end


local function destroyStandUi(
	stand: Model
)
	local state =
		standUis[stand]

	if not state then
		return
	end

	state.Gui:Destroy()
	standUis[stand] = nil

	if pendingStand == stand then
		pendingStand = nil
	end
end


local function createUpgradeGui(
	stand: Model
)
	if standUis[stand] then
		return
	end

	local adornee =
		getAdornee(stand)

	if not adornee then
		warn(
			`{stand:GetFullName()} is missing ManagementUIPosition.`
		)

		return
	end

	local billboard =
		Instance.new(
			"BillboardGui"
		)

	billboard.Name =
		"BusinessUpgradeUI"

	billboard.Adornee =
		adornee

	billboard.Size =
		UDim2.fromOffset(
			250,
			118
		)

	-- Keep the appearance upgrade UI above the
	-- existing Move / Remove / Upgrade management UI.
	billboard.StudsOffsetWorldSpace =
		Vector3.new(
			0,
			6.5,
			0
		)

	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	billboard.MaxDistance =
		MANAGEMENT_DISTANCE + 3

	billboard.Active = true
	billboard.Enabled = false
	billboard.ResetOnSpawn = false

	billboard.Parent =
		playerGui


	local container =
		Instance.new("Frame")

	container.Name =
		"Container"

	container.Size =
		UDim2.fromScale(
			1,
			1
		)

	container.BackgroundColor3 =
		Color3.fromRGB(
			31,
			35,
			40
		)

	container.BackgroundTransparency =
		0.04

	container.BorderSizePixel = 0
	container.Active = true

	container.Parent =
		billboard

	addCorner(
		container,
		12
	)

	addStroke(
		container,
		2
	)


	local levelLabel =
		Instance.new("TextLabel")

	levelLabel.Name =
		"LevelLabel"

	levelLabel.Position =
		UDim2.fromOffset(
			10,
			7
		)

	levelLabel.Size =
		UDim2.new(
			1,
			-20,
			0,
			24
		)

	levelLabel.BackgroundTransparency = 1

	levelLabel.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	levelLabel.Font =
		Enum.Font.GothamBold

	levelLabel.TextSize = 17

	levelLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	levelLabel.Parent =
		container


	local detailsLabel =
		Instance.new("TextLabel")

	detailsLabel.Name =
		"DetailsLabel"

	detailsLabel.Position =
		UDim2.fromOffset(
			10,
			31
		)

	detailsLabel.Size =
		UDim2.new(
			1,
			-20,
			0,
			27
		)

	detailsLabel.BackgroundTransparency =
		1

	detailsLabel.TextColor3 =
		Color3.fromRGB(
			205,
			210,
			220
		)

	detailsLabel.Font =
		Enum.Font.Gotham

	detailsLabel.TextSize =
		13

	detailsLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	detailsLabel.Parent =
		container


	local upgradeButton =
		Instance.new("TextButton")

	upgradeButton.Name =
		"UpgradeButton"

	upgradeButton.Position =
		UDim2.fromOffset(
			10,
			67
		)

	upgradeButton.Size =
		UDim2.new(
			1,
			-20,
			0,
			40
		)

	upgradeButton.BackgroundColor3 =
		Color3.fromRGB(
			50,
			185,
			90
		)

	upgradeButton.BorderSizePixel = 0
	upgradeButton.AutoButtonColor = true

	upgradeButton.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	upgradeButton.Font =
		Enum.Font.GothamBold

	upgradeButton.TextSize = 15
	upgradeButton.Active = true
	upgradeButton.Selectable = true
	upgradeButton.Interactable = true

	upgradeButton.Parent =
		container

	addCorner(
		upgradeButton,
		9
	)

	addStroke(
		upgradeButton,
		1.5
	)


	local function refresh()
		if not stand.Parent then
			return
		end

		local level =
			getLevel(stand)

		local displayConfig =
			DISPLAY_LEVELS[level]

		levelLabel.Text =
			`Lemonade Stand — Level {level}`

		if not displayConfig then
			detailsLabel.Text =
				"Appearance level unlocked."

			upgradeButton.Text =
				"MAX LEVEL"

			upgradeButton.BackgroundColor3 =
				Color3.fromRGB(
					95,
					100,
					110
				)

			upgradeButton.Interactable =
				false

			return
		end

		detailsLabel.Text =
			displayConfig.Description
			or "Appearance level unlocked."

		if not displayConfig.UpgradeCost then
			upgradeButton.Text =
				"MAX LEVEL"

			upgradeButton.BackgroundColor3 =
				Color3.fromRGB(
					95,
					100,
					110
				)

			upgradeButton.Interactable =
				false

			return
		end

		upgradeButton.Text =
			string.format(
				"UPGRADE TO LEVEL %d — $%d",
				level + 1,
				displayConfig.UpgradeCost
			)

		upgradeButton.BackgroundColor3 =
			Color3.fromRGB(
				50,
				185,
				90
			)

		-- Only one appearance upgrade request can
		-- be running for this player at once.
		upgradeButton.Interactable =
			pendingStand == nil
	end


	upgradeButton.MouseButton1Click:Connect(
		function()
			if pendingStand then
				return
			end

			if not stand.Parent then
				return
			end

			pendingStand = stand

			refreshAllStandUis()

			upgradeButton.Text =
				"UPGRADING..."

			requestUpgradeRemote:FireServer(
				stand
			)
		end
	)


	stand:GetAttributeChangedSignal(
		"Level"
	):Connect(
		refresh
	)


	standUis[stand] = {
		Gui = billboard,
		Refresh = refresh,
	}

	refresh()
end


local function synchronizeStandUis()
	local activeStands:
		{[Model]: boolean} = {}

	for _, stand in
		getOwnedStands()
	do
		activeStands[stand] = true

		if not standUis[stand] then
			createUpgradeGui(
				stand
			)
		end
	end

	-- Remove GUIs belonging to stands that were
	-- deleted, upgraded/replaced, or moved away.
	for stand in standUis do
		if not activeStands[stand]
			or not stand.Parent then

			destroyStandUi(
				stand
			)
		end
	end
end


upgradeResultRemote.OnClientEvent:Connect(
	function(
		success: boolean,
		message: string,
		_level: number?
	)
		pendingStand = nil

	if success then
		print(message)
	else
		warn(message)
	end

	-- Appearance upgrades replace the old model with
	-- a new model. The synchronization loop discovers
	-- the replacement and creates its own GUI.
	refreshAllStandUis()
end
)


task.spawn(function()
	while true do
		synchronizeStandUis()

		local root =
			getCharacterRoot()

		local editingBusiness =
			player:GetAttribute(
				"EditingBusiness"
			)

		for stand, state in standUis do
			local shouldShow = false

			if root
				and stand.Parent
				and editingBusiness == nil
				and stand:GetAttribute(
					"StandUnavailable"
				) ~= true then

				local distance =
					(
						root.Position
						- stand:GetPivot().Position
					).Magnitude

				shouldShow =
					distance
					<= MANAGEMENT_DISTANCE
			end

			state.Gui.Enabled =
				shouldShow
		end

		task.wait(
			UPDATE_INTERVAL
		)
	end
end)