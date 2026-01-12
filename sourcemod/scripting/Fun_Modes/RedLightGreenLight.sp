#pragma semicolon 1
#pragma newdecls required

ModeInfo g_RLGLInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_RLGLInfo

bool g_bEnableDetecting;

char countDownPath[PLATFORM_MAX_PATH];

float g_fOriginalSpeed[MAXPLAYERS + 1];

/* Timers */
Handle g_hRLGLTimer;
Handle g_hRLGLDetectTimer;
Handle g_hRLGLWarningTimer;

#define RLGL_CONVAR_TIME_BETWEEN_DAMAGE 		0
#define RLGL_CONVAR_FREEZE_TIME 				1
#define RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MIN	2
#define RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MAX	3
#define RLGL_CONVAR_DAMAGE						4
#define RLGL_CONVAR_WARNING_TIME				5
#define RLGL_CONVAR_ZOMBIES_SPEED				6
#define RLGL_CONVAR_COUNTDOWN_FOLDER			7
#define RLGL_CONVAR_TOGGLE						8

/* CALLED on Plugin Start */
stock void OnPluginStart_RLGL()
{
	THIS_MODE_INFO.name = "RLGL";
	THIS_MODE_INFO.tag = "{gold}[FunModes-RedLightGreenLight]{lightgreen}";

	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_rlgl", Cmd_RLGLToggle, ADMFLAG_CONVARS, "Enable/Disable RedLightGreenLight mode.");

	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_TIME_BETWEEN_DAMAGE, 
		"sm_rlgl_time_between_damage", "0.1", "The timer interval for player to detect their movement",
		("0.1,0.3,0.5,0.8"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_FREEZE_TIME, 
		"sm_rlgl_freeze_time", "5.0", "How many seconds the movement detection should be disabled after",
		("2.0,5.0,10.0,15.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MIN, 
		"sm_rlgl_time_between_redlights_min", "20.0", "After how many seconds to keep repeating the redlights (MIN VALUE)",
		("20.0,30.0,40.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MAX, 
		"sm_rlgl_time_between_redlights_max", "30.0", "After how many seconds to keep repeating the redlights (MAX VALUE, SET TO 0 to disable min/max)",
		("25.0,35.0,45.0,65.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_DAMAGE,
		"sm_rlgl_damage", "5.0", "Damage to apply to the player that is moving while its a red light",
		("1.0,2.0,3.0,4.0,5.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_WARNING_TIME,
		"sm_rlgl_warning_time", "8.0", "Time in seconds to warn the players before red light is on",
		("5.0,8.0,10.0,15.0,20.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_ZOMBIES_SPEED,
		"sm_rlgl_zombies_speed", "0.5", ("Zombies speed during red light, if set to 0 then it is disabled"),
		("0.0,0.2,0.5,0.8,1.5,2.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_COUNTDOWN_FOLDER,
		"sm_rlgl_countdown_folder", "zr/countdown/$.mp3", "Countdown folder and the files that can be used for sound",
		"", ""
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, RLGL_CONVAR_TOGGLE,
		"sm_rlgl_enable", "1", "Enable/Disable the RLGL Mode (This differes from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = RLGL_CONVAR_TOGGLE;

	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_TOGGLE].cvar.AddChangeHook(OnRLGLModeToggle);	
}

void OnRLGLModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_RLGL() 
{
	THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_COUNTDOWN_FOLDER].cvar.GetString(countDownPath, sizeof(countDownPath));
	
	for (int i = 1; i <= THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_WARNING_TIME].cvar.IntValue; i++)
	{
		char sndPath[PLATFORM_MAX_PATH];
		strcopy(sndPath, sizeof(sndPath), countDownPath);
		
		char numStr[3];
		IntToString(i, numStr, sizeof(numStr));
		ReplaceString(sndPath, sizeof(sndPath), "$", numStr);
		
		PrecacheSound(sndPath);
		FormatEx(sndPath, sizeof(sndPath), "sound/%s", sndPath);
		AddFileToDownloadsTable(sndPath);
	}
}

stock void OnMapEnd_RLGL()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);

	g_hRLGLTimer = null;
	g_hRLGLDetectTimer = null;
	g_hRLGLWarningTimer = null;
}

stock void OnClientPutInServer_RLGL(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_RLGL(int client)
{
	g_fOriginalSpeed[client] = 0.0;
}

stock void ZR_OnClientInfected_RLGL(int client)
{
	if (!(THIS_MODE_INFO.isOn && g_bEnableDetecting))
		return;

	float speed = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_ZOMBIES_SPEED].cvar.FloatValue;
	if (speed <= 0.0)
		return;

	g_fOriginalSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
}

stock void Event_RoundStart_RLGL()
{
	delete g_hRLGLWarningTimer;
	delete g_hRLGLTimer;
	delete g_hRLGLDetectTimer;
	
	if (THIS_MODE_INFO.isOn)
		StartRLGLTimer();
}

stock void Event_RoundEnd_RLGL() {}
stock void Event_PlayerSpawn_RLGL(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_RLGL(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_RLGL(int client)
{
	#pragma unused client
}

void ApplyFade(const char[] sColor)
{
	int color[4];
	if (strcmp(sColor, "Red", false) == 0)
	{
		color[0] = 255;
		color[1] = 0;
	}
	else
	{
		color[0] = 124;
		color[1] = 252;
	}

	color[2] = 0;
	color[3] = 20;

	int count = 0;
	int allHumans[MAXPLAYERS + 1];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		allHumans[count] = i;
		count++;
	}

	if (count == 0)
		return;

	int flags = (FFADE_OUT);

	Handle message = StartMessage("Fade", allHumans, count, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", 500);
		pb.SetInt("hold_time", 500);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(500);
		bf.WriteShort(500);
		bf.WriteShort(flags);		
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}

public Action Cmd_RLGLToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s RLGL mode is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	CPrintToChatAll("%s Red Light Green Light is now {olive}%s{lightgreen}.", THIS_MODE_INFO.tag, (THIS_MODE_INFO.isOn) ? "Enabled" : "Disabled");

	delete g_hRLGLTimer;
	delete g_hRLGLDetectTimer;

	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		StartRLGLTimer();
	}

	return Plugin_Handled;
}

Action RLGL_Timer(Handle timer)
{
	g_hRLGLTimer = null;
	
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	delete g_hRLGLWarningTimer;
	g_hRLGLWarningTimer = CreateTimer(1.0, RLGL_Warning_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	
	StartRLGLTimer();
	
	return Plugin_Stop;
}

Action RLGL_Warning_Timer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hRLGLWarningTimer = null;
		return Plugin_Stop;
	}

	static int timePassed;
	char sMessage[256];
	FormatEx(sMessage, sizeof(sMessage), "Warning: Red Light is coming in %d seconds, Do not move after that", (THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_WARNING_TIME].cvar.IntValue - timePassed));
	
	int warningTime = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_WARNING_TIME].cvar.IntValue;

	char numStr[3];
	IntToString(warningTime - timePassed, numStr, sizeof(numStr));
	
	char sndPath[PLATFORM_MAX_PATH];
	strcopy(sndPath, sizeof(sndPath), countDownPath);
	ReplaceString(sndPath, sizeof(sndPath), "$", numStr);
	
	char sndPath2[PLATFORM_MAX_PATH];
	FormatEx(sndPath2, sizeof(sndPath2), "sound/%s", sndPath);
	bool playSnd = FileExists(sndPath2);
	sndPath2[0] = '\0';
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		SendHudText(i, sMessage, _, 0);
		if (playSnd) {
			EmitSoundToClient(i, sndPath);
		}
	}

	timePassed++;

	if (timePassed > warningTime)
	{
		ApplyFade("Red");
		g_bEnableDetecting = true;
		float speed = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_ZOMBIES_SPEED].cvar.FloatValue;
		if (speed > 0.0) {
			SetZombiesSpeed(speed);
		}
		
		CreateTimer(THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_FREEZE_TIME].cvar.FloatValue, RLGL_Detect_Time_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
		timePassed = 0;
		g_hRLGLWarningTimer = null;
		
		delete g_hRLGLDetectTimer;
		g_hRLGLDetectTimer 	= CreateTimer(THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_TIME_BETWEEN_DAMAGE].cvar.FloatValue, RLGL_Detect_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action RLGL_Detect_Timer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn || !g_bEnableDetecting)
	{
		g_hRLGLDetectTimer = null;
		return Plugin_Stop;
	}

	float damage = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_DAMAGE].cvar.FloatValue;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		MoveType moveType = GetEntityMoveType(i);
		if (moveType == MOVETYPE_NOCLIP || moveType == MOVETYPE_NONE)
			continue;

		int buttons = GetClientButtons(i);
		if (buttons & (IN_WALK | IN_BACK | IN_FORWARD | IN_RIGHT | IN_LEFT | IN_JUMP))
		{
			SDKHooks_TakeDamage(i, 0, 0, damage);
			SendHudText(i, "STOP MOVING ITS A RED LIGHT!!!", _, 1);
		}

		continue;
	}

	return Plugin_Continue;
}

Action RLGL_Detect_Time_Timer(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	ApplyFade("Green");
	g_bEnableDetecting = false;
	SetZombiesSpeed(1.0);
	
	delete g_hRLGLDetectTimer;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		SendHudText(i, "YOU CAN MOVE NOW, ITS A GREEN LIGHT!", _, 2);
	}

	return Plugin_Continue;
}

stock void SetZombiesSpeed(float val) {
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_T) 
			continue;
		
		g_fOriginalSpeed[i] = (val == 1.0) ? 0.0 : GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue");
		float thisVal = (val == 1.0) ? g_fOriginalSpeed[i] : val;

		if (thisVal == 0.0)
			thisVal = 1.0;

		SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", thisVal); 
		CPrintToChat(i, "%s Your speed has been changed to {olive}%.2f", THIS_MODE_INFO.tag, thisVal); 
		CPrintToChat(i, "%s This is a part of {olive}Red Light Green Light.{white} An admin decided to have this kicker.", THIS_MODE_INFO.tag);
	}
}

stock void StartRLGLTimer()
{
	float time = 10.0;
	float timeMax = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MAX].cvar.FloatValue;
	float timeMin = THIS_MODE_INFO.cvarInfo[RLGL_CONVAR_TIME_BETWEEN_REDLIGHTS_MIN].cvar.FloatValue;
	if (timeMax <= 0.0) 
		time = timeMin;
	else
		time = GetRandomFloat(timeMin, timeMax);
		
	g_hRLGLTimer = CreateTimer(time, RLGL_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

/* RLGL Settings */
public Action Cmd_RLGLSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_RLGLSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Menu_RLGLSettings(Menu menu, MenuAction action, int param1, int param2)
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