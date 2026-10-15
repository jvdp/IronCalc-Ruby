require "minitest/autorun"
require "ironcalc"
require_relative "models_helper"

# The recursion limits of the raw Model's evaluation.
class EvaluationLimitsTest < Minitest::Test
  include ModelsHelper

  def test_max_evaluation_depth_round_trip
    model.set_max_evaluation_depth(10)
    assert_equal 10, model.get_max_evaluation_depth
  end

  def test_max_evaluation_depth_is_at_least_one
    model.set_max_evaluation_depth(0)
    assert_equal 1, model.get_max_evaluation_depth
  end

  def test_max_evaluation_stack_round_trip
    model.set_max_evaluation_stack(65_536)
    assert_equal 65_536, model.get_max_evaluation_stack
  end

  def test_negative_limit_raises
    assert_raises(RangeError) { model.set_max_evaluation_depth(-1) }
    assert_raises(RangeError) { model.set_max_evaluation_stack(-1) }
  end

  def test_limits_do_not_change_results
    model.set_max_evaluation_depth(1)
    model.set_max_evaluation_stack(0)
    model.set_user_input(0, 1, 1, "1")
    (2..500).each { |row| model.set_user_input(0, row, 1, "=A#{row - 1}+1") }
    model.evaluate
    assert_equal 500.0, model.get_cell_value_by_index(0, 500, 1)
  end
end
