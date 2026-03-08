# WoW Legion — One Stop Setup (Client Required)

A ready-to-run World of Warcraft: Legion (patch 7.3.5) private server built on **AshamaneCore**, featuring custom ambient world NPCs that wander, hunt, socialize — and can be hired as intelligent companions that follow you, fight alongside you, gain XP and level up.

## Features

- Full Legion 7.3.5 private server (AshamaneCore)
- **Ambient World NPCs**: 15 unique named companions (warriors, mages, rogues, druids, monks, demon hunters, etc.) that populate starting zones with dynamic behavior
- **Companion System**: Hire NPCs to join your party, they follow you, assist in combat, and gain XP independently
- **Party integration**: Hiring an NPC creates a real WoW party group (blue `[Party]` chat, group loot)
- Multi-companion support (hire several at once)
- Companions persist through logout/login
- One-click automated setup

---

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 or 11 (64-bit) | Must be able to "run as administrator" |
| WoW 7.3.5 client | Hellgarve or any 7.3.5 build — you provide this |
| Internet connection | For downloading server files and databases (~650MB total) |
| ~10 GB free disk space | For databases, maps, and extracted game data |
| 30–60 minutes | For first-time setup (map extraction takes time) |

> **MySQL** will be installed automatically if not already present (via `winget`).

---

## Setup (First Time Only)

### Step 1 — Download this repo

Click **Code → Download ZIP** on this GitHub page, then extract it anywhere. Example:
```
C:\WoWServer\
```

### Step 2 — Place your WoW client

Copy (or move) your WoW 7.3.5 client folder **into** the downloaded folder and rename it `WoW_Client`:
```
C:\WoWServer\
├── setup.bat
├── start_server.bat
├── ...
└── WoW_Client\          ← your client goes here
    └── Wow.exe
```

### Step 3 — Run setup.bat as Administrator

Right-click **`setup.bat`** → **Run as administrator**

The setup script will automatically:
1. Check for (and install) MySQL if needed
2. Download server binaries from this GitHub Release (~60 MB)
3. Download the AshamaneCore world databases (~500 MB)
4. Import all databases
5. Apply custom patches (companion system, ambient NPCs)
6. Extract maps, DBCs, and visual maps from your WoW client
7. Patch your WoW client to connect to `localhost`
8. Configure everything

> ☕ Step 6 (map extraction) takes **15–30 minutes**. Go make a coffee.
> ⏰ Optional movement maps (mmaps) take **2–6 hours** but aren't required to play.

---

## Starting the Server

After setup is complete, just run:
```
start_server.bat
```

Wait about **60 seconds** for the world to finish loading, then open:
```
WoW_Client\Wow.exe
```

Log in with the account credentials you set during setup.

---

## Creating Additional Accounts

Run `create_account.bat` for a guided wizard.

Or, while the server is running, type these commands **directly into the worldserver console window**:
```
account create USERNAME PASSWORD
bnetaccount create EMAIL@example.com PASSWORD
bnetaccount link EMAIL@example.com USERNAME
```

To make someone a GM (admin):
```
account set gmlevel USERNAME 3 -1
```

---

## The Companion System

### Hiring a companion
Walk up to any of the 15 custom ambient NPCs in the starting zones and right-click them. Select **"Join my party!"** to hire them.

### What companions do
- **Follow** you at a close distance
- **Defend** you and assist in combat automatically
- **Hunt** nearby hostile creatures on their own (in a radius around you)
- **Gain XP** from kills — both when you kill things and when they kill things
- **Level up** independently, gaining health and damage as they grow
- **Socialize** with other nearby NPCs when idle

### Dismissing a companion
Right-click the NPC → **"Dismiss"**. Their level and XP are saved — they'll be at the same level next time you play.

### Multiple companions
You can hire more than one. All companions in your party share kill XP with each other.

---

## Stopping the Server

Run `stop_server.bat` or simply close the worldserver and bnetserver windows.

---

## Troubleshooting

**"Could not connect to MySQL"** during setup  
→ Make sure MySQL service is running: `Win+R` → `services.msc` → find "MySQL80" → Start

**"Failed to download server binaries"**  
→ Check that this GitHub Release has a `server_binaries.zip` asset attached.

**Server crashes immediately on start**  
→ Check `server\Server.log` for error details.  
→ Most crashes are DB connection issues — verify worldserver.conf has the right password.

**World loads but I can't log in**  
→ Make sure your client was patched (connection_patcher.exe).  
→ Verify account was created with the worldserver console commands above.

**Map extraction step fails**  
→ The extractor needs the full WoW client with all patches. Verify `WoW_Client\Wow.exe` exists and the `Data\` folder is present.

---

## File Structure (after setup)

```
WoWServer/
├── setup.bat              ← Run once to set everything up
├── start_server.bat       ← Start the server
├── stop_server.bat        ← Stop the server
├── create_account.bat     ← Create a new account
├── sql/                   ← Custom SQL patches (applied by setup)
├── WoW_Client/            ← Your WoW 7.3.5 client (you provide)
└── server/                ← Created by setup
    ├── worldserver.exe
    ├── bnetserver.exe
    ├── worldserver.conf
    ├── bnetserver.conf
    └── data/
        ├── maps/
        ├── vmaps/
        ├── dbc/
        ├── gt/
        └── cameras/
```

---

## For Repo Owners / Developers

The `src/npc_ambient_world.cpp` file contains the full source for the ambient NPC and companion system.

To package new server binaries after a code change:
1. Build AshamaneCore (Visual Studio 2022 + vcpkg)
2. Run `prepare_release.bat` to create `server_binaries.zip`
3. Upload to a new GitHub Release
4. Update the `RELEASE_TAG` in `setup.bat`

---

## Credits

- [AshamaneCore](https://github.com/AshamaneProject/AshamaneCore) — Legion 7.3.5 server core (AGPL-3.0)
- [TrinityCore](https://github.com/TrinityCore/TrinityCore) — Base framework
- Custom ambient NPC + companion system by the repo owner
