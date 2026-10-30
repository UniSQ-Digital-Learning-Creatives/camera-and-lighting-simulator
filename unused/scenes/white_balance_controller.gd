extends Node

var white_balance_kelvin := 5600.0

func calculate_white_balance_colour() -> Color:
	var t = (white_balance_kelvin - 5600.0) / 3000.0
	
	return Color(
		1.0 + (t * 0.2),
		1.0,
		1.0 - (t * 0.2)
	)
