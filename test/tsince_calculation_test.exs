defmodule TsinceCalculationTest do
  @moduledoc """
  Test that our tsince calculation matches python-sgp4's pure Python implementation
  """

  use ExUnit.Case

  # Depends on NIFs not yet implemented in the current build.
  # Run with: mix test --include pending_nif
  @moduletag :pending_nif

  test "tsince calculation matches python-sgp4 for GEO satellite" do
    # GEO satellite test case
    line1 = "1  6380U 73013A   24304.15169943 -.00000082  00000-0  00000+0 0   308"
    line2 = "2  6380   1.8694 269.0495 0023047 261.3377 358.8221  1.00268641 20433"

    {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

    # The epoch from python-sgp4: 2024-10-30 03:38:26.830752
    assert tle.epoch == ~U[2024-10-30 03:38:26.830752Z]

    # Test time: 30 minutes later
    target_time = ~U[2024-10-30 04:08:26.830750Z]

    # Calculate tsince using our method
    tsince_minutes = DateTime.diff(target_time, tle.epoch, :microsecond) / 60_000_000.0

    # From python verification: 29.999999966666667 minutes
    assert_in_delta tsince_minutes, 29.999999966666667, 0.000000001

    # Propagate and check result
    {:ok, state} = Sgp4Ex.propagate_tle_to_datetime(tle, target_time)

    # Expected TEME position from python-sgp4 at exactly 30 minutes
    # [-41976.9592448208, 2404.6060612946, -1386.9193799907] km
    expected_x = -41976.9592448208
    expected_y = 2404.6060612946
    expected_z = -1386.9193799907

    {x, y, z} = state.position

    # Check accuracy - should be within millimeters now
    # 1 mm tolerance
    assert_in_delta x, expected_x, 0.000001
    assert_in_delta y, expected_y, 0.000001
    assert_in_delta z, expected_z, 0.000001
  end

  test "tsince calculation for multiple satellites" do
    test_cases = [
      # ISS
      %{
        line1: "1 25544U 98067A   24001.50000000  .00012819  00000+0  22940-3 0  9991",
        line2: "2 25544  51.6416 339.8007 0002651  33.1945  60.9689 15.50231879434602",
        target_time: ~U[2024-01-01 12:30:00.000000Z],
        expected_tsince: 30.0
      },
      # STARLINK
      %{
        line1: "1 44713U 19074A   24001.50000000  .00001134  00000+0  95012-4 0  9994",
        line2: "2 44713  53.0539 127.4164 0001336  90.9831 269.1306 15.06386803232720",
        target_time: ~U[2024-01-01 12:30:00.000000Z],
        expected_tsince: 30.0
      }
    ]

    for test_case <- test_cases do
      {:ok, tle} = Sgp4Ex.parse_tle(test_case.line1, test_case.line2)

      tsince = DateTime.diff(test_case.target_time, tle.epoch, :microsecond) / 60_000_000.0

      # Should be exactly the expected time
      assert_in_delta tsince, test_case.expected_tsince, 0.0000001
    end
  end
end
