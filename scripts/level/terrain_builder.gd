class_name TerrainBuilder
extends RefCounted
## Turns a LevelLayout into physics nodes: merged rock collision, one-way
## platforms, spike hazards, and a closed boundary around the map.

const WORLD_LAYER := 1
const PLATFORM_LAYER := 1 << 6
const PLAYER_HURTBOX_LAYER := 1 << 3
const PLATFORM_THICKNESS := 4.0
const BOUNDARY_THICKNESS := 64.0
const SPIKE_HEIGHT := 8.0


static func build(layout: LevelLayout, parent: Node) -> void:
	var t := float(LevelLayout.TILE_SIZE)

	var solids := StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = WORLD_LAYER
	solids.collision_mask = 0
	for rect in layout.merge_rects(LevelLayout.SOLID):
		_add_rect(solids, Rect2(Vector2(rect.position) * t, Vector2(rect.size) * t))
	var bounds := layout.get_pixel_rect()
	var b := BOUNDARY_THICKNESS
	_add_rect(solids, Rect2(bounds.position.x - b, bounds.position.y - b, b, bounds.size.y + b * 2))
	_add_rect(solids, Rect2(bounds.end.x, bounds.position.y - b, b, bounds.size.y + b * 2))
	_add_rect(solids, Rect2(bounds.position.x, bounds.position.y - b, bounds.size.x, b))
	_add_rect(solids, Rect2(bounds.position.x, bounds.end.y, bounds.size.x, b))
	parent.add_child(solids)

	var platforms := StaticBody2D.new()
	platforms.name = "Platforms"
	platforms.collision_layer = PLATFORM_LAYER
	platforms.collision_mask = 0
	for rect in layout.merge_rects(LevelLayout.PLATFORM, false):
		var shape := _add_rect(platforms, Rect2(
			Vector2(rect.position) * t, Vector2(rect.size.x * t, PLATFORM_THICKNESS)))
		shape.one_way_collision = true
	parent.add_child(platforms)

	var hazards := Node2D.new()
	hazards.name = "Hazards"
	for rect in layout.merge_rects(LevelLayout.SPIKES, false):
		var spikes := Hitbox.new()
		spikes.name = "Spikes"
		spikes.collision_layer = 0
		spikes.collision_mask = PLAYER_HURTBOX_LAYER
		spikes.continuous = true
		spikes.is_hazard = true
		spikes.damage = 1
		var top := (rect.position.y + 1) * t - SPIKE_HEIGHT
		_add_rect(spikes, Rect2(rect.position.x * t + 2.0, top, rect.size.x * t - 4.0, SPIKE_HEIGHT))
		hazards.add_child(spikes)
	parent.add_child(hazards)


static func _add_rect(body: CollisionObject2D, rect: Rect2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = rect.get_center()
	body.add_child(node)
	return node
