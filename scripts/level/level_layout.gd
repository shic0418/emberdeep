class_name LevelLayout
extends Resource
## A level authored as a character grid (one tile per character, 16 px tiles).
##
## Legend:
##   #  solid rock          =  one-way platform (drop through with down + jump)
##   ^  spikes (hazard)     .  empty
##   P  player start        C  checkpoint shrine
##   E  Gloomshell enemy    *  glimmer pickup
## Rows may be ragged; short rows are padded with empty space. The builder
## surrounds the grid with solid walls, so the map edge is always closed.

const TILE_SIZE := 16
const SOLID := "#"
const PLATFORM := "="
const SPIKES := "^"
const EMPTY := "."
const PLAYER_START := "P"
const CHECKPOINT := "C"
const ENEMY := "E"
const GLIMMER := "*"
const VALID_CHARS := "#=^.PCE*"

@export var level_id: StringName = &"level"
@export var display_name := ""
@export_multiline var map := ""

var _rows: PackedStringArray = []


func get_rows() -> PackedStringArray:
	if _rows.is_empty():
		_parse()
	return _rows


func get_size() -> Vector2i:
	var rows := get_rows()
	return Vector2i(rows[0].length() if rows.size() > 0 else 0, rows.size())


func get_pixel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(get_size() * TILE_SIZE))


func get_cell(cell: Vector2i) -> String:
	var rows := get_rows()
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return SOLID  # outside the map behaves like the boundary wall
	return rows[cell.y][cell.x]


func is_solid(cell: Vector2i) -> bool:
	return get_cell(cell) == SOLID


## All cells containing the given character, in reading order.
func find_cells(character: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rows := get_rows()
	for y in rows.size():
		var x := rows[y].find(character)
		while x != -1:
			result.append(Vector2i(x, y))
			x = rows[y].find(character, x + 1)
	return result


## Characters in the map that are not part of the legend.
func find_invalid_chars() -> PackedStringArray:
	var bad := PackedStringArray()
	for row in get_rows():
		for c in row:
			if not VALID_CHARS.contains(c) and not bad.has(c):
				bad.append(c)
	return bad


## Pixel position of a cell's bottom-center: where an actor standing in it has its feet.
static func cell_to_feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, (cell.y + 1) * TILE_SIZE)


static func cell_to_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5


## Greedy rectangle cover of all cells matching `character`: horizontal runs
## are merged with identical runs directly below. Keeps collision shape counts low.
func merge_rects(character: String, merge_vertically := true) -> Array[Rect2i]:
	var rows := get_rows()
	var open: Dictionary = {}  # Vector2i(x_start, x_end) -> Rect2i still growing downward
	var done: Array[Rect2i] = []
	for y in rows.size():
		var next_open: Dictionary = {}
		var x := 0
		var row := rows[y]
		while x < row.length():
			if row[x] != character:
				x += 1
				continue
			var start := x
			while x < row.length() and row[x] == character:
				x += 1
			var key := Vector2i(start, x)
			if merge_vertically and open.has(key):
				var rect: Rect2i = open[key]
				rect.size.y += 1
				next_open[key] = rect
				open.erase(key)
			else:
				next_open[key] = Rect2i(start, y, x - start, 1)
		done.append_array(open.values())
		open = next_open
	done.append_array(open.values())
	return done


func _parse() -> void:
	var lines := map.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	while lines.size() > 0 and lines[0].strip_edges() == "":
		lines.remove_at(0)
	var width := 0
	for line in lines:
		width = maxi(width, line.length())
	_rows = PackedStringArray()
	for line in lines:
		_rows.append(line.rpad(width, EMPTY))
