## Main Test Scene
##
## Test scene for verifying FEMapCreator foundation components.
extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var initialize_button: Button = $VBoxContainer/ButtonContainer/InitializeButton
@onready var load_map_button: Button = $VBoxContainer/ButtonContainer/LoadMapButton
@onready var test_all_button: Button = $VBoxContainer/ButtonContainer/TestAllButton
@onready var quick_demo_button: Button = $VBoxContainer/ButtonContainer/QuickDemoButton
@onready var generate_map_button: Button = $VBoxContainer/ButtonContainer/GenerateMapButton
@onready var output_text: TextEdit = $VBoxContainer/OutputTextEdit

var fe_data_path: String = ""
var test_runner: TestRunner

func _ready():
	# Set up the FE data path (adjust this to your actual path)
	fe_data_path = "/Users/sunnigen/Godot/projects/fe-map-creator"
	#fe_data_path = "/Users/sunnigen/Godot/FEMapCreator"
	
	# Create test runner
	test_runner = TestRunner.new()
	
	# Connect buttons
	initialize_button.pressed.connect(_on_initialize_pressed)
	load_map_button.pressed.connect(_on_load_map_pressed)
	test_all_button.pressed.connect(_on_test_all_pressed)
	quick_demo_button.pressed.connect(_on_quick_demo_pressed)
	generate_map_button.pressed.connect(_on_generate_map_pressed)
	
	# Connect to EventBus signals
	EventBus.editor_ready.connect(_on_editor_ready)
	EventBus.map_loaded.connect(_on_map_loaded)
	
	log_message("FE Map Creator Test Scene Ready")
	log_message("FE Data Path: " + fe_data_path)
	log_message("Choose an action to begin testing")

func _on_initialize_pressed():
	initialize_button.disabled = true
	status_label.text = "Initializing AssetManager..."
	log_message("Initializing AssetManager...")
	
	# Initialize AssetManager with FE data
	AssetManager.initialize(fe_data_path)
	
	# Check if initialization was successful  
	if AssetManager.is_ready():
		status_label.text = "AssetManager Ready"
		load_map_button.disabled = false
		test_all_button.disabled = false
		quick_demo_button.disabled = false
		generate_map_button.disabled = false
		
		var status = AssetManager.get_status()
		log_message("AssetManager initialized successfully!")
		log_message("- Terrain types loaded: " + str(status.terrain_count))
		log_message("- Tilesets loaded: " + str(status.tileset_count))
		log_message("- Textures loaded: " + str(status.texture_count))
		
		# Show system status
		var system_status = test_runner.get_system_status()
		log_message("System Status:")
		log_message("- Available tilesets: " + str(system_status.available_tilesets.size()))
		log_message("- Memory usage: ~" + str(system_status.memory_usage.total_estimated_bytes / 1024 / 1024) + " MB")
		
		EventBus.emit_editor_ready()
	else:
		status_label.text = "AssetManager Failed"
		initialize_button.disabled = false
		log_message("AssetManager initialization failed!")

func _on_load_map_pressed():
	log_message("Loading test map...")
	
	# Try to load a sample map from FE7
	var test_map_paths = [
		fe_data_path + "/FE7 Maps/0100xx03/Ch1FootstepsofFate.map",
		fe_data_path + "/FE6 Maps/0100xx01/Ch1 - Girl of the Plains.map",
		fe_data_path + "/FE8 Maps/0100xx01/Ch1 - The Fall of Renais.map"
	]
	
	var test_map_path = ""
	
	# Find the first existing map file
	for path in test_map_paths:
		if FileAccess.file_exists(path):
			test_map_path = path
			break
	
	if test_map_path.is_empty():
		# Try to find any .map file
		var available_maps = MapIO.get_available_maps(fe_data_path)
		log_message("No default test maps found. Available map collections:")
		
		for game in available_maps.keys():
			log_message("  " + game + ":")
			var collections = available_maps[game]
			for collection in collections:
				log_message("    " + collection.folder + " (" + str(collection.maps.size()) + " maps)")
				if collection.maps.size() > 0 and test_map_path.is_empty():
					# Use the first available map
					test_map_path = collection.maps[0].path
					log_message("    -> Using: " + collection.maps[0].name)
					break
			if not test_map_path.is_empty():
				break
	
	if test_map_path.is_empty():
		log_message("No .map files found in FE data directory!")
		return
	
	# Load the map
	var map = MapIO.load_map_from_file(test_map_path)
	
	if map:
		log_message("Map loaded successfully!")
		log_message("- Name: " + map.name)
		log_message("- Dimensions: " + str(map.width) + "x" + str(map.height))
		log_message("- Tileset ID: " + map.tileset_id)
		log_message("- Total tiles: " + str(map.tile_data.size()))
		
		# Validate the map
		var validation = map.validate()
		if validation.valid:
			log_message("Map validation: PASSED")
		else:
			log_message("Map validation: FAILED")
			for issue in validation.issues:
				log_message("  Issue: " + issue) 
		
		for warning in validation.warnings:
			log_message("  Warning: " + warning)
		
		# Perform advanced validation
		log_message("Running advanced validation...")
		var advanced_validation = MapValidator.validate_map(map)
		log_message("Advanced validation: " + advanced_validation.get_summary())
		
		if advanced_validation.issues.size() > 0:
			log_message("Issues found:")
			for issue in advanced_validation.issues.slice(0, 5):
				log_message("  - " + issue.title + ": " + issue.description)
		
		# Show terrain analysis
		if advanced_validation.stats.has("terrain_distribution"):
			log_message("Terrain Distribution:")
			var distribution = advanced_validation.stats.terrain_distribution
			for terrain_name in distribution.keys():
				var data = distribution[terrain_name]
				log_message("  - %s: %d tiles (%.1f%%)" % [terrain_name, data.count, data.percentage])
		
		EventBus.emit_map_loaded(map)
	else:
		log_message("Failed to load map from: " + test_map_path)

func _on_editor_ready():
	log_message("Editor ready event received")

func _on_test_all_pressed():
	test_all_button.disabled = true
	status_label.text = "Running all tests..."
	log_message("\n=== Running Full Test Suite ===")
	
	# Capture test output
	var original_print = print
	var test_output = []
	
	# Run tests (they will print to console)
	test_runner.run_all_tests()
	
	test_all_button.disabled = false
	status_label.text = "Tests completed"

func _on_quick_demo_pressed():
	quick_demo_button.disabled = true
	status_label.text = "Running quick demo..."
	log_message("\n=== Quick Demo Starting ===")
	
	test_runner.run_quick_demo()
	
	quick_demo_button.disabled = false
	status_label.text = "Demo completed"

func _on_generate_map_pressed():
	generate_map_button.disabled = true
	status_label.text = "Generating map..."
	log_message("\n=== Map Generation Test ===")
	
	# Generate a test map
	var tileset_ids = AssetManager.get_tileset_ids()
	if tileset_ids.is_empty():
		log_message("Error: No tilesets available for generation")
		generate_map_button.disabled = false
		status_label.text = "Generation failed"
		return
	
	# Create different types of maps
	var presets = ["small_skirmish", "forest_maze", "mountain_pass", "river_crossing"]
	
	for preset_name in presets:
		log_message("Generating " + preset_name + " map...")
		
		var params = MapGenerator.create_preset(preset_name, tileset_ids[0])
		var generated_map = MapGenerator.generate_map(params)
		
		if generated_map:
			log_message("  ✓ Generated %dx%d map" % [generated_map.width, generated_map.height])
			
			# Validate the generated map
			var validation = MapValidator.validate_map(generated_map)
			log_message("  ✓ Validation: " + validation.get_summary())
			
			# Show some statistics
			if validation.stats.has("terrain_distribution"):
				log_message("  ✓ Terrain variety: " + str(validation.stats.terrain_types) + " types")
		else:
			log_message("  ✗ Failed to generate " + preset_name)
	
	generate_map_button.disabled = false
	status_label.text = "Generation completed"

func _on_map_loaded(map: FEMap):
	log_message("Map loaded event received: " + map.name)

func log_message(message: String):
	print(message)
	output_text.text += message + "\n"
	# Auto-scroll to bottom
	await get_tree().process_frame
	output_text.scroll_vertical = output_text.get_v_scroll_bar().max_value
