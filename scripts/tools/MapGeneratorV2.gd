## Map Generator V2 - With Autotiling Intelligence
##
## Enhanced map generation that uses autotiling patterns for intelligent tile placement.
## Creates more natural-looking maps by considering neighbor relationships.
class_name MapGeneratorV2
extends RefCounted

# Import enums from original MapGenerator
enum Algorithm {
	RANDOM,
	PERLIN_NOISE,
	CELLULAR_AUTOMATA,
	TEMPLATE_BASED,
	STRATEGIC_PLACEMENT
}

enum MapTheme {
	PLAINS,
	FOREST,
	MOUNTAIN,
	DESERT,
	CASTLE,
	VILLAGE,
	MIXED
}

# Generation parameters (same as MapGenerator)
class GenerationParams:
	var width: int = 20
	var height: int = 15
	var tileset_id: String = ""
	var algorithm: Algorithm = Algorithm.PERLIN_NOISE
	var map_theme: MapTheme = MapTheme.PLAINS
	var seed_value: int = -1
	var complexity: float = 0.5  # 0.0 = simple, 1.0 = complex
	var defensive_terrain_ratio: float = 0.3
	var water_ratio: float = 0.1
	var mountain_ratio: float = 0.15
	var forest_ratio: float = 0.25
	var ensure_connectivity: bool = true
	var add_strategic_features: bool = true
	var border_type: String = "natural"  # "natural", "walls", "water", "none"
	var use_autotiling: bool = true  # NEW: Enable/disable autotiling intelligence

## Generate a new map with given parameters
static func generate_map(params: GenerationParams) -> FEMap:
	# Set up random seed
	if params.seed_value > 0:
		seed(params.seed_value)
	else:
		randomize()
	
	var map = FEMap.new()
	map.initialize(params.width, params.height, 0)
	map.tileset_id = params.tileset_id
	map.name = "Generated Map V2 (%s)" % MapGenerator._get_theme_name(params.map_theme)
	map.description = "Procedurally generated using %s algorithm with autotiling" % MapGenerator._get_algorithm_name(params.algorithm)
	
	# Get tileset data for terrain mapping
	var tileset_data = AssetManager.get_tileset_data(params.tileset_id)
	if not tileset_data:
		push_error("Cannot generate map: tileset not found - " + params.tileset_id)
		return map
	
	print("\n=== MAP GENERATION V2 DEBUG ===")
	print("Tileset: %s (%s)" % [params.tileset_id, tileset_data.name])
	print("Algorithm: %s" % MapGenerator._get_algorithm_name(params.algorithm))
	print("Theme: %s" % MapGenerator._get_theme_name(params.map_theme))
	print("Size: %dx%d" % [params.width, params.height])
	print("Seed: %d" % params.seed_value)
	print("Autotiling: %s" % ("ENABLED" if params.use_autotiling else "DISABLED"))
	
	# Check autotiling availability
	if params.use_autotiling and tileset_data.has_autotiling_intelligence():
		var stats = tileset_data.get_autotiling_stats()
		print("Autotiling patterns available: %d patterns, %d terrain types" % [stats.patterns, stats.terrain_coverage])
	else:
		print("Autotiling not available or disabled")
		params.use_autotiling = false
	
	# Generate base terrain layout (terrain IDs, not tile indices)
	var terrain_map = _generate_terrain_layout(map, tileset_data, params)
	
	# Convert terrain IDs to actual tiles using autotiling intelligence
	if params.use_autotiling:
		_apply_autotiling(map, terrain_map, tileset_data)
	else:
		_apply_random_tiles(map, terrain_map, tileset_data)
	
	# Post-processing
	if params.ensure_connectivity:
		_ensure_connectivity_v2(map, tileset_data)
	
	if params.add_strategic_features:
		_add_strategic_features_v2(map, tileset_data, params)
	
	_add_borders_v2(map, tileset_data, params)
	
	# Final autotiling pass to fix any issues from post-processing
	if params.use_autotiling:
		_final_autotiling_pass(map, tileset_data)
	
	# Validate and fix obvious issues
	var validation = MapValidator.validate_map(map)
	if validation.has_critical_issues():
		MapValidator.auto_fix_map(map, validation.issues)
	
	print("Generated map V2: %dx%d using %s with %s" % [
		params.width, params.height, 
		MapGenerator._get_algorithm_name(params.algorithm),
		"autotiling" if params.use_autotiling else "random tiles"
	])
	print("=== END MAP GENERATION V2 ===\n")
	
	return map

## Generate terrain layout (returns 2D array of terrain IDs)
static func _generate_terrain_layout(map: FEMap, tileset_data: FETilesetData, params: GenerationParams) -> Array:
	var terrain_map = []
	for y in range(map.height):
		terrain_map.append([])
		for x in range(map.width):
			terrain_map[y].append(0)  # Default terrain ID
	
	match params.algorithm:
		Algorithm.RANDOM:
			_generate_random_terrain(terrain_map, tileset_data, params)
		Algorithm.PERLIN_NOISE:
			_generate_perlin_terrain(terrain_map, tileset_data, params)
		Algorithm.CELLULAR_AUTOMATA:
			_generate_cellular_terrain(terrain_map, tileset_data, params)
		Algorithm.TEMPLATE_BASED:
			_generate_template_terrain(terrain_map, tileset_data, params)
		Algorithm.STRATEGIC_PLACEMENT:
			_generate_strategic_terrain(terrain_map, tileset_data, params)
	
	return terrain_map

## Generate random terrain layout
static func _generate_random_terrain(terrain_map: Array, tileset_data: FETilesetData, params: GenerationParams):
	var terrain_categories = _get_terrain_categories(tileset_data, params.map_theme)
	
	for y in range(terrain_map.size()):
		for x in range(terrain_map[y].size()):
			var category = _random_terrain_category(params)
			var terrain_id = _get_terrain_for_category(terrain_categories, category)
			terrain_map[y][x] = terrain_id

## Generate Perlin noise terrain layout
static func _generate_perlin_terrain(terrain_map: Array, tileset_data: FETilesetData, params: GenerationParams):
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.1 * (1.0 + params.complexity)
	
	var terrain_categories = _get_terrain_categories(tileset_data, params.map_theme)
	
	for y in range(terrain_map.size()):
		for x in range(terrain_map[y].size()):
			var noise_value = noise.get_noise_2d(x, y)
			var category = _noise_to_terrain_category(noise_value, params)
			var terrain_id = _get_terrain_for_category(terrain_categories, category)
			terrain_map[y][x] = terrain_id

## Other generation algorithms (simplified for brevity)
static func _generate_cellular_terrain(terrain_map: Array, tileset_data: FETilesetData, params: GenerationParams):
	# Implement cellular automata terrain generation
	_generate_perlin_terrain(terrain_map, tileset_data, params)  # Fallback for now

static func _generate_template_terrain(terrain_map: Array, tileset_data: FETilesetData, params: GenerationParams):
	# Implement template-based terrain generation
	_generate_perlin_terrain(terrain_map, tileset_data, params)  # Fallback for now

static func _generate_strategic_terrain(terrain_map: Array, tileset_data: FETilesetData, params: GenerationParams):
	# Implement strategic terrain placement
	_generate_perlin_terrain(terrain_map, tileset_data, params)  # Fallback for now

## Apply autotiling intelligence to convert terrain IDs to tile indices
static func _apply_autotiling(map: FEMap, terrain_map: Array, tileset_data: FETilesetData):
	print("\nApplying autotiling intelligence...")
	var tiles_placed = {}
	var autotile_hits = 0
	var fallback_used = 0
	
	for y in range(map.height):
		for x in range(map.width):
			var center_terrain = terrain_map[y][x]
			
			# Get neighbor terrain IDs
			var neighbors = _get_neighbor_terrains(terrain_map, x, y)
			
			# Use autotiling intelligence to get the best tile
			var tile_index = tileset_data.get_smart_tile(center_terrain, neighbors)
			
			# Track whether autotiling was successful
			if tileset_data.autotiling_db and tileset_data.autotiling_db.get_best_tile(center_terrain, neighbors) != tileset_data.get_basic_tile_for_terrain(center_terrain):
				autotile_hits += 1
			else:
				fallback_used += 1
			
			map.set_tile_at(x, y, tile_index)
			
			# Count tile usage
			if tile_index not in tiles_placed:
				tiles_placed[tile_index] = 0
			tiles_placed[tile_index] += 1
	
	print("Autotiling complete: %d pattern matches, %d fallbacks" % [autotile_hits, fallback_used])
	print("Unique tiles used: %d" % tiles_placed.size())

## Apply random tiles (fallback when autotiling is disabled)
static func _apply_random_tiles(map: FEMap, terrain_map: Array, tileset_data: FETilesetData):
	print("\nApplying random tile selection...")
	
	for y in range(map.height):
		for x in range(map.width):
			var terrain_id = terrain_map[y][x]
			var tiles = tileset_data.get_tiles_with_terrain(terrain_id)
			
			var tile_index = 0
			if not tiles.is_empty():
				tile_index = tiles[randi() % tiles.size()]
			
			map.set_tile_at(x, y, tile_index)

## Get neighbor terrain IDs for autotiling
static func _get_neighbor_terrains(terrain_map: Array, x: int, y: int) -> Array[int]:
	var neighbors: Array[int] = []
	var height = terrain_map.size()
	var width = terrain_map[0].size() if height > 0 else 0
	
	# Get 8 neighbors in clockwise order starting from top
	var offsets = [
		Vector2i(0, -1),   # Top
		Vector2i(1, -1),   # Top-right
		Vector2i(1, 0),    # Right
		Vector2i(1, 1),    # Bottom-right
		Vector2i(0, 1),    # Bottom
		Vector2i(-1, 1),   # Bottom-left
		Vector2i(-1, 0),   # Left
		Vector2i(-1, -1)   # Top-left
	]
	
	for offset in offsets:
		var nx = x + offset.x
		var ny = y + offset.y
		
		if nx >= 0 and nx < width and ny >= 0 and ny < height:
			neighbors.append(terrain_map[ny][nx])
		else:
			neighbors.append(-1)  # Out of bounds
	
	return neighbors

## Final autotiling pass to clean up any inconsistencies
static func _final_autotiling_pass(map: FEMap, tileset_data: FETilesetData):
	if not tileset_data.has_autotiling_intelligence():
		return
	
	print("\nPerforming final autotiling pass...")
	var changes = 0
	
	# Create a copy to avoid modifying while iterating
	var new_tiles = []
	for y in range(map.height):
		new_tiles.append([])
		for x in range(map.width):
			new_tiles[y].append(map.get_tile_at(x, y))
	
	# Check each tile and re-apply autotiling if needed
	for y in range(map.height):
		for x in range(map.width):
			var current_tile = map.get_tile_at(x, y)
			var current_terrain = tileset_data.get_terrain_type(current_tile)
			
			# Get neighbor tiles and convert to terrain IDs
			var neighbor_terrains: Array[int] = []
			var offsets = [
				Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
				Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
			]
			
			for offset in offsets:
				var nx = x + offset.x
				var ny = y + offset.y
				
				if nx >= 0 and nx < map.width and ny >= 0 and ny < map.height:
					var neighbor_tile = map.get_tile_at(nx, ny)
					neighbor_terrains.append(tileset_data.get_terrain_type(neighbor_tile))
				else:
					neighbor_terrains.append(-1)
			
			# Get the best tile for this position
			var best_tile = tileset_data.get_smart_tile(current_terrain, neighbor_terrains)
			
			if best_tile != current_tile:
				new_tiles[y][x] = best_tile
				changes += 1
	
	# Apply changes
	for y in range(map.height):
		for x in range(map.width):
			map.set_tile_at(x, y, new_tiles[y][x])
	
	print("Final pass complete: %d tiles updated" % changes)

## Get terrain categories based on tileset analysis
static func _get_terrain_categories(tileset_data: FETilesetData, map_theme: MapTheme) -> Dictionary:
	var terrain_categories = {
		"plains": [],
		"forest": [],
		"mountain": [],
		"water": [],
		"fort": [],
		"wall": [],
		"floor": []
	}
	
	# Get unique terrain IDs from the tileset
	var terrain_ids = {}
	for tile_index in range(tileset_data.terrain_tags.size()):
		var terrain_id = tileset_data.terrain_tags[tile_index]
		if terrain_id > 0:  # Skip default/null terrain
			terrain_ids[terrain_id] = true
	
	# Categorize terrain IDs (not tile indices)
	for terrain_id in terrain_ids:
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		if not terrain_data:
			continue
		
		var terrain_name = terrain_data.name.to_lower()
		
		# Categorize based on terrain name
		if "plain" in terrain_name or "grass" in terrain_name or "road" in terrain_name:
			terrain_categories["plains"].append(terrain_id)
		elif "forest" in terrain_name or "tree" in terrain_name:
			terrain_categories["forest"].append(terrain_id)
		elif "mountain" in terrain_name or "hill" in terrain_name or "peak" in terrain_name:
			terrain_categories["mountain"].append(terrain_id)
		elif "water" in terrain_name or "sea" in terrain_name or "river" in terrain_name:
			terrain_categories["water"].append(terrain_id)
		elif "fort" in terrain_name or "castle" in terrain_name or "throne" in terrain_name:
			terrain_categories["fort"].append(terrain_id)
		elif "wall" in terrain_name or terrain_data.defense_bonus > 2:
			terrain_categories["wall"].append(terrain_id)
		else:
			terrain_categories["floor"].append(terrain_id)
	
	# Ensure we have at least one terrain ID per category
	if terrain_categories["plains"].is_empty() and not terrain_ids.is_empty():
		terrain_categories["plains"].append(terrain_ids.keys()[0])
	
	return terrain_categories

## Get terrain ID for a category
static func _get_terrain_for_category(terrain_categories: Dictionary, category: String) -> int:
	var terrain_ids = terrain_categories.get(category, [])
	if terrain_ids.is_empty():
		terrain_ids = terrain_categories.get("plains", [0])
	
	if terrain_ids.is_empty():
		return 0  # Default terrain
	
	return terrain_ids[randi() % terrain_ids.size()]

## Convert noise to terrain category
static func _noise_to_terrain_category(noise_value: float, params: GenerationParams) -> String:
	# Normalize noise from [-1, 1] to [0, 1]
	var normalized = (noise_value + 1.0) / 2.0
	
	match params.map_theme:
		MapTheme.PLAINS:
			if normalized < 0.2:
				return "water"
			elif normalized < 0.4:
				return "forest"
			elif normalized < 0.9:
				return "plains"
			else:
				return "mountain"
		
		MapTheme.FOREST:
			if normalized < 0.1:
				return "water"
			elif normalized < 0.6:
				return "forest"
			elif normalized < 0.9:
				return "plains"
			else:
				return "mountain"
		
		MapTheme.MOUNTAIN:
			if normalized < 0.1:
				return "water"
			elif normalized < 0.3:
				return "plains"
			elif normalized < 0.5:
				return "forest"
			else:
				return "mountain"
		
		_:
			return "plains"

## Random terrain category
static func _random_terrain_category(params: GenerationParams) -> String:
	var roll = randf()
	
	if roll < params.water_ratio:
		return "water"
	elif roll < params.water_ratio + params.forest_ratio:
		return "forest"
	elif roll < params.water_ratio + params.forest_ratio + params.mountain_ratio:
		return "mountain"
	else:
		return "plains"

## Ensure connectivity (V2 - terrain-aware)
static func _ensure_connectivity_v2(map: FEMap, tileset_data: FETilesetData):
	# TODO: Implement terrain-aware connectivity
	pass

## Add strategic features (V2 - autotiling-aware)
static func _add_strategic_features_v2(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	# TODO: Implement autotiling-aware strategic features
	pass

## Add borders (V2 - autotiling-aware)
static func _add_borders_v2(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	if params.border_type == "none":
		return
	
	# TODO: Implement autotiling-aware borders
	# For now, use simple border placement
	var border_terrain = _find_border_terrain(tileset_data, params.border_type)
	
	if params.use_autotiling:
		# Create terrain map for borders
		var terrain_map = []
		for y in range(map.height):
			terrain_map.append([])
			for x in range(map.width):
				var current_tile = map.get_tile_at(x, y)
				terrain_map[y].append(tileset_data.get_terrain_type(current_tile))
		
		# Apply border terrain
		for x in range(map.width):
			terrain_map[0][x] = border_terrain
			terrain_map[map.height - 1][x] = border_terrain
		
		for y in range(map.height):
			terrain_map[y][0] = border_terrain
			terrain_map[y][map.width - 1] = border_terrain
		
		# Re-apply autotiling for the whole map
		_apply_autotiling(map, terrain_map, tileset_data)
	else:
		# Simple tile placement
		var border_tiles = tileset_data.get_tiles_with_terrain(border_terrain)
		if not border_tiles.is_empty():
			var border_tile = border_tiles[0]
			
			for x in range(map.width):
				map.set_tile_at(x, 0, border_tile)
				map.set_tile_at(x, map.height - 1, border_tile)
			
			for y in range(map.height):
				map.set_tile_at(0, y, border_tile)
				map.set_tile_at(map.width - 1, y, border_tile)

## Find border terrain ID
static func _find_border_terrain(tileset_data: FETilesetData, border_type: String) -> int:
	# Get all unique terrain IDs
	var terrain_ids = {}
	for terrain_id in tileset_data.terrain_tags:
		if terrain_id > 0:
			terrain_ids[terrain_id] = true
	
	# Find appropriate terrain for border type
	for terrain_id in terrain_ids:
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		if not terrain_data:
			continue
		
		var terrain_name = terrain_data.name.to_lower()
		
		match border_type:
			"walls":
				if "wall" in terrain_name or not terrain_data.is_passable(0, 0):
					return terrain_id
			"water":
				if "water" in terrain_name or "sea" in terrain_name:
					return terrain_id
	
	return 0  # Default terrain

## Create quick preset parameters (with autotiling enabled)
static func create_preset(preset_name: String, tileset_id: String) -> GenerationParams:
	var params = GenerationParams.new()
	params.tileset_id = tileset_id
	params.use_autotiling = true  # Enable by default
	
	match preset_name.to_lower():
		"small_skirmish":
			params.width = 15
			params.height = 12
			params.algorithm = Algorithm.STRATEGIC_PLACEMENT
			params.map_theme = MapTheme.PLAINS
			params.complexity = 0.3
		
		"large_battle":
			params.width = 30
			params.height = 20
			params.algorithm = Algorithm.PERLIN_NOISE
			params.map_theme = MapTheme.MIXED
			params.complexity = 0.7
		
		"forest_maze":
			params.width = 20
			params.height = 15
			params.algorithm = Algorithm.CELLULAR_AUTOMATA
			params.map_theme = MapTheme.FOREST
			params.complexity = 0.8
			params.forest_ratio = 0.6
		
		"mountain_pass":
			params.width = 25
			params.height = 15
			params.algorithm = Algorithm.STRATEGIC_PLACEMENT
			params.map_theme = MapTheme.MOUNTAIN
			params.complexity = 0.5
			params.mountain_ratio = 0.4
		
		"river_crossing":
			params.width = 20
			params.height = 15
			params.algorithm = Algorithm.STRATEGIC_PLACEMENT
			params.map_theme = MapTheme.PLAINS
			params.water_ratio = 0.3
			params.complexity = 0.4
		
		_:  # Default
			params.algorithm = Algorithm.PERLIN_NOISE
			params.map_theme = MapTheme.PLAINS
	
	return params