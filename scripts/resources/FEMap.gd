## Fire Emblem Map Resource
##
## Represents a tactical battle map with tile layout and metadata.
## Compatible with original FEMapCreator .map file format.
@tool
class_name FEMap
extends Resource

## Tileset ID used by this map (e.g., "01000703")
@export var tileset_id: String = ""

## Map width in tiles
@export var width: int = 20

## Map height in tiles  
@export var height: int = 15

## Flat array of tile indices (size = width * height)
## Each value is a tile index (0-1023) in the tileset
@export var tile_data: Array[int] = []

## Human-readable map name
@export var name: String = ""

## Map description
@export var description: String = ""

## Original filename if loaded from file
@export var filename: String = ""

## Map creation/modification timestamp
@export var timestamp: String = ""

## Initializes the map with given dimensions
func initialize(map_width: int, map_height: int, default_tile: int = 0):
	width = map_width
	height = map_height
	tile_data.clear()
	
	# Fill with default tile
	for i in range(width * height):
		tile_data.append(default_tile)

## Gets the tile index at the specified coordinates
## Returns -1 if coordinates are out of bounds
func get_tile_at(x: int, y: int) -> int:
	if not _is_valid_position(x, y):
		return -1
	return tile_data[y * width + x]

## Sets the tile index at the specified coordinates
## Returns true if successful, false if out of bounds
func set_tile_at(x: int, y: int, tile_index: int) -> bool:
	if not _is_valid_position(x, y):
		push_warning("Invalid tile position: (%d, %d)" % [x, y])
		return false
		
	if not _is_valid_tile_index(tile_index):
		push_warning("Invalid tile index: %d" % tile_index)
		return false
		
	tile_data[y * width + x] = tile_index
	return true

## Gets tile index from flat array index
func get_tile_by_index(index: int) -> int:
	if index < 0 or index >= tile_data.size():
		return -1
	return tile_data[index]

## Sets tile by flat array index
func set_tile_by_index(index: int, tile_index: int) -> bool:
	if index < 0 or index >= tile_data.size():
		return false
	tile_data[index] = tile_index
	return true

## Converts 2D coordinates to flat array index
func coords_to_index(x: int, y: int) -> int:
	if not _is_valid_position(x, y):
		return -1
	return y * width + x

## Converts flat array index to 2D coordinates
func index_to_coords(index: int) -> Vector2i:
	if index < 0 or index >= tile_data.size():
		return Vector2i(-1, -1)
	return Vector2i(index % width, index / width)

## Fills a rectangular area with a tile
func fill_rect(start_x: int, start_y: int, end_x: int, end_y: int, tile_index: int):
	var min_x = max(0, min(start_x, end_x))
	var max_x = min(width - 1, max(start_x, end_x))
	var min_y = max(0, min(start_y, end_y))
	var max_y = min(height - 1, max(start_y, end_y))
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			set_tile_at(x, y, tile_index)

## Flood fills an area starting from a position
func flood_fill(start_x: int, start_y: int, new_tile: int) -> int:
	if not _is_valid_position(start_x, start_y):
		return 0
		
	var target_tile = get_tile_at(start_x, start_y)
	if target_tile == new_tile:
		return 0  # Nothing to fill
		
	var tiles_changed = 0
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var visited = {}
	
	while stack.size() > 0:
		var pos = stack.pop_back()
		var key = str(pos.x) + "," + str(pos.y)
		
		if key in visited:
			continue
		visited[key] = true
		
		if get_tile_at(pos.x, pos.y) != target_tile:
			continue
			
		set_tile_at(pos.x, pos.y, new_tile)
		tiles_changed += 1
		
		# Add adjacent positions
		var neighbors = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]
		
		for neighbor in neighbors:
			if _is_valid_position(neighbor.x, neighbor.y):
				var neighbor_key = str(neighbor.x) + "," + str(neighbor.y)
				if not neighbor_key in visited:
					stack.append(neighbor)
	
	return tiles_changed

## Resizes the map, optionally preserving existing data
func resize(new_width: int, new_height: int, preserve_data: bool = true):
	var old_data = tile_data.duplicate() if preserve_data else []
	var old_width = width
	var old_height = height
	
	width = new_width
	height = new_height
	tile_data.clear()
	
	# Initialize with default tiles
	for i in range(width * height):
		tile_data.append(0)
	
	# Copy old data if preserving
	if preserve_data and old_data.size() > 0:
		var copy_width = min(old_width, new_width)
		var copy_height = min(old_height, new_height)
		
		for y in range(copy_height):
			for x in range(copy_width):
				var old_index = y * old_width + x
				var new_index = y * new_width + x
				tile_data[new_index] = old_data[old_index]

## Gets a rectangular section of the map
func get_rect(start_x: int, start_y: int, rect_width: int, rect_height: int) -> Array[int]:
	var result: Array[int] = []
	
	for y in range(rect_height):
		for x in range(rect_width):
			var map_x = start_x + x
			var map_y = start_y + y
			result.append(get_tile_at(map_x, map_y))
	
	return result

## Sets a rectangular section of the map
func set_rect(start_x: int, start_y: int, rect_width: int, rect_height: int, rect_data: Array[int]):
	if rect_data.size() != rect_width * rect_height:
		push_error("Rectangle data size mismatch")
		return
		
	for y in range(rect_height):
		for x in range(rect_width):
			var map_x = start_x + x
			var map_y = start_y + y
			var data_index = y * rect_width + x
			set_tile_at(map_x, map_y, rect_data[data_index])

## Creates a copy of this map
func duplicate_map() -> FEMap:
	var copy = FEMap.new()
	copy.tileset_id = tileset_id
	copy.width = width
	copy.height = height
	copy.tile_data = tile_data.duplicate()
	copy.name = name + " (Copy)"
	copy.description = description
	return copy

## Validates the map data
func validate() -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	
	# Check dimensions
	if width <= 0 or height <= 0:
		issues.append("Invalid dimensions: %dx%d" % [width, height])
	
	# Check tile data size
	var expected_size = width * height
	if tile_data.size() != expected_size:
		issues.append("Tile data size mismatch: %d expected, %d actual" % [expected_size, tile_data.size()])
	
	# Check for invalid tile indices
	var invalid_tiles = 0
	for i in range(tile_data.size()):
		if not _is_valid_tile_index(tile_data[i]):
			invalid_tiles += 1
	
	if invalid_tiles > 0:
		warnings.append("%d invalid tile indices found" % invalid_tiles)
	
	# Check tileset ID
	if tileset_id.is_empty():
		warnings.append("No tileset ID specified")
	
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings,
		"stats": get_stats()
	}

## Gets map statistics
func get_stats() -> Dictionary:
	var tile_counts = {}
	for tile in tile_data:
		tile_counts[tile] = tile_counts.get(tile, 0) + 1
	
	return {
		"dimensions": "%dx%d" % [width, height],
		"total_tiles": tile_data.size(),
		"unique_tiles": tile_counts.size(),
		"tileset_id": tileset_id,
		"tile_distribution": tile_counts
	}

## Checks if position is within map bounds
func _is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

## Checks if tile index is valid (0-1023)
func _is_valid_tile_index(tile_index: int) -> bool:
	return tile_index >= 0 and tile_index < 1024

func _to_string() -> String:
	return "FEMap(%s): %dx%d using tileset %s" % [name, width, height, tileset_id]
