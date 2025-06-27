stock void TF2_AddAttribute(int entity, const char[] name, float value=1.0, float duration=-1.0)
{
    static char buffer[MAX_BUFFER_LENGTH];
    Format(buffer, sizeof(buffer), "self.Add%sAttribute(\"%s\", %f, %f)", 0 < entity <= MaxClients ? "Custom" : "", name, value, duration);
    SetVariantString(buffer);
    AcceptEntityInput(entity, "RunScriptCode");
}

stock void TF2_RemoveAttribute(int entity, const char[] name)
{
    static char buffer[MAX_BUFFER_LENGTH];
    Format(buffer, sizeof(buffer), "self.Remove%sAttribute(\"%s\")", 0 < entity <= MaxClients ? "Custom" : "", name);
    SetVariantString(buffer);
    AcceptEntityInput(entity, "RunScriptCode");
}

void CreateSetupTimer()
{
    int winIndex = EntityLump.Append();
    EntityLumpEntry winEntry = EntityLump.Get(winIndex);
    winEntry.Append("classname", "game_round_win");
    winEntry.Append("targetname", "blu_win");
    winEntry.Append("TeamNum", "3"); // 3 = BLU
    winEntry.Append("force_map_reset", "1");
    delete winEntry;

    int index = EntityLump.Append();
    EntityLumpEntry entry = EntityLump.Get(index);
    entry.Append("classname", "team_round_timer");
    static char timerLengthStr[16];
    IntToString(g_hJuggernautSetupTime.IntValue+5, timerLengthStr, sizeof(timerLengthStr));
    static char roundTimerStr[16];
    IntToString(g_hJuggernautRoundTime.IntValue, roundTimerStr, sizeof(roundTimerStr));
    entry.Append("timer_length", roundTimerStr);
    entry.Append("setup_length", timerLengthStr);
    entry.Append("start_paused", "0");
    entry.Append("show_in_hud", "1");

    entry.Append("OnFinished", "blu_win,RoundWin,,0,-1");
    delete entry;
}