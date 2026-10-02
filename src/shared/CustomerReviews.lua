local CustomerReviews = {}


local POSITIVE_REVIEWS = {
	"Great service! I'll definitely come back!",
	"This place is awesome!",
	"I love this business!",
	"Really good service!",
	"That was worth the wait!",
	"The product was amazing!",
	"I had a great experience!",
	"This place keeps getting better!",
	"Absolutely loved it!",
	"That was really good!",
}


local AVERAGE_REVIEWS = {
	"Pretty good, but it could be better.",
	"The service was okay.",
	"Not bad at all.",
	"I'd probably come back.",
	"The product was pretty good.",
	"Good experience overall.",
	"That was decent!",
	"Pretty solid place.",
}


local NEGATIVE_REVIEWS = {
	"The line took way too long.",
	"The service could be faster.",
	"I expected a little more.",
	"This place needs some upgrades.",
	"The wait wasn't worth it.",
	"Could definitely be better.",
}


local randomGenerator =
	Random.new()


function CustomerReviews.GetReview(
	rating: number
): string

	if typeof(rating) ~= "number" then
		rating = 3
	end


	rating =
		math.clamp(
			rating,
			3,
			5
		)


	local reviews


	if rating >= 4.25 then

		reviews =
			POSITIVE_REVIEWS

	elseif rating >= 3.5 then

		reviews =
			AVERAGE_REVIEWS

	else

		reviews =
			NEGATIVE_REVIEWS
	end


	return reviews[
		randomGenerator:NextInteger(
			1,
			#reviews
		)
	]
end


function CustomerReviews.GetColor(
	rating: number
): Color3

	if rating >= 4.25 then

		return Color3.fromRGB(
			72,
			211,
			126
		)

	elseif rating >= 3.5 then

		return Color3.fromRGB(
			255,
			194,
			66
		)

	else

		return Color3.fromRGB(
			255,
			99,
			112
		)
	end
end


return CustomerReviews