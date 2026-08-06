local FormatNumber = {}

local SUFFIXES = {
	{ Value = 1e39, Suffix = "Dd" }, -- Duodecillion
	{ Value = 1e36, Suffix = "Ud" }, -- Undecillion
	{ Value = 1e33, Suffix = "Dc" }, -- Decillion
	{ Value = 1e30, Suffix = "No" }, -- Nonillion
	{ Value = 1e27, Suffix = "Oc" }, -- Octillion
	{ Value = 1e24, Suffix = "Sp" }, -- Septillion
	{ Value = 1e21, Suffix = "Sx" }, -- Sextillion
	{ Value = 1e18, Suffix = "Qi" }, -- Quintillion
	{ Value = 1e15, Suffix = "Qa" }, -- Quadrillion
	{ Value = 1e12, Suffix = "T" },
	{ Value = 1e9, Suffix = "B" },
	{ Value = 1e6, Suffix = "M" },
	{ Value = 1e3, Suffix = "K" },
}

local MAX_DECIMAL_PLACES = 6

local function isValidNumber(
	value: any
): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function clampDecimalPlaces(
	decimalPlaces: number?
): number
	if typeof(decimalPlaces) ~= "number" then
		return 1
	end

	return math.clamp(
		math.floor(decimalPlaces),
		0,
		MAX_DECIMAL_PLACES
	)
end

local function trimTrailingZeros(
	text: string
): string
	-- Removes zeros at the end of the decimal portion.
	text = string.gsub(
		text,
		"(%..-)0+$",
		"%1"
	)

	-- Removes a decimal point if nothing remains after it.
	text = string.gsub(
		text,
		"%.$",
		""
	)

	return text
end

local function roundToDecimalPlaces(
	value: number,
	decimalPlaces: number
): number
	local multiplier =
		10 ^ decimalPlaces

	return math.floor(
		value * multiplier + 0.5
	) / multiplier
end

local function formatDecimal(
	value: number,
	decimalPlaces: number
): string
	local formatString =
		"%." .. decimalPlaces .. "f"

	return trimTrailingZeros(
		string.format(
			formatString,
			value
		)
	)
end

local function addCommas(
	integerText: string
): string
	local reversed =
		string.reverse(integerText)

	local grouped =
		string.gsub(
			reversed,
			"(%d%d%d)",
			"%1,"
		)

	grouped =
		string.reverse(grouped)

	if string.sub(grouped, 1, 1) == "," then
		grouped =
			string.sub(grouped, 2)
	end

	return grouped
end

function FormatNumber.Compact(
	value: number,
	decimalPlaces: number?
): string
	if not isValidNumber(value) then
		return "0"
	end

	local places =
		clampDecimalPlaces(
			decimalPlaces
		)

	local negative =
		value < 0

	local absoluteValue =
		math.abs(value)

	local formatted =
		"0"

	for _, suffixDefinition in SUFFIXES do
		if absoluteValue
			>= suffixDefinition.Value then

			local shortenedValue =
				absoluteValue
				/ suffixDefinition.Value

			shortenedValue =
				roundToDecimalPlaces(
					shortenedValue,
					places
				)

			-- Rounding can turn 999.99K into 1000K.
			-- Promote it to the next suffix when possible.
			local suffixIndex =
				table.find(
					SUFFIXES,
					suffixDefinition
				)

			if shortenedValue >= 1000
				and suffixIndex
				and suffixIndex > 1 then

				local largerDefinition =
					SUFFIXES[
						suffixIndex - 1
					]

				shortenedValue =
					absoluteValue
						/ largerDefinition.Value

				shortenedValue =
					roundToDecimalPlaces(
						shortenedValue,
						places
					)

				formatted =
					formatDecimal(
						shortenedValue,
						places
					)
					.. largerDefinition.Suffix
			else
				formatted =
					formatDecimal(
						shortenedValue,
						places
					)
					.. suffixDefinition.Suffix
			end

			if negative then
				return "-" .. formatted
			end

			return formatted
		end
	end

	formatted =
		formatDecimal(
			absoluteValue,
			places
		)

	if negative then
		return "-" .. formatted
	end

	return formatted
end

function FormatNumber.Currency(
	value: number,
	decimalPlaces: number?
): string
	if not isValidNumber(value) then
		return "$0"
	end

	local compact =
		FormatNumber.Compact(
			math.abs(value),
			decimalPlaces
		)

	if value < 0 then
		return "-$" .. compact
	end

	return "$" .. compact
end

function FormatNumber.Full(
	value: number,
	decimalPlaces: number?
): string
	if not isValidNumber(value) then
		return "0"
	end

	local places =
		clampDecimalPlaces(
			decimalPlaces
		)

	local negative =
		value < 0

	local absoluteValue =
		math.abs(value)

	local formatted =
		formatDecimal(
			absoluteValue,
			places
		)

	local integerPart, decimalPart =
		string.match(
			formatted,
			"^(%d+)%.?(%d*)$"
		)

	integerPart =
		addCommas(
			integerPart or "0"
		)

	if decimalPart
		and decimalPart ~= "" then

		formatted =
			integerPart
				.. "."
				.. decimalPart
	else
		formatted =
			integerPart
	end

	if negative then
		return "-" .. formatted
	end

	return formatted
end

function FormatNumber.FullCurrency(
	value: number,
	decimalPlaces: number?
): string
	if not isValidNumber(value) then
		return "$0"
	end

	local formatted =
		FormatNumber.Full(
			math.abs(value),
			decimalPlaces
		)

	if value < 0 then
		return "-$" .. formatted
	end

	return "$" .. formatted
end

return FormatNumber