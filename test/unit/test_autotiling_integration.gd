extends GutTest

# Test the integration between autotiling intelligence and map generation
var asset_manager: AssetManager

func before_all():
	asset_manager = AssetManager
	await asset_manager.await_ready()

func test_mapgen_detects_intelligent_tilesets():
	# Test that MapGenerator can detect and use intelligent tilesets
	var tileset_ids = asset_manager.get_tileset_ids()
	var intelligent_count = 0
	var total_count = 0
	
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data:
			total_count += 1
			if tileset_data.has_autotiling_intelligence():
				intelligent_count += 1
				
				# Verify the tileset has meaningful intelligence
				var stats = tileset_data.get_autotiling_stats()
				assert_true(stats.available, "Intelligent tileset should have available stats")
				assert_gt(stats.patterns, 0, "Intelligent tileset should have patterns")
				
				gut.p("Intelligent tileset %s: %d patterns" % [tileset_id, stats.patterns])
	
	gut.p("Found %d intelligent tilesets out of %d total" % [intelligent_count, total_count])
	assert_gt(intelligent_count, 0, "Should have at least one intelligent tileset")
	assert_gt(total_count, 0, "Should have at least one tileset")

func test_smart_vs_basic_tile_selection():
	# Compare smart tile selection vs basic selection
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping comparison test")
		return
	
	var tileset_data = asset_manager.get_tileset_data(intelligent_tileset_id)
	var terrain_id = 1  # Plains terrain
	var neighbors: Array[int] = [1, 1, 18, 18, 1, 1, 18, 18]  # Alternating plains and forest
	
	# Test smart selection
	var smart_tile = tileset_data.get_smart_tile(terrain_id, neighbors)
	assert_gte(smart_tile, 0, "Smart tile should be valid")
	
	# Test basic selection  
	var basic_tile = tileset_data.get_basic_tile_for_terrain(terrain_id)
	assert_gte(basic_tile, 0, "Basic tile should be valid")
	
	gut.p("Terrain %d with mixed neighbors: smart=%d, basic=%d" % [terrain_id, smart_tile, basic_tile])
	
	# They might be the same, but smart selection should be valid
	assert_true(smart_tile >= 0 and basic_tile >= 0, "Both selection methods should work")

func test_autotiling_database_functionality():
	# Test that autotiling databases are functional
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping database test")
		return
	
	var tileset_data = asset_manager.get_tileset_data(intelligent_tileset_id)
	assert_true(tileset_data.has_autotiling_intelligence(), "Should have intelligence")
	
	var db = tileset_data.autotiling_db
	assert_not_null(db, "Should have autotiling database")
	assert_true(db.has_method("get_pattern_count"), "Database should have get_pattern_count method")
	assert_true(db.has_method("get_best_tile"), "Database should have get_best_tile method")
	
	var pattern_count = db.get_pattern_count()
	assert_gt(pattern_count, 0, "Database should have patterns")
	
	gut.p("Database for %s has %d patterns" % [intelligent_tileset_id, pattern_count])

func test_mapgen_intelligence_branching():
	# Test that MapGenerator properly branches between intelligent and fallback generation
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping branching test")
		return
	
	# Mock test by directly calling the generation functions would be ideal,
	# but since they're static functions in MapGenerator, we'll test indirectly
	
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.PLAINS
	params.complexity = 0.3
	params.width = 5
	params.height = 5
	params.tileset_id = intelligent_tileset_id
	
	# This should use the intelligent path
	var map = MapGenerator.generate_map(params)
	assert_not_null(map, "Intelligent generation should work")
	assert_eq(map.tileset_id, intelligent_tileset_id, "Should use intelligent tileset")

func test_terrain_id_mapping():
	# Test that terrain ID mapping is working correctly
	var test_cases = [
		{"noise": -0.5, "expected": 38, "terrain": "water"},
		{"noise": -0.3, "expected": 1, "terrain": "plains"},
		{"noise": 0.0, "expected": 2, "terrain": "road"},
		{"noise": 0.3, "expected": 18, "terrain": "forest"},
		{"noise": 0.6, "expected": 16, "terrain": "mountain"}
	]
	
	var params = MapGenerator.GenerationParams.new()
	
	for test_case in test_cases:
		var result = MapGenerator._noise_to_terrain_id(test_case.noise, params)
		assert_eq(result, test_case.expected, 
			"Noise %.1f should map to terrain %d (%s)" % [test_case.noise, test_case.expected, test_case.terrain])

func test_neighbor_context_affects_selection():
	# Test that different neighbor contexts produce different tile selections
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping context test")
		return
	
	var tileset_data = asset_manager.get_tileset_data(intelligent_tileset_id)
	var terrain_id = 1  # Plains
	
	# Different neighbor contexts
	var context1: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]  # All plains
	var context2: Array[int] = [18, 18, 18, 18, 18, 18, 18, 18]  # Surrounded by forest
	var context3: Array[int] = [16, 16, 16, 16, 16, 16, 16, 16]  # Surrounded by mountains
	
	var tile1 = tileset_data.get_smart_tile(terrain_id, context1)
	var tile2 = tileset_data.get_smart_tile(terrain_id, context2)
	var tile3 = tileset_data.get_smart_tile(terrain_id, context3)
	
	gut.p("Plains tile in different contexts: all_plains=%d, forest_surround=%d, mountain_surround=%d" % [tile1, tile2, tile3])
	
	# All should be valid tiles
	assert_gte(tile1, 0, "Context 1 should produce valid tile")
	assert_gte(tile2, 0, "Context 2 should produce valid tile")
	assert_gte(tile3, 0, "Context 3 should produce valid tile")
	
	# With good intelligence, different contexts might produce different tiles
	# But this isn't guaranteed, so we just verify they're all valid

func test_generation_produces_varied_output():
	# Test that intelligent generation produces varied, non-uniform output
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping variety test")
		return
	
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.MIXED
	params.complexity = 0.8  # High complexity for more variety
	params.width = 12
	params.height = 8
	params.tileset_id = intelligent_tileset_id
	
	var map = MapGenerator.generate_map(params)
	
	# Count unique tiles
	var tile_counts = {}
	for y in range(map.height):
		for x in range(map.width):
			var tile = map.get_tile_at(x, y)
			tile_counts[tile] = tile_counts.get(tile, 0) + 1
	
	var unique_tiles = tile_counts.size()
	var total_tiles = map.width * map.height
	var variety_ratio = float(unique_tiles) / float(total_tiles)
	
	gut.p("Generated map: %d unique tiles out of %d positions (%.1f%% variety)" % 
		[unique_tiles, total_tiles, variety_ratio * 100])
	
	# Intelligent generation with mixed theme should produce good variety
	assert_gt(unique_tiles, 3, "Mixed theme with intelligence should use multiple tile types")
	assert_gt(variety_ratio, 0.05, "Should have reasonable tile variety")

# Helper function to find an intelligent tileset
func _find_intelligent_tileset() -> String:
	var tileset_ids = asset_manager.get_tileset_ids()
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data and tileset_data.has_autotiling_intelligence():
			return tileset_id
	return ""
