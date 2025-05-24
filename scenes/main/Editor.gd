## Main Editor Controller
##
## Controls the main Fire Emblem Map Creator interface, coordinating between
## all the UI components and managing the editing workflow.
extends Control

# UI References
@onready var menu_bar: MenuBar = $VBoxContainer/MenuBar
@onready var toolbar: HBoxContainer = $VBoxContainer/ToolBar/HBoxContainer
@onready var tileset_panel: Control = $VBoxContainer/ContentArea/LeftPanel/TilesetPanel
@onready var map_canvas: MapCanvas = $VBoxContainer/ContentArea/CenterPanel/MapCanvas
@onready var terrain_inspector: Control = $VBoxContainer/ContentArea/RightPanel/TerrainInspector
@onready var status_bar: HBoxContainer = $VBoxContainer/StatusBar/HBoxContainer
@onready var status_label: Label = $VBoxContainer/StatusBar/HBoxContainer/StatusLabel
@onready var zoom_label: Label = $VBoxContainer/StatusBar/HBoxContainer/ZoomLabel
@onready var tool_label: Label = $VBoxContainer/StatusBar/HBoxContainer/ToolLabel

# File dialogs
@onready var open_dialog: FileDialog = $OpenDialog
@onready var save_dialog: FileDialog = $SaveDialog

# Tool buttons
var tool_buttons: Dictionary = {}

# Current state
var current_map: FEMap
var current_file_path: String = ""
var is_modified: bool = false
var current_tool: EventBus.EditorTool = EventBus.EditorTool.PAINT

func _ready():
	# Initialize AssetManager first
	var fe_data_path = "/Users/sunnigen/Godot/FEMapCreator"  # You may want to make this configurable
	AssetManager.initialize(fe_data_path)
	
	# Set up UI
	_setup_menu_bar()
	_setup_toolbar()
	_setup_file_dialogs()
	
	# Connect signals
	_connect_signals()
	
	# Update UI state
	_update_ui_state()
	
	# Create a default map to start with
	_create_new_map()
	
	print("FE Map Creator Editor ready!")

func _setup_menu_bar():
	# File menu
	var file_menu = PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("New Map", 0)
	file_menu.add_item("Open Map", 1)
	file_menu.add_separator()
	file_menu.add_item("Save Map", 2)
	file_menu.add_item("Save As...", 3)
	file_menu.add_separator()
	file_menu.add_item("Export to Scene", 4)
	file_menu.add_item("Export to JSON", 5)
	file_menu.add_separator()
	file_menu.add_item("Exit", 6)
	
	file_menu.id_pressed.connect(_on_file_menu_pressed)
	menu_bar.add_child(file_menu)
	
	# Edit menu
	var edit_menu = PopupMenu.new()
	edit_menu.name = "Edit"
	edit_menu.add_item("Undo", 0)
	edit_menu.add_item("Redo", 1)
	edit_menu.add_separator()
	edit_menu.add_item("Copy", 2)
	edit_menu.add_item("Paste", 3)
	edit_menu.add_separator()
	edit_menu.add_item("Fill Map", 4)
	edit_menu.add_item("Clear Map", 5)
	
	edit_menu.id_pressed.connect(_on_edit_menu_pressed)
	menu_bar.add_child(edit_menu)
	
	# View menu
	var view_menu = PopupMenu.new()
	view_menu.name = "View"
	view_menu.add_check_item("Show Grid", 0)
	view_menu.set_item_checked(0, true)
	view_menu.add_separator()
	view_menu.add_item("Zoom In", 1)
	view_menu.add_item("Zoom Out", 2)
	view_menu.add_item("Zoom Reset", 3)
	view_menu.add_separator()
	view_menu.add_item("Center View", 4)
	
	view_menu.id_pressed.connect(_on_view_menu_pressed)
	menu_bar.add_child(view_menu)

func _setup_toolbar():
	# Tool selection buttons
	var tools = [
		{"tool": EventBus.EditorTool.PAINT, "text": "Paint (B)", "icon": null},
		{"tool": EventBus.EditorTool.FILL, "text": "Fill (F)", "icon": null},
		{"tool": EventBus.EditorTool.SELECT, "text": "Select (S)", "icon": null},
		{"tool": EventBus.EditorTool.EYEDROPPER, "text": "Eyedropper (I)", "icon": null}
	]
	
	for tool_data in tools:
		var button = Button.new()
		button.text = tool_data.text
		button.toggle_mode = true
		button.button_group = _get_or_create_tool_button_group()
		
		if tool_data.tool == current_tool:
			button.button_pressed = true
		
		button.pressed.connect(_on_tool_button_pressed.bind(tool_data.tool))
		toolbar.add_child(button)
		tool_buttons[tool_data.tool] = button
	
	# Add separator
	var separator = VSeparator.new()
	toolbar.add_child(separator)
	
	# Grid toggle
	var grid_button = Button.new()
	grid_button.text = "Grid (G)"
	grid_button.toggle_mode = true
	grid_button.button_pressed = true
	grid_button.toggled.connect(_on_grid_toggled)
	toolbar.add_child(grid_button)

func _setup_file_dialogs():
	# Open dialog
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.add_filter("*.map", "Fire Emblem Map Files")
	open_dialog.file_selected.connect(_on_file_selected_for_open)
	
	# Save dialog
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.add_filter("*.map", "Fire Emblem Map Files")
	save_dialog.file_selected.connect(_on_file_selected_for_save)

func _connect_signals():
	# EventBus signals
	EventBus.tool_changed.connect(_on_tool_changed)
	EventBus.zoom_changed.connect(_on_zoom_changed)
	EventBus.map_loaded.connect(_on_map_loaded)
	EventBus.tile_selected.connect(_on_tile_selected)
	
	# Component signals
	map_canvas.tile_painted.connect(_on_tile_painted)
	map_canvas.map_modified.connect(_on_map_modified)
	map_canvas.selection_changed.connect(_on_selection_changed)
	
	tileset_panel.tile_selected.connect(_on_tileset_tile_selected)
	tileset_panel.tileset_changed.connect(_on_tileset_changed)

func _get_or_create_tool_button_group() -> ButtonGroup:
	# Create a button group for tool selection
	var group = ButtonGroup.new()
	return group

## Create a new map
func _create_new_map():
	var map = FEMap.new()
	map.initialize(20, 15, 0)  # 20x15 map filled with tile 0
	map.name = "New Map"
	
	# Use first available tileset
	var tileset_ids = AssetManager.get_tileset_ids()  
	if tileset_ids.size() > 0:
		map.tileset_id = tileset_ids[0]
	
	_load_map(map)

## Load a map into the editor
func _load_map(map: FEMap):
	current_map = map
	current_file_path = ""
	is_modified = false
	
	# Load into components
	map_canvas.load_map(map)
	
	# Update UI
	_update_window_title()
	_update_status("Map loaded: " + map.name)
	
	# Emit global signal
	EventBus.emit_map_loaded(map)

## Save the current map
func _save_map():
	if current_file_path.is_empty():
		_save_map_as()
	else:
		_save_map_to_file(current_file_path)

## Save map with file dialog
func _save_map_as():
	if current_map:
		save_dialog.current_file = current_map.name + ".map"
		save_dialog.popup_centered(Vector2i(800, 600))

## Save map to specific file
func _save_map_to_file(file_path: String):
	if not current_map:
		return
	
	if MapIO.save_map_to_file(current_map, file_path):
		current_file_path = file_path
		is_modified = false
		_update_window_title()
		_update_status("Map saved: " + file_path.get_file())
		Settings.add_recent_file(file_path)
		EventBus.emit_map_saved(current_map, file_path)
	else:
		_update_status("Failed to save map")

## Open a map file
func _open_map():
	open_dialog.current_dir = Settings.get_fe_data_path()
	open_dialog.popup_centered(Vector2i(800, 600))

## Update window title
func _update_window_title():
	var title = "FE Map Creator"
	if current_map:
		title += " - " + current_map.name
		if is_modified:
			title += "*"
	get_window().title = title

## Update status bar
func _update_status(message: String):
	status_label.text = message

## Update UI state
func _update_ui_state():
	# Update tool display
	tool_label.text = "Tool: " + EventBus.get_tool_name(current_tool)
	
	# Update zoom display
	if map_canvas:
		var zoom_info = map_canvas.get_zoom_info()
		zoom_label.text = "Zoom: %.0f%%" % (zoom_info.current * 100)

## Handle keyboard shortcuts
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_B:
				_set_tool(EventBus.EditorTool.PAINT)
			KEY_F:
				_set_tool(EventBus.EditorTool.FILL)
			KEY_S:
				_set_tool(EventBus.EditorTool.SELECT)
			KEY_I:
				_set_tool(EventBus.EditorTool.EYEDROPPER)
			KEY_G:
				EventBus.emit_grid_toggled(not map_canvas.show_grid)

## Set current tool
func _set_tool(tool: EventBus.EditorTool):
	current_tool = tool
	EventBus.emit_tool_changed(tool)

# Event handlers
func _on_file_menu_pressed(id: int):
	match id:
		0: _create_new_map()
		1: _open_map()
		2: _save_map()
		3: _save_map_as()
		4: _export_to_scene()
		5: _export_to_json()
		6: get_tree().quit()

func _on_edit_menu_pressed(id: int):
	match id:
		0: print("Undo - not implemented yet")
		1: print("Redo - not implemented yet") 
		2: print("Copy - not implemented yet")
		3: print("Paste - not implemented yet")
		4: _fill_map()
		5: _clear_map()

func _on_view_menu_pressed(id: int):
	match id:
		0: 
			var view_menu = menu_bar.get_child(2) as PopupMenu
			var is_checked = view_menu.is_item_checked(0)
			view_menu.set_item_checked(0, not is_checked)
			EventBus.emit_grid_toggled(not is_checked)
		1: map_canvas.zoom_in()
		2: map_canvas.zoom_out()
		3: map_canvas.set_zoom(1.0)
		4: map_canvas._center_view()

func _on_tool_button_pressed(tool: EventBus.EditorTool):
	_set_tool(tool)

func _on_grid_toggled(pressed: bool):
	EventBus.emit_grid_toggled(pressed)

func _on_tool_changed(tool: EventBus.EditorTool):
	current_tool = tool
	_update_ui_state()
	
	# Update button states
	for button_tool in tool_buttons:
		var button = tool_buttons[button_tool]
		button.button_pressed = (button_tool == tool)

func _on_zoom_changed(zoom_level: float):
	_update_ui_state()

func _on_map_loaded(map: FEMap):
	_update_status("Map loaded: " + map.name)

func _on_tile_selected(tile_index: int):
	pass  # Handled by individual components

func _on_tile_painted(position: Vector2i, old_tile: int, new_tile: int):
	is_modified = true
	_update_window_title()
	
	# Update terrain inspector for painted tile
	if terrain_inspector and current_map:
		terrain_inspector.display_terrain_info(position, current_map)

func _on_map_modified():
	is_modified = true
	_update_window_title()

func _on_selection_changed(area: Rect2i):
	_update_status("Selection: %dx%d at (%d, %d)" % [area.size.x, area.size.y, area.position.x, area.position.y])

func _on_tileset_tile_selected(tile_index: int):
	pass  # This will be handled by EventBus

func _on_tileset_changed(tileset_id: String):
	pass  # This will be handled by EventBus

func _on_file_selected_for_open(file_path: String):
	var map = MapIO.load_map_from_file(file_path)
	if map:
		_load_map(map)
		current_file_path = file_path
		Settings.add_recent_file(file_path)
	else:
		_update_status("Failed to load map: " + file_path.get_file())

func _on_file_selected_for_save(file_path: String):
	_save_map_to_file(file_path)

## Fill entire map with selected tile
func _fill_map():
	if not current_map:
		return
	
	var selected_tile = map_canvas.get_selected_tile()
	for y in range(current_map.height):
		for x in range(current_map.width):
			current_map.set_tile_at(x, y, selected_tile)
	
	map_canvas._refresh_tilemap()
	is_modified = true
	_update_window_title()
	_update_status("Map filled with tile " + str(selected_tile))

## Clear map (fill with tile 0)
func _clear_map():
	if not current_map:
		return
	
	for y in range(current_map.height):
		for x in range(current_map.width):
			current_map.set_tile_at(x, y, 0)
	
	map_canvas._refresh_tilemap()
	is_modified = true
	_update_window_title()
	_update_status("Map cleared")

## Export to Godot scene
func _export_to_scene():
	if not current_map:
		return
	
	var export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.add_filter("*.tscn", "Godot Scene Files")
	export_dialog.current_file = current_map.name + ".tscn"
	
	export_dialog.file_selected.connect(func(file_path: String):
		if MapIO.export_to_scene(current_map, file_path):
			_update_status("Exported to scene: " + file_path.get_file())
		else:
			_update_status("Failed to export scene")
		export_dialog.queue_free()
	)
	
	add_child(export_dialog)
	export_dialog.popup_centered(Vector2i(800, 600))

## Export to JSON
func _export_to_json():
	if not current_map:
		return
	
	var export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.add_filter("*.json", "JSON Files")
	export_dialog.current_file = current_map.name + ".json"
	
	export_dialog.file_selected.connect(func(file_path: String):
		if MapIO.export_to_json(current_map, file_path):
			_update_status("Exported to JSON: " + file_path.get_file())
		else:
			_update_status("Failed to export JSON")
		export_dialog.queue_free()
	)
	
	add_child(export_dialog)
	export_dialog.popup_centered(Vector2i(800, 600))
