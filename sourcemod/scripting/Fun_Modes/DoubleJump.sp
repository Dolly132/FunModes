
#pragma semicolon 1
#pragma newdecls required

ModeInfo g_DoubleJumpInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_DoubleJumpInfo

#define DOUBLEJUMP_CONVAR_BOOST     0
#define DOUBLEJUMP_CONVAR_MAX_JUMPS 1
#define DOUBLEJUMP_CONVAR_HUMANS    2
#define DOUBLEJUMP_CONVAR_ZOMBIES   3
#define DOUBLEJUMP_CONVAR_TOGGLE    4

float g_fDoubleJump_Boost;
int g_iDoubleJump_MaxJumps;

bool g_bDoubleJump_Humans;
bool g_bDoubleJump_Zombies;
bool g_bDoubleJump_Enabled;

stock void OnPluginStart_DoubleJump()
{
	THIS_MODE_INFO.name = "DoubleJump";
	THIS_MODE_INFO.tag = "{gold}[FunModes-DoubleJump]{lightgreen}";

	RegAdminCmd("sm_fm_doublejump", Cmd_DoubleJumpToggle, ADMFLAG_CONVARS);
	RegAdminCmd("sm_doublejump_settings", Cmd_DoubleJumpSettings, ADMFLAG_CONFIG);

	DECLARE_FM_CVAR(
		DOUBLEJUMP_CONVAR_BOOST, "sm_doublejump_boost",
		"260.0", "Vertical boost applied to double jump",
		("150.0,260.0,300.0,320.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[DOUBLEJUMP_CONVAR_BOOST].HookChange(DoubleJump_OnConVarChange);

	DECLARE_FM_CVAR(
		DOUBLEJUMP_CONVAR_MAX_JUMPS, "sm_doublejump_max_jumps",
		"1", "Number of mid-air jumps",
		("1,2,3,4,5"), CONVAR_INT
	);
	THIS_MODE_INFO.cvars[DOUBLEJUMP_CONVAR_MAX_JUMPS].HookChange(DoubleJump_OnConVarChange);

	DECLARE_FM_CVAR(
		DOUBLEJUMP_CONVAR_HUMANS, "sm_doublejump_humans",
		"1", "Enable for humans",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[DOUBLEJUMP_CONVAR_HUMANS].HookChange(DoubleJump_OnConVarChange);

	DECLARE_FM_CVAR(
		DOUBLEJUMP_CONVAR_ZOMBIES, "sm_doublejump_zombies",
		"0", "Enable for zombies",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[DOUBLEJUMP_CONVAR_ZOMBIES].HookChange(DoubleJump_OnConVarChange);

	DECLARE_FM_CVAR(
		DOUBLEJUMP_CONVAR_TOGGLE, "sm_doublejump_enable",
		"1", "Enable DoubleJump",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[DOUBLEJUMP_CONVAR_TOGGLE].HookChange(DoubleJump_OnConVarChange);

	THIS_MODE_INFO.enableIndex = DOUBLEJUMP_CONVAR_TOGGLE;

	FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_DoubleJump()
{
	int modeIndex = THIS_MODE_INFO.index;

	g_fDoubleJump_Boost =
		_FUNMODES_CVAR_GET_VALUE(modeIndex, DOUBLEJUMP_CONVAR_BOOST, Float);

	g_iDoubleJump_MaxJumps =
		_FUNMODES_CVAR_GET_VALUE(modeIndex, DOUBLEJUMP_CONVAR_MAX_JUMPS, Int);

	g_bDoubleJump_Humans =
		_FUNMODES_CVAR_GET_VALUE(modeIndex, DOUBLEJUMP_CONVAR_HUMANS, Bool);

	g_bDoubleJump_Zombies =
		_FUNMODES_CVAR_GET_VALUE(modeIndex, DOUBLEJUMP_CONVAR_ZOMBIES, Bool);

	g_bDoubleJump_Enabled =
		_FUNMODES_CVAR_GET_VALUE(modeIndex, DOUBLEJUMP_CONVAR_TOGGLE, Bool);
}

void DoubleJump_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
	switch (cvarIndex)
	{
		case DOUBLEJUMP_CONVAR_BOOST:
			g_fDoubleJump_Boost =
				_FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case DOUBLEJUMP_CONVAR_MAX_JUMPS:
			g_iDoubleJump_MaxJumps =
				_FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);

		case DOUBLEJUMP_CONVAR_HUMANS:
			g_bDoubleJump_Humans =
				_FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

		case DOUBLEJUMP_CONVAR_ZOMBIES:
			g_bDoubleJump_Zombies =
				_FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

		case DOUBLEJUMP_CONVAR_TOGGLE:
		{
			bool val =
				_FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

			if (THIS_MODE_INFO.isOn)
				CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

			g_bDoubleJump_Enabled = val;
		}
	}
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
	if (!g_bDoubleJump_Enabled)
	{
		CReplyToCommand(client, "%s DoubleJump disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll(
		"%s DoubleJump is now %s",
		THIS_MODE_INFO.tag,
		THIS_MODE_INFO.isOn ? "Enabled" : "Disabled"
	);

	if (THIS_MODE_INFO.isOn)
	{
		CPrintToChatAll(
			"%s Humans: %s | Zombies: %s",
			THIS_MODE_INFO.tag,
			g_bDoubleJump_Humans ? "Enabled" : "Disabled",
			g_bDoubleJump_Zombies ? "Enabled" : "Disabled"
		);
	}

	return Plugin_Handled;
}

void OnPlayerRunCmdPost_DoubleJump(int client, int buttons, int impulse)
{
	#pragma unused impulse

	if (!THIS_MODE_INFO.isOn || !IsPlayerAlive(client))
		return;

	bool isHuman = GetClientTeam(client) == CS_TEAM_CT;
	bool isZombie = GetClientTeam(client) == CS_TEAM_T;

	if ((isHuman && !g_bDoubleJump_Humans)
	|| (isZombie && !g_bDoubleJump_Zombies))
		return;

	static bool wasJump[MAXPLAYERS+1];
	static int jumps[MAXPLAYERS+1];

	bool onGround = !!(GetEntityFlags(client) & FL_ONGROUND);
	bool pressingJump = !!(buttons & IN_JUMP);

	if (onGround)
		jumps[client] = 0;

	else if (!wasJump[client]
	&& pressingJump
	&& jumps[client]++ <= g_iDoubleJump_MaxJumps)
		ApplyNewJump(client);

	wasJump[client] = pressingJump;
}

stock void ApplyNewJump(int client)
{
	float vel[3];

	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);

	vel[2] = g_fDoubleJump_Boost;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
}

public Action Cmd_DoubleJumpSettings(int client, int args)
{
	Menu menu = new Menu(Menu_DoubleJumpSettings);

	menu.SetTitle("%s Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars");

	menu.ExitBackButton = true;

	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
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
			ShowCvarsInfo(param1, THIS_MODE_INFO);
	}

	return 0;
}
