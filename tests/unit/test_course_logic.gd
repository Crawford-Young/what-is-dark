extends GutTest

var course: CourseLogic


func before_each() -> void:
	course = CourseLogic.new([0.0, 25.0, 50.0, 75.0] as Array[float])


func test_nearest_passed_marker() -> void:
	assert_eq(course.nearest_passed_marker(60.0), 2)
	assert_eq(course.nearest_passed_marker(25.0), 1, "exactly on a marker counts as passed")
	assert_eq(course.nearest_passed_marker(-5.0), -1, "before the course")


func test_setback_index_goes_back_n_markers() -> void:
	assert_eq(course.setback_index(60.0, 1), 1)
	assert_eq(course.setback_index(60.0, 2), 0)


func test_setback_index_clamps_at_zero() -> void:
	assert_eq(course.setback_index(10.0, 3), 0)
	assert_eq(course.setback_index(-5.0, 1), 0)
