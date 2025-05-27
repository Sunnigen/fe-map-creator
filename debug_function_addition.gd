
# Add this function to the Main.gd file after the existing functions

func _test_tilemap_rendering(map: FEMap, tileset_data: FETilesetData):
	log_message("    → Creating test TileMap...")
	
	# Create a test scene with TileMap
	var test_scene = Node2D.new()
	var tilemap = TileMap.new()
	
	# Set up the tilemap
	tilemap.tile_set = tileset_data.tileset_resource
	test_scene.add_child(tilemap)
	
	log_message("    → TileMap created with TileSet: %s" % (tilemap.tile_set != null))
	
	if tilemap.tile_set:
		# Set a few test tiles
		var tiles_set = 0
		for y in range(min(3, map.height)):
			for x in range(min(3, map.width)):
				var tile_index = map.get_tile_at(x, y)
				var atlas_coords = Vector2i(tile_index % 32, tile_index / 32)
				tilemap.set_cell(0, Vector2i(x, y), 0, atlas_coords)
				tiles_set += 1
		
		log_message("    → Attempted to set %d tiles" % tiles_set)
		
		# Check if cells were actually set
		var used_cells = tilemap.get_used_cells(0)
		log_message("    → TileMap reports %d used cells" % used_cells.size())
		
		if used_cells.size() > 0:
			log_message("    ✓ TileMap rendering working - cells were set!")
			var sample_cell = used_cells[0]
			var source_id = tilemap.get_cell_source_id(0, sample_cell)
			var atlas_coords = tilemap.get_cell_atlas_coords(0, sample_cell)
			log_message("    → Sample cell %s: source=%d, atlas=%s" % [sample_cell, source_id, atlas_coords])
		else:
			log_message("    ✗ TileMap rendering FAILED - no cells were set!")
			
			# Try to diagnose why
			if not tilemap.tile_set:
				log_message("      → Reason: TileSet is null")
			elif tilemap.tile_set.get_source_count() == 0:
				log_message("      → Reason: TileSet has no sources")
			else:
				log_message("      → Reason: Unknown - TileSet appears valid")
	else:
		log_message("    ✗ TileSet assignment failed!")
	
	# Clean up
	test_scene.queue_free()
