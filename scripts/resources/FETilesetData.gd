## Fire Emblem Tileset Data Resource
##
## Contains tileset information including terrain mapping and animation data.
## Maps visual tiles (0-1023) to terrain types and handles tile animations.
@tool
class_name FETilesetData
extends Resource

## Unique tileset ID (matches original hex IDs like "01000703")
@export var id: String = ""

## Human-readable tileset name
@export var name: String = ""

## Graphic filename (e.g., "Plains", "Castle")
@export var graphic_name: String = ""

## Array of 1024 terrain type IDs, one for each tile in the 32x32 grid
## terrain_tags[tile_index] = terrain_type_id
@export var terrain_tags: Array[int] = []

## Animation data for animated tiles in this tileset
@export var animated_tiles: Array[AnimatedTileData] = []

## Godot TileSet resource created from this data
@export var tileset_resource: TileSet

## Texture resource for this tileset
@export var texture: Texture2D

## Autotiling database for intelligent tile placement
@export var autotiling_db: AutotilingDatabase

## Whether pattern analysis has been completed for this tileset
@export var pattern_analysis_complete: bool = false

## Dictionary mapping tile indices to their animation data
var _animation_lookup: Dictionary = {}

## Dictionary mapping base tile indices to animation groups
var _animation_groups: Dictionary = {}

## Initialize the tileset data and build lookup tables
func initialize():
	_build_animation_lookup()

## Builds lookup tables for fast animation queries
func _build_animation_lookup():
	_animation_lookup.clear()
	_animation_groups.clear()
	
	for anim in animated_tiles:
		# Map all tiles in this animation sequence
		for frame in range(anim.frame_count):
			var tile_index = anim.base_tile_index + frame
			_animation_lookup[tile_index] = anim
		
		# Group animations by base tile
		_animation_groups[anim.base_tile_index] = anim

## Gets terrain type ID for a tile index
func get_terrain_type(tile_index: int) -> int:
	if tile_index < 0 or tile_index >= terrain_tags.size():
		return 0  # Default terrain
	return terrain_tags[tile_index]

## Checks if a tile is animated
func is_tile_animated(tile_index: int) -> bool:
	return tile_index in _animation_lookup

## Gets animation data for a tile (null if not animated)
func get_tile_animation(tile_index: int) -> AnimatedTileData:
	return _animation_lookup.get(tile_index, null)

## Gets all animation groups in this tileset
func get_animation_groups() -> Array[AnimatedTileData]:
	return animated_tiles

## Creates terrain tags array from a space-separated string
func set_terrain_tags_from_string(terrain_string: String):
	terrain_tags.clear()
	var parts = terrain_string.split(" ")
	
	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part != "":
			terrain_tags.append(clean_part.to_int())
	
	# Ensure we have exactly 1024 entries
	while terrain_tags.size() < 1024:
		terrain_tags.append(0)

## Parses animation data from the XML format
func parse_animation_data(anim_data_string: String, anim_names: Array[String]):
	animated_tiles.clear()
	var values = anim_data_string.split(" ")
	
	# Parse 4-integer groups: [frame_count, start_delay, frame_duration, base_tile]
	var name_index = 0
	for i in range(0, values.size(), 4):
		if i + 3 >= values.size():
			break
			
		var anim = AnimatedTileData.new()
		anim.frame_count = values[i].strip_edges().to_int()
		anim.start_delay = values[i + 1].strip_edges().to_int()
		anim.frame_duration = values[i + 2].strip_edges().to_int()
		anim.base_tile_index = values[i + 3].strip_edges().to_int()
		
		# Assign name if available
		if name_index < anim_names.size():
			anim.name = anim_names[name_index]
		else:
			anim.name = "Animation_%d" % name_index
			
		animated_tiles.append(anim)
		name_index += 1
	
	# Rebuild lookup tables
	initialize()

## Gets atlas coordinates for a tile index (for Godot TileMap)
func get_atlas_coords(tile_index: int) -> Vector2i:
	var x = tile_index % 32
	var y = tile_index / 32
	return Vector2i(x, y)

## Gets tile index from atlas coordinates
func get_tile_index(atlas_coords: Vector2i) -> int:
	return atlas_coords.y * 32 + atlas_coords.x

## Gets all tiles using a specific terrain type
func get_tiles_with_terrain(terrain_type: int) -> Array[int]:
	var tiles: Array[int] = []
	for i in range(terrain_tags.size()):
		if terrain_tags[i] == terrain_type:
			tiles.append(i)
	return tiles

## Gets smart tile using autotiling intelligence
func get_smart_tile(center_terrain: int, neighbors: Array[int]) -> int:
	if autotiling_db and pattern_analysis_complete:
		return autotiling_db.get_best_tile(center_terrain, neighbors)
	else:
		# Fallback to basic terrain lookup
		return get_basic_tile_for_terrain(center_terrain)

## Gets basic tile for terrain type (fallback method)
func get_basic_tile_for_terrain(terrain_id: int) -> int:
	var tiles = get_tiles_with_terrain(terrain_id)
	if tiles.is_empty():
		return 0  # Default tile
	return tiles[0]  # Return first available tile

## Checks if autotiling intelligence is available
func has_autotiling_intelligence() -> bool:
	return autotiling_db != null and pattern_analysis_complete

## Gets autotiling database statistics
func get_autotiling_stats() -> Dictionary:
	if not has_autotiling_intelligence():
		return {"available": false}
	
	return {
		"available": true,
		"patterns": autotiling_db.patterns.size(),
		"terrain_coverage": autotiling_db.terrain_tiles.size(),
		"extraction_stats": autotiling_db.extraction_stats
	}

## Gets tileset statistics for debugging
func get_stats() -> Dictionary:
	var terrain_counts = {}
	for terrain_id in terrain_tags:
		terrain_counts[terrain_id] = terrain_counts.get(terrain_id, 0) + 1
	
	var stats = {
		"id": id,
		"name": name,
		"total_tiles": terrain_tags.size(),
		"unique_terrains": terrain_counts.size(),
		"animated_groups": animated_tiles.size(),
		"terrain_distribution": terrain_counts,
		"autotiling_available": has_autotiling_intelligence()
	}
	
	if has_autotiling_intelligence():
		stats["autotiling"] = get_autotiling_stats()
	
	return stats

func _to_string() -> String:
	return "FETileset(%s - %s): %d tiles, %d animations" % [
		id, name, terrain_tags.size(), animated_tiles.size()
	]
