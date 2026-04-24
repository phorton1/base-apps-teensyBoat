# teensyBoat.pm — User Interface

**[Home](readme.md)** --
**[Architecture](architecture.md)** --
**User Interface** --
**[Integration](integration.md)**

## Main Frame

The application window is a **Pub::WX::Frame** with a toolbook (a tabbed notebook
where each tab opens a separate panel). Three panels are available from the **View**
menu: Prog, BoatSim, and Seatalk. Each panel can be opened and closed independently;
their positions, sizes, and any per-panel state (zoom level, TTL value) are saved to
the per-instance ini file and restored on next launch.

## Prog Window (winProg.pm)

The Prog window configures which virtual instruments emit traffic on which protocols,
and controls several firmware-level behaviors. It is activated by `B_PROG=1` on open
and `B_PROG=0` on close; its state is fully refreshed from a `BINARY_TYPE_PROG` packet
on connect and whenever the firmware changes instrument state.

### Instrument / Protocol Matrix

The main grid is **9 instruments × 5 protocols**:

```
              SEATALK1  SEATALK2  NMEA0183A  NMEA0183B  NMEA2000
  DEPTH         [ ]       [ ]       [ ]        [ ]        [ ]
  LOG           [ ]       [ ]       [ ]        [ ]        [ ]
  WIND          [ ]       [ ]       [ ]        [ ]        [ ]
  COMPASS       [ ]       [ ]       [ ]        [ ]        [ ]
  GPS           [ ]       [ ]       [ ]        [ ]        [ ]
  AIS           [ ]       [ ]       [ ]        [ ]        [ ]
  AP            [ ]       [ ]       [ ]        [ ]        [ ]
  ENG           [ ]       [ ]       [ ]        [ ]        [ ]
  GEN           [ ]       [ ]       [ ]        [ ]        [ ]
```

Each checkbox sends `I_<INSTNAME>=<port_mask>` to the firmware, where `port_mask`
is a bitfield across all five ports for that instrument (bit 0 = ST1, bit 1 = ST2,
bit 2 = 83A, bit 3 = 83B, bit 4 = 2000). Changing one checkbox recomputes the mask
from all checkboxes in that instrument's row.

Below the instrument rows are two extra rows per protocol column:

- **all_on** button — checks all instrument boxes for that column; sends
  `I_<portid>=1` for every instrument
- **all_off** button — unchecks all; sends `I_<portid>=0` for every instrument

### Protocol Monitor Controls

Below the all-on/all-off buttons is a **MONITOR** row with one hex text control
per protocol. Changing a value sends `M_<portid>=<value>`. These control the
firmware's per-protocol monitoring verbosity/filter at a low level.

### Forwarding and Filter Controls

A row of checkboxes at the top of the window controls packet forwarding between ports:

| Checkbox | Command sent     | Effect                              |
|----------|------------------|-------------------------------------|
| 1->2     | FWD bitmask bit0 | Forward SeaTalk1 output to port 2   |
| 1<-2     | FWD bitmask bit1 | Forward SeaTalk2 output to port 1   |
| A->B     | FWD bitmask bit2 | Forward NMEA0183A output to port B  |
| A<-B     | FWD bitmask bit3 | Forward NMEA0183B output to port A  |
| E80 Filter | E80_FILTER=N   | Suppress E80-generated SeaTalk echo |

### GP8 Mode Combo

A drop-down in the top-right corner selects the operating mode of the GP8 hardware
output: **OFF**, **SPEED**, **WIND**, or **ESP32**. Sends `GP8_MODE=<value>`.

### LOAD / SAVE / CLEAR Buttons

- **LOAD** — sends `LOAD`; firmware loads instrument config from EEPROM
- **SAVE** — sends `SAVE`; firmware saves current instrument config to EEPROM
- **CLEAR** — sends `CLEAR`; resets instrument state

## BoatSim Window (winBoatSim.pm)

The BoatSim window shows the complete real-time state of the boat simulator as a
grid of labeled static-text fields. It is activated by `B_SIM=1` on open and
`B_SIM=0` on close. Each `BINARY_TYPE_SIM` packet refreshes all fields; a field
that changed since the last packet is shown in **red**, and reverts to black on
the next packet if unchanged.

The window is organized in three columns:

**Column 0 — Navigation and Routing**

| Field          | Description                                     |
|----------------|-------------------------------------------------|
| running        | Simulator time loop active (0/1)                |
| autopilot      | Autopilot mode (0=off, 1=AUTO)                  |
| routing        | Route auto-advance active (0/1)                 |
| arrived        | Final waypoint arrival flag (0/1)               |
| route_name     | Current route name (up to 16 chars)             |
| trip_on        | Trip odometer running (0/1)                     |
| trip_dist      | Trip distance (nm, 2 decimal places)            |
| log_total      | Total log distance (nm, 1 decimal place)        |
| start_wp       | Index of starting waypoint                      |
| start_name     | Name of starting waypoint (up to 8 chars)       |
| target_wp      | Index of target waypoint                        |
| target_name    | Name of target waypoint (up to 8 chars)         |
| head_to_wp     | True heading to target waypoint (degrees)       |
| dist_to_wp     | Distance to target waypoint (nm, 4 places)      |
| desired_heading| Autopilot desired heading (degrees)             |
| rudder         | Rudder angle (degrees, 1 place)                 |

**Column 1 — Boat State**

| Field            | Description                                    |
|------------------|------------------------------------------------|
| depth            | Water depth (feet, 1 place)                    |
| heading          | True heading (degrees, 1 place)                |
| water_speed      | Speed through water (knots, 1 place)           |
| current_set      | Current direction (degrees true, 1 place)      |
| current_drift    | Current speed (knots, 1 place)                 |
| wind_angle       | True wind angle (degrees from, 1 place)        |
| wind_speed       | True wind speed (knots, 1 place)               |
| latitude         | Latitude (degree-minutes or decimal, 6 places) |
| longitude        | Longitude (degree-minutes or decimal, 6 places)|
| sog              | Speed over ground (knots, 1 place)             |
| cog              | Course over ground (degrees true, 1 place)     |
| app_wind_angle   | Apparent wind angle (degrees, 1 place)         |
| app_wind_speed   | Apparent wind speed (knots, 1 place)           |
| estimated_set    | Estimated current set (degrees, 4 places)      |
| estimated_drift  | Estimated current drift (knots, 4 places)      |
| cross_track_error| Cross-track error (nm, 4 places)               |
| closest          | Index of closest waypoint                      |

**Column 2 — Engine and Genset**

| Field            | Description                                    |
|------------------|------------------------------------------------|
| rpm              | Engine RPM                                     |
| boost_pressure   | Turbo boost pressure (1 place)                 |
| oil_pressure     | Engine oil pressure (1 place)                  |
| oil_temp         | Engine oil temperature (1 place)               |
| coolant_temp     | Engine coolant temperature (1 place)           |
| alt_voltage      | Alternator voltage (1 place)                   |
| fuel_rate        | Fuel consumption rate (1 place)                |
| fuel_level1      | Fuel tank 1 level (2 places)                   |
| fuel_level2      | Fuel tank 2 level (2 places)                   |
| genset           | Genset running (0/1)                           |
| gen_rpm          | Genset RPM                                     |
| gen_oil_pressure | Genset oil pressure (1 place)                  |
| gen_cool_temp    | Genset coolant temperature (1 place)           |
| gen_voltage      | Genset output voltage (1 place)                |
| gen_freq         | Genset output frequency (Hz)                   |

Latitude and longitude are displayed in degree-minutes format
(`DD°MM.MMM`) when `$SHOW_DEGREE_MINUTES` is set (the default), or as a
decimal float to 6 places otherwise.

Each `BINARY_TYPE_SIM` packet also calls `updateTBServer()` to push the current
COG, latitude, and longitude to the HTTP server state, which feeds `/position.kml`.

## Seatalk Window (winST.pm)

The Seatalk window is a live browser of incoming SeaTalk protocol messages on ST1
and ST2. It is activated by `B_ST=1` on open and `B_ST=0` on close.

The window uses **tbListCtrl**, a custom list control that:

- Maintains one row per unique message type (keyed on `dir + st_name`)
- Auto-expires rows after a configurable TTL (default 10 seconds, editable in the
  TTL text control at the top of the window)
- Supports zoom-level font scaling (persisted in the ini file)

**Columns:**

| Column   | Description                                             |
|----------|---------------------------------------------------------|
| count    | Number of times this message type has been received    |
| dir      | Direction (in/out)                                      |
| st_name  | SeaTalk message name / opcode                           |
| hex      | Raw byte sequence in hex                                |
| descrip  | Decoded description (if available)                      |

The `hex` and `descrip` columns are marked `dynamic` and share the remaining
width after the fixed-width columns are laid out.

Window zoom level and TTL value are saved to and restored from the ini file via
`getDataForIniFile()` / `createPane()` data passing.

## Console (tbConsole.pm)

The console is the Win32 console window attached to the Perl process. It serves as
both the primary log output surface and a direct serial command line.

**Output:** all `display()`, `warning()`, and `error()` calls from Perl code, plus
every text character received from the firmware's serial stream, rendered with colors
matching the firmware's ANSI escape codes. The same output is accumulated in a
2000-line in-memory ring buffer that feeds the HTTP `/api/log` endpoint.

**Keyboard input** (processed in the console_thread):

| Key    | Action                                                         |
|--------|----------------------------------------------------------------|
| Ctrl-A | Toggle boat track recording (`$tb_tracking` in tbServer)      |
| Ctrl-B | Clear the current track (`clearTBTrack()`)                    |
| Ctrl-C | Exit the application                                          |
| Ctrl-D | Clear the console display                                     |
| Enter  | Send the buffered input line as a command to the firmware     |
| Other  | Echo to console and append to input buffer                    |

Backspace is handled: it removes the last character from the input buffer and
erases it from the console display.

---

**Next:** [Integration](integration.md)
