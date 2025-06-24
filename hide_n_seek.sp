#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2items_stocks>
#include <multicolors>

public Plugin myinfo = 
{
    name = "Hide'n'Seek",
    author = "Heapons (Commissioned by ArJay)",
    description = "Made for ArJay's event.",
    version = "1.0.0",
    url = "https://github.com/Heapons/Hide-N-Seek"
};

bool g_bIsJuggernaut[MAXPLAYERS+1];

public void OnMapStart()
{
    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);

    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("post_inventory_application", OnLoadoutRefresh);
}

public void OnMapEnd()
{
    UnhookEvent("teamplay_round_start", OnRoundStart);
    UnhookEvent("post_inventory_application", OnLoadoutRefresh);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    int bluePlayer = 0;
    int playerCount = 0;
    int players[MAXPLAYERS+1];

    for (int i = 1; i <= MaxClients; i++)
        g_bIsJuggernaut[i] = false;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            players[playerCount++] = i;
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
        else
        {
            if (TF2_GetClientTeam(client) != TFTeam_Red)
                TF2_ChangeClientTeam(client, TFTeam_Red);
        }
    }
}

public void OnLoadoutRefresh(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    if (g_bIsJuggernaut[client] && TF2_GetPlayerClass(client) == TFClass_Spy)
    {
        int weapon = GetPlayerWeaponSlot(client, 4); // PDA2 slot
        if (weapon > MaxClients && IsValidEntity(weapon))
        {
            int idx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
            float value = (idx == 59) ? 1.0 : 2.0;

            ServerCommand("sig_addattr #%i 48 %f", GetClientUserId(client), value);
        }
    }
}