local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local CodeConfig =
	require(
		ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("CodeConfig")
	)

local DataService =
	require(
		script.Parent
			:WaitForChild("DataService")
	)


local CodeService = {}


local MAX_CODE_LENGTH =
	40


local function normalizeCode(
	input: string
): string

	local code =
		string.upper(input)

	code =
		string.gsub(
			code,
			"%s+",
			""
		)

	return code
end


local function getAvailability(
	definition: {[any]: any}
): (
	boolean,
	string?
)

	local now =
		DateTime.now().UnixTimestamp

	local startTime =
		definition.StartTime

	local endTime =
		definition.EndTime


	if typeof(startTime) == "number"
		and now < startTime then

		return false,
			"NotStarted"
	end


	if typeof(endTime) == "number"
		and now > endTime then

		return false,
			"Expired"
	end


	return true,
		nil
end


local function grantReward(
	player: Player,
	reward: {[any]: any}
): boolean

	if type(reward) ~= "table" then
		return false
	end


	if reward.Type == "Cash" then

		local amount =
			reward.Amount

		if typeof(amount) ~= "number"
			or amount ~= amount
			or amount == math.huge
			or amount == -math.huge then

			return false
		end

		amount =
			math.floor(amount)

		if amount <= 0 then
			return false
		end


		return DataService.AddCash(
			player,
			amount
		)
	end


	return false
end


function CodeService.Redeem(
	player: Player,
	input: any
)

	if typeof(input) ~= "string" then
		return {
			Success = false,
			Status = "Invalid",
			Message = "Enter a valid code.",
		}
	end


	if #input > MAX_CODE_LENGTH then
		return {
			Success = false,
			Status = "Invalid",
			Message = "That code is invalid.",
		}
	end


	local code =
		normalizeCode(input)


	if code == "" then
		return {
			Success = false,
			Status = "Empty",
			Message = "Enter a code first.",
		}
	end


	local definition =
		CodeConfig.Codes[code]


	if type(definition) ~= "table" then
		return {
			Success = false,
			Status = "Invalid",
			Message = "That code doesn't exist.",
		}
	end


	local active,
		reason =
		getAvailability(
			definition
		)


	if not active then

		if reason == "NotStarted" then
			return {
				Success = false,
				Status = "NotStarted",
				Message =
					"That code isn't active yet.",
			}
		end


		return {
			Success = false,
			Status = "Expired",
			Message =
				"That code has expired.",
		}
	end


	if DataService.HasRedeemedCode(
		player,
		code
	) then

		return {
			Success = false,
			Status = "AlreadyRedeemed",
			Message =
				"You've already redeemed that code.",
		}
	end


	local marked =
		DataService.MarkCodeRedeemed(
			player,
			code
		)


	if not marked then
		return {
			Success = false,
			Status = "AlreadyRedeemed",
			Message =
				"You've already redeemed that code.",
		}
	end


	local rewardGranted =
		grantReward(
			player,
			definition.Reward
		)


	if not rewardGranted then

		DataService.UnmarkCodeRedeemed(
			player,
			code
		)

		return {
			Success = false,
			Status = "ServerError",
			Message =
				"Something went wrong. Try again.",
		}
	end


	local reward =
		definition.Reward


	if reward.Type == "Cash" then
		return {
			Success = true,
			Status = "Redeemed",

			Message =
				`Code redeemed! You received ${reward.Amount}.`,
		}
	end


	return {
		Success = true,
		Status = "Redeemed",
		Message = "Code redeemed!",
	}
end


return CodeService