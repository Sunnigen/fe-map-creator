## Tileset Panel
##
## UI panel containing tileset viewer with search, filtering, and selection features.
extends Control

# UI References
@onready var tileset_selector: OptionButton = $VBoxContainer/HeaderContainer/TilesetSelector
@onready var search_box: LineEdit = $VBoxContainer/HeaderContainer/ControlsContainer/SearchBox
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var tileset_viewer: TilesetViewer = $VBoxContainer/ScrollContainer/TilesetViewer
@onready var tile_info_label: Label = $VBoxContainer/FooterContainer/TileInfoLabel
@onready var filter_button: Button = $VBoxContainer/HeaderContainer/ControlsContainer/FilterButton

# State
var current_tileset_id: String = ""
var available_tilesets: Array[String] = []
var search_filter: String = ""
var terrain_filter: int = -1  # -1 = no filter

# Signals
signal tile_selected(tile_index: int)
signal tileset_changed(tileset_id: String)

func _ready():
	# Connect UI signals
	tileset_selector.item_selected.connect(_on_tileset_selected)
	search_box.text_changed.connect(_on_search_changed)
	filter_button.pressed.connect(_on_filter_pressed)
	
	# Connect tileset viewer signals
	tileset_viewer.tile_clicked.connect(_on_tile_clicked)
	tileset_viewer.tile_hovered.connect(_on_tile_hovered)
	
	# Connect to EventBus
	EventBus.tileset_changed.connect(_on_global_tileset_changed)
	EventBus.tile_selected.connect(_on_global_tile_selected)
	
	# Connect to AssetManager initialization signal
	AssetManager.initialization_completed.connect(_on_asset_manager_ready)
	
	# Try to populate immediately if already ready, otherwise wait for signal
	if AssetManager.is_ready():
		_populate_tileset_selector()

func _on_asset_manager_ready():
	# Called when AssetManager finishes initialization
	_populate_tileset_selector()

## Populate the tileset selector with available tilesets
func _populate_tileset_selector():
	tileset_selector.clear()
	
	if not AssetManager.is_ready():
		tileset_selector.add_item("(AssetManager not initialized)")
		tileset_selector.disabled = true
		return
	
	available_tilesets = AssetManager.get_tileset_ids()
	
	if available_tilesets.is_empty():
		tileset_selector.add_item("(No tilesets available)")
		tileset_selector.disabled = true
		return
	
	tileset_selector.disabled = false
	for tileset_id in available_tilesets:
		var tileset_data = AssetManager.get_tileset_data(tileset_id)
		var display_name = tileset_id
		
		if tileset_data:
			display_name = "%s - %s" % [tileset_id, tileset_data.name]
		
		tileset_selector.add_item(display_name)
	
	# Select first tileset by default
	if available_tilesets.size() > 0:
		_load_tileset(available_tilesets[0])

## Load a specific tileset
func _load_tileset(tileset_id: String):
	current_tileset_id = tileset_id
	var tileset_data = AssetManager.get_tileset_data(tileset_id)
	
	if not tileset_data:
		push_error("Could not load tileset: " + tileset_id)
		return
	
	# Display in viewer
	tileset_viewer.display_tileset(tileset_data)
	
	# Update UI
	_update_tile_info(-1)  # Clear tile info
	
	# Apply current filters
	_apply_filters()
	
	print("Loaded tileset: ", tileset_data.name)

## Apply current search and filter criteria
func _apply_filters():
	# For now, we'll implement basic search
	# Advanced filtering could be added later
	pass

## Get currently selected tileset ID
func get_current_tileset_id() -> String:
	return current_tileset_id

## Set selected tile
func set_selected_tile(tile_index: int):
	tileset_viewer.set_selected_tile(tile_index)
	_update_tile_info(tile_index)

## Get selected tile
func get_selected_tile() -> int:
	return tileset_viewer.get_selected_tile()

## Update tile information display
func _update_tile_info(tile_index: int):
	if tile_index < 0:
		tile_info_label.text = "No tile selected"
		return
	
	var tile_info = tileset_viewer.get_tile_info(tile_index)
	var info_parts: Array[String] = []
	
	info_parts.append("Tile: %d" % tile_index)
	info_parts.append("(%d, %d)" % [tile_info.atlas_coords.x, tile_info.atlas_coords.y])
	info_parts.append("Terrain: %s" % tile_info.terrain_name)
	
	if tile_info.animated:
		info_parts.append("Animated")
	
	# Add terrain stats if available
	var terrain_data = AssetManager.get_terrain_data(tile_info.terrain_type)
	if terrain_data:
		var stats = terrain_data.get_stats_string()
		if stats != "No bonuses":
			info_parts.append(stats)
	
	tile_info_label.text = " | ".join(info_parts)

## Show filter dialog
func _show_filter_dialog():
	# This would open a dialog for advanced filtering
	# For now, just show available terrain types
	print("Filter options would go here")

# Event handlers
func _on_tileset_selected(index: int):
	if index >= 0 and index < available_tilesets.size():
		var tileset_id = available_tilesets[index]
		_load_tileset(tileset_id)
		tileset_changed.emit(tileset_id)
		EventBus.emit_tileset_changed(tileset_id)

func _on_search_changed(text: String):
	search_filter = text
	_apply_filters()

func _on_filter_pressed():
	_show_filter_dialog() 

func _on_tile_clicked(tile_index: int):
	_update_tile_info(tile_index)
	tile_selected.emit(tile_index)
	EventBus.emit_tile_selected(tile_index)

func _on_tile_hovered(tile_index: int):
	if tile_index >= 0:
		_update_tile_info(tile_index)

func _on_global_tileset_changed(tileset_id: String):
	# Respond to external tileset changes
	if tileset_id != current_tileset_id:
		_load_tileset(tileset_id)
		
		# Update selector
		var index = available_tilesets.find(tileset_id)
		if index >= 0:
			tileset_selector.select(index)

func _on_global_tile_selected(tile_index: int):
	# Respond to external tile selection
	if tileset_viewer.get_selected_tile() != tile_index:
		tileset_viewer.set_selected_tile(tile_index)
		_update_tile_info(tile_index)

## Get terrain types used in current tileset
func get_terrain_types() -> Array[int]:
	if not current_tileset_id:
		return []
	
	var tileset_data = AssetManager.get_tileset_data(current_tileset_id)
	if not tileset_data:
		return []
	
	var terrain_types: Array[int] = []
	var used_types = {}
	
	for terrain_id in tileset_data.terrain_tags:
		if not terrain_id in used_types:
			terrain_types.append(terrain_id)
			used_types[terrain_id] = true
	
	terrain_types.sort()
	return terrain_types

## Get animated tiles in current tileset
func get_animated_tiles() -> Array[int]:
	return tileset_viewer.get_animated_tiles()

## Scroll to show a specific tile
func scroll_to_tile(tile_index: int):
	tileset_viewer.scroll_to_tile(tile_index)

## Get current tileset stats
func get_tileset_stats() -> Dictionary:
	return tileset_viewer.get_tileset_stats()
