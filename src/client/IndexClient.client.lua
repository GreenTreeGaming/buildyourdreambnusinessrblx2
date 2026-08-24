local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


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


--==================================================
-- GUI
--==================================================

local gui =
	playerGui:WaitForChild(
		"ManageUI"
	) :: ScreenGui


local mainFrame =
	gui:WaitForChild(
		"Main"
	) :: Frame


local title =
	mainFrame:WaitForChild(
		"Title"
	) :: TextLabel


local subtitle =
	mainFrame:FindFirstChild(
		"Subtitle"
	)


local indexButton =
	mainFrame:WaitForChild(
		"IndexButton"
	) :: TextButton


local indexFrame =
	mainFrame:WaitForChild(
		"IndexFrame"
	) :: Frame


local buttons =
	indexFrame:WaitForChild(
		"Buttons"
	) :: Frame


local businessesButton =
	buttons:WaitForChild(
		"Businesses"
	) :: GuiButton


local customersButton =
	buttons:WaitForChild(
		"Customers"
	) :: GuiButton


local businessesFrame =
	indexFrame:WaitForChild(
		"BusinessesFrame"
	) :: ScrollingFrame


local businessTemplate =
	businessesFrame:WaitForChild(
		"Template"
	) :: Frame


-- Existing Manage UI pages.
local marketingFrame =
	mainFrame:FindFirstChild(
		"Frame"
	)


local plotFrame =
	mainFrame:FindFirstChild(
		"PlotFrame"
	)


local reputationFrame =
	mainFrame:FindFirstChild(
		"ReputationFrame"
	)


local marketingButton =
	mainFrame:FindFirstChild(
		"MarketingButton"
	)


local plotButton =
	mainFrame:FindFirstChild(
		"PlotButton"
	)


local reputationButton =
	mainFrame:FindFirstChild(
		"ReputationButton"
	)


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
	35


local CAMERA_PADDING =
	1.4


--==================================================
-- STATE
--==================================================

local indexSelected =
	false


local currentIndexState: {
	BusinessState
} = {}


local loading =
	false


-- The real templates remain hidden.
-- Every generated card is a visible clone.
businessTemplate.Visible =
	false


businessesFrame.AutomaticCanvasSize =
	Enum.AutomaticSize.Y


--==================================================
-- CLEANUP
--==================================================

local function clearGeneratedBusinesses()
	for _, child in
		businessesFrame:GetChildren() do

		if child == businessTemplate then
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


local function clearGeneratedLevels(
	levelsFrame: Frame,
	levelTemplate: Frame
)
	for _, child in
		levelsFrame:GetChildren() do

		if child == levelTemplate then
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
-- VIEWPORT MODEL CLEANUP
--==================================================

local function prepareModelForViewport(
	model: Model,
	unlocked: boolean
)
	for _, descendant in
		model:GetDescendants() do

		-- Scripts have no reason to run in an index preview.
		if descendant:IsA(
			"Script"
		)
			or descendant:IsA(
				"LocalScript"
			) then

			descendant:Destroy()

			continue
		end


		-- Don't display world UI inside previews.
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


			if not unlocked then

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
-- CAMERA
--==================================================

local function positionCamera(
	viewport: ViewportFrame,
	model: Model
)
	local boundingCFrame,
		boundingSize =
		model:GetBoundingBox()


	local center =
		boundingCFrame.Position


	local largestSize =
		math.max(
			boundingSize.X,
			boundingSize.Y,
			boundingSize.Z
		)


	largestSize =
		math.max(
			largestSize,
			1
		)


	local halfFov =
		math.rad(
			VIEWPORT_FOV * 0.5
		)


	local distance =
		(
			largestSize
				/ (
					2
					* math.tan(
						halfFov
					)
				)
		)
		* CAMERA_PADDING


	local direction =
		Vector3.new(
			1,
			0.65,
			1
		).Unit


	local camera =
		Instance.new(
			"Camera"
		)


	camera.Name =
		"IndexCamera"

	camera.FieldOfView =
		VIEWPORT_FOV


	camera.CFrame =
		CFrame.lookAt(
			center
				+ direction
					* distance,

			center
		)


	camera.Parent =
		viewport


	viewport.CurrentCamera =
		camera
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


	viewport.BackgroundTransparency =
		1


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

		-- Locked previews receive no viewport light at all.
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
			`[Index] ReplicatedStorage.BusinessModels is missing model "{templateName}".`
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


	positionCamera(
		viewport,
		model
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


	populateViewport(
		viewport,
		levelState.TemplateName,
		levelState.Unlocked
	)


	levelCard.Parent =
		levelsFrame
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


	for _, levelState in
		businessState.Levels do

		createLevelCard(
			levelsFrame,
			levelTemplate,
			levelState
		)
	end


	card.Parent =
		businessesFrame
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
-- REQUEST INDEX
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
-- PAGE VISIBILITY
--==================================================

local function hideExistingPages()
	if marketingFrame
		and marketingFrame:IsA(
			"GuiObject"
		) then

		marketingFrame.Visible =
			false
	end


	if plotFrame
		and plotFrame:IsA(
			"GuiObject"
		) then

		plotFrame.Visible =
			false
	end


	if reputationFrame
		and reputationFrame:IsA(
			"GuiObject"
		) then

		reputationFrame.Visible =
			false
	end
end


local function deactivateExistingButtons()
	for _, button in {
		marketingButton,
		plotButton,
		reputationButton,
	} do

		if button
			and button:IsA(
				"GuiButton"
			) then

			button.BackgroundTransparency =
				0.2
		end
	end
end


local function showIndex()
	indexSelected =
		true


	hideExistingPages()


	indexFrame.Visible =
		true


	-- User specifically requested the ManageUI title
	-- to simply become "Index".
	title.Text =
		"Index"


	if subtitle
		and subtitle:IsA(
			"TextLabel"
		) then

		subtitle.Text =
			"Discover every business and upgrade level!"
	end


	deactivateExistingButtons()


	indexButton.BackgroundTransparency =
		0


	-- Start on Businesses.
	businessesFrame.Visible =
		true


	requestIndexState()
end


local function leaveIndex()
	indexSelected =
		false

	indexFrame.Visible =
		false


	indexButton.BackgroundTransparency =
		0.2
end


--==================================================
-- BUTTONS
--==================================================

indexButton.Activated:Connect(
	function()

		showIndex()
	end
)


businessesButton.Activated:Connect(
	function()

		businessesFrame.Visible =
			true
	end
)


-- Customers is intentionally left for the next stage
-- of the Index.
customersButton.Activated:Connect(
	function()

		-- We don't have a CustomersFrame yet.
		-- Leave the businesses page as-is for now.
	end
)


local function connectExistingTab(
	button: Instance?
)
	if not button
		or not button:IsA(
			"GuiButton"
		) then

		return
	end


	button.Activated:Connect(
		function()

			leaveIndex()
		end
	)
end


connectExistingTab(
	marketingButton
)

connectExistingTab(
	plotButton
)

connectExistingTab(
	reputationButton
)


--==================================================
-- REFRESH EVENTS
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

			if indexSelected then

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

			if indexSelected then

				requestIndexState()
			end
		end
	)
end


--==================================================
-- REOPEN SAFETY
--==================================================

-- MarketingMenuClient remembers its own last tab.
-- If the player closed the menu while on Index and
-- opens it again, re-apply Index after its normal
-- showTab() has run.

mainFrame:GetPropertyChangedSignal(
	"Visible"
):Connect(
	function()

		if not mainFrame.Visible
			or not indexSelected then

			return
		end


		task.defer(
			function()

				if mainFrame.Visible
					and indexSelected then

					hideExistingPages()

					indexFrame.Visible =
						true

					title.Text =
						"Index"


					if subtitle
						and subtitle:IsA(
							"TextLabel"
						) then

						subtitle.Text =
							"Discover every business and upgrade level!"
					end
				end
			end
		)
	end
)


--==================================================
-- INITIAL STATE
--==================================================

indexFrame.Visible =
	false

businessesFrame.Visible =
	false