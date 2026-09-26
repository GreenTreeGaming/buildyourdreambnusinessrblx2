local Players =
	game:GetService(
		"Players"
	)

local MarketplaceService =
	game:GetService(
		"MarketplaceService"
	)

local ReplicatedStorage =
	game:GetService(
		"ReplicatedStorage"
	)


local player =
	Players.LocalPlayer


local playerGui =
	player:WaitForChild(
		"PlayerGui"
	)


--==================================================
-- CONFIG
--==================================================

local ShopConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("ShopConfig")
	)


local config =
	ShopConfig.StarterPack


assert(
	type(config) == "table",
	"[StarterPack] ShopConfig.StarterPack is missing."
)


--==================================================
-- UI
--==================================================

local shopGui =
	playerGui:WaitForChild(
		"Shop"
	)


local main =
	shopGui:WaitForChild(
		"Main"
	)


local scrollingFrame =
	main:WaitForChild(
		"ScrollingFrame"
	)


local starterPack =
	scrollingFrame:WaitForChild(
		"StarterPack"
	) :: GuiObject


local starterPackFrame =
	starterPack:WaitForChild(
		"Frame"
	)


local buyButton =
	starterPackFrame:WaitForChild(
		"Buy"
	) :: TextButton


local limitedTime =
	starterPack:WaitForChild(
		"LimitedTime"
	)


local timerText =
	limitedTime:WaitForChild(
		"InText"
	) :: TextLabel


local buyText =
	buyButton:FindFirstChild(
		"InText"
	)


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
-- STATE
--==================================================

local offerEndsAtPlaytime =
	0


local purchasePromptOpen =
	false


local expired =
	false


--==================================================
-- HELPERS
--==================================================

local function setBuyText(
	text: string
)

	if buyText
		and buyText:IsA(
			"TextLabel"
		) then

		buyText.Text =
			text

	else

		buyButton.Text =
			text
	end
end


local function setButtonEnabled(
	enabled: boolean
)

	buyButton.Active =
		enabled

	buyButton.Selectable =
		enabled

	buyButton.AutoButtonColor =
		enabled
end


local function formatTime(
	seconds: number
): string

	seconds =
		math.max(
			0,
			math.floor(
				seconds
			)
		)


	local minutes =
		math.floor(
			seconds / 60
		)


	local remainingSeconds =
		seconds % 60


	return string.format(
		"%02d:%02d",
		minutes,
		remainingSeconds
	)
end


local function getCurrentTimePlayed(): number

	local value =
		player:GetAttribute(
			"TimePlayed"
		)


	if typeof(value)
		~= "number" then

		return 0
	end


	return math.max(
		0,
		math.floor(
			value
		)
	)
end


local function getRemainingTime(): number

	return math.max(
		0,

		offerEndsAtPlaytime
			- getCurrentTimePlayed()
	)
end


--==================================================
-- LIVE ROBUX PRICE
--==================================================

local function loadPrice()

	local success,
		productInfo =
		pcall(
			function()

				return MarketplaceService:
					GetProductInfo(
						config.Id,
						Enum.InfoType.GamePass
					)
			end
		)


	if not success
		or type(productInfo)
			~= "table" then

		warn(
			"[StarterPack] Could not load gamepass product info:",
			productInfo
		)


		setBuyText(
			"Purchase"
		)


		return
	end


	local price =
		productInfo.PriceInRobux


	if typeof(price)
		== "number" then

		setBuyText(
			`Purchase - R${price}`
		)

	else

		setBuyText(
			"Purchase"
		)
	end
end


--==================================================
-- LOAD STATE
--==================================================

local function refreshState()

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
			"[StarterPack] Failed to load state:",
			state
		)

		starterPack.Visible =
			false


		return
	end


	if type(state)
			~= "table"
		or state.Loaded
			~= true then

		starterPack.Visible =
			false


		return
	end


	if state.Visible
		~= true then

		starterPack.Visible =
			false


		if state.SecondsRemaining
				== 0 then

			timerText.Text =
				"00:00"


			expired =
				true
		end


		return
	end


	expired =
		false


	local secondsRemaining =
		math.max(
			0,

			math.floor(
				tonumber(
					state.SecondsRemaining
				) or 0
			)
		)


	offerEndsAtPlaytime =
		getCurrentTimePlayed()
			+ secondsRemaining


	timerText.Text =
		formatTime(
			secondsRemaining
		)


	starterPack.Visible =
		true


	setButtonEnabled(
		true
	)
end


--==================================================
-- PURCHASE
--==================================================

buyButton.Activated:Connect(
	function()

		if purchasePromptOpen
			or expired
			or not starterPack.Visible
			or not buyButton.Active then

			return
		end


		purchasePromptOpen =
			true


		local success,
			errorMessage =
			pcall(
				function()

					MarketplaceService:
						PromptGamePassPurchase(
							player,
							config.Id
						)
				end
			)


		if not success then

			purchasePromptOpen =
				false


			warn(
				"[StarterPack] Purchase prompt failed:",
				errorMessage
			)
		end
	end
)


--==================================================
-- PURCHASE RESULT
--==================================================

MarketplaceService
	.PromptGamePassPurchaseFinished:
	Connect(
		function(
			purchasedPlayer: Player,
			gamePassId: number,
			wasPurchased: boolean
		)

			if purchasedPlayer
					~= player
				or gamePassId
					~= config.Id then

				return
			end


			purchasePromptOpen =
				false


			if wasPurchased then

				-- Hide immediately. Server performs
				-- the authoritative reward grant.
				starterPack.Visible =
					false


				return
			end


			refreshState()
		end
	)


--==================================================
-- SERVER UPDATE
--==================================================

starterPackUpdated.OnClientEvent:
	Connect(
		function()

			refreshState()
		end
	)


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

			task.delay(
				0.25,
				refreshState
			)
		end
	end
)


--==================================================
-- COUNTDOWN
--==================================================

task.spawn(
	function()

		while starterPack.Parent do

			if starterPack.Visible
				and not expired then

				local remaining =
					getRemainingTime()


				timerText.Text =
					formatTime(
						remaining
					)


				if remaining <= 0 then

					expired =
						true


					timerText.Text =
						"00:00"


					setButtonEnabled(
						false
					)


					-- The offer simply disappears from
					-- the shop when the countdown ends.
					starterPack.Visible =
						false
				end
			end


			task.wait(
				0.25
			)
		end
	end
)


--==================================================
-- INITIAL
--==================================================

starterPack.Visible =
	false


setButtonEnabled(
	false
)


loadPrice()


task.spawn(
	refreshState
)