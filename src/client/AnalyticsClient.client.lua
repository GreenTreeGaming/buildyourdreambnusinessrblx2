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


local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local analyticsEvent =
	remotes:WaitForChild(
		"AnalyticsEvent"
	) :: RemoteEvent


--==================================================
-- HELPERS
--==================================================

local function fire(
	eventName: string,
	data: {[string]: any}?
)

	analyticsEvent:FireServer(
		eventName,
		data or {}
	)
end


local function isGuiOpen(
	screenGui: ScreenGui?,
	object: GuiObject?
): boolean

	if not screenGui
		or not object then

		return false
	end


	return screenGui.Enabled
		and object.Visible
end


local function watchOpenState(
	screenGui: ScreenGui,
	object: GuiObject,
	callback: () -> ()
)

	local wasOpen =
		false


	local function refresh()

		local currentlyOpen =
			isGuiOpen(
				screenGui,
				object
			)


		if currentlyOpen
			and not wasOpen then

			callback()
		end


		wasOpen =
			currentlyOpen
	end


	screenGui:GetPropertyChangedSignal(
		"Enabled"
	):Connect(
		refresh
	)


	object:GetPropertyChangedSignal(
		"Visible"
	):Connect(
		refresh
	)


	task.defer(
		refresh
	)
end


--==================================================
-- TUTORIAL
--==================================================

task.spawn(
	function()

		local tutorialGui =
			playerGui:WaitForChild(
				"Tutorial"
			) :: ScreenGui


		local tutorialFrame =
			tutorialGui:WaitForChild(
				"Frame"
			) :: Frame


		watchOpenState(
			tutorialGui,
			tutorialFrame,

			function()

				fire(
					"TutorialStarted"
				)
			end
		)
	end
)


--==================================================
-- PLACEMENT MODE
--==================================================

task.spawn(
	function()

		local addBusinessGui =
			playerGui:WaitForChild(
				"AddBusiness"
			) :: ScreenGui


		local addButtons =
			addBusinessGui:WaitForChild(
				"AddButtons"
			) :: Frame


		watchOpenState(
			addBusinessGui,
			addButtons,

			function()

				fire(
					"EnteredPlacementMode"
				)
			end
		)
	end
)


--==================================================
-- MANAGE STAND / UPGRADES
--==================================================

task.spawn(
	function()

		local manageGui =
			playerGui:WaitForChild(
				"ManageStand"
			) :: ScreenGui


		local main =
			manageGui:WaitForChild(
				"Main"
			) :: Frame


		watchOpenState(
			manageGui,
			main,

			function()

				fire(
					"OpenedManageStand"
				)


				--
				-- The upgrade cards are visible as soon
				-- as Manage Stand opens.
				--
				fire(
					"ViewedUpgrade"
				)
			end
		)
	end
)


--==================================================
-- PLOT EXPANSION UI
--==================================================

task.spawn(
	function()

		local manageGui =
			playerGui:WaitForChild(
				"ManageUI"
			) :: ScreenGui


		local main =
			manageGui:WaitForChild(
				"Main"
			) :: Frame


		local plotFrame =
			main:WaitForChild(
				"PlotFrame"
			) :: Frame


		local wasOpen =
			false


		local function refresh()

			local currentlyOpen =
				manageGui.Enabled
				and main.Visible
				and plotFrame.Visible


			if currentlyOpen
				and not wasOpen then

				fire(
					"OpenedExpansionUI"
				)
			end


			wasOpen =
				currentlyOpen
		end


		manageGui:GetPropertyChangedSignal(
			"Enabled"
		):Connect(
			refresh
		)


		main:GetPropertyChangedSignal(
			"Visible"
		):Connect(
			refresh
		)


		plotFrame:GetPropertyChangedSignal(
			"Visible"
		):Connect(
			refresh
		)


		task.defer(
			refresh
		)
	end
)


--==================================================
-- QUESTS
--==================================================

task.spawn(
	function()

		local questGui =
			playerGui:WaitForChild(
				"Quests"
			) :: ScreenGui


		local main =
			questGui:WaitForChild(
				"Main"
			) :: Frame


		watchOpenState(
			questGui,
			main,

			function()

				fire(
					"FirstQuestViewed"
				)
			end
		)
	end
)


--==================================================
-- DAILY REWARDS
--==================================================

task.spawn(
	function()

		local dailyGui =
			playerGui:WaitForChild(
				"DailyRewards"
			) :: ScreenGui


		local main =
			dailyGui:WaitForChild(
				"Frame"
			) :: Frame


		watchOpenState(
			dailyGui,
			main,

			function()

				fire(
					"OpenedDailyRewards"
				)
			end
		)
	end
)


--==================================================
-- RARE CUSTOMER
--==================================================

task.spawn(
	function()

		local rareCustomerNotification =
			remotes:WaitForChild(
				"RareCustomerNotification"
			) :: RemoteEvent


		rareCustomerNotification
			.OnClientEvent:Connect(
				function(
					customerType: string
				)

					if typeof(
						customerType
					) ~= "string" then

						return
					end


					fire(
						"FirstRareCustomerSeen",

						{
							CustomerType =
								customerType,
						}
					)
				end
			)
	end
)


--==================================================
-- SHOP
--==================================================

task.spawn(
	function()

		local shopGui =
			playerGui:WaitForChild(
				"Shop"
			) :: ScreenGui


		local main =
			shopGui:WaitForChild(
				"Main"
			) :: Frame


		watchOpenState(
			shopGui,
			main,

			function()

				fire(
					"ShopOpened"
				)
			end
		)


		local scrollingFrame =
			main:WaitForChild(
				"ScrollingFrame"
			)


		local gamepasses =
			scrollingFrame:WaitForChild(
				"TopGamepasses"
			)


		local developerProducts =
			scrollingFrame:WaitForChild(
				"DevProducts"
			)


		local connectedButtons: {
			[GuiButton]: boolean
		} = {}


		local function connectContainer(
			container: Instance,
			productType: string
		)

			local function connectCard(
				card: Instance
			)

				if not card:IsA(
					"GuiObject"
				) then

					return
				end


				local button =
					card:FindFirstChild(
						"Buy"
					)


				if not button
					or not button:IsA(
						"GuiButton"
					)
					or connectedButtons[
						button
					] then

					return
				end


				connectedButtons[
					button
				] =
					true


				button.Activated:Connect(
					function()

						local data = {
							Product =
								card.Name,

							ProductType =
								productType,
						}


						--
						-- Clicking Buy means the player
						-- has meaningfully viewed/selected
						-- this offer.
						--
						fire(
							"ProductViewed",
							data
						)


						fire(
							"PurchasePromptOpened",
							data
						)
					end
				)
			end


			for _, card in
				container:GetChildren()
			do

				connectCard(
					card
				)
			end


			container.ChildAdded:Connect(
				connectCard
			)
		end


		connectContainer(
			gamepasses,
			"GamePass"
		)


		connectContainer(
			developerProducts,
			"DeveloperProduct"
		)
	end
)