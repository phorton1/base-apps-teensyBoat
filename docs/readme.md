# teensyBoat.pm

**Home** --
**[Architecture](architecture.md)** --
**[User Interface](user_interface.md)** --
**[Integration](integration.md)**

**teensyBoat.pm** is a wxPerl desktop application for Windows that monitors and
controls the **[teensyBoat.ino](https://github.com/phorton1/Arduino-boat-teensyBoat)**
firmware running on a Teensy 4.0 microcontroller. It connects over USB serial or over
UDP via a companion ESP32 WiFi bridge (tbESP32). The application provides real-time
display of boat simulator state, SeaTalk protocol monitoring, virtual instrument
configuration, and an HTTP API for remote control and automation.

This app is one part of a three-repo system: the Perl application (this repo),
the Teensy firmware, and the shared **[Boat library](https://github.com/phorton1/Arduino-libraries-Boat)**
that defines the binary protocol used between them.

## Documentation Outline

- **[Architecture](architecture.md)** —
  Three-repo system, startup and configuration, threading model, connection modes
  (serial/UDP), inbound binary protocol, command protocol, and HTTP server.

- **[User Interface](user_interface.md)** —
  Main frame and window management; the Prog, BoatSim, and Seatalk windows in detail;
  console keyboard shortcuts.

- **[Integration](integration.md)** —
  Launching the app, firmware command reference, HTTP API endpoints, Google Earth
  KML integration, and connection to the Raymarine reverse-engineering project.

## Credits

- **[Pub::WX](https://github.com/phorton1/base-Pub)** — Patrick's wxPerl application
  framework; provides the main frame, window/pane management, ini-file state
  persistence, and the HTTP server base class used by tbServer.

- **[Win32::SerialPort](https://metacpan.org/pod/Win32::SerialPort)** — CPAN module
  for USB serial communication with the Teensy device.

## License

This software is released under the
[**GNU General Public License v3**](../LICENSE.TXT).

## Please Also See

- [**phorton1/Arduino-boat-teensyBoat**](https://github.com/phorton1/Arduino-boat-teensyBoat) —
  The Teensy 4.0 firmware. Implements the boat simulator, virtual instruments,
  Seatalk1/NMEA0183/NMEA2000 protocol encoding and decoding, and the binary/text
  serial protocol consumed by this application.

- [**phorton1/Arduino-libraries-Boat**](https://github.com/phorton1/Arduino-libraries-Boat) —
  The shared Arduino library. Defines the boatSimulator, instSimulator, boatState,
  and autoPilot classes used by the firmware, and the binary packet types shared
  with this Perl application.

- [**phorton1/base-apps-raymarine**](https://github.com/phorton1/base-apps-raymarine) —
  Raymarine reverse-engineering work (SeatalkHS/RAYNET ethernet protocols, FSH file
  format, navMate). teensyBoat.ino was the hardware tool used to drive the E80
  chartplotter to known states during that effort; this Perl app provided the
  monitoring and control interface during those sessions.

---

**Next:** [Architecture](architecture.md)
