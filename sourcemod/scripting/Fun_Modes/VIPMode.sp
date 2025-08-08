#pragma semicolon 1
#pragma newdecls required

ConVarInfo g_cvInfoVIP[4] = 
{
	{null, "15.0,25.0,40.0,60.0", "float"},
	{null, "2.0,3.0,5.0,10.0", "float"},
	{null, "0,1", "bool"},
	{null, "1,2,3,4,5", "int"}
};

/* CALLED ON PLUGIN START */
stock void PluginStart_VIPMode()
{
	RegAdminCmd("sm_fm_vipmode", Cmd_VIPModeEnable, ADMFLAG_CONVARS, "Enable/Disable VIP Mode");
	RegAdminCmd("sm_vipmode_setvip", Cmd_SetVIP, ADMFLAG_CONVARS);
	RegConsoleCmd("sm_checkvip", Cmd_CheckVIP);
	
	/* CONVARS */
	g_cvVIPModeTimer = CreateConVar("sm_vipmode_timer", "15", "After how many seconds from round start to pick VIP");
	g_cvVIPModeCount = CreateConVar("sm_vipmode_counter", "3", "After how many seconds all the other humans will be slayed after the VIP dies");
	g_cvVIPModeLaser = CreateConVar("sm_vipmode_laser", "1", "Don't Kill all humans when vip dies to a laser, 1 = Enabled, 0 = Disabled");
	g_cvVIPMax 		 = CreateConVar("sm_vipmode_max_vips", "1", "How many VIPs to be picked");
	
	VIPMode_SetCvarsInfo();
}

void VIPMode_SetCvarsInfo()
{
	ConVar cvars[sizeof(g_cvInfoVIP)];
	cvars[0] = g_cvVIPModeTimer;
	cvars[1] = g_cvVIPModeCount;
	cvars[2] = g_cvVIPModeLaser;
	cvars[3] = g_cvVIPMax;
	
	for (int i = 0; i < sizeof(g_cvInfoVIP); i++)
		g_cvInfoVIP[i].cvar = cvars[i];
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if(!g_bIsVIPModeOn || !g_cvVIPModeLaser.BoolValue)
		return;
	
	if(!g_bIsVIP[victim]) {
		return;
	}

	if(!IsValidEntity(attacker))
		return;

	char classname[64];
	if(!GetEntityClassname(attacker, classname, sizeof(classname)))
		return;

	/* if attacker entity is not trigger_hurt */
	if(strcmp(classname, "trigger_hurt") != 0)
	{
		RemoveClientVIP(victim, true, "VIPMode_VIPDeath");
		return;
	}

	/* we should now check if trigger_hurt is from a laser */
	int parent = GetEntPropEnt(attacker, Prop_Data, "m_hParent");
	if(!IsValidEntity(parent))
	{
		RemoveClientVIP(victim, true, "VIPMode_VIPDeath");
		return;
	}
	
	bool isFromLaser = false;
	char parentClassName[64];
	if(!GetEntityClassname(parent, parentClassName, sizeof(parentClassName))) {
		RemoveClientVIP(victim, true, "VIPMode_VIPDeath");
		return;
	}

	if(strcmp(parentClassName, "func_movelinear") != 0 || strcmp(parentClassName, "func_door") != 0)
		isFromLaser = true;

	if(!isFromLaser)
	{
		RemoveClientVIP(victim, true, "VIPMode_VIPDeathLaser");
		return;
	}

	CPrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_VIPDeathLaser", victim, victim);
	RemoveClientVIP(victim, false);
	return;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(!g_bIsVIPModeOn || !g_cvVIPModeLaser.BoolValue)
		return;
	
	if(!g_bIsVIP[client])
		return;
		
	RemoveClientVIP(client, true, "VIPMode_VIPDeath");
}

stock void PlayerDeath_VIPMode(int userid)
{
	if(!g_bIsVIPModeOn || g_cvVIPModeLaser.BoolValue)
		return;

	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
		return;

	if(!g_bIsVIP[client])
		return;

	RemoveClientVIP(client, true, "VIPMode_VIPDeath");
}

stock void PlayerTeam_VIPMode(int userid, int team)
{
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
		return;

	if(!g_bIsVIP[client])
		return;

	if(team == CS_TEAM_SPECTATOR || team == CS_TEAM_NONE) 
		RemoveClientVIP(client, true, "VIPMode_VIPDeathSpec");
}

stock void ClientDisconnect_VIPMode(int client)
{
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	if(!g_bIsVIP[client]) {
		return;
	}
	
	RemoveClientVIP(client, true, "VIPMode_VIPDeathDisconnect");

	delete g_hKillAllTimer;
	g_hKillAllTimer = CreateTimer(g_cvVIPModeCount.FloatValue, VIPMode_KillAllTimer);
}

Action VIPMode_KillAllTimer(Handle timer)
{
	g_hKillAllTimer = null;
	
	if(GetCurrentVIPsCount() > 0)
	{
		CPrintToChatAll("%s Found a VIP player, {olive}Cancelling The kills...", VIPMode_Tag);
		return Plugin_Stop;
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		ForcePlayerSuicide(i);
	}

	return Plugin_Continue;
}

stock void RoundStart_VIPMode()
{
	if(!g_bIsVIPModeOn)
		return;

	delete g_hKillAllTimer;
	
	/* DELETE VIP BEACON TIMER */
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i))
			continue;

		g_bIsVIP[i] = false;
		delete g_hVIPBeaconTimer[i];
	}

	delete g_hVIPRoundStartTimer;
	g_hVIPRoundStartTimer = CreateTimer(g_cvVIPModeTimer.FloatValue, VIPRoundStart_Timer);
}

Action VIPRoundStart_Timer(Handle timer)
{
	g_hVIPRoundStartTimer = null;

	/* CHECK IF THERE IS ALREADY VIP SET BY ADMIN */
	if(GetCurrentVIPsCount() > 0)
		return Plugin_Stop;

	/* Lets pick a random human */
	for (int i = 0; i < g_cvVIPMax.IntValue; i++)
		VIP_PickRandom();
		
	return Plugin_Stop;
}

Action VIP_BeaconTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	if(!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}

	if(g_bRoundEnd)
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}

	BeaconPlayer(client, BeaconMode_VIP); 
	return Plugin_Continue;
}

Action Cmd_VIPModeEnable(int client, int args)
{
	if(g_bIsVIPModeOn)
	{
		g_bIsVIPModeOn = false;
		if(!client)
			CReplyToCommand(client, "%s VIP Mode is now OFF!", VIPMode_Tag);
		else
			CReplyToCommand(client, "%s %T", VIPMode_Tag, "VIPMode_Disabled", client);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsValidClient(i) || !g_bIsVIP[i])	
				continue;
				
			g_bIsVIP[i] = false;
			delete g_hVIPBeaconTimer[i];
		}
		
		return Plugin_Handled;
	}
	else
	{
		g_bIsVIPModeOn = true;
		
		/* Events Hooks */
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		FunModes_HookEvent(g_bEvent_PlayerTeam, "player_team", Event_PlayerTeam);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
		
		if(!client)
			CReplyToCommand(client, "%s VIP Mode is now ON!", VIPMode_Tag);
		else
			CReplyToCommand(client, "%s %T", VIPMode_Tag, "VIPMode_Enabled", client);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
				continue;

			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		return Plugin_Handled;
	}
}

Action Cmd_SetVIP(int client, int args)
{
	if(args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_setvip <player>", VIPMode_Tag);
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);

	if(target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if(g_bIsVIP[target])
	{
		CReplyToCommand(client, "%s The specified target is already VIP!", VIPMode_Tag);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(target) || GetClientTeam(target) != CS_TEAM_CT)
	{
		CReplyToCommand(client, "%s Cannot set VIP to a player that is not human.", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	g_bIsVIP[target] = true;
	CPrintToChatAll("%s {olive}%N {lightgreen}is a VIP!", VIPMode_Tag, target);

	delete g_hVIPBeaconTimer[target];
	g_hVIPBeaconTimer[target] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(target), TIMER_REPEAT);
	return Plugin_Handled;
}

Action Cmd_CheckVIP(int client, int args)
{
	if(!g_bIsVIPModeOn)
	{
		CReplyToCommand(client, "%s VIP Mode is currently OFF", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	if(GetCurrentVIPsCount() == 0)
	{
		CReplyToCommand(client, "%s No VIP was found!", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	char vipPlayers[200];
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || !g_bIsVIP[i])
			continue;
				
		Format(vipPlayers, sizeof(vipPlayers), "%s%N, ", vipPlayers, i);
	}
	
	CReplyToCommand(client, "%s The current {purple}VIPs {olive}are: {purple}%s", VIPMode_Tag, vipPlayers);
	return Plugin_Handled;
}

stock int GetCurrentVIPsCount()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || !g_bIsVIP[i]) 
			continue;
				
		count++;
	}
	
	return count;
}

stock void RemoveClientVIP(int client, bool kill, const char[] translation = "")
{
	g_bIsVIP[client] = false;
	delete g_hVIPBeaconTimer[client];
	
	CPrintToChatAll("%s %t", VIPMode_Tag, translation, client);
	
	if(kill && GetCurrentVIPsCount() == 0)
	{
		CPrintToChatAll("%s %t", VIPMode_Tag, "VIPMode_KillAll", g_cvVIPModeCount.IntValue);

		delete g_hKillAllTimer;
		g_hKillAllTimer = CreateTimer(g_cvVIPModeCount.FloatValue, VIPMode_KillAllTimer);
	}
}

stock void VIP_PickRandom() 
{
	/* Lets pick a random human */
	int clientsCount[MAXPLAYERS + 1];
	int humansCount;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT || g_bIsVIP[i])
			continue;

		clientsCount[humansCount++] = i;
	}

	if(humansCount <= 0)
		return;
	
	int random = clientsCount[GetRandomInt(0, (humansCount - 1))];
	if(random < 1)
		return;

	g_bIsVIP[random] = true;
	CPrintToChatAll("%s {olive}%N {lightgreen}is a VIP!", VIPMode_Tag, random);

	delete g_hVIPBeaconTimer[random];
	g_hVIPBeaconTimer[random] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(random), TIMER_REPEAT);
}
