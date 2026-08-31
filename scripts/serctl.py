#!/usr/bin/env python3
"""Interactive serial runner: holds /dev/ttyACM0 open, sends a scripted
sequence with delays, logs everything with timestamps.

Usage: serctl.py <logfile> <<'EOF'
[login]root
[sleep:2]
[cmd]dmesg | grep -i scmi
...
EOF
"""
import sys
import time
import serial

PORT = "/dev/ttyACM0"
BAUD = 1500000


def main(logfile, script):
    ser = serial.Serial(PORT, BAUD, timeout=0.1)
    f = open(logfile, "wb", buffering=0)

    def pump_read(dur):
        end = time.time() + dur
        while time.time() < end:
            data = ser.read(4096)
            if data:
                ts = time.time()
                stamp = time.strftime("%H:%M:%S", time.localtime(ts)) + ".%03d " % int((ts % 1) * 1000)
                f.write(f"[{stamp}] ".encode() + data)

    for line in script:
        line = line.rstrip("\n")
        if not line:
            continue
        if line.startswith("[login]"):
            ser.write(line[7:].encode() + b"\n")
            time.sleep(0.3)
            ser.write(b"\n")  # in case login prompt needs wake
        elif line.startswith("[sleep:]"):
            pump_read(float(line[8:]))
        elif line.startswith("[cmd]"):
            ser.write(line[5:].encode() + b"\n")
            pump_read(0.4)
        elif line.startswith("[raw]"):
            ser.write(line[5:].encode())
            pump_read(0.2)
        elif line.startswith("[wait]"):
            pump_read(float(line[6:]))
        else:
            ser.write(line.encode() + b"\n")
            pump_read(0.4)
    pump_read(2)
    ser.close()


if __name__ == "__main__":
    script = sys.stdin.readlines()
    main(sys.argv[1], script)
