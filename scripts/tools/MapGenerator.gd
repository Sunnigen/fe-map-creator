## Map Generator
##
## Recreates the original FE Map Creator's sophisticated generation algorithm.
## Current implementation: Basic generation + pattern matching (functional)
## TODO: Implement original's Generation_Data + 8-method validation system
class_name MapGenerator
extends RefCounted

# Debug flag for showing plains tiles once
static var has_shown_plains_tiles: bool = false

# Generation algorithms
enum Algorithm {
	RANDOM,
	PERLIN_NOISE,
	CELLULAR_AUTOMATA,
	TEMPLATE_BASED,
	STRATEGIC_PLACEMENT
}

# Map themes
enum MapTheme {
	PLAINS,
	FOREST,
	MOUNTAIN,
	DESERT,
	CASTLE,
	VILLAGE,
	MIXED
}

# Generation parameters (TODO: Recreate original FE Map Creator parameters)
class GenerationParams:
	var width: int = 20
	var height: int = 15
	var tileset_id: String = ""
	var algorithm: Algorithm = Algorithm.PERLIN_NOISE
	var map_theme: MapTheme = MapTheme.PLAINS
	var seed_value: int = -1
	
	# Current basic parameters
	var complexity: float = 0.5  # 0.0 = simple, 1.0 = complex
	var defensive_terrain_ratio: float = 0.3
	var water_ratio: float = 0.1
	var mountain_ratio: float = 0.15
	var forest_ratio: float = 0.25
	var ensure_connectivity: bool = true
	var add_strategic_features: bool = true
	var border_type: String = "natural"  # "natural", "walls", "water", "none"
	
	# TODO: Add original FE Map Creator parameters found in executable:
	# var depth_complexity: float = 0.5     # DepthUpDown - terrain variety
	# var feature_spacing: float = 3.0      # DistUpDown - feature distribution  
	# var priority_bias: float = 0.8        # tile_priorities weighting
	# var terrain_variety: float = 0.7      # Generation_Data configuration

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
	map.name = "Generated Map (%s)" % _get_theme_name(params.map_theme)
	map.description = "Procedurally generated using %s algorithm" % _get_algorithm_name(params.algorithm)
	
	# Get tileset data for terrain mapping
	var tileset_data = AssetManager.get_tileset_data(params.tileset_id)
	if not tileset_data:
		push_error("Cannot generate map: tileset not found - " + params.tileset_id)
		return map
	
	print("\n=== MAP GENERATION DEBUG ===")
	print("🔧 Current: Basic generation + pattern matching")
	print("🎯 TODO: Recreate original's Generation_Data + 8-method validation")
	print("Tileset: %s (%s)" % [params.tileset_id, tileset_data.name])
	print("Algorithm: %s" % _get_algorithm_name(params.algorithm))
	print("Theme: %s" % _get_theme_name(params.map_theme))
	print("Size: %dx%d" % [params.width, params.height])
	print("Seed: %d" % params.seed_value)
	
	# Generate base terrain
	match params.algorithm:
		Algorithm.RANDOM:
			_generate_random(map, tileset_data, params)
		Algorithm.PERLIN_NOISE:
			_generate_perlin_noise(map, tileset_data, params)
		Algorithm.CELLULAR_AUTOMATA:
			_generate_cellular_automata(map, tileset_data, params)
		Algorithm.TEMPLATE_BASED:
			_generate_template_based(map, tileset_data, params)
		Algorithm.STRATEGIC_PLACEMENT:
			_generate_strategic_placement(map, tileset_data, params)
	
	# Post-processing
	if params.ensure_connectivity:
		_ensure_connectivity(map, tileset_data)
	
	if params.add_strategic_features:
		_add_strategic_features(map, tileset_data, params)
	
	_add_borders(map, tileset_data, params)
	
	# Validate and fix obvious issues
	var validation = MapValidator.validate_map(map)
	if validation.has_critical_issues():
		MapValidator.auto_fix_map(map, validation.issues)
	
	print("Generated map: %dx%d using %s" % [params.width, params.height, _get_algorithm_name(params.algorithm)])
	
	# Debug print tile grid for small maps
	if params.width <= 10 and params.height <= 10:
		_debug_print_tile_grid(map, params)
	
	return map

## Generate using random placement
static func _generate_random(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	for y in range(map.height):
		for x in range(map.width):
			var tile_category = _random_terrain_category(params)
			var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
			map.set_tile_at(x, y, tile_index)

## Generate using Perlin noise
static func _generate_perlin_noise(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.1 * (1.0 + params.complexity)
	
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	# First pass: Generate terrain layout using smart tile selection if available
	if tileset_data.has_autotiling_intelligence():
		_generate_perlin_noise_with_intelligence(map, tileset_data, params, noise)
		return
	
	# Fallback to legacy generation
	
	print("\n=== PERLIN NOISE GENERATION DEBUG ===")
	print("Noise seed: %d, frequency: %f" % [noise.seed, noise.frequency])
	
	# Sample some noise values and see what categories they map to
	var sample_positions = [Vector2i(0,0), Vector2i(5,5), Vector2i(10,7), Vector2i(15,12)]
	for pos in sample_positions:
		var noise_value = noise.get_noise_2d(pos.x, pos.y)
		var tile_category = _noise_to_terrain_category(noise_value, params)
		var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
		print("  Sample at (%d,%d): noise=%.3f -> category='%s' -> tile=%d" % [pos.x, pos.y, noise_value, tile_category, tile_index])
	
	var tiles_placed = {}
	for y in range(map.height):
		for x in range(map.width):
			var noise_value = noise.get_noise_2d(x, y)
			var tile_category = _noise_to_terrain_category(noise_value, params)
			var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
			map.set_tile_at(x, y, tile_index)
			
			# Count tile usage
			if tile_index not in tiles_placed:
				tiles_placed[tile_index] = 0
			tiles_placed[tile_index] += 1
	
	print("\nTiles placed:")
	for tile_idx in tiles_placed:
		print("  Tile %d: %d times" % [tile_idx, tiles_placed[tile_idx]])
	print("=== END PERLIN NOISE GENERATION ===\n")

## Generate using cellular automata
static func _generate_cellular_automata(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	# Initial random fill
	var cells = []
	for y in range(map.height):
		cells.append([])
		for x in range(map.width):
			cells[y].append(randf() < 0.45)  # 45% chance for "wall"
	
	# Apply cellular automata rules
	var iterations = int(5 + params.complexity * 3)
	for i in range(iterations):
		cells = _apply_cellular_rules(cells, map.width, map.height)
	
	# Convert to terrain
	for y in range(map.height):
		for x in range(map.width):
			var is_wall = cells[y][x]
			var tile_category = "wall" if is_wall else "floor"
			var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
			map.set_tile_at(x, y, tile_index)

## Generate using template-based approach
static func _generate_template_based(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	# Select template based on theme and size
	var template = _select_map_template(params)
	
	# Apply the template to the map
	_apply_template_to_map(map, template, terrain_tiles, params)
	
	# Add variation and details
	_add_template_variations(map, terrain_tiles, params)

## Apply cellular automata rules
static func _apply_cellular_rules(cells: Array, width: int, height: int) -> Array:
	var new_cells = []
	
	for y in range(height):
		new_cells.append([])
		for x in range(width):
			var wall_count = 0
			
			# Count neighboring walls
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx = x + dx
					var ny = y + dy
					
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						wall_count += 1  # Treat borders as walls
					elif cells[ny][nx]:
						wall_count += 1
			
			# Apply rules
			new_cells[y].append(wall_count >= 4)
	
	return new_cells

## Generate using strategic placement
static func _generate_strategic_placement(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	# Use intelligent strategic placement if available
	if tileset_data.has_autotiling_intelligence():
		_generate_strategic_placement_with_intelligence(map, tileset_data, params)
		return
	
	# Fallback to legacy generation
	# Fill with base terrain
	var base_tile = _get_random_tile_for_category(terrain_tiles, "plains")
	for y in range(map.height):
		for x in range(map.width):
			map.set_tile_at(x, y, base_tile)
	
	# Add strategic features
	_place_mountain_ranges(map, terrain_tiles, params)
	_place_forests(map, terrain_tiles, params)
	_place_water_features(map, terrain_tiles, params)
	_place_defensive_positions(map, terrain_tiles, params)

## Select appropriate template based on parameters
static func _select_map_template(params: GenerationParams) -> Dictionary:
	var templates = _get_map_templates()
	
	# Filter templates by size category
	var size_category = _get_size_category(params.width, params.height)
	var theme_name = _get_theme_name(params.map_theme).to_lower()
	
	# Look for theme-specific template first
	var template_key = theme_name + "_" + size_category
	if template_key in templates:
		return templates[template_key]
	
	# Fall back to generic template
	var generic_key = "generic_" + size_category
	if generic_key in templates:
		return templates[generic_key]
	
	# Ultimate fallback
	return templates["generic_medium"]

## Get predefined map templates
static func _get_map_templates() -> Dictionary:
	var templates = {}
	
	# Small map templates (10-20 tiles)
	templates["generic_small"] = {
		"pattern": [
			"MMMMMMMMMMMMMMMM",
			"M..............M",
			"M..FF....FF....M",
			"M.....~~~~~~...M",
			"M....~~~~~~~...M",
			"M..FF~~~~~~~FF.M",
			"M....~~~~~~~...M",
			"M.....~~~~~~...M",
			"M..FF....FF....M",
			"M..............M",
			"MMMMMMMMMMMMMMMM"
		],
		"legend": {
			"M": "mountain",
			".": "plains",
			"F": "forest",
			"~": "water"
		}
	}
	
	templates["forest_small"] = {
		"pattern": [
			"FFFFFFFFFFFFFFFF",
			"F..............F",
			"F..FF......FF..F",
			"F..............F",
			"F....~~~~~~....F",
			"F...~~~~~~~~...F",
			"F....~~~~~~....F",
			"F..............F",
			"F..FF......FF..F",
			"F..............F",
			"FFFFFFFFFFFFFFFF"
		],
		"legend": {
			"F": "forest",
			".": "plains",
			"~": "water"
		}
	}
	
	# Medium map templates (20-30 tiles)
	templates["generic_medium"] = {
		"pattern": [
			"MMMMMMMMMMMMMMMMMMMMMMMMM",
			"M.......................M",
			"M...FF...........FF.....M",
			"M.......................M",
			"M........~~~~~~~........M",
			"M.......~~~~~~~~~.......M",
			"M......~~~~~~~~~~~......M",
			"M.....~~~~~~~~~~~~~.....M",
			"M......~~~~~~~~~~~......M",
			"M.......~~~~~~~~~.......M",
			"M........~~~~~~~........M",
			"M.......................M",
			"M...FF...........FF.....M",
			"M.......................M",
			"MMMMMMMMMMMMMMMMMMMMMMMMM"
		],
		"legend": {
			"M": "mountain",
			".": "plains",
			"F": "forest",
			"~": "water"
		}
	}
	
	templates["mountain_medium"] = {
		"pattern": [
			"MMMMMMMMMMMMMMMMMMMMMMMMM",
			"MMMM.................MMMM",
			"MMM...................MMM",
			"MM...FF.........FF.....MM",
			"M......................M",
			"M......................M",
			"M........~~~~~.........M",
			"M.......~~~~~~~........M",
			"M........~~~~~.........M",
			"M......................M",
			"M......................M",
			"MM...FF.........FF.....MM",
			"MMM...................MMM",
			"MMMM.................MMMM",
			"MMMMMMMMMMMMMMMMMMMMMMMMM"
		],
		"legend": {
			"M": "mountain",
			".": "plains",
			"F": "forest",
			"~": "water"
		}
	}
	
	# Large map templates (30+ tiles)
	templates["generic_large"] = {
		"pattern": [
			"MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",
			"M................................M",
			"M...FF....................FF.....M",
			"M................................M",
			"M................................M",
			"M..........~~~~~~~~~~............M",
			"M.........~~~~~~~~~~~~...........M",
			"M........~~~~~~~~~~~~~~..........M",
			"M.......~~~~~~~~~~~~~~~~.........M",
			"M........~~~~~~~~~~~~~~..........M",
			"M.........~~~~~~~~~~~~...........M",
			"M..........~~~~~~~~~~............M",
			"M................................M",
			"M................................M",
			"M...FF....................FF.....M",
			"M................................M",
			"MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
		],
		"legend": {
			"M": "mountain",
			".": "plains",
			"F": "forest",
			"~": "water"
		}
	}
	
	return templates

## Get size category for template selection
static func _get_size_category(width: int, height: int) -> String:
	var total_tiles = width * height
	
	if total_tiles <= 300:
		return "small"
	elif total_tiles <= 600:
		return "medium"
	else:
		return "large"

## Apply template pattern to map
static func _apply_template_to_map(map: FEMap, template: Dictionary, terrain_tiles: Dictionary, params: GenerationParams):
	var pattern: Array = template["pattern"]
	var legend = template["legend"]
	
	# Scale template to fit map dimensions
	var scaled_pattern = _scale_template_pattern(pattern, map.width, map.height)
	
	# Apply the scaled pattern
	for y in range(map.height):
		for x in range(map.width):
			if y < scaled_pattern.size() and x < scaled_pattern[y].length():
				var pattern_char = scaled_pattern[y][x]
				var terrain_category = legend.get(pattern_char, "plains")
				var tile_index = _get_random_tile_for_category(terrain_tiles, terrain_category)
				map.set_tile_at(x, y, tile_index)
			else:
				# Fill remaining space with plains
				var tile_index = _get_random_tile_for_category(terrain_tiles, "plains")
				map.set_tile_at(x, y, tile_index)

## Scale template pattern to fit target dimensions
static func _scale_template_pattern(pattern: Array, target_width: int, target_height: int) -> Array[String]:
	var scaled_pattern: Array[String] = []
	
	if pattern.is_empty():
		# Create default pattern
		for y in range(target_height):
			scaled_pattern.append(".".repeat(target_width))
		return scaled_pattern
	
	var template_height = pattern.size()
	var template_width = pattern[0].length() if template_height > 0 else 1
	
	# Simple scaling - repeat or truncate as needed
	for y in range(target_height):
		var template_y = y % template_height
		var template_row = pattern[template_y]
		
		var scaled_row = ""
		for x in range(target_width):
			var template_x = x % template_width
			scaled_row += template_row[template_x]
		
		scaled_pattern.append(scaled_row)
	
	return scaled_pattern

## Add variations to template-based map
static func _add_template_variations(map: FEMap, terrain_tiles: Dictionary, params: GenerationParams):
	# Add random variations to make the template less predictable
	var variation_chance = params.complexity * 0.3  # Up to 30% tiles can be varied
	
	for y in range(map.height):
		for x in range(map.width):
			if randf() < variation_chance:
				# Replace tile with a related terrain type
				var current_tile = map.get_tile_at(x, y)
				var varied_tile = _get_terrain_variation(current_tile, terrain_tiles, params)
				map.set_tile_at(x, y, varied_tile)

## Get a terrain variation for adding randomness
static func _get_terrain_variation(base_tile: int, terrain_tiles: Dictionary, params: GenerationParams) -> int:
	# This is a simplified approach - could be more sophisticated
	var variation_types = ["plains", "forest"]
	
	# Bias variations based on theme
	match params.map_theme:
		MapTheme.FOREST:
			variation_types = ["forest", "plains"]
		MapTheme.MOUNTAIN:
			variation_types = ["mountain", "plains"]
		MapTheme.PLAINS:
			variation_types = ["plains", "forest"]
		_:
			variation_types = ["plains", "forest", "mountain"]
	
	var random_category = variation_types[randi() % variation_types.size()]
	return _get_random_tile_for_category(terrain_tiles, random_category)

## Place mountain ranges
static func _place_mountain_ranges(map: FEMap, terrain_tiles: Dictionary, params: GenerationParams):
	var mountain_tiles = terrain_tiles.get("mountain", [0])
	if mountain_tiles.is_empty():
		return
	
	var num_ranges = int(1 + params.complexity * 2)
	
	for i in range(num_ranges):
		var start_x = randi() % map.width
		var start_y = randi() % map.height
		var length = int(3 + randf() * 8)
		
		_place_line_feature(map, Vector2i(start_x, start_y), length, mountain_tiles[0])

## Place forests
static func _place_forests(map: FEMap, terrain_tiles: Dictionary, params: GenerationParams):
	var forest_tiles = terrain_tiles.get("forest", [0])
	if forest_tiles.is_empty():
		return
	
	var num_forests = int(2 + params.complexity * 3)
	
	for i in range(num_forests):
		var center_x = randi() % map.width
		var center_y = randi() % map.height
		var size = int(2 + randf() * 4)
		
		_place_blob_feature(map, Vector2i(center_x, center_y), size, forest_tiles[0])

## Place water features
static func _place_water_features(map: FEMap, terrain_tiles: Dictionary, params: GenerationParams):
	if params.water_ratio <= 0:
		return
	
	var water_tiles = terrain_tiles.get("water", [0])
	if water_tiles.is_empty():
		return
	
	# Place rivers or lakes
	if randf() < 0.5:
		_place_river(map, water_tiles[0])
	else:
		_place_lakes(map, water_tiles[0], params)

## Place defensive positions
static func _place_defensive_positions(map: FEMap, terrain_tiles: Dictionary, params: GenerationParams):
	var fort_tiles = terrain_tiles.get("fort", [0])
	if fort_tiles.is_empty():
		return
	
	var num_forts = int(1 + params.defensive_terrain_ratio * 3)
	
	for i in range(num_forts):
		var x = randi() % map.width
		var y = randi() % map.height
		map.set_tile_at(x, y, fort_tiles[0])

## Place line feature (like mountain ranges)
static func _place_line_feature(map: FEMap, start: Vector2i, length: int, tile_index: int):
	var current = start
	var direction = Vector2i([-1, 0, 1][randi() % 3], [-1, 0, 1][randi() % 3])
	
	for i in range(length):
		if current.x >= 0 and current.x < map.width and current.y >= 0 and current.y < map.height:
			map.set_tile_at(current.x, current.y, tile_index)
		
		# Randomly change direction
		if randf() < 0.3:
			direction = Vector2i([-1, 0, 1][randi() % 3], [-1, 0, 1][randi() % 3])
		
		current += direction

## Place blob feature (like forests)
static func _place_blob_feature(map: FEMap, center: Vector2i, size: int, tile_index: int):
	for dy in range(-size, size + 1):
		for dx in range(-size, size + 1):
			var distance = sqrt(dx * dx + dy * dy)
			if distance <= size and randf() < (1.0 - distance / size):
				var x = center.x + dx
				var y = center.y + dy
				if x >= 0 and x < map.width and y >= 0 and y < map.height:
					map.set_tile_at(x, y, tile_index)

## Place a river across the map
static func _place_river(map: FEMap, water_tile: int):
	var start_side = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
	var start_pos: Vector2i
	var direction: Vector2i
	
	match start_side:
		0:  # Top
			start_pos = Vector2i(randi() % map.width, 0)
			direction = Vector2i(0, 1)
		1:  # Right
			start_pos = Vector2i(map.width - 1, randi() % map.height)
			direction = Vector2i(-1, 0)
		2:  # Bottom
			start_pos = Vector2i(randi() % map.width, map.height - 1)
			direction = Vector2i(0, -1)
		3:  # Left
			start_pos = Vector2i(0, randi() % map.height)
			direction = Vector2i(1, 0)
	
	var current = start_pos
	var steps = max(map.width, map.height)
	
	for i in range(steps):
		if current.x >= 0 and current.x < map.width and current.y >= 0 and current.y < map.height:
			map.set_tile_at(current.x, current.y, water_tile)
		
		# Randomly meander
		if randf() < 0.3:
			direction = Vector2i(direction.y, direction.x)  # Perpendicular
			if randf() < 0.5:
				direction = -direction
		
		current += direction
		
		# Stop if we hit the opposite edge
		if (start_side == 0 and current.y >= map.height - 1) or \
		   (start_side == 1 and current.x <= 0) or \
		   (start_side == 2 and current.y <= 0) or \
		   (start_side == 3 and current.x >= map.width - 1):
			break

## Place lakes
static func _place_lakes(map: FEMap, water_tile: int, params: GenerationParams):
	var num_lakes = int(1 + params.water_ratio * 3)
	
	for i in range(num_lakes):
		var center = Vector2i(randi() % map.width, randi() % map.height)
		var size = int(1 + randf() * 3)
		_place_blob_feature(map, center, size, water_tile)

## Get terrain tiles for a theme
static func _get_theme_terrain_tiles(tileset_data: FETilesetData, map_theme: MapTheme) -> Dictionary:
	var terrain_categories = {
		"plains": [],
		"forest": [],
		"mountain": [],
		"water": [],
		"fort": [],
		"wall": [],
		"floor": []
	}
	
	print("\n=== TERRAIN CATEGORIZATION DEBUG ===")
	print("Tileset ID: %s, Name: %s" % [tileset_data.id, tileset_data.name])
	print("Terrain tags array size: %d" % tileset_data.terrain_tags.size())
	
	# Analyze tileset to categorize tiles by terrain type
	var tiles_processed = 0
	var tiles_categorized = 0
	for tile_index in range(min(1024, tileset_data.terrain_tags.size())):
		tiles_processed += 1
		var terrain_id = tileset_data.terrain_tags[tile_index]
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		
		if not terrain_data:
			if tile_index < 10:  # Only show first few to avoid spam
				print("  Tile %d: terrain_id=%d -> NO TERRAIN DATA" % [tile_index, terrain_id])
			continue
		
		var terrain_name = terrain_data.name.to_lower()
		var categorized = false
		
		# Categorize based on terrain name
		if "plain" in terrain_name or "grass" in terrain_name or "road" in terrain_name:
			terrain_categories["plains"].append(tile_index)
			categorized = true
		elif "forest" in terrain_name or "tree" in terrain_name:
			terrain_categories["forest"].append(tile_index)
			categorized = true
		elif "mountain" in terrain_name or "hill" in terrain_name or "peak" in terrain_name:
			terrain_categories["mountain"].append(tile_index)
			categorized = true
		elif "water" in terrain_name or "sea" in terrain_name or "river" in terrain_name:
			terrain_categories["water"].append(tile_index)
			categorized = true
		elif "fort" in terrain_name or "castle" in terrain_name or "throne" in terrain_name:
			terrain_categories["fort"].append(tile_index)
			categorized = true
		elif "wall" in terrain_name or terrain_data.defense_bonus > 2:
			terrain_categories["wall"].append(tile_index)
			categorized = true
		else:
			terrain_categories["floor"].append(tile_index)
			categorized = true
		
		# Debug output for first few tiles
		if tile_index < 20:
			print("  Tile %d: terrain_id=%d, name='%s' -> %s" % [tile_index, terrain_id, terrain_name, "categorized" if categorized else "uncategorized"])
		
		if categorized:
			tiles_categorized += 1
	
	print("Processed %d tiles, categorized %d tiles" % [tiles_processed, tiles_categorized])
	
	# Ensure we have at least basic tiles
	if terrain_categories["plains"].is_empty():
		print("WARNING: No plains tiles found, using tile 0 as fallback")
		terrain_categories["plains"].append(0)  # Fallback to tile 0
	if terrain_categories["floor"].is_empty():
		print("WARNING: No floor tiles found, using plains as fallback")
		terrain_categories["floor"] = terrain_categories["plains"]
	
	# Print category summary
	print("\nTerrain categories:")
	for category in terrain_categories:
		var tiles = terrain_categories[category]
		print("  %s: %d tiles %s" % [category, tiles.size(), str(tiles.slice(0, 5)) if tiles.size() > 0 else "[]"])
	
	print("=== END TERRAIN CATEGORIZATION ===\n")
	
	return terrain_categories

## Convert noise value to terrain category
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

## Random terrain category based on theme ratios
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

## Get random tile for category (legacy method)
static func _get_random_tile_for_category(terrain_tiles: Dictionary, category: String) -> int:
	var tiles = terrain_tiles.get(category, [])
	if tiles.is_empty():
		print("WARNING: No tiles found for category '%s', falling back to plains" % category)
		tiles = terrain_tiles.get("plains", [0])
	
	if tiles.is_empty():
		print("CRITICAL: No tiles available at all, using tile 0")
		return 0
	
	var selected_tile = tiles[randi() % tiles.size()]
	# Only print for debugging specific cases
	if category == "water" or category == "mountain" or randi() % 100 == 0:  # 1% chance for general tiles
		print("    Selected tile %d from category '%s' (had %d options)" % [selected_tile, category, tiles.size()])
	
	return selected_tile

## Get smart tile using autotiling intelligence when available
## TODO: Replace with original's 8-method validation + tile_priorities system
static func _get_smart_tile_for_terrain(tileset_data: FETilesetData, terrain_id: int, neighbors: Array[int]) -> int:
	if tileset_data.has_autotiling_intelligence():
		return tileset_data.get_smart_tile(terrain_id, neighbors)
	else:
		# Fallback to basic tile selection
		return tileset_data.get_basic_tile_for_terrain(terrain_id)

## Get smart tile with position and noise-based variation
static func _get_smart_tile_with_position_variation(tileset_data: FETilesetData, terrain_id: int, neighbors: Array[int], x: int, y: int, variation_noise: float) -> int:
	if not tileset_data.has_autotiling_intelligence():
		return tileset_data.get_basic_tile_for_terrain(terrain_id)
	
	# Get all tiles for this terrain
	var terrain_tiles = tileset_data.get_tiles_with_terrain(terrain_id)
	if terrain_tiles.is_empty():
		return 0
	
	# Debug: Show available plains tiles on first call
	if terrain_id == 1 and not has_shown_plains_tiles:
		has_shown_plains_tiles = true
		print("\nAvailable Plains tiles in tileset %s:" % tileset_data.id)
		print("Total plains tiles: %d" % terrain_tiles.size())
		if terrain_tiles.size() <= 50:
			print("All plains tiles: %s" % str(terrain_tiles))
		else:
			print("First 50 plains tiles: %s" % str(terrain_tiles.slice(0, 50)))
	
	# Count same-terrain neighbors
	var same_terrain_count = 0
	for n in neighbors:
		if n == terrain_id:
			same_terrain_count += 1
	
	# For completely uniform areas, add spatial variation using authentic Fire Emblem tiles
	# TODO: Replace with original's Identical_Tiles + tile_priorities system
	if same_terrain_count == 8:  # All same terrain (not just plains)
		# Get authentic tiles from Fire Emblem patterns instead of all terrain tiles
		var authentic_tiles = tileset_data.get_authentic_tiles_for_terrain(terrain_id)
		
		if authentic_tiles.is_empty():
			# Fallback to autotiling if no authentic tiles available
			print("DEBUG: No authentic tiles for terrain %d, using autotiling fallback" % terrain_id)
			return tileset_data.get_smart_tile(terrain_id, neighbors)
		
		# Use position-based selection from authentic Fire Emblem tiles
		# TODO: Replace with priority-weighted selection like original tile_priorities
		var position_hash = hash(Vector2i(x, y))
		var noise_factor = int((variation_noise + 1.0) * 50)  # Convert noise to integer
		var combined_hash = position_hash + noise_factor
		
		var tile_count = min(5, authentic_tiles.size())  # Limit to 5 variations
		var tile_index = combined_hash % tile_count
		
		# DEBUG: Show tile selection for first few positions only
		if x < 2 and y < 2:
			print("DEBUG Uniform terrain %d at (%d,%d): authentic_tiles[%d] = %d (from %d total authentic tiles)" % [
				terrain_id, x, y, tile_index, authentic_tiles[tile_index], authentic_tiles.size()
			])
		
		return authentic_tiles[tile_index]
	
	# For edges and other cases, use standard autotiling
	var smart_tile = tileset_data.get_smart_tile(terrain_id, neighbors)
	return smart_tile

## Generate Perlin noise with autotiling intelligence
static func _generate_perlin_noise_with_intelligence(map: FEMap, tileset_data: FETilesetData, params: GenerationParams, noise: FastNoiseLite):
	print("\n🧠 USING AUTOTILING INTELLIGENCE for Perlin noise generation")
	
	# Step 1: Generate terrain layout (terrain IDs, not tile indices)
	var terrain_layout = []
	var terrain_counts = {}
	for y in range(map.height):
		terrain_layout.append([])
		for x in range(map.width):
			var noise_value = noise.get_noise_2d(x, y)
			var terrain_id = _noise_to_terrain_id(noise_value, params)
			terrain_layout[y].append(terrain_id)
			terrain_counts[terrain_id] = terrain_counts.get(terrain_id, 0) + 1
	
	print("Terrain layout generated. Terrain IDs used:")
	for terrain_id in terrain_counts:
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		var terrain_name = terrain_data.name if terrain_data else "Unknown"
		print("  Terrain %d (%s): %d tiles" % [terrain_id, terrain_name, terrain_counts[terrain_id]])
	
	# Step 2: Apply smart tile selection based on neighbor context
	# Create a secondary noise for tile variation within same terrain
	var tile_noise = FastNoiseLite.new()
	tile_noise.seed = noise.seed + 12345  # Different seed for variation
	tile_noise.frequency = 0.15  # Lower frequency for larger, smoother patches
	tile_noise.noise_type = FastNoiseLite.TYPE_PERLIN  # Ensure Perlin for smooth gradients
	
	for y in range(map.height):
		for x in range(map.width):
			var center_terrain = terrain_layout[y][x]
			var neighbors = _get_terrain_neighbors(terrain_layout, x, y, map.width, map.height)
			
			# Get noise value for this position
			var variation_noise = tile_noise.get_noise_2d(x, y)
			
			# Pass position and noise value for organic variation
			var smart_tile = _get_smart_tile_with_position_variation(tileset_data, center_terrain, neighbors, x, y, variation_noise)
			map.set_tile_at(x, y, smart_tile)
	
	print("✅ Smart tile placement complete!")

## Convert noise value to terrain ID instead of category
static func _noise_to_terrain_id(noise_value: float, params: GenerationParams) -> int:
	# Map noise values to terrain IDs based on the map theme
	# For now, use simplified mappings until we can verify actual terrain IDs
	
	match params.map_theme:
		MapTheme.PLAINS:
			# Create a more interesting plains map with multiple terrain types
			# The autotiling will handle transitions properly
			if noise_value < -0.7:
				return 16  # River/Water (from the debug output, 16 was River)
			elif noise_value < -0.5:
				return 14  # Sand/Beach - transition terrain
			elif noise_value < 0.5:
				return 1   # Plains - main terrain (most of the map)
			elif noise_value < 0.7:
				return 3   # Village or grass variant
			else:
				return 38  # Cliff for high areas
		
		MapTheme.FOREST:
			if noise_value < -0.3:
				return 1  # Plains
			elif noise_value < 0.3:
				return 1  # Plains
			else:
				return 1  # Plains (TODO: Find actual forest terrain ID)
		
		MapTheme.MIXED:
			# Original mixed logic - but commented until we verify terrain IDs
			if noise_value < -0.4:
				return 1  # Plains (was 38 - Water)
			elif noise_value < -0.2:
				return 1  # Plains
			elif noise_value <= 0.0:
				return 1  # Plains (was 2 - Road)
			elif noise_value < 0.2:
				return 1  # Plains
			elif noise_value < 0.4:
				return 1  # Plains (was 18 - Peak/Forest?)
			else:
				return 1  # Plains (was 16 - Mountain)
		
		_:
			return 1  # Default to plains

## Get terrain neighbors for a position
static func _get_terrain_neighbors(terrain_layout: Array, x: int, y: int, width: int, height: int) -> Array[int]:
	var neighbors: Array[int] = []
	
	# Get 8 neighbors in standard order (N, NE, E, SE, S, SW, W, NW)
	var directions = [
		Vector2i(0, -1),  # N
		Vector2i(1, -1),  # NE
		Vector2i(1, 0),   # E
		Vector2i(1, 1),   # SE
		Vector2i(0, 1),   # S
		Vector2i(-1, 1),  # SW
		Vector2i(-1, 0),  # W
		Vector2i(-1, -1)  # NW
	]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		
		if nx >= 0 and nx < width and ny >= 0 and ny < height:
			neighbors.append(terrain_layout[ny][nx])
		else:
			# Use edge terrain for out-of-bounds
			neighbors.append(1)  # Plains as default edge terrain
	
	return neighbors

## Generate strategic placement with autotiling intelligence
static func _generate_strategic_placement_with_intelligence(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	print("\n🧠 USING AUTOTILING INTELLIGENCE for strategic placement")
	
	# Step 1: Create terrain layout with strategic features
	var terrain_layout = []
	
	# Initialize with plains
	for y in range(map.height):
		terrain_layout.append([])
		for x in range(map.width):
			terrain_layout[y].append(1)  # Plains terrain ID
	
	# Add strategic terrain features to the layout
	_add_strategic_terrain_features(terrain_layout, map.width, map.height, params)
	
	# Step 2: Apply smart tile selection
	for y in range(map.height):
		for x in range(map.width):
			var center_terrain = terrain_layout[y][x]
			var neighbors = _get_terrain_neighbors(terrain_layout, x, y, map.width, map.height)
			var smart_tile = _get_smart_tile_for_terrain(tileset_data, center_terrain, neighbors)
			map.set_tile_at(x, y, smart_tile)
	
	print("✅ Strategic placement with intelligence complete!")

## Add strategic terrain features to terrain layout
static func _add_strategic_terrain_features(terrain_layout: Array, width: int, height: int, params: GenerationParams):
	# Add mountain ranges
	_add_terrain_mountain_ranges(terrain_layout, width, height, params)
	
	# Add forest clusters
	_add_terrain_forests(terrain_layout, width, height, params)
	
	# Add water features
	_add_terrain_water(terrain_layout, width, height, params)
	
	# Add defensive positions (forts, villages)
	_add_terrain_defensive_positions(terrain_layout, width, height, params)

## Add mountain ranges to terrain layout
static func _add_terrain_mountain_ranges(terrain_layout: Array, width: int, height: int, params: GenerationParams):
	var num_ranges = int(1 + params.complexity * 2)
	
	for i in range(num_ranges):
		var start_x = randi() % width
		var start_y = randi() % height
		var length = int(3 + randf() * 8)
		
		var direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
		
		for j in range(length):
			var x = int(start_x + direction.x * j)
			var y = int(start_y + direction.y * j)
			
			if x >= 0 and x < width and y >= 0 and y < height:
				terrain_layout[y][x] = 16  # Mountain terrain ID

## Add forest clusters to terrain layout
static func _add_terrain_forests(terrain_layout: Array, width: int, height: int, params: GenerationParams):
	var num_forests = int(2 + params.complexity * 3)
	
	for i in range(num_forests):
		var center_x = randi() % width
		var center_y = randi() % height
		var radius = int(2 + randf() * 4)
		
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x = center_x + dx
				var y = center_y + dy
				
				if x >= 0 and x < width and y >= 0 and y < height:
					var distance = sqrt(dx * dx + dy * dy)
					if distance <= radius and randf() < 0.7:
						terrain_layout[y][x] = 18  # Forest terrain ID

## Add water features to terrain layout
static func _add_terrain_water(terrain_layout: Array, width: int, height: int, params: GenerationParams):
	if params.map_theme == MapTheme.MIXED:
		# Add a river or lake
		if randf() < 0.6:  # River
			var start_x = 0 if randf() < 0.5 else width - 1
			var end_x = width - 1 if start_x == 0 else 0
			var y = int(height * 0.3 + randf() * height * 0.4)
			
			var steps = width
			for i in range(steps):
				var x = int(lerp(start_x, end_x, float(i) / steps))
				y += int(randf() * 3 - 1)  # Random vertical movement
				y = clamp(y, 0, height - 1)
				
				terrain_layout[y][x] = 38  # Water terrain ID
		else:  # Lake
			var center_x = int(width * 0.3 + randf() * width * 0.4)
			var center_y = int(height * 0.3 + randf() * height * 0.4)
			var radius = int(2 + randf() * 3)
			
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var x = center_x + dx
					var y = center_y + dy
					
					if x >= 0 and x < width and y >= 0 and y < height:
						var distance = sqrt(dx * dx + dy * dy)
						if distance <= radius:
							terrain_layout[y][x] = 38  # Water terrain ID

## Add defensive positions to terrain layout
static func _add_terrain_defensive_positions(terrain_layout: Array, width: int, height: int, params: GenerationParams):
	# Add a few strategic positions
	var positions = int(1 + params.complexity)
	
	for i in range(positions):
		var x = int(width * 0.2 + randf() * width * 0.6)
		var y = int(height * 0.2 + randf() * height * 0.6)
		
		if randf() < 0.5:
			terrain_layout[y][x] = 3  # Village terrain ID  
		else:
			terrain_layout[y][x] = 21  # Fort terrain ID

## Ensure map connectivity
static func _ensure_connectivity(map: FEMap, tileset_data: FETilesetData):
	# Simple approach: replace impassable islands with passable terrain
	var passable_tile = _find_passable_tile(tileset_data)
	if passable_tile < 0:
		return
	
	# This is a simplified connectivity check
	# A full implementation would use proper pathfinding
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			if _is_tile_impassable(map.get_tile_at(x, y), tileset_data):
				# Check if surrounded by passable terrain
				var surrounded = true
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var neighbor_tile = map.get_tile_at(x + dx, y + dy)
						if _is_tile_impassable(neighbor_tile, tileset_data):
							surrounded = false
							break
					if not surrounded:
						break
				
				if surrounded:
					map.set_tile_at(x, y, passable_tile)

## Find a passable tile in the tileset
static func _find_passable_tile(tileset_data: FETilesetData) -> int:
	for tile_index in range(min(100, tileset_data.terrain_tags.size())):
		var terrain_id = tileset_data.terrain_tags[tile_index]
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		
		if terrain_data and terrain_data.is_passable(0, 0):
			return tile_index
	
	return -1

## Check if tile is impassable
static func _is_tile_impassable(tile_index: int, tileset_data: FETilesetData) -> bool:
	if tile_index < 0 or tile_index >= tileset_data.terrain_tags.size():
		return true
	
	var terrain_id = tileset_data.terrain_tags[tile_index]
	var terrain_data = AssetManager.get_terrain_data(terrain_id)
	
	return not terrain_data or not terrain_data.is_passable(0, 0)

## Add strategic features like chests, spawn points, etc.
static func _add_strategic_features(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	# This would add special features like:
	# - Chest tiles
	# - Village tiles  
	# - Gate/door tiles
	# - Throne tiles
	# For now, just add a few defensive positions
	pass

## Add borders to the map
static func _add_borders(map: FEMap, tileset_data: FETilesetData, params: GenerationParams):
	if params.border_type == "none":
		return
	
	var border_tile = _find_border_tile(tileset_data, params.border_type)
	
	match params.border_type:
		"walls":
			_add_wall_borders(map, border_tile)
		"water":
			_add_water_borders(map, border_tile)
		"natural":
			_add_natural_borders(map, tileset_data)

## Find appropriate border tile
static func _find_border_tile(tileset_data: FETilesetData, border_type: String) -> int:
	for tile_index in range(min(100, tileset_data.terrain_tags.size())):
		var terrain_id = tileset_data.terrain_tags[tile_index]
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		
		if not terrain_data:
			continue
		
		var terrain_name = terrain_data.name.to_lower()
		
		match border_type:
			"walls":
				if "wall" in terrain_name or not terrain_data.is_passable(0, 0):
					return tile_index
			"water":
				if "water" in terrain_name or "sea" in terrain_name:
					return tile_index
	
	return 0  # Fallback

## Add wall borders
static func _add_wall_borders(map: FEMap, wall_tile: int):
	# Top and bottom
	for x in range(map.width):
		map.set_tile_at(x, 0, wall_tile)
		map.set_tile_at(x, map.height - 1, wall_tile)
	
	# Left and right
	for y in range(map.height):
		map.set_tile_at(0, y, wall_tile)
		map.set_tile_at(map.width - 1, y, wall_tile)

## Add water borders
static func _add_water_borders(map: FEMap, water_tile: int):
	# Similar to walls but might leave gaps for bridges
	_add_wall_borders(map, water_tile)
	
	# Add some bridge gaps
	var num_gaps = 2 + randi() % 3
	for i in range(num_gaps):
		var side = randi() % 4
		match side:
			0:  # Top
				var x = 1 + randi() % (map.width - 2)
				map.set_tile_at(x, 0, _find_passable_tile(AssetManager.get_tileset_data(map.tileset_id)))
			1:  # Right
				var y = 1 + randi() % (map.height - 2)
				map.set_tile_at(map.width - 1, y, _find_passable_tile(AssetManager.get_tileset_data(map.tileset_id)))

## Add natural borders (varied terrain)
static func _add_natural_borders(map: FEMap, tileset_data: FETilesetData):
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, MapTheme.MIXED)
	
	# Top and bottom - mix of mountain and forest
	for x in range(map.width):
		var tile_category = "mountain" if randf() < 0.6 else "forest"
		var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
		map.set_tile_at(x, 0, tile_index)
		map.set_tile_at(x, map.height - 1, tile_index)
	
	# Left and right - similar variety
	for y in range(1, map.height - 1):
		var tile_category = "mountain" if randf() < 0.6 else "forest"
		var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
		map.set_tile_at(0, y, tile_index)
		map.set_tile_at(map.width - 1, y, tile_index)

## Get algorithm name for display
static func _get_algorithm_name(algorithm: Algorithm) -> String:
	match algorithm:
		Algorithm.RANDOM:
			return "Random"
		Algorithm.PERLIN_NOISE:
			return "Perlin Noise"
		Algorithm.CELLULAR_AUTOMATA:
			return "Cellular Automata"
		Algorithm.TEMPLATE_BASED:
			return "Template Based"
		Algorithm.STRATEGIC_PLACEMENT:
			return "Strategic Placement"
		_:
			return "Unknown"

## Get theme name for display
static func _get_theme_name(map_theme: MapTheme) -> String:
	match map_theme:
		MapTheme.PLAINS:
			return "Plains"
		MapTheme.FOREST:
			return "Forest"
		MapTheme.MOUNTAIN:
			return "Mountain"
		MapTheme.DESERT:
			return "Desert"
		MapTheme.CASTLE:
			return "Castle"
		MapTheme.VILLAGE:
			return "Village"
		MapTheme.MIXED:
			return "Mixed"
		_:
			return "Unknown"

## Debug print tile grid for small maps
static func _debug_print_tile_grid(map: FEMap, params: GenerationParams):
	print("\n=== TILE GRID DEBUG ===")
	print("Tileset: %s" % params.tileset_id)
	print("Size: %dx%d" % [map.width, map.height])
	print("Algorithm: %s" % _get_algorithm_name(params.algorithm))
	print("Theme: %s" % _get_theme_name(params.map_theme))
	
	# Print the grid
	print("\nTile Index Grid:")
	for y in range(map.height):
		var row_str = ""
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			row_str += "%4d " % tile_index
		print(row_str)
	
	# Print unique tiles and their counts
	var tile_counts = {}
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			tile_counts[tile_index] = tile_counts.get(tile_index, 0) + 1
	
	print("\nUnique tiles used: %d" % tile_counts.size())
	print("Tile distribution:")
	for tile_index in tile_counts:
		var terrain_id = -1
		var tileset_data = AssetManager.get_tileset_data(params.tileset_id)
		if tileset_data and tile_index < tileset_data.terrain_tags.size():
			terrain_id = tileset_data.terrain_tags[tile_index]
		var terrain_name = "Unknown"
		if terrain_id >= 0:
			var terrain_data = AssetManager.get_terrain_data(terrain_id)
			if terrain_data:
				terrain_name = terrain_data.name
		print("  Tile %4d (terrain %3d: %s): %d times" % [tile_index, terrain_id, terrain_name, tile_counts[tile_index]])
	
	print("=== END TILE GRID DEBUG ===\n")

## Create quick preset parameters
static func create_preset(preset_name: String, tileset_id: String) -> GenerationParams:
	var params = GenerationParams.new()
	params.tileset_id = tileset_id
	
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
