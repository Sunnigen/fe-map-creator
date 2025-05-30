extends GutTest

# Test comparing intelligent vs legacy map generation
var asset_manager: AssetManager

func before_all():
	asset_manager = AssetManager
	await asset_manager.await_ready()

func test_intelligent_vs_legacy_perlin_generation():
	# Compare intelligent vs legacy Perlin noise generation
	var intelligent_tileset_id = _find_intelligent_tileset()
	var legacy_tileset_id = _find_legacy_tileset()
	
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping comparison")
		return
	
	if legacy_tileset_id.is_empty():
		gut.p("No legacy tileset found, using intelligent tileset for both tests")
		legacy_tileset_id = intelligent_tileset_id
	
	# Generate maps with same parameters but different tilesets
	var base_params = MapGenerator.GenerationParams.new()
	base_params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	base_params.map_theme = MapGenerator.MapTheme.MIXED
	base_params.complexity = 0.6
	base_params.width = 10
	base_params.height = 8
	base_params.seed_value = 98765  # Fixed seed for comparison
	
	# Intelligent generation
	var intelligent_params = _copy_params(base_params)
	intelligent_params.tileset_id = intelligent_tileset_id
	var intelligent_map = MapGenerator.generate_map(intelligent_params)
	
	# Legacy generation (or intelligent if no legacy available)
	var legacy_params = _copy_params(base_params)
	legacy_params.tileset_id = legacy_tileset_id
	var legacy_map = MapGenerator.generate_map(legacy_params)
	
	# Analyze both maps
	var intelligent_stats = _analyze_map_quality(intelligent_map)
	var legacy_stats = _analyze_map_quality(legacy_map)
	
	gut.p("=== GENERATION COMPARISON ===")
	gut.p("Intelligent tileset %s:" % intelligent_tileset_id)
	gut.p("  - Unique tiles: %d (%.1f%% variety)" % [intelligent_stats.unique_tiles, intelligent_stats.variety_ratio * 100])
	gut.p("  - Transition quality: %.1f%%" % [intelligent_stats.transition_quality * 100])
	
	gut.p("Legacy tileset %s:" % legacy_tileset_id)
	gut.p("  - Unique tiles: %d (%.1f%% variety)" % [legacy_stats.unique_tiles, legacy_stats.variety_ratio * 100])
	gut.p("  - Transition quality: %.1f%%" % [legacy_stats.transition_quality * 100])
	
	# Intelligent generation should have better quality metrics
	if intelligent_tileset_id != legacy_tileset_id:
		assert_gte(intelligent_stats.variety_ratio, legacy_stats.variety_ratio * 0.8, 
			"Intelligent generation should have comparable or better variety")

func test_intelligent_generation_consistency():
	# Test that intelligent generation is consistent across multiple runs
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping consistency test")
		return
	
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params.map_theme = MapGenerator.MapTheme.FOREST
	params.complexity = 0.4
	params.width = 8
	params.height = 6
	params.tileset_id = intelligent_tileset_id
	params.seed_value = 11111  # Fixed seed
	
	# Generate multiple maps with same parameters
	var maps = []
	for i in range(3):
		var map = MapGenerator.generate_map(params)
		maps.append(map)
	
	# All maps should be identical (same seed)
	var first_map = maps[0]
	for i in range(1, maps.size()):
		var current_map = maps[i]
		for y in range(first_map.height):
			for x in range(first_map.width):
				var first_tile = first_map.get_tile_at(x, y)
				var current_tile = current_map.get_tile_at(x, y)
				assert_eq(first_tile, current_tile, 
					"Maps with same seed should be identical at position (%d,%d)" % [x, y])
	
	gut.p("✅ Intelligent generation is consistent with fixed seeds")

func test_strategic_placement_intelligence():
	# Test strategic placement with intelligence
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping strategic test")
		return
	
	var params = MapGenerator.GenerationParams.new()
	params.algorithm = MapGenerator.Algorithm.STRATEGIC_PLACEMENT
	params.map_theme = MapGenerator.MapTheme.MIXED
	params.complexity = 0.8  # High complexity for strategic features
	params.width = 15
	params.height = 10
	params.tileset_id = intelligent_tileset_id
	
	var map = MapGenerator.generate_map(params)
	var stats = _analyze_map_quality(map)
	
	gut.p("Strategic placement with intelligence:")
	gut.p("  - Map size: %dx%d" % [map.width, map.height])
	gut.p("  - Unique tiles: %d" % stats.unique_tiles)
	gut.p("  - Variety ratio: %.1f%%" % [stats.variety_ratio * 100])
	
	# Strategic placement should create varied maps
	assert_gt(stats.unique_tiles, 2, "Strategic placement should use multiple tile types")
	assert_gt(stats.variety_ratio, 0.03, "Should have reasonable variety")

func test_generation_debug_output():
	# Test that intelligent generation produces debug output
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping debug test")
		return
	
	# This test verifies that the debug messages are produced
	# We can't easily capture print output in GUT, but we can verify the functions exist
	var tileset_data = asset_manager.get_tileset_data(intelligent_tileset_id)
	assert_true(tileset_data.has_autotiling_intelligence(), "Should have intelligence")
	
	# Verify the intelligent generation functions exist by checking the script
	var generator_instance = MapGenerator.new()
	var script = generator_instance.get_script()
	var method_list = script.get_script_method_list()
	var method_names = method_list.map(func(m): return m.name)
	
	assert_true("_generate_perlin_noise_with_intelligence" in method_names, 
		"Should have intelligent Perlin generation")
	assert_true("_generate_strategic_placement_with_intelligence" in method_names, 
		"Should have intelligent strategic generation")
	assert_true("_get_smart_tile_for_terrain" in method_names, 
		"Should have smart tile selection")

func test_edge_cases_and_robustness():
	# Test edge cases in intelligent generation
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping edge case test")
		return
	
	# Test very small map
	var small_params = MapGenerator.GenerationParams.new()
	small_params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	small_params.map_theme = MapGenerator.MapTheme.PLAINS
	small_params.complexity = 0.1
	small_params.width = 2
	small_params.height = 2
	small_params.tileset_id = intelligent_tileset_id
	
	var small_map = MapGenerator.generate_map(small_params)
	assert_not_null(small_map, "Should handle very small maps")
	assert_eq(small_map.width, 2, "Small map should have correct width")
	assert_eq(small_map.height, 2, "Small map should have correct height")
	
	# Test very large map (within reason)
	var large_params = MapGenerator.GenerationParams.new()
	large_params.algorithm = MapGenerator.Algorithm.STRATEGIC_PLACEMENT
	large_params.map_theme = MapGenerator.MapTheme.MIXED
	large_params.complexity = 0.5
	large_params.width = 25
	large_params.height = 20
	large_params.tileset_id = intelligent_tileset_id
	
	var large_map = MapGenerator.generate_map(large_params)
	assert_not_null(large_map, "Should handle larger maps")
	assert_eq(large_map.width, 25, "Large map should have correct width")
	assert_eq(large_map.height, 20, "Large map should have correct height")

func test_all_algorithms_with_intelligence():
	# Test that all algorithms work with intelligent tilesets
	var intelligent_tileset_id = _find_intelligent_tileset()
	if intelligent_tileset_id.is_empty():
		gut.p("No intelligent tileset found, skipping algorithm test")
		return
	
	var algorithms = [
		MapGenerator.Algorithm.RANDOM,
		MapGenerator.Algorithm.PERLIN_NOISE,
		MapGenerator.Algorithm.CELLULAR_AUTOMATA,
		MapGenerator.Algorithm.TEMPLATE_BASED,
		MapGenerator.Algorithm.STRATEGIC_PLACEMENT
	]
	
	for algorithm in algorithms:
		var params = MapGenerator.GenerationParams.new()
		params.algorithm = algorithm
		params.map_theme = MapGenerator.MapTheme.MIXED
		params.complexity = 0.5
		params.width = 8
		params.height = 6
		params.tileset_id = intelligent_tileset_id
		
		var map = MapGenerator.generate_map(params)
		assert_not_null(map, "Algorithm %s should work with intelligent tileset" % algorithm)
		assert_eq(map.tileset_id, intelligent_tileset_id, "Should use intelligent tileset")
		
		var stats = _analyze_map_quality(map)
		gut.p("Algorithm %s: %d unique tiles, %.1f%% variety" % 
			[algorithm, stats.unique_tiles, stats.variety_ratio * 100])

# Helper functions
func _find_intelligent_tileset() -> String:
	var tileset_ids = asset_manager.get_tileset_ids()
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data and tileset_data.has_autotiling_intelligence():
			return tileset_id
	return ""

func _find_legacy_tileset() -> String:
	var tileset_ids = asset_manager.get_tileset_ids()
	for tileset_id in tileset_ids:
		var tileset_data = asset_manager.get_tileset_data(tileset_id)
		if tileset_data and not tileset_data.has_autotiling_intelligence():
			return tileset_id
	return ""

func _analyze_map_quality(map: FEMap) -> Dictionary:
	var tile_counts = {}
	var total_tiles = map.width * map.height
	
	# Count unique tiles
	for y in range(map.height):
		for x in range(map.width):
			var tile = map.get_tile_at(x, y)
			tile_counts[tile] = tile_counts.get(tile, 0) + 1
	
	var unique_tiles = tile_counts.size()
	var variety_ratio = float(unique_tiles) / float(total_tiles)
	
	# Calculate transition quality (simplified)
	var good_transitions = 0
	var total_transitions = 0
	
	for y in range(map.height):
		for x in range(map.width):
			if x < map.width - 1:
				total_transitions += 1
				# For now, consider all transitions "good"
				good_transitions += 1
			if y < map.height - 1:
				total_transitions += 1
				good_transitions += 1
	
	var transition_quality = float(good_transitions) / float(total_transitions) if total_transitions > 0 else 0.0
	
	return {
		"unique_tiles": unique_tiles,
		"variety_ratio": variety_ratio,
		"transition_quality": transition_quality,
		"total_tiles": total_tiles
	}

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
