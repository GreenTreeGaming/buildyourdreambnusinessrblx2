local CustomerTypes = {}


local random =
	Random.new()


export type CustomerTypeConfig = {
	DisplayName: string,

	Weight: number,

	PaymentMultiplier: number,
	TrafficMultiplier: number,

	BusinessPreferences: {
		[string]: number
	}?,

	TextColor: Color3,
	StrokeColor: Color3,
}

--==================================================
-- CONFIG
--==================================================

CustomerTypes.Types = {
	Regular = {
	DisplayName =
		"Regular",

	Weight =
		760,

	PaymentMultiplier =
		1,

	TrafficMultiplier =
		1,

	TextColor =
		Color3.fromRGB(
			88,
			255,
			103
		),

	BusinessPreferences = {
		LemonadeStand = 1.00,
		HotdogStand = 1.00,
		HaircutStand = 1.00,
	},

	StrokeColor =
		Color3.fromRGB(
			25,
			112,
			35
		),
},


Generous = {
	DisplayName =
		"Generous",

	Weight =
		120,

	PaymentMultiplier =
		1.5,

	TrafficMultiplier =
		1,

	TextColor =
		Color3.fromRGB(
			105,
			220,
			255
		),

	BusinessPreferences = {
		LemonadeStand = 1.00,
		HotdogStand = 1.10,
		HaircutStand = 1.05,
	},

	StrokeColor =
		Color3.fromRGB(
			30,
			110,
			160
		),
},


Rich = {
	DisplayName =
		"Rich",

	Weight =
		65,

	PaymentMultiplier =
		2,

	TrafficMultiplier =
		1,

	TextColor =
		Color3.fromRGB(
			93,
			255,
			181
		),

	BusinessPreferences = {
		LemonadeStand = 0.90,
		HotdogStand = 1.05,
		HaircutStand = 1.35,
	},

	StrokeColor =
		Color3.fromRGB(
			24,
			128,
			85
		),
},


VIP = {
	DisplayName =
		"VIP",

	Weight =
		30,

	PaymentMultiplier =
		3,

	TrafficMultiplier =
		1,

	TextColor =
		Color3.fromRGB(
			255,
			226,
			52
		),

	BusinessPreferences = {
		LemonadeStand = 0.75,
		HotdogStand = 1.05,
		HaircutStand = 1.80,
	},

	StrokeColor =
		Color3.fromRGB(
			165,
			112,
			10
		),
},


	Celebrity = {
		DisplayName =
			"Celebrity",

		Weight =
			15,

		PaymentMultiplier =
			2.5,

		TrafficMultiplier =
			1.3,

		TextColor =
			Color3.fromRGB(
				255,
				118,
				218
			),

		BusinessPreferences = {
	LemonadeStand = 0.80,
	HotdogStand = 1.10,
	HaircutStand = 1.65,
},

		StrokeColor =
			Color3.fromRGB(
				153,
				45,
				126
			),
	},


	Influencer = {
		DisplayName =
			"Influencer",

		Weight =
			6,

		PaymentMultiplier =
			3.5,

		TrafficMultiplier =
			1.5,

		TextColor =
			Color3.fromRGB(
				185,
				105,
				255
			),

		BusinessPreferences = {
	LemonadeStand = 0.85,
	HotdogStand = 1.30,
	HaircutStand = 1.45,
},

		StrokeColor =
			Color3.fromRGB(
				93,
				39,
				153
			),
	},


	Billionaire = {
		DisplayName =
			"Billionaire",

		Weight =
			3,

		PaymentMultiplier =
			7,

		TrafficMultiplier =
			1,

		TextColor =
			Color3.fromRGB(
				68,
				224,
				255
			),

		BusinessPreferences = {
	LemonadeStand = 0.60,
	HotdogStand = 0.95,
	HaircutStand = 2.30,
},

		StrokeColor =
			Color3.fromRGB(
				18,
				94,
				145
			),
	},


	Golden = {
		DisplayName =
			"Golden",

		Weight =
			1,

		PaymentMultiplier =
			15,

		TrafficMultiplier =
			1.75,

		TextColor =
			Color3.fromRGB(
				255,
				206,
				36
			),

		BusinessPreferences = {
	LemonadeStand = 0.75,
	HotdogStand = 1.10,
	HaircutStand = 2.00,
},

		StrokeColor =
			Color3.fromRGB(
				150,
				87,
				5
			),
	},
}


--==================================================
-- TOTAL WEIGHT
--==================================================

local totalWeight =
	0


for _, config in
	CustomerTypes.Types do

	totalWeight +=
		config.Weight
end


--==================================================
-- GET
--==================================================

function CustomerTypes.Get(
	customerType: string
): CustomerTypeConfig

	local config =
		CustomerTypes.Types[
			customerType
		]


	if config then
		return config
	end


	return CustomerTypes.Types.Regular
end


--==================================================
-- RANDOM
--==================================================

function CustomerTypes.GetRandomType(): (
	string,
	CustomerTypeConfig
)

	local roll =
		random:NextNumber(
			0,
			totalWeight
		)


	local accumulated =
		0


	for customerType, config in
		CustomerTypes.Types do

		accumulated +=
			config.Weight


		if roll <= accumulated then

			return customerType,
				config
		end
	end


	return "Regular",
		CustomerTypes.Types.Regular
end


return CustomerTypes