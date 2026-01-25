/*
    (). FunModes V2:
        
    @file           DoubleJump.sp
    @Usage          Functions for the DoubleJump mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_DoubleJumpInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_DoubleJumpInfo

#define DOUBLEJUMP_CONVAR_BOOST		0
#define DOUBLEJUMP_CONVAR_MAX_JUMPS	1
#define DOUBLEJUMP_CONVAR_HUMANS	2
#define DOUBLEJUMP_CONVAR_ZOMBIES	3
#define DOUBLEJUMP_CONVAR_TOGGLE	4

/* CALLED on Plugin Start */
stock void OnPluginStart_DoubleJump()
{
	THIS_MODE_INFO.name = "DoubleJump";
	THIS_MODE_INFO.tag = "{gold}[FunModes-DoubleJump]{lightgreen}";

	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_doublejump", Cmd_DoubleJumpToggle, ADMFLAG_CONVARS, "Enable/Disable Double Jump mode.");

	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DOUBLEJUMP_CONVAR_BOOST,
		"sm_doublejump_boost", "260.0", "The amount of vertical boost to apply to double jumps.",
		("150.0,260.0,300.0,320.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DOUBLEJUMP_CONVAR_MAX_JUMPS,
		"sm_doublejump_max_jumps", "1", "How many re-jumps the player can do while he is in the air.",
		("1,2,3,4,5"), "int"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DOUBLEJUMP_CONVAR_HUMANS,
		"sm_doublejump_humans", "1", "Enable/Disable Double jump for humans.",
		("0,1"), "bool"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DOUBLEJUMP_CONVAR_ZOMBIES,
		"sm_doublejump_zombies", "0", "Enable/Disable Double jump zombies.",
		("0,1"), "bool"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DOUBLEJUMP_CONVAR_TOGGLE,
		"sm_doublejump_enable", "1", "Enable/Disable Double Jump mode",
		("0,1"), "bool"
	);

	THIS_MODE_INFO.enableIndex = DOUBLEJUMP_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_TOGGLE].cvar.AddChangeHook(OnDoubleJumpModeToggle);
}

void OnDoubleJumpModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_DoubleJump() {}
stock void OnMapEnd_DoubleJump()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_DoubleJump(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_DoubleJump(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_DoubleJump(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_DoubleJump() {}
stock void Event_RoundEnd_DoubleJump() {}
stock void Event_PlayerSpawn_DoubleJump(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_DoubleJump(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_DoubleJump(int client)
{
	#pragma unused client
}

public Action Cmd_DoubleJumpToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s Double Jump mode is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll("%s Double Jump is now {olive}%s. %s", THIS_MODE_INFO.tag, (THIS_MODE_INFO.isOn) ? "Enabled" : "Disabled",
													(THIS_MODE_INFO.isOn) ? "You can re-jump while you are in the air." : "");

	if(THIS_MODE_INFO.isOn)
	{
		CPrintToChatAll("%s Humans Double Jump: {olive}%s\n%s Zombies Double Jump: {olive}%s.", 
						THIS_MODE_INFO.tag, (THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_HUMANS].cvar.BoolValue) ? "Enabled" : "Disabled",
						THIS_MODE_INFO.tag, (THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_ZOMBIES].cvar.BoolValue) ? "Enabled" : "Disabled");
	}
			
	return Plugin_Handled;
}

/* SM DOUBLEJUMP 1.1.0, ALL CREDITS GO TO - https://forums.alliedmods.net/showpost.php?p=2759524&postcount=37 */
void OnPlayerRunCmdPost_DoubleJump(int client, int buttons, int impulse)
{
	#pragma unused buttons
	#pragma unused impulse
	
	if(!THIS_MODE_INFO.isOn || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	if((!THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_HUMANS].cvar.BoolValue && GetClientTeam(client) == CS_TEAM_CT) || (!THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_ZOMBIES].cvar.BoolValue && GetClientTeam(client) == CS_TEAM_T))
		return;

	static bool inGround;
	static bool inJump;
	static bool wasJump[MAXPLAYERS + 1];
	static bool landed[MAXPLAYERS + 1];

	inGround 	= !!(GetEntityFlags(client) & FL_ONGROUND);
	inJump 		= !!(GetClientButtons(client) & IN_JUMP);

	if(!landed[client])
	{
		if(THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_MAX_JUMPS].cvar.IntValue)
		{
			static int jumps[MAXPLAYERS+1];
			if(inGround)
				jumps[client] = 0;
			else if(!wasJump[client] && inJump && jumps[client]++ <= THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_MAX_JUMPS].cvar.IntValue)
				ApplyNewJump(client);
		}
		else if(!inGround && !wasJump[client] && inJump)
		{
			ApplyNewJump(client);
		}			
	}

	landed[client]	= inGround;
	wasJump[client]	= inJump;

	return;
}

stock void ApplyNewJump(int client)
{
	static float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	vel[2] = THIS_MODE_INFO.cvarInfo[DOUBLEJUMP_CONVAR_BOOST].cvar.FloatValue;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
}

/* DoubleJump Settings */
public void Cmd_DoubleJumpSettings(int client)
{
	Menu menu = new Menu(Menu_DoubleJumpSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_DoubleJumpSettings(Menu menu, MenuAction action, int param1, int param2)
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