## Test Autotiling Intelligence System
##
## This script demonstrates the pattern analysis and smart tile placement capabilities.
extends Control

@onready var output_label: RichTextLabel = $VBoxContainer/ScrollContainer/OutputLabel
@onready var test_button: Button = $VBoxContainer/TestButton
@onready var analyze_button: Button = $VBoxContainer/AnalyzeButton
@onready var validate_button: Button = $VBoxContainer/ValidateButton

var analysis_results: Dictionary = {}

func _ready():
	test_button.pressed.connect(_on_test_pressed)
	analyze_button.pressed.connect(_on_analyze_pressed) 
	validate_button.pressed.connect(_on_validate_pressed)
	
	# Set up the UI
	output_label.bbcode_enabled = true
	_update_output("[color=cyan]🧠 Autotiling Intelligence Test Console[/color]\n")
	_update_output("Ready to test pattern analysis system.\n\n")
	
	# Check if AssetManager is ready
	if AssetManager.initialized:
		_update_output("[color=green]✅ AssetManager is already initialized[/color]\n")
		_enable_buttons()
	else:
		_update_output("[color=yellow]⏳ Waiting for AssetManager initialization...[/color]\n")
		AssetManager.initialization_completed.connect(_on_asset_manager_ready)

func _on_asset_manager_ready():
	_update_output("[color=green]✅ AssetManager initialized successfully![/color]\n")
	_enable_buttons()

func _enable_buttons():
	test_button.disabled = false
	analyze_button.disabled = false
	validate_button.disabled = false

func _on_test_pressed():
	_update_output("\n[color=cyan]🧪 Testing Autotiling Intelligence System[/color]\n")
	_test_autotiling_system()

func _on_analyze_pressed():
	_update_output("\n[color=cyan]📊 Running Pattern Analysis[/color]\n")
	_analyze_patterns()

func _on_validate_pressed():
	_update_output("\n[color=cyan]✅ Validating Pattern Databases[/color]\n")
	_validate_patterns()

func _test_autotiling_system():
	var tileset_ids = AssetManager.get_tileset_ids()
	_update_output("Found %d tilesets to test.\n" % tileset_ids.size())
	
	var tested_count = 0
	var intelligent_count = 0
	
	for tileset_id in tileset_ids:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data:
			continue
			
		tested_count += 1
		
		if tileset_data.has_autotiling_intelligence():
			intelligent_count += 1
			_test_tileset_intelligence(tileset_id, tileset_data)
		else:
			_update_output("  [color=orange]⚠️ %s: No autotiling intelligence available[/color]\n" % tileset_id)
	
	_update_output("\n[color=green]🎯 Test Summary:[/color]\n")
	_update_output("  • Total tilesets tested: %d\n" % tested_count)
	_update_output("  • Tilesets with autotiling: %d\n" % intelligent_count)
	_update_output("  • Intelligence coverage: %.1f%%[/color]\n" % (float(intelligent_count) / float(tested_count) * 100.0))

func _test_tileset_intelligence(tileset_id: String, tileset_data: FETilesetData):
	var stats = tileset_data.get_autotiling_stats()
	
	_update_output("  [color=lime]✅ %s (%s):[/color]\n" % [tileset_id, tileset_data.name])
	_update_output("    • Patterns: %d\n" % stats.patterns)
	_update_output("    • Terrain coverage: %d types\n" % stats.terrain_coverage)
	
	# Test smart tile selection
	_test_smart_tile_selection(tileset_data)

func _test_smart_tile_selection(tileset_data: FETilesetData):
	# Test a few common terrain scenarios
	var test_scenarios = [
		{"name": "Plains surrounded by plains", "terrain": 1, "neighbors": [1,1,1,1,1,1,1,1]},
		{"name": "Forest next to plains", "terrain": 2, "neighbors": [1,1,1,1,2,2,2,2]},
		{"name": "Water edge case", "terrain": 3, "neighbors": [1,1,2,3,3,3,1,1]}
	]
	
	for scenario in test_scenarios:
		var smart_tile = tileset_data.get_smart_tile(scenario.terrain, scenario.neighbors)
		var basic_tile = tileset_data.get_basic_tile_for_terrain(scenario.terrain)
		
		if smart_tile != basic_tile:
			_update_output("    • %s: Smart tile %d (vs basic %d) ✨\n" % [scenario.name, smart_tile, basic_tile])
		else:
			_update_output("    • %s: Standard tile %d\n" % [scenario.name, smart_tile])

func _analyze_patterns():
	var tileset_ids = AssetManager.get_tileset_ids()
	analysis_results.clear()
	
	for tileset_id in tileset_ids:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		if not tileset_data or not tileset_data.has_autotiling_intelligence():
			continue
			
		var validation = PatternAnalyzer.validate_pattern_database(tileset_data.autotiling_db)
		analysis_results[tileset_id] = validation
		
		_update_output("📊 [color=cyan]%s Analysis:[/color]\n" % tileset_id)
		_update_output("  • Total patterns: %d\n" % validation.total_patterns)
		_update_output("  • Terrain types: %d\n" % validation.terrain_coverage.size())
		
		# Show quality distribution
		var quality = validation.pattern_quality
		_update_output("  • Quality: High(%d) Med(%d) Low(%d)\n" % [quality.high, quality.medium, quality.low])
		
		# Show recommendations
		if validation.recommendations.size() > 0:
			_update_output("  [color=yellow]⚠️ Recommendations:[/color]\n")
			for rec in validation.recommendations:
				_update_output("    - %s\n" % rec)
		else:
			_update_output("  [color=green]✅ No issues found[/color]\n")
		
		_update_output("\n")

func _validate_patterns():
	if analysis_results.is_empty():
		_update_output("[color=orange]⚠️ Run analysis first to see validation results[/color]\n")
		return
	
	_update_output("🔍 [color=cyan]Pattern Database Validation:[/color]\n\n")
	
	var total_patterns = 0
	var total_terrains = 0
	var high_quality_count = 0
	var issues_found = 0
	
	for tileset_id in analysis_results:
		var validation = analysis_results[tileset_id]
		total_patterns += validation.total_patterns
		total_terrains += validation.terrain_coverage.size()
		high_quality_count += validation.pattern_quality.high
		issues_found += validation.recommendations.size()
	
	_update_output("[color=lime]📈 Overall Statistics:[/color]\n")
	_update_output("  • Total patterns extracted: %d\n" % total_patterns)
	_update_output("  • Total terrain types covered: %d\n" % total_terrains)
	_update_output("  • High quality patterns: %d\n" % high_quality_count)
	_update_output("  • Issues/Recommendations: %d\n" % issues_found)
	
	# Calculate average patterns per tileset
	var avg_patterns = float(total_patterns) / float(analysis_results.size())
	_update_output("  • Average patterns per tileset: %.1f\n" % avg_patterns)
	
	# Overall quality assessment
	var quality_score = float(high_quality_count) / float(total_patterns) * 100.0
	if quality_score >= 70.0:
		_update_output("\n  [color=green]🎉 Overall Quality: Excellent (%.1f%%)[/color]\n" % quality_score)
	elif quality_score >= 50.0:
		_update_output("\n  [color=yellow]⚡ Overall Quality: Good (%.1f%%)[/color]\n" % quality_score)
	else:
		_update_output("\n  [color=orange]⚠️ Overall Quality: Needs Improvement (%.1f%%)[/color]\n" % quality_score)

func _update_output(text: String):
	output_label.append_text(text)
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	var v_scroll = output_label.get_parent() as ScrollContainer
	if v_scroll:
		v_scroll.scroll_vertical = v_scroll.get_v_scroll_bar().max_value

func _on_clear_pressed():
	output_label.clear()
	_update_output("[color=cyan]🧠 Autotiling Intelligence Test Console[/color]\n")
	_update_output("Console cleared.\n\n")
