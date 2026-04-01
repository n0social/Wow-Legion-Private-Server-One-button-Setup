# WoW Legion — One-Button Setup (Client Required)

A ready-to-run World of Warcraft: Legion (patch 7.3.5) private server built on **AshamaneCore**, featuring custom ambient world NPCs that wander, hunt, and socialize — and can be hired as intelligent companions that follow you, fight alongside you, gain XP, and level up.

---

## Features

- Full Legion 7.3.5 private server (AshamaneCore / TrinityCore)
- **Ambient World NPCs** — 15 unique named companions (warriors, mages, rogues, druids, monks, demon hunters, etc.) populating starting zones with dynamic behavior
- **Companion System** — Hire NPCs to join your party; they follow you, assist in combat, and gain XP independently
- **Party integration** — Hiring an NPC creates a real WoW party group (blue `[Party]` chat, group loot)
- Multi-companion support (hire several at once)
- Companions persist between sessions
- Everything managed from a single script — `play.bat`

---

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 or 11 (64-bit) | Must be able to run as administrator |
| WoW 7.3.5 client | Hellgarve or any 7.3.5 build — **you provide this** |
| MySQL 8.x | Installed automatically via `winget` if not present |
| Internet connection | ~650 MB download (databases + binaries) |
| ~10 GB free disk space | Databases, maps, and extracted game data |

---

## ⚠️ Important — Add a Windows Defender Exclusion First

**Do this before running setup.** The server loads hundreds of large data files on every startup. Without an exclusion, Windows Defender scans each file as it's read, which can make the world server take **10–20 minutes** to finish loading instead of 2–5 minutes.

1. Open **Windows Security** → **Virus & threat protection**
2. Under *Virus & threat protection settings* click **Manage settings**
3. Scroll to **Exclusions** → **Add or remove exclusions** → **Add a folder**
4. Select the `server\` folder inside this repo

> `setup.bat` will also attempt to add this exclusion automatically when it runs (requires admin rights).

---

## Setup (First Time Only)

### Step 1 — Download this repo

Click **Code → Download ZIP** on this page and extract it anywhere, for example:
```
C:\WoWServer\
```

### Step 2 — Place your WoW client

Copy your WoW 7.3.5 client folder anywhere on your PC. The setup script will find it automatically, or prompt you if it can't.

Supported client exe names: `Wow.exe`, `Wow-64.exe`, `Hellgarve.Legion-64.exe`

### Step 3 — Run setup.bat as Administrator

Right-click **`setup.bat`** → **Run as administrator**

Setup will automatically:
1. Install MySQL if needed
2. Download server binaries and world databases (~650 MB)
3. Import all databases and apply patches
4. Extract maps, DBCs, and VMaps from your WoW client
5. Patch your client to connect to `localhost`
6. Add a Windows Defender exclusion for the `server\` folder
7. Create your first game account

> ☕ Map extraction (step 4) takes **15–30 minutes**.

---

## Playing

After setup, everything runs from one file:

**Right-click `play.bat` → Run as administrator**

The menu gives you:
- **[1] Launch Server + Play** — starts MySQL, bnetserver, worldserver, then opens your WoW client
- **[2] Create Account** — add a new game account while the server is running
- **[3] Stop Server** — cleanly shuts down both server processes

### First launch load time

The world server loads a large amount of data on startup. Expect **5–15 minutes** depending on your drive speed and whether Windows Defender is scanning files. Adding the Defender exclusion (see top of README) is the most effective way to reduce this.

The play.bat menu will tell you when the server is ready. Do not open WoW until it says so.

---

## The Companion System

### Hiring a companion
Walk up to any of the 15 custom ambient NPCs in the starting zones and right-click → **"Join my party!"**

### What companions do
- **Follow** you closely
- **Defend** you and assist in combat automatically
- **Hunt** nearby hostile creatures on their own
- **Gain XP** from kills — both yours and their own
- **Level up** independently, gaining health and damage
- **Socialize** with nearby NPCs when idle

### Dismissing a companion
Right-click → **"Dismiss"**. Level and XP are saved for next time.

### Multiple companions
Hire as many as you like. All companions share kill XP with each other.

---

## GM / Admin Commands

While the server is running, type these directly into the **worldserver console window**:

```
account create USERNAME PASSWORD
account set gmlevel USERNAME 3 -1
```

---

## Troubleshooting

**World server takes forever to load**
→ Add a Windows Defender exclusion for the `server\` folder (see top of this README).
→ Defender scanning every `.db2` and `.dll` on each launch is the most common cause of slow startup.

**"Could not connect to MySQL" during setup**
→ `Win+R` → `services.msc` → find MySQL80 or MySQL84 → Start

**Server crashes immediately**
→ Check `server\Server.log` — most crashes are DB connection issues.
→ Verify `worldserver.conf` DB connection strings are correct.

**"Failed to download server binaries"**
→ Check that this GitHub Release has a `server_binaries.zip` asset attached.

**Client shows "Server is offline" after server fully loads**
→ Confirm the connection patcher ran during setup (it patches your client exe to point to `127.0.0.1`).
→ Check `server\Bnet.log` — bnetserver must be running and listening on port 1119.

**Map extraction fails**
→ Verify your WoW client has a `Data\` folder with the full game data present.

---

## File Structure

```
WoWServer/
├── setup.bat          ← Run once (first-time setup)
├── play.bat           ← Run every time you want to play
├── sql/               ← Database patches (applied automatically by setup)
├── server/            ← Server binaries and config
│   ├── worldserver.exe
│   ├── bnetserver.exe
│   ├── worldserver.conf
│   ├── bnetserver.conf
│   └── data/          ← Extracted maps/DBCs (created by setup)
└── logs/              ← Session logs from play.bat
```

---

## For Developers

Source for the ambient NPC and companion system: `src/npc_ambient_world.cpp`

To ship new binaries:
1. Build AshamaneCore (Visual Studio 2022 + vcpkg)
2. Run `prepare_release.bat` to produce `server_binaries.zip`
3. Upload to a new GitHub Release and update `RELEASE_TAG` in `setup.bat`

---

## Credits

- [AshamaneCore](https://github.com/AshamaneProject/AshamaneCore) — Legion 7.3.5 server core (AGPL-3.0)
- [TrinityCore](https://github.com/TrinityCore/TrinityCore) — Base framework
- Custom ambient NPC + companion system by the repo owner
