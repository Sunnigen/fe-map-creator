extends SceneTree

## Simple test runner for AssetManager debugging
## Run this script from the command line: godot --script test_runner.gd

func _init():
	print("🧪 Starting AssetManager Debug Tests")
	
	# Create a GUT instance
	var gut = load("res://addons/gut/gut.gd").new()
	gut.set_log_level(gut.LOG_LEVEL_ALL_ASSERTS)
	gut.set_yield_between_tests(true)
	gut.set_export_path("res://test_results.txt")
	
	# Add our test directory
	gut.add_directory("res://test/unit")
	
	# Run the tests
	gut.test_scripts()
	
	# Wait for tests to complete
	await gut.tests_finished
	
	print("\n📊 Test Results Summary:")
	print("Total Tests: %d" % gut.get_test_count())
	print("Passed: %d" % gut.get_pass_count())
	print("Failed: %d" % gut.get_fail_count())
	print("Errors: %d" % gut.get_error_count())
	
	if gut.get_fail_count() > 0 or gut.get_error_count() > 0:
		print("❌ Some tests failed - check output above for details")
	else:
		print("✅ All tests passed!")
	
	# Exit
	quit()