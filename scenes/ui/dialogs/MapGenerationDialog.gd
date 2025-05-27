## Map Generation Dialog
##
## Dialog for configuring procedural map generation with various parameters.
extends AcceptDialog

# UI References
@onready var preset_option: OptionButton = $VBoxContainer/PresetContainer/PresetOption
@onready var algorithm_option: OptionButton = $VBoxContainer/BasicContainer/AlgorithmOption
@onready var theme_option: OptionButton = $VBoxContainer/BasicContainer/ThemeOption
@onready var tileset_option: OptionButton = $VBoxContainer/BasicContainer/TilesetOption
@onready var width_spin: SpinBox = $VBoxContainer/SizeContainer/WidthSpin
@onready var height_spin: SpinBox = $VBoxContainer/SizeContainer/HeightSpin
@onready var seed_spin: SpinBox = $VBoxContainer/SeedContainer/SeedSpin
@onready var complexity_slider: HSlider = $VBoxContainer/ComplexityContainer/ComplexitySlider
@onready var complexity_label: Label = $VBoxContainer/ComplexityContainer/ComplexityLabel
@onready var water_slider: HSlider = $VBoxContainer/TerrainContainer/WaterContainer/WaterSlider
@onready var water_label: Label = $VBoxContainer/TerrainContainer/WaterContainer/WaterLabel
@onready var forest_slider: HSlider = $VBoxContainer/TerrainContainer/ForestContainer/ForestSlider
@onready var forest_label: Label = $VBoxContainer/TerrainContainer/ForestContainer/ForestLabel
@onready var mountain_slider: HSlider = $VBoxContainer/TerrainContainer/MountainContainer/MountainSlider
@onready var mountain_label: Label = $VBoxContainer/TerrainContainer/MountainContainer/MountainLabel
@onready var connectivity_check: CheckBox = $VBoxContainer/OptionsContainer/ConnectivityCheck
@onready var strategic_check: CheckBox = $VBoxContainer/OptionsContainer/StrategicCheck
@onready var border_option: OptionButton = $VBoxContainer/BorderContainer/BorderOption

# Signals
signal map_generation_requested(params: MapGenerator.GenerationParams)

func _ready():
	title = "Generate Map"
	size = Vector2i(450, 600)
	
	# Connect signals
	confirmed.connect(_on_confirmed)
	preset_option.item_selected.connect(_on_preset_selected)
	complexity_slider.value_changed.connect(_on_complexity_changed)
	water_slider.value_changed.connect(_on_water_changed)
	forest_slider.value_changed.connect(_on_forest_changed)
	mountain_slider.value_changed.connect(_on_mountain_changed)
	
	# Set up controls
	_setup_controls()
	_populate_options()
	_apply_default_preset()

## Set up control ranges and values
func _setup_controls():
	# Size controls
	width_spin.min_value = 10
	width_spin.max_value = 100
	width_spin.value = 20
	
	height_spin.min_value = 8
	height_spin.max_value = 100
	height_spin.value = 15
	
	# Seed control
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = randi() % 999999 + 1
	
	# Sliders
	complexity_slider.min_value = 0.0
	complexity_slider.max_value = 1.0
	complexity_slider.step = 0.1
	complexity_slider.value = 0.5
	
	water_slider.min_value = 0.0
	water_slider.max_value = 0.5
	water_slider.step = 0.05
	water_slider.value = 0.1
	
	forest_slider.min_value = 0.0
	forest_slider.max_value = 0.6
	forest_slider.step = 0.05
	forest_slider.value = 0.25
	
	mountain_slider.min_value = 0.0
	mountain_slider.max_value = 0.5
	mountain_slider.step = 0.05
	mountain_slider.value = 0.15
	
	# Update labels
	_update_slider_labels()

## Populate dropdown options
func _populate_options():
	# Presets
	preset_option.add_item("Custom")
	preset_option.add_item("Small Skirmish")
	preset_option.add_item("Large Battle")
	preset_option.add_item("Forest Maze")
	preset_option.add_item("Mountain Pass")
	preset_option.add_item("River Crossing")
	
	# Algorithms
	algorithm_option.add_item("Random")
	algorithm_option.add_item("Perlin Noise")
	algorithm_option.add_item("Cellular Automata")
	algorithm_option.add_item("Strategic Placement")
	algorithm_option.select(1)  # Default to Perlin Noise
	
	# Themes
	theme_option.add_item("Plains")
	theme_option.add_item("Forest")
	theme_option.add_item("Mountain")
	theme_option.add_item("Desert")
	theme_option.add_item("Castle")
	theme_option.add_item("Village")
	theme_option.add_item("Mixed")
	
	# Borders
	border_option.add_item("Natural")
	border_option.add_item("Walls")
	border_option.add_item("Water")
	border_option.add_item("None")
	
	# Tilesets
	_populate_tilesets()

## Populate tileset options
func _populate_tilesets():
	tileset_option.clear()
	
	if not AssetManager.is_ready():
		print("AssetManager not ready - adding placeholder")
		tileset_option.add_item("(AssetManager not initialized)")
		tileset_option.disabled = true
		return
	
	var tileset_ids = AssetManager.get_tileset_ids()
	print("Found %d tilesets: %s" % [tileset_ids.size(), str(tileset_ids)])
	
	if tileset_ids.is_empty():
		tileset_option.add_item("(No tilesets found)")
		tileset_option.disabled = true
		return
	
	tileset_option.disabled = false
	for tileset_id in tileset_ids:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		var display_name = tileset_id
		
		if tileset_data and tileset_data.name:
			display_name = "%s - %s" % [tileset_id, tileset_data.name]
		
		tileset_option.add_item(display_name)
		tileset_option.set_item_metadata(tileset_option.get_item_count() - 1, tileset_id)
	
	# Select first tileset by default
	if tileset_option.get_item_count() > 0:
		tileset_option.select(0)

## Apply default preset
func _apply_default_preset():
	preset_option.select(1)  # Small Skirmish
	_apply_preset("small_skirmish")

## Show generation dialog
func show_generation_dialog():
	# Refresh tileset list in case AssetManager was initialized since dialog creation
	_populate_tilesets()
	
	# Randomize seed
	seed_spin.value = randi() % 999999 + 1
	popup_centered()

## Handle preset selection
func _on_preset_selected(index: int):
	if index == 0:  # Custom
		return
	
	var preset_names = ["", "small_skirmish", "large_battle", "forest_maze", "mountain_pass", "river_crossing"]
	if index < preset_names.size():
		_apply_preset(preset_names[index])

## Apply preset values
func _apply_preset(preset_name: String):
	match preset_name:
		"small_skirmish":
			width_spin.value = 15
			height_spin.value = 12
			algorithm_option.select(3)  # Strategic Placement
			theme_option.select(0)      # Plains
			complexity_slider.value = 0.3
			water_slider.value = 0.05
			forest_slider.value = 0.2
			mountain_slider.value = 0.1
		
		"large_battle":
			width_spin.value = 30
			height_spin.value = 20
			algorithm_option.select(1)  # Perlin Noise
			theme_option.select(6)      # Mixed
			complexity_slider.value = 0.7
			water_slider.value = 0.15
			forest_slider.value = 0.3
			mountain_slider.value = 0.2
		
		"forest_maze":
			width_spin.value = 20
			height_spin.value = 15
			algorithm_option.select(2)  # Cellular Automata
			theme_option.select(1)      # Forest
			complexity_slider.value = 0.8
			water_slider.value = 0.05
			forest_slider.value = 0.6
			mountain_slider.value = 0.05
		
		"mountain_pass":
			width_spin.value = 25
			height_spin.value = 15
			algorithm_option.select(3)  # Strategic Placement
			theme_option.select(2)      # Mountain
			complexity_slider.value = 0.5
			water_slider.value = 0.1
			forest_slider.value = 0.15
			mountain_slider.value = 0.4
		
		"river_crossing":
			width_spin.value = 20
			height_spin.value = 15
			algorithm_option.select(3)  # Strategic Placement
			theme_option.select(0)      # Plains
			complexity_slider.value = 0.4
			water_slider.value = 0.3
			forest_slider.value = 0.2
			mountain_slider.value = 0.1
	
	_update_slider_labels()

## Update slider labels with current values
func _update_slider_labels():
	complexity_label.text = "Complexity: %.1f" % complexity_slider.value
	water_label.text = "Water: %.0f%%" % (water_slider.value * 100)
	forest_label.text = "Forest: %.0f%%" % (forest_slider.value * 100)
	mountain_label.text = "Mountain: %.0f%%" % (mountain_slider.value * 100)

## Slider change handlers
func _on_complexity_changed(value: float):
	complexity_label.text = "Complexity: %.1f" % value

func _on_water_changed(value: float):
	water_label.text = "Water: %.0f%%" % (value * 100)

func _on_forest_changed(value: float):
	forest_label.text = "Forest: %.0f%%" % (value * 100)

func _on_mountain_changed(value: float):
	mountain_label.text = "Mountain: %.0f%%" % (value * 100)

## Handle confirmation
func _on_confirmed():
	var params = MapGenerator.GenerationParams.new()
	
	# Basic parameters
	params.width = int(width_spin.value)
	params.height = int(height_spin.value)
	params.seed_value = int(seed_spin.value)
	
	# Get selected tileset
	var selected_tileset_index = tileset_option.selected
	if selected_tileset_index >= 0 and not tileset_option.disabled:
		var tileset_id = tileset_option.get_item_metadata(selected_tileset_index)
		if tileset_id != null:
			params.tileset_id = tileset_id
		else:
			# Fallback: use first available tileset
			var tileset_ids = AssetManager.get_tileset_ids()
			if tileset_ids.size() > 0:
				params.tileset_id = tileset_ids[0]
			else:
				push_error("No tilesets available for map generation")
				return
	else:
		# No selection or disabled dropdown - use first available tileset
		var tileset_ids = AssetManager.get_tileset_ids()
		if tileset_ids.size() > 0:
			params.tileset_id = tileset_ids[0]
		else:
			push_error("No tilesets available for map generation")
			return
	
	# Algorithm
	match algorithm_option.selected:
		0: params.algorithm = MapGenerator.Algorithm.RANDOM
		1: params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
		2: params.algorithm = MapGenerator.Algorithm.CELLULAR_AUTOMATA
		3: params.algorithm = MapGenerator.Algorithm.STRATEGIC_PLACEMENT
		_: params.algorithm = MapGenerator.Algorithm.PERLIN_NOISE
	
	# Theme
	match theme_option.selected:
		0: params.map_theme = MapGenerator.MapTheme.PLAINS
		1: params.map_theme = MapGenerator.MapTheme.FOREST
		2: params.map_theme = MapGenerator.MapTheme.MOUNTAIN
		3: params.map_theme = MapGenerator.MapTheme.DESERT
		4: params.map_theme = MapGenerator.MapTheme.CASTLE
		5: params.map_theme = MapGenerator.MapTheme.VILLAGE
		6: params.map_theme = MapGenerator.MapTheme.MIXED
		_: params.map_theme = MapGenerator.MapTheme.PLAINS
	
	# Terrain ratios
	params.complexity = complexity_slider.value
	params.water_ratio = water_slider.value
	params.forest_ratio = forest_slider.value
	params.mountain_ratio = mountain_slider.value
	params.defensive_terrain_ratio = 0.3  # Fixed for now
	
	# Options
	params.ensure_connectivity = connectivity_check.button_pressed
	params.add_strategic_features = strategic_check.button_pressed
	
	# Border type
	match border_option.selected:
		0: params.border_type = "natural"
		1: params.border_type = "walls"
		2: params.border_type = "water"
		3: params.border_type = "none"
		_: params.border_type = "natural"
	
	# Final validation
	if params.tileset_id.is_empty():
		push_error("Cannot generate map: no valid tileset selected")
		return
	
	print("Generating map with tileset: %s, algorithm: %s, theme: %s" % [params.tileset_id, params.algorithm, params.map_theme])
	
	# Emit signal
	map_generation_requested.emit(params)
