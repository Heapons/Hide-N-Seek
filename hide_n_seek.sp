#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <entitylump>
#include <tf2>
#include <tf2_stocks>
#include <multicolors>
#include <stocksoup/sdkports/util>

public Plugin myinfo = 
{
    name = "Hide'n'Seek",
    author = "Heapons (Commissioned by ArJay)",
    description = "Made for ArJay's event.",
    version = "1.0.0",
    url = "https://github.com/Heapons/Hide-N-Seek"
};

#define MEDIC_ALERT "ui/medic_alert.wav"

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
    "team_control_point_master",
    "team_round_timer",
    "item_teamflag",
    "trigger_capture_area"
};

ConVar g_hJuggernautSteamID;
ConVar g_hJuggernautMaxHealth;
ConVar g_hJuggernautSignalInterval;
ConVar g_hJuggernautSetupTime;
ConVar g_hJuggernautRoundTime;
Handle g_hJuggernautSignalTimer = null;

public void OnPluginStart()
{
    g_hJuggernautSteamID = CreateConVar("sm_juggernaut", "76561199186248824", "SteamID64 of the only player allowed to be Juggernaut", FCVAR_NONE, true, 0.0, false, 0.0);
    g_hJuggernautMaxHealth = CreateConVar("sm_juggernaut_maxhealth", "300", "Max health for Juggernaut.");
    g_hJuggernautSignalInterval = CreateConVar("sm_juggernaut_signal_interval", "2.0", "Interval in minutes to signal Juggernaut's position with an outline (0 = disabled).");
    g_hJuggernautSetupTime = CreateConVar("sm_juggernaut_setup_time", "300", "Setup Time length (in seconds).");
    g_hJuggernautRoundTime = CreateConVar("sm_juggernaut_round_time", "300", "Round Time length (in seconds).");

    AutoExecConfig(true, "hide_n_seek", "arjay");

    RegConsoleCmd("sm_ready", Command_Ready);
}

public void OnMapInit()
{
    int lumpIndex = -1;

    for (int i = 0; i < sizeof(g_szGamemodeEntities); i++)
    {
        int index = -1;
        while ((index = FindEntityLumpEntryByClassname(g_szGamemodeEntities[i], index)) != -1)
        {
            EntityLump.Erase(index);
            index--;
        }
    }

    static const char removeClasses[][] = {
        "func_respawnroomvisualizer",
        "func_respawnroom",
        "func_regenerate",
        "trigger_multiple"
    };

    for (int i = 0; i < sizeof(removeClasses); i++)
    {
        lumpIndex = -1;
        while ((lumpIndex = FindEntityLumpEntryByClassname(removeClasses[i], lumpIndex)) != -1)
        {
            EntityLump.Erase(lumpIndex);
            lumpIndex--;
        }
    }

    while ((lumpIndex = FindEntityLumpEntryByClassname("prop_dynamic", lumpIndex)) != -1)
    {
        EntityLumpEntry entry = EntityLump.Get(lumpIndex);
        char model[PLATFORM_MAX_PATH];
        entry.GetNextKey("model", model, sizeof(model), -1);
        if (StrEqual(model, "models/props_gameplay/cap_point_base.mdl", false))
        {
            EntityLump.Erase(lumpIndex);
            lumpIndex--;
        }
        delete entry;
    }

    CreateSetupTimer();
}

public void OnMapStart()
{
    PrecacheSound(MEDIC_ALERT, true);

    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);
    FindConVar("mp_forceautoteam").SetBool(true);

    HookEvent("teamplay_round_start", OnSetupStart);
    HookEvent("teamplay_setup_finished", OnSetupFinished);
    HookEvent("teamplay_round_win", OnRoundEnd);
    HookEvent("player_spawn", OnPlayerSpawn);

    // --- Keep all doors open for the entire round ---
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "func_door")) != -1 ||
           (ent = FindEntityByClassname(ent, "func_movelinear")) != -1 ||
           (ent = FindEntityByClassname(ent, "func_areaportal")) != -1)
    {
        AcceptEntityInput(ent, "Open");
    }
    // ------------------------------------------------

}

public void OnMapEnd()
{
    RemoveCommandListener(BlacklistCommands, "kill");
    RemoveCommandListener(BlacklistCommands, "explode");
    RemoveCommandListener(BlacklistCommands, "autoteam");
    RemoveCommandListener(BlacklistCommands, "jointeam");
    RemoveCommandListener(BlacklistCommands, "joinclass");

    UnhookEvent("teamplay_round_start", OnSetupStart);
    UnhookEvent("teamplay_setup_finished", OnSetupFinished);
    UnhookEvent("teamplay_round_win", OnRoundEnd);
    UnhookEvent("player_spawn", OnPlayerSpawn);
    UnhookEvent("player_death", OnPlayerDeath);

    StopJuggernautSignalTimer();
}

public void OnSetupStart(Event event, const char[] name, bool dontBroadcast)
{
    AddCommandListener(BlacklistCommands, "kill");
    AddCommandListener(BlacklistCommands, "explode");
    AddCommandListener(BlacklistCommands, "autoteam");
    AddCommandListener(BlacklistCommands, "jointeam");
    AddCommandListener(BlacklistCommands, "joinclass");

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsClientSourceTV(i))
            continue;

        char clientSteamID[32];
        GetClientAuthId(i, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));
        if (StrEqual(clientSteamID, allowedSteamID))
        {
            TF2_ChangeClientTeam(i, TFTeam_Blue);
            TF2_SetPlayerClass(i, TFClass_Spy, true, true);
            CreateTimer(1.0, OnJuggernautSpawn, i);
            TF2_RespawnPlayer(i);
        }
        else
        {
            TF2_ChangeClientTeam(i, TFTeam_Unassigned);
            UTIL_ScreenFade(i, {0, 0, 0, 255}, 2.0, 5.0, FFADE_OUT|FFADE_STAYOUT);
        }
    }

    // --- Keep all doors open after setup finishes ---
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
    {
        AcceptEntityInput(ent, "Open");
        AcceptEntityInput(ent, "Lock");
    }
    ent = -1;
    while ((ent = FindEntityByClassname(ent, "func_door_rotating")) != -1)
    {
        AcceptEntityInput(ent, "Open");
        AcceptEntityInput(ent, "Lock");
    }
    // ------------------------------------------------
}

public void OnSetupFinished(Event event, const char[] name, bool dontBroadcast)
{
    HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
    
    int bluePlayer = 0;

    for (int i = 1; i <= MaxClients; i++)
        g_bIsJuggernaut[i] = false;

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    bluePlayer = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            char clientSteamID[32];
            GetClientAuthId(i, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));
            if (StrEqual(clientSteamID, allowedSteamID))
            {
                bluePlayer = i;
                break;
            }
        }
    }

    if (bluePlayer == 0)
        return;

    g_bIsJuggernaut[bluePlayer] = true;

    // Respawn all dead RED players as Heavy
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsClientSourceTV(i))
            continue;

        if (TF2_GetClientTeam(i) != TFTeam_Blue)
        {
            TF2_ChangeClientTeam(i, TFTeam_Red);
            TF2_SetPlayerClass(i, TFClass_Heavy, true, true);
            TF2_RespawnPlayer(i);
        }
    }

    /*for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (i == bluePlayer)
        {
            //TF2_ChangeClientTeam(i, TFTeam_Blue);
            //TF2_SetPlayerClass(i, TFClass_Spy, true, true);
        }
        else
        {
            TF2_ChangeClientTeam(i, TFTeam_Red);
            TF2_SetPlayerClass(i, TFClass_Heavy, true, true);
            TF2_RespawnPlayer(i);
        }

        float vecOrigin[3], vecAngles[3];
        GetClientAbsOrigin(i, vecOrigin);
        GetClientAbsAngles(i, vecAngles);
        TF2_RespawnPlayer(i);
        TeleportEntity(i, vecOrigin, vecAngles, NULL_VECTOR);
    }*/

    StartJuggernautSignalTimer();
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    UnhookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
    StopJuggernautSignalTimer();
}

public Action OnJuggernautSpawn(Handle timer, int client)
{
    int knife = GetPlayerWeaponSlot(client, 2);

    if (knife > MaxClients && IsValidEntity(knife))
    {
        int knife_index = GetEntProp(knife, Prop_Send, "m_iItemDefinitionIndex");
        int baseHealth = g_hJuggernautMaxHealth.IntValue;
        TF2_AddAttribute(knife, "SET BONUS: max health additive bonus", knife_index == 356 ? float(baseHealth + 55 - 125) : float(baseHealth - 125));
        //TF2_AddCondition(client, TFCond_HalloweenQuickHeal, 3.0);
    }

    int watch = GetPlayerWeaponSlot(client, 4);

    if (watch > MaxClients && IsValidEntity(watch))
    {
        TF2_AddAttribute(watch, "mult cloak meter consume rate", -99.9);
    }

    return Plugin_Stop;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientInGame(client))
        return;

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    char clientSteamID[32];
    GetClientAuthId(client, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));

    if (StrEqual(clientSteamID, allowedSteamID))
    {
        int entity = CreateEntityByName("game_round_win");
        if (entity != -1)
        {
            DispatchKeyValue(entity, "force_map_reset", "1");
            SetEntProp(entity, Prop_Data, "m_iTeamNum", TFTeam_Red);
            AcceptEntityInput(entity, "RoundWin");
            RemoveEntity(entity);
        }
        return;
    }

    TF2_ChangeClientTeam(client, TFTeam_Unassigned);
    UTIL_ScreenFade(client, {0, 0, 0, 255}, 2.0, 5.0, FFADE_OUT|FFADE_STAYOUT);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    char clientSteamID[32];
    GetClientAuthId(client, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));

    // If not the juggernaut, force to RED and Heavy
    if (!StrEqual(clientSteamID, allowedSteamID))
    {
        TF2_ChangeClientTeam(client, TFTeam_Red);
        TF2_SetPlayerClass(client, TFClass_Heavy, true, true);
    }

    // Always restrict RED team to melee
    if (TF2_GetClientTeam(client) == TFTeam_Red)
    {
        TF2_RemoveWeaponSlot(client, 0); // Primary
        TF2_RemoveWeaponSlot(client, 1); // Secondary
    }
}

public Action BlacklistCommands(int client, const char[] command, int argc)
{
    if (client > 0 && IsClientInGame(client) && TF2_GetClientTeam(client) != TFTeam_Spectator)
    {
        PrintToChat(client, "You can't perform this command.");
        if (StrEqual(command, "kill", false) || StrEqual(command, "explode", false))
        {
            TF2_ChangeClientTeam(client, TFTeam_Unassigned);
            UTIL_ScreenFade(client, {0, 0, 0, 255}, 2.0, 5.0, FFADE_OUT|FFADE_STAYOUT);
        }
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action Command_Ready(int client, int args)
{
    if (!IsClientInGame(client))
        return Plugin_Handled;

    char allowedSteamID[32];
    if (g_hJuggernautSteamID != null)
        g_hJuggernautSteamID.GetString(allowedSteamID, sizeof(allowedSteamID));
    else
        allowedSteamID[0] = '\0';

    char clientSteamID[32];
    GetClientAuthId(client, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID));

    if (!StrEqual(clientSteamID, allowedSteamID))
    {
        PrintToChat(client, "Only the Juggernaut can use this command.");
        return Plugin_Handled;
    }

    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "team_round_timer")) != -1)
    {
        SetVariantInt(1);
        AcceptEntityInput(entity, "SetSetupTime");
    }
    
    return Plugin_Handled;
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

void StartJuggernautSignalTimer()
{
    float interval = g_hJuggernautSignalInterval.FloatValue;
    if (interval > 0.0)
    {
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

    float pos[3];
    GetClientAbsOrigin(juggernaut, pos);
    EmitAmbientSound(MEDIC_ALERT, pos, juggernaut, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
    EmitAmbientSound(MEDIC_ALERT, pos, juggernaut, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
    EmitAmbientSound(MEDIC_ALERT, pos, juggernaut, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
    EmitAmbientSound(MEDIC_ALERT, pos, juggernaut, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
    EmitAmbientSound(MEDIC_ALERT, pos, juggernaut, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    //TF2_ChangeClientTeam(client, TFTeam_Unassigned);
    TF2_SetPlayerClass(client, TFClass_Heavy, true, true);
    //UTIL_ScreenFade(client, {0, 0, 0, 255}, 2.0, 5.0, FFADE_OUT|FFADE_STAYOUT);
}

#include "arjay/stocks.sp"