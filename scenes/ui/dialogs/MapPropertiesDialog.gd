## Map Properties Dialog
##
## Dialog for editing map properties like name, description, dimensions, and tileset.
extends AcceptDialog

# UI References
@onready var name_edit: LineEdit = $VBoxContainer/GridContainer/NameEdit
@onready var description_edit: TextEdit = $VBoxContainer/GridContainer/DescriptionEdit
@onready var width_spin: SpinBox = $VBoxContainer/GridContainer/WidthSpin
@onready var height_spin: SpinBox = $VBoxContainer/GridContainer/HeightSpin
@onready var tileset_option: OptionButton = $VBoxContainer/GridContainer/TilesetOption
@onready var preserve_data_check: CheckBox = $VBoxContainer/PreserveDataCheck

# Current map
var current_map: FEMap

# Signals
signal map_properties_changed(map: FEMap, resize_needed: bool)

func _ready():
	title = "Map Properties"
	size = Vector2i(400, 300)
	
	# Set up spinboxes
	width_spin.min_value = 5
	width_spin.max_value = 100
	width_spin.step = 1
	
	height_spin.min_value = 5
	height_spin.max_value = 100
	height_spin.step = 1
	
	# Connect signals
	confirmed.connect(_on_confirmed)
	
	# Populate tilesets
	_populate_tilesets()

## Show dialog for editing map properties
func edit_map_properties(map: FEMap):
	if not map:
		return
	
	current_map = map
	
	# Populate fields
	name_edit.text = map.name
	description_edit.text = map.description
	width_spin.value = map.width
	height_spin.value = map.height
	
	# Select current tileset
	_select_tileset(map.tileset_id)
	
	# Show dialog
	popup_centered()

## Populate tileset dropdown
func _populate_tilesets():
	tileset_option.clear()
	
	if not AssetManager.is_ready():
		tileset_option.add_item("(No tilesets available)")
		tileset_option.disabled = true
		return
	
	var tileset_ids = AssetManager.get_tileset_ids()
	for tileset_id in tileset_ids:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		var display_name = tileset_id
		
		if tileset_data:
			display_name = "%s - %s" % [tileset_id, tileset_data.name]
		
		tileset_option.add_item(display_name)
		tileset_option.set_item_metadata(tileset_option.get_item_count() - 1, tileset_id)

## Select tileset in dropdown
func _select_tileset(tileset_id: String):
	for i in range(tileset_option.get_item_count()):
		var item_tileset_id = tileset_option.get_item_metadata(i)
		if item_tileset_id == tileset_id:
			tileset_option.select(i)
			break

## Handle confirmation
func _on_confirmed():
	if not current_map:
		return
	
	var resize_needed = false
	
	# Update basic properties
	current_map.name = name_edit.text
	current_map.description = description_edit.text
	
	# Check if tileset changed
	var selected_index = tileset_option.selected
	if selected_index >= 0:
		var new_tileset_id = tileset_option.get_item_metadata(selected_index)
		if new_tileset_id != current_map.tileset_id:
			current_map.tileset_id = new_tileset_id
	
	# Check if resize is needed
	var new_width = int(width_spin.value)
	var new_height = int(height_spin.value)
	
	if new_width != current_map.width or new_height != current_map.height:
		current_map.resize(new_width, new_height, preserve_data_check.button_pressed)
		resize_needed = true
	
	# Emit signal
	map_properties_changed.emit(current_map, resize_needed)
