extends Control

## Test the actual AssetManager XML parsing

func _ready():
	print("\n=== TESTING REAL ASSETMANAGER ===")
	
	# Force initialize AssetManager if not ready
	if not AssetManager.is_ready():
		print("AssetManager not initialized, forcing initialization...")
		AssetManager.initialize("/Users/sunnigen/Godot/projects/fe-map-creator")
		AssetManager.initialization_completed.connect(_on_assetmanager_ready)
	else:
		test_assetmanager_terrain()

func _on_assetmanager_ready():
	test_assetmanager_terrain()

func test_assetmanager_terrain():
	print("\nAssetManager terrain data:")
	
	# Check first few terrains
	for i in range(5):
		var terrain = AssetManager.get_terrain_data(i)
		if terrain:
			print("Terrain %d: '%s' (avoid:%d, def:%d)" % [i, terrain.name, terrain.avoid_bonus, terrain.defense_bonus])
		else:
			print("Terrain %d: NOT FOUND" % i)
	
	# Test direct XML parsing
	print("\n=== TESTING DIRECT XML ACCESS ===")
	test_direct_xml_parsing()

func test_direct_xml_parsing():
	# Load the XML file directly and test parsing
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("❌ ERROR: Could not open XML file")
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("✅ XML loaded, length: ", xml_content.length())
	
	# Test the specific Plains item
	var plains_comment = "<!-- 1: Plains -->"
	var comment_pos = xml_content.find(plains_comment)
	if comment_pos == -1:
		print("❌ Could not find Plains comment")
		return
	
	print("✅ Found Plains comment at: ", comment_pos)
	
	# Find the Item after the comment
	var item_start = xml_content.find("<Item>", comment_pos)
	var item_end = xml_content.find("</Item>", item_start) + 7
	
	if item_start == -1 or item_end == -1:
		print("❌ Could not find Item tags")
		return
	
	var complete_item = xml_content.substr(item_start, item_end - item_start)
	print("✅ Extracted Plains item, length: ", complete_item.length())
	
	# Show raw content around the name
	var n_pos = complete_item.find("<n>")
	if n_pos != -1:
		var surrounding = complete_item.substr(n_pos - 10, 40)
		print("Raw content around <n>: '", surrounding, "'")
		
		# Show hex values
		var name_start = n_pos + 3
		var name_end = complete_item.find("</n>", name_start)
		if name_end != -1:
			var name_content = complete_item.substr(name_start, name_end - name_start)
			print("Name content: '", name_content, "'")
			print("Name length: ", name_content.length())
			
			# Show each character
			for i in range(name_content.length()):
				var char = name_content[i]
				var code = char.unicode_at(0)
				print("  Char %d: '%s' (unicode: %d)" % [i, char, code])
		else:
			print("❌ Could not find </n> tag")
	else:
		print("❌ Could not find <n> tag in item")
		print("First 200 chars of item:")
		print(complete_item.substr(0, 200))
