local Players =
	game:GetService("Players")

local MarketplaceService =
	game:GetService("MarketplaceService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local player =
	Players.LocalPlayer

local playerGui =
	player:WaitForChild("PlayerGui")

local ShopConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("ShopConfig")
	)

local shopGui =
	playerGui:WaitForChild("Shop")

local main =
	shopGui:WaitForChild("Main")

local openButton =
	shopGui:WaitForChild("OpenButton")

local closeButton =
	main:WaitForChild("Close")

closeButton.Active =
	true

closeButton.Selectable =
	true

local closeX =
	closeButton:FindFirstChild("X")

if closeX
	and closeX:IsA("GuiObject") then

	closeX.Active =
		false

	closeX.Selectable =
		false
end

local scrollingFrame =
	main:WaitForChild("ScrollingFrame")

local gamepassesFrame =
	scrollingFrame:WaitForChild(
		"TopGamepasses"
	)

local devProductsFrame =
	scrollingFrame:WaitForChild(
		"DevProducts"
	)

--==================================================
-- SHOP OPEN / CLOSE
--==================================================

local mainScale =
	main:FindFirstChildOfClass(
		"UIScale"
	)

if not mainScale then
	mainScale =
		Instance.new("UIScale")

	mainScale.Name =
		"ShopScale"

	mainScale.Scale =
		1

	mainScale.Parent =
		main
end


local activeMenuTween: Tween? =
	nil

local shopOpen =
	false


local function stopMenuTween()
	if activeMenuTween then
		activeMenuTween:Cancel()

		activeMenuTween =
			nil
	end
end


local function openShop()
	-- ScreenGui NEVER gets disabled.
	if not shopGui.Enabled then
		shopGui.Enabled =
			true
	end

	if shopOpen
		and main.Visible then

		return
	end

	shopOpen =
		true

	stopMenuTween()

	-- Only change the FRAME visibility.
	main.Visible =
		true

	openButton.Visible =
		true

	mainScale.Scale =
		0.92

	local tween =
		TweenService:Create(
			mainScale,

			TweenInfo.new(
				0.2,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),

			{
				Scale = 1,
			}
		)

	activeMenuTween =
		tween

	tween.Completed:Once(
		function()
			if activeMenuTween
				~= tween then

				return
			end

			activeMenuTween =
				nil

			mainScale.Scale =
				1
		end
	)

	tween:Play()
end


local function closeShop()
	if not main.Visible then
		shopOpen =
			false

		return
	end

	shopOpen =
		false

	stopMenuTween()

	local tween =
		TweenService:Create(
			mainScale,

			TweenInfo.new(
				0.13,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),

			{
				Scale = 0.92,
			}
		)

	activeMenuTween =
		tween

	tween.Completed:Once(
		function()
			if activeMenuTween
				~= tween then

				return
			end

			activeMenuTween =
				nil

			if not shopOpen then
				-- ONLY hide Main.
				-- Do NOT disable Shop.
				main.Visible =
					false

				mainScale.Scale =
					1

				openButton.Visible =
					true
			end
		end
	)

	tween:Play()
end


--==================================================
-- BUTTONS
--==================================================

openButton.Active =
	true

openButton.Selectable =
	true

closeButton.Active =
	true

closeButton.Selectable =
	true


openButton.Activated:Connect(
	function()
		openShop()
	end
)


closeButton.Activated:Connect(
	function()
		closeShop()
	end
)


--==================================================
-- STARTING STATE
--==================================================

-- ScreenGui stays enabled FOREVER.
shopGui.Enabled =
	true

-- Only Main gets hidden/opened.
main.Visible =
	false

openButton.Visible =
	true

mainScale.Scale =
	1

shopOpen =
	false

local function getBuyButton(
	card: Instance
): TextButton?
	local button =
		card:FindFirstChild("Buy")

	if button
		and button:IsA("TextButton") then

		return button
	end

	return nil
end

local function getButtonText(
	button: TextButton
): TextLabel?
	local label =
		button:FindFirstChild("InText")

	if label
		and label:IsA("TextLabel") then

		return label
	end

	return nil
end

local function setButtonText(
	button: TextButton,
	text: string
)
	local label =
		getButtonText(button)

	if label then
		label.Text =
			text
	else
		button.Text =
			text
	end
end

local function setButtonEnabled(
	button: TextButton,
	enabled: boolean
)
	button.Active =
		enabled

	button.AutoButtonColor =
		enabled

	button.Selectable =
		enabled
end

local function getProductPrice(
	id: number,
	infoType: Enum.InfoType
): number?
	if id <= 0 then
		return nil
	end

	local success, info =
		pcall(function()
			return MarketplaceService:
				GetProductInfo(
					id,
					infoType
				)
		end)

	if not success
		or type(info) ~= "table" then

		warn(
			`Could not get shop product info for ID {id}: {info}`
		)

		return nil
	end

	local price =
		info.PriceInRobux

	if typeof(price)
		~= "number" then

		return nil
	end

	return price
end

local function ownsGamePass(
	id: number
): boolean
	if id <= 0 then
		return false
	end

	local success, result =
		pcall(function()
			return MarketplaceService:
				UserOwnsGamePassAsync(
					player.UserId,
					id
				)
		end)

	if not success then
		warn(
			`Could not check gamepass ownership for {id}: {result}`
		)

		return false
	end

	return result == true
end

local gamePassButtons = {}

local function refreshGamePass(
	key: string,
	config: {[any]: any}
)
	local card =
		gamepassesFrame:FindFirstChild(
			config.FrameName
		)

	if not card then
		warn(
			`Shop gamepass frame "{config.FrameName}" was not found.`
		)

		return
	end

	local button =
		getBuyButton(card)

	if not button then
		warn(
			`{card:GetFullName()} is missing Buy.`
		)

		return
	end

	gamePassButtons[key] =
		button

	if config.Id <= 0 then
		setButtonText(
			button,
			"Set Gamepass ID"
		)

		setButtonEnabled(
			button,
			false
		)

		return
	end

	if ownsGamePass(
		config.Id
	) then

		setButtonText(
			button,
			"Owned"
		)

		setButtonEnabled(
			button,
			false
		)

		return
	end

	local price =
		getProductPrice(
			config.Id,
			Enum.InfoType.GamePass
		)

	if price then
		setButtonText(
			button,
			`Purchase - R{price}`
		)
	else
		setButtonText(
			button,
			"Purchase"
		)
	end

	setButtonEnabled(
		button,
		true
	)
end

local function setupGamePass(
	key: string,
	config: {[any]: any}
)
	local card =
		gamepassesFrame:FindFirstChild(
			config.FrameName
		)

	if not card then
		warn(
			`Shop gamepass frame "{config.FrameName}" was not found.`
		)

		return
	end

	local button =
		getBuyButton(card)

	if not button then
		return
	end

	refreshGamePass(
		key,
		config
	)

	button.Activated:Connect(
		function()
			if config.Id <= 0 then
				return
			end

			if ownsGamePass(
				config.Id
			) then

				refreshGamePass(
					key,
					config
				)

				return
			end

			local success, errorMessage =
				pcall(function()
					MarketplaceService:
						PromptGamePassPurchase(
							player,
							config.Id
						)
				end)

			if not success then
				warn(
					`Could not prompt gamepass purchase: {errorMessage}`
				)
			end
		end
	)
end

local function setupDeveloperProduct(
	config: {[any]: any}
)
	local card =
		devProductsFrame:FindFirstChild(
			config.FrameName
		)

	if not card then
		warn(
			`[Shop] Developer product frame "{config.FrameName}" was not found.`
		)

		return
	end

	local button =
		getBuyButton(card)

	if not button then
		warn(
			`[Shop] {card:GetFullName()} is missing Buy.`
		)

		return
	end

	if config.Id <= 0 then
		setButtonText(
			button,
			"Set Product ID"
		)

		setButtonEnabled(
			button,
			false
		)

		return
	end

	local success, productInfo =
		pcall(function()
			return MarketplaceService:
				GetProductInfo(
					config.Id,
					Enum.InfoType.Product
				)
		end)

	if not success
		or type(productInfo) ~= "table" then

		warn(
			`[Shop] Could not load developer product {config.FrameName} ({config.Id}): {productInfo}`
		)

		setButtonText(
			button,
			"Unavailable"
		)

		setButtonEnabled(
			button,
			false
		)

		return
	end

	print(
		`[Shop] Loaded {config.FrameName}: ID={config.Id}, Name={tostring(productInfo.Name)}, Price={tostring(productInfo.PriceInRobux)}, IsForSale={tostring(productInfo.IsForSale)}`
	)

	if productInfo.IsForSale ~= true then
		warn(
			`[Shop] Developer product {config.FrameName} ({config.Id}) is NOT currently for sale.`
		)

		setButtonText(
			button,
			"Not For Sale"
		)

		setButtonEnabled(
			button,
			false
		)

		return
	end

	local price =
		productInfo.PriceInRobux

	if typeof(price) == "number" then
		setButtonText(
			button,
			`Purchase - R${price}`
		)
	else
		setButtonText(
			button,
			"Purchase"
		)
	end

	setButtonEnabled(
		button,
		true
	)

	button.Activated:Connect(
		function()
			print(
				`[Shop] Purchase button clicked: {config.FrameName}, product ID {config.Id}`
			)

			local promptSuccess,
				promptError =
				pcall(function()

					MarketplaceService:
						PromptProductPurchase(
							player,
							config.Id
						)
				end)

			if not promptSuccess then
				warn(
					`[Shop] PromptProductPurchase FAILED for {config.FrameName} ({config.Id}): {promptError}`
				)

				return
			end

			print(
				`[Shop] PromptProductPurchase called successfully for {config.FrameName}.`
			)
		end
	)
end

for key, config in
	ShopConfig.GamePasses do

	setupGamePass(
		key,
		config
	)
end

for _, config in
	ShopConfig.DeveloperProducts do

	setupDeveloperProduct(
		config
	)
end

MarketplaceService.PromptGamePassPurchaseFinished:
	Connect(function(
		purchasedPlayer: Player,
		gamePassId: number,
		wasPurchased: boolean
	)
		if purchasedPlayer ~= player
			or not wasPurchased then

			return
		end

		task.delay(
			0.75,
			function()
				for key, config in
					ShopConfig.GamePasses do

					if config.Id
						== gamePassId then

						refreshGamePass(
							key,
							config
						)

						break
					end
				end
			end
		)
	end)

openButton.Activated:Connect(
	function()
		openShop()
	end
)

closeButton.Activated:Connect(
	function()
		closeShop()
	end
)

shopGui.Enabled =
	true

main.Visible =
	false

mainScale.Scale =
	1