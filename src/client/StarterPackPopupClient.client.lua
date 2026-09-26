local Players =
	game:GetService(
		"Players"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)

local TweenService =
	game:GetService(
		"TweenService"
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- POPUP UI
--==================================================

local popupGui =
	playerGui:WaitForChild(
		"StarterPackPopup"
	) :: ScreenGui


local popupMain =
	popupGui:WaitForChild(
		"Main"
	) :: Frame


local yesButton =
	popupMain:WaitForChild(
		"Yes"
	) :: GuiButton


local noButton =
	popupMain:WaitForChild(
		"No"
	) :: GuiButton


--==================================================
-- SHOP
--==================================================

local shopGui =
	playerGui:WaitForChild(
		"Shop"
	) :: ScreenGui


local shopMain =
	shopGui:WaitForChild(
		"Main"
	) :: Frame


local scrollingFrame =
	shopMain:WaitForChild(
		"ScrollingFrame"
	) :: ScrollingFrame


local starterPack =
	scrollingFrame:WaitForChild(
		"StarterPack"
	) :: GuiObject


local openShopRequest =
	shopGui:WaitForChild(
		"OpenShopRequest"
	) :: BindableEvent


--==================================================
-- REMOTES
--==================================================

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local getStarterPackState =
	remotes:WaitForChild(
		"GetStarterPackState"
	) :: RemoteFunction


local starterPackUpdated =
	remotes:WaitForChild(
		"StarterPackUpdated"
	) :: RemoteEvent


--==================================================
-- SETTINGS
--==================================================

-- Small delay after the tutorial ends before
-- showing the offer.
local POPUP_DELAY =
	4


local OPEN_SCALE =
	1


local START_SCALE =
	0.88


local OPEN_TIME =
	0.22


local CLOSE_TIME =
	0.14


--==================================================
-- STATE
--==================================================

local shownThisSession =
	false


local popupOpen =
	false


local activeTween: Tween? =
	nil


--==================================================
-- SCALE
--==================================================

local uiScale =
	popupMain:FindFirstChild(
		"StarterPackPopupScale"
	)


if not uiScale then

	uiScale =
		Instance.new(
			"UIScale"
		)

	uiScale.Name =
		"StarterPackPopupScale"

	uiScale.Scale =
		OPEN_SCALE

	uiScale.Parent =
		popupMain
end


--==================================================
-- HELPERS
--==================================================

local function stopTween()

	if activeTween then

		activeTween:Cancel()

		activeTween =
			nil
	end
end


local function closePopup()

	if not popupOpen then

		popupGui.Enabled =
			false

		return
	end


	popupOpen =
		false


	stopTween()


	local tween =
		TweenService:Create(
			uiScale,

			TweenInfo.new(
				CLOSE_TIME,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale =
					START_SCALE,
			}
		)


	activeTween =
		tween


	tween.Completed:Once(
		function()

			if activeTween
				~= tween then

				return
			end


			activeTween =
				nil


			if not popupOpen then

				popupGui.Enabled =
					false


				uiScale.Scale =
					OPEN_SCALE
			end
		end
	)


	tween:Play()
end


local function openPopup()

	if popupOpen
		or shownThisSession then

		return
	end


	shownThisSession =
		true


	popupOpen =
		true


	stopTween()


	popupGui.Enabled =
		true


	popupMain.Visible =
		true


	uiScale.Scale =
		START_SCALE


	local tween =
		TweenService:Create(
			uiScale,

			TweenInfo.new(
				OPEN_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Scale =
					OPEN_SCALE,
			}
		)


	activeTween =
		tween


	tween.Completed:Once(
		function()

			if activeTween
				~= tween then

				return
			end


			activeTween =
				nil


			uiScale.Scale =
				OPEN_SCALE
		end
	)


	tween:Play()
end


--==================================================
-- STARTER PACK STATE
--==================================================

local function getState()

	local success,
		state =
		pcall(
			function()

				return getStarterPackState:
					InvokeServer()
			end
		)


	if not success then

		warn(
			"[StarterPackPopup] Failed to get Starter Pack state:",
			state
		)

		return nil
	end


	if type(state)
			~= "table"
		or state.Loaded
			~= true then

		return nil
	end


	return state
end


local function offerIsAvailable(): boolean

	local state =
		getState()


	if not state then
		return false
	end


	return state.Visible
		== true
end


--==================================================
-- SCROLL TO STARTER PACK
--==================================================

local function scrollToStarterPack()

	-- Give the Shop a moment to become visible
	-- and calculate AbsolutePosition correctly.
	task.wait(
		0.08
	)


	local currentCanvasY =
		scrollingFrame.CanvasPosition.Y


	local offset =
		starterPack.AbsolutePosition.Y
		- scrollingFrame.AbsolutePosition.Y


	local targetY =
		currentCanvasY
		+ offset
		- 20


	local maximumY =
		math.max(
			0,

			scrollingFrame.AbsoluteCanvasSize.Y
				- scrollingFrame.AbsoluteWindowSize.Y
		)


	targetY =
		math.clamp(
			targetY,
			0,
			maximumY
		)


	TweenService:Create(
		scrollingFrame,

		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),

		{
			CanvasPosition =
				Vector2.new(
					0,
					targetY
				),
		}
	):Play()
end


--==================================================
-- YES
--==================================================

yesButton.Activated:Connect(
	function()

		if not popupOpen then
			return
		end


		closePopup()


		openShopRequest:
			Fire()


		task.spawn(
			scrollToStarterPack
		)
	end
)


--==================================================
-- NO
--==================================================

noButton.Activated:Connect(
	function()

		closePopup()
	end
)


--==================================================
-- SHOW OFFER
--==================================================

local function tryShowPopup()

	if shownThisSession then
		return
	end


	if player:GetAttribute(
		"TutorialCompleted"
	) ~= true then

		return
	end


	if not offerIsAvailable() then
		return
	end


	task.wait(
		POPUP_DELAY
	)


	if shownThisSession then
		return
	end


	-- Check again because they could have bought
	-- or expired the offer during the delay.
	if not offerIsAvailable() then
		return
	end


	openPopup()
end


--==================================================
-- TUTORIAL COMPLETION
--==================================================

player:GetAttributeChangedSignal(
	"TutorialCompleted"
):Connect(
	function()

		if player:GetAttribute(
			"TutorialCompleted"
		) == true then

			task.spawn(
				tryShowPopup
			)
		end
	end
)


--==================================================
-- STARTER PACK STATE CHANGED
--==================================================

starterPackUpdated.OnClientEvent:
	Connect(
		function()

			local state =
				getState()


			if not state
				or state.Visible
					~= true then

				closePopup()
			end
		end
	)


--==================================================
-- INITIAL
--==================================================

popupGui.Enabled =
	false


popupMain.Visible =
	true


uiScale.Scale =
	OPEN_SCALE


task.spawn(
	tryShowPopup
)