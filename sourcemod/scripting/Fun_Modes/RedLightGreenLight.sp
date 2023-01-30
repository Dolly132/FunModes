#pragma semicolon 1
#pragma newdecls required

#define FFADE_IN       (0x0001) // Fade in
#define FFADE_OUT      (0x0002) // Fade out
#define FFADE_MODULATE (0x0004) // Modulate (Don't blend)
#define FFADE_STAYOUT  (0x0008) // Ignores the duration, stays faded out until a new fade message is received
#define FFADE_PURGE    (0x0010) // Purges all other fades, replacing them with this one

/* CALLED on Plugin Start */
stock void PluginStart_RLGL() {
	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_rlgl", Cmd_RLGL, ADMFLAG_CONVARS, "Enable/Disable RedLightGreenLight mode.");

	/* CONVARS HANDLES */
	g_cvRLGLDetectTimer = CreateConVar("sm_rlgl_detect_timer", "0.1", "The timer interval for player to detect their movement");
	g_cvRLGLFinishDetectTime = CreateConVar("sm_rlgl_finish_detect_time", "3", "How many seconds the movement detection should be disabled after");
	g_cvRLGLDetectTimerRepeat = CreateConVar("sm_rlgl_detect_timer_repeat", "60.0", "After how many seconds to keep repeating the detect timer");
	g_cvRLGLDamage = CreateConVar("sm_rlgl_damage", "5.0", "Damage to apply to the player that is moving while its a red light");
	g_cvRLGLWarningTime = CreateConVar("sm_rlgl_warning_time", "5", "Time in seconds to warn the players before red light is on");
}

void ApplyFade(const char[] sColor) {
	int color[4];
	if(StrEqual(sColor, "Red", false)) {
		color[0] = 255;
		color[1] = 0;
	} else {
		color[0] = 124;
		color[1] = 252;
	}
	
	color[2] = 0;
	color[3] = 50;
	
	int count = 0;
	int allHumans[MAXPLAYERS + 1];
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		allHumans[count] = i;
		count++;
	}
	
	if(count == 0) {
		return;
	}
	
	int flags = (FFADE_OUT);
	
	Handle message = StartMessage("Fade", allHumans, count, 1);
	if(GetUserMessageType() == UM_Protobuf) {
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", 500);
		pb.SetInt("hold_time", 500);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	} else {
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

Action Cmd_RLGL(int client, int args) {
	g_bIsRLGLEnabled = !g_bIsRLGLEnabled;
	CPrintToChatAll("%s Red Light Green Light is now {olive}%s{lightgreen}.", RLGL_Tag, (g_bIsRLGLEnabled) ? "Enabled" : "Disabled");
	
	delete g_hRLGLTimer;
	delete g_hRLGLDetectTimer;
	
	if(g_bIsRLGLEnabled) {
		g_hRLGLTimer 		= CreateTimer(g_cvRLGLDetectTimerRepeat.FloatValue - g_cvRLGLWarningTime.FloatValue, RLGL_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		g_hRLGLDetectTimer 	= CreateTimer(g_cvRLGLDetectTimer.FloatValue, RLGL_Detect_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}

	return Plugin_Handled;
}

Action RLGL_Timer(Handle timer) {
	if(!g_bIsRLGLEnabled) {
		g_hRLGLTimer = null;
		return Plugin_Stop;
	}
	
	CreateTimer(1.0, RLGL_Warning_Timer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	return Plugin_Continue;
}

Action RLGL_Warning_Timer(Handle timer) {
	static int timePassed;
	
	SetHudTextParams(-1.0, 0.1, 2.0, 255, 36, 255, 13);
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		}
		
		ShowSyncHudText(i, g_hHudMsg, "Warning: Red Light is coming in %d seconds, Do not move after that", (g_cvRLGLWarningTime.IntValue - timePassed));
	}
	
	timePassed++;
	
	if(timePassed >= g_cvRLGLWarningTime.IntValue) {
		ApplyFade("Red");
		g_bEnableDetecting = true;
		CreateTimer(g_cvRLGLFinishDetectTime.FloatValue, RLGL_Detect_Time_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
		timePassed = 0;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

Action RLGL_Detect_Timer(Handle timer) {
	if(!g_bIsRLGLEnabled) {
		g_hRLGLDetectTimer = null;
		return Plugin_Stop;
	}
	
	if(!g_bEnableDetecting) {
		return Plugin_Handled;
	}
	
	SetHudTextParams(-1.0, 0.1, 2.0, 255, 0, 0, 50);
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		} 
		
		MoveType moveType = GetEntityMoveType(i);
		if(moveType == MOVETYPE_NOCLIP || moveType == MOVETYPE_NONE) {
			continue;
		}
		
		int buttons = GetClientButtons(i);
		if(buttons & (IN_WALK | IN_BACK | IN_FORWARD | IN_RIGHT | IN_LEFT | IN_DUCK | IN_JUMP)) {
			SDKHooks_TakeDamage(i, 0, 0, g_cvRLGLDamage.FloatValue);
			ShowSyncHudText(i, g_hHudMsg, "STOP MOVING ITS A RED LIGHT!!!");
		}
		
		continue;
	}
	
	return Plugin_Continue;
}

Action RLGL_Detect_Time_Timer(Handle timer) {
	ApplyFade("Green");
	g_bEnableDetecting = false;
	
	SetHudTextParams(-1.0, 0.1, 2.0, 124, 252, 0, 50);
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT) {
			continue;
		} 
		
		ShowSyncHudText(i, g_hHudMsg, "YOU CAN MOVE NOW, ITS A GREEN LIGHT!");
	}
	
	return Plugin_Continue;
}

stock void RLGL_GetConVars(ConVar cvars[5]) {
	cvars[0] = g_cvRLGLDetectTimer;
	cvars[1] = g_cvRLGLFinishDetectTime;
	cvars[2] = g_cvRLGLDetectTimerRepeat;
	cvars[3] = g_cvRLGLDamage;
	cvars[4] = g_cvRLGLWarningTime;
}
