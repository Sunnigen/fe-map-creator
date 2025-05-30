extends Node

# Test script to compare map generation with and without autotiling intelligence

func _ready():
	print("\n=== MAP GENERATION COMPARISON TEST ===")
	print("This test compares the old MapGenerator (random tiles) with MapGeneratorV2 (autotiling intelligence)")
	
	# Wait for AssetManager
	if not AssetManager.is_ready():
		AssetManager.initialization_complete.connect(_on_asset_manager_ready, CONNECT_ONE_SHOT)
	else:
		_on_asset_manager_ready()

func _on_asset_manager_ready():
	print("\nAssetManager ready, starting comparison tests...")
	
	# Get a tileset with good autotiling coverage
	var tileset_ids = AssetManager.get_available_tileset_ids()
	var test_tileset_id = ""
	var best_pattern_count = 0
	
	# Find tileset with most patterns
	for tileset_id in tileset_ids:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if tileset_data and tileset_data.has_autotiling_intelligence():
			var stats = tileset_data.get_autotiling_stats()
			if stats.patterns > best_pattern_count:
				best_pattern_count = stats.patterns
				test_tileset_id = tileset_id
	
	if test_tileset_id == "":
		push_error("No tilesets with autotiling intelligence found!")
		return
	
	var tileset_data = AssetManager.get_tileset_data(test_tileset_id)
	print("\nUsing tileset: %s (%s)" % [test_tileset_id, tileset_data.name])
	print("Autotiling patterns: %d" % best_pattern_count)
	
	# Test parameters
	var width = 20
	var height = 15
	var seed_value = 12345  # Fixed seed for reproducible results
	
	# Generate with old MapGenerator (no autotiling)
	print("\n--- Generating with MapGenerator (random tiles) ---")
	var params_v1 = MapGenerator.GenerationParams.new()
	params_v1.width = width
	params_v1.height = height
	params_v1.tileset_id = test_tileset_id
	params_v1.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	params_v1.map_theme = MapGenerator.MapTheme.PLAINS
	params_v1.seed_value = seed_value
	
	var map_v1 = MapGenerator.generate_map(params_v1)
	_analyze_map(map_v1, tileset_data, "MapGenerator V1")
	
	# Generate with new MapGeneratorV2 (with autotiling)
	print("\n--- Generating with MapGeneratorV2 (autotiling intelligence) ---")
	var params_v2 = MapGeneratorV2.GenerationParams.new()
	params_v2.width = width
	params_v2.height = height
	params_v2.tileset_id = test_tileset_id
	params_v2.algorithm = MapGeneratorV2.Algorithm.PERLIN_NOISE
	params_v2.map_theme = MapGeneratorV2.MapTheme.PLAINS
	params_v2.seed_value = seed_value
	params_v2.use_autotiling = true
	
	var map_v2 = MapGeneratorV2.generate_map(params_v2)
	_analyze_map(map_v2, tileset_data, "MapGenerator V2")
	
	# Compare edge continuity
	print("\n--- Edge Continuity Analysis ---")
	var v1_score = _calculate_edge_continuity_score(map_v1, tileset_data)
	var v2_score = _calculate_edge_continuity_score(map_v2, tileset_data)
	
	print("V1 Edge Continuity Score: %.2f%%" % v1_score)
	print("V2 Edge Continuity Score: %.2f%%" % v2_score)
	print("Improvement: %.2f%%" % (v2_score - v1_score))
	
	# Save both maps for visual comparison
	var base_path = "user://map_generation_comparison_"
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	
	MapIO.save_map(map_v1, base_path + timestamp + "_v1.map")
	MapIO.save_map(map_v2, base_path + timestamp + "_v2.map")
	
	print("\nMaps saved for comparison:")
	print("  V1: " + base_path + timestamp + "_v1.map")
	print("  V2: " + base_path + timestamp + "_v2.map")
	
	print("\n=== COMPARISON TEST COMPLETE ===")

func _analyze_map(map: FEMap, tileset_data: FETilesetData, generator_name: String):
	print("\nAnalyzing %s output:" % generator_name)
	
	# Count unique tiles used
	var tile_usage = {}
	var terrain_usage = {}
	
	for y in range(map.height):
		for x in range(map.width):
			var tile = map.get_tile_at(x, y)
			tile_usage[tile] = tile_usage.get(tile, 0) + 1
			
			var terrain_id = tileset_data.get_terrain_type(tile)
			terrain_usage[terrain_id] = terrain_usage.get(terrain_id, 0) + 1
	
	print("  Unique tiles used: %d" % tile_usage.size())
	print("  Unique terrain types: %d" % terrain_usage.size())
	
	# Show top 5 most used tiles
	var sorted_tiles = []
	for tile in tile_usage:
		sorted_tiles.append([tile, tile_usage[tile]])
	sorted_tiles.sort_custom(func(a, b): return a[1] > b[1])
	
	print("  Top 5 tiles:")
	for i in range(min(5, sorted_tiles.size())):
		var tile = sorted_tiles[i][0]
		var count = sorted_tiles[i][1]
		var terrain_id = tileset_data.get_terrain_type(tile)
		var terrain_data = AssetManager.get_terrain_data(terrain_id)
		var terrain_name = terrain_data.name if terrain_data else "Unknown"
		print("    Tile %d (%s): %d times" % [tile, terrain_name, count])

func _calculate_edge_continuity_score(map: FEMap, tileset_data: FETilesetData) -> float:
	# Calculate how well tiles match their neighbors
	var total_edges = 0
	var matching_edges = 0
	
	for y in range(map.height):
		for x in range(map.width):
			var center_tile = map.get_tile_at(x, y)
			var center_terrain = tileset_data.get_terrain_type(center_tile)
			
			# Check horizontal neighbor
			if x < map.width - 1:
				var right_tile = map.get_tile_at(x + 1, y)
				var right_terrain = tileset_data.get_terrain_type(right_tile)
				
				total_edges += 1
				if _terrains_compatible(center_terrain, right_terrain):
					matching_edges += 1
			
			# Check vertical neighbor
			if y < map.height - 1:
				var bottom_tile = map.get_tile_at(x, y + 1)
				var bottom_terrain = tileset_data.get_terrain_type(bottom_tile)
				
				total_edges += 1
				if _terrains_compatible(center_terrain, bottom_terrain):
					matching_edges += 1
	
	return (float(matching_edges) / float(total_edges)) * 100.0 if total_edges > 0 else 0.0

func _terrains_compatible(terrain1: int, terrain2: int) -> bool:
	# Simple compatibility check - same terrain or both passable
	if terrain1 == terrain2:
		return true
	
	var data1 = AssetManager.get_terrain_data(terrain1)
	var data2 = AssetManager.get_terrain_data(terrain2)
	
	if not data1 or not data2:
		return false
	
	# Consider terrains compatible if they have similar properties
	var passable1 = data1.is_passable(0, 0)
	var passable2 = data2.is_passable(0, 0)
	
	return passable1 == passable2