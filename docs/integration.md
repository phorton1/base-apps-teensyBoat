# teensyBoat.pm — Integration

**[Home](readme.md)** --
**[Architecture](architecture.md)** --
**[User Interface](user_interface.md)** --
**Integration**

## The Three-Repo System

```
  base-apps-teensyBoat    (this repo — Perl wxPerl app)
          |
          |  USB serial (Win32::SerialPort) or UDP (IO::Socket::INET via tbESP32)
          |
  Arduino-boat-teensyBoat (Teensy 4.0 firmware)
          |
          |  #include
          |
  Arduino-libraries-Boat  (shared C++ library — boatSimulator, instSimulator, etc.)
```

Each repo is independent with its own git history. The binary packet type constants
in `tbBinary.pm` must match the corresponding constants in the Boat library; they
are kept in sync manually.

## Launching the App

```
perl teensyBoat.pm          # USB serial COM14 (default, Teensy on laptop)
perl teensyBoat.pm 4        # USB serial COM4  (breadboard device)
perl teensyBoat.pm 55       # UDP to tbESP32 at 10.237.50.55:5005
```

Multiple instances can run simultaneously against different devices; each gets
its own window title (`teensyBoat(N)`) and ini file (`teensyBoat.N.ini`).

## Firmware Command Reference

Commands are plain ASCII text sent to the Teensy over serial or UDP.
The format is `KEY=VALUE\r\n` for setters, or `VERB\r\n` for monadic commands.
Full documentation is in the teensyBoat.ino repo; the key commands are summarized
here for reference.

### Simulator Control

| Command        | Effect                                                          |
|----------------|-----------------------------------------------------------------|
| RUN            | Start the simulator time loop (1 Hz ticks)                     |
| STOP           | Pause the simulator; state is preserved                        |
| ROUTE=name     | Load named route; teleport boat to wp 0; reset ap and routing  |
| J=N            | Teleport boat to waypoint N; turn off ap and routing           |
| WP=N           | Set navigation target to waypoint N; do not move boat          |
| S=N            | Water speed (knots) — **must be > 0 for the boat to move**    |
| H=N            | True heading (degrees) — overridden by autopilot each tick     |
| DH=N           | Desired heading for autopilot (when not routing)               |
| D=N            | Water depth (feet)                                             |
| WA=N           | True wind angle (degrees from)                                 |
| WS=N           | True wind speed (knots)                                        |
| CS=N           | Current set (degrees true)                                     |
| CD=N           | Current drift (knots)                                          |
| RPM=N          | Engine RPM                                                     |
| GEN=0/1        | Start / stop the genset                                        |
| AP=0/1         | Disable / enable autopilot AUTO mode                           |
| R=0/1          | Disable / enable routing (R=1 also enables AP AUTO)            |

When routing is on and the boat reaches the final waypoint, both routing and
the autopilot are turned off and water speed is set to zero.

### Virtual Instrument Assignment

Each instrument can be configured to output on any combination of the five protocols.
The mask is a bitfield: bit 0 = ST1, bit 1 = ST2, bit 2 = 83A, bit 3 = 83B, bit 4 = 2000.

```
I_DEPTH=mask       I_LOG=mask         I_WIND=mask
I_COMPASS=mask     I_GPS=mask         I_AIS=mask
I_AP=mask          I_ENG=mask         I_GEN=mask
```

To turn all instruments on or off for a given port:

```
I_ST1=N    I_ST2=N    I_83A=N    I_83B=N    I_2000=N
```

### Protocol Forwarding and Monitoring

```
FWD=bitmask           # bit0=ST1→ST2, bit1=ST2→ST1, bit2=83A→83B, bit3=83B→83A
E80_FILTER=0/1        # suppress E80-generated SeaTalk echo
M_ST1=N               # ST1 monitoring verbosity (hex value)
M_ST2=N               # ST2 monitoring verbosity
M_83A=N               # NMEA0183A monitoring verbosity
M_83B=N               # NMEA0183B monitoring verbosity
M_2000=N              # NMEA2000 monitoring verbosity
```

### Binary Streaming

The Perl app activates binary output by window:

```
B_PROG=1/0     # winProg instrument state packets (BINARY_TYPE_PROG)
B_SIM=1/0      # winBoatSim simulator state packets (BINARY_TYPE_SIM)
B_ST=1/0       # winST SeaTalk monitor packets (BINARY_TYPE_ST1/ST2)
```

### Configuration and System

```
LOAD           # load instrument config from firmware EEPROM
SAVE           # save instrument config to firmware EEPROM
CLEAR          # reset instrument state
STATE          # send current instrument state as BINARY_TYPE_PROG packet
DT=YYYY-MM-DD HH:MM:SS    # set firmware RTC (UTC)
GP8_MODE=OFF/SPEED/WIND/ESP32    # GP8 hardware output mode
```

### Simulator Query

```
SIM            # print current simulator state to serial output
ROUTES         # list all routes with waypoint counts
ROUTE_WPS=name # list all waypoints in the named route
?              # show command summary
help           # show detailed help
```

## HTTP API (tbServer)

The HTTP server runs on **port 9881** when `$WITH_TB_SERVER = 1` (the default).
It is designed for external tools and automation — including remote control from
Claude Code sessions.

| Endpoint                 | Description                                                      |
|--------------------------|------------------------------------------------------------------|
| GET /api/status          | Liveness ping; returns `{ok:1, server:"teensyBoat", port:9881}` |
| GET /api/command?cmd=CMD | Queues CMD to firmware; returns `{ok:1, cmd:...}` immediately   |
| GET /api/log?tail=N      | Last N lines from output ring (default 200)                      |
| GET /api/log?since=seq   | All lines with seq > N (for bracketed polling after a command)   |
| GET /position.kml        | Google Earth KML: boat position icon + recorded track polyline   |

**URL encoding:** Commands containing `=` must percent-encode the `=` as `%3D`
in the query string, because the server splits on the first `=` only.

```
# Correct:
curl -s "http://localhost:9881/api/command?cmd=S%3D5"

# Wrong — value is silently dropped:
curl -s "http://localhost:9881/api/command?cmd=S=5"
```

Monadic commands (RUN, STOP, SIM, ROUTES, ?) need no encoding.

**Typical polling workflow:**

```sh
# 1. Check liveness
curl -s http://localhost:9881/api/status

# 2. Record sequence before command
SEQ=$(curl -s "http://localhost:9881/api/log?tail=1" | perl -ne 'print $1 if /"seq":(\d+)/')

# 3. Send command
curl -s "http://localhost:9881/api/command?cmd=SIM"

# 4. Wait, then fetch output since before the command
sleep 1
curl -s "http://localhost:9881/api/log?since=$SEQ"
```

## Google Earth Integration

The `/position.kml` endpoint returns a KML document containing:

- A **position placemark** with the boat icon (`boat_icon.png`) rotated to the
  current heading, at the current latitude/longitude
- A **track polyline** showing the path recorded since tracking was last enabled

The boat icon is served from `site/boat_icon.png` by the same HTTP server, but
the `kml_placemark()` function references it via port 9882 (a legacy artifact;
see tbServer.pm if this needs correction).

Track recording is controlled from the console:

- **Ctrl-A** toggles `$tb_tracking` on/off
- **Ctrl-B** clears the current track (`clearTBTrack()`)

Track points are added adaptively. Each boat position update computes a weighted
urgency score from heading change, distance moved, elapsed time, and inverse speed.
A point is recorded when the score exceeds 1.0, avoiding excessive density when
the boat is slow or moving straight, and capturing detail during turns.

## Connection to the Raymarine Project

**teensyBoat.ino** was the hardware instrument used during the reverse engineering
of Raymarine's SeatalkHS ethernet protocol suite (**RAYNET**). The firmware generates
configurable Seatalk1, NMEA0183, and NMEA2000 traffic that drives the Raymarine E80
chartplotter to specific, reproducible states, making it possible to probe the E80's
ethernet responses systematically.

This Perl application was the monitoring and control interface during those sessions
— observing what the firmware was outputting, sending commands to adjust simulator
state, and coordinating the timing of network captures.

See [**phorton1/base-apps-raymarine**](https://github.com/phorton1/base-apps-raymarine)
for the full RAYNET protocol documentation, tools, and the navMate navigation
data management system built on that work.

---

**Next:** [Home](readme.md)
