#pragma semicolon 1
#pragma newdecls required

/* CALLED ON PLUGIN START */
stock void PluginStart_VIPMode() {
	RegAdminCmd("sm_fm_vipmode", Cmd_VIPModeEnable, ADMFLAG_CONVARS, "Enable/Disable VIP Mode");
	RegAdminCmd("sm_vipmode_setvip", Cmd_SetVIP, ADMFLAG_CONVARS);
	RegConsoleCmd("sm_checkvip", Cmd_CheckVIP);
	
	/* CONVARS */
	g_cvVIPModeTimer = CreateConVar("sm_vipmode_timer", "15", "After how many seconds from round start to pick VIP");
	g_cvVIPModeCount = CreateConVar("sm_vipmode_counter", "3", "After how many seconds all the other humans will be slayed after the VIP dies");
	g_cvVIPModeLaser = CreateConVar("sm_vipmode_laser", "1", "Don't Kill all humans when vip dies to a laser, 1 = Enabled, 0 = Disabled");
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype) {
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	if(!g_cvVIPModeLaser.BoolValue) {
		return;
	}
	
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(!IsValidClient(vip)) {
		return;
	}
	
	if(victim != vip) {
		return;
	}
	
	if(IsPlayerAlive(victim)) {
		return;
	}

	if(!IsValidEntity(attacker)) {
		PrintToChatAll("entity is invalid entity");
		return;
	}
	
	char classname[64];
	if(!GetEntityClassname(attacker, classname, sizeof(classname))) {
		return;
	}
	
	/* if attacker entity is not trigger_hurt */
	if(!StrEqual(classname, "trigger_hurt")) {
		KillVIPAndHumans(victim);
		return;
	}
	
	/* we should now check if trigger_hurt is from a laser */
	int parent = GetEntPropEnt(attacker, Prop_Data, "m_hParent");
	if(!IsValidEntity(parent)) {
		PrintToChatAll("parent is invalid entity");
		return;
	}
	
	bool isFromLaser = false;
	char parentClassName[64];
	if(!GetEntityClassname(parent, parentClassName, sizeof(parentClassName))) {
		return;
	}
	
	if(StrEqual(parentClassName, "func_movelinear") || StrEqual(parentClassName, "func_door")) {
		isFromLaser = true;
	}
	
	if(!isFromLaser) {
		KillVIPAndHumans(victim);
		return;
	}
	
	CPrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_VIPDeathLaser", victim, victim);
	g_iVIPUserid = -1;
	return;
}

stock void KillVIPAndHumans(int victim) {
	CPrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_VIPDeath", victim, victim);
	CPrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_KillAll", victim, g_cvVIPModeCount.IntValue);

	delete g_hKillAllTimer;
	g_hKillAllTimer = CreateTimer(g_cvVIPModeCount.FloatValue, VIPMode_KillAllTimer);
	g_iVIPUserid = -1;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn) {
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	if(!g_cvVIPModeLaser.BoolValue) {
		return;
	}
	
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(vip != client) {
		return;
	}
	
	KillVIPAndHumans(client);
}

stock void PlayerDeath_VIPMode(int userid) {
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	if(g_cvVIPModeLaser.BoolValue) {
		return;
	}
	
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		return;
	}
	
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(!IsValidClient(vip)) {
		return;
	}
	
	if(client != vip) {
		return;
	}
	
	KillVIPAndHumans(client);
}

stock void PlayerTeam_VIPMode(int userid, int team) {
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		return;
	}
	
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(!IsValidClient(vip)) {
		return;
	}
	
	if(client != vip) {
		return;
	}
	
	if(team == CS_TEAM_SPECTATOR || team == CS_TEAM_NONE) {
		g_iVIPUserid = -1;
		PrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_VIPDeathSpec", client);
		PrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_KillAll", g_cvVIPModeCount.IntValue);
	
		delete g_hKillAllTimer;
		g_hKillAllTimer = CreateTimer(g_cvVIPModeCount.FloatValue, VIPMode_KillAllTimer);
	}
}

stock void ClientDisconnect_VIPMode(int client) {
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(!IsValidClient(vip)) {
		return;
	}
	
	if(client != vip) {
		return;
	}
	
	g_iVIPUserid = -1;
	PrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_VIPDeathDisconnect", client, client);
	PrintToChatAll("%s %T", VIPMode_Tag, "VIPMode_KillAll", client, g_cvVIPModeCount.IntValue);

	delete g_hKillAllTimer;
	g_hKillAllTimer = CreateTimer(g_cvVIPModeCount.FloatValue, VIPMode_KillAllTimer);
}

Action VIPMode_KillAllTimer(Handle timer) {
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		ForcePlayerSuicide(i);
	}
	
	g_hKillAllTimer = null;
	return Plugin_Continue;
}

stock void RoundStart_VIPMode() {
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	g_iVIPUserid = -1;
	
	/* DELETE VIP BEACON TIMER */
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		delete g_hVIPBeaconTimer[i];
	}
	
	delete g_hVIPRoundStartTimer;
	g_hVIPRoundStartTimer = CreateTimer(g_cvVIPModeTimer.FloatValue, VIPRoundStart_Timer);
}

Action VIPRoundStart_Timer(Handle timer) {
	g_hVIPRoundStartTimer = null;
	
	/* CHECK IF THERE IS ALREADY VIP SET BY ADMIN */
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(IsValidClient(vip)) {
		return Plugin_Stop;
	}
	
	/* Lets pick a random human */
	int clientsCount[MAXPLAYERS + 1];
	int humansCount;
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		clientsCount[humansCount++] = i;
	}
	
	if(humansCount <= 0) {
		return Plugin_Stop;
	}
	
	int random = clientsCount[GetRandomInt(0, (humansCount - 1))];
	if(random < 1) {
		return Plugin_Stop;
	}
	
	g_iVIPUserid = GetClientUserId(random);
	CPrintToChatAll("%s {olive}%N {lightgreen}is The VIP!", VIPMode_Tag, random);
	
	delete g_hVIPBeaconTimer[random];
	g_hVIPBeaconTimer[random] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(random), TIMER_REPEAT);
	return Plugin_Stop;
}

Action VIP_BeaconTimer(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	if(!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT) {
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	if(g_bRoundEnd) {
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	BeaconPlayer(client, BeaconMode_VIP); 
	return Plugin_Continue;
}

Action Cmd_VIPModeEnable(int client, int args) {
	/* Check if healbeacon mode is on first both modes cant be played at the same time*/
	if(g_bIsHealBeaconOn) {
		if(!client) {
			CReplyToCommand(client, "%s Heal Beacon mode is ON, VIP Mode and HealBeacon Mode can't be played together at the same time.", VIPMode_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", VIPMode_Tag, "VIPMode_HealBeaconOn", client);
		}
		
		return Plugin_Handled;
	}
	
	if(g_bIsVIPModeOn) {
		g_bIsVIPModeOn = false;
		if(!client) {
			CReplyToCommand(client, "%s VIP Mode is now OFF!", VIPMode_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", VIPMode_Tag, "VIPMode_Disabled", client);
		}
		
		int vip = GetClientOfUserId(g_iVIPUserid);
		if(IsValidClient(vip)) {
			delete g_hVIPBeaconTimer[vip];
		}
		
		return Plugin_Handled;
	}
	else {
		g_bIsVIPModeOn = true;
		if(!client) {
			CReplyToCommand(client, "%s VIP Mode is now ON!", VIPMode_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", VIPMode_Tag, "VIPMode_Enabled", client);
		}
		
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i)) {
				continue;
			}
			
			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}
		
		return Plugin_Handled;
	}
}

Action Cmd_SetVIP(int client, int args) {
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_setvip <player>", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);
	
	if(target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(target == vip) {
		CReplyToCommand(client, "%s The specified target is already VIP!", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(target) || GetClientTeam(target) != CS_TEAM_CT) {
		CReplyToCommand(client, "%s Cannot set VIP to a player that is not human.", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	if(IsValidClient(vip)) {
		SetEntityRenderColor(vip, 255, 255, 255, 255);
		delete g_hVIPBeaconTimer[vip];
	}
	
	g_iVIPUserid = GetClientUserId(target);
	CPrintToChatAll("%s {olive}%N {lightgreen}is The VIP!", VIPMode_Tag, target);
	
	delete g_hVIPBeaconTimer[target];
	g_hVIPBeaconTimer[target] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(target), TIMER_REPEAT);
	return Plugin_Handled;
}

Action Cmd_CheckVIP(int client, int args) {
	int vip = GetClientOfUserId(g_iVIPUserid);
	if(!IsValidClient(vip)) {
		CReplyToCommand(client, "%s The current VIP is {olive}None.", VIPMode_Tag);
		return Plugin_Handled;
	}
	
	CReplyToCommand(client, "%s The current VIP is {olive}%N", VIPMode_Tag, vip);
	return Plugin_Handled;
}

stock void VIPMode_GetConVars(ConVar cvars[3]) {
	cvars[0] = g_cvVIPModeTimer;
	cvars[1] = g_cvVIPModeCount;
	cvars[2] = g_cvVIPModeLaser;
}
