#pragma semicolon 1
#pragma newdecls required

/* Called in OnPluginStart */
stock void PluginStart_HealBeacon() {
	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_healbeacon", Cmd_HealBeacon, ADMFLAG_CONVARS, "Enable/Disable Healbeacon");
	RegAdminCmd("sm_healbeacon", Cmd_HealBeaconMenu, ADMFLAG_CONVARS, "Shows healbeacon menu");
	RegAdminCmd("sm_beacon_distance", Cmd_HealBeaconDistance, ADMFLAG_CONVARS, "Change beacon distance");
	RegAdminCmd("sm_replacebeacon", Cmd_HealBeaconReplace, ADMFLAG_BAN, "Replace an already heal beaconed player with another one");
	RegAdminCmd("sm_addnewbeacon", Cmd_HealBeaconAddNew, ADMFLAG_BAN, "Add a new heal beaconed player");
	RegAdminCmd("sm_removebeacon", Cmd_HealBeaconRemove, ADMFLAG_BAN, "Remove heal beacon player");
	RegConsoleCmd("sm_checkdistance", Cmd_HealBeaconCheckDistance, "...");

	/* CONVARS HANDLES */
	g_cvHealBeaconTimer = CreateConVar("sm_beacon_timer", "20.0", "The time that will start picking random players at round start");
	g_cvAlertTimer = CreateConVar("sm_beacon_alert_timer", "10", "How much time in seconds the damage will start being applied from heal beacon as an alert for the other humans");
	g_cvHealBeaconDamage = CreateConVar("sm_beacon_damage", "5", "The damage that the heal beacon will give");
	g_cvHealBeaconHeal = CreateConVar("sm_beacon_heal", "1", "How much heal beacon should heal the players in 1 second");
	g_cvRandoms = CreateConVar("sm_healbeacon_randoms", "2", "How many random players should get the heal beacon");
	g_cvDefaultDistance = CreateConVar("sm_healbeacon_distance", "400.0", "Default distance of beacon to give");
}

stock void RoundStart_HealBeacon() {
	/* DELETE TIMER HANDLES SO WE DONT GET ERRORS */
	HealBeacon_DeleteAllTimers();
	
	/* CHECK IF ARRAYLIST IS NOT NULL AND THEN ERASE ALL CLIENTS INDEXES IN ARRAYLIST */
	if(g_aHBPlayers == null) {
		return;
	}
	
	g_aHBPlayers.Clear();
	
	if(!g_bIsHealBeaconOn) {
		return;
	}
	
	/* RESET COUNTER */
	g_iCounter = 0;
	
	/* LETS CREATE THE FIRST ROUND START TIMER */
	g_hRoundStart_Timer[0] = CreateTimer(g_cvHealBeaconTimer.FloatValue, RoundStart_Timer);
}

stock void PlayerDeath_HealBeacon(int userid) {
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		return;
	}
	
	if(!g_BeaconPlayersData[client].hasHealBeacon) {
		return;
	}
	
	RemoveBeacon(-1, client);
	CPrintToChatAll("%s {olive}%N {lightgreen}died with HealBeacon.", HealBeacon_Tag, client);
}

stock void PlayerTeam_HealBeacon(int userid, int team) {
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		return;
	}
	
	if(!g_BeaconPlayersData[client].hasHealBeacon) {
		return;
	}
	
	if(team == CS_TEAM_SPECTATOR || team == CS_TEAM_NONE) {
		RemoveBeacon(-1, client);
		CPrintToChatAll("%s {olive}%N {lightgreen}moved to spectator team with HealBeacon.", HealBeacon_Tag, client);
	}
}

stock void ClientDisconnect_HealBeacon(int client) {
	if(!g_BeaconPlayersData[client].hasHealBeacon) {
		delete g_hBeaconTimer[client];
		g_BeaconPlayersData[client].ResetValues();
		return;
	}
	
	RemoveBeacon(-1, client);
	CPrintToChatAll("%s {olive}%N {lightgreen}disconnected with HealBeacon.", HealBeacon_Tag, client);
}

Action RoundStart_Timer(Handle timer) {
	g_hRoundStart_Timer[0] = null;
	
	/* Let's now pick the random players */
	for(int i = 0; i < g_cvRandoms.IntValue; i++) {
		GetRandomPlayer();
	}
	
	/* Delete the previous timer handler if found so we dont assign a new CreateTimer over the old one */
	delete g_hRoundStart_Timer[1];
	g_hRoundStart_Timer[1] = CreateTimer(1.0, RoundStart_CountTimer, _, TIMER_REPEAT);
	return Plugin_Stop;
}

Action RoundStart_CountTimer(Handle timer) {
	int alertTime = g_cvAlertTimer.IntValue;
	
	if(g_iCounter >= alertTime) {
		HealBeacon_Setup();
		g_hRoundStart_Timer[1] = null;
		return Plugin_Stop;
	}
	
	SetHudTextParams(-0.2, 1.0, 2.0, 255, 36, 255, 13);
	
	/* Lets send the hud message to all clients */
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		ShowSyncHudText(i, g_hHudMsg, "%T", "HealBeacon_Alert", i, (alertTime - g_iCounter));
	}
	
	g_iCounter++;
	return Plugin_Continue;
}

stock void GetRandomPlayer() {
	int clientsCount[MAXPLAYERS + 1];
	int humansCount;
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		/* if client is already heal beaconed then dont include them in */
		if(g_BeaconPlayersData[i].hasHealBeacon) {
			continue;
		}
		
		clientsCount[humansCount++] = i;
	}
	
	if(humansCount <= 0 || humansCount < g_cvRandoms.IntValue) {
		return;
	}
	
	int random = clientsCount[GetRandomInt(0, (humansCount - 1))];
	if(random < 1) {
		return;
	}
	
	/* Lets now apply healbeacon to the choosen one */
	SetHealBeaconToClient(random);
	CPrintToChatAll("%s %T", HealBeacon_Tag, "HealBeacon_AddAnnounce", random, random);
}

stock void SetHealBeaconToClient(int client) {
	/* Lets save the healbeacon player data they are needed */
	g_BeaconPlayersData[client].hasHealBeacon = true;
	g_BeaconPlayersData[client].distance = g_cvDefaultDistance.FloatValue;
	g_BeaconPlayersData[client].ResetColor();
	
	/* BEACON THE PLAYER */
	delete g_hBeaconTimer[client];
	g_hBeaconTimer[client] = CreateTimer(0.1, HealBeacon_BeaconTimer, GetClientUserId(client), TIMER_REPEAT);
	
	/* Lets now push client indexes to the arraylist */
	g_aHBPlayers.Push(client);
}

stock void HealBeacon_Setup() {
	/* Lets create the damage timer and delete the handle first so we dont get problems */
	delete g_hDamageTimer;
	g_hDamageTimer = CreateTimer(0.7, HealBeacon_DamageTimer, _, TIMER_REPEAT);
	
	/* Lets create the heal timer and delete the handle first so we dont get problems */
	delete g_hHealTimer;
	g_hHealTimer = CreateTimer(1.0, HealBeacon_HealTimer, _, TIMER_REPEAT);
}

Action HealBeacon_BeaconTimer(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client)) {
		g_hBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	if(!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT || !g_BeaconPlayersData[client].hasHealBeacon) {
		g_hBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	BeaconPlayer(client, BeaconMode_HealBeacon);
	return Plugin_Continue;
}

Action HealBeacon_DamageTimer(Handle timer) {
	/* if round is ending */
	if(g_bRoundEnd) {
		return Plugin_Handled;
	}
	
	/* if all healbeacon players died */
	if(g_aHBPlayers.Length == 0) {
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsValidClient(i)) {
				continue;
			}
			
			if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
				continue;
			}
			
			SDKHooks_TakeDamage(i, 0, 0, g_cvHealBeaconDamage.FloatValue);
		}
		
		return Plugin_Handled;
	}
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		/* if client is healbeaconed then continue the loop and ignore that client */
		if(g_BeaconPlayersData[i].hasHealBeacon) {
			continue;
		}
		
		HealBeacon_DealDamage(i);
	}
	
	return Plugin_Continue;
}

stock void HealBeacon_DealDamage(int client) {
	bool isFar = false;
	
	for(int i = 0; i < g_aHBPlayers.Length; i++) {
		int random = g_aHBPlayers.Get(i);
		float distance = GetDistanceBetween(random, client);
		
		/* if player is not far from any heal beacon player then we need to stop the loop */
		if(distance < (g_BeaconPlayersData[random].distance / 2.0)) {
			isFar = false;
			break;
		}
		
		/* else */
		if(distance > (g_BeaconPlayersData[random].distance / 2.0)) {
			isFar = true;
		}
	}
	
	/* if player is far then do damage and warn them */
	if(isFar) {
		SDKHooks_TakeDamage(client, 0, 0, g_cvHealBeaconDamage.FloatValue);
		SetHudTextParams(-0.2, 1.0, 0.7, 255, 13, 55, 255);
		ShowSyncHudText(client, g_hHudMsg, "%T", "HealBeacon_Damage", client);
	}
}

Action HealBeacon_HealTimer(Handle timer) {
	/* IF BETTER DAMAGE MODE IS ON THEN stop the timer for a while until its off */
	/* BETTER DAMAGE mode means that the players will get hurt but they wont get heal */
	if(g_bIsBetterDamageModeOn) {
		return Plugin_Handled;
	}
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		HealBeacon_DealHeal(i);
	}
	
	return Plugin_Continue;
}

stock void HealBeacon_DealHeal(int client) {
	/* if client has healbeacon then give heal to them */
	if(g_BeaconPlayersData[client].hasHealBeacon) {
		int health = GetEntProp(client, Prop_Send, "m_iHealth");
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		
		/* WE SHOULD ALWAYS CHECK IF MAXHEALTH IS MORE THAN PLAYERS HEALTH summing with the extra health */
		if((health) < maxHealth) {
			int newHealth = (health + g_cvHealBeaconHeal.IntValue);
			if(newHealth == maxHealth) {
				newHealth = maxHealth;
			}
			else if(newHealth > maxHealth) {
				newHealth = (health + 1);
			}
			
			SetEntProp(client, Prop_Data, "m_iHealth", newHealth);
		}
		
		return;
	}
	
	for(int i = 0; i < g_aHBPlayers.Length; i++) {
		int random = g_aHBPlayers.Get(i);
		float distance = GetDistanceBetween(random, client);
		
		/* if distance between both of them is less than or equal the healbeacon distance */
		if(distance <= (g_BeaconPlayersData[random].distance / 2.0)) {
			int health = GetEntProp(client, Prop_Send, "m_iHealth");
			int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
			
			/* WE SHOULD ALWAYS CHECK IF MAXHEALTH IS MORE THAN PLAYERS HEALTH summing with the extra health */
			if((health) < maxHealth) {
				int newHealth = (health + g_cvHealBeaconHeal.IntValue);
				if(newHealth == maxHealth) {
					newHealth = maxHealth;
				}
				else if(newHealth > maxHealth) {
					newHealth = (health + 1);
				}
				
				SetEntProp(client, Prop_Data, "m_iHealth", newHealth);
			}
			
			break;
		}
	}
}

stock void HealBeacon_DeleteAllTimers() {
	for(int i = 0; i <= 1; i++) {
		delete g_hRoundStart_Timer[i];
	}
	
	delete g_hDamageTimer;
	delete g_hHealTimer;
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsValidClient(i)) {
			continue;
		}
		
		delete g_hBeaconTimer[i];
	}
}

stock void SetClientNeon(int client) {
	RemoveNeon(client);
	
	int entity = CreateEntityByName("light_dynamic");
	
	if(!IsValidEntity(entity)) {
		return;
	}
	
	g_BeaconPlayersData[client].hasNeon = true;
	g_BeaconPlayersData[client].neonEntity = entity;
	
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	fOrigin[2] += 5;
	
	int color[4];
	color[0] = g_BeaconPlayersData[client].color[0];
	color[1] = g_BeaconPlayersData[client].color[1];
	color[2] = g_BeaconPlayersData[client].color[2];
	color[3] = g_BeaconPlayersData[client].color[3];
	
	char sColor[64];
	Format(sColor, sizeof(sColor), "%i %i %i %i", color[0], color[1], color[2], color[3]);
	
	DispatchKeyValue(entity, "_light", sColor);
	DispatchKeyValue(entity, "brightness", "5");
	DispatchKeyValue(entity, "distance", "150");
	DispatchKeyValue(entity, "spotlight_radius", "50");
	DispatchKeyValue(entity, "style", "0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");
	
	TeleportEntity(entity, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);
}

stock void RemoveNeon(int client) {
	if(g_BeaconPlayersData[client].neonEntity && IsValidEntity(g_BeaconPlayersData[client].neonEntity)) {
		AcceptEntityInput(g_BeaconPlayersData[client].neonEntity, "KillHierarchy");
	}
	
	g_BeaconPlayersData[client].hasNeon = false;
	g_BeaconPlayersData[client].neonEntity = -1;
}

stock void AddNewBeacon(int client, int target) {
	SetHealBeaconToClient(target);
	
	/* ANNOUNCE THAT THIS TARGET IS NOW A HEALBEACON! */
	CPrintToChatAll("%s %T", HealBeacon_Tag, "HealBeacon_AddAnnounce", client, target);
}

stock void RemoveBeacon(int client, int target) {
	/* REMOVE NEON */
	RemoveNeon(target);
	
	/* SAVE HEAL BEACON PLAYER DATA */
	g_BeaconPlayersData[target].ResetValues();
	
	/* ERASE THE TARGET INDEX FROM ARRAYLIST */
	for(int i = 0; i < g_aHBPlayers.Length; i++) {
		int random = g_aHBPlayers.Get(i);
		if(random == target) {
			g_aHBPlayers.Erase(i);
			break;
		}
	}

	/* DELETE BEACON TIMER */
	delete g_hBeaconTimer[target];
	
	/* ANNOUNCE THAT THIS DUDE HEALBEACON IS REMOVED */
	if(client > 0) {
		CPrintToChatAll("%s %T", HealBeacon_Tag, "HealBeacon_RemoveAnnounce", client, client, target);
		LogAction(client, target, "[FunModes-HealBeacon] \"%L\" removed HealBeacon from \"%L\"", client, target);
	}
}

stock void ReplaceBeacon(int client, int random, int target) {
	/* if is Repick */
	if(target == -1) {
		/* WE GOTTA REPICK a RANDOM HUMAN FOR HEALBEACON */
		int clientsCount[MAXPLAYERS + 1];
		int humansCount;
		
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsValidClient(i)) {
				continue;
			}
			
			if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
				continue;
			}
			
			if(g_BeaconPlayersData[i].hasHealBeacon) {
				continue;
			}
			
			clientsCount[humansCount++] = i;
		}
		
		if(humansCount <= 0) {
			return;
		}
		
		/* REMOVE BEACON FROM PREVIOUS HEALBEACON */
		RemoveBeacon(-1, random);
		
		/* WE CAN FINALLY GET THE NEW HEALBEACON */
		int newRandom = clientsCount[GetRandomInt(0, humansCount - 1)];
		SetHealBeaconToClient(newRandom);
		
		/* ANNOUNCE THAT THIS DUDE IS A HEALBEACON */
		CPrintToChatAll("%s %T", HealBeacon_Tag, "HealBeacon_RepickAnnounce", client, client, newRandom, random);
		return;
	}
	
	/* if is a normal replace */
	RemoveBeacon(-1, random);
	SetHealBeaconToClient(target);
	
	/* ANNOUNCE THAT THIS DUDE IS A HEALBEACON */
	CPrintToChatAll("%s %T", HealBeacon_Tag, "HealBeacon_ReplaceAnnounce", client, client, target, random);
}

/*---------------------*/
/* COMMANDS CALLBACKS */
/*---------------------*/

Action Cmd_HealBeacon(int client, int args) {
	/* Check if VIP mode is on first both modes cant be played at the same time*/
	if(g_bIsVIPModeOn) {
		if(!client) {
			ReplyToCommand(client, "%s VIP Mode is on, HealBeacon and VIP Mode can't be played together at the same time.", HealBeacon_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_VIPModeOn", client);
		}
		
		return Plugin_Handled;
	}
	
	if(g_bIsHealBeaconOn) {
		g_bIsHealBeaconOn = false;
		delete g_aHBPlayers;
		
		HealBeacon_DeleteAllTimers();
		if(!client) {
			ReplyToCommand(client, "%s HealBeacon Mode is now OFF!", HealBeacon_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		}
		
		return Plugin_Handled;
	}
	else {
		g_bIsHealBeaconOn = true;
		
		delete g_aHBPlayers;
		g_aHBPlayers = new ArrayList(ByteCountToCells(32));
		if(!client) {
			ReplyToCommand(client, "%s HealBeacon Mode is now ON!", HealBeacon_Tag);
		}
		else {
			CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Enabled", client);
		}
		
		return Plugin_Handled;
	}
}

Action Cmd_HealBeaconMenu(int client, int args) {
	if(!client) {
		return Plugin_Handled;
	}
	
	if(!g_bIsHealBeaconOn) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}
	
	HealBeacon_DisplayMainMenu(client);
	return Plugin_Handled;
}

Action Cmd_HealBeaconDistance(int client, int args) {
	if(!g_bIsHealBeaconOn) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}
	
	if(args < 2) {
		CReplyToCommand(client, "%s Usage: sm_beacon_distance <healBeacon Player> <distance>", HealBeacon_Tag);
		return Plugin_Handled;
	}
	
	char arg1[65], arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int target = FindTarget(client, arg1, false, false);
	if(target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	if(!g_BeaconPlayersData[target].hasHealBeacon) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}
	
	float distance;
	if(!StringToFloatEx(arg2, distance)) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_InvalidDistnace", client);
		return Plugin_Handled;
	}
	
	g_BeaconPlayersData[target].distance = distance;
	CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_DistanceChange", client, target, distance);
	LogAction(client, target, "[FunModes-HealBeacon] \"%L\" changed Beacon Distance of \"%L\" to \"%d\"", client, target, distance);
	return Plugin_Handled;
}

Action Cmd_HealBeaconReplace(int client, int args) {
	if(!g_bIsHealBeaconOn) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}
	
	if(args < 2) {
		CReplyToCommand(client, "%s Usage: sm_replacebeacon <healBeacon Player> <player>", HealBeacon_Tag);
		return Plugin_Handled;
	}
	
	char arg1[65], arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int healBeaconTarget = FindTarget(client, arg1, false, false);
	int target = FindTarget(client, arg2, false, false);
	
	if(healBeaconTarget < 1 || target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	if(!g_BeaconPlayersData[healBeaconTarget].hasHealBeacon) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}
	
	if(g_BeaconPlayersData[target].hasHealBeacon) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_PlayerIs", client);
		return Plugin_Handled;
	}
	
	ReplaceBeacon(client, healBeaconTarget, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconAddNew(int client, int args) {
	if(!g_bIsHealBeaconOn) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}
	
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_addnewbeacon <player>", HealBeacon_Tag);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, false, false);
	if(target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	if(g_BeaconPlayersData[target].hasHealBeacon) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_PlayerIs", client);
		return Plugin_Handled;
	}
	
	AddNewBeacon(client, target);
	LogAction(client, target, "[FunModes-HealBeacon] \"%L\" added \"%L\" with a HealBeacon.", client, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconRemove(int client, int args) {
	if(!g_bIsHealBeaconOn) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}
	
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_removebeacon <player>", HealBeacon_Tag);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, false, false);
	if(target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	if(!g_BeaconPlayersData[target].hasHealBeacon) {
		CReplyToCommand(client, "%s %T", HealBeacon_Tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}
	
	RemoveBeacon(client, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconCheckDistance(int client, int args) {
	if(!client) {
		return Plugin_Handled;
	}
	
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_checkdistance <player>", HealBeacon_Tag);
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, false, false);
	if(target < 1) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(target)) {
		ReplyToTargetError(client, COMMAND_TARGET_NOT_ALIVE);
		return Plugin_Handled;
	}
	
	float distance = GetDistanceBetween(client, target);
	CReplyToCommand(client, "%s Distance between you and %N is: {olive}%.2f.", HealBeacon_Tag, target, distance);
	return Plugin_Handled;
}

stock void HealBeacon_GetConVars(ConVar cvars[6]) {
	cvars[0] = g_cvHealBeaconTimer;
	cvars[1] = g_cvAlertTimer;
	cvars[2] = g_cvHealBeaconDamage;
	cvars[3] = g_cvHealBeaconHeal;
	cvars[4] = g_cvRandoms;
	cvars[5] = g_cvDefaultDistance;
}
