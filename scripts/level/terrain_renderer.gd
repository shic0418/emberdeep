class_name TerrainRenderer
extends Node2D
## Draws placeholder cavern art for a LevelLayout: shaded rock with pale
## lichen lips, glowing crystals, stone slab platforms, and bone-white spikes.
## Decoration is seeded by tile coordinates, so it is stable across reloads.

const ROCK := Color("2e2a3a")
const ROCK_DARK := Color("221f2c")
const ROCK_LIP := Color("5a6672")
const LICHEN := Color("5f8f7a")
const CRYSTAL := Color("6fd6e8")
const SLAB := Color("6b5a48")
const SLAB_DARK := Color("3d3329")
const SPIKE := Color("cfc6b4")
const BACKDROP := Color("0f0d18")
const BACKDROP_PILLAR := Color("17152a")

var layout: LevelLayout


func _draw() -> void:
	if layout == null:
		return
	var size := layout.get_size()
	var t := LevelLayout.TILE_SIZE
	draw_rect(Rect2(-64, -64, size.x * t + 128, size.y * t + 128), ROCK_DARK)
	draw_rect(layout.get_pixel_rect(), BACKDROP)
	_draw_backdrop_pillars(size)
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			match layout.get_cell(cell):
				LevelLayout.SOLID:
					_draw_rock(cell)
				LevelLayout.PLATFORM:
					_draw_platform(cell)
				LevelLayout.SPIKES:
					_draw_spikes(cell)


## Faint distant rock columns for depth.
func _draw_backdrop_pillars(size: Vector2i) -> void:
	var t := LevelLayout.TILE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layout.level_id)
	var x := 0.0
	while x < size.x * t:
		var w := rng.randf_range(24.0, 60.0)
		var color := BACKDROP.lerp(BACKDROP_PILLAR, rng.randf_range(0.4, 1.0))
		draw_rect(Rect2(x, 0, w, size.y * t), color)
		x += w + rng.randf_range(40.0, 140.0)


func _draw_rock(cell: Vector2i) -> void:
	var t := float(LevelLayout.TILE_SIZE)
	var rect := Rect2(Vector2(cell) * t, Vector2(t, t))
	var noise := _cell_hash(cell)
	draw_rect(rect, ROCK.lerp(ROCK_DARK, (noise % 5) / 8.0))
	if not layout.is_solid(cell + Vector2i.UP):
		draw_rect(Rect2(rect.position, Vector2(t, 3)), ROCK_LIP)
		if noise % 3 == 0:
			draw_rect(Rect2(rect.position + Vector2(noise % 10, -2), Vector2(4, 2)), LICHEN)
	if not layout.is_solid(cell + Vector2i.DOWN):
		draw_rect(Rect2(rect.position + Vector2(0, t - 2), Vector2(t, 2)), ROCK_DARK)
	if not layout.is_solid(cell + Vector2i.LEFT):
		draw_rect(Rect2(rect.position, Vector2(2, t)), ROCK_LIP.darkened(0.4))
	if not layout.is_solid(cell + Vector2i.RIGHT):
		draw_rect(Rect2(rect.position + Vector2(t - 2, 0), Vector2(2, t)), ROCK_LIP.darkened(0.4))
	if noise % 23 == 0 and not layout.is_solid(cell + Vector2i.UP):
		var base := rect.position + Vector2(6 + noise % 5, 0)
		draw_colored_polygon(PackedVector2Array([
			base, base + Vector2(2, -7), base + Vector2(4, 0)]), CRYSTAL)


func _draw_platform(cell: Vector2i) -> void:
	var t := float(LevelLayout.TILE_SIZE)
	var pos := Vector2(cell) * t
	draw_rect(Rect2(pos, Vector2(t, 4)), SLAB)
	draw_rect(Rect2(pos + Vector2(0, 4), Vector2(t, 2)), SLAB_DARK)
	if layout.get_cell(cell + Vector2i.LEFT) != LevelLayout.PLATFORM \
			or layout.get_cell(cell + Vector2i.RIGHT) != LevelLayout.PLATFORM:
		draw_rect(Rect2(pos + Vector2(6, 6), Vector2(4, 5)), SLAB_DARK)


func _draw_spikes(cell: Vector2i) -> void:
	var t := float(LevelLayout.TILE_SIZE)
	var bottom := Vector2(cell.x * t, (cell.y + 1) * t)
	for i in 3:
		var x := bottom.x + 1.0 + i * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, bottom.y), Vector2(x + 2.5, bottom.y - 9.0), Vector2(x + 5.0, bottom.y)]), SPIKE)


func _cell_hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)
