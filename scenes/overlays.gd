extends Control

@export var show_grid := false
@export var show_action_safe := false
@export var show_title_safe := false

func _draw():
	var w = size.x
	var h = size.y

	# Rule of thirds grid
	if show_grid:
		var x1 = w / 3.0
		var x2 = w * 2.0 / 3.0

		var y1 = h / 3.0
		var y2 = h * 2.0 / 3.0

		var color = Color(1, 1, 1, 0.5)

		draw_line(Vector2(x1, 0), Vector2(x1, h), color, 2)
		draw_line(Vector2(x2, 0), Vector2(x2, h), color, 2)

		draw_line(Vector2(0, y1), Vector2(w, y1), color, 2)
		draw_line(Vector2(0, y2), Vector2(w, y2), color, 2)

		var intersections = [
			Vector2(x1, y1),
			Vector2(x2, y1),
			Vector2(x1, y2),
			Vector2(x2, y2)
		]

		for point in intersections:
			draw_circle(point, 4, Color(1, 1, 0, 0.8))

	# Action Safe
	if show_action_safe:
		var action_margin = 0.05

		var action_rect = Rect2(
			Vector2(w * action_margin, h * action_margin),
			Vector2(
				w * (1.0 - action_margin * 2.0),
				h * (1.0 - action_margin * 2.0)
			)
		)

		draw_rect(
			action_rect,
			Color(1, 1, 0, 0.4),
			false,
			2
		)

	# Title Safe
	if show_title_safe:
		var title_margin = 0.10

		var title_rect = Rect2(
			Vector2(w * title_margin, h * title_margin),
			Vector2(
				w * (1.0 - title_margin * 2.0),
				h * (1.0 - title_margin * 2.0)
			)
		)

		draw_rect(
			title_rect,
			Color(0, 1, 1, 0.4),
			false,
			2
		)
