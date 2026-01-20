#!/usr/bin/env python3
import os
import sys
import traceback

try:
    import clr
except Exception:
    print("pythonnet is required. Install with: pip install pythonnet")
    sys.exit(1)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DLL_PATH = os.path.join(BASE_DIR, "ClassLibrary.dll")

if not os.path.isfile(DLL_PATH):
    print("ClassLibrary.dll not found next to the script. Build the project and copy the DLL here.")
    sys.exit(1)

clr.AddReference(DLL_PATH)
from ClassLibrary.PLC.Omron import OmronConnection

def prompt(text, default=None):
    if default is None:
        v = input(f"{text}: ").strip()
        return v
    v = input(f"{text} [{default}]: ").strip()
    return v if v != "" else default

def create_connection():
    pc_ip = prompt("Local PC IP for OmronConnection (PCip)", "192.168.3.101")
    plc_ip = prompt("PLC IP", "192.168.3.1")
    port = int(prompt("UDP port", "9600"))
    try:
        conn = OmronConnection(pc_ip, plc_ip, port)
        print("Connection object created.")
        return conn
    except Exception:
        print("Failed to create OmronConnection:")
        traceback.print_exc()
        return None

def write_coords(conn, mem_area, x_addr, trigger_addr, y_addr, x_val, y_val, trigger_val):
    try:
        # if value_type == "int":
        #     # Write separately to avoid assuming contiguous layout
        #     okx = conn.WriteInt(mem_area, int(x_addr), str(int(x_val)))
        #     oky = conn.WriteInt(mem_area, int(y_addr), str(int(y_val)))
        # else:
            # floats: WriteFloat expects space-separated float string
        okx = conn.WriteFloat(mem_area, int(x_addr), str(float(x_val)))
        oky = conn.WriteFloat(mem_area, int(y_addr), str(float(y_val)))
        trigger = conn.WriteInt(mem_area, int(trigger_addr), str(int(trigger_val)))
        print(f"Write results: X OK={okx}, Y OK={oky}, Trigger OK={trigger}")
        trigger = conn.WriteInt(mem_area, int(trigger_addr), "0")
    except Exception:
        print("Write failed:")
        traceback.print_exc()

def read_coords(conn, mem_area, x_addr, y_addr):
    try:
        # if value_type == "int":
        #     rx = conn.ReadInt(mem_area, int(x_addr), 1)
        #     ry = conn.ReadInt(mem_area, int(y_addr), 1)
        # else:
        rx = conn.ReadFloat(mem_area, int(x_addr), 1)
        ry = conn.ReadFloat(mem_area, int(y_addr), 1)
        print(f"Readback -> X: {rx}   Y: {ry}")
    except Exception:
        print("Read failed:")
        traceback.print_exc()

def main():
    conn = None
    mem_area = "D"
    x_addr = "2810"   # default addresses — change if your PLC uses different registers
    y_addr = "2910"
    trigger_addr = "3000"

    try:
        while True:
            print("\n--- PLC Coordinates CLI ---")
            print("1) Create connection")
            print("2) Configure registers / type")
            print("3) Write X,Y coordinates")
            print("4) Read X,Y coordinates")
            print("5) Close connection")
            print("0) Exit")
            choice = input("Choose: ").strip()

            if choice == "1":
                if conn:
                    print("Connection already exists. Close it first to recreate.")
                else:
                    conn = create_connection()

            elif choice == "2":
                mem_area = prompt("Memory area (e.g. D)", mem_area)
                x_addr = prompt("X register address (number)", x_addr)
                y_addr = prompt("Y register address (number)", y_addr)

            elif choice == "3":
                if not conn:
                    print("Create connection first.")
                    continue
                x_val = prompt("X value to write")
                y_val = prompt("Y value to write")
                trigger_val = prompt("Trigger value to write")
                write_coords(conn, mem_area, x_addr, trigger_addr, y_addr, x_val, y_val, trigger_val)

            elif choice == "4":
                if not conn:
                    print("Create connection first.")
                    continue
                read_coords(conn, mem_area, x_addr, y_addr)

            elif choice == "5":
                if conn:
                    try:
                        conn.Close()
                    except Exception:
                        pass
                    conn = None
                    print("Closed.")
                else:
                    print("No connection open.")

            elif choice == "0":
                break
            else:
                print("Unknown option.")
    finally:
        if conn:
            try:
                conn.Close()
            except Exception:
                pass

if __name__ == "__main__":
    main()