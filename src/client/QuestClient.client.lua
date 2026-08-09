local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")


local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local FormatNumber =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("FormatNumber")
	)


local getQuestStateRemote =
	remotes:WaitForChild(
		"GetQuestState"
	)

local claimQuestRemote =
	remotes:WaitForChild(
		"ClaimQuest"
	)

local questStateChangedRemote =
	remotes:WaitForChild(
		"QuestStateChanged"
	)

local questClaimResultRemote =
	remotes:WaitForChild(
		"QuestClaimResult"
	)


--==================================================
-- UI REFERENCES
--==================================================

local questsGui =
	playerGui:WaitForChild(
		"Quests"
	) :: ScreenGui


local main =
	questsGui:WaitForChild(
		"Main"
	) :: Frame


local openButton =
	questsGui:WaitForChild(
		"OpenButton"
	) :: TextButton


local openButtonImage =
	openButton:WaitForChild(
		"ImageLabel"
	) :: ImageLabel


local contentFrame =
	main:WaitForChild(
		"Frame"
	) :: Frame


local scrollingFrame =
	contentFrame:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame


local template =
	scrollingFrame:WaitForChild(
		"Template"
	) :: Frame


--==================================================
-- CONSTANTS
--==================================================

local CLOSED_ARROW =
	"rbxassetid://105512300611319"

local OPEN_ARROW =
	"rbxassetid://85497061094623"


local OPEN_TIME =
	0.34

local CLOSE_TIME =
	0.28
--==================================================
-- IMPORTANT:
-- NO LAYOUT/SIZE CHANGES
--==================================================

--
-- We intentionally DO NOT touch:
--
--   Main.Size
--   Template.Size
--   UIGridLayout.CellSize
--   UIGridLayout.CellPadding
--   ScrollingFrame.Size
--   ScrollingFrame.CanvasSize
--   ScrollingFrame.AutomaticCanvasSize
--
-- All of those remain exactly as authored in Studio.
--

questsGui.Enabled =
	true

main.Visible =
	false

template.Visible =
	false


--==================================================
-- REMOVE OLD RUNTIME CLONES
--==================================================

for _, child in
	scrollingFrame:GetChildren()
do
	if child:IsA("Frame")
		and child ~= template then

		child:Destroy()
	end
end


--==================================================
-- QUEST CARD TYPE
--==================================================

type QuestCard = {
	Root: Frame,

	Title: TextLabel,
	Subtitle: TextLabel,

	Reward: TextLabel,

	ProgressText: TextLabel,
	ProgressBar: Frame,

	CompleteButton: TextButton,
	CompleteText: TextLabel,

	QuestId: string,
}


local cards: {
	[string]: QuestCard
} = {}


local currentState = {}
--==================================================
-- DRAWER POSITIONS
--==================================================

--
-- Main.Position in Studio is its OPEN position.
-- We never change Main.Size.
--
local MAIN_OPEN_POSITION =
	main.Position


--
-- Closed button sits against the RIGHT side.
--
-- Keep the Y position you designed in Studio.
--
local BUTTON_CLOSED_POSITION =
	UDim2.new(
		1,
		-75,

		openButton.Position.Y.Scale,
		openButton.Position.Y.Offset
	)


--
-- When the menu is open, the button moves left
-- alongside the quest panel.
--
local BUTTON_OPEN_POSITION =
	UDim2.new(
		0.47,
		0,

		openButton.Position.Y.Scale,
		openButton.Position.Y.Offset
	)


--
-- Main starts to the right of the screen.
-- POSITION ONLY.
--
local MAIN_HIDDEN_POSITION =
	UDim2.new(
		1.05,
		MAIN_OPEN_POSITION.X.Offset,

		MAIN_OPEN_POSITION.Y.Scale,
		MAIN_OPEN_POSITION.Y.Offset
	)


--==================================================
-- DRAWER STATE
--==================================================

local menuOpen =
	false

local animationVersion =
	0


local mainTween: Tween? =
	nil

local buttonTween: Tween? =
	nil


local function stopDrawerTweens()
	if mainTween then
		mainTween:Cancel()

		mainTween =
			nil
	end


	if buttonTween then
		buttonTween:Cancel()

		buttonTween =
			nil
	end
end


--==================================================
-- FORCE CORRECT STARTING STATE
--==================================================

questsGui.Enabled =
	true

main.Visible =
	false

main.Position =
	MAIN_OPEN_POSITION

openButton.Position =
	BUTTON_CLOSED_POSITION

openButtonImage.Image =
	CLOSED_ARROW


--==================================================
-- OPEN DRAWER
--==================================================

local function openDrawer()
	if menuOpen then
		return
	end


	menuOpen =
		true

	animationVersion +=
		1


	local version =
		animationVersion


	stopDrawerTweens()


	--
	-- Put the panel offscreen first.
	--
	main.Position =
		MAIN_HIDDEN_POSITION


	--
	-- IMPORTANT:
	-- Make Main visible BEFORE tweening it.
	--
	main.Visible =
		true


	openButtonImage.Image =
		OPEN_ARROW


	mainTween =
		TweenService:Create(
			main,

			TweenInfo.new(
				0.32,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),

			{
				Position =
					MAIN_OPEN_POSITION,
			}
		)


	buttonTween =
		TweenService:Create(
			openButton,

			TweenInfo.new(
				0.32,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),

			{
				Position =
					BUTTON_OPEN_POSITION,
			}
		)


	mainTween:Play()
	buttonTween:Play()


	mainTween.Completed:Once(
		function()
			if version
					~= animationVersion
				or not menuOpen then

				return
			end


			main.Position =
				MAIN_OPEN_POSITION
		end
	)
end


--==================================================
-- CLOSE DRAWER
--==================================================

local function closeDrawer()
	if not menuOpen then
		return
	end


	menuOpen =
		false

	animationVersion +=
		1


	local version =
		animationVersion


	stopDrawerTweens()


	mainTween =
		TweenService:Create(
			main,

			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Position =
					MAIN_HIDDEN_POSITION,
			}
		)


	buttonTween =
		TweenService:Create(
			openButton,

			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Position =
					BUTTON_CLOSED_POSITION,
			}
		)


	mainTween:Play()
	buttonTween:Play()


	mainTween.Completed:Once(
		function()
			if version
					~= animationVersion
				or menuOpen then

				return
			end


			main.Visible =
				false


			--
			-- Reset while invisible so the next
			-- opening always starts consistently.
			--
			main.Position =
				MAIN_OPEN_POSITION


			openButtonImage.Image =
				CLOSED_ARROW
		end
	)
end


--==================================================
-- TOGGLE
--==================================================

local function toggleDrawer()
	if menuOpen then
		closeDrawer()
	else
		openDrawer()
	end
end
--==================================================
-- BUTTON ANIMATION
--==================================================

local function prepareButton(
	button: TextButton
)
	button.Active =
		true

	button.Selectable =
		true

	button.AutoButtonColor =
		false


	for _, descendant in
		button:GetDescendants()
	do
		if descendant:IsA(
			"GuiObject"
		) then

			descendant.Active =
				false

			descendant.Selectable =
				false
		end
	end


	local scale =
		button:FindFirstChild(
			"ButtonScale"
		)


	if scale
		and not scale:IsA(
			"UIScale"
		) then

		scale:Destroy()

		scale =
			nil
	end


	if not scale then
		scale =
			Instance.new(
				"UIScale"
			)

		scale.Name =
			"ButtonScale"

		scale.Parent =
			button
	end


	scale =
		scale :: UIScale


	scale.Scale =
		1


	local activeTween:
		Tween? =
		nil


	local function tweenTo(
		value: number,
		duration: number
	)
		if activeTween then
			activeTween:Cancel()
		end


		activeTween =
			TweenService:Create(
				scale,

				TweenInfo.new(
					duration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),

				{
					Scale =
						value,
				}
			)


		activeTween:Play()
	end


	button.MouseEnter:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				1.045,
				0.1
			)
		end
	)


	button.MouseLeave:Connect(
		function()
			tweenTo(
				1,
				0.1
			)
		end
	)


	button.MouseButton1Down:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				0.94,
				0.06
			)
		end
	)


	button.MouseButton1Up:Connect(
		function()
			if not button.Active then
				return
			end


			tweenTo(
				1.045,
				0.07
			)
		end
	)
end


prepareButton(
	openButton
)


openButtonImage.Image =
	CLOSED_ARROW


openButton.MouseButton1Click:Connect(
	toggleDrawer
)


--==================================================
-- QUEST CARD CREATION
--==================================================

local function createCard(
	questId: string,
	layoutOrder: number
): QuestCard

	local clone =
		template:Clone()


	clone.Name =
		questId

	clone.LayoutOrder =
		layoutOrder

	clone.Visible =
		true

	clone.Parent =
		scrollingFrame


	local background =
		clone:WaitForChild(
			"Background"
		) :: Frame


	local completeButton =
		clone:WaitForChild(
			"Complete"
		) :: TextButton


	local card: QuestCard = {
		Root =
			clone,

		Title =
			clone:WaitForChild(
				"Title"
			) :: TextLabel,

		Subtitle =
			clone:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		Reward =
			clone:WaitForChild(
				"Reward"
			) :: TextLabel,

		ProgressText =
			background:WaitForChild(
				"Subtitle"
			) :: TextLabel,

		ProgressBar =
			background:WaitForChild(
				"Bar"
			) :: Frame,

		CompleteButton =
			completeButton,

		CompleteText =
			completeButton:WaitForChild(
				"InText"
			) :: TextLabel,

		QuestId =
			questId,
	}


	card.CompleteButton.Text =
		""


	prepareButton(
		card.CompleteButton
	)


	card.CompleteButton
		.MouseButton1Click
		:Connect(
			function()
				if not card
					.CompleteButton
					.Active then

					return
				end


				card.CompleteButton.Active =
					false

				card.CompleteText.Text =
					"CLAIMING..."


				claimQuestRemote:FireServer(
					card.QuestId
				)
			end
		)


	cards[
		questId
	] = card


	return card
end


--==================================================
-- CARD UPDATE
--==================================================

local function formatProgressNumber(
	value: number
): string

	return FormatNumber.Compact(
		math.floor(value)
	)
end


local function updateCard(
	card: QuestCard,
	state
)
	card.Title.Text =
		state.DisplayName
		or state.Id


	card.Subtitle.Text =
		state.Description
		or ""


	card.Reward.Text =
		`REWARD: {FormatNumber.Currency(
			state.RewardCash
				or 0
		)}`


	local progress =
		math.max(
			0,
			state.Progress
				or 0
		)

	local required =
		math.max(
			1,
			state.Required
				or 1
		)


	local ratio =
		math.clamp(
			progress / required,
			0,
			1
		)


	--
	-- This is the ONLY intentional Size modification.
	--
	-- Background.Bar is the progress fill itself.
	-- Template/card/grid sizes are never touched.
	--
	TweenService:Create(
		card.ProgressBar,

		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			Size =
				UDim2.new(
					ratio,
					0,

					card.ProgressBar
						.Size
						.Y
						.Scale,

					card.ProgressBar
						.Size
						.Y
						.Offset
				),
		}
	):Play()


	card.ProgressText.Text =
		`{formatProgressNumber(
			math.min(
				progress,
				required
			)
		)} / {formatProgressNumber(
			required
		)}`


	if state.Claimed then
		card.CompleteText.Text =
			"CLAIMED"

		card.CompleteButton.Active =
			false

		card.CompleteButton.Selectable =
			false

		card.CompleteButton.AutoButtonColor =
			false


	elseif state.Completed then
		card.CompleteText.Text =
			"CLAIM"

		card.CompleteButton.Active =
			true

		card.CompleteButton.Selectable =
			true

		card.CompleteButton.AutoButtonColor =
			false


	else
		card.CompleteText.Text =
			"IN PROGRESS"

		card.CompleteButton.Active =
			false

		card.CompleteButton.Selectable =
			false

		card.CompleteButton.AutoButtonColor =
			false
	end
end


--==================================================
-- WHOLE STATE UPDATE
--==================================================

local function applyState(
	state
)
	if typeof(state)
		~= "table" then

		return
	end


	currentState =
		state


	local seen: {
		[string]: boolean
	} = {}


	for index, quest in
		state
	do
		if typeof(quest)
				~= "table"
			or typeof(quest.Id)
				~= "string" then

			continue
		end


		seen[
			quest.Id
		] = true


		local card =
			cards[
				quest.Id
			]


		if not card then
			card =
				createCard(
					quest.Id,
					index
				)
		end


		card.Root.LayoutOrder =
			index


		updateCard(
			card,
			quest
		)
	end


	for questId, card in
		cards
	do
		if not seen[
			questId
		] then

			card.Root:Destroy()

			cards[
				questId
			] = nil
		end
	end
end


--==================================================
-- INITIAL STATE
--==================================================

local function requestInitialState()
	local success,
		state =
		pcall(
			function()
				return getQuestStateRemote
					:InvokeServer()
			end
		)


	if not success then
		warn(
			"Could not load quest state."
		)

		return
	end


	applyState(
		state
	)
end


task.spawn(
	requestInitialState
)


--==================================================
-- SERVER UPDATES
--==================================================

questStateChangedRemote.OnClientEvent:Connect(
	function(
		state
	)
		applyState(
			state
		)
	end
)


questClaimResultRemote.OnClientEvent:Connect(
	function(
		success: boolean,
		message: string
	)
		if success then
			print(
				message
			)
		else
			warn(
				message
			)
		end
	end
)