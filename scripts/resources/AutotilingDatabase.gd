## Autotiling Database Resource
##
## Contains all learned patterns for a specific tileset, extracted from professional
## Fire Emblem maps. Provides intelligent tile selection based on neighbor context.
@tool
class_name AutotilingDatabase
extends Resource

## Tileset ID this database applies to
@export var tileset_id: String = ""

## Dictionary mapping pattern signatures to TilePattern resources
## signature (String) -> TilePattern
@export var patterns: Dictionary = {}

## Dictionary mapping terrain IDs to available tile indices
## terrain_id (int) -> Array[int] of tile indices
@export var terrain_tiles: Dictionary = {}

## Dictionary mapping tiles to their related/similar tiles
## tile_index (int) -> Array[int] of related tiles
@export var tile_relationships: Dictionary = {}

## Cache for frequently accessed patterns
var _pattern_cache: Dictionary = {}

## Statistics about pattern extraction
@export var extraction_stats: Dictionary = {}

## Initialize the database and build lookup caches
func initialize():
	_build_caches()
	_calculate_stats()

## Builds internal caches for fast pattern lookups
func _build_caches():
	_pattern_cache.clear()
	
	# Build terrain tile mapping if not already done
	if terrain_tiles.is_empty():
		_build_terrain_tiles_mapping()
	
	# Build tile relationships
	_build_tile_relationships()

## Builds mapping of terrain types to available tiles
func _build_terrain_tiles_mapping():
	terrain_tiles.clear()
	
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		var terrain_id = pattern.center_terrain
		
		if terrain_id not in terrain_tiles:
			var typed_array: Array[int] = []
			terrain_tiles[terrain_id] = typed_array
		
		for tile_index in pattern.valid_tiles:
			if tile_index not in terrain_tiles[terrain_id]:
				terrain_tiles[terrain_id].append(tile_index)

## Builds relationships between similar tiles
func _build_tile_relationships():
	tile_relationships.clear()
	
	# Group tiles by terrain type
	var terrain_groups = {}
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		var terrain_id = pattern.center_terrain
		
		if terrain_id not in terrain_groups:
			var typed_array: Array[int] = []
			terrain_groups[terrain_id] = typed_array
		
		for tile_index in pattern.valid_tiles:
			if tile_index not in terrain_groups[terrain_id]:
				terrain_groups[terrain_id].append(tile_index)
	
	# Set relationships within terrain groups
	for terrain_id in terrain_groups:
		var tiles = terrain_groups[terrain_id]
		for tile in tiles:
			tile_relationships[tile] = tiles.duplicate()

## Gets the best tile for given terrain and neighbor context
func get_best_tile(center_terrain: int, neighbors: Array[int]) -> int:
	var signature = create_neighbor_signature(center_terrain, neighbors)
	
	# Count how many neighbors are the same terrain
	var same_terrain_count = 0
	for n in neighbors:
		if n == center_terrain:
			same_terrain_count += 1
	
	# Try exact pattern match first
	if signature in patterns:
		var pattern = patterns[signature] as TilePattern
		var tile = pattern.get_primary_tile()
		# Use primary tile for consistency
		return tile
	
	# Try with wildcards (ignore some neighbors)
	var fallback_tile = get_fallback_tile(center_terrain, neighbors)
	if fallback_tile != -1:
		return fallback_tile
	
	# Last resort: any tile of the right terrain
	var default_tile = get_default_tile_for_terrain(center_terrain)
	return default_tile

## Gets a fallback tile using partial pattern matching
func get_fallback_tile(center_terrain: int, neighbors: Array[int]) -> int:
	var best_match_score = 0
	var best_tile = -1
	
	# Try to find patterns with similar neighbor configurations
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		if pattern.center_terrain != center_terrain:
			continue
		
		var match_score = calculate_neighbor_similarity(neighbors, pattern.neighbor_terrains)
		if match_score > best_match_score:
			best_match_score = match_score
			best_tile = pattern.get_primary_tile()
	
	return best_tile

## Calculates similarity score between two neighbor arrays
func calculate_neighbor_similarity(neighbors1: Array[int], neighbors2: Array[int]) -> int:
	if neighbors1.size() != 8 or neighbors2.size() != 8:
		return 0
	
	var matches = 0
	for i in range(8):
		if neighbors1[i] == neighbors2[i]:
			matches += 1
	
	return matches

## Gets default tile for a terrain type (most common one)
func get_default_tile_for_terrain(terrain_id: int) -> int:
	if terrain_id not in terrain_tiles:
		return 0  # Fallback tile
	
	var tiles = terrain_tiles[terrain_id]
	if tiles.is_empty():
		return 0
	
	# Return first tile (usually most common due to how we build the list)
	return tiles[0]

## Creates pattern signature from terrain and neighbors
func create_neighbor_signature(center: int, neighbors: Array[int]) -> String:
	if neighbors.size() != 8:
		push_error("Invalid neighbor array size: %d" % neighbors.size())
		return ""
	
	var neighbor_str = "_".join(neighbors.map(str))
	return str(center) + "_" + neighbor_str

## Adds a new pattern to the database
func add_pattern(center_terrain: int, neighbors: Array[int], tile_index: int, source_map: String):
	var signature = create_neighbor_signature(center_terrain, neighbors)
	
	if signature not in patterns:
		var pattern = TilePattern.new()
		pattern.center_terrain = center_terrain
		# Ensure proper typing when duplicating the neighbors array
		pattern.neighbor_terrains.assign(neighbors)
		patterns[signature] = pattern
	
	var pattern = patterns[signature] as TilePattern
	pattern.add_valid_tile(tile_index)
	pattern.add_source_map(source_map)
	pattern.increment_frequency()

## Gets all patterns for a specific terrain type
func get_patterns_for_terrain(terrain_id: int) -> Array[TilePattern]:
	var terrain_patterns: Array[TilePattern] = []
	
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		if pattern.center_terrain == terrain_id:
			terrain_patterns.append(pattern)
	
	return terrain_patterns

## Gets the total number of patterns in the database
func get_pattern_count() -> int:
	return patterns.size()

## Gets database statistics
func get_stats() -> Dictionary:
	return {
		"tileset_id": tileset_id,
		"total_patterns": patterns.size(),
		"terrain_types": terrain_tiles.size(),
		"total_tiles": _count_total_tiles(),
		"avg_tiles_per_pattern": _calculate_avg_tiles_per_pattern(),
		"quality_distribution": _get_quality_distribution()
	}

## Calculates internal statistics
func _calculate_stats():
	extraction_stats = {
		"patterns_extracted": patterns.size(),
		"terrains_covered": terrain_tiles.size(),
		"total_tile_variants": _count_total_tiles(),
		"extraction_timestamp": Time.get_datetime_string_from_system()
	}

## Counts total unique tiles across all patterns
func _count_total_tiles() -> int:
	var unique_tiles = {}
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		for tile in pattern.valid_tiles:
			unique_tiles[tile] = true
	return unique_tiles.size()

## Calculates average tiles per pattern
func _calculate_avg_tiles_per_pattern() -> float:
	if patterns.is_empty():
		return 0.0
	
	var total_tiles = 0
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		total_tiles += pattern.valid_tiles.size()
	
	return float(total_tiles) / float(patterns.size())

## Gets quality score distribution
func _get_quality_distribution() -> Dictionary:
	var distribution = {"high": 0, "medium": 0, "low": 0}
	
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		var quality = pattern.get_quality_score()
		
		if quality >= 0.7:
			distribution.high += 1
		elif quality >= 0.4:
			distribution.medium += 1
		else:
			distribution.low += 1
	
	return distribution

## Validates the database integrity
func validate() -> Dictionary:
	var issues = []
	var warnings = []
	
	# Check for empty patterns
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		if pattern.valid_tiles.is_empty():
			issues.append("Pattern %s has no valid tiles" % signature)
		
		if pattern.frequency == 0:
			warnings.append("Pattern %s has zero frequency" % signature)
		
		if pattern.neighbor_terrains.size() != 8:
			issues.append("Pattern %s has invalid neighbor count: %d" % [signature, pattern.neighbor_terrains.size()])
	
	# Check terrain tile mapping
	for terrain_id in terrain_tiles:
		if terrain_tiles[terrain_id].is_empty():
			warnings.append("Terrain %d has no available tiles" % terrain_id)
	
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings,
		"total_patterns": patterns.size(),
		"empty_patterns": _count_empty_patterns()
	}

## Counts patterns with no valid tiles
func _count_empty_patterns() -> int:
	var count = 0
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		if pattern.valid_tiles.is_empty():
			count += 1
	return count

## Exports database to JSON for external analysis
func export_to_json() -> String:
	var export_data = {
		"tileset_id": tileset_id,
		"extraction_stats": extraction_stats,
		"patterns": {},
		"terrain_tiles": terrain_tiles
	}
	
	for signature in patterns:
		var pattern = patterns[signature] as TilePattern
		export_data.patterns[signature] = pattern.get_debug_info()
	
	return JSON.stringify(export_data, "\t")

func _to_string() -> String:
	return "AutotilingDB(%s): %d patterns, %d terrains" % [
		tileset_id, patterns.size(), terrain_tiles.size()
	]
