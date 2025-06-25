#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <entitylump>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2items_stocks>
#include <multicolors>
#include <stocksoup/tf/entity_prefabs>

public Plugin myinfo = 
{
    name = "Hide'n'Seek",
    author = "Heapons (Commissioned by ArJay)",
    description = "Made for ArJay's event.",
    version = "1.0.0",
    url = "https://github.com/Heapons/Hide-N-Seek"
};

bool g_bIsJuggernaut[MAXPLAYERS+1];

static const char g_szGamemodeEntities[][] = {
    "tf_gamerules",
    "tf_logic_arena",
    "tf_logic_competitive",
    "tf_logic_mannpower",
    "tf_logic_multiple_escort",
    "tf_logic_koth",
    "tf_logic_medieval",
    "tf_logic_training_mode",
    "tf_logic_hybrid_ctf_cp",
    "tf_logic_raid",
    "tf_logic_boss_battle",
    "tf_logic_mann_vs_machine",
    "tf_logic_holiday",
    "tf_logic_on_holiday",
    "tf_logic_minigames",
    "tf_base_minigame",
    "tf_halloween_minigame",
    "tf_halloween_minigame_falling_platforms",
    "tf_logic_robot_destruction",
    "tf_logic_player_destruction", 
    "team_train_watcher",
    "mapobj_cart_dispenser",
    "team_control_point",
    "team_round_timer"
};

ConVar g_hJuggernautSteamID;
ConVar g_hJuggernautMaxHealth;
ConVar g_hJuggernautSignalInterval;
ConVar g_hJuggernautSignalDuration;
Handle g_hJuggernautSignalTimer = null;

public void OnPluginStart()
{
    g_hJuggernautSteamID = CreateConVar("sm_juggernaut", "76561199186248824", "SteamID64 of the only player allowed to be Juggernaut", FCVAR_NONE, true, 0.0, false, 0.0);
    g_hJuggernautMaxHealth = CreateConVar("sm_juggernaut_maxhealth", "300", "Max health for Juggernaut.");
    g_hJuggernautSignalInterval = CreateConVar("sm_juggernaut_signal_interval", "2.0", "Interval in minutes to signal Juggernaut's position with an outline (0 = disabled).");
    g_hJuggernautSignalDuration = CreateConVar("sm_juggernaut_signal_duration", "3.0", "Duration in seconds for Juggernaut's outline signal.");

    AutoExecConfig(true, "hide_n_seek", "arjay");

    AddCommandListener(BlacklistCommands, "kill");
    AddCommandListener(BlacklistCommands, "explode");
    //AddCommandListener(BlacklistCommands, "changeteam");
    AddCommandListener(BlacklistCommands, "jointeam");
}

public void OnMapInit()
{
    for (int i = 0; i < sizeof(g_szGamemodeEntities); i++)
    {
        int index = -1;
        while ((index = FindEntityLumpEntryByClassname(g_szGamemodeEntities[i], index)) != -1)
        {
            EntityLump.Erase(index);
            index--;
        }
    }

    int lumpIndex = -1;
    while ((lumpIndex = FindEntityLumpEntryByClassname("func_respawnroomvisualizer", lumpIndex)) != -1)
    {
        EntityLump.Erase(lumpIndex);
        lumpIndex--;
    }

    int index = EntityLump.Append();
    EntityLumpEntry entry = EntityLump.Get(index);
    entry.Append("classname", "tf_logic_arena");
    delete entry;
}

public void OnMapStart()
{
    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);

    HookEvent("teamplay_round_start", OnRoundPreStart);
    HookEvent("arena_round_start", OnRoundStart);
    HookEvent("teamplay_round_win", OnRoundEnd);
    HookEvent("post_inventory_application", OnLoadoutRefresh);
}

public void OnMapEnd()
{
    UnhookEvent("teamplay_round_start", OnRoundPreStart);
    UnhookEvent("arena_round_start", OnRoundStart);
    UnhookEvent("teamplay_round_win", OnRoundEnd);
    UnhookEvent("post_inventory_application", OnLoadoutRefresh);

    StopJuggernautSignalTimer();
}

public void OnRoundPreStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            TF2_ChangeClientTeam(i, TFTeam_Red);
        }
    }
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    /* Player Manager */
    int bluePlayer = 0;
    int playerCount = 0;
    int players[MAXPLAYERS+1];

    for (int i = 1; i <= MaxClients; i++)
        g_bIsJuggernaut[i] = false;

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            if (allowedSteamID[0] != '\0')
            {
                char clientSteamID[32];
                GetClientAuthId(i, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));
                if (StrEqual(clientSteamID, allowedSteamID))
                    players[playerCount++] = i;
            }
            else
            {
                players[playerCount++] = i;
            }
        }
    }

    if (playerCount == 0)
        return;

    bluePlayer = players[GetRandomInt(0, playerCount - 1)];

    g_bIsJuggernaut[bluePlayer] = true;

    for (int i = 0; i < playerCount; i++)
    {
        int client = players[i];
        if (client == bluePlayer)
        {
            if (TF2_GetClientTeam(client) != TFTeam_Blue)
                TF2_ChangeClientTeam(client, TFTeam_Blue);

            TF2_SetPlayerClass(client, TFClass_Spy, true, true);
            TF2_RespawnPlayer(client);
        }
        else if (TF2_GetClientTeam(client) != TFTeam_Red)
        {
            TF2_ChangeClientTeam(client, TFTeam_Red);

            int weapon = GetPlayerWeaponSlot(client, 4);
            if (weapon > MaxClients && IsValidEntity(weapon))
            {
                ServerCommand("sig_addattr #%i 48 0.0", GetClientUserId(client));
            }
        }
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !IsPlayerAlive(i))
        {
            TF2_RespawnPlayer(i);
        }
    }

    /* Forcefully Open All Gates */
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "func_door")) != -1)
    {
        if (!IsValidEntity(entity))
            continue;

        AcceptEntityInput(entity, "Open");
    }

    // Start Juggernaut signal timer
    StartJuggernautSignalTimer();
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            TF2_ChangeClientTeam(i, (i % 2 == 0) ? TFTeam_Red : TFTeam_Blue);

        if (g_bIsJuggernaut[i])
        {
            ServerCommand("sig_addattr #%i 48 0", GetClientUserId(i));
            ServerCommand("sig_addattr #%i 517 0", GetClientUserId(i));
        }
    }

    // Stop Juggernaut signal timer
    StopJuggernautSignalTimer();
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientInGame(client))
        return;

    TF2_ChangeClientTeam(client, TFTeam_Unassigned);
}

public void OnLoadoutRefresh(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    if (g_bIsJuggernaut[client] && TF2_GetPlayerClass(client) == TFClass_Spy)
    {
        int weapon = GetPlayerWeaponSlot(client, 4); // Spy Watch Slot
        if (weapon > MaxClients && IsValidEntity(weapon))
        {
            int weapon_index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
            float attribute_value = (weapon_index == 59) ? 1.0 : 2.0;

            ServerCommand("sig_addattr #%i 48 %f", GetClientUserId(client), attribute_value);

            int knife = GetPlayerWeaponSlot(client, 2); // Melee Slot
            if (knife > MaxClients && IsValidEntity(knife))
            {
                int knife_index = GetEntProp(knife, Prop_Send, "m_iItemDefinitionIndex");
                int baseHealth = g_hJuggernautMaxHealth.IntValue;
                if (knife_index == 356)
                {
                    ServerCommand("sig_addattr #%i 517 %d", GetClientUserId(client), baseHealth + 55 - 125);
                }
                else
                {
                    ServerCommand("sig_addattr #%i 517 %d", GetClientUserId(client), baseHealth - 125);
                }
            }
        }
    }
    // Do not reset attributes for RED players here
}

public Action BlacklistCommands(int client, const char[] command, int argc)
{
    if (client > 0 && IsClientInGame(client))
    {
        PrintToChat(client, "You may not perform this command.");
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

/* Helper Functions */
stock int FindEntityLumpEntryByClassname(const char[] classname, int start = -1)
{
    int len = EntityLump.Length();
    for (int i = start + 1; i < len; i++)
    {
        EntityLumpEntry entry = EntityLump.Get(i);
        char value[64];
        entry.GetNextKey("classname", value, sizeof(value), -1);
        bool match = StrEqual(value, classname, false);
        delete entry;
        if (match)
            return i;
    }
    return -1;
}

// --- Juggernaut Signal Timer Logic ---

void StartJuggernautSignalTimer()
{
    StopJuggernautSignalTimer();

    float interval = g_hJuggernautSignalInterval.FloatValue;
    if (interval > 0.0)
    {
        // Convert minutes to seconds
        g_hJuggernautSignalTimer = CreateTimer(interval * 60.0, JuggernautSignalTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

void StopJuggernautSignalTimer()
{
    if (g_hJuggernautSignalTimer != null)
    {
        KillTimer(g_hJuggernautSignalTimer);
        g_hJuggernautSignalTimer = null;
    }
}

public Action JuggernautSignalTimer(Handle timer)
{
    int juggernaut = -1;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_bIsJuggernaut[i] && IsClientInGame(i) && IsPlayerAlive(i))
        {
            juggernaut = i;
            break;
        }
    }

    if (juggernaut == -1)
        return Plugin_Continue;

    int glow = TF2_AttachBasicGlow(juggernaut);
    if (glow != -1 && IsValidEntity(glow))
    {
        float duration = g_hJuggernautSignalDuration.FloatValue;
        CreateTimer(duration, RemoveGlowEntity, EntIndexToEntRef(glow));
    }

    return Plugin_Continue;
}

public Action RemoveGlowEntity(Handle timer, any entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if (entity > 0 && IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }
    return Plugin_Stop;
}