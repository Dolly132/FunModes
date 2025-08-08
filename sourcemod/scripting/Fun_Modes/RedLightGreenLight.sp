#pragma semicolon 1
#pragma newdecls required

#define FFADE_IN       (0x0001) // Fade in
#define FFADE_OUT      (0x0002) // Fade out
#define FFADE_MODULATE (0x0004) // Modulate (Don't blend)
#define FFADE_STAYOUT  (0x0008) // Ignores the duration, stays faded out until a new fade message is received
#define FFADE_PURGE    (0x0010) // Purges all other fades, replacing them with this one

char countDownPath[PLATFORM_MAX_PATH];

// %1: client, %2: speed value (float)
#define ChangeSpeed(%1,%2) \ 
	SetEntPropFloat(%1,Prop_Data,"m_flLaggedMovementValue",%2); \
	CPrintToChat(%1,RLGL_Tag..." Your speed has been changed to {olive}%.2f",%2); \
	CPrintToChat(%1,RLGL_Tag..." This is a part of {olive}Red Light Green Light.{white} An admin decided to have this kicker.")

ConVarInfo g_cvInfoRLGL[7] = 
{
    {null, "0.1,0.3,0.5,0.8", "float"},
    {null, "2.0,5.0,10.0,15.0", "float"},
    {null, "20.0,30.0,40.0,60.0", "float"},
    {null, "25.0,35.0,55.0,65.0", "float"},
    {null, "1.0,2.0,3.0,4.0,5.0", "float"},
    {null, "3.0,5.0,8.0,10.0", "float"},
    {null, "0.0,0.2,0.5,1.2,1.5,2.0", "float"}
};

/* CALLED on Plugin Start */
stock void PluginStart_RLGL()
{
	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_rlgl", Cmd_RLGL, ADMFLAG_CONVARS, "Enable/Disable RedLightGreenLight mode.");

	/* CONVARS HANDLES */
	g_cvRLGLDetectTimer = CreateConVar("sm_rlgl_time_between_damage", "0.1", "The timer interval for player to detect their movement");
	g_cvRLGLFinishDetectTime = CreateConVar("sm_rlgl_freeze_time", "5", "How many seconds the movement detection should be disabled after");
	g_cvRLGLDetectTimerRepeatMin = CreateConVar("sm_rlgl_time_between_redlights_min", "20.0", "After how many seconds to keep repeating the redlights (MIN VALUE)");
	g_cvRLGLDetectTimerRepeatMax = CreateConVar("sm_rlgl_time_between_redlights_max", "30.0", "After how many seconds to keep repeating the redlights (MAX VALUE, SET TO 0 to disable min/max)");
	g_cvRLGLDamage = CreateConVar("sm_rlgl_damage", "5.0", "Damage to apply to the player that is moving while its a red light");
	g_cvRLGLWarningTime = CreateConVar("sm_rlgl_warning_time", "8", "Time in seconds to warn the players before red light is on");
	g_cvRLGLZombiesSpeed = CreateConVar("sm_rlgl_zombies_speed", "0.5", "Zombies speed during red light, if set to 0 then it is disabled");
	g_cvCountdownFolder = CreateConVar("sm_rlgl_countdown_folder", "zr/countdown/$.mp3", "Countdown folder and the files that can be used for sound");
	
	RLGL_SetCvarsInfo();
}

void RLGL_SetCvarsInfo()
{
	ConVar cvars[sizeof(g_cvInfoRLGL)];
	cvars[0] = g_cvRLGLDetectTimer;
	cvars[1] = g_cvRLGLFinishDetectTime;
	cvars[2] = g_cvRLGLDetectTimerRepeatMin;
	cvars[3] = g_cvRLGLDetectTimerRepeatMax;
	cvars[4] = g_cvRLGLDamage;
	cvars[5] = g_cvRLGLWarningTime;
	cvars[6] = g_cvRLGLZombiesSpeed;

	for (int i = 0; i < sizeof(g_cvInfoRLGL); i++)
		g_cvInfoRLGL[i].cvar = cvars[i];
}

stock void MapStart_RLGL() {
	g_cvCountdownFolder.GetString(countDownPath, sizeof(countDownPath));
	
	for (int i = 1; i <= g_cvRLGLWarningTime.IntValue; i++)
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

stock void RoundStart_RLGL() {
	delete g_hRLGLWarningTime;
	delete g_hRLGLTimer;
	delete g_hRLGLDetectTimer;
	
	if(g_bIsRLGLEnabled)
		StartRLGLTimer();
}

void ApplyFade(const char[] sColor)
{
	int color[4];
	if(strcmp(sColor, "Red", false) == 0)
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

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;

		allHumans[count] = i;
		count++;
	}

	if(count == 0)
		return;

	int flags = (FFADE_OUT);

	Handle message = StartMessage("Fade", allHumans, count, 1);
	if(GetUserMessageType() == UM_Protobuf)
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

Action Cmd_RLGL(int client, int args)
{
	g_bIsRLGLEnabled = !g_bIsRLGLEnabled;
	CPrintToChatAll("%s Red Light Green Light is now {olive}%s{lightgreen}.", RLGL_Tag, (g_bIsRLGLEnabled) ? "Enabled" : "Disabled");

	delete g_hRLGLTimer;
	delete g_hRLGLDetectTimer;

	if(g_bIsRLGLEnabled)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		StartRLGLTimer();
	}

	return Plugin_Handled;
}

Action RLGL_Timer(Handle timer)
{
	if(!g_bIsRLGLEnabled)
		return Plugin_Stop;

	g_hRLGLWarningTime = CreateTimer(1.0, RLGL_Warning_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	
	StartRLGLTimer();
	
	return Plugin_Stop;
}

Action RLGL_Warning_Timer(Handle timer)
{
	static int timePassed;
	char sMessage[256];
	FormatEx(sMessage, sizeof(sMessage), "Warning: Red Light is coming in %d seconds, Do not move after that", (g_cvRLGLWarningTime.IntValue - timePassed));
	
	char numStr[3];
	IntToString(g_cvRLGLWarningTime.IntValue - timePassed, numStr, sizeof(numStr));
	
	char sndPath[PLATFORM_MAX_PATH];
	strcopy(sndPath, sizeof(sndPath), countDownPath);
	ReplaceString(sndPath, sizeof(sndPath), "$", numStr);
	
	char sndPath2[PLATFORM_MAX_PATH];
	FormatEx(sndPath2, sizeof(sndPath2), "sound/%s", sndPath);
	bool playSnd = FileExists(sndPath2);
	sndPath2[0] = '\0';
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		SendHudText(i, sMessage, _, 0);
		if(playSnd) {
			EmitSoundToClient(i, sndPath);
		}
	}

	timePassed++;

	if(timePassed > g_cvRLGLWarningTime.IntValue)
	{
		ApplyFade("Red");
		g_bEnableDetecting = true;
		float speed = g_cvRLGLZombiesSpeed.FloatValue;
		if(speed > 0.0) {
			SetZombiesSpeed(speed);
		}
		
		CreateTimer(g_cvRLGLFinishDetectTime.FloatValue, RLGL_Detect_Time_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
		timePassed = 0;
		g_hRLGLWarningTime = null;
		
		delete g_hRLGLDetectTimer;
		g_hRLGLDetectTimer 	= CreateTimer(g_cvRLGLDetectTimer.FloatValue, RLGL_Detect_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

Action RLGL_Detect_Timer(Handle timer)
{
	if(!g_bIsRLGLEnabled || !g_bEnableDetecting)
	{
		g_hRLGLDetectTimer = null;
		return Plugin_Stop;
	}

	char sMessage[256];
	FormatEx(sMessage, sizeof(sMessage), "STOP MOVING ITS A RED LIGHT!!!");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		MoveType moveType = GetEntityMoveType(i);
		if(moveType == MOVETYPE_NOCLIP || moveType == MOVETYPE_NONE)
			continue;

		int buttons = GetClientButtons(i);
		if(buttons & (IN_WALK | IN_BACK | IN_FORWARD | IN_RIGHT | IN_LEFT | IN_JUMP))
		{
			SDKHooks_TakeDamage(i, 0, 0, g_cvRLGLDamage.FloatValue);
			SendHudText(i, sMessage, _, 1);
		}

		continue;
	}

	return Plugin_Continue;
}

Action RLGL_Detect_Time_Timer(Handle timer)
{
	ApplyFade("Green");
	g_bEnableDetecting = false;
	SetZombiesSpeed(1.0);
	
	delete g_hRLGLDetectTimer;
	
	char sMessage[256];
	FormatEx(sMessage, sizeof(sMessage), "YOU CAN MOVE NOW, ITS A GREEN LIGHT!");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		SendHudText(i, sMessage, _, 2);
	}

	return Plugin_Continue;
}

stock void SetZombiesSpeed(float val) {
	for (int i = 1; i <= MaxClients; i++) 
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_T) 
			continue;
			
		ChangeSpeed(i,val);
	}
}


stock void StartRLGLTimer()
{
	float time = 10.0;
	float timeMax = g_cvRLGLDetectTimerRepeatMax.FloatValue;
	float timeMin = g_cvRLGLDetectTimerRepeatMin.FloatValue;
	if(timeMax <= 0.0) 
		time = timeMin;
	else
		time = GetRandomFloat(timeMin, timeMax);
		
	g_hRLGLTimer 		= CreateTimer(time, RLGL_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}
