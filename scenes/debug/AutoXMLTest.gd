extends Control

## Auto-running XML debug test

func _ready():
	print("=== AUTO XML PARSING DEBUG ===")
	
	# Test the extract function first with simple cases
	test_extract_function()
	
	# Test with actual XML file
	test_actual_xml_parsing()

func test_extract_function():
	print("\n=== TESTING _extract_xml_value FUNCTION ===")
	
	var test_cases = [
		["<n>Plains</n>", "n", "Plains"],
		["<Key>1</Key>", "Key", "1"],
		["<Avoid>20</Avoid>", "Avoid", "20"],
		["  <n>Forest</n>  ", "n", "Forest"],
		["<n>Multi Word Name</n>", "n", "Multi Word Name"]
	]
	
	for test_case in test_cases:
		var xml = test_case[0]
		var tag = test_case[1] 
		var expected = test_case[2]
		
		var result = _extract_xml_value(xml, tag)
		var status = "✅ PASS" if result == expected else "❌ FAIL"
		print("%s: _extract_xml_value('%s', '%s') = '%s' (expected: '%s')" % [status, xml, tag, result, expected])

func test_actual_xml_parsing():
	print("\n=== TESTING ACTUAL XML FILE ===")
	
	# Load the XML file
	var xml_path = "/Users/sunnigen/Godot/projects/fe-map-creator/Terrain_Data.xml"
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		print("❌ ERROR: Could not open XML file: ", xml_path)
		return
	
	var xml_content = file.get_as_text()
	file.close()
	
	print("✅ XML file loaded, length: ", xml_content.length())
	
	# Test the first Item manually (Plains)
	test_plains_item(xml_content)

func test_plains_item(xml_content: String):
	print("\n=== TESTING PLAINS ITEM (ID=1) ===")
	
	# Find the Plains item specifically
	var plains_start = xml_content.find("<!-- 1: Plains -->")
	if plains_start == -1:
		print("❌ Could not find Plains comment")
		return
	
	print("✅ Found Plains comment at position: ", plains_start)
	
	# Find the <Item> tag after the comment
	var item_start = xml_content.find("<Item>", plains_start)
	if item_start == -1:
		print("❌ Could not find <Item> tag after Plains comment")
		return
	
	print("✅ Found <Item> tag at position: ", item_start)
	
	# Find the matching closing tag
	var item_end = find_matching_closing_tag(xml_content, item_start, "<Item>", "</Item>")
	if item_end == -1:
		print("❌ Could not find matching </Item> tag")
		return
	
	print("✅ Found matching </Item> at position: ", item_end)
	
	# Extract the complete item
	var complete_item = xml_content.substr(item_start, item_end - item_start + 7)
	print("✅ Extracted complete item, length: ", complete_item.length())
	
	# Test key extraction
	var key = _extract_xml_value(complete_item, "Key")
	print("Key extracted: '", key, "' (should be '1')")
	
	# Find Value section
	var value_start = complete_item.find("<Value>")
	var value_end = find_matching_closing_tag(complete_item, value_start, "<Value>", "</Value>")
	
	if value_start == -1 or value_end == -1:
		print("❌ Could not find Value section")
		return
	
	var value_section = complete_item.substr(value_start, value_end - value_start + 8)
	print("✅ Extracted Value section, length: ", value_section.length())
	
	# Show the first part of the Value section
	var preview = value_section.substr(0, min(150, value_section.length()))
	print("Value section preview: ", preview, "...")
	
	# Test name extraction
	var name = _extract_xml_value(value_section, "n")
	print("Name extracted: '", name, "' (should be 'Plains')")
	
	# Test other fields
	var id = _extract_xml_value(value_section, "Id")
	var avoid = _extract_xml_value(value_section, "Avoid")
	var def_val = _extract_xml_value(value_section, "Def")
	
	print("Id: '", id, "' (should be '1')")
	print("Avoid: '", avoid, "' (should be '0')")
	print("Def: '", def_val, "' (should be '0')")
	
	# Check if the extraction is working
	if name == "Plains":
		print("🎉 SUCCESS: Name extraction working correctly!")
	else:
		print("💥 PROBLEM: Name extraction failed - investigating...")
		debug_name_extraction(value_section)

func debug_name_extraction(value_section: String):
	print("\n=== DEBUGGING NAME EXTRACTION ===")
	
	# Look for <n> tag manually
	var n_start = value_section.find("<n>")
	var n_end = value_section.find("</n>")
	
	print("Manual search for <n>: start=", n_start, ", end=", n_end)
	
	if n_start != -1 and n_end != -1:
		var manual_extract = value_section.substr(n_start + 3, n_end - n_start - 3)
		print("Manual extraction: '", manual_extract, "'")
		print("After strip_edges(): '", manual_extract.strip_edges(), "'")
	
	# Check what _extract_xml_value is actually doing
	print("\nStep-by-step _extract_xml_value debug:")
	var start_tag = "<n>"
	var end_tag = "</n>"
	
	var start_index = value_section.find(start_tag)
	print("start_index (", start_tag, "): ", start_index)
	
	if start_index != -1:
		start_index += start_tag.length()
		print("start_index after tag length: ", start_index)
		
		var end_index = value_section.find(end_tag, start_index)
		print("end_index (", end_tag, "): ", end_index)
		
		if end_index != -1:
			var raw_result = value_section.substr(start_index, end_index - start_index)
			print("raw_result: '", raw_result, "'")
			print("raw_result.strip_edges(): '", raw_result.strip_edges(), "'")

## Copy of AssetManager functions
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
