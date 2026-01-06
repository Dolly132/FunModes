/*
    (). FunModes V2:
        
    @file           VIPMode.sp
    @Usage          Functions for the VIP mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_VIPModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_VIPModeInfo

#define VIPMODE_CONVAR_TIMER 	0
#define VIPMODE_CONVAR_COUNT 	1
#define VIPMODE_CONVAR_LASER 	2
#define VIPMODE_CONVAR_VIP_MAX 	3
#define VIPMODE_CONVAR_TOGGLE	4

bool g_bDiedFromLaser[MAXPLAYERS+1];
bool g_bIsVIP[MAXPLAYERS + 1];

/* Timers */
Handle g_hKillAllTimer = null;
Handle g_hVIPRoundStartTimer = null;
Handle g_hVIPBeaconTimer[MAXPLAYERS + 1] = { null, ... };

/* CALLED ON PLUGIN START */
stock void OnPluginStart_VIPMode()
{
	THIS_MODE_INFO.name = "VIPMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-VIPMode]{lightgreen}";

	/* Commands */
	RegAdminCmd("sm_fm_vipmode", Cmd_VIPModeToggle, ADMFLAG_CONVARS, "Enable/Disable VIP Mode");
	RegAdminCmd("sm_vipmode_setvip", Cmd_SetVIP, ADMFLAG_CONVARS);
	RegConsoleCmd("sm_checkvip", Cmd_CheckVIP);
	RegAdminCmd("sm_vipmode_settings", Cmd_VIPModeSettings, ADMFLAG_CONVARS, "Open VIPMode Settings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, VIPMODE_CONVAR_TIMER, 
		"sm_vipmode_timer",	"15", "After how many seconds from round start to pick VIP",
		("15.0,25.0,40.0,60.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, VIPMODE_CONVAR_COUNT,
		"sm_vipmode_counter", "3", "After how many seconds all the other humans will be slayed after the vip dies",
		("2.0,3.0,5.0,10.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, VIPMODE_CONVAR_LASER,
		"sm_vipmode_laser", "1", ("Don't Kill all humans when vip dies to a laser, 1 = Enabled, 0 = Disabled"),
		("0,1"), "bool"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, VIPMODE_CONVAR_VIP_MAX,
		"sm_vipmode_max_vips", "1", "How many VIPs to be picked",
		("1,2,3,4,5"), "int"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, VIPMODE_CONVAR_TOGGLE,
		"sm_vipmode_enable", "1", "Enable/Disable the VIP Mode (This differes from turning it on/off)",
		("0,1"), "bool"
	);

	THIS_MODE_INFO.enableIndex = VIPMODE_CONVAR_TOGGLE;

	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[VIPMODE_CONVAR_TOGGLE].cvar.AddChangeHook(OnVIPModeToggle);	
}

void OnVIPModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_VIPMode() {}
stock void OnMapEnd_VIPMode()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);

	g_hKillAllTimer = null;
	g_hVIPRoundStartTimer = null;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hVIPBeaconTimer[i] = null;
		g_bDiedFromLaser[i] = false;
	}
}

stock void OnClientPutInServer_VIPMode(int client)
{
	if (g_bSDKHook_OnTakeDamage[client])
		return;
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_bSDKHook_OnTakeDamage[client] = true;
}

stock void OnClientDisconnect_VIPMode(int client)
{
	delete g_hVIPBeaconTimer[client];
	
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!g_bIsVIP[client])
		return;
	
	RemoveClientVIP(client, true, "VIPMode_VIPDeathDisconnect");
}

stock void ZR_OnClientInfected_VIPMode(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_VIPMode()
{
	if (!THIS_MODE_INFO.isOn)
		return;

	delete g_hKillAllTimer;
	
	/* DELETE VIP BEACON TIMER */
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bIsVIP[i] = false;
		g_bDiedFromLaser[i] = false;
		delete g_hVIPBeaconTimer[i];
	}

	delete g_hVIPRoundStartTimer;
	g_hVIPRoundStartTimer = CreateTimer(THIS_MODE_INFO.cvarInfo[VIPMODE_CONVAR_TIMER].cvar.FloatValue, VIPRoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock void Event_RoundEnd_VIPMode() {}
stock void Event_PlayerSpawn_VIPMode(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_VIPMode(Event event)
{
	if (!!THIS_MODE_INFO.isOn)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !g_bIsVIP[client])
		return;

	int team = event.GetInt("team");
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_NONE) 
		RemoveClientVIP(client, true, "VIPMode_VIPDeathSpec");
}

stock void Event_PlayerDeath_VIPMode(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;

	if (!g_bIsVIP[client])
		return;

	if (g_bDiedFromLaser[client])
	{
		CPrintToChatAll("%s %T", THIS_MODE_INFO.tag, "VIPMode_VIPDeathLaser", client, client);
		RemoveClientVIP(client, false);
		g_bDiedFromLaser[client] = false;
		return;
	}

	RemoveClientVIP(client, true, "VIPMode_VIPDeath");
}

stock void OnTakeDamagePost_VIPMode(int victim, int attacker, float damage)
{
	#pragma unused victim
	#pragma unused attacker
	#pragma unused damage
}

stock void OnTakeDamage_VIPMode(int victim, int attacker, float damage, Action &result)
{
	#pragma unused result
	
	if (!THIS_MODE_INFO.cvarInfo[VIPMODE_CONVAR_LASER].cvar.BoolValue)
		return;
	
	if (!g_bIsVIP[victim])
		return;

	if (!IsValidEntity(attacker))
		return;

	char classname[64];
	if (!GetEntityClassname(attacker, classname, sizeof(classname)))
		return;

	/* if attacker entity is not trigger_hurt */
	if (strcmp(classname, "trigger_hurt") != 0)
		return;

	/* we should now check if trigger_hurt is from a laser */
	int parent = GetEntPropEnt(attacker, Prop_Data, "m_hParent");
	if (!IsValidEntity(parent))
		return;

	bool isFromLaser = false;
	char parentClassName[64];
	if (!GetEntityClassname(parent, parentClassName, sizeof(parentClassName)))
		return;

	if (strcmp(parentClassName, "func_movelinear") == 0 || strcmp(parentClassName, "func_door") == 0)
		isFromLaser = true;
	
	if (!isFromLaser)
		return;
	
	g_bDiedFromLaser[victim] = false;
	if (damage > GetClientHealth(victim))
		g_bDiedFromLaser[victim] = true;
}

stock void OnWeaponEquip_VIPMode(int client, int weapon, Action &result)
{
	#pragma unused client
	#pragma unused weapon
	#pragma unused result
}

Action VIPMode_KillAllTimer(Handle timer)
{
	g_hKillAllTimer = null;

	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	if (GetCurrentVIPsCount() > 0)
	{
		CPrintToChatAll("%s Found a VIP player, {olive}Cancelling The kills...", THIS_MODE_INFO.tag);
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		ForcePlayerSuicide(i);
	}

	return Plugin_Continue;
}

Action VIPRoundStart_Timer(Handle timer)
{
	g_hVIPRoundStartTimer = null;

	if (THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	/* CHECK IF THERE IS ALREADY VIP SET BY ADMIN */
	if (GetCurrentVIPsCount() > 0)
		return Plugin_Stop;

	/* Lets pick a random human */
	for (int i = 0; i < THIS_MODE_INFO.cvarInfo[VIPMODE_CONVAR_VIP_MAX].cvar.IntValue; i++)
		VIP_PickRandom();
		
	return Plugin_Stop;
}

Action VIP_BeaconTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		return Plugin_Stop;
	}

	if (!THIS_MODE_INFO.isOn)
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;	
	}

	if (!IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}

	if (g_bRoundEnd)
	{
		g_hVIPBeaconTimer[client] = null;
		return Plugin_Stop;
	}

	BeaconPlayer(client, 1); 
	return Plugin_Continue;
}

public Action Cmd_VIPModeToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s VIPmode is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	bool isOn = THIS_MODE_INFO.isOn;
	if (isOn)
	{
		isOn = false;
		if (!client)
			CReplyToCommand(client, "%s VIP Mode is now OFF!", THIS_MODE_INFO.tag);
		else
			CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "VIPMode_Disabled", client);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			g_bIsVIP[i] = false;
			delete g_hVIPBeaconTimer[i];
		}
	}
	else
	{
		isOn = true;
		
		/* Events Hooks */
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		FunModes_HookEvent(g_bEvent_PlayerTeam, "player_team", Event_PlayerTeam);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
		
		if (!client)
			CReplyToCommand(client, "%s VIP Mode is now ON!", THIS_MODE_INFO.tag);
		else
			CReplyToCommand(client, "%s %T", THIS_MODE_INFO.tag, "VIPMode_Enabled", client);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, isOn, THIS_MODE_INFO.index);
	return Plugin_Handled;
}

Action Cmd_SetVIP(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s VIP Mode is currently OFF!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_vipmode_setvip <player>", THIS_MODE_INFO.tag);
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

	if (g_bIsVIP[target])
	{
		CReplyToCommand(client, "%s The specified target is already VIP!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(target) || GetClientTeam(target) != CS_TEAM_CT)
	{
		CReplyToCommand(client, "%s Cannot set VIP to a player that is not human.", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	g_bIsVIP[target] = true;
	CPrintToChatAll("%s {olive}%N {lightgreen}is a VIP!", THIS_MODE_INFO.tag, target);

	delete g_hVIPBeaconTimer[target];
	g_hVIPBeaconTimer[target] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(target), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

Action Cmd_CheckVIP(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s VIP Mode is currently OFF", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (GetCurrentVIPsCount() == 0)
	{
		CReplyToCommand(client, "%s No VIP was found!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	char vipPlayers[200];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_bIsVIP[i])
			continue;
				
		Format(vipPlayers, sizeof(vipPlayers), "%s%N, ", vipPlayers, i);
	}
	
	CReplyToCommand(client, "%s The current {purple}VIPs {olive}are: {purple}%s", THIS_MODE_INFO.tag, vipPlayers);
	return Plugin_Handled;
}

stock int GetCurrentVIPsCount()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_bIsVIP[i]) 
			continue;
				
		count++;
	}
	
	return count;
}

stock void RemoveClientVIP(int client, bool kill, const char[] translation = "")
{
	g_bIsVIP[client] = false;
	delete g_hVIPBeaconTimer[client];
	
	CPrintToChatAll("%s %t", THIS_MODE_INFO.tag, translation, client);
	
	if (kill && GetCurrentVIPsCount() == 0)
	{
		int counter = THIS_MODE_INFO.cvarInfo[VIPMODE_CONVAR_COUNT].cvar.IntValue;
		CPrintToChatAll("%s %t", THIS_MODE_INFO.tag, "VIPMode_KillAll", counter);

		delete g_hKillAllTimer;
		g_hKillAllTimer = CreateTimer(float(counter), VIPMode_KillAllTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

stock void VIP_PickRandom() 
{
	/* Lets pick a random human */
	int clientsCount[MAXPLAYERS + 1];
	int humansCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT || g_bIsVIP[i])
			continue;

		clientsCount[humansCount++] = i;
	}

	if (humansCount <= 0)
		return;
	
	int random = clientsCount[GetRandomInt(0, (humansCount - 1))];
	if (random < 1)
		return;

	g_bIsVIP[random] = true;
	CPrintToChatAll("%s {olive}%N {lightgreen}is a VIP!", THIS_MODE_INFO.tag, random);

	delete g_hVIPBeaconTimer[random];
	g_hVIPBeaconTimer[random] = CreateTimer(1.0, VIP_BeaconTimer, GetClientUserId(random), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

/* VIPMode Settings */
public Action Cmd_VIPModeSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_VIPModeSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");
	menu.AddItem(NULL_STRING, "Check current VIPs", THIS_MODE_INFO.isOn ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem(NULL_STRING, "Set Player VIP", THIS_MODE_INFO.isOn ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Menu_VIPModeSettings(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				DisplayModeInfo(param1, g_iPreviousModeIndex[param1]);
		}

		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					ShowCvarsInfo(param1, THIS_MODE_INFO);
				}

				case 1:
				{
					ShowCurrentVIPs(param1);
				}

				case 2:
				{
					ShowSetPlayerVIP(param1);
				}
			}
		}
	}

	return 0;
}

void ShowCurrentVIPs(int client)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
		return;

	Menu menu = new Menu(Menu_VIPCurrentVIPs);

	menu.SetTitle("%s - Current VIPs List", THIS_MODE_INFO.name);

	if (!THIS_MODE_INFO.isOn)
		menu.AddItem(NULL_STRING, "The VIPMode is currently Off!", ITEMDRAW_DISABLED);
	else
	{
		bool found = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!g_bIsVIP[i])
				continue;
			
			found = true;
			int userid = GetClientUserId(i);
			
			char useridStr[10];
			IntToString(userid, useridStr, sizeof(useridStr));

			char menuItem[70];
			FormatEx(menuItem, sizeof(menuItem), "[#%d] %N - Remove", userid, i);

			menu.AddItem(useridStr, menuItem);
		}

		if (!found)
			menu.AddItem(NULL_STRING, "There's no VIP player yet!", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_VIPCurrentVIPs(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_VIPModeSettings(param1, 0);
		}

		case MenuAction_Select:
		{
			char useridStr[10];
			menu.GetItem(param2, useridStr, sizeof(useridStr));

			int userid = StringToInt(useridStr);
			int client = GetClientOfUserId(userid);
			if (!client || !g_bIsVIP[client])
			{
				CPrintToChat(param1, "%s The selected player either left or is no longer {purple]VIP!", THIS_MODE_INFO.tag);
				ShowCurrentVIPs(param1);
				return 0;
			}

			RemoveClientVIP(client, false, "VIPMode_AdminRemove");
			ShowCurrentVIPs(param1);
		}
	}
	
	return 0;
}

void ShowSetPlayerVIP(int client)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
		return;

	Menu menu = new Menu(Menu_VIPSetPlayerVIP);

	menu.SetTitle("%s - Players List - Select a player to set them to a VIP", THIS_MODE_INFO.name);

	if (!THIS_MODE_INFO.isOn)
		menu.AddItem(NULL_STRING, "The VIPMode is currently Off!", ITEMDRAW_DISABLED);
	else
	{
		bool found = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_bIsVIP[i] || !IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
				continue;
			
			if (ZR_IsClientZombie(i))
				continue;

			found = true;
			int userid = GetClientUserId(i);
			
			char useridStr[10];
			IntToString(userid, useridStr, sizeof(useridStr));

			char menuItem[70];
			FormatEx(menuItem, sizeof(menuItem), "[#%d] %N - Set VIP", userid, i);

			menu.AddItem(useridStr, menuItem);
		}

		if (!found)
			menu.AddItem(NULL_STRING, "No player was found!", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_VIPSetPlayerVIP(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_VIPModeSettings(param1, 0);
		}

		case MenuAction_Select:
		{
			char useridStr[10];
			menu.GetItem(param2, useridStr, sizeof(useridStr));

			int userid = StringToInt(useridStr);
			int client = GetClientOfUserId(userid);
			if (!client || g_bIsVIP[client] || ZR_IsClientZombie(client))
			{
				CPrintToChat(param1, "%s The selected player either left, died or is currently a {purple]VIP!", THIS_MODE_INFO.tag);
				ShowCurrentVIPs(param1);
				return 0;
			}

			g_bIsVIP[client] = true;
			CPrintToChatAll("%s {olive}%N {lightgreen}is a VIP!", THIS_MODE_INFO.tag, client);

			delete g_hVIPBeaconTimer[client];
			g_hVIPBeaconTimer[client] = CreateTimer(1.0, VIP_BeaconTimer, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

			ShowCurrentVIPs(param1);
		}
	}
	
	return 0;
}