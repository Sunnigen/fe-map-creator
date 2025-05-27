extends Control

## Debug script to test XML parsing step by step

func _on_test_button_pressed():
	print("=== XML PARSING DEBUG ===")
	
	# Load the XML file directly
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open XML file: ", xml_path)
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("XML file loaded, length: ", xml_content.length())
	
	# Test finding the first few Items
	test_basic_item_parsing(xml_content)

func test_basic_item_parsing(xml_content: String):
	print("\n=== TESTING BASIC ITEM PARSING ===")
	
	var clean_xml = xml_content.replace("\r", "")
	var search_pos = 0
	var item_count = 0
	
	while item_count < 3:  # Only test first 3 items
		# Find the start of the next <Item> block
		var item_start = clean_xml.find("<Item>", search_pos)
		if item_start == -1:
			print("No more <Item> tags found")
			break
		
		print("\nFound <Item> at position: ", item_start)
		
		# Find the matching closing tag
		var item_end = find_matching_closing_tag(clean_xml, item_start, "<Item>", "</Item>")
		if item_end == -1:
			print("ERROR: No matching </Item> found")
			break
		
		print("Found matching </Item> at position: ", item_end)
		
		# Extract the complete item block
		var complete_item = clean_xml.substr(item_start, item_end - item_start + 7)
		print("Item length: ", complete_item.length())
		
		# Show first 200 characters of the item
		var preview = complete_item.substr(0, min(200, complete_item.length()))
		print("Item preview: ", preview, "...")
		
		# Test key extraction
		var key_match = _extract_xml_value(complete_item, "Key")
		print("Extracted Key: '", key_match, "'")
		
		# Find Value section
		var value_start = complete_item.find("<Value>")
		var value_end = find_matching_closing_tag(complete_item, value_start, "<Value>", "</Value>")
		
		if value_start != -1 and value_end != -1:
			var value_section = complete_item.substr(value_start, value_end - value_start + 8)
			print("Value section found, length: ", value_section.length())
			
			# Test name extraction from Value section
			var name_match = _extract_xml_value(value_section, "n")
			print("Extracted name: '", name_match, "'")
			
			# Show first part of Value section for debugging
			var value_preview = value_section.substr(0, min(300, value_section.length()))
			print("Value section preview: ", value_preview, "...")
		else:
			print("ERROR: Could not find Value section")
		
		item_count += 1
		search_pos = item_end + 7

func _on_test_extract_button_pressed():
	print("\n=== TESTING _extract_xml_value FUNCTION ===")
	
	# Test with simple known XML strings
	var test_cases = [
		"<n>Plains</n>",
		"<Key>1</Key>",
		"<Avoid>20</Avoid>",
		"  <n>Forest</n>  ",  # With whitespace
		"<something><n>Nested</n></something>",
		"<n>Multi Word Name</n>"
	]
	
	for test_xml in test_cases:
		print("\nTesting: ", test_xml)
		var result = _extract_xml_value(test_xml, "n")
		print("Result for 'n': '", result, "'")
		
		if test_xml.contains("Key"):
			var key_result = _extract_xml_value(test_xml, "Key")
			print("Result for 'Key': '", key_result, "'")
		
		if test_xml.contains("Avoid"):
			var avoid_result = _extract_xml_value(test_xml, "Avoid")
			print("Result for 'Avoid': '", avoid_result, "'")

func _on_test_single_item_button_pressed():
	print("\n=== TESTING SINGLE ITEM PARSE ===")
	
	# Test with a known good item from the XML
	var test_item = """<Item>
      <Key>1</Key>
      <Value>
        <Id>1</Id>
        <n>Plains</n>
        <Avoid>0</Avoid>
        <Def>0</Def>
        <Res>0</Res>
        <Stats_Visible>true</Stats_Visible>
        <Step_Sound_Group>0</Step_Sound_Group>
        <Platform_Rename></Platform_Rename>
        <Background_Rename></Background_Rename>
        <Dust_Type>0</Dust_Type>
        <Fire_Through>true</Fire_Through>
        <Move_Costs>
          <Item>1 1 1 1 1</Item>
          <Item>2 2 2 3 2</Item>
          <Item>1 1 1 1 1</Item>
        </Move_Costs>
        <Heal Null="true" />
        <Minimap>1</Minimap>
        <Minimap_Group />
      </Value>
    </Item>"""
	
	print("Testing with known good item...")
	
	# Extract Key
	var key = _extract_xml_value(test_item, "Key")
	print("Key: '", key, "'")
	
	# Find Value section
	var value_start = test_item.find("<Value>")
	var value_end = find_matching_closing_tag(test_item, value_start, "<Value>", "</Value>")
	
	if value_start != -1 and value_end != -1:
		var value_section = test_item.substr(value_start, value_end - value_start + 8)
		print("Value section extracted successfully")
		
		# Test all extractions
		var id = _extract_xml_value(value_section, "Id")
		var name = _extract_xml_value(value_section, "n")
		var avoid = _extract_xml_value(value_section, "Avoid")
		var def_val = _extract_xml_value(value_section, "Def")
		
		print("Id: '", id, "'")
		print("Name: '", name, "'")
		print("Avoid: '", avoid, "'")
		print("Def: '", def_val, "'")
	else:
		print("ERROR: Could not extract Value section")

## Copy of AssetManager functions for testing
func find_matching_closing_tag(text: String, start_pos: int, open_tag: String, close_tag: String) -> int:
	var pos = start_pos + open_tag.length()
	var nesting_level = 1
	
	while nesting_level > 0 and pos < text.length():
		var next_open = text.find(open_tag, pos)
		var next_close = text.find(close_tag, pos)
		
		if next_close == -1:
			return -1
		
		if next_open != -1 and next_open < next_close:
			nesting_level += 1
			pos = next_open + open_tag.length()
		else:
			nesting_level -= 1
			if nesting_level == 0:
				return next_close
			pos = next_close + close_tag.length()
	
	return -1

func _extract_xml_value(xml_text: String, tag: String) -> String:
	var start_tag = "<" + tag + ">"
	var end_tag = "</" + tag + ">"
	
	var start_index = xml_text.find(start_tag)
	if start_index == -1:
		return ""
	
	start_index += start_tag.length()
	var end_index = xml_text.find(end_tag, start_index)
	if end_index == -1:
		return ""
	
	var result = xml_text.substr(start_index, end_index - start_index).strip_edges()
	return result
