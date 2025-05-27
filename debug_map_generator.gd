## Debug MapGenerator Step by Step
##
## Test MapGenerator to see why it's generating all 0s
extends Node

func _ready():
	print("=== MAP GENERATOR DEBUG ===")
	
	# Initialize AssetManager
	var fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	AssetManager.initialize(fe_data_path)
	
	var tileset_ids = AssetManager.get_tileset_ids()
	var test_tileset_id = tileset_ids[0]  # "01000203"
	
	print("Using tileset: %s" % test_tileset_id)
	
	# Create simple test parameters
	var params = MapGenerator.GenerationParams.new()
	params.width = 5
	params.height = 5
	params.tileset_id = test_tileset_id
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.PLAINS
	params.seed_value = 12345
	
	print("Test parameters:")
	print("- Size: %dx%d" % [params.width, params.height])
	print("- Algorithm: PERLIN_NOISE")
	print("- Theme: PLAINS")
	
	# Test map creation and initialization
	print("\n=== TESTING MAP CREATION ===")
	var map = FEMap.new()
	map.initialize(params.width, params.height, 99)  # Fill with 99 to see if it changes
	map.tileset_id = params.tileset_id
	
	print("Created map filled with tile 99:")
	_print_map_grid(map)
	
	# Test setting individual tiles
	print("\n=== TESTING TILE SETTING ===")
	print("Setting tile at (1,1) to 42...")
	var success = map.set_tile_at(1, 1, 42)
	print("set_tile_at() returned: %s" % success)
	print("Tile at (1,1) is now: %d" % map.get_tile_at(1, 1))
	
	_print_map_grid(map)
	
	# Test terrain categorization manually
	print("\n=== TESTING TERRAIN CATEGORIZATION ===")
	var tileset_data = AssetManager.get_tileset_data(test_tileset_id)
	if tileset_data:
		print("Tileset found: %s" % tileset_data.name)
		var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
		
		print("Terrain categories:")
		for category in terrain_tiles:
			var tiles = terrain_tiles[category]
			print("  %s: %s" % [category, str(tiles.slice(0, 3))])  # Show first 3 tiles
	
	# Test the actual generation with debug
	print("\n=== TESTING ACTUAL GENERATION ===")
	_test_perlin_generation_manually(map, tileset_data, params)
	
	print("\nFinal map state:")
	_print_map_grid(map)

func _print_map_grid(map: FEMap):
	print("Map grid (%dx%d):" % [map.width, map.height])
	for y in range(map.height):
		var row = []
		for x in range(map.width):
			row.append(str(map.get_tile_at(x, y)))
		print("  " + " ".join(row))

func _test_perlin_generation_manually(map: FEMap, tileset_data: FETilesetData, params: MapGenerator.GenerationParams):
	print("Testing Perlin noise generation manually...")
	
	var noise = FastNoiseLite.new()
	noise.seed = 12345
	noise.frequency = 0.1 * (1.0 + params.complexity)
	
	print("Noise setup: seed=%d, frequency=%f" % [noise.seed, noise.frequency])
	
	var terrain_tiles = _get_theme_terrain_tiles(tileset_data, params.map_theme)
	
	# Generate a few test tiles
	for y in range(min(3, map.height)):
		for x in range(min(3, map.width)):
			var noise_value = noise.get_noise_2d(x, y)
			var tile_category = _noise_to_terrain_category(noise_value, params)
			var tile_index = _get_random_tile_for_category(terrain_tiles, tile_category)
			
			print("Position (%d,%d): noise=%.3f -> category='%s' -> tile=%d" % [x, y, noise_value, tile_category, tile_index])
			
			# Try to set the tile
			var old_tile = map.get_tile_at(x, y)
			var success = map.set_tile_at(x, y, tile_index)
			var new_tile = map.get_tile_at(x, y)
			
			print("  set_tile_at(%d, %d, %d): success=%s, old=%d, new=%d" % [x, y, tile_index, success, old_tile, new_tile])
			
			if not success or new_tile != tile_index:
				print("  *** TILE SETTING FAILED! ***")

# Copy these functions from MapGenerator to test locally
func _get_theme_terrain_tiles(tileset_data: FETilesetData, map_theme: MapGenerator.MapTheme) -> Dictionary:
	var terrain_categories = {
		"plains": [],
		"forest": [],
		"mountain": [],
		"water": [],
		"fort": [],
		"wall": [],
		"floor": []
	}
	
	print("Analyzing tileset for terrain categories...")
	
	# Analyze tileset to categorize tiles by terrain type
	var tiles_categorized = 0
	for tile_index in range(min(100, tileset_data.terrain_tags.size())):  # Test first 100 tiles
		var terrain_id = tileset_data.terrain_tags[tile_index]
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		
		if not terrain_data:
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
		
		if categorized:
			tiles_categorized += 1
	
	print("Categorized %d tiles" % tiles_categorized)
	
	# Ensure we have at least basic tiles
	if terrain_categories["plains"].is_empty():
		print("WARNING: No plains tiles found, using tile 1 as fallback")
		terrain_categories["plains"].append(1)  # Fallback to tile 1
	if terrain_categories["floor"].is_empty():
		terrain_categories["floor"] = terrain_categories["plains"]
	
	return terrain_categories

func _noise_to_terrain_category(noise_value: float, params: MapGenerator.GenerationParams) -> String:
	# Normalize noise from [-1, 1] to [0, 1]
	var normalized = (noise_value + 1.0) / 2.0
	
	if normalized < 0.2:
		return "water"
	elif normalized < 0.4:
		return "forest"
	elif normalized < 0.9:
		return "plains"
	else:
		return "mountain"

func _get_random_tile_for_category(terrain_tiles: Dictionary, category: String) -> int:
	var tiles = terrain_tiles.get(category, [])
	if tiles.is_empty():
		print("WARNING: No tiles found for category '%s', falling back to plains" % category)
		tiles = terrain_tiles.get("plains", [1])  # Fallback to plains or tile 1
	
	if tiles.is_empty():
		print("CRITICAL: No tiles available at all, using tile 1")
		return 1
	
	var selected_tile = tiles[randi() % tiles.size()]
	print("    Selected tile %d from category '%s' (had %d options)" % [selected_tile, category, tiles.size()])
	
	return selected_tile
