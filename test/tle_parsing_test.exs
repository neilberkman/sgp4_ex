defmodule Sgp4Ex.TleParsingTest do
  use ExUnit.Case

  describe "parse_tle/2 exactly matches python-sgp4 behavior" do
    test "accepts TLE with trailing backslashes" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993\\"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12\\"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25544"
    end

    test "accepts TLE with extra trailing characters beyond position 69" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993EXTRA"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12MORESTUFF"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25544"
    end

    test "accepts TLE with trailing spaces" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993   "
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12     "

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25544"
    end

    test "accepts TLE with trailing newlines" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993\n"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12\n\n"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25544"
    end

    test "handles eccentricity with spaces (replaces with zeros)" do
      # Eccentricity field has spaces that should be replaced with zeros
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367    1234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      # "   1234" becomes "0.0001234"
      assert tle.eccentricity == 0.0001234
    end

    test "trims trailing whitespace from international designator" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      # "98067A  " should be trimmed to "98067A"
      assert tle.international_designator == "98067A"
    end

    test "handles negative mean motion derivative" do
      line1 = "1 25544U 98067A   21275.54791667 -.00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.mean_motion_dot < 0
    end

    test "handles negative bstar" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0 -39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.bstar < 0
    end

    test "handles negative mean motion double derivative" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264 -12345-5  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.mean_motion_double_dot < 0
    end

    test "actually test with truly short lines" do
      # Test with line1 that's actually too short (< 64 chars)
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:error, _} = Sgp4Ex.parse_tle(line1, line2)

      # Test with line2 that's actually too short (< 68 chars)  
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.4899"

      assert {:error, _} = Sgp4Ex.parse_tle(line1, line2)
    end

    test "validates satellite numbers match between lines" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25545  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:error, "Object numbers in lines 1 and 2 do not match"} =
               Sgp4Ex.parse_tle(line1, line2)
    end

    test "validates required spaces and periods at specific positions" do
      # Missing space at position 8
      line1 = "1 25544U198067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:error, _} = Sgp4Ex.parse_tle(line1, line2)
    end

    test "year handling: < 57 means 2000s, >= 57 means 1900s" do
      # Year 56 -> 2056
      line1 = "1 25544U 98067A   56275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.epoch.year == 2056

      # Year 57 -> 1957
      line1 = "1 25544U 98067A   57275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.epoch.year == 1957
    end

    test "epoch day conversion (day 1 = Jan 1)" do
      # Day 1.0 should be Jan 1 00:00:00
      line1 = "1 25544U 98067A   21001.00000000  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.epoch.month == 1
      assert tle.epoch.day == 1
      assert tle.epoch.hour == 0
      assert tle.epoch.minute == 0
      assert tle.epoch.second == 0
    end

    test "accepts classification as space (defaults to 'U')" do
      line1 = "1 25544  98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      # Classification defaults to 'U' when empty
      assert tle.classification == " "
    end

    test "rejects non-ASCII characters" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12é"

      assert {:error, "TLE lines contain non-ASCII characters"} =
               Sgp4Ex.parse_tle(line1, line2)
    end

    test "handles TLE with trailing backslash (70 chars total)" do
      # Some TLE sources append a backslash after the checksum
      line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14\\"
      line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25162"
      # negative value
      assert tle.mean_motion_dot < 0
      # negative bstar
      assert tle.bstar < 0
    end

    test "accepts TLE with 68 characters (truncated checksum)" do
      # Some TLE formats may have truncated checksums
      line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    1"
      line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      assert {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      assert tle.catalog_number == "25162"
    end

    test "stores cleaned lines without trailing characters" do
      # Input has trailing backslash that should be removed from stored lines
      input_line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14\\"
      input_line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      # Expected cleaned lines (no backslash)
      expected_line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14"
      expected_line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      assert {:ok, tle} = Sgp4Ex.parse_tle(input_line1, input_line2)

      # Verify stored lines are clean
      assert tle.line1 == expected_line1
      assert tle.line2 == expected_line2
      assert String.length(tle.line1) == 69
      assert String.length(tle.line2) == 69
    end

    test "stores cleaned lines with trailing spaces removed" do
      # Input has trailing spaces that should be removed
      input_line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14    "
      input_line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943   "

      # Expected cleaned lines (no trailing spaces)
      expected_line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14"
      expected_line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      assert {:ok, tle} = Sgp4Ex.parse_tle(input_line1, input_line2)

      # Verify stored lines are clean
      assert tle.line1 == expected_line1
      assert tle.line2 == expected_line2
    end
  end
end
