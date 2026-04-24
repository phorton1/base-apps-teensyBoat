# teensyBoat.pm — Architecture

**[Home](readme.md)** --
**Architecture** --
**[User Interface](user_interface.md)** --
**[Integration](integration.md)**

## The Three-Repo System

The teensyBoat system spans three repositories that work together:

```
  base-apps-teensyBoat    (this repo — Perl wxPerl app)
          |
          |  USB serial or UDP (WiFi via tbESP32)
          |
  Arduino-boat-teensyBoat (Teensy 4.0 firmware)
          |
          |  #include
          |
  Arduino-libraries-Boat  (shared C++ library)
```

The **Boat library** defines the binary packet types, the boat simulator, virtual
instruments, autopilot, and boatState. The **firmware** uses those classes to generate
real and simulated NMEA/SeaTalk traffic and to produce binary telemetry packets. This
**Perl app** receives those packets and displays them, and sends text commands back to
control the firmware.

## Startup and Configuration

The app is launched as:

```
perl teensyBoat.pm [N]
```

The optional argument `N` determines the connection mode:

- **N ≤ 40** (default 14): USB serial COM port. COM14 is the Teensy on the laptop;
  COM4 is a breadboard device.
- **N > 40**: UDP mode. Connects to a tbESP32 WiFi bridge at `10.237.50.N` on port 5005.

`N` also determines the ini file name (`teensyBoat.N.ini`) and the window title
(`teensyBoat(N)`), so two instances can run simultaneously against different devices.

**tbUtils.pm** runs at `use` time to parse the argument, initialize `Pub::Utils`
(temp dir, data dir, log ring buffer), and export all shared constants. If
`$WITH_TB_SERVER` is true (it is, by default), **tbServer.pm** starts its HTTP
listener before the WX app is created. Then **teensyBoat.pm** creates the frame,
which starts **tbConsole**.

## Threading Model

The application uses four thread groups:

| Thread               | Role                                                              |
|----------------------|-------------------------------------------------------------------|
| Main (WX event loop) | GUI, onIdle binary dispatch, window management                   |
| console_thread       | Serial/UDP read loop (~100 Hz), command queue drain              |
| arduino_thread       | Polls process list for arduino-builder.exe / esptool.exe;        |
|                      | disconnects serial port during firmware uploads                  |
| HTTP server threads  | Up to 5, spawned per request by Pub::HTTP::ServerBase            |

All inter-thread state uses Perl `threads::shared` variables. The key shared
structures are `$binary_queue` (inbound binary packets) and `$command_queue`
(outbound text commands), both shared array refs.

## Connection Modes

### USB Serial

`Win32::SerialPort` opens `COM<N>` at 115200 baud with an 8-N-1 frame and a 60 KB
read buffer. The console_thread polls `$port->status()` every loop to detect
disconnection and retries `initComPort()` every 3 seconds when no port is open.
The arduino_thread watches for `arduino-builder.exe` or `esptool.exe` processes; if
found, it closes the serial port to avoid contending with the Arduino IDE during a
firmware upload, then reopens 2 seconds after those processes exit.

### UDP (tbESP32)

When `N > 40`, the app opens a UDP socket bound to port 5005 instead of a serial
port. The tbESP32 device (an ESP32 running myIOT firmware with a custom serial
bridge) relays traffic between the Teensy and the laptop over WiFi. The protocol
is identical; UDP datagrams carry the same text commands and binary packet stream.
In UDP mode `$TB_ONLINE` is set immediately at startup since there is no
connect/disconnect handshake.

### Online Notification

When the serial port opens (or at startup in UDP mode), `$TB_ONLINE` is set to 1.
**tbFrame.onIdle** detects this, sends `DT=<timestamp>` to synchronize the firmware
clock, calls `initTBCommands()` on every open window (which re-sends each window's
activation command), then clears `$TB_ONLINE`.

## Serial Protocol — Inbound (Firmware → Perl)

The firmware sends a mixed stream of text and binary on the same connection:

**Text lines** are terminated with `\n`. The firmware uses ANSI escape sequences
(`ESC [ <color> m`) for colorized output. **tbConsole.handleComBytes()** strips the
ANSI codes, applies the color to the Win32 console, and pushes each complete line to
the 2000-entry output ring buffer (which also feeds `/api/log`).

**Binary packets** are introduced by a `0x02` byte (STX), followed by a 2-byte
little-endian length, followed by that many bytes of payload. The payload always
begins with a 2-byte little-endian type field. The binary parser state machine in
`handleComBytes()` accumulates the payload and pushes the complete packet onto
`$binary_queue` when `binary_got == binary_len`. A 0.5-second timeout resets the
parser if a packet is not completed in time.

**Binary packet types** (defined in tbBinary.pm, must match the firmware constants):

| Constant           | Value  | Sent by              | Consumed by  |
|--------------------|--------|----------------------|--------------|
| BINARY_TYPE_PROG   | 0x0001 | STATE / I_ commands  | winProg      |
| BINARY_TYPE_SIM    | 0x0002 | B_SIM=1              | winBoatSim   |
| BINARY_TYPE_BOAT   | 0x0004 | (reserved)           | —            |
| BINARY_TYPE_ST1    | 0x0010 | B_ST=1               | winST        |
| BINARY_TYPE_ST2    | 0x0020 | B_ST=1               | winST        |
| BINARY_TYPE_0183A  | 0x0100 | (vestigial)          | —            |
| BINARY_TYPE_0183B  | 0x0200 | (vestigial)          | —            |
| BINARY_TYPE_2000   | 0x1000 | (not yet used)       | —            |

## Binary Dispatch — tbFrame.onIdle

`onIdle` runs on every WX idle event. It processes one binary packet per call from
`$binary_queue` and routes it by type:

- **PROG** → `winProg->handleBinaryData()` — updates instrument/port checkboxes and
  forwarding state
- **SIM** → `winBoatSim->handleBinaryData()` + `updateTBServer()` — updates the
  live BoatSim display and pushes lat/lon/heading to the HTTP server state
- **ST1 / ST2** → `winST->handleBinaryData()` — adds a row to the SeaTalk browser
- **0183A / 0183B** → vestigial VSPE virtual COM forward; disabled
  (`$NMEA0183_COMPORT = 0`)

It also handles the `$TB_ONLINE` notification before packet dispatch each cycle.

## Command Protocol — Outbound (Perl → Firmware)

Any Perl code calls `sendTeensyCommand($cmd)`, which pushes `$cmd` onto the
thread-shared `$command_queue`. The console_thread drains one command per loop
iteration, writing `"$cmd\r\n"` to the serial port or UDP socket. Commands are plain
ASCII text (`KEY=VALUE` or monadic `VERB`) defined by the firmware's serial parser.

## HTTP Server (tbServer.pm)

`tbServer` extends `Pub::HTTP::ServerBase` and listens on **port 9881**. It is
enabled by `$WITH_TB_SERVER = 1` in tbUtils.pm. Up to 5 request threads run
concurrently; keep-alive is off. Debug output for `/api/` requests is suppressed
to avoid noise in the console.

`winBoatSim` calls `updateTBServer({heading, latitude, longitude})` on every
`BINARY_TYPE_SIM` packet, which updates the server's shared position state and
calls `addTrackPoint()`. Track points are added adaptively based on a weighted
urgency score (heading change, distance moved, elapsed time, speed); the threshold
is 1.0. Ctrl-A in the console toggles `$tb_tracking`; Ctrl-B calls `clearTBTrack()`.

The server also hosts static files from `site/` (currently just `boat_icon.jpg` and
`boat_icon.png`) for the Google Earth KML icon.

See [Integration](integration.md) for the full HTTP API endpoint reference.

---

**Next:** [User Interface](user_interface.md)
