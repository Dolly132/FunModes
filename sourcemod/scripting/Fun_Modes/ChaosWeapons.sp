/*
    (). FunModes V2:
        
    @file           ChaosWeapons.sp
    @Usage          Funcitons for the ChaosWeapons mode.
*/

 /*
	Chaos Weapons: A mode where every 30 seconds or 1 minute, 
	a global message says what weapon will be used like "Only the AK47 will push the zombies for the next 30 seconds!" 
	and only the named weapon will have normal knockback, any other weapon will have 0.1 knockback (It wont push zombies) 
	making the humans buy a certain weapon all the time and buy all the variety of weapons in the shop.
	
	By @kiku-san
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_ChaosWeaponsInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_ChaosWeaponsInfo

#define CHAOSWEAPONS_CONVAR_TIMER_INTERVAL	0
#define CHAOSWEAPONS_CONVAR_KNOCKBACK		1
#define CHAOSWEAPONS_CONVAR_COUNTDOWN		2
#define CHAOSWEAPONS_CONVAR_TOGGLE 			3

Handle g_hChaosWeaponsTimer;

char g_sChaosWeaponCurrent[32];

char g_ChaosWeaponsList[][] = 
{
	"mac10", "tmp", "mp5navy", "ump45", "p90", /* SMGs */
	"galil", "famas", "ak47", "m4a1", "aug", "sg552", /* Rifles */
	"m3", "xm1014" /* Shotguns */
};

float g_fOriginalWeaponsKB[sizeof(g_ChaosWeaponsList)];

/* ConVars Values variables */
float g_fChaosWeapons_TimerInterval;
float g_fChaosWeapons_Knockback;

int g_iChaosWeapons_Countdown;

bool g_bChaosWeapons_Enabled;

stock void OnPluginStart_ChaosWeapons()
{
	THIS_MODE_INFO.name = "ChaosWeapons";
	THIS_MODE_INFO.tag = "{gold}[FunModes-ChaosWeapons]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_chaosweapons", Cmd_ChaosWeaponsToggle, ADMFLAG_CONVARS, "Turn ChaosWeapons Mode On/Off");
	RegAdminCmd("sm_chaosweapons_settings", Cmd_ChaosWeaponsSettings, ADMFLAG_CONVARS, "Open ChaosWeapons Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		CHAOSWEAPONS_CONVAR_TIMER_INTERVAL, "sm_chaosweapons_timer_interval",
		"30.0", "Every how many seconds to keep picking a random weapon?",
		("10.0,15.0,20.0,30.0"), CONVAR_FLOAT
	);

	THIS_MODE_INFO.cvars[CHAOSWEAPONS_CONVAR_TIMER_INTERVAL].HookChange(ChaosWeapons_OnConVarChange);

	DECLARE_FM_CVAR(
		CHAOSWEAPONS_CONVAR_KNOCKBACK, "sm_chaosweapons_knockback",
		"0.1", "Knockback to set of other weapons",
		("0.1,0.2,0.5,1.0"), CONVAR_FLOAT
	);

	THIS_MODE_INFO.cvars[CHAOSWEAPONS_CONVAR_KNOCKBACK].HookChange(ChaosWeapons_OnConVarChange);

	DECLARE_FM_CVAR(
		CHAOSWEAPONS_CONVAR_COUNTDOWN, "sm_chaosweapons_countdown",
		"10", "How many seconds for the countdown",
		("5,10,15,20"), CONVAR_INT
	);

	THIS_MODE_INFO.cvars[CHAOSWEAPONS_CONVAR_COUNTDOWN].HookChange(ChaosWeapons_OnConVarChange);

	DECLARE_FM_CVAR(
		CHAOSWEAPONS_CONVAR_TOGGLE, "sm_chaosweapons_enable",
		"1", "Enable/Disable ChaosWeapons Mode (This differs from turning it on/off)",
		("0,1"), CONVAR_BOOL
	);

	THIS_MODE_INFO.cvars[CHAOSWEAPONS_CONVAR_TOGGLE].HookChange(ChaosWeapons_OnConVarChange);

	THIS_MODE_INFO.enableIndex = CHAOSWEAPONS_CONVAR_TOGGLE;

	FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_ChaosWeapons()
{
	int modeIndex = THIS_MODE_INFO.index;

	g_fChaosWeapons_TimerInterval = _FUNMODES_CVAR_GET_VALUE(modeIndex, CHAOSWEAPONS_CONVAR_TIMER_INTERVAL, Float);
	g_fChaosWeapons_Knockback = _FUNMODES_CVAR_GET_VALUE(modeIndex, CHAOSWEAPONS_CONVAR_KNOCKBACK, Float);

	g_iChaosWeapons_Countdown = _FUNMODES_CVAR_GET_VALUE(modeIndex, CHAOSWEAPONS_CONVAR_COUNTDOWN, Int);

	g_bChaosWeapons_Enabled = _FUNMODES_CVAR_GET_VALUE(modeIndex, CHAOSWEAPONS_CONVAR_TOGGLE, Bool);
}

void ChaosWeapons_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
	switch (cvarIndex)
	{
		case CHAOSWEAPONS_CONVAR_TIMER_INTERVAL:
		{
			g_fChaosWeapons_TimerInterval = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);
		}

		case CHAOSWEAPONS_CONVAR_KNOCKBACK:
		{
			g_fChaosWeapons_Knockback = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);
		}

		case CHAOSWEAPONS_CONVAR_COUNTDOWN:
		{
			g_iChaosWeapons_Countdown = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);
		}

		case CHAOSWEAPONS_CONVAR_TOGGLE:
		{
			bool val = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);
			if (THIS_MODE_INFO.isOn)
				CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

			g_bChaosWeapons_Enabled = val;
		}
	}
}

stock void OnMapStart_ChaosWeapons() {}
stock void OnMapEnd_ChaosWeapons()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	
	g_hChaosWeaponsTimer = null;
}

stock void OnClientPutInServer_ChaosWeapons(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_ChaosWeapons(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_ChaosWeapons(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_ChaosWeapons() {}
stock void Event_RoundEnd_ChaosWeapons() {}
stock void Event_PlayerSpawn_ChaosWeapons(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_ChaosWeapons(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_ChaosWeapons(int client)
{
	#pragma unused client
}

public Action Cmd_ChaosWeaponsToggle(int client, int args)
{
	if (!g_bChaosWeapons_Enabled)
	{
		CReplyToCommand(client, "%s ChaosWeapons Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s ChaosWeapons Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		g_hChaosWeaponsTimer = CreateTimer(g_fChaosWeapons_TimerInterval, Timer_ChaosWeapons, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		CPrintToChatAll("%s a Random weapon will get normal knockback and the others will get their knockback nerfed every %.2f seconds!", THIS_MODE_INFO.tag, g_fChaosWeapons_TimerInterval);
		
		SetAllWeaponsKnockback(g_fChaosWeapons_Knockback, _, true);
		
		PickRandomWeapon();
	}
	else
	{
		delete g_hChaosWeaponsTimer;
		SetAllWeaponsKnockback(_, _, _, true);
	}
	
	return Plugin_Handled;
}

/* ChaosWeapons Settings */
public Action Cmd_ChaosWeaponsSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_ChaosWeaponsSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_ChaosWeaponsSettings(Menu menu, MenuAction action, int param1, int param2)
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

Action Timer_ChaosWeapons(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hChaosWeaponsTimer = null;
		return Plugin_Handled;
	}
	
	CreateTimer(1.0, Timer_ChaosWeaponsRepeat, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	return Plugin_Continue;
}

Action Timer_ChaosWeaponsRepeat(Handle timer)
{
	static int counter;
	if (!THIS_MODE_INFO.isOn || g_bRoundEnd || !g_bMotherZombie)
	{
		counter = 0;
		return Plugin_Stop;
	}

	if (++counter >= g_iChaosWeapons_Countdown)
	{
		counter = 0;
		PickRandomWeapon();
		return Plugin_Stop;
	}

	char msg[128];
	FormatEx
	(
		msg, sizeof(msg), "[ChaosWeapons] The weapon that pushes zombies will change in %d seconds!", 
		g_iChaosWeapons_Countdown - counter
	);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		SendHudText(i, msg, _, 1);
	}

	return Plugin_Continue;
}

void PickRandomWeapon()
{
	int index = GetRandomInt(0, sizeof(g_ChaosWeaponsList) - 1);
	
	FormatEx(g_sChaosWeaponCurrent, sizeof(g_sChaosWeaponCurrent), "weapon_%s", g_ChaosWeaponsList[index]);
	SetAllWeaponsKnockback(g_fChaosWeapons_Knockback, index);
	
	char msg[255];
	FormatEx(
		msg, sizeof(msg),
		"Only the [%s] will push the zombies for the next %.0f seconds\nPress F to buy it!",
		StrToUpper(g_ChaosWeaponsList[index]),
		g_fChaosWeapons_TimerInterval
	);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		SendHudText(i, msg, _, 1);
		CPrintToChat(i, "%s %s", THIS_MODE_INFO.tag, msg);
	}
}

stock char[] StrToUpper(const char[] buffer)
{
	int len = strlen(buffer);
	char myChar[32];
	
	for (int i = 0; i < len; i++)
	{
		char c = buffer[i];
		if (c >= 'a' && c <= 'z')
			c &= ~0x20;
			
		myChar[i] = c;
	}
	
	return myChar;
}

void SetAllWeaponsKnockback(float kb = 0.0, int index = -1, bool firstTime = false, bool turnOff = false)
{
	for (int i = 0; i < sizeof(g_ChaosWeaponsList); i++)
	{	
		if (turnOff || (index >= 0 && i == index))
		{
			ZR_SetWeaponKnockback(g_ChaosWeaponsList[i], g_fOriginalWeaponsKB[i]);
			continue;
		}
		
		if (firstTime)
			g_fOriginalWeaponsKB[i] = ZR_GetWeaponKnockback(g_ChaosWeaponsList[i]);
		
		ZR_SetWeaponKnockback(g_ChaosWeaponsList[i], kb);
	}
}

stock void OnPlayerRunCmdPost_ChaosWeapons(int client, int buttons, int impulse)
{
	#pragma unused buttons
	
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
		return;
		
	static float playersTime[MAXPLAYERS + 1];
	
	float currentTime = GetGameTime();
	if (currentTime <= playersTime[client])
		return;
		
	// https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/server/player.cpp#L6073
	if (impulse == 100)
	{	
		playersTime[client] = currentTime + 2.0;
		
		char curWeapon[sizeof(g_sChaosWeaponCurrent)];
		strcopy(curWeapon, sizeof(curWeapon), g_sChaosWeaponCurrent);
		
		int weapon = 0; 
		
		ReplaceString(curWeapon, sizeof(curWeapon), "weapon_", "");
		int price = ZR_GetWeaponZMarketPrice(curWeapon);
		
		int cash = GetEntProp(client, Prop_Send, "m_iAccount");
		if (cash < price)
		{
			CPrintToChat(client, "%s Insufficent fund", THIS_MODE_INFO.tag);
			return;
		}
		
		weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		if (IsValidEntity(weapon))
		{
			SDKHooks_DropWeapon(client, weapon);
			RemoveEntity(weapon);
		}
		
		weapon = GivePlayerItem(client, g_sChaosWeaponCurrent);
		if (!IsValidEntity(weapon))
			return;
			
		if (g_hSwitchSDKCall != null)
			SDKCall(g_hSwitchSDKCall, client, weapon, 0);
		
		SetEntProp(client, Prop_Send, "m_iAccount", cash - price);
	}
}
