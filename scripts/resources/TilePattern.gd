## Tile Pattern Resource
##
## Represents a pattern of terrain relationships found in professional Fire Emblem maps.
## Used by the autotiling system to place tiles that match original map design.
@tool
class_name TilePattern
extends Resource

## Terrain type at the center of this pattern
@export var center_terrain: int = 0

## Array of 8 terrain types for neighboring positions
## Order: NW, N, NE, W, E, SW, S, SE
@export var neighbor_terrains: Array[int] = []

## Array of tile indices that work well in this terrain context
@export var valid_tiles: Array[int] = []

## How often this pattern appears in original maps (higher = more common)
@export var frequency: int = 1

## Source maps where this pattern was found (for debugging/analysis)
@export var source_maps: Array[String] = []

## Creates a unique signature string for this neighbor pattern
func create_signature() -> String:
	var neighbor_str = "_".join(neighbor_terrains.map(str))
	return str(center_terrain) + "_" + neighbor_str

## Adds a valid tile option for this pattern
func add_valid_tile(tile_index: int):
	if tile_index not in valid_tiles:
		valid_tiles.append(tile_index)

## Gets a random valid tile for this pattern
func get_random_tile() -> int:
	if valid_tiles.is_empty():
		return -1
	return valid_tiles[randi() % valid_tiles.size()]

## Gets the most common valid tile (first one added)
func get_primary_tile() -> int:
	return valid_tiles[0] if not valid_tiles.is_empty() else -1

## Adds a source map to the list
func add_source_map(map_path: String):
	if map_path not in source_maps:
		source_maps.append(map_path)

## Increments frequency counter
func increment_frequency():
	frequency += 1

## Gets pattern quality score (0.0 to 1.0)
func get_quality_score() -> float:
	# Quality based on frequency and tile variety
	var frequency_score = min(frequency / 10.0, 1.0)  # Max at 10+ occurrences
	var variety_score = min(valid_tiles.size() / 5.0, 1.0)  # Max at 5+ tile options
	var source_score = min(source_maps.size() / 3.0, 1.0)  # Max at 3+ source maps
	
	return (frequency_score + variety_score + source_score) / 3.0

## Checks if this pattern matches the given neighbor configuration
func matches_neighbors(neighbors: Array[int]) -> bool:
	if neighbors.size() != 8:
		return false
	
	for i in range(8):
		if neighbor_terrains[i] != neighbors[i]:
			return false
	
	return true

## Gets debug information about this pattern
func get_debug_info() -> Dictionary:
	return {
		"signature": create_signature(),
		"center_terrain": center_terrain,
		"neighbors": neighbor_terrains,
		"valid_tiles": valid_tiles,
		"frequency": frequency,
		"quality": get_quality_score(),
		"source_count": source_maps.size(),
		"tile_variety": valid_tiles.size()
	}

func _to_string() -> String:
	return "TilePattern(%s): %d tiles, freq=%d, quality=%.2f" % [
		create_signature(), valid_tiles.size(), frequency, get_quality_score()
	]
