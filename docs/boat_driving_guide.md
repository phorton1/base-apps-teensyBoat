# teensyBoat.pm -- Driving the Boat

**[Home](readme.md)** --
**[Architecture](architecture.md)** --
**[User Interface](user_interface.md)** --
**[Integration](integration.md)** --
**Driving Guide**

repos: **[phorton1](https://github.com/phorton1)** --
**[teensyBoat Firmware](https://github.com/phorton1/Arduino-boat-teensyBoat/blob/master/docs/readme.md)** --
**teensyBoat App** --
**[Boat Library](https://github.com/phorton1/Arduino-libraries-Boat/blob/master/docs/readme.md)** --
**[tbESP32 WiFi](https://github.com/phorton1/Arduino-boat-tbESP32/blob/master/docs/readme.md)** --
**[teensyWind Tester](https://github.com/phorton1/Arduino-boat-teensyWind/blob/master/docs/readme.md)** --
**[teensyGPS](https://github.com/phorton1/Arduino-boat-teensyGPS/blob/master/docs/readme.md)**

This page describes how to drive the **teensyBoat** simulator remotely through
its HTTP API. The same workflow is used by Claude Code sessions and by external
automation tools. This page focuses on the subset of firmware commands needed
to actually drive the boat.

For commands beyond the driving subset -- instrument I/O configuration, protocol
monitoring, ST50 testing, GP8 modes, NMEA 2000 device queries, EEPROM, and
binary streaming -- see the firmware
[Commands](https://github.com/phorton1/Arduino-boat-teensyBoat/blob/master/docs/commands.md)
reference (denormalized superset of the
[Boat Library Commands](https://github.com/phorton1/Arduino-libraries-Boat/blob/master/docs/commands.md)
authoritative semantics). The wx app's specific consumer/emitter contract
(which binary streaming commands this application sends and when) is described
on the [Integration](integration.md) page.

## HTTP Server

teensyBoat.pm starts an HTTP server on **port 9881**. All API endpoints suppress
per-request debug noise in the teensyBoat console. Examples below use `curl`.

## Endpoints

**`GET /api/status`** -- liveness ping. Returns `{ok:1, server:"teensyBoat", port:9881}`.

**`GET /api/command?cmd=<command>`** -- sends a command to the Teensy firmware.
Returns `{ok:1, cmd:...}` immediately; poll `/api/log` after about 1 second for
output. Commands are case-insensitive.

**CRITICAL -- URL encoding of `=` in setter commands:**
The HTTP server splits query parameters on the first `=` only. A command like
`cmd=H=135` is parsed as `cmd=H` and the value `135` is silently dropped.
**Always percent-encode `=` as `%3D` inside the command value:**

```
cmd=H%3D135    (correct)
cmd=H=135      (wrong -- value silently dropped)
```

Monadic commands with no value (`RUN`, `STOP`, `SIM`, `ROUTES`, `?`) need no encoding.

**`GET /api/log?tail=N`** or **`?since=seq`** -- in-memory ring buffer of all output.
Captures: all `display()`/`warning()`/`error()` from Perl code, all text lines from
the Teensy serial stream (printed char-by-char, accumulated per line), binary packet
markers (`[BINARY pkt=N type=0xXXXX len=N]`), and console status messages.
Response: `{seq, overflow, lines:[{seq,color,text},...]}`.
Use `?since=N` for bracketed queries (record seq before command, fetch after about
1 second).

## Typical curl workflow

```
curl -s http://localhost:9881/api/status
curl -s "http://localhost:9881/api/log?tail=20"
SEQ=$(curl -s "http://localhost:9881/api/log?tail=1" | perl -ne 'print $1 if /"seq":(\d+)/')
curl -s "http://localhost:9881/api/command?cmd=SIM"
sleep 1
curl -s "http://localhost:9881/api/log?since=$SEQ"
```

## Discovering Routes

```
curl -s "http://localhost:9881/api/command?cmd=ROUTES"
```

Output (in log): lists all routes with waypoint counts. Current routes (3):
**Popa** (11 wps), **Michelle** (46 wps), **Agua** (10 wps). All in Bocas del
Toro, Panama. Popa00 = 9.334083,-82.242050 (home anchorage).

```
curl -s "http://localhost:9881/api/command?cmd=ROUTE_WPS%3DPopa"
```

Output (in log): every waypoint with index, name, lat, lon. Use this to
correlate teensyBoat waypoints with E80 WPMGR waypoints by lat/lon proximity.

## Checking Simulator State

```
curl -s "http://localhost:9881/api/command?cmd=SIM"
```

Output lines in log (all prefixed `SIM`):

```
SIM running=1 routing=1 ap=AUTO arrived=0
SIM route=Popa wps=11 target=3:Popa03(9.249720,-82.193311)
SIM pos=9.252100,-82.196000 hdg=192.1 spd=5.0 sog=4.8 cog=191.3
SIM dist=0.420 hdg_to_wp=189.6 xte=0.010
```

Fields: `running` (simulator on), `routing` (auto-advance waypoints), `ap`
(OFF/AUTO/VANE), `arrived` (completed arrival at last waypoint), `wps` (total
waypoints in route), `target` (current target wp num:name(lat,lon)), `dist`
(nm to target), `xte` (cross-track error nm).

## Driving the Boat -- Standard Sequence

```
# 1. Load a route (places boat at wp 0, turns off ap and routing)
curl -s "http://localhost:9881/api/command?cmd=ROUTE%3DPopa"

# 2. Set water speed (REQUIRED -- boat won't move at speed 0)
curl -s "http://localhost:9881/api/command?cmd=S%3D5"

# 3. Start the simulator (if not already running)
curl -s "http://localhost:9881/api/command?cmd=RUN"

# 4. Start routing (also enables autopilot AUTO mode)
curl -s "http://localhost:9881/api/command?cmd=R%3D1"

# 5. Poll state
curl -s "http://localhost:9881/api/command?cmd=SIM"
sleep 1
curl -s "http://localhost:9881/api/log?tail=10"
```

## State Machine

- `RUN` -- starts the simulator time loop (1 Hz ticks)
- `STOP` -- stops the simulator; state is preserved. **Do not use STOP to halt
  the boat in normal use** -- it freezes the entire simulator, silencing all
  instrument feeds to downstream devices such as the E80 chartplotter (which
  responds with alarms). To stop the boat without losing instrument output,
  set water speed to zero: `cmd=S%3D0`. To resume: `cmd=S%3DN`.
- `R%3D1` -- enables routing AND autopilot AUTO; boat auto-steers to target
  waypoint, advances to next waypoint on arrival, stops (and turns off routing)
  at final waypoint
- `R%3D0` -- disables routing; autopilot stays on at current heading
- `AP%3D0` -- disables autopilot (also disables routing); manual heading
- `AP%3D1` -- autopilot AUTO: steers toward current target waypoint
- `arrived=1` -- set when boat reaches final waypoint; routing stops

## Jumping to Waypoints

```
# Move boat to waypoint N (no ap/routing change)
curl -s "http://localhost:9881/api/command?cmd=J%3D3"

# Set target waypoint (what ap steers toward)
curl -s "http://localhost:9881/api/command?cmd=WP%3D4"
```

`J%3DN` teleports the boat to waypoint N (useful for testing a specific leg).
`WP%3DN` sets the navigation target without moving the boat.

## Useful Simulator Setters

Use `%3D` in place of `=` in all curl URLs (e.g. `cmd=S%3D5`).

| Command | curl encoding | Effect                                                                |
|---------|---------------|-----------------------------------------------------------------------|
| `S=N`   | `cmd=S%3DN`   | Water speed (knots) -- **must be > 0 for boat to move**               |
| `H=N`   | `cmd=H%3DN`   | Heading (true degrees) -- overridden by autopilot each tick           |
| `DH=N`  | `cmd=DH%3DN`  | Desired heading for AP (when not routing)                             |
| `D=N`   | `cmd=D%3DN`   | Depth (feet)                                                          |
| `WT=N`  | `cmd=WT%3DN`  | Water temperature (Celsius); suffix F for Fahrenheit (e.g. WT=78.8F)  |
| `WA=N`  | `cmd=WA%3DN`  | True wind angle (degrees from)                                        |
| `WS=N`  | `cmd=WS%3DN`  | True wind speed (knots)                                               |
| `CS=N`  | `cmd=CS%3DN`  | Current set (degrees true)                                            |
| `CD=N`  | `cmd=CD%3DN`  | Current drift (knots)                                                 |

## Important Notes

- Speed: `S=5` (5 knots) is a good default. Without it the boat does not move.
- Magnetic variance: hardcoded 3.0 degrees for Bocas del Toro (added to true
  heading for ST output).
- `ROUTE=name` is case-insensitive in the firmware.
- The simulator runs at about 1 Hz. Allow 1-2 seconds after commands before
  polling state.
- `B_SIM=1` enables binary streaming of simulator state to the Perl GUI windows
  -- not needed for text-based API interaction.

---

**Next:** [Home](readme.md)
