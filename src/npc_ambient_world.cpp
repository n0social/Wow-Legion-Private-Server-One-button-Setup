/*
 * npc_ambient_world.cpp
 * BotSystem Phase 5 -- Dynamic Ambient NPC Population + Fake-Player AI
 *
 * SPAWNING  (PlayerScript):
 *   - OnUpdateZone fires for every zone/subzone change
 *   - Counts ambient summons within 200y; spawns 3-6 if below minimum
 *   - Works on ALL non-instanced, non-capital outdoor zones (including DK start)
 *   - Spawns player-archetype NPCs (Warrior/Mage/Rogue/etc.) with class subnames
 *
 * BEHAVIOUR (CreatureScript  "npc_ambient_ai"):
 *   State-machine loop:  IDLE -> WANDER -> ACTIVITY -> HUNT -> SOCIAL
 *
 *   IDLE     - stand still 3-7s; play a random flavour emote
 *   WANDER   - walk via MovePoint to a fresh position near home (15-60y)
 *              terrain Z is looked up so they land on the ground
 *   ACTIVITY - role-specific anim: spellcast (mage/healer), work-sheathed
 *              (warrior/rogue), bow-shot (hunter), eating (default)
 *   HUNT     - scan 40y for any non-player hostile creature not in combat;
 *              rush over and actually attack it (real melee / emotes)
 *   SOCIAL   - face the closest ambient NPC within 20y and wave/cheer/bow;
 *              the target waves back half the time
 *
 * Template pools (NPC entries in the world DB):
 *   Alliance  9500080-9500084   Warrior / Paladin / Mage / Hunter / Rogue
 *   Horde     9500085-9500089   Warrior / Shaman  / Hunter/ Mage / Rogue
 *   Neutral   9500090-9500094   Death Knight / Demon Hunter / Druid / Monk / Priest
 *   Scourge pool removed -- all zones now use the player-like entries above
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Random.h"
#include "TemporarySummon.h"
#include "ObjectAccessor.h"
#include "ScriptedCreature.h"
#include "MotionMaster.h"
#include "Creature.h"
#include "Unit.h"
#include "Log.h"
#include "Chat.h"
#include "ScriptedGossip.h"
#include "DatabaseEnv.h"
#include "Group.h"
#include "GroupMgr.h"
#include <string>
#include <chrono>
#include <mutex>
#include <map>
#include <set>
#include <cmath>
#include <vector>

// ============================================================
//  Name generator - culture-appropriate pools
// ============================================================
namespace AmbientNames
{
    static const char* ALLIANCE[] = {
        "Aldric","Arwyn","Brennan","Caelan","Davin","Elara","Fenwick","Gareth",
        "Haldor","Idris","Jaryn","Kaelan","Lira","Maren","Neth","Owyn","Petra",
        "Quill","Raena","Seldra","Toven","Uric","Vael","Wynn","Xara","Yona","Zael",
        "Borin","Bryndis","Caldric","Dara","Edric","Fenna","Gilda","Holt","Ira",
        "Jeth","Kira","Lodric","Mira","Niall","Odric","Pell","Rann","Sigrid","Thal",
        "Ulric","Vara","Weiss","Ylva","Aeron","Beric","Corra","Dwyn","Elan","Fyrd",
        "Gwynn","Hadric","Ilara","Jorel","Kaera","Lorin","Myra","Naric","Orla","Perin",
    };
    static constexpr uint32 ALLIANCE_COUNT = 63;

    static const char* HORDE_ORC[] = {
        "Goruk","Krag","Morg","Nathrak","Rakh","Skrag","Throk","Urgok","Vrak","Zug",
        "Grish","Lurg","Mash","Nok","Org","Pug","Rok","Snag","Trog","Urg",
        "Grak","Hurk","Kash","Murk","Prak","Rorg","Snork","Targ","Urk","Vorg",
        "Bruk","Drakh","Fruk","Gnak","Hurg","Kruk","Lurk","Nrug","Pruk","Sruk",
        "Drakka","Grokka","Hrakka","Krukka","Mrakka","Nrakka","Prikka","Rrakka",
    };
    static constexpr uint32 HORDE_ORC_COUNT = 48;

    static const char* HORDE_TROLL[] = {
        "Zek'han","Rokhan","Jen'ari","Khal'dun","Maz'jin",
        "Zen'kaji","Dal'jin","Fal'zul","Gal'jin","Hal'zek","Jal'zan","Kal'jin",
        "Lal'zul","Mal'dun","Nal'jin","Pal'zek","Ral'zul","Sal'jin","Tal'dun",
        "Ulu'zek","Val'jin","Wal'zul","Xal'jin","Yul'zek","Zal'jin","Bel'dun",
        "Drek'zul","Frek'jin","Grek'zul","Hrek'jin",
    };
    static constexpr uint32 HORDE_TROLL_COUNT = 30;

    static const char* HORDE_TAUREN[] = {
        "Hamuul","Trag","Mak","Brightmane","Longrunner",
        "Earthcaller","Ragehoof","Plainstrider","Moonsong","Rivermane",
        "Stonehoof","Bloodhoof","Thunderhorn","Sunwalker","Highmountain",
        "Grimtotem","Windsong","Dustwalker","Ironhorn","Swiftmane",
        "Skychaser","Mudhorn","Rockhide","Firewalker","Cloudhoof",
    };
    static constexpr uint32 HORDE_TAUREN_COUNT = 25;

    static const char* HORDE_BELF[] = {
        "Selvaine","Aelindris","Vaelris","Thelris","Kaelindra","Sylvaris",
        "Faelindra","Maelindra","Naelindra","Raelindra","Daelindra","Baelindra",
        "Sorel","Lorel","Morel","Norel","Porel","Rorel","Torel","Vorel",
        "Lyria","Myria","Pyria","Tyria","Xyria","Zyria",
    };
    static constexpr uint32 HORDE_BELF_COUNT = 26;

    static const char* NEUTRAL[] = {
        "Aelindra","Faelyn","Sylara","Varethis","Thalion","Isaeryn","Vaelrin",
        "Celindra","Xarven","Ylarven","Zarven","Alorin","Belorin","Celorin",
        "Elorin","Felorin","Gelorin","Helorin","Ilorin","Jalorin","Kalorin",
        "Morthalun","Yunlan","Drevok","Thandris","Shandris","Maiev","Tyrande",
        "Illidan","Akama","Xuen","Niuzao","Yulon","Chiroptera","Wavemender",
        "Aravel","Brevel","Crevel","Drevel","Erevel","Frevel","Grevel",
    };
    static constexpr uint32 NEUTRAL_COUNT = 42;

    static const char* SURNAMES[] = {
        "Swiftblade","Stonehammer","Ironhide","Dawnseeker","Shadowstep",
        "Frostweave","Emberforge","Stormcaller","Nightwhisper","Sunfire",
        "Moonveil","Ashvale","Grimshaw","Brightmantle","Coldwater",
        "Dustrunner","Ironclad","Lightbringer","Windwalker","Duskmantle",
        "Emberveil","Frostfall","Goldvein","Highpeak","Ironwood",
        "Jadewing","Kindlesmith","Longstride","Mistwalker","Northwind",
        "Oakenshield","Pinecrest","Quickstrike","Redthorn","Silverbow",
        "Thornwood","Veilshroud","Wardbane","Zenith","Flamestrike",
        "Crystalvein","Dawnblade","Earthshaker","Farseer","Galeforce",
    };
    static constexpr uint32 SURNAMES_COUNT = 45;

    static std::string Roll(uint32 npcEntry)
    {
        const char* first = nullptr;
        if (npcEntry >= 9500080 && npcEntry <= 9500084)
            first = ALLIANCE[urand(0, ALLIANCE_COUNT - 1)];
        else if (npcEntry >= 9500085 && npcEntry <= 9500086)
            first = HORDE_ORC[urand(0, HORDE_ORC_COUNT - 1)];
        else if (npcEntry == 9500087)
            first = HORDE_TROLL[urand(0, HORDE_TROLL_COUNT - 1)];
        else if (npcEntry == 9500088)
            first = HORDE_BELF[urand(0, HORDE_BELF_COUNT - 1)];
        else if (npcEntry == 9500089)
            first = HORDE_TAUREN[urand(0, HORDE_TAUREN_COUNT - 1)];
        else
            first = NEUTRAL[urand(0, NEUTRAL_COUNT - 1)];

        std::string name = first ? first : "Adventurer";
        if (urand(0, 99) < 35)
        {
            name += " ";
            name += SURNAMES[urand(0, SURNAMES_COUNT - 1)];
        }
        return name;
    }
}

// ============================================================
//  Spawn configuration
// ============================================================
static constexpr uint32 MIN_AMBIENT_NPCS  = 4;
static constexpr uint32 SPAWN_COUNT_MIN   = 3;
static constexpr uint32 SPAWN_COUNT_MAX   = 6;
static constexpr float  SEARCH_RADIUS     = 200.f;
static constexpr float  SPREAD_RADIUS     = 60.f;
static constexpr uint32 DESPAWN_TIME_MS   = 30 * 60 * 1000;
static constexpr uint32 SPAWN_THROTTLE_MS = 30 * 1000;

static constexpr uint32 ALLIANCE_POOL[5] = { 9500080, 9500081, 9500082, 9500083, 9500084 };
static constexpr uint32 HORDE_POOL[5]    = { 9500085, 9500086, 9500087, 9500088, 9500089 };
static constexpr uint32 NEUTRAL_POOL[5]  = { 9500090, 9500091, 9500092, 9500093, 9500094 };

static const std::set<uint32> SKIP_ZONES =
{
    1519, 1637, 1657, 1638, 1539, 362,
    14,   3487, 3557,
    4395, 7502, 7563,
};

static const std::set<uint32> STARTING_ZONES =
{
    12,   // Elwynn Forest
    1,    // Dun Morogh
    141,  // Teldrassil
    3524, // Azuremyst Isle
    4987, // Gilneas
    85,   // Tirisfal Glades
    215,  // Mulgore
    3430, // Eversong Woods
    5170, // Wandering Isle
    4815, // Lost Isles
};

static constexpr uint32 MIN_STARTING_NPCS  = 10;
static constexpr uint32 STARTING_SPAWN_MIN = 10;
static constexpr uint32 STARTING_SPAWN_MAX = 18;

// ============================================================
//  Race display ID pools (zone-based NPC appearance).
//  All IDs verified against creature_model_info in this DB build.
//  Primary pool = ~70 % of spawns (dominant zone race).
//  Secondary pool = ~30 % (faction racial variety).
//
//  Verified display IDs (BoundingRadius ~0.3-0.4 = humanoid-scale):
//   Human    : 3167, 3258, 3257   (Stormwind Guards)
//   Dwarf    : 1598, 1608, 3524   (Ironforge Guards/Mountaineer)
//   Night Elf: 4408, 4841, 4842   (NE Trainer, NE Sentinel)
//   Draenei  : 11650,11652,16602  (Draenei Refugee, Vindicator)
//   Worgen   : 29317,29318,30215  (Gilnean Militia)
//   Forsaken : 2858, 2855, 1648   (Tirisfal Deathguards)
//   Tauren   : 1678, 3797         (Tauren Druid Trainers)
//   Blood Elf: 18980,18982,18981  (BE Reclaimer / Surveyor)
//   Orc      : 4573, 4551         (World Orc humanoids)
//   Goblin   : 7107, 7109, 7108   (Goblin Mercenary / Engineer)
//   Troll    : 4609, 1882, 15574  (World Troll Trainers, Darkspear)
//   Pandaren : 29421,29422        (Wandering Isle)
//   Gnome    : 2490, 2891, 3562   (Gnome Racer, World Gnome Trainers)
// ============================================================
struct ZoneRacePool
{
    std::vector<uint32> primary;    // heavily weighted
    std::vector<uint32> secondary;  // lightly weighted (racial variety)
};

static const std::map<uint32, ZoneRacePool> ZONE_RACE_MAP =
{
    // ---- Alliance starting zones ----
    { 12,   { {3167,3258,3167,3258,3257}, {1598,1608,4408,4841} } },     // Elwynn:     Human, Dwarf/NElf
    { 1,    { {1598,1608,3524,1598,1608}, {3167,3258,2490,2891} } },     // Dun Morogh: Dwarf, Human/Gnome
    { 141,  { {4408,4841,4842,4408,4841}, {3167,3258,11650,11652} } },   // Teldrassil: Night Elf, Human/Draenei
    { 3524, { {11650,11652,16602,11650},  {4408,4841,3167,3258} } },     // Azuremyst:  Draenei, NElf/Human
    { 4987, { {29317,29318,30215,3167},   {1598,1608,4408,4841} } },     // Gilneas:    Worgen+Human, Dwarf/NElf
    // ---- Horde starting zones ----
    { 85,   { {2858,2855,1648,2858,2855}, {18980,18982,4573,4551,1678} } }, // Tirisfal:  Forsaken, BElf/Orc/Tauren
    { 215,  { {1678,3797,1678,3797},      {4573,4551,2858,2855,18980} } },  // Mulgore:   Tauren, Orc/Forsaken/BElf
    { 3430, { {18980,18982,18981,18980},  {4573,4551,2858,2855,1678} } },   // Eversong:  Blood Elf, Orc/Forsaken/Tauren
    { 4815, { {7107,7109,4573,4551,7108}, {1678,2858,2855,18980} } },       // LostIsles: Goblin+Orc, Tauren/Forsaken/BElf
    // ---- Neutral ----
    { 5170, { {29421,29422,29421,29422},  {3167,3258,4573,4551} } },     // WanderingIsle: Pandaren, Human/Orc
};

// ============================================================
//  Companion system
// ============================================================
static constexpr uint32 COMPANION_GOSSIP_SENDER  = 200;
static constexpr uint32 COMPANION_ACTION_HIRE    = 1;
static constexpr uint32 COMPANION_ACTION_DISMISS = 2;
static constexpr uint32 COMPANION_ACTION_STATUS  = 3;
static constexpr uint32 COMPANION_ACTION_CLOSE   = 4;  // "Goodbye" - just close menu

static uint32 CompanionXpForLevel(uint32 level)
{
    return 100u * level * (1u + level / 10u);
}

static uint32 CompanionXpGain(uint32 killedLevel)
{
    return killedLevel * 5u + 10u;
}

struct CompanionData
{
    ObjectGuid  ownerGuid;
    uint32      currentLevel = 1;
    uint32      xp           = 0;
    uint32      xpNeeded     = 110;
    std::string displayName;          // cached at HireCompanion time
};

static std::mutex                          s_companionMutex;
static std::map<ObjectGuid, CompanionData> s_companions;

static void RegisterCompanion(ObjectGuid guid, ObjectGuid owner, uint32 level,
    std::string const& name)
{
    std::lock_guard<std::mutex> lk(s_companionMutex);
    CompanionData d;
    d.ownerGuid    = owner;
    d.currentLevel = level;
    d.xp           = 0;
    d.xpNeeded     = CompanionXpForLevel(level);
    d.displayName  = name;
    s_companions[guid] = d;
}

static void UnregisterCompanion(ObjectGuid guid)
{
    std::lock_guard<std::mutex> lk(s_companionMutex);
    s_companions.erase(guid);
}

static bool IsCompanion(ObjectGuid guid)
{
    std::lock_guard<std::mutex> lk(s_companionMutex);
    return s_companions.count(guid) > 0;
}

static bool AwardCompanionXP(ObjectGuid guid, uint32 gain, uint32& outNewLevel)
{
    std::lock_guard<std::mutex> lk(s_companionMutex);
    auto it = s_companions.find(guid);
    if (it == s_companions.end())
    {
        outNewLevel = 0;
        return false;
    }
    CompanionData& d = it->second;
    d.xp += gain;
    if (d.xp >= d.xpNeeded && d.currentLevel < 110)
    {
        d.xp      -= d.xpNeeded;
        ++d.currentLevel;
        d.xpNeeded = CompanionXpForLevel(d.currentLevel);
        outNewLevel = d.currentLevel;
        return true;
    }
    outNewLevel = d.currentLevel;
    return false;
}

static bool GetCompanionData(ObjectGuid guid, CompanionData& out)
{
    std::lock_guard<std::mutex> lk(s_companionMutex);
    auto it = s_companions.find(guid);
    if (it == s_companions.end())
        return false;
    out = it->second;
    return true;
}

// ============================================================
//  DB persistence helpers (character_companion table)
//  PK = (player_guid, name)  -- one row per companion per player.
// ============================================================
static void DB_SaveCompanion(uint32 playerGuid, Creature* companion,
    uint32 level, uint32 xp)
{
    // Escape companion name to prevent SQL injection
    std::string esc = companion->GetName();
    CharacterDatabase.EscapeString(esc);
    CharacterDatabase.PExecute(
        "REPLACE INTO character_companion "
        "(player_guid, name, entry, level, xp, display_id) "
        "VALUES (%u, '%s', %u, %u, %u, %u)",
        playerGuid, esc.c_str(),
        companion->GetEntry(), level, xp,
        companion->GetDisplayId());
}

static void DB_UpdateCompanionXP(uint32 playerGuid,
    std::string const& name, uint32 level, uint32 xp)
{
    std::string esc = name;
    CharacterDatabase.EscapeString(esc);
    CharacterDatabase.PExecute(
        "UPDATE character_companion SET level=%u, xp=%u "
        "WHERE player_guid=%u AND name='%s'",
        level, xp, playerGuid, esc.c_str());
}

static void DB_DeleteCompanion(uint32 playerGuid, std::string const& name)
{
    std::string esc = name;
    CharacterDatabase.EscapeString(esc);
    CharacterDatabase.PExecute(
        "DELETE FROM character_companion WHERE player_guid=%u AND name='%s'",
        playerGuid, esc.c_str());
}

static void DB_DeleteAllCompanions(uint32 playerGuid)
{
    CharacterDatabase.PExecute(
        "DELETE FROM character_companion WHERE player_guid=%u", playerGuid);
}

// Group helper: disband the player's party if this was the last companion.
// Call AFTER the companion has already been removed from s_companions.
static void TryDisbandGroupIfLast(Player* owner, ObjectGuid removedGuid)
{
    if (!owner)
        return;
    bool hasMore = false;
    {
        std::lock_guard<std::mutex> lk(s_companionMutex);
        for (auto const& kv : s_companions)
            if (kv.first != removedGuid && kv.second.ownerGuid == owner->GetGUID())
                { hasMore = true; break; }
    }
    if (!hasMore)
    {
        if (Group* grp = owner->GetGroup())
            if (grp->GetMembersCount() <= 1)
                grp->Disband();
    }
}

// ============================================================
//  Role system - drives which emotes/AI each archetype uses
// ============================================================
enum AmbientRole : uint8
{
    AMBIENT_WARRIOR = 0,
    AMBIENT_MAGE    = 1,
    AMBIENT_HEALER  = 2,
    AMBIENT_HUNTER  = 3,
    AMBIENT_ROGUE   = 4,
    AMBIENT_DEFAULT = 5,
};

static AmbientRole GetRoleForEntry(uint32 entry)
{
    switch (entry)
    {
        case 9500080: case 9500085: return AMBIENT_WARRIOR;
        case 9500081: case 9500086: return AMBIENT_HEALER;
        case 9500082: case 9500088: return AMBIENT_MAGE;
        case 9500083: case 9500087: return AMBIENT_HUNTER;
        case 9500084: case 9500089: return AMBIENT_ROGUE;
        default:                    return AMBIENT_DEFAULT;
    }
}

static uint32 GetCombatEmote(AmbientRole role)
{
    switch (role)
    {
        case AMBIENT_WARRIOR: case AMBIENT_ROGUE: return EMOTE_ONESHOT_ATTACK1H;
        case AMBIENT_HUNTER:                  return EMOTE_ONESHOT_ATTACK_BOW;
        case AMBIENT_MAGE:                    return EMOTE_ONESHOT_SPELL_CAST_W_SOUND;
        case AMBIENT_HEALER:                  return EMOTE_ONESHOT_SPELL_CAST;
        default:                           return EMOTE_ONESHOT_ATTACK1H;
    }
}

// ============================================================
//  AI state machine
// ============================================================
enum AmbientState : uint8
{
    STATE_IDLE     = 0,
    STATE_WANDER   = 1,
    STATE_ACTIVITY = 2,
    STATE_HUNT     = 3,
    STATE_SOCIAL   = 4,
};

struct npc_ambient_aiAI : public ScriptedAI
{
    npc_ambient_aiAI(Creature* c) : ScriptedAI(c),
        _state(STATE_IDLE),
        _timer(urand(1000, 3000)),
        _role(GetRoleForEntry(c->GetEntry())),
        _homeX(c->GetPositionX()),
        _homeY(c->GetPositionY()),
        _homeZ(c->GetPositionZ()),
        _combatEmoteTimer(0),
        _moveDone(true),
        _isCompanion(false),
        _ownerGuid()
    {
        // Ambient NPCs must never auto-engage; HUNT state handles targeting explicitly.
        me->SetReactState(REACT_PASSIVE);
    }

    void Reset() override
    {
        _state = STATE_IDLE;
        _timer = urand(2000, 5000);
        _moveDone = true;
        // Ambient NPCs must never auto-aggro; only HUNT state calls AttackStart.
        // Companion mode switches to REACT_DEFENSIVE in HireCompanion.
        if (!_isCompanion)
            me->SetReactState(REACT_PASSIVE);
    }

    void EnterCombat(Unit* /*who*/) override { }

    void MovementInform(uint32 type, uint32 /*id*/) override
    {
        if (type == POINT_MOTION_TYPE)
            _moveDone = true;
    }

    void UpdateAI(uint32 diff) override
    {
        // ─── Companion mode ──────────────────────────────────────────
        if (_isCompanion)
        {
            Player* owner = ObjectAccessor::GetPlayer(*me, _ownerGuid);
            if (!owner || !owner->IsAlive())
            {
                _isCompanion = false;
                _ownerGuid   = ObjectGuid::Empty;
                UnregisterCompanion(me->GetGUID());
                Reset();
                return;
            }

            // Companion in combat — fight
            if (me->IsInCombat())
            {
                if (!me->GetVictim())
                {
                    if (Unit* t = owner->GetVictim())
                        AttackStart(t);
                    return;
                }
                if (_combatEmoteTimer <= diff)
                {
                    me->HandleEmoteCommand(GetCombatEmote(_role));
                    _combatEmoteTimer = urand(2200, 4000);
                }
                else
                    _combatEmoteTimer -= diff;
                DoMeleeAttackIfReady();
                return;
            }

            // Assist owner if they pulled something
            if (owner->IsInCombat())
            {
                if (Unit* t = owner->GetVictim())
                {
                    me->GetMotionMaster()->Clear();
                    AttackStart(t);
                    return;
                }
            }

            // Follow owner
            if (me->GetDistance(owner) > 5.0f)
            {
                me->GetMotionMaster()->Clear();
                me->GetMotionMaster()->MoveFollow(owner, 3.0f, float(M_PI));
            }
            return;
        }
        // ─── End companion mode ───────────────────────────────────────

        // If actually in melee combat, fight and show combat emotes
        if (me->IsInCombat())
        {
            if (!me->GetVictim())
            {
                _state = STATE_IDLE;
                _timer = urand(2000, 4000);
                return;
            }
            if (_combatEmoteTimer <= diff)
            {
                me->HandleEmoteCommand(GetCombatEmote(_role));
                _combatEmoteTimer = urand(2200, 4000);
            }
            else
                _combatEmoteTimer -= diff;

            DoMeleeAttackIfReady();
            return;
        }

        // State timer countdown
        if (_timer <= diff)
        {
            _timer = 0;
            _SelectNextState();
        }
        else
            _timer -= diff;
    }

    // ── Companion state (public so gossip handler can access) ──────────────
    bool        _isCompanion;
    ObjectGuid  _ownerGuid;
    std::string _myCompanionName;  // name cached at hire, used in kill messages

    void HireCompanion(Player* player, uint32 restoreLevel = 0, uint32 restoreXp = 0)
    {
        if (_isCompanion)
            return;
        _isCompanion       = true;
        _ownerGuid         = player->GetGUID();
        _myCompanionName   = me->GetName();   // cache NOW - template name already overridden by SetName()
        uint32 lvl         = restoreLevel > 0 ? restoreLevel : (uint32)me->getLevel();

        RegisterCompanion(me->GetGUID(), player->GetGUID(), lvl, _myCompanionName);

        // Inject restored XP if this is a login-restore
        if (restoreXp > 0 && restoreLevel > 0)
        {
            std::lock_guard<std::mutex> lk(s_companionMutex);
            auto it = s_companions.find(me->GetGUID());
            if (it != s_companions.end())
            {
                it->second.xp       = restoreXp;
                it->second.xpNeeded = CompanionXpForLevel(lvl);
            }
        }

        me->SetReactState(REACT_DEFENSIVE);
        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MoveFollow(player, 3.0f, float(M_PI));

        // Guardian mode: SetCreatorGUID links the NPC to the player server-side
        // WITHOUT occupying the pet frame. This means no conflict with Hunter pets,
        // Warlock demons, or any other class pet. The NPC simply follows and assists.
        me->SetCreatorGUID(player->GetGUID());

        // Create a real WoW party group so group loot/XP rules apply and
        // the blue [Party] channel activates. Only create if not already grouped.
        if (!player->GetGroup())
        {
            Group* grp = new Group();
            if (grp->Create(player))
                sGroupMgr->AddGroup(grp);
            else
                delete grp;
        }

        // Save to DB (skip on restore to avoid overwriting the restored XP)
        if (restoreLevel == 0)
            DB_SaveCompanion(player->GetGUID().GetCounter(), me, lvl, 0);
    }

    void DismissCompanion()
    {
        if (!_isCompanion)
            return;
        Player* owner     = ObjectAccessor::GetPlayer(*me, _ownerGuid);
        ObjectGuid myGuid = me->GetGUID();
        if (owner)
            DB_DeleteCompanion(owner->GetGUID().GetCounter(), _myCompanionName);
        UnregisterCompanion(myGuid);
        _isCompanion     = false;
        _ownerGuid       = ObjectGuid::Empty;
        _myCompanionName.clear();
        me->SetCreatorGUID(ObjectGuid::Empty);
        me->SetReactState(REACT_PASSIVE);
        me->GetMotionMaster()->Clear();
        // Disband the group if this was the last companion
        TryDisbandGroupIfLast(owner, myGuid);
        Reset();
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (_isCompanion)
        {
            Player*    owner  = ObjectAccessor::GetPlayer(*me, _ownerGuid);
            ObjectGuid myGuid = me->GetGUID();
            if (owner)
                DB_DeleteCompanion(owner->GetGUID().GetCounter(), _myCompanionName);
            UnregisterCompanion(myGuid);
            _isCompanion     = false;
            _ownerGuid       = ObjectGuid::Empty;
            _myCompanionName.clear();
            TryDisbandGroupIfLast(owner, myGuid);
        }
    }

    // When the companion lands a killing blow:
    //   • owner player gets XP
    //   • this companion and ALL other companions of the same owner get XP
    // Creatures cannot join WoW Groups, so we manually share XP here.
    void KilledUnit(Unit* killed) override
    {
        if (!_isCompanion || !killed)
            return;

        Player* owner = ObjectAccessor::GetPlayer(*me, _ownerGuid);
        if (!owner)
            return;

        uint32 xpGain = CompanionXpGain((uint32)killed->getLevel());

        // 1. Award XP to the owner player
        owner->GiveXP(xpGain, nullptr);

        // 2. Award XP to THIS companion
        uint32 myNewLevel = 0;
        bool   myLvlUp   = AwardCompanionXP(me->GetGUID(), xpGain, myNewLevel);
        std::string killerName = _myCompanionName.empty() ? me->GetName() : _myCompanionName;
        ChatHandler(owner->GetSession()).PSendSysMessage(
            "|cff00ccff[Party]|r %s scored a kill \xe2\x80\x94 all companions gained %u XP!",
            killerName.c_str(), xpGain);
        if (myLvlUp)
        {
            me->SetLevel(myNewLevel);
            ChatHandler(owner->GetSession()).PSendSysMessage(
                "|cffffd700[Companion]|r %s reached level %u!",
                killerName.c_str(), myNewLevel);
        }

        // 3. Award XP to ALL other companions of the same owner
        std::vector<ObjectGuid> siblings;
        {
            std::lock_guard<std::mutex> lk(s_companionMutex);
            for (auto const& kv : s_companions)
                if (kv.first != me->GetGUID() &&
                    kv.second.ownerGuid == _ownerGuid)
                    siblings.push_back(kv.first);
        }
        for (ObjectGuid sibGuid : siblings)
        {
            Creature* sib = ObjectAccessor::GetCreature(*me, sibGuid);
            if (!sib || !sib->IsAlive())
                continue;
            uint32 sibNewLevel = 0;
            bool   sibLvlUp   = AwardCompanionXP(sibGuid, xpGain, sibNewLevel);
            CompanionData sibCd;
            std::string sibName = (GetCompanionData(sibGuid, sibCd) && !sibCd.displayName.empty())
                ? sibCd.displayName : sib->GetName();
            ChatHandler(owner->GetSession()).PSendSysMessage(
                "|cff00ccff[Party]|r %s gained %u XP  (Lv %u)",
                sibName.c_str(), xpGain, sibNewLevel);
            if (sibLvlUp)
            {
                sib->SetLevel(sibNewLevel);
                ChatHandler(owner->GetSession()).PSendSysMessage(
                    "|cffffd700[Companion]|r %s reached level %u!",
                    sibName.c_str(), sibNewLevel);
            }
        }
    }

private:
    AmbientState _state;
    uint32       _timer;
    AmbientRole  _role;
    float        _homeX, _homeY, _homeZ;
    uint32       _combatEmoteTimer;
    bool         _moveDone;

    // Weight table: WANDER=38%, IDLE=27%, HUNT=18%, ACTIVITY=12%, SOCIAL=5%
    void _SelectNextState()
    {
        uint32 roll = urand(0, 99);
        if      (roll < 38) _DoWander();
        else if (roll < 65) _DoIdle();
        else if (roll < 83) _DoHunt();
        else if (roll < 95) _DoActivity();
        else                _DoSocial();
    }

    // ---- IDLE -----------------------------------------------
    void _DoIdle()
    {
        _state = STATE_IDLE;
        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MoveIdle();

        static const uint32 IDLE_EMOTES[] = {
            EMOTE_ONESHOT_WAVE, EMOTE_ONESHOT_CHEER, EMOTE_ONESHOT_LAUGH,
            EMOTE_ONESHOT_BOW,  EMOTE_ONESHOT_POINT, EMOTE_ONESHOT_SALUTE,
            EMOTE_ONESHOT_ROAR, EMOTE_ONESHOT_EAT_NO_SHEATHE,
        };
        me->HandleEmoteCommand(IDLE_EMOTES[urand(0, 7)]);
        _timer = urand(3000, 7000);
    }

    // ---- WANDER ---------------------------------------------
    // Walk to a random point near home using MovePoint so it looks purposeful
    // and won't loop forever like MoveRandom does.
    void _DoWander()
    {
        _state    = STATE_WANDER;
        _moveDone = false;

        float angle  = frand(0.f, float(M_PI) * 2.f);
        float dist   = frand(15.f, SPREAD_RADIUS);
        float destX  = _homeX + std::cos(angle) * dist;
        float destY  = _homeY + std::sin(angle) * dist;
        float destZ  = _homeZ;

        // Sample terrain height so they land on the ground
        if (Map* m = me->GetMap())
        {
            float h = m->GetHeight(me->GetPhaseShift(), destX, destY, _homeZ + 5.f, true, 50.f);
            if (h > INVALID_HEIGHT + 1.f)
                destZ = h;
        }

        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MovePoint(1, destX, destY, destZ);

        // Allow enough time for a walk at ~2.5 m/s across up to 60y (~24s max)
        _timer = urand(6000, 14000);
    }

    // ---- ACTIVITY -------------------------------------------
    void _DoActivity()
    {
        _state = STATE_ACTIVITY;
        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MoveIdle();

        switch (_role)
        {
            case AMBIENT_MAGE:
            case AMBIENT_HEALER:
                me->HandleEmoteCommand(EMOTE_ONESHOT_SPELL_PRECAST);
                _timer = urand(7000, 11000);
                break;
            case AMBIENT_WARRIOR:
            case AMBIENT_ROGUE:
                me->HandleEmoteCommand(EMOTE_STATE_WORK_SHEATHED);
                _timer = urand(4000, 8000);
                break;
            case AMBIENT_HUNTER:
                me->HandleEmoteCommand(EMOTE_ONESHOT_ATTACK_BOW);
                _timer = urand(2500, 5000);
                break;
            default:
                me->HandleEmoteCommand(EMOTE_ONESHOT_EAT_NO_SHEATHE);
                _timer = urand(5000, 9000);
                break;
        }
    }

    // ---- HUNT -----------------------------------------------
    // Find and attack any visible hostile creature not currently fighting
    // a real player.  Gives them dynamic, unpredictable looking fights.
    void _DoHunt()
    {
        _state = STATE_HUNT;

        Creature* target = nullptr;

        // Walk through nearby world objects looking for a valid target.
        // Only attack creatures that are ACTIVELY hostile to us (not merely
        // "not friendly") and appear to be wild/combat mobs, never city NPCs.
        std::list<Creature*> nearList;
        me->GetCreatureListInGrid(nearList, 40.f);
        for (Creature* c : nearList)
        {
            if (target)
                break;
            if (c == me || !c->IsAlive())
                continue;
            // Must be genuinely hostile to us — skips neutral city NPCs entirely
            if (!c->IsHostileTo(me))
                continue;
            if (c->IsSummon())
                continue;
            if (c->IsInCombat())
                continue;
            // Skip other ambient NPCs
            if (c->GetEntry() >= 9500080 && c->GetEntry() <= 9500094)
                continue;
            // Skip critters
            if (c->IsCritter())
                continue;
            // Skip city/friendly service NPCs (vendors, trainers, quest givers, gossip)
            if (c->IsVendor() || c->IsTrainer() || c->IsQuestGiver() || c->IsGossip())
                continue;
            // Only attack mobs that the engine has flagged as aggressive
            // (passive/defensive mobs sitting in towns are excluded)
            if (c->GetReactState() != REACT_AGGRESSIVE)
                continue;
            target = c;
        }

        if (target)
        {
            me->GetMotionMaster()->Clear();
            AttackStart(target);
            _timer = urand(10000, 20000);
            return;
        }

        // No hostile mobs nearby – fall back to wander
        _DoWander();
    }

    // ---- SOCIAL ---------------------------------------------
    void _DoSocial()
    {
        _state = STATE_SOCIAL;
        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MoveIdle();

        Creature* buddy = nullptr;
        std::list<Creature*> socialList;
        me->GetCreatureListInGrid(socialList, 20.f);
        for (Creature* c : socialList)
        {
            if (buddy) break;
            if (c == me || !c->IsAlive()) continue;
            if (c->GetEntry() < 9500080 || c->GetEntry() > 9500094) continue;
            buddy = c;
        }

        if (buddy)
        {
            me->SetFacingToObject(buddy);
            static const uint32 SOCIAL_EMOTES[] = {
                EMOTE_ONESHOT_WAVE, EMOTE_ONESHOT_POINT,
                EMOTE_ONESHOT_LAUGH, EMOTE_ONESHOT_BOW, EMOTE_ONESHOT_CHEER,
            };
            me->HandleEmoteCommand(SOCIAL_EMOTES[urand(0, 4)]);
            if (urand(0, 1))
                buddy->HandleEmoteCommand(EMOTE_ONESHOT_WAVE_NO_SHEATHE);
        }

        _timer = urand(3000, 6000);
    }
};

// ============================================================
//  CreatureScript  (AI + gossip)
// ============================================================
class npc_ambient_ai : public CreatureScript
{
public:
    npc_ambient_ai() : CreatureScript("npc_ambient_ai") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_ambient_aiAI(creature);
    }

    // ------ Gossip: Hello (open menu) -------------------------
    bool OnGossipHello(Player* player, Creature* creature) override
    {
        npc_ambient_aiAI* ai = CAST_AI(npc_ambient_aiAI, creature->AI());
        if (!ai)
            return false;

        if (ai->_isCompanion && ai->_ownerGuid == player->GetGUID())
        {
            // Already companion of this player - show status + options
            CompanionData cd;
            if (GetCompanionData(creature->GetGUID(), cd))
            {
                std::string status = "Level " + std::to_string(cd.currentLevel) +
                    "  \xe2\x80\x94  XP: " + std::to_string(cd.xp) +
                    " / " + std::to_string(cd.xpNeeded);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, status,
                    COMPANION_GOSSIP_SENDER, COMPANION_ACTION_STATUS);
            }
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "You are free to go. Return to your own path.",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_DISMISS);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "Goodbye.",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_CLOSE);
        }
        else if (!ai->_isCompanion)
        {
            // Available to hire - offer Join and a safe exit
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                "Join my party!",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_HIRE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "Goodbye.",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_CLOSE);
        }
        else
        {
            // Busy with another player
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "I am already assisting someone else.",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_STATUS);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "Goodbye.",
                COMPANION_GOSSIP_SENDER, COMPANION_ACTION_CLOSE);
        }

        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    // ------ Gossip: Select (player chose an option) -----------
    bool OnGossipSelect(Player* player, Creature* creature,
        uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        npc_ambient_aiAI* ai = CAST_AI(npc_ambient_aiAI, creature->AI());
        if (!ai)
            return false;

        switch (action)
        {
            case COMPANION_ACTION_HIRE:
                ai->HireCompanion(player);
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Companion]|r %s joins your party!",
                    creature->GetName().c_str());
                break;
            case COMPANION_ACTION_DISMISS:
                ai->DismissCompanion();
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffaaaaaa[Companion]|r %s has departed.",
                    creature->GetName().c_str());
                break;
            case COMPANION_ACTION_CLOSE:
                // Just close — no action needed (gossip already closed above)
                break;
            default:
                break;
        }
        return true;
    }
};

// ============================================================
//  Spawn helpers
// ============================================================
static uint32 PickAmbientEntry(Player* player)
{
    uint32 mapId = player->GetMapId();
    // Broken Isles / Argus -- neutral only
    if (mapId == 1220 || mapId == 1116)
        return NEUTRAL_POOL[urand(0, 4)];

    // 70% same-faction, 30% neutral for variety
    uint32 roll = urand(0, 9);
    if (player->GetTeam() == ALLIANCE)
        return (roll < 7) ? ALLIANCE_POOL[urand(0, 4)] : NEUTRAL_POOL[urand(0, 4)];
    if (player->GetTeam() == HORDE)
        return (roll < 7) ? HORDE_POOL[urand(0, 4)]    : NEUTRAL_POOL[urand(0, 4)];
    return NEUTRAL_POOL[urand(0, 4)];
}

static uint32 CountNearbyAmbient(Player* player)
{
    uint32 count = 0;
    for (uint32 e = 9500080; e <= 9500094; ++e)
    {
        std::list<Creature*> nl;
        GetCreatureListWithEntryInGrid(nl, player, e, SEARCH_RADIUS);
        count += static_cast<uint32>(nl.size());
    }
    return count;
}

static Position RandomPositionNear(Player* player)
{
    float angle = frand(0.f, float(M_PI) * 2.f);
    float dist  = frand(15.f, SPREAD_RADIUS);
    float x = player->GetPositionX() + std::cos(angle) * dist;
    float y = player->GetPositionY() + std::sin(angle) * dist;
    float z = player->GetPositionZ();

    if (Map* m = player->GetMap())
    {
        float h = m->GetHeight(player->GetPhaseShift(), x, y, z + 5.f, true, 50.f);
        if (h > INVALID_HEIGHT + 1.f)
            z = h;
    }
    return { x, y, z, frand(0.f, float(M_PI) * 2.f) };
}

// ============================================================
//  PlayerScript
// ============================================================
class AmbientWorldPlayerScript : public PlayerScript
{
public:
    AmbientWorldPlayerScript() : PlayerScript("AmbientWorldPlayerScript") { }

    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        if (!player) return;
        {
            std::lock_guard<std::mutex> lk(s_mutex);
            s_nextSpawnTime.erase(player->GetGUID());
        }
        // Restore a previously-hired companion that was saved on logout
        RestoreCompanionForPlayer(player);
    }

    void OnUpdateZone(Player* player, uint32 newZone, uint32 /*newArea*/, uint32 /*oldZone*/) override
    {
        if (!player || !player->IsInWorld() || !player->IsAlive()) return;
        if (player->getLevel() == 0) return;
        TrySpawnAmbient(player, newZone);
    }

    void OnLogout(Player* player) override
    {
        if (!player) return;
        {
            std::lock_guard<std::mutex> lk(s_mutex);
            s_nextSpawnTime.erase(player->GetGUID());
        }
        // Snapshot the companion's current XP/level before it despawns
        SaveCompanionOnLogout(player);
    }

    void OnCreatureKill(Player* killer, Creature* killed) override
    {
        if (!killer || !killed)
            return;

        uint32 xpGain = CompanionXpGain((uint32)killed->getLevel());

        // Award XP to every companion owned by this player that is nearby
        for (uint32 entry = 9500080; entry <= 9500094; ++entry)
        {
            std::list<Creature*> cList;
            GetCreatureListWithEntryInGrid(cList, killer, entry, 50.f);
            for (Creature* companion : cList)
            {
                if (!companion || !companion->IsAlive())
                    continue;
                if (!IsCompanion(companion->GetGUID()))
                    continue;
                CompanionData cd;
                if (!GetCompanionData(companion->GetGUID(), cd))
                    continue;
                if (cd.ownerGuid != killer->GetGUID())
                    continue;

                uint32 newLevel = 0;
                bool   leveledUp = AwardCompanionXP(companion->GetGUID(), xpGain, newLevel);

                // Use the cached display name; fall back to GetName() if needed
                std::string cname = (!cd.displayName.empty()) ? cd.displayName
                                                              : companion->GetName();
                ChatHandler(killer->GetSession()).PSendSysMessage(
                    "|cff00ccff[Party]|r %s gained %u XP  (Lv %u)",
                    cname.c_str(), xpGain, newLevel);

                if (leveledUp)
                {
                    companion->SetLevel(newLevel);
                    ChatHandler(killer->GetSession()).PSendSysMessage(
                        "|cffffd700[Companion]|r %s reached level %u!",
                        cname.c_str(), newLevel);
                }
            }
        }
    }

private:
    static std::mutex s_mutex;
    static std::map<ObjectGuid, std::chrono::steady_clock::time_point> s_nextSpawnTime;

    // ---- Login restore: spawn all saved companions near the player ----
    void RestoreCompanionForPlayer(Player* player)
    {
        QueryResult result = CharacterDatabase.PQuery(
            "SELECT entry, level, xp, name, display_id "
            "FROM character_companion WHERE player_guid = %u",
            player->GetGUID().GetCounter());
        if (!result)
            return;

        uint32 count = 0;
        do
        {
            Field*      f      = result->Fetch();
            uint32      entry  = f[0].GetUInt32();
            uint32      lvl    = f[1].GetUInt32();
            uint32      xp     = f[2].GetUInt32();
            std::string name   = f[3].GetString();
            uint32      dispId = f[4].GetUInt32();

            if (!sObjectMgr->GetCreatureTemplate(entry))
                continue;

            Position pos = RandomPositionNear(player);
            TempSummon* s = player->SummonCreature(entry, pos,
                TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, DESPAWN_TIME_MS);
            if (!s) continue;

            uint8 slvl = (uint8)std::min(lvl, 110u);
            s->SetLevel(slvl);
            uint32 hp = 100u * slvl * slvl + 500u * slvl + 1000u;
            s->SetMaxHealth(hp);
            s->SetHealth(hp);
            // Keep damage proportional to level
            s->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, float(slvl) * 0.90f);
            s->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, float(slvl) * 1.35f);
            s->UpdateDamagePhysical(BASE_ATTACK);
            s->SetName(name);
            if (dispId)
                s->SetDisplayId(dispId);

            npc_ambient_aiAI* ai = CAST_AI(npc_ambient_aiAI, s->AI());
            if (!ai) continue;

            ai->HireCompanion(player, slvl, xp);
            ++count;

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ff00[Companion]|r %s is waiting nearby.", name.c_str());
        }
        while (result->NextRow());

        TC_LOG_INFO("scripts", "AmbientNPC: restored %u companion(s) for %s",
            count, player->GetName().c_str());
    }

    // ---- Logout save: snapshot XP/level for ALL companions before they despawn ----
    void SaveCompanionOnLogout(Player* player)
    {
        for (uint32 entry = 9500080; entry <= 9500094; ++entry)
        {
            std::list<Creature*> cList;
            GetCreatureListWithEntryInGrid(cList, player, entry, 100.f);
            for (Creature* companion : cList)
            {
                if (!IsCompanion(companion->GetGUID()))
                    continue;
                CompanionData cd;
                if (!GetCompanionData(companion->GetGUID(), cd))
                    continue;
                if (cd.ownerGuid != player->GetGUID())
                    continue;

                // Use cached displayName (not GetName() which may return template name)
                std::string savedName = (!cd.displayName.empty()) ? cd.displayName
                                                                  : companion->GetName();
                DB_UpdateCompanionXP(player->GetGUID().GetCounter(),
                    savedName, cd.currentLevel, cd.xp);
                // continue - save ALL companions, not just the first one
            }
        }
    }

    void TrySpawnAmbient(Player* player, uint32 zoneId)
    {
        Map* map = player->GetMap();
        if (!map) return;

        // Skip true instances (dungeons/raids)
        if (map->Instanceable())
            return;

        if (player->InBattleground())
            return;

        if (SKIP_ZONES.count(zoneId))
            return;

        // Per-player throttle
        {
            std::lock_guard<std::mutex> lk(s_mutex);
            auto now = std::chrono::steady_clock::now();
            auto it  = s_nextSpawnTime.find(player->GetGUID());
            if (it != s_nextSpawnTime.end() && now < it->second)
                return;
            s_nextSpawnTime[player->GetGUID()] = now + std::chrono::milliseconds(SPAWN_THROTTLE_MS);
        }

        uint32 existing = CountNearbyAmbient(player);
        TC_LOG_INFO("scripts", "AmbientNPC: [%s] zone %u map %u existing=%u",
            player->GetName().c_str(), zoneId, player->GetMapId(), existing);

        bool   isStarting   = STARTING_ZONES.count(zoneId) > 0;
        uint32 minThreshold = isStarting ? MIN_STARTING_NPCS : MIN_AMBIENT_NPCS;

        if (existing >= minThreshold)
            return;

        uint32 spawnMin = isStarting ? STARTING_SPAWN_MIN : SPAWN_COUNT_MIN;
        uint32 spawnMax = isStarting ? STARTING_SPAWN_MAX : SPAWN_COUNT_MAX;
        uint32 needed   = urand(spawnMin, spawnMax);
        uint32 spawned = 0;
        for (uint32 i = 0; i < needed; ++i)
        {
            uint32 entry = PickAmbientEntry(player);

            if (!sObjectMgr->GetCreatureTemplate(entry))
            {
                TC_LOG_ERROR("scripts", "AmbientNPC: missing template for entry %u", entry);
                continue;
            }

            Position pos = RandomPositionNear(player);
            TempSummon* s = player->SummonCreature(entry, pos, TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, DESPAWN_TIME_MS);
            if (!s) continue;

            // Scale level to player's level ±5 for natural variation
            uint8 plvl  = player->getLevel();
            int32 offset = (int32)urand(0, 10) - 5;  // -5 to +5
            uint8 lvl   = (uint8)std::max(1, std::min(110, (int32)plvl + offset));
            s->SetLevel(lvl);

            // Scale HP to level so NPCs aren't trivially one-shot at endgame
            // Formula: 100*L^2 + 500*L + 1000  (~1 M HP at L100, ~1.3 M at L110)
            {
                uint32 hp = uint32(100u * lvl * lvl + 500u * lvl + 1000u);
                s->SetMaxHealth(hp);
                s->SetHealth(hp);
            }

            // Scale weapon damage to level — the template default (BaseAttackTime=0,
            // Legion scaling) can produce wildly wrong values at low levels.
            // Keep damage modest so these NPCs are flavour, not balance-breakers.
            {
                float minDmg = float(lvl) * 0.90f;
                float maxDmg = float(lvl) * 1.35f;
                s->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, minDmg);
                s->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, maxDmg);
                s->UpdateDamagePhysical(BASE_ATTACK);
            }

            // Culture-appropriate random name
            s->SetName(AmbientNames::Roll(entry));

            // Zone-based race appearance: 70 % primary race, 30 % racial variety
            {
                auto raceIt = ZONE_RACE_MAP.find(zoneId);
                if (raceIt != ZONE_RACE_MAP.end())
                {
                    const ZoneRacePool& pool = raceIt->second;
                    bool usePrimary = !pool.primary.empty() && (urand(0, 9) < 7);
                    const std::vector<uint32>& ids = usePrimary ? pool.primary : pool.secondary;
                    if (!ids.empty())
                        s->SetDisplayId(ids[urand(0, uint32(ids.size()) - 1u)]);
                }
            }

            ++spawned;
        }

        TC_LOG_INFO("scripts", "AmbientNPC: [%s] spawned %u/%u in zone %u (map %u)",
            player->GetName().c_str(), spawned, needed, zoneId, player->GetMapId());
    }
};

std::mutex AmbientWorldPlayerScript::s_mutex;
std::map<ObjectGuid, std::chrono::steady_clock::time_point> AmbientWorldPlayerScript::s_nextSpawnTime;

// ============================================================
//  Registration
// ============================================================
void AddSC_npc_ambient_world()
{
    new npc_ambient_ai();
    new AmbientWorldPlayerScript();
}
