## Test Runner
##
## Runs various tests and demos for the FE Map Creator system.
## Useful for debugging and verifying functionality.
class_name TestRunner
extends Node

# Test categories
enum TestCategory {
	ASSET_LOADING,
	MAP_IO,
	MAP_GENERATION,
	VALIDATION,
	UNDO_REDO,
	ALL
}

# Test results
var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0

## Run all tests
func run_all_tests():
	print("=== FE Map Creator Test Suite ===")
	
	test_results.clear()
	total_tests = 0
	passed_tests = 0
	
	_run_asset_loading_tests()
	_run_map_io_tests()
	_run_map_generation_tests()
	_run_validation_tests()
	_run_undo_redo_tests()
	
	_print_test_summary()

## Run specific test category
func run_tests(category: TestCategory):
	print("=== Running %s Tests ===" % _get_category_name(category))
	
	test_results.clear()
	total_tests = 0
	passed_tests = 0
	
	match category:
		TestCategory.ASSET_LOADING:
			_run_asset_loading_tests()
		TestCategory.MAP_IO:
			_run_map_io_tests()
		TestCategory.MAP_GENERATION:
			_run_map_generation_tests()
		TestCategory.VALIDATION:
			_run_validation_tests()
		TestCategory.UNDO_REDO:
			_run_undo_redo_tests()
		TestCategory.ALL:
			run_all_tests()
			return
	
	_print_test_summary()

## Asset loading tests
func _run_asset_loading_tests():
	print("\n--- Asset Loading Tests ---")
	
	# Test AssetManager initialization
	_test("AssetManager Initialization", func():
		var fe_data_path = "/Users/sunnigen/Godot/FEMapCreator"
		AssetManager.initialize(fe_data_path)
		return AssetManager.is_ready()
	)
	
	# Test terrain data loading
	_test("Terrain Data Loading", func():
		return AssetManager.terrain_data.size() > 0
	)
	
	# Test tileset data loading
	_test("Tileset Data Loading", func():
		return AssetManager.tileset_data.size() > 0
	)
	
	# Test specific terrain properties
	_test("Plains Terrain Properties", func():
		var plains_terrain = null
		for terrain_id in AssetManager.terrain_data:
			var terrain = AssetManager.terrain_data[terrain_id]
			if "plains" in terrain.name.to_lower():
				plains_terrain = terrain
				break
		
		return plains_terrain != null and plains_terrain.is_passable(0, 0)
	)
	
	# Test tileset resource creation
	_test("TileSet Resource Creation", func():
		var tileset_ids = AssetManager.get_tileset_ids()
		if tileset_ids.is_empty():
			return false
		
		var first_tileset = AssetManager.get_tileset_resource(tileset_ids[0])
		return first_tileset != null
	)

## Map I/O tests
func _run_map_io_tests():
	print("\n--- Map I/O Tests ---")
	
	# Test map creation
	var test_map: FEMap
	_test("Map Creation", func():
		test_map = FEMap.new()
		test_map.initialize(10, 8, 5)
		test_map.name = "Test Map"
		test_map.tileset_id = AssetManager.get_tileset_ids()[0] if not AssetManager.get_tileset_ids().is_empty() else "test"
		return test_map.width == 10 and test_map.height == 8 and test_map.tile_data.size() == 80
	)
	
	# Test tile manipulation
	_test("Tile Manipulation", func():
		if not test_map:
			return false
		
		test_map.set_tile_at(5, 4, 42)
		return test_map.get_tile_at(5, 4) == 42
	)
	
	# Test flood fill
	_test("Flood Fill", func():
		if not test_map:
			return false
		
		var tiles_changed = test_map.flood_fill(0, 0, 99)
		return tiles_changed > 0
	)
	
	# Test map saving and loading
	_test("Map Save/Load", func():
		if not test_map:
			return false
		
		var temp_path = "res://test_map.map"
		
		# Save map
		if not MapIO.save_map_to_file(test_map, temp_path):
			return false
		
		# Load map
		var loaded_map = MapIO.load_map_from_file(temp_path)
		if not loaded_map:
			return false
		
		# Verify data
		var matches = loaded_map.width == test_map.width and \
					 loaded_map.height == test_map.height and \
					 loaded_map.tileset_id == test_map.tileset_id
		
		# Clean up
		DirAccess.remove_absolute(temp_path)
		
		return matches
	)
	
	# Test JSON export
	_test("JSON Export", func():
		if not test_map:
			return false
		
		var temp_path = "res://test_map.json"
		var success = MapIO.export_to_json(test_map, temp_path)
		
		if success:
			DirAccess.remove_absolute(temp_path)
		
		return success
	)

## Map generation tests
func _run_map_generation_tests():
	print("\n--- Map Generation Tests ---")
	
	# Test basic generation
	_test("Basic Map Generation", func():
		var tileset_ids = AssetManager.get_tileset_ids()
		if tileset_ids.is_empty():
			return false
		
		var params = MapGenerator.GenerationParams.new()
		params.width = 15
		params.height = 12
		params.tileset_id = tileset_ids[0]
		params.algorithm = MapGenerator.Algorithm.RANDOM
		
		var generated_map = MapGenerator.generate_map(params)
		return generated_map != null and generated_map.tile_data.size() == 180
	)
	
	# Test Perlin noise generation
	_test("Perlin Noise Generation", func():
		var tileset_ids = AssetManager.get_tileset_ids()
		if tileset_ids.is_empty():
			return false
		
		var params = MapGenerator.GenerationParams.new()
		params.width = 20
		params.height = 15
		params.tileset_id = tileset_ids[0]
		params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
		params.seed_value = 12345
		
		var map1 = MapGenerator.generate_map(params)
		var map2 = MapGenerator.generate_map(params)
		
		# Same seed should produce same map
		return map1.tile_data == map2.tile_data
	)
	
	# Test preset generation
	_test("Preset Generation", func():
		var tileset_ids = AssetManager.get_tileset_ids()
		if tileset_ids.is_empty():
			return false
		
		var params = MapGenerator.create_preset("small_skirmish", tileset_ids[0])
		var generated_map = MapGenerator.generate_map(params)
		
		return generated_map != null and generated_map.width == 15 and generated_map.height == 12
	)

## Validation tests
func _run_validation_tests():
	print("\n--- Validation Tests ---")
	
	# Create test maps
	var valid_map = FEMap.new()
	valid_map.initialize(20, 15, 0)
	var tileset_ids = AssetManager.get_tileset_ids()
	if not tileset_ids.is_empty():
		valid_map.tileset_id = tileset_ids[0]
	
	var invalid_map = FEMap.new()
	invalid_map.width = 5
	invalid_map.height = 5
	invalid_map.tile_data.assign([0, 1, 2])  # Wrong size
	invalid_map.tileset_id = "nonexistent"
	
	# Test valid map validation
	_test("Valid Map Validation", func():
		var result = MapValidator.validate_map(valid_map)
		return result != null and not result.has_critical_issues()
	)
	
	# Test invalid map detection
	_test("Invalid Map Detection", func():
		var result = MapValidator.validate_map(invalid_map)
		return result != null and result.has_critical_issues()
	)
	
	# Test auto-fix functionality
	_test("Auto-fix Functionality", func():
		var broken_map = FEMap.new()
		broken_map.initialize(10, 10, 0)
		broken_map.tile_data.append(1024)  # Invalid tile
		broken_map.tile_data.append(-1)    # Invalid tile
		
		var validation = MapValidator.validate_map(broken_map)
		var fixed_count = MapValidator.auto_fix_map(broken_map, validation.issues)
		
		return fixed_count > 0
	)
	
	# Test validation statistics
	_test("Validation Statistics", func():
		var result = MapValidator.validate_map(valid_map)
		return result.stats.has("dimensions") and result.stats.has("total_tiles")
	)

## Undo/Redo tests
func _run_undo_redo_tests():
	print("\n--- Undo/Redo Tests ---")
	
	var test_map = FEMap.new()
	test_map.initialize(10, 10, 0)
	
	var undo_manager = UndoRedoManager.new()
	undo_manager.set_current_map(test_map)
	
	# Test paint action
	_test("Paint Action Undo/Redo", func():
		# Paint a tile
		test_map.set_tile_at(5, 5, 42)
		undo_manager.add_paint_action(Vector2i(5, 5), 0, 42)
		
		# Undo
		var could_undo = undo_manager.undo()
		var tile_after_undo = test_map.get_tile_at(5, 5)
		
		# Redo
		var could_redo = undo_manager.redo()
		var tile_after_redo = test_map.get_tile_at(5, 5)
		
		return could_undo and tile_after_undo == 0 and could_redo and tile_after_redo == 42
	)
	
	# Test flood fill action
	_test("Flood Fill Action", func():
		# Fill area
		var affected_tiles = {}
		for y in range(3):
			for x in range(3):
				affected_tiles[Vector2i(x, y)] = test_map.get_tile_at(x, y)
		
		test_map.flood_fill(0, 0, 99)
		undo_manager.add_flood_fill_action(Vector2i(0, 0), affected_tiles, 99)
		
		# Undo
		var could_undo = undo_manager.undo()
		var tile_after_undo = test_map.get_tile_at(0, 0)
		
		return could_undo and tile_after_undo != 99
	)
	
	# Test history management
	_test("History Management", func():
		undo_manager.clear_history()
		
		# Add multiple actions
		for i in range(5):
			undo_manager.add_paint_action(Vector2i(i, i), 0, i + 1)
		
		var history_count = undo_manager.get_undo_count()
		return history_count == 5
	)

## Helper function to run a single test
func _test(test_name: String, test_func: Callable) -> bool:
	total_tests += 1
	
	var start_time = Time.get_ticks_msec()
	var result = false
	

	result = test_func.call()
	if result == null:
		result = false
	
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0
	
	if result:
		passed_tests += 1
		print("  ✓ %s (%.3fs)" % [test_name, duration])
	else:
		print("  ✗ %s (%.3fs)" % [test_name, duration])
	
	test_results[test_name] = {
		"passed": result,
		"duration": duration
	}
	
	return result

## Print test summary
func _print_test_summary():
	print("\n=== Test Summary ===")
	print("Total tests: %d" % total_tests)
	print("Passed: %d" % passed_tests)
	print("Failed: %d" % (total_tests - passed_tests))
	print("Success rate: %.1f%%" % ((float(passed_tests) / float(total_tests)) * 100.0))
	
	if passed_tests < total_tests:
		print("\nFailed tests:")
		for test_name in test_results:
			if not test_results[test_name].passed:
				print("  - %s" % test_name)

## Get category name for display
func _get_category_name(category: TestCategory) -> String:
	match category:
		TestCategory.ASSET_LOADING:
			return "Asset Loading"
		TestCategory.MAP_IO:
			return "Map I/O"
		TestCategory.MAP_GENERATION:
			return "Map Generation"
		TestCategory.VALIDATION:
			return "Validation"
		TestCategory.UNDO_REDO:
			return "Undo/Redo"
		TestCategory.ALL:
			return "All"
		_:
			return "Unknown"

## Run quick demo of main features
func run_quick_demo():
	print("=== FE Map Creator Quick Demo ===")
	
	# Initialize
	print("1. Initializing AssetManager...")
	AssetManager.initialize("/Users/sunnigen/Godot/FEMapCreator")
	
	if not AssetManager.is_ready():
		print("   Error: AssetManager failed to initialize!")
		return
	
	print("   ✓ Loaded %d terrain types" % AssetManager.terrain_data.size())
	print("   ✓ Loaded %d tilesets" % AssetManager.tileset_data.size())
	
	# Generate a map
	print("\n2. Generating a map...")
	var tileset_ids = AssetManager.get_tileset_ids()
	if tileset_ids.is_empty():
		print("   Error: No tilesets available!")
		return
	
	var params = MapGenerator.create_preset("small_skirmish", tileset_ids[0])
	var demo_map = MapGenerator.generate_map(params)
	
	print("   ✓ Generated %dx%d map using %s tileset" % [demo_map.width, demo_map.height, demo_map.tileset_id])
	
	# Validate the map
	print("\n3. Validating map...")
	var validation = MapValidator.validate_map(demo_map)
	print("   ✓ " + validation.get_summary())
	
	if validation.issues.size() > 0:
		print("   Issues found:")
		for issue in validation.issues.slice(0, 3):  # Show first 3 issues
			print("     - %s: %s" % [issue.title, issue.description])
	
	# Save the map
	print("\n4. Saving map...")
	var demo_path = "res://demo_map.map"
	if MapIO.save_map_to_file(demo_map, demo_path):
		print("   ✓ Saved to %s" % demo_path)
		
		# Load it back
		var loaded_map = MapIO.load_map_from_file(demo_path)
		if loaded_map:
			print("   ✓ Successfully loaded back from file")
		
		# Clean up
		DirAccess.remove_absolute(demo_path)
	else:
		print("   ✗ Failed to save map")
	
	print("\n=== Demo Complete ===")

## Get system status for debugging
func get_system_status() -> Dictionary:
	return {
		"asset_manager": AssetManager.get_status(),
		"available_tilesets": AssetManager.get_tileset_ids(),
		"sample_terrain": _get_sample_terrain_info(),
		"memory_usage": _get_memory_usage_estimate()
	}

## Get sample terrain info for debugging
func _get_sample_terrain_info() -> Dictionary:
	var info = {}
	var count = 0
	
	for terrain_id in AssetManager.terrain_data:
		if count >= 5:  # Just show first 5
			break
		
		var terrain = AssetManager.terrain_data[terrain_id]
		info[terrain.name] = {
			"id": terrain_id,
			"passable": terrain.is_passable(0, 0),
			"movement_cost": terrain.get_movement_cost(0, 0),
			"bonuses": terrain.get_stats_string()
		}
		count += 1
	
	return info

## Rough memory usage estimate
func _get_memory_usage_estimate() -> Dictionary:
	var terrain_size = AssetManager.terrain_data.size() * 200  # Rough estimate
	var tileset_size = AssetManager.tileset_data.size() * 1024 * 4  # Terrain tags array
	var texture_size = AssetManager.tileset_textures.size() * 512 * 512 * 4  # Rough texture size
	
	return {
		"terrain_data_bytes": terrain_size,
		"tileset_data_bytes": tileset_size,
		"texture_data_bytes": texture_size,
		"total_estimated_bytes": terrain_size + tileset_size + texture_size
	}
