/*
    (). FunModes V2:
        
    @file           MakoKickers.sp
    @Usage         	Functions for the MakoKickers Mode.
    				
*/

/*
	These are kickers from Fierce's mako event.
	Autobhop + sv_airaccelerate 1000
	Low gravity
	Real life mode: block enabled + no transparency
	1 hp + no heal + fall damage
	300 ping
	-300 ping
	Slippery ground + inverted controls
	Flashbang mode: all CTs get 2 flashbangs (normal flashbang from deathmatch)
	Failnades mode: CTs won't be able to buy weapons. They will have 1000 failnades and a knife.
	Invisible mode: every player (human/zombie) becomes invisible, except on radar.
	
	by @Schonzer
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_MakoKickersInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_MakoKickersInfo

#define MAKOKICKERS_CONVAR_HEGRENADES_COUNT	0
#define MAKOKICKERS_CONVAR_PING				1
#define MAKOKICKERS_CONVAR_HEGRENADE_KB		2
#define MAKOKICKERS_CONVAR_TOGGLE 			3

static char g_ConVarsToChange[][][] =
{
	{ "sv_autobunnyhopping", "1" },
	{ "sv_airaccelerate", "1000" },
	{ "sv_gravity", "100" },
	{ "sm_noblock_players", "0" },
	{ "sm_noblock_grenades", "0" },
	{ "sm_pvis_minplayers_enable", "-1" },
	{ "sv_accelerate", "-5" },
	{ "zr_greneffect_flash_light", "0" },
	{ "zr_weapons_zmarket", "0" },
    { "zr_weapons_zmarket_rebuy", "0" }
};

static char g_ConVarsOriginalValues[sizeof(g_ConVarsToChange)][10];

float g_fOriginalHGKB;

stock void OnPluginStart_MakoKickers()
{
	THIS_MODE_INFO.name = "MakoKickers";
	THIS_MODE_INFO.tag = "{gold}[FunModes-MakoKickers]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_makokickers", Cmd_MakoKickersToggle, ADMFLAG_CONVARS, "Turn MakoKickers Mode On/Off");
	RegAdminCmd("sm_makokickers_settings", Cmd_MakoKickersSettings, ADMFLAG_CONVARS, "Open MakoKickers Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MAKOKICKERS_CONVAR_HEGRENADES_COUNT,
		"sm_makokickers_hegrenades_count", "1000", "How many grenades to give to humans?",
		("1,5,10,50,100"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MAKOKICKERS_CONVAR_PING,
		"sm_makokickers_ping", "300", "The value to sum with players' original ping",
		("-300,300"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MAKOKICKERS_CONVAR_HEGRENADE_KB,
		"sm_makokickers_hegrenades_kb", "6.0", "The new KB value of hegrenades during MakoKickers mode",
		("2.0,4.0,5.0,10.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MAKOKICKERS_CONVAR_TOGGLE,
		"sm_makokickers_enable", "1", "Enable/Disable MakoKickers Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = MAKOKICKERS_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[MAKOKICKERS_CONVAR_TOGGLE].cvar.AddChangeHook(OnMakoKickersModeToggle);
}

void OnMakoKickersModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_MakoKickers() {}
stock void OnMapEnd_MakoKickers()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_MakoKickers(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_MakoKickers(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_MakoKickers(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	SetVariantString("rendermode 10");
	AcceptEntityInput(client, "AddOutput");
}

stock void Event_RoundStart_MakoKickers() {}
stock void Event_RoundEnd_MakoKickers() {}
stock void Event_PlayerSpawn_MakoKickers(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	RequestFrame(PlayerSpawn_Check_MakoKickers, client);
}

void PlayerSpawn_Check_MakoKickers(int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || ZR_IsClientZombie(client))
		return;
	
	SetupHuman_MakoKickers(client);
}

stock void Event_PlayerTeam_MakoKickers(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_MakoKickers(int client)
{
	#pragma unused client
}

public Action Cmd_MakoKickersToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s MakoKickers Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s MakoKickers Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_PlayerSpawn, "player_spawn", Event_PlayerSpawn);
		
		ToggleMakoKickers(true);
	}
	else
		ToggleMakoKickers(false);
		
	return Plugin_Handled;
}

/* MakoKickers Settings */
public Action Cmd_MakoKickersSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_MakoKickersSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");
	
	menu.AddItem(NULL_STRING, "MakoKickers start-up Cvars/Commands: (Not Updated on LIVE)\n", ITEMDRAW_DISABLED);
	
	for (int i = 0; i < sizeof(g_ConVarsToChange); i++)
	{
		char menuItem[64];
		FormatEx(menuItem, sizeof(menuItem), "# %s - %s", g_ConVarsToChange[i][0], g_ConVarsToChange[i][1]);
		
		menu.AddItem(NULL_STRING, menuItem, ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_MakoKickersSettings(Menu menu, MenuAction action, int param1, int param2)
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

void ToggleMakoKickers(bool toggle)
{
	if (toggle)
	{
		g_fOriginalHGKB = ZR_GetWeaponKnockback("hegrenade");
		ZR_SetWeaponKnockback("hegrenade", THIS_MODE_INFO.cvarInfo[MAKOKICKERS_CONVAR_HEGRENADE_KB].cvar.FloatValue);
	}
	else
		ZR_SetWeaponKnockback("hegrenade", g_fOriginalHGKB);
		
	ConVar cvars[sizeof(g_ConVarsToChange)];
	
	for (int i = 0; i < sizeof(cvars); i++)
	{
		ConVar cvar = FindConVar(g_ConVarsToChange[i][0]);
		if (cvar == null)
			continue;
		
		if (toggle)
		{
			cvar.GetString(g_ConVarsOriginalValues[i], sizeof(g_ConVarsOriginalValues[]));
			cvar.SetString(g_ConVarsToChange[i][1]);
		}
		else
			cvar.SetString(g_ConVarsOriginalValues[i]);
		
		delete cvar;
	}
}

void SetupHuman_MakoKickers(int client)
{
	for (int i = 0; i < 5; i++)
	{
		if (i == CS_SLOT_KNIFE)
			continue;
		
		int w = -1;

		while ((w = GetPlayerWeaponSlot(client, i)) != -1)
		{
			if (IsValidEntity(w) && IsValidEdict(w))
			{
				RemovePlayerItem(client, w);
				AcceptEntityInput(w, "Kill");
			}
		}
	}
	
	GiveGrenadesToClient(client, GrenadeType_HEGrenade, THIS_MODE_INFO.cvarInfo[MAKOKICKERS_CONVAR_HEGRENADES_COUNT].cvar.IntValue);
	
	SetVariantString("rendermode 10");
	AcceptEntityInput(client, "AddOutput");
}