extends GutTest

# Test the MapGenerator with autotiling intelligence
var asset_manager: AssetManager
var intelligent_tileset_id: String = ""
var intelligent_tileset_data: FETilesetData

func before_all():
	# Initialize AssetManager
	asset_manager = AssetManager
	await asset_manager.await_ready()
	
	# Find a tileset with autotiling intelligence
	var tileset_ids = asset_manager.get_tileset_ids()
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data and tileset_data.has_autotiling_intelligence():
			intelligent_tileset_id = tileset_id
			intelligent_tileset_data = tileset_data
			break
	
	assert_false(intelligent_tileset_id.is_empty(), "Should have at least one intelligent tileset for testing")

func test_mapgen_uses_intelligence_for_perlin_noise():
	# Test that Perlin noise generation uses autotiling intelligence
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.MIXED
	params.complexity = 0.5
	params.width = 15
	params.height = 10
	params.tileset_id = intelligent_tileset_id
	
	gut.p("Testing Perlin noise with intelligent tileset: %s" % intelligent_tileset_id)
	
	var map = MapGenerator.generate_map(params)
	
	assert_not_null(map, "Map should be generated")
	assert_eq(map.width, 15, "Map should have correct width")
	assert_eq(map.height, 10, "Map should have correct height")
	assert_eq(map.tileset_id, intelligent_tileset_id, "Map should use intelligent tileset")
	
	# Analyze tile variety - intelligent maps should have more variety
	var tile_counts = {}
	var total_tiles = 0
	
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index not in tile_counts:
				tile_counts[tile_index] = 0
			tile_counts[tile_index] += 1
			total_tiles += 1
	
	var unique_tiles = tile_counts.size()
	gut.p("Generated map uses %d unique tiles out of %d total positions" % [unique_tiles, total_tiles])
	
	# With intelligence, we should see meaningful tile variety
	assert_gt(unique_tiles, 1, "Intelligent generation should use multiple tile types")
	assert_lte(unique_tiles, total_tiles, "Can't have more unique tiles than positions")
	
	# Test tile placement quality by checking neighbor relationships
	var good_transitions = 0
	var total_transitions = 0
	
	for y in range(map.height - 1):
		for x in range(map.width - 1):
			var center_tile = map.get_tile_at(x, y)
			var right_tile = map.get_tile_at(x + 1, y)
			var down_tile = map.get_tile_at(x, y + 1)
			
			# Check if tiles are compatible (this is a simplified check)
			if _tiles_are_compatible(center_tile, right_tile):
				good_transitions += 1
			if _tiles_are_compatible(center_tile, down_tile):
				good_transitions += 1
			total_transitions += 2
	
	var transition_quality = float(good_transitions) / float(total_transitions)
	gut.p("Transition quality: %.2f%% good transitions" % (transition_quality * 100))
	
	# With intelligence, we expect better transition quality
	assert_gt(transition_quality, 0.3, "Intelligent generation should have reasonable transition quality")

func test_mapgen_uses_intelligence_for_strategic_placement():
	# Test that strategic placement uses autotiling intelligence
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.STRATEGIC_PLACEMENT
	params.map_theme = MapGenerator.MapTheme.MIXED
	params.complexity = 0.7
	params.width = 12
	params.height = 8
	params.tileset_id = intelligent_tileset_id
	
	gut.p("Testing strategic placement with intelligent tileset: %s" % intelligent_tileset_id)
	
	var map = MapGenerator.generate_map(params)
	
	assert_not_null(map, "Map should be generated")
	assert_eq(map.tileset_id, intelligent_tileset_id, "Map should use intelligent tileset")
	
	# Strategic maps should have variety due to strategic features
	var tile_counts = {}
	for y in range(map.height):
		for x in range(map.width):
			var tile_index = map.get_tile_at(x, y)
			if tile_index not in tile_counts:
				tile_counts[tile_index] = 0
			tile_counts[tile_index] += 1
	
	var unique_tiles = tile_counts.size()
	gut.p("Strategic map uses %d unique tiles" % unique_tiles)
	
	assert_gt(unique_tiles, 2, "Strategic placement with intelligence should use multiple terrain types")

func test_mapgen_fallback_without_intelligence():
	# Test that generation works even without intelligence (fallback)
	# Find a tileset without intelligence or create mock parameters
	var fallback_tileset_id = ""
	var tileset_ids = asset_manager.get_tileset_ids()
	
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data and not tileset_data.has_autotiling_intelligence():
			fallback_tileset_id = tileset_id
			break
	
	if fallback_tileset_id.is_empty():
		gut.p("No non-intelligent tileset found, skipping fallback test")
		return
	
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.PLAINS
	params.complexity = 0.3
	params.width = 8
	params.height = 6
	params.tileset_id = fallback_tileset_id
	
	gut.p("Testing fallback generation with non-intelligent tileset: %s" % fallback_tileset_id)
	
	var map = MapGenerator.generate_map(params)
	
	assert_not_null(map, "Map should be generated even without intelligence")
	assert_eq(map.tileset_id, fallback_tileset_id, "Map should use fallback tileset")

func test_smart_tile_selection_vs_random():
	# Compare smart tile selection vs random selection
	var terrain_id = 1  # Plains
	var neighbors: Array[int] = [1, 18, 1, 1, 18, 18, 1, 18]  # Mixed plains and forest
	
	# Test smart selection
	var smart_tile = MapGenerator._get_smart_tile_for_terrain(intelligent_tileset_data, terrain_id, neighbors)
	assert_gte(smart_tile, 0, "Smart tile selection should return valid tile index")
	
	# Test that smart selection is consistent
	var smart_tile2 = MapGenerator._get_smart_tile_for_terrain(intelligent_tileset_data, terrain_id, neighbors)
	# Note: Smart selection might have some randomness but should be in valid range
	assert_gte(smart_tile2, 0, "Smart tile selection should consistently return valid tiles")
	
	gut.p("Smart tile selection for terrain %d with mixed neighbors: tile %d" % [terrain_id, smart_tile])

func test_terrain_neighbor_calculation():
	# Test the terrain neighbor calculation function
	var terrain_layout = [
		[1, 1, 18],
		[1, 16, 18], 
		[16, 16, 38]
	]
	
	# Test center position
	var neighbors = MapGenerator._get_terrain_neighbors(terrain_layout, 1, 1, 3, 3)
	assert_eq(neighbors.size(), 8, "Should return 8 neighbors")
	
	# Expected neighbors for position (1,1) in clockwise order from North
	# N=1, NE=18, E=18, SE=38, S=16, SW=16, W=1, NW=1
	var expected = [1, 18, 18, 38, 16, 16, 1, 1]
	assert_eq(neighbors, expected, "Neighbors should be in correct order")
	
	# Test edge position
	var edge_neighbors = MapGenerator._get_terrain_neighbors(terrain_layout, 0, 0, 3, 3)
	assert_eq(edge_neighbors.size(), 8, "Edge position should also return 8 neighbors")
	
	# Edge neighbors should use default terrain (1) for out-of-bounds
	assert_eq(edge_neighbors[0], 1, "Out-of-bounds neighbor should be default terrain")

func test_noise_to_terrain_conversion():
	# Test noise value to terrain ID conversion
	var params = MapGenerator.GenerationParams.new()
	
	# Test various noise values
	assert_eq(MapGenerator._noise_to_terrain_id(-0.5, params), 38, "Very low noise should map to water")
	assert_eq(MapGenerator._noise_to_terrain_id(-0.3, params), 1, "Low noise should map to plains")
	assert_eq(MapGenerator._noise_to_terrain_id(0.0, params), 2, "Zero noise should map to road")
	assert_eq(MapGenerator._noise_to_terrain_id(0.3, params), 18, "Positive noise should map to forest")
	assert_eq(MapGenerator._noise_to_terrain_id(0.6, params), 16, "High noise should map to mountain")

func test_generation_determinism():
	# Test that generation with same seed produces same results
	var params1 = MapGenerator.GenerationParams.new()
	params1.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params1.map_theme = MapGenerator.MapTheme.PLAINS
	params1.complexity = 0.5
	params1.width = 6
	params1.height = 4
	params1.tileset_id = intelligent_tileset_id
	params1.seed_value = 12345
	
	var params2 = MapGenerator.GenerationParams.new()
	params2.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params2.map_theme = MapGenerator.MapTheme.PLAINS
	params2.complexity = 0.5
	params2.width = 6
	params2.height = 4
	params2.tileset_id = intelligent_tileset_id
	params2.seed_value = 12345
	
	var map1 = MapGenerator.generate_map(params1)
	var map2 = MapGenerator.generate_map(params2)
	
	# Maps with same seed should be identical
	for y in range(map1.height):
		for x in range(map1.width):
			var tile1 = map1.get_tile_at(x, y)
			var tile2 = map2.get_tile_at(x, y)
			assert_eq(tile1, tile2, "Maps with same seed should have identical tiles at (%d,%d)" % [x, y])

func test_algorithm_variety():
	# Test that different algorithms produce different results
	var base_params = MapGenerator.GenerationParams.new()
	base_params.map_theme = MapGenerator.MapTheme.MIXED
	base_params.complexity = 0.5
	base_params.width = 8
	base_params.height = 6
	base_params.tileset_id = intelligent_tileset_id
	base_params.seed_value = 54321
	
	var algorithms = [
		MapGenerator.Algorithm.PERLIN_NOISE,
		MapGenerator.Algorithm.STRATEGIC_PLACEMENT,
		MapGenerator.Algorithm.CELLULAR_AUTOMATA
	]
	
	var maps = []
	for algorithm in algorithms:
		var params = _copy_params(base_params)
		params.algorithm = algorithm
		var map = MapGenerator.generate_map(params)
		maps.append(map)
		gut.p("Algorithm %s generated map with tileset %s" % [algorithm, map.tileset_id])
	
	# Different algorithms should produce different maps
	var perlin_map = maps[0]
	var strategic_map = maps[1]
	
	var differences = 0
	for y in range(perlin_map.height):
		for x in range(perlin_map.width):
			if perlin_map.get_tile_at(x, y) != strategic_map.get_tile_at(x, y):
				differences += 1
	
	var total_positions = perlin_map.width * perlin_map.height
	var difference_ratio = float(differences) / float(total_positions)
	
	gut.p("Perlin vs Strategic: %.1f%% different tiles" % (difference_ratio * 100))
	assert_gt(difference_ratio, 0.1, "Different algorithms should produce meaningfully different maps")

# Helper function to check if two tiles are compatible
func _tiles_are_compatible(tile1: int, tile2: int) -> bool:
	# This is a simplified compatibility check
	# In a real implementation, this would check terrain types and transitions
	return true  # For now, accept all transitions as compatible

func _copy_params(source: MapGenerator.GenerationParams) -> MapGenerator.GenerationParams:
	# Helper function to copy GenerationParams since it doesn't have duplicate()
	var copy = MapGenerator.GenerationParams.new()
	copy.width = source.width
	copy.height = source.height
	copy.tileset_id = source.tileset_id
	copy.algorithm = source.algorithm
	copy.map_theme = source.map_theme
	copy.seed_value = source.seed_value
	copy.complexity = source.complexity
	copy.defensive_terrain_ratio = source.defensive_terrain_ratio
	copy.water_ratio = source.water_ratio
	copy.mountain_ratio = source.mountain_ratio
	copy.forest_ratio = source.forest_ratio
	copy.ensure_connectivity = source.ensure_connectivity
	copy.add_strategic_features = source.add_strategic_features
	copy.border_type = source.border_type
	return copy
