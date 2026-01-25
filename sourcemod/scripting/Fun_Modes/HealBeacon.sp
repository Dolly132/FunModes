/*
    (). FunModes V2:
        
    @file           HealBeacon.sp
    @Usage          Functions for the HealBeacon mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_HBInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_HBInfo

bool g_bIsBetterDamageModeOn;

/* Arraylist to save client indexes of the heal beaconed players */
ArrayList g_aHBPlayers;

/* Timers */
Handle g_hRoundStart_Timer[2] = { null, ... };
Handle g_hDamageTimer = null;
Handle g_hHealTimer = null;
Handle g_hBeaconTimer[MAXPLAYERS + 1] = { null, ... };

#define HB_CONVAR_BEACON_TIMER 		0
#define HB_CONVAR_ALERT_TIMER 		1
#define HB_CONVAR_BEACON_DAMAGE		2
#define HB_CONVAR_BEACON_HEAL		3
#define HB_CONVAR_RANDOMS			4
#define HB_CONVAR_DEFAULT_DISTANCE	5
#define HB_CONVAR_TOGGLE			6

enum struct BeaconPlayers
{
	bool hasHealBeacon;
	bool hasNeon;
	int color[4];
	float distance;
	int neonEntity;
	
	void SetColor(int setColor[4])
	{
		this.color[0] = setColor[0];
		this.color[1] = setColor[1];
		this.color[2] = setColor[2];
		this.color[3] = setColor[3];
	}
	
	void ResetColor()
	{
		this.color[0] = g_ColorDefault[0];
		this.color[1] = g_ColorDefault[1];
		this.color[2] = g_ColorDefault[2];
		this.color[3] = g_ColorDefault[3];
	}
	
	void ResetValues()
	{
		this.hasHealBeacon = false;
		this.ResetColor();
		this.distance = THIS_MODE_INFO.cvarInfo[HB_CONVAR_DEFAULT_DISTANCE].cvar.FloatValue;
		this.neonEntity = -1;
	}
}

BeaconPlayers g_BeaconPlayersData[MAXPLAYERS + 1];

/* Called in OnPluginStart */
stock void OnPluginStart_HealBeacon()
{
	THIS_MODE_INFO.name = "HealBeacon";
	THIS_MODE_INFO.tag = "{gold}[FunModes-HealBeacon]{lightgreen}";

	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_healbeacon", Cmd_HealBeaconToggle, ADMFLAG_CONVARS, "Enable/Disable Healbeacon");
	RegAdminCmd("sm_healbeacon", Cmd_HealBeaconSettings, ADMFLAG_CONVARS, "Shows healbeacon menu");
	RegAdminCmd("sm_beacon_distance", Cmd_HealBeaconDistance, ADMFLAG_CONVARS, "Change beacon distance");
	RegAdminCmd("sm_replacebeacon", Cmd_HealBeaconReplace, ADMFLAG_BAN, "Replace an already heal beaconed player with another one");
	RegAdminCmd("sm_addnewbeacon", Cmd_HealBeaconAddNew, ADMFLAG_BAN, "Add a new heal beaconed player");
	RegAdminCmd("sm_removebeacon", Cmd_HealBeaconRemove, ADMFLAG_BAN, "Remove heal beacon player");
	RegConsoleCmd("sm_checkdistance", Cmd_HealBeaconCheckDistance, "...");

	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_BEACON_TIMER,
		"sm_beacon_timer", "20.0", "The time that will start picking random players at round start",
		("20.0,30.0,40.0,60.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_ALERT_TIMER,
		"sm_beacon_alert_timer", "10.0", "How much time in seconds the damage will start being applied from heal beacon as an alert for the other humans",
		("5.0,8.0,10.0,15.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_BEACON_DAMAGE,
		"sm_beacon_damage", "5.0", "The damage that the heal beacon will give",
		("2.0,5.0,8.0,10.0,15.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_BEACON_HEAL,
		"sm_beacon_heal", "1", "How much heal beacon should heal the players in 1 second",
		("1,2,3,4,5,10"), "int"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_RANDOMS,
		"sm_healbeacon_randoms", "2", "How many random players should get the heal beacon",
		("1,2,3,4,5,10"), "int"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_DEFAULT_DISTANCE,
		"sm_healbeacon_distance", "400.0", "Default distance of beacon to give",
		("100.0,200.0,400.0,500.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, HB_CONVAR_TOGGLE,
		"sm_healbeacon_enable", "1", "Enable/Disable HealBeacon mode.",
		("0,1"), "bool"
	);

	THIS_MODE_INFO.enableIndex = HB_CONVAR_TOGGLE;

	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[HB_CONVAR_TOGGLE].cvar.AddChangeHook(OnHBModeToggle);
}

void OnHBModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_HealBeacon() {}
stock void OnMapEnd_HealBeacon()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);

	for (int i = 1; i <= MaxClients; i++)
	{
		g_hBeaconTimer[i] = null;
	}
	g_hRoundStart_Timer[0] = null;
	g_hRoundStart_Timer[1] = null;
 	g_hDamageTimer = null;
	g_hHealTimer = null;
}

stock void OnClientPutInServer_HealBeacon(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_HealBeacon(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	if (!g_BeaconPlayersData[client].hasHealBeacon)
	{
		delete g_hBeaconTimer[client];
		g_BeaconPlayersData[client].ResetValues();
		return;
	}

	RemoveBeacon(-1, client);
	CPrintToChatAll("%s {olive}%N {lightgreen}disconnected with HealBeacon.", THIS_MODE_INFO.tag, client);
}

stock void ZR_OnClientInfected_HealBeacon(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_HealBeacon()
{
	/* DELETE TIMER HANDLES SO WE DONT GET ERRORS */
	HealBeacon_DeleteAllTimers();

	/* CHECK IF ARRAYLIST IS NOT NULL AND THEN ERASE ALL CLIENTS INDEXES IN ARRAYLIST */
	if (g_aHBPlayers == null)
		return;

	g_aHBPlayers.Clear();

	if (!THIS_MODE_INFO.isOn)
		return;

	/* RESET COUNTER */
	g_iCounter = 0;

	/* LETS CREATE THE FIRST ROUND START TIMER */
	g_hRoundStart_Timer[0] = CreateTimer(THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_TIMER].cvar.FloatValue, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock void Event_RoundEnd_HealBeacon() {}
stock void Event_PlayerSpawn_HealBeacon(int client)
{
	#pragma unused client
}

stock void Event_PlayerDeath_HealBeacon(int client)
{
	if (!THIS_MODE_INFO.isOn || !g_BeaconPlayersData[client].hasHealBeacon)
		return;

	RemoveBeacon(-1, client);
	CPrintToChatAll("%s {olive}%N {lightgreen}died with HealBeacon.", THIS_MODE_INFO.tag, client);
}

stock void Event_PlayerTeam_HealBeacon(Event event)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !g_BeaconPlayersData[client].hasHealBeacon)
		return;

	int team = event.GetInt("team");
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_NONE)
	{
		RemoveBeacon(-1, client);
		CPrintToChatAll("%s {olive}%N {lightgreen}moved to spectator team with HealBeacon.", THIS_MODE_INFO.tag, client);
	}
}

Action RoundStart_Timer(Handle timer)
{
	g_hRoundStart_Timer[0] = null;
	
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;
		
	/* Let's now pick the random players */
	for (int i = 0; i < THIS_MODE_INFO.cvarInfo[HB_CONVAR_RANDOMS].cvar.IntValue; i++)
	{
		GetRandomPlayer();
	}

	/* Delete the previous timer handler if found so we dont assign a new CreateTimer over the old one */
	delete g_hRoundStart_Timer[1];
	g_hRoundStart_Timer[1] = CreateTimer(1.0, RoundStart_CountTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

Action RoundStart_CountTimer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hRoundStart_Timer[1] = null;
		return Plugin_Stop;
	}
	
	int alertTime = THIS_MODE_INFO.cvarInfo[HB_CONVAR_ALERT_TIMER].cvar.IntValue;

	if (g_iCounter >= alertTime)
	{
		HealBeacon_Setup();
		g_hRoundStart_Timer[1] = null;
		return Plugin_Stop;
	}

	/* Lets send the hud message to all clients */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		char message[256];
		FormatEx(message, sizeof(message), "%T", "HealBeacon_Alert", i, (alertTime - g_iCounter));
		SendHudText(i, message);
	}

	g_iCounter++;
	return Plugin_Continue;
}

stock void GetRandomPlayer()
{
	int clientsCount[MAXPLAYERS + 1];
	int humansCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		/* if client is already heal beaconed then dont include them in */
		if (g_BeaconPlayersData[i].hasHealBeacon)
			continue;

		clientsCount[humansCount++] = i;
	}

	if (humansCount <= 0 || humansCount < THIS_MODE_INFO.cvarInfo[HB_CONVAR_RANDOMS].cvar.IntValue)
		return;

	int random = clientsCount[GetRandomInt(0, (humansCount - 1))];
	if (random < 1)
		return;

	/* Lets now apply healbeacon to the choosen one */
	SetHealBeaconToClient(random);
	CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "HealBeacon_AddAnnounce", random, random);
}

stock void SetHealBeaconToClient(int client)
{
	/* Lets save the healbeacon player data they are needed */
	g_BeaconPlayersData[client].hasHealBeacon = true;
	g_BeaconPlayersData[client].distance = THIS_MODE_INFO.cvarInfo[HB_CONVAR_DEFAULT_DISTANCE].cvar.FloatValue;
	g_BeaconPlayersData[client].ResetColor();

	/* BEACON THE PLAYER */
	delete g_hBeaconTimer[client];
	g_hBeaconTimer[client] = CreateTimer(0.1, HealBeacon_BeaconTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	/* Lets now push client indexes to the arraylist */
	g_aHBPlayers.Push(client);
}

stock void HealBeacon_Setup()
{
	/* Lets create the damage timer and delete the handle first so we dont get problems */
	delete g_hDamageTimer;
	g_hDamageTimer = CreateTimer(0.7, HealBeacon_DamageTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	/* Lets create the heal timer and delete the handle first so we dont get problems */
	delete g_hHealTimer;
	g_hHealTimer = CreateTimer(1.0, HealBeacon_HealTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action HealBeacon_BeaconTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		return Plugin_Stop;
	}
	
	if (!THIS_MODE_INFO.isOn)
	{
		g_hBeaconTimer[client] = null;
		return Plugin_Stop;
	}
	
	if (!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT || !g_BeaconPlayersData[client].hasHealBeacon)
	{
		g_hBeaconTimer[client] = null;
		return Plugin_Stop;
	}

	BeaconPlayer(client, 0, g_BeaconPlayersData[client].distance, g_BeaconPlayersData[client].color);
	return Plugin_Continue;
}

Action HealBeacon_DamageTimer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hDamageTimer = null;
		return Plugin_Stop;
	}
	
	/* if round is ending */
	if (g_bRoundEnd)
		return Plugin_Handled;

	/* if all healbeacon players died */
	if (g_aHBPlayers.Length == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
				continue;

			SDKHooks_TakeDamage(i, 0, 0, THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_DAMAGE].cvar.FloatValue);
		}

		return Plugin_Handled;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;
		
		/* if client is healbeaconed then continue the loop and ignore that client */
		if (g_BeaconPlayersData[i].hasHealBeacon)
			continue;

		HealBeacon_DealDamage(i);
	}

	return Plugin_Continue;
}

stock void HealBeacon_DealDamage(int client)
{
	bool isFar = false;

	for (int i = 0; i < g_aHBPlayers.Length; i++)
	{
		int random = g_aHBPlayers.Get(i);
		
		// squarred distance, better for performance
		float distance = GetDistanceBetween(random, client, true);

		/* if player is not far from any heal beacon player then we need to stop the loop */
		float beaconRadiusHalf = g_BeaconPlayersData[random].distance / 2.0;
		if (distance < (beaconRadiusHalf * beaconRadiusHalf))
		{
			isFar = false;
			break;
		}

		/* else */
		isFar = true;
	}

	/* if player is far then do damage and warn them */
	if (isFar)
	{
		SDKHooks_TakeDamage(client, 0, 0, THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_DAMAGE].cvar.FloatValue);
		char sMessage[256];
		FormatEx(sMessage, sizeof(sMessage), "%T", "HealBeacon_Damage", client);
		SendHudText(client, sMessage, true);
	}
}

Action HealBeacon_HealTimer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hHealTimer = null;
		return Plugin_Stop;
	}
	
	/* IF BETTER DAMAGE MODE IS ON THEN stop the timer for a while until its off */
	/* BETTER DAMAGE mode means that the players will get hurt but they wont get heal */
	if (g_bIsBetterDamageModeOn)
		return Plugin_Handled;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		HealBeacon_DealHeal(i);
	}

	return Plugin_Continue;
}

stock void HealBeacon_DealHeal(int client)
{
	/* if client has healbeacon then give heal to them */
	if (g_BeaconPlayersData[client].hasHealBeacon)
	{
		int health = GetEntProp(client, Prop_Send, "m_iHealth");
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");

		/* WE SHOULD ALWAYS CHECK IF MAXHEALTH IS MORE THAN PLAYERS HEALTH summing with the extra health */
		if ((health) < maxHealth)
		{
			int newHealth = (health + THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_HEAL].cvar.IntValue);

			if (newHealth == maxHealth)
				newHealth = maxHealth;
			else if (newHealth > maxHealth)
				newHealth = (health + 1);

			SetEntProp(client, Prop_Data, "m_iHealth", newHealth);
		}

		return;
	}
	
	for (int i = 0; i < g_aHBPlayers.Length; i++)
	{
		int random = g_aHBPlayers.Get(i);
		float distance = GetDistanceBetween(random, client);

		/* if distance between both of them is less than or equal the healbeacon distance */
		if (distance <= (g_BeaconPlayersData[random].distance / 2.0))
		{
			int health = GetEntProp(client, Prop_Send, "m_iHealth");
			int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");

			/* WE SHOULD ALWAYS CHECK IF MAXHEALTH IS MORE THAN PLAYERS HEALTH summing with the extra health */
			if ((health) < maxHealth)
			{
				int newHealth = (health + THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_HEAL].cvar.IntValue);

				if (newHealth == maxHealth)
					newHealth = maxHealth;
				else if (newHealth > maxHealth)
					newHealth = (health + 1);

				SetEntProp(client, Prop_Data, "m_iHealth", newHealth);
			}

			break;
		}
	}
}

stock void HealBeacon_DeleteAllTimers()
{
	for (int i = 0; i <= 1; i++) {
		delete g_hRoundStart_Timer[i];
	}

	delete g_hDamageTimer;
	delete g_hHealTimer;

	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hBeaconTimer[i];
	}
}

stock void SetClientNeon(int client)
{
	RemoveNeon(client);

	int entity = CreateEntityByName("light_dynamic");

	if (!IsValidEntity(entity))
		return;

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

stock void RemoveNeon(int client)
{
	if (g_BeaconPlayersData[client].neonEntity && IsValidEntity(g_BeaconPlayersData[client].neonEntity))
		AcceptEntityInput(g_BeaconPlayersData[client].neonEntity, "KillHierarchy");

	g_BeaconPlayersData[client].hasNeon = false;
	g_BeaconPlayersData[client].neonEntity = -1;
}

stock void AddNewBeacon(int client, int target)
{
	SetHealBeaconToClient(target);

	/* ANNOUNCE THAT THIS TARGET IS NOW A HEALBEACON! */
	CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "HealBeacon_AddAnnounce", client, target);
}

stock void RemoveBeacon(int client, int target)
{
	/* REMOVE NEON */
	RemoveNeon(target);

	/* SAVE HEAL BEACON PLAYER DATA */
	g_BeaconPlayersData[target].ResetValues();

	/* ERASE THE TARGET INDEX FROM ARRAYLIST */
	for (int i = 0; i < g_aHBPlayers.Length; i++)
	{
		int random = g_aHBPlayers.Get(i);
		if (random == target)
		{
			g_aHBPlayers.Erase(i);
			break;
		}
	}

	/* DELETE BEACON TIMER */
	delete g_hBeaconTimer[target];

	/* ANNOUNCE THAT THIS DUDE HEALBEACON IS REMOVED */
	if (client > 0)
	{
		CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "HealBeacon_RemoveAnnounce", client, client, target);
		LogAction(client, target, "[FunModes-HealBeacon] \"%L\" removed HealBeacon from \"%L\"", client, target);
	}
}

stock void ReplaceBeacon(int client, int random, int target)
{
	/* if is Repick */
	if (target == -1)
	{
		/* WE GOTTA REPICK a RANDOM HUMAN FOR HEALBEACON */
		int clientsCount[MAXPLAYERS + 1];
		int humansCount;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
				continue;

			if (g_BeaconPlayersData[i].hasHealBeacon)
				continue;

			clientsCount[humansCount++] = i;
		}
		
		if (humansCount <= 0)
			return;

		/* REMOVE BEACON FROM PREVIOUS HEALBEACON */
		RemoveBeacon(-1, random);

		/* WE CAN FINALLY GET THE NEW HEALBEACON */
		int newRandom = clientsCount[GetRandomInt(0, humansCount - 1)];
		SetHealBeaconToClient(newRandom);

		/* ANNOUNCE THAT THIS DUDE IS A HEALBEACON */
		CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "HealBeacon_RepickAnnounce", client, client, newRandom, random);
		return;
	}

	/* if is a normal replace */
	RemoveBeacon(-1, random);
	SetHealBeaconToClient(target);

	/* ANNOUNCE THAT THIS DUDE IS A HEALBEACON */
	CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "HealBeacon_ReplaceAnnounce", client, client, target, random);
}

/*---------------------*/
/* COMMANDS CALLBACKS */
/*---------------------*/

public Action Cmd_HealBeaconToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s Healbeacon is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (THIS_MODE_INFO.isOn)
	{
		delete g_aHBPlayers;

		HealBeacon_DeleteAllTimers();
	
		if (!client)
			ReplyToCommand(client, "%s HealBeacon Mode is now OFF!", THIS_MODE_INFO.tag);
		else
			CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
	}
	else
	{
		/* Event hooks */
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		FunModes_HookEvent(g_bEvent_PlayerTeam, "player_team", Event_PlayerTeam);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
		
		delete g_aHBPlayers;
		g_aHBPlayers = new ArrayList(ByteCountToCells(32));
		if (!client)
			ReplyToCommand(client, "%s HealBeacon Mode is now ON!", THIS_MODE_INFO.tag);
		else
			CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Enabled", client);
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	return Plugin_Handled;
}

public Action Cmd_HealBeaconSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}

	HealBeacon_DisplayMainMenu(client);
	return Plugin_Handled;
}

Action Cmd_HealBeaconDistance(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "%s Usage: sm_beacon_distance <healBeacon Player> <distance>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg1[65], arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	int target = FindTarget(client, arg1, false, false);
	if (target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if (!g_BeaconPlayersData[target].hasHealBeacon)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}

	float distance;
	if (!StringToFloatEx(arg2, distance))
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_InvalidDistnace", client);
		return Plugin_Handled;
	}

	g_BeaconPlayersData[target].distance = distance;
	CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_DistanceChange", client, target, distance);
	LogAction(client, target, "[FunModes-HealBeacon] \"%L\" changed Beacon Distance of \"%L\" to \"%d\"", client, target, distance);
	return Plugin_Handled;
}

Action Cmd_HealBeaconReplace(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "%s Usage: sm_replacebeacon <healBeacon Player> <player>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg1[65], arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	int healBeaconTarget = FindTarget(client, arg1, false, false);
	int target = FindTarget(client, arg2, false, false);

	if (healBeaconTarget < 1 || target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if (!g_BeaconPlayersData[healBeaconTarget].hasHealBeacon)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}

	if (g_BeaconPlayersData[target].hasHealBeacon)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIs", client);
		return Plugin_Handled;
	}

	ReplaceBeacon(client, healBeaconTarget, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconAddNew(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_addnewbeacon <player>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, false, false);
	if (target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if (g_BeaconPlayersData[target].hasHealBeacon)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIs", client);
		return Plugin_Handled;
	}

	AddNewBeacon(client, target);
	LogAction(client, target, "[FunModes-HealBeacon] \"%L\" added \"%L\" with a HealBeacon.", client, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconRemove(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Disabled", client);
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_removebeacon <player>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, false, false);
	if (target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if (!g_BeaconPlayersData[target].hasHealBeacon)
	{
		CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIsNot", client);
		return Plugin_Handled;
	}

	RemoveBeacon(client, target);
	return Plugin_Handled;
}

Action Cmd_HealBeaconCheckDistance(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_checkdistance <player>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, false, false);
	if (target < 1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_IN_GAME);
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(target))
	{
		ReplyToTargetError(client, COMMAND_TARGET_NOT_ALIVE);
		return Plugin_Handled;
	}

	float distance = GetDistanceBetween(client, target);
	CReplyToCommand(client, "%s Distance between you and %N is: {olive}%.2f.", THIS_MODE_INFO.tag, target, distance);
	return Plugin_Handled;
}

#include "Fun_Modes/HealBeacon_Menus.sp"