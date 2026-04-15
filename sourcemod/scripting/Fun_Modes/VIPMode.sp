/*
    (). FunModes V2:

    @file           VIPMode.sp
    @Usage          Functions for the VIPMode Mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_VIPModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_VIPModeInfo

#define VIPMODE_CONVAR_TIMER     0
#define VIPMODE_CONVAR_COUNT     1
#define VIPMODE_CONVAR_LASER     2
#define VIPMODE_CONVAR_VIP_MAX   3
#define VIPMODE_CONVAR_TOGGLE    4

bool g_bDiedFromLaser[MAXPLAYERS + 1];
bool g_bIsVIP[MAXPLAYERS + 1];

Handle g_hKillAllTimer = null;
Handle g_hVIPRoundStartTimer = null;
Handle g_hVIPBeaconTimer[MAXPLAYERS + 1] = { null, ... };

float g_fVIP_Timer;
float g_fVIP_KillDelay;
bool g_bVIP_LaserException;
int g_iVIP_Max;
bool g_bVIP_Enabled;

stock void OnPluginStart_VIPMode()
{
	THIS_MODE_INFO.name = "VIPMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-VIPMode]{lightgreen}";

	RegAdminCmd("sm_fm_vipmode", Cmd_VIPModeToggle, ADMFLAG_CONVARS, "Turn VIPMode On/Off");
	RegAdminCmd("sm_vipmode_setvip", Cmd_SetVIP, ADMFLAG_CONVARS, "Set a player as VIP");
	RegConsoleCmd("sm_checkvip", Cmd_CheckVIP);
	RegAdminCmd("sm_vipmode_settings", Cmd_VIPModeSettings, ADMFLAG_CONVARS, "Open VIPMode Settings Menu");

	DECLARE_FM_CVAR(
		VIPMODE_CONVAR_TIMER, "sm_vipmode_timer",
		"15", "How many seconds after round start before choosing the VIPs",
		("15,25,40,60"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[VIPMODE_CONVAR_TIMER].HookChange(VIPMode_OnConVarChange);

	DECLARE_FM_CVAR(
		VIPMODE_CONVAR_COUNT, "sm_vipmode_counter",
		"3", "How many seconds to wait before killing all CTs when all VIPs die",
		("2,3,5,10"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[VIPMODE_CONVAR_COUNT].HookChange(VIPMode_OnConVarChange);

	DECLARE_FM_CVAR(
		VIPMODE_CONVAR_LASER, "sm_vipmode_laser",
		"1", "Whether laser deaths should be ignored as a VIP death exception",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[VIPMODE_CONVAR_LASER].HookChange(VIPMode_OnConVarChange);

	DECLARE_FM_CVAR(
		VIPMODE_CONVAR_VIP_MAX, "sm_vipmode_max_vips",
		"1", "Maximum number of VIPs to pick each round",
		("1,2,3,4,5"), CONVAR_INT
	);
	THIS_MODE_INFO.cvars[VIPMODE_CONVAR_VIP_MAX].HookChange(VIPMode_OnConVarChange);

	DECLARE_FM_CVAR(
		VIPMODE_CONVAR_TOGGLE, "sm_vipmode_enable",
		"1", "Enable/Disable VIPMode (This differs from turning it on/off)",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[VIPMODE_CONVAR_TOGGLE].HookChange(VIPMode_OnConVarChange);

	THIS_MODE_INFO.enableIndex = VIPMODE_CONVAR_TOGGLE;

	FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_VIPMode()
{
	int modeIndex = THIS_MODE_INFO.index;

	g_fVIP_Timer = _FUNMODES_CVAR_GET_VALUE(modeIndex, VIPMODE_CONVAR_TIMER, Float);
	g_fVIP_KillDelay = _FUNMODES_CVAR_GET_VALUE(modeIndex, VIPMODE_CONVAR_COUNT, Float);
	g_bVIP_LaserException = _FUNMODES_CVAR_GET_VALUE(modeIndex, VIPMODE_CONVAR_LASER, Bool);
	g_iVIP_Max = _FUNMODES_CVAR_GET_VALUE(modeIndex, VIPMODE_CONVAR_VIP_MAX, Int);
	g_bVIP_Enabled = _FUNMODES_CVAR_GET_VALUE(modeIndex, VIPMODE_CONVAR_TOGGLE, Bool);
}

void VIPMode_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
	switch (cvarIndex)
	{
		case VIPMODE_CONVAR_TIMER:
			g_fVIP_Timer = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case VIPMODE_CONVAR_COUNT:
			g_fVIP_KillDelay = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case VIPMODE_CONVAR_LASER:
			g_bVIP_LaserException = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

		case VIPMODE_CONVAR_VIP_MAX:
			g_iVIP_Max = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);

		case VIPMODE_CONVAR_TOGGLE:
		{
			bool val = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);
			if (THIS_MODE_INFO.isOn)
				CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

			g_bVIP_Enabled = val;
		}
	}
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
	if (!THIS_MODE_INFO.isOn)
		return;

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
	g_hVIPRoundStartTimer = CreateTimer(g_fVIP_Timer, VIPRoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock void Event_RoundEnd_VIPMode() {}
stock void Event_PlayerSpawn_VIPMode(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_VIPMode(Event event)
{
	if (!THIS_MODE_INFO.isOn)
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

	if (!THIS_MODE_INFO.isOn || !g_bVIP_LaserException)
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

public Action Cmd_VIPModeToggle(int client, int args)
{
	if (!g_bVIP_Enabled)
	{
		CReplyToCommand(client, "%s VIPMode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll("%s VIPMode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");

	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
	}

	delete g_hKillAllTimer;
	delete g_hVIPRoundStartTimer;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (THIS_MODE_INFO.isOn && IsClientInGame(i))
			OnClientPutInServer_VIPMode(i);

		g_bIsVIP[i] = false;
		g_bDiedFromLaser[i] = false;
		delete g_hVIPBeaconTimer[i];
	}

	return Plugin_Handled;
}

Action VIPRoundStart_Timer(Handle timer)
{
	g_hVIPRoundStartTimer = null;

	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	for (int i = 0; i < g_iVIP_Max; i++)
		VIP_PickRandom();

	return Plugin_Stop;
}

stock void RemoveClientVIP(int client, bool kill, const char[] translation = "")
{
	g_bIsVIP[client] = false;
	delete g_hVIPBeaconTimer[client];
	
	CPrintToChatAll("%s %t", THIS_MODE_INFO.tag, translation, client);
	
	if (kill && GetCurrentVIPsCount() == 0)
	{
		CPrintToChatAll("%s %t", THIS_MODE_INFO.tag, "VIPMode_KillAll", RoundToNearest(g_fVIP_KillDelay));

		delete g_hKillAllTimer;
		g_hKillAllTimer = CreateTimer(g_fVIP_KillDelay, VIPMode_KillAllTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

stock void VIP_PickRandom()
{
	int players[MAXPLAYERS + 1];
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT || g_bIsVIP[i])
			continue;

		players[count] = i;
		count++;
	}

	if (!count)
		return;

	int client = players[GetRandomInt(0, count - 1)];

	g_bIsVIP[client] = true;

	delete g_hVIPBeaconTimer[client];
	g_hVIPBeaconTimer[client] = CreateTimer(
		1.0,
		VIP_BeaconTimer,
		GetClientUserId(client),
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
	);

	CPrintToChatAll("%s %N is VIP!", THIS_MODE_INFO.tag, client);
}

Action VIP_BeaconTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!client || !IsPlayerAlive(client) || !THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	BeaconPlayer(client, 1);

	return Plugin_Continue;
}

Action VIPMode_KillAllTimer(Handle timer)
{
	g_hKillAllTimer = null;

	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		ForcePlayerSuicide(i);
	}

	return Plugin_Stop;
}

stock int GetCurrentVIPsCount()
{
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bIsVIP[i])
			count++;
	}

	return count;
}

public Action Cmd_SetVIP(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Handled;

	if (args < 1)
		return Plugin_Handled;

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));

	int target = FindTarget(client, arg, false, false);

	if (target < 1 || !IsPlayerAlive(target) || ZR_IsClientZombie(target))
		return Plugin_Handled;

	g_bIsVIP[target] = true;

	delete g_hVIPBeaconTimer[target];
	g_hVIPBeaconTimer[target] = CreateTimer(
		1.0,
		VIP_BeaconTimer,
		GetClientUserId(target),
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
	);

	CPrintToChatAll("%s %N has been set as VIP!", THIS_MODE_INFO.tag, target);

	return Plugin_Handled;
}

public Action Cmd_CheckVIP(int client, int args)
{
	bool found;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_bIsVIP[i])
			continue;

		CReplyToCommand(client, "%s VIP: %N", THIS_MODE_INFO.tag, i);
		found = true;
	}

	if (!found)
		CReplyToCommand(client, "%s no VIP", THIS_MODE_INFO.tag);

	return Plugin_Handled;
}

public Action Cmd_VIPModeSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_VIPModeSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);
	menu.AddItem(NULL_STRING, "Show Cvars\n");

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
			ShowCvarsInfo(param1, THIS_MODE_INFO);
		}
	}

	return 0;
}
