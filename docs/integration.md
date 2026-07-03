# teensyBoat.pm — Integration

**[Home](readme.md)** --
**[Architecture](architecture.md)** --
**[User Interface](user_interface.md)** --
**Integration** --
**[Driving Guide](boat_driving_guide.md)**

repos: **[phorton1](https://github.com/phorton1)** --
**[teensyBoat Firmware](https://github.com/phorton1/Arduino-boat-teensyBoat/blob/master/docs/readme.md)** --
**teensyBoat App** --
**[Boat Library](https://github.com/phorton1/Arduino-libraries-Boat/blob/master/docs/readme.md)** --
**[tbESP32 WiFi](https://github.com/phorton1/Arduino-boat-tbESP32/blob/master/docs/readme.md)** --
**[teensyWind Tester](https://github.com/phorton1/Arduino-boat-teensyWind/blob/master/docs/readme.md)** --
**[teensyGPS](https://github.com/phorton1/Arduino-boat-teensyGPS/blob/master/docs/readme.md)**

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

The teensyBoat firmware accepts a comprehensive set of text commands --
plain ASCII, case-insensitive, `KEY=VALUE` or `VERB` form,
newline-terminated -- that drive the virtual boat simulator, configure
virtual instrument output, control protocol monitoring, and toggle the
binary streaming channels described below.

The full command reference is in the firmware repository:
**[teensyBoat Commands](https://github.com/phorton1/Arduino-boat-teensyBoat/blob/master/docs/commands.md)**.
That page is a denormalized superset of the
**[Boat Library Commands](https://github.com/phorton1/Arduino-libraries-Boat/blob/master/docs/commands.md)**
reference, which is the authoritative source for what each command does
in terms of simulator and instrument state.

This application sends user-issued commands unchanged via the USB serial
connection and via the HTTP `/api/command` endpoint (see
[HTTP API](#http-api-tbserver) below).

### Commands this application emits

In addition to forwarding user-issued commands, **teensyBoat.pm** itself
emits a small set of commands as part of its window lifecycle.  These
toggle the firmware's binary streaming channels so that only the data
corresponding to currently-open windows is being transmitted, and
synchronize the firmware's clock.

| Command       | Emitted when                              | Purpose                                                |
|---------------|-------------------------------------------|--------------------------------------------------------|
| `DT=...`      | On startup, from tbFrame.pm               | Set the firmware's RTC from the local clock (UTC)      |
| `STATE`       | On winProg open                           | Refresh the application's view of firmware state       |
| `B_PROG=N`    | winProg open (N=1) / close (N=0)          | Toggle `BINARY_TYPE_PROG` instrument config packets    |
| `B_SIM=N`     | winBoatSim open / close                   | Toggle `BINARY_TYPE_SIM` simulator state packets       |
| `B_AIS=N`     | winAIS open / close                       | Toggle `BINARY_TYPE_AIS` virtual AIS target packets    |
| `B_ST=N`      | winST open / close                        | Toggle `BINARY_TYPE_ST1` + `BINARY_TYPE_ST2` packets   |

The other binary streaming channels (`B_0183`, `B_2000`, `B_BOAT`) are
not wired to any application window today; the corresponding firmware
output remains off unless toggled manually from the console or via the
HTTP API.

## HTTP API (tbServer)

The HTTP server runs on **port 9881**.
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

**Next:** [Driving Guide](boat_driving_guide.md)
