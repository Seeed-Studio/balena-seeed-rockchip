#!/usr/bin/env python3
"""Timestamped serial capture for /dev/ttyACM0 (1500000 8N1, no flow control).

Usage:
  sercap.py capture <logfile>        # stream timestamps chunks to logfile + stdout tail
  sercap.py send <text>              # write text (+ nothing else) to the port
  sercap.py probe                    # interactive: send newlines every 5s, capture
"""
import sys
import time
import serial

PORT = "/dev/ttyACM0"
BAUD = 1500000


def open_port():
    return serial.Serial(
        PORT,
        BAUD,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.1,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
    )


def capture(logfile):
    ser = open_port()
    with open(logfile, "ab", buffering=0) as f:
        print(f"[cap] started {time.strftime('%F %T')} -> {logfile}", flush=True)
        while True:
            data = ser.read(4096)
            if data:
                ts = time.time()
                stamp = time.strftime("%H:%M:%S", time.localtime(ts)) + ".%03d" % int((ts % 1) * 1000)
                f.write(f"\n[{stamp} +{len(data)}B] ".encode() + data)
                try:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                except Exception:
                    pass


def send(text):
    ser = open_port()
    ser.write(text.encode())
    ser.flush()
    time.sleep(0.2)
    ser.close()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "capture"
    if cmd == "capture":
        capture(sys.argv[2])
    elif cmd == "send":
        send(sys.argv[2])
