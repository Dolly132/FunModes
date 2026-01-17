/*
    (). FunModes V2:
        
    @file           ChaosWeapons.sp
    @Usage         	Funcitons for the ChaosWeapons mode.
    				
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
#define CHAOSWEAPONS_CONVAR_TOGGLE 			2

Handle g_hChaosWeaponsTimer;

char g_ChaosWeaponsList[][] = 
{
	"ELITE", "DEAGLE", /* Pistols */
	"MAC10", "TMP", "MP5NAVY", "UMP45", "P90", /* SMGs */
	"GALIL", "FAMAS", "AK47", "M4A1", "AUG", "SG552", /* Rifles */
	"M3", "XM1014" /* Shotguns */
};

float g_fOriginalWeaponsKB[sizeof(g_ChaosWeaponsList)];

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
		THIS_MODE_INFO.cvarInfo, CHAOSWEAPONS_CONVAR_TIMER_INTERVAL,
		"sm_chaosweapons_timer_interval", "30.0", "Every how many seconds to keep picking a random weapon?",
		("10.0,15.0,20.0,30.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CHAOSWEAPONS_CONVAR_KNOCKBACK,
		"sm_chaosweapons_knockback", "0.1", "Knockback to set of other weapons",
		("0.1,0.2,0.5,1.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CHAOSWEAPONS_CONVAR_TOGGLE,
		"sm_chaosweapons_enable", "1", "Enable/Disable ChaosWeapons Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = CHAOSWEAPONS_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[CHAOSWEAPONS_CONVAR_TOGGLE].cvar.AddChangeHook(OnChaosWeaponsModeToggle);
}

void OnChaosWeaponsModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
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
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s ChaosWeapons Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s ChaosWeapons Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		float interval = THIS_MODE_INFO.cvarInfo[CHAOSWEAPONS_CONVAR_TIMER_INTERVAL].cvar.FloatValue;
		g_hChaosWeaponsTimer = CreateTimer(interval, Timer_ChaosWeapons, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		CPrintToChatAll("%s a Random weapon will get normal knockback and the others will get their knockback nerfed every %.2f seconds!", THIS_MODE_INFO.tag, interval);
		
		SetAllWeaponsKnockback(THIS_MODE_INFO.cvarInfo[CHAOSWEAPONS_CONVAR_KNOCKBACK].cvar.FloatValue, _, true);
		
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
	
	PickRandomWeapon();
	return Plugin_Continue;
}

void PickRandomWeapon()
{
	int index = GetRandomInt(0, sizeof(g_ChaosWeaponsList) - 1);
	
	SetAllWeaponsKnockback(THIS_MODE_INFO.cvarInfo[CHAOSWEAPONS_CONVAR_KNOCKBACK].cvar.FloatValue, index);
	
	char msg[255];
	FormatEx(msg, sizeof(msg), "Only the [%s] will push the zombies for the next %d seconds!", g_ChaosWeaponsList[index], THIS_MODE_INFO.cvarInfo[CHAOSWEAPONS_CONVAR_TIMER_INTERVAL].cvar.IntValue);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		SendHudText(i, msg, _, 1);
		CPrintToChat(i, "%s %s", THIS_MODE_INFO.tag, msg);
	}
}

void SetAllWeaponsKnockback(float kb = 0.0, int index = -1, bool firstTime = false, bool turnOff = false)
{
	for (int i = 0; i < sizeof(g_ChaosWeaponsList); i++)
	{	
		int len = strlen(g_ChaosWeaponsList[i]);
		char[] lower = new char[len + 1];
		
		for (int j = 0; j < len; j++)
		{
			char c = g_ChaosWeaponsList[i][j];
			if (c >= 'A' && c <= 'Z')
				c |= 0x20;
			
			lower[j] = c;
		}
		
		if (turnOff || (index >= 0 && i == index))
		{
			ZR_SetWeaponKnockback(lower, g_fOriginalWeaponsKB[i]);
			continue;
		}
		
		if (firstTime)
			g_fOriginalWeaponsKB[i] = ZR_GetWeaponKnockback(lower);
		
		ZR_SetWeaponKnockback(lower, kb);
	}
}