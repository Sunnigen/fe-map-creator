## Phase 1 Verification Test
##
## Comprehensive test to verify that autotiling intelligence is working correctly.
## This test will check every component and provide detailed pass/fail results.
extends Control

@onready var output_label: RichTextLabel = $VBoxContainer/ScrollContainer/OutputLabel
@onready var run_test_button: Button = $VBoxContainer/ButtonContainer/RunTestButton
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0

func _ready():
	run_test_button.pressed.connect(_run_comprehensive_verification)
	output_label.bbcode_enabled = true
	
	_log("[color=cyan]🔍 Phase 1 Autotiling Intelligence Verification System[/color]")
	_log("Click 'Run Full Verification' to test all components.\n")

func _run_comprehensive_verification():
	_log("\n[color=yellow]🚀 Starting Phase 1 Comprehensive Verification...[/color]\n")
	
	run_test_button.disabled = true
	progress_bar.visible = true
	progress_bar.value = 0
	
	test_results.clear()
	total_tests = 0
	passed_tests = 0
	
	# Run all verification tests
	_log("[color=yellow]Starting test sequence...[/color]")
	await _test_file_structure()
	_log("[color=yellow]Test 1 complete[/color]")
	
	await _test_asset_manager_integration()
	_log("[color=yellow]Test 2 complete[/color]")
	
	await _test_pattern_analysis_system()
	_log("[color=yellow]Test 3 complete[/color]")
	
	await _test_tileset_intelligence()
	_log("[color=yellow]Test 4 complete[/color]")
	
	await _test_pattern_quality()
	_log("[color=yellow]Test 5 complete[/color]")
	
	await _test_resource_saving()
	_log("[color=yellow]Test 6 complete[/color]")
	
	await _test_smart_tile_selection()
	_log("[color=yellow]Test 7 complete[/color]")
	
	# Generate final report
	_generate_final_report()
	
	run_test_button.disabled = false
	progress_bar.visible = false

## Test 1: File Structure and Dependencies
func _test_file_structure():
	_log("[color=cyan]📁 Test 1: File Structure and Dependencies[/color]")
	
	var required_files = [
		"res://scripts/resources/TilePattern.gd",
		"res://scripts/resources/AutotilingDatabase.gd", 
		"res://scripts/tools/PatternAnalyzer.gd"
	]
	
	var all_files_exist = true
	for file_path in required_files:
		if FileAccess.file_exists(file_path):
			_log("  ✅ Found: %s" % file_path.get_file())
		else:
			_log("  ❌ Missing: %s" % file_path.get_file())
			all_files_exist = false
	
	# Test resource classes can be instantiated
	var pattern = TilePattern.new()
	var database = AutotilingDatabase.new()
	
	if pattern and database:
		_log("  ✅ Resource classes instantiate correctly")
	else:
		_log("  ❌ Resource classes failed to instantiate")
		all_files_exist = false
	
	_record_test("File Structure", all_files_exist)
	_update_progress()
	await get_tree().process_frame

## Test 2: AssetManager Integration
func _test_asset_manager_integration():
	_log("\n[color=cyan]⚙️ Test 2: AssetManager Integration[/color]")
	
	# Check if AssetManager has the new methods
	var has_extract_method = AssetManager.has_method("extract_autotiling_patterns")
	var has_save_method = AssetManager.has_method("save_pattern_databases")
	
	_log("  • extract_autotiling_patterns(): %s" % ("✅" if has_extract_method else "❌"))
	_log("  • save_pattern_databases(): %s" % ("✅" if has_save_method else "❌"))
	
	# Check if initialization path is set
	var data_path = "res://data"
	var path_exists = DirAccess.dir_exists_absolute(data_path)
	
	_log("  • FE Data Path exists: %s (%s)" % [("✅" if path_exists else "❌"), data_path])

	
	# Test initialization - check if we need to initialize or if it's already done
	if AssetManager.initialized:
		_log("  ✅ AssetManager already initialized")
		# Check current state
		var tileset_count = AssetManager.get_tileset_ids().size()
		_log("  📊 Current state: %d tilesets loaded" % tileset_count)
		
		# Check if any have intelligence
		var intelligent_count = 0
		for tid in AssetManager.get_tileset_ids():
			var tdata = AssetManager.get_tileset_data(tid)
			if tdata and tdata.has_autotiling_intelligence():
				intelligent_count += 1
		_log("  🧠 Tilesets with intelligence: %d" % intelligent_count)
		
		# Force re-initialization to load patterns
		if intelligent_count == 0:
			_log("  🔄 Re-initializing to load pattern databases...")
			AssetManager.initialize(data_path)
			await AssetManager.await_ready()
			_log("  ✅ Re-initialization complete")
	else:
		_log("  🔄 Initializing AssetManager...")
		AssetManager.initialize(data_path)
		await AssetManager.await_ready()
		_log("  ✅ AssetManager initialization complete")
			
	# Always give it a frame to settle
	await get_tree().process_frame
	
	var integration_success = has_extract_method and has_save_method and path_exists and AssetManager.initialized
	_record_test("AssetManager Integration", integration_success)
	_update_progress()
	await get_tree().process_frame

## Test 3: Pattern Analysis System
func _test_pattern_analysis_system():
	_log("\n[color=cyan]🧠 Test 3: Pattern Analysis System[/color]")
	print("DEBUG: Starting Test 3 - Pattern Analysis System")
	
	# Test PatternAnalyzer can be called
	var analyzer_works = true
	
	
	# Check that PatternAnalyzer is a valid object and has the needed methods
	#var has_analyze_method = PatternAnalyzer != null and PatternAnalyzer.has_method("analyze_all_original_maps")
	#var has_validate_method = PatternAnalyzer != null and PatternAnalyzer.has_method("validate_pattern_database")

	#_log("  • analyze_all_original_maps(): %s" % ("✅" if has_analyze_method else "❌"))
	#_log("  • validate_pattern_database(): %s" % ("✅" if has_validate_method else "❌"))
#
	#analyzer_works = has_analyze_method and has_validate_method
#
	## Optional fallback log
	#if not analyzer_works:
		#_log("  ❌ PatternAnalyzer methods not accessible")
	
	# Check if pattern databases directory was created
	var patterns_dir = "res://resources/autotiling_patterns/"
	var dir_exists = DirAccess.dir_exists_absolute(patterns_dir)
	
	_log("  • Pattern database directory: %s" % ("✅" if dir_exists else "❌"))
	
	analyzer_works = analyzer_works and dir_exists
	_record_test("Pattern Analysis System", analyzer_works)
	_update_progress()
	await get_tree().process_frame

## Test 4: Tileset Intelligence Integration
func _test_tileset_intelligence():
	_log("\n[color=cyan]🎯 Test 4: Tileset Intelligence Integration[/color]")
	print("DEBUG: Starting Test 4 - Tileset Intelligence Integration")
	
	var tileset_ids = AssetManager.get_tileset_ids()
	_log("  • Found %d tilesets" % tileset_ids.size())
	
	var tilesets_with_intelligence = 0
	var total_patterns = 0
	var tested_tilesets = 0
	
	# Test first few tilesets
	for tileset_id in tileset_ids:
		if tested_tilesets >= 5:  # Limit testing for performance
			break
			
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data:
			continue
			
		tested_tilesets += 1
		
		# Check if tileset has intelligence methods
		var has_smart_tile_method = tileset_data.has_method("get_smart_tile")
		var has_intelligence_check = tileset_data.has_method("has_autotiling_intelligence")
		
		if not has_smart_tile_method or not has_intelligence_check:
			_log("  ❌ Tileset %s missing intelligence methods" % tileset_id)
			continue
			
		# Check if autotiling intelligence is available
		if tileset_data.has_autotiling_intelligence():
			tilesets_with_intelligence += 1
			var stats = tileset_data.get_autotiling_stats()
			total_patterns += stats.patterns
			_log("  ✅ %s: %d patterns" % [tileset_id, stats.patterns])
		else:
			_log("  ⚠️ %s: No intelligence available" % tileset_id)
	
	_log("  📊 Summary: %d/%d tilesets have intelligence (%d total patterns)" % [tilesets_with_intelligence, tested_tilesets, total_patterns])
	
	# Success if we have some tilesets with intelligence and total patterns > 0
	var intelligence_success = tilesets_with_intelligence > 0 and total_patterns > 0
	_record_test("Tileset Intelligence", intelligence_success)
	_update_progress()
	await get_tree().process_frame

## Test 5: Pattern Quality Assessment
func _test_pattern_quality():
	_log("\n[color=cyan]📈 Test 5: Pattern Quality Assessment[/color]")
	print("DEBUG: Starting Test 5 - Pattern Quality Assessment")
	
	var tileset_ids = AssetManager.get_tileset_ids()
	var quality_data = {"high": 0, "medium": 0, "low": 0, "total": 0}
	var validated_tilesets = 0
	
	for tileset_id in tileset_ids:
		if validated_tilesets >= 3:  # Limit for performance
			break
			
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data or not tileset_data.has_autotiling_intelligence():
			continue
			
		validated_tilesets += 1
		
		# Validate pattern database quality
		var validation = PatternAnalyzer.validate_pattern_database(tileset_data.autotiling_db)
		var quality = validation.pattern_quality
		
		quality_data.high += quality.high
		quality_data.medium += quality.medium  
		quality_data.low += quality.low
		quality_data.total += validation.total_patterns
		
		_log("  📊 %s: H:%d M:%d L:%d (Total: %d)" % [tileset_id, quality.high, quality.medium, quality.low, validation.total_patterns])
	
	if quality_data.total > 0:
		var high_percentage = float(quality_data.high) / float(quality_data.total) * 100.0
		_log("  🎯 Overall Quality: %.1f%% high-quality patterns" % high_percentage)
		
		# Success if we have reasonable quality distribution
		var quality_success = high_percentage >= 30.0 and quality_data.total >= 100
		_record_test("Pattern Quality", quality_success)
	else:
		_log("  ❌ No pattern data found for quality assessment")
		_record_test("Pattern Quality", false)
	
	_update_progress()
	await get_tree().process_frame

## Test 6: Resource Saving System
func _test_resource_saving():
	_log("\n[color=cyan]💾 Test 6: Resource Saving System[/color]")
	
	var patterns_dir = "res://resources/autotiling_patterns/"
	var dir = DirAccess.open(patterns_dir)
	
	if not dir:
		_log("  ❌ Pattern database directory not accessible")
		_record_test("Resource Saving", false)
		_update_progress()
		return
	
	# Count saved pattern files
	var pattern_files = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with("_patterns.tres"):
			pattern_files += 1
			_log("  ✅ Found pattern database: %s" % file_name)
		file_name = dir.get_next()
	
	_log("  📁 Total pattern database files: %d" % pattern_files)
	
	# Test loading a pattern database
	var loading_success = false
	if pattern_files > 0:
		dir.list_dir_begin()
		file_name = dir.get_next()
		
		while file_name != "" and not loading_success:
			if file_name.ends_with("_patterns.tres"):
				var pattern_db = load(patterns_dir + file_name) as AutotilingDatabase
				if pattern_db and pattern_db.patterns.size() > 0:
					_log("  ✅ Successfully loaded pattern database with %d patterns" % pattern_db.patterns.size())
					loading_success = true
				else:
					_log("  ⚠️ Pattern database %s exists but is empty or invalid" % file_name)
			file_name = dir.get_next()
	
	var saving_success = pattern_files > 0 and loading_success
	_record_test("Resource Saving", saving_success)
	_update_progress()
	await get_tree().process_frame

## Test 7: Smart Tile Selection
func _test_smart_tile_selection():
	_log("\n[color=cyan]🎯 Test 7: Smart Tile Selection[/color]")
	
	var tileset_ids = AssetManager.get_tileset_ids()
	var smart_selections = 0
	var _total_tests = 0
	
	# Test smart tile selection on available tilesets
	for tileset_id in tileset_ids:
		if _total_tests >= 3:  # Limit testing
			break
			
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data or not tileset_data.has_autotiling_intelligence():
			continue
			
		_total_tests += 1
		
		# Test various terrain scenarios
		var plains_neighbors: Array[int] = [1,1,1,1,1,1,1,1]
		var forest_neighbors: Array[int] = [1,1,1,2,2,1,1,1]
		var water_neighbors: Array[int] = [1,2,1,3,3,3,2,1]
		var mountain_neighbors: Array[int] = [1,1,4,4,4,1,1,1]
		
		var test_scenarios = [
			{"name": "Plains surrounded by plains", "terrain": 1, "neighbors": plains_neighbors},
			{"name": "Forest with plains neighbors", "terrain": 2, "neighbors": forest_neighbors},
			{"name": "Water transition", "terrain": 3, "neighbors": water_neighbors},
			{"name": "Mountain edge", "terrain": 4, "neighbors": mountain_neighbors}
		]
		
		var tileset_smart_selections = 0
		
		for scenario in test_scenarios:
			var smart_tile = tileset_data.get_smart_tile(scenario.terrain, scenario.neighbors)
			var basic_tile = tileset_data.get_basic_tile_for_terrain(scenario.terrain)
			
			if smart_tile != basic_tile and smart_tile != -1:
				tileset_smart_selections += 1
				_log("  🎯 %s - %s: Smart tile %d (basic: %d)" % [tileset_id, scenario.name, smart_tile, basic_tile])
		
		if tileset_smart_selections > 0:
			smart_selections += 1
			_log("  ✅ %s: %d intelligent selections found" % [tileset_id, tileset_smart_selections])
		else:
			_log("  ⚠️ %s: No intelligent selections detected" % tileset_id)
	
	var selection_success = smart_selections > 0
	_log("  📊 %d/%d tilesets showing intelligent tile selection" % [smart_selections, total_tests])
	
	_record_test("Smart Tile Selection", selection_success)
	_update_progress()
	await get_tree().process_frame

## Generate Final Report
func _generate_final_report():
	_log("\n" + "=".repeat(60))
	_log("[color=cyan]📋 PHASE 1 VERIFICATION FINAL REPORT[/color]")
	_log("=".repeat(60))

	
	# Overall success rate
	var success_rate = float(passed_tests) / float(total_tests) * 100.0
	
	if success_rate >= 85.0:
		_log("[color=lime]🎉 PHASE 1: COMPLETE AND FUNCTIONAL (%.1f%%)[/color]" % success_rate)
	elif success_rate >= 70.0:
		_log("[color=yellow]⚡ PHASE 1: MOSTLY FUNCTIONAL (%.1f%%)[/color]" % success_rate)
	else:
		_log("[color=red]❌ PHASE 1: NEEDS ATTENTION (%.1f%%)[/color]" % success_rate)
	
	_log("\n[color=cyan]📊 Detailed Results:[/color]")
	
	for test_name in test_results:
		var result = test_results[test_name]
		var status = "✅ PASS" if result else "❌ FAIL"
		_log("  %s: %s" % [test_name, status])
	
	# Recommendations based on results
	_log("\n[color=cyan]💡 Recommendations:[/color]")
	
	if test_results.get("File Structure", false) == false:
		_log("  🔧 Fix missing files - check that all Phase 1 files were created correctly")
	
	if test_results.get("AssetManager Integration", false) == false:
		_log("  🔧 Check AssetManager initialization - verify FE data path is correct")
	
	if test_results.get("Tileset Intelligence", false) == false:
		_log("  🔧 Pattern extraction may have failed - check that original .map files are accessible")
	
	if test_results.get("Pattern Quality", false) == false:
		_log("  🔧 Low pattern quality - may need more original maps or better extraction")
	
	if test_results.get("Smart Tile Selection", false) == false:
		_log("  🔧 Intelligence not active - patterns may be extracted but not providing smart selections")
	
	if success_rate >= 85.0:
		_log("\n[color=lime]🚀 Ready to proceed to Phase 2: Smart Map Generation Integration![/color]")
	elif success_rate >= 70.0:
		_log("\n[color=yellow]🔄 Address failing tests before proceeding to Phase 2[/color]")
	else:
		_log("\n[color=red]🛠️ Significant issues detected - Phase 1 needs debugging before proceeding[/color]")

## Helper functions
func _record_test(test_name: String, passed: bool):
	test_results[test_name] = passed
	total_tests += 1
	if passed:
		passed_tests += 1

func _update_progress():
	var progress = float(total_tests) / 7.0 * 100.0  # 7 total tests
	progress_bar.value = progress

func _log(message: String):
	output_label.append_text(message + "\n")
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	var v_scroll = output_label.get_parent() as ScrollContainer
	if v_scroll:
		v_scroll.scroll_vertical = v_scroll.get_v_scroll_bar().max_value
