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
-- UI
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

local updateFrame =
	openButton:WaitForChild(
		"Update"
	) :: Frame


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
	0.30

local CLOSE_TIME =
	0.24


--
-- ONLY drawer positioning number.
--
-- Your previous 0.30 was pulling the entire drawer
-- way too far left.
--
local DRAWER_X_SHIFT =
	0.225


--==================================================
-- STARTING STATE
--==================================================

questsGui.Enabled =
	true

main.Visible =
	false

template.Visible =
	false

updateFrame.Visible =
	false

--==================================================
-- REMOVE RUNTIME CLONES
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
-- TYPES
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

--==================================================
-- DRAWER POSITIONS
--==================================================

--
-- Studio positions are CLOSED positions.
--
local MAIN_CLOSED_POSITION =
	main.Position

local BUTTON_CLOSED_POSITION =
	openButton.Position


local MAIN_OPEN_POSITION =
	UDim2.new(
		MAIN_CLOSED_POSITION.X.Scale
			- DRAWER_X_SHIFT,

		MAIN_CLOSED_POSITION.X.Offset,

		MAIN_CLOSED_POSITION.Y.Scale,
		MAIN_CLOSED_POSITION.Y.Offset
	)


local BUTTON_OPEN_POSITION =
	UDim2.new(
		BUTTON_CLOSED_POSITION.X.Scale
			- DRAWER_X_SHIFT,

		BUTTON_CLOSED_POSITION.X.Offset,

		BUTTON_CLOSED_POSITION.Y.Scale,
		BUTTON_CLOSED_POSITION.Y.Offset
	)


--==================================================
-- DRAWER STATE
--==================================================

local menuOpen =
	false

local animationVersion =
	0


local mainTween:
	Tween? =
	nil

local buttonTween:
	Tween? =
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


main.Position =
	MAIN_CLOSED_POSITION

openButton.Position =
	BUTTON_CLOSED_POSITION

openButtonImage.Image =
	CLOSED_ARROW


--==================================================
-- OPEN
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


	main.Position =
		MAIN_CLOSED_POSITION

	openButton.Position =
		BUTTON_CLOSED_POSITION


	main.Visible =
		true


	openButtonImage.Image =
		OPEN_ARROW


	mainTween =
		TweenService:Create(
			main,

			TweenInfo.new(
				OPEN_TIME,
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
				OPEN_TIME,
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

			openButton.Position =
				BUTTON_OPEN_POSITION
		end
	)
end


--==================================================
-- CLOSE
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
				CLOSE_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),

			{
				Position =
					MAIN_CLOSED_POSITION,
			}
		)


	buttonTween =
		TweenService:Create(
			openButton,

			TweenInfo.new(
				CLOSE_TIME,
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


			main.Position =
				MAIN_CLOSED_POSITION

			openButton.Position =
				BUTTON_CLOSED_POSITION


			openButtonImage.Image =
				CLOSED_ARROW
		end
	)
end


local function toggleDrawer()
	if menuOpen then
		closeDrawer()
	else
		openDrawer()
	end
end


--==================================================
-- BUTTON EFFECTS
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


	local tween:
		Tween? =
		nil


	local function tweenTo(
		value: number,
		duration: number
	)
		if tween then
			tween:Cancel()
		end


		tween =
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


		tween:Play()
	end


	button.MouseEnter:Connect(
		function()
			if button.Active then
				tweenTo(
					1.045,
					0.10
				)
			end
		end
	)


	button.MouseLeave:Connect(
		function()
			tweenTo(
				1,
				0.10
			)
		end
	)


	button.MouseButton1Down:Connect(
		function()
			if button.Active then
				tweenTo(
					0.94,
					0.06
				)
			end
		end
	)


	button.MouseButton1Up:Connect(
		function()
			if button.Active then
				tweenTo(
					1.045,
					0.07
				)
			end
		end
	)
end


prepareButton(
	openButton
)


openButton.MouseButton1Click:Connect(
	toggleDrawer
)


--==================================================
-- CREATE QUEST CARD
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
	] =
		card


	return card
end


--==================================================
-- FORMAT
--==================================================

local function formatProgressNumber(
	value: number
): string

	return FormatNumber.Compact(
		math.floor(value)
	)
end


--==================================================
-- UPDATE CARD
--==================================================

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
	-- Only the progress bar fill changes size.
	--
	local currentSize =
		card.ProgressBar.Size


	TweenService:Create(
		card.ProgressBar,

		TweenInfo.new(
			0.20,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),

		{
			Size =
				UDim2.new(
					ratio,
					0,

					currentSize.Y.Scale,
					currentSize.Y.Offset
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


	if state.Completed then
		card.CompleteText.Text =
			"CLAIM"

		card.CompleteButton.Active =
			true

		card.CompleteButton.Selectable =
			true
	else
		card.CompleteText.Text =
			"IN PROGRESS"

		card.CompleteButton.Active =
			false

		card.CompleteButton.Selectable =
			false
	end
end


--==================================================
-- APPLY SERVER STATE
--==================================================

local function applyState(
	state
)
	if typeof(state) ~= "table" then
		return
	end


	local seen: {
		[string]: boolean
	} = {}


	local hasClaimableQuest =
		false


	for index, quest in state do
		if typeof(quest) ~= "table"
			or typeof(quest.Id) ~= "string" then

			continue
		end


		seen[
			quest.Id
		] = true


		local isCompleted =
			quest.Completed == true


		if isCompleted then
			hasClaimableQuest =
				true
		end


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


	-- Remove quest cards that disappeared
	-- after being claimed/replaced.
	for questId, card in cards do
		if not seen[
			questId
		] then

			card.Root:Destroy()

			cards[
				questId
			] = nil
		end
	end


	-- Keep the indicator visible for as long as
	-- at least one quest reward is ready to claim.
	updateFrame.Visible =
		hasClaimableQuest
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
-- LIVE UPDATES
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