defmodule RandomTleAccuracyTest do
  @moduledoc """
  Test SGP4 propagation accuracy using random TLEs from the database.

  This test compares our implementation against Skyfield's expected values
  for a variety of satellites with different orbital characteristics.

  Expected accuracy: Within 1-2 meters for position, 1 mm/s for velocity.
  """
  use ExUnit.Case

  # TLE data from database
  @tle_data %{
    55912 => %{
      line1: "1 55912U 23030AQ  24304.49652537  .00013532  00000-0  68644-4 0  9991",
      line2: "2 55912  97.4268  23.7895 0001316  92.2453 267.8924 15.16818361 91908"
    },
    14551 => %{
      line1: "1 14551U 83122A   24013.26490053  .00016610  00000-0  54348-3 0    16",
      line2: "2 14551  82.4967 308.4845 0003849 174.3092 185.8194 15.31566189934250"
    },
    21233 => %{
      line1: "1 21233U 91030B   24177.93216564  .00000214  00000-0  53009-3 0    12",
      line2: "2 21233  82.5475 342.8645 0016820 181.8048 292.7756 13.16368809593856"
    },
    48662 => %{
      line1: "1 48662U 21044D   24304.46455016  .00002252  00000-0  37065-4 0  9998",
      line2: "2 48662  97.5181  16.3618 0002282 344.8025  15.3035 14.82147901182673"
    },
    48941 => %{
      line1: "1 48941U 21059BV  24304.29372659  .00001846  00000-0  30440-4 0  9997",
      line2: "2 48941  97.5146   7.9851 0002336  18.4616 341.6681 14.82165021172098"
    },
    57882 => %{
      line1: "1 57882U 23146B   24304.56318421  .00014949  00000-0  76745-4 0  9994",
      line2: "2 57882  97.4261  23.5668 0001523  94.7308 265.4096 15.16548994 63643"
    },
    6380 => %{
      line1: "1  6380U 73013A   24304.15169943 -.00000082  00000-0  00000+0 0   308",
      line2: "2  6380   1.8694 269.0495 0023047 261.3377 358.8221  1.00268641 20433"
    },
    51141 => %{
      line1: "1 51141U 22005AP  24003.89358717 -.00000542  00000-0 -15936-4 0    13",
      line2: "2 51141  53.2176 271.5842 0001670 111.5084 248.6086 15.08839207108603"
    },
    53480 => %{
      line1: "1 53480U 22099R   24144.84960470  .00000601  00000-0  51398-4 0    16",
      line2: "2 53480  97.6525 266.0417 0000819 250.5996 109.5140 15.01266100 97734"
    },
    58038 => %{
      line1: "1 58038U 23156L   24061.84144064 -.00000813  00000-0 -23561-4 0  1879",
      line2: "2 58038  53.0676 269.8587 0001622  86.0704 274.0476 15.18719765 23032"
    }
  }

  # Reference GCRS positions from Skyfield
  # Generated on: 2025-07-12T19:32:29.278330

  @norad_55912_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-10-30T12:24:59.791962Z],
      gcrs_pos: {-2216.7346988437, -1857.9004097485, 6249.5842087703},
      gcrs_vel: {-6.5471437326, -2.4097325647, -3.0317647283}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-10-30T13:54:59.791962Z],
      gcrs_pos: {-168.5748808083, -1048.3367611371, 6802.9092001155},
      gcrs_vel: {-6.9823754148, -2.9516301368, -0.6265134353}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-10-30T15:54:59.791962Z],
      gcrs_pos: {-6290.9872025436, -2586.2478609584, -1147.5853057875},
      gcrs_vel: {0.7709821623, 1.4014461669, -7.4322907117}
    }
  ]

  @norad_14551_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-01-13T06:51:27.405823Z],
      gcrs_pos: {-1129.9208500164, 2768.8670340994, 6153.5094905552},
      gcrs_vel: {-4.6137519770, 5.1840626214, -3.1757768397}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-01-13T08:21:27.405823Z],
      gcrs_pos: {29.4539512993, 1412.6300159347, 6693.7860477114},
      gcrs_vel: {-4.7752676364, 5.8278641974, -1.2092663042}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-01-13T10:21:27.405823Z],
      gcrs_pos: {-4228.7238975897, 4940.2384892778, -2159.1753136167},
      gcrs_vel: {0.7354090479, -2.4949958868, -7.1708974517}
    }
  ]

  @norad_21233_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-06-25T22:52:19.111298Z],
      gcrs_pos: {-6198.5494607000, 1378.9656046674, -4124.3799005889},
      gcrs_vel: {3.5589965843, -1.9480277507, -6.0181724485}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-06-26T00:22:19.111298Z],
      gcrs_pos: {-6040.9928297734, 2434.6311860290, 3846.6950575314},
      gcrs_vel: {-3.8004544634, 0.3452040103, -6.1829529529}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-06-26T02:22:19.111298Z],
      gcrs_pos: {-7218.4018547540, 2211.0346830249, -520.3439343446},
      gcrs_vel: {0.1885554794, -1.0506979441, -7.1860678449}
    }
  ]

  @norad_48662_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-10-30T11:38:57.133820Z],
      gcrs_pos: {-2185.5921087841, -1521.7444547253, 6468.2800896928},
      gcrs_vel: {-6.8658528245, -1.6037082569, -2.6901507007}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-10-30T13:08:57.133820Z],
      gcrs_pos: {914.5967591610, -688.8932042187, 6899.1896616574},
      gcrs_vel: {-7.1884902834, -2.1769482214, 0.7358719129}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-10-30T15:08:57.133820Z],
      gcrs_pos: {-6549.0466049320, -2086.4182302507, 1345.3034014650},
      gcrs_vel: {-1.6835349626, 0.5238603221, -7.3364844822}
    }
  ]

  @norad_48941_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-10-30T07:32:57.977386Z],
      gcrs_pos: {-2387.0661717228, -1184.5851195240, 6466.6040695158},
      gcrs_vel: {-7.0259193641, -0.5869429969, -2.6935623980}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-10-30T09:02:57.977386Z],
      gcrs_pos: {801.1311127329, -812.3220433888, 6898.8686183955},
      gcrs_vel: {-7.4303771478, -1.1059181601, 0.7328531085}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-10-30T11:02:57.977386Z],
      gcrs_pos: {-6784.1652444362, -1108.8927560083, 1339.9717269931},
      gcrs_vel: {-1.5840929406, 0.7613977387, -7.3380283919}
    }
  ]

  @norad_57882_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-10-30T14:00:59.115753Z],
      gcrs_pos: {-2222.3888243171, -1848.6668793680, 6251.0478209191},
      gcrs_vel: {-6.5569431204, -2.3848569751, -3.0295376001}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-10-30T15:30:59.115753Z],
      gcrs_pos: {-163.9918311194, -1043.9936759865, 6804.3676872451},
      gcrs_vel: {-6.9937795183, -2.9259408348, -0.6161908702}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-10-30T17:30:59.115753Z],
      gcrs_pos: {-6303.6079957291, -2565.5373015060, -1129.3023624744},
      gcrs_vel: {0.7573165453, 1.3904375813, -7.4353634595}
    }
  ]

  @norad_6380_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-10-30T04:08:26.830750Z],
      gcrs_pos: {-41966.1775105654, 2637.5926663023, -1286.0144618872},
      gcrs_vel: {-0.1939630178, -3.0756147560, -0.0028242753}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-10-30T05:38:26.830750Z],
      gcrs_pos: {-39753.7364657786, -13744.8227446314, -1201.7884694601},
      gcrs_vel: {1.0025631612, -2.9130178003, 0.0335997594}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-10-30T07:38:26.830750Z],
      gcrs_pos: {-27481.9499654863, -31902.1291144369, -808.2080300373},
      gcrs_vel: {2.3267603231, -2.0142237144, 0.0731826636}
    }
  ]

  @norad_51141_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-01-03T21:56:45.931488Z],
      gcrs_pos: {3754.1393110670, 2820.1193191291, 5070.2230018024},
      gcrs_vel: {-1.9510329077, 6.9360042251, -2.4074545634}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-01-03T23:26:45.931488Z],
      gcrs_pos: {4140.0450898395, 428.5992260059, 5515.4263857500},
      gcrs_vel: {-0.3591776807, 7.5812962194, -0.3193090326}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-01-04T01:26:45.931488Z],
      gcrs_pos: {-500.3586093344, 6876.4247502017, -581.3076000304},
      gcrs_vel: {-4.5262490144, -0.8325436090, -6.0391240226}
    }
  ]

  @norad_53480_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-05-23T20:53:25.846100Z],
      gcrs_pos: {-637.2501981183, 2729.5225721076, 6343.4584712192},
      gcrs_vel: {0.8987569872, 6.9473847831, -2.8934913294}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-05-23T22:23:25.846100Z],
      gcrs_pos: {-903.4623438474, 92.9966162548, 6874.4564385239},
      gcrs_vel: {0.5571995547, 7.5582493718, -0.0291760832}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-05-24T00:23:25.846100Z],
      gcrs_pos: {503.9860891350, 6925.5312232373, -52.4063876518},
      gcrs_vel: {0.9846504954, -0.1210228733, -7.5130591413}
    }
  ]

  @norad_58038_test_data [
    %{
      minutes: 30.000000,
      datetime: ~U[2024-03-01T20:41:40.471283Z],
      gcrs_pos: {3813.0970410183, 2777.1240573236, 5009.0342291604},
      gcrs_vel: {-1.8061559393, 6.9672315213, -2.4810520168}
    },
    %{
      minutes: 120.000000,
      datetime: ~U[2024-03-01T22:11:40.471283Z],
      gcrs_pos: {4135.7689129169, 659.6791937514, 5458.0304603122},
      gcrs_vel: {-0.3687109477, 7.5776436075, -0.6347538911}
    },
    %{
      minutes: 240.000000,
      datetime: ~U[2024-03-02T00:11:40.471283Z],
      gcrs_pos: {-719.2320471369, 6756.8478825296, -1141.1722368261},
      gcrs_vel: {-4.5169269034, -1.4773170668, -5.9409738233}
    }
  ]

  describe "Random TLE propagation accuracy" do
    test "NORAD 55912 propagation matches Skyfield" do
      test_satellite_propagation(55912, @norad_55912_test_data)
    end

    test "NORAD 14551 propagation matches Skyfield" do
      test_satellite_propagation(14551, @norad_14551_test_data)
    end

    test "NORAD 21233 propagation matches Skyfield" do
      test_satellite_propagation(21233, @norad_21233_test_data)
    end

    test "NORAD 48662 propagation matches Skyfield" do
      test_satellite_propagation(48662, @norad_48662_test_data)
    end

    test "NORAD 48941 propagation matches Skyfield" do
      test_satellite_propagation(48941, @norad_48941_test_data)
    end

    test "NORAD 57882 propagation matches Skyfield" do
      test_satellite_propagation(57882, @norad_57882_test_data)
    end

    test "NORAD 6380 propagation matches Skyfield" do
      test_satellite_propagation(6380, @norad_6380_test_data)
    end

    test "NORAD 51141 propagation matches Skyfield" do
      test_satellite_propagation(51141, @norad_51141_test_data)
    end

    test "NORAD 53480 propagation matches Skyfield" do
      test_satellite_propagation(53480, @norad_53480_test_data)
    end

    test "NORAD 58038 propagation matches Skyfield" do
      test_satellite_propagation(58038, @norad_58038_test_data)
    end
  end

  defp test_satellite_propagation(norad_id, test_cases) do
    tle_info = @tle_data[norad_id]
    {:ok, tle} = Sgp4Ex.parse_tle(tle_info.line1, tle_info.line2)

    for test_case <- test_cases do
      {:ok, teme_state} = Sgp4Ex.propagate_tle_to_datetime(tle, test_case.datetime)
      gcrs_state = Sgp4Ex.teme_to_gcrs(teme_state, test_case.datetime)

      # Extract actual values
      {actual_x, actual_y, actual_z} = gcrs_state.position
      {actual_vx, actual_vy, actual_vz} = gcrs_state.velocity

      # Extract expected values
      {expected_x, expected_y, expected_z} = test_case.gcrs_pos
      {expected_vx, expected_vy, expected_vz} = test_case.gcrs_vel

      # Calculate position errors
      error_x = actual_x - expected_x
      error_y = actual_y - expected_y
      error_z = actual_z - expected_z
      error_magnitude = :math.sqrt(error_x * error_x + error_y * error_y + error_z * error_z)

      # Calculate velocity errors
      vel_error_x = actual_vx - expected_vx
      vel_error_y = actual_vy - expected_vy
      vel_error_z = actual_vz - expected_vz

      vel_error_magnitude =
        :math.sqrt(
          vel_error_x * vel_error_x + vel_error_y * vel_error_y + vel_error_z * vel_error_z
        )

      # Log detailed error information
      IO.puts("")
      IO.puts("NORAD #{norad_id} at #{Float.round(test_case.minutes, 1)} minutes after epoch:")
      IO.puts("  Position error magnitude: #{Float.round(error_magnitude * 1000, 6)} meters")
      IO.puts("    X: #{Float.round(error_x * 1000, 6)} m")
      IO.puts("    Y: #{Float.round(error_y * 1000, 6)} m")
      IO.puts("    Z: #{Float.round(error_z * 1000, 6)} m")
      IO.puts("  Velocity error: #{Float.round(vel_error_magnitude * 1000, 6)} m/s")

      # Assert position accuracy - allow 2 meters for now
      # 2 meters
      tolerance_km = 0.002

      assert error_magnitude < tolerance_km,
             "Position error for NORAD #{norad_id} at #{test_case.minutes} minutes: #{Float.round(error_magnitude * 1000, 1)} meters exceeds tolerance of #{tolerance_km * 1000} meters"

      # Assert velocity accuracy (allowing 1 m/s tolerance)
      velocity_tolerance_km_s = 0.001

      assert vel_error_magnitude < velocity_tolerance_km_s,
             "Velocity error for NORAD #{norad_id} at #{test_case.minutes} minutes: #{Float.round(vel_error_magnitude * 1000, 3)} m/s exceeds tolerance of 1 m/s"
    end
  end
end
