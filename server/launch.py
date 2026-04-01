"""
AshamaneCore Legion Private Server Launcher
Starts MySQL -> bnetserver -> worldserver -> WoW client in order.
Run with: python launch.py
"""

import subprocess
import sys
import os
import time
import socket
import signal

# ── Configuration ─────────────────────────────────────────────────────────────

BIN_DIR       = os.path.dirname(os.path.abspath(__file__))
MYSQL_EXE     = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe"
MYSQL_CLIENT  = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
MYSQL_DATADIR = r"C:\ProgramData\MySQL\MySQL Server 8.4\Data"

BNETSERVER_EXE  = os.path.join(BIN_DIR, "bnetserver.exe")
WORLDSERVER_EXE = os.path.join(BIN_DIR, "worldserver.exe")
CLIENT_EXE      = r"C:\Users\donav\Desktop\Legion+repack+privateServer\Legion_Full_Client\Hellgarve_Legion_Full_Client\Hellgarve.Legion-64.exe"

MYSQL_HOST    = "127.0.0.1"
MYSQL_PORT    = 3306
BNET_PORT     = 1119   # default bnetserver port
WORLD_PORT    = 8085   # default worldserver port

MYSQL_TIMEOUT   = 30   # seconds to wait for MySQL to accept connections
BNET_TIMEOUT    = 20
WORLD_TIMEOUT   = 180  # worldserver loads maps/vmaps — takes ~100s on first run

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg, tag="*"):
    print(f"[{tag}] {msg}", flush=True)

def wait_for_port(host, port, timeout, label):
    """Poll a TCP port until it accepts connections or timeout."""
    log(f"Waiting for {label} on {host}:{port} (up to {timeout}s)...")
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                log(f"{label} is ready.", tag="+")
                return True
        except (ConnectionRefusedError, OSError):
            time.sleep(1)
    log(f"Timed out waiting for {label}.", tag="!")
    return False

def is_port_open(host, port):
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False

def start_process(exe, label, cwd=None, new_window=True):
    """Start a process in its own console window."""
    log(f"Starting {label}...")
    if new_window:
        proc = subprocess.Popen(
            [exe],
            cwd=cwd or os.path.dirname(exe),
            creationflags=subprocess.CREATE_NEW_CONSOLE,
        )
    else:
        proc = subprocess.Popen(
            [exe],
            cwd=cwd or os.path.dirname(exe),
        )
    return proc

# ── Step 1: MySQL ─────────────────────────────────────────────────────────────

def start_mysql():
    if is_port_open(MYSQL_HOST, MYSQL_PORT):
        log("MySQL already running.", tag="+")
        return None

    if not os.path.isfile(MYSQL_EXE):
        log(f"MySQL not found at: {MYSQL_EXE}", tag="!")
        sys.exit(1)

    log("Starting MySQL 8.4...")
    proc = subprocess.Popen(
        [
            MYSQL_EXE,
            f"--datadir={MYSQL_DATADIR}",
            f"--bind-address={MYSQL_HOST}",
            f"--port={MYSQL_PORT}",
        ],
        creationflags=subprocess.CREATE_NEW_CONSOLE,
    )

    if not wait_for_port(MYSQL_HOST, MYSQL_PORT, MYSQL_TIMEOUT, "MySQL"):
        log("MySQL failed to start. Check that the data directory exists.", tag="!")
        log(f"  Data dir: {MYSQL_DATADIR}", tag="!")
        proc.terminate()
        sys.exit(1)

    return proc

# ── Step 2: bnetserver ────────────────────────────────────────────────────────

def start_bnetserver():
    if not os.path.isfile(BNETSERVER_EXE):
        log(f"bnetserver not found at: {BNETSERVER_EXE}", tag="!")
        sys.exit(1)

    proc = start_process(BNETSERVER_EXE, "bnetserver", cwd=BIN_DIR)
    if not wait_for_port(MYSQL_HOST, BNET_PORT, BNET_TIMEOUT, "bnetserver"):
        log("bnetserver did not open its port in time. It may still be starting.", tag="~")
        # Non-fatal — bnetserver port detection can be unreliable
    return proc

# ── Step 3: worldserver ───────────────────────────────────────────────────────

def start_worldserver():
    if not os.path.isfile(WORLDSERVER_EXE):
        log(f"worldserver not found at: {WORLDSERVER_EXE}", tag="!")
        sys.exit(1)

    proc = start_process(WORLDSERVER_EXE, "worldserver", cwd=BIN_DIR)
    if not wait_for_port(MYSQL_HOST, WORLD_PORT, WORLD_TIMEOUT, "worldserver"):
        log("worldserver did not open its port in time.", tag="~")
        log("  If this is the first run, make sure data files (maps/dbc/vmaps) are extracted.", tag="~")
    return proc

# ── Step 4: WoW client ────────────────────────────────────────────────────────

def start_client():
    if not os.path.isfile(CLIENT_EXE):
        log(f"WoW client not found at: {CLIENT_EXE}", tag="!")
        log("Skipping client launch.", tag="~")
        return None

    log("Launching WoW Legion client...")
    proc = subprocess.Popen(
        [CLIENT_EXE],
        cwd=os.path.dirname(CLIENT_EXE),
        creationflags=subprocess.CREATE_NEW_CONSOLE,
    )
    log("Client started.", tag="+")
    return proc

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  AshamaneCore Legion Private Server Launcher")
    print("=" * 60)

    procs = []

    mysql_proc = start_mysql()
    if mysql_proc:
        procs.append(("MySQL", mysql_proc))

    bnet_proc = start_bnetserver()
    procs.append(("bnetserver", bnet_proc))

    # Give bnetserver a moment to register with auth DB before worldserver starts
    time.sleep(2)

    world_proc = start_worldserver()
    procs.append(("worldserver", world_proc))

    # Give worldserver a moment to finish registering sessions after port opens
    time.sleep(5)

    client_proc = start_client()
    if client_proc:
        procs.append(("client", client_proc))

    print()
    log("All processes launched. Press Ctrl+C to shut everything down.", tag="*")
    print("=" * 60)

    try:
        # Keep script alive; monitor for any process that dies unexpectedly
        while True:
            time.sleep(5)
            for name, proc in procs:
                if proc and proc.poll() is not None:
                    log(f"{name} exited with code {proc.returncode}.", tag="!")
            procs = [(n, p) for n, p in procs if p and p.poll() is None]
            if not procs:
                log("All processes have exited.", tag="*")
                break
    except KeyboardInterrupt:
        print()
        log("Shutting down all server processes...")
        for name, proc in reversed(procs):
            if proc and proc.poll() is None:
                log(f"  Terminating {name}...")
                proc.terminate()
        # Give processes a few seconds to exit gracefully
        time.sleep(3)
        for name, proc in reversed(procs):
            if proc and proc.poll() is None:
                log(f"  Force-killing {name}...")
                proc.kill()
        log("Done.", tag="+")

if __name__ == "__main__":
    main()
