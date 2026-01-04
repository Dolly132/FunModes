/*
    (). FunModes V2:
        
    @file           PullGame.sp
    @Usage         	Functions for the PullGame Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_PullGameInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_PullGameInfo

#define PULLGAME_CONVAR_TOGGLE 0

int g_iPullGameUses[2]; // 0 = zombies, 1 = humans
float g_fPullLastUseTime[MAXPLAYERS + 1];
bool g_bPullState[MAXPLAYERS + 1];
float g_fPullOriginalSpeed[MAXPLAYERS + 1];
float g_fPullOriginalDistance[MAXPLAYERS + 1];
int g_iPullClientTarget[MAXPLAYERS + 1];

stock void OnPluginStart_PullGame()
{
	THIS_MODE_INFO.name = "PullGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-PullGame]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_pullgame", Cmd_PullGameToggle, ADMFLAG_CONVARS, "Turn PullGame Mode On/Off");
	RegAdminCmd("sm_pullgame_settings", Cmd_PullGameSettings, ADMFLAG_CONVARS, "Open PullGame Sttings Menu");
	RegConsoleCmd("sm_pull", Cmd_Pull, "Pulls an enemy!");
	RegConsoleCmd("sm_grab", Cmd_Grab, "Pulls an enemy!");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_TOGGLE,
		"sm_pullgame_enable", "1", "Enable/Disable PullGame Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enabled = true;
	
	THIS_MODE_INFO.index = g_arModesInfo.Length;
	g_arModesInfo.PushArray(THIS_MODE_INFO);
	
	THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_TOGGLE].cvar.AddChangeHook(OnPullGameModeToggle);
}

void OnPullGameModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, enabled, cvar.BoolValue, THIS_MODE_INFO.index);
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnMapStart_PullGame()
{
	if (g_iLaserBeam == -1)
		return;
	
}
stock void OnMapEnd_PullGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_PullGame(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_PullGame(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_PullGame(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_PullGame() {}
stock void Event_RoundEnd_PullGame() {}
stock void Event_PlayerSpawn_PullGame(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_PullGame(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_PullGame(int client)
{
	#pragma unused client
}

public Action Cmd_PullGameToggle(int client, int args)
{
	if (!THIS_MODE_INFO.enabled)
	{
		CReplyToCommand(client, "%s PullGame Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s PullGame Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	return Plugin_Handled;
}

/* PullGame Settings */
public Action Cmd_PullGameSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_PullGameSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_PullGameSettings(Menu menu, MenuAction action, int param1, int param2)
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

Action Cmd_Pull(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s PullGame is currently OFF!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (!client)
		return Plugin_Handled;
	
	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "%s You have to be alive to use this command.", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	int target = GetClientAimTarget(client);
	if (target == -1)
	{
		CReplyToCommand(client, "%s You have to aim at a player!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	bool isClientHuman = ZR_IsClientHuman(client);
	bool isTargetHuman = ZR_IsClientHuman(target);
	
	if (isClientHuman)
	{
		if (!isTargetHuman)
		{
			CReplyToCommand(client, "%s You cannot target a zombie!", THIS_MODE_INFO.tag);
			return Plugin_Handled;
		}
		
		if (!g_bPullState[target])
		{
			CReplyToCommand(client, "%s You cannot pull a human that's not being pulled from the zombies!", THIS_MODE_INFO.tag);
			return Plugin_Handled;
		}
	}
	
	PullGame_StartGrab(client, target);
}

void PullGame_StartGrab(int client, int target)
{
	g_iPullClientTarget[client] = target;
	
	// we dont care about optimization here as this is called once only
	g_fPullOriginalDistance[client] = GetDistanceBetween(client, target, false);
	
	if (!g_bPullState[target])
		g_fPullOriginalSpeed[target] = GetEntPropFloat(target, Prop_Send, "m_flMaxspeed");
		
	SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", 0.01);
	
	CreateTimer(0.05, PullGame_Pull_Timer, client, TIMER_REPEAT);
}

Action PullGame_Pull_Timer(Handle timer, int client)
{
	int target = g_iPullClientTarget[client];
	if (target == -1)
		return Plugin_Stop;
	
	float speed = 5.0;
	float clientEyePos[3], clientEyeAngles[3], velocity[3], targetLoc[3];
	
	float distance = g_fPullOriginalDistance[client];
	
	GetClientEyePosition(client, clientEyePos);
	GetClientEyeAngles(client, clientEyeAngles);
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetLoc);
	
	TR_TraceRayFilter(clientEyePos, clientEyeAngles, MASK_ALL, RayType_Infinite, TraceRayTryToHit); // Find where the player is aiming
	TR_GetEndPosition(velocity); // Get the end position of the trace ray
	
	distance += speed * 10.0;
	
	SubtractVectors(velocity, clientEyePos, velocity);
	NormalizeVector(velocity, velocity);
	
	ScaleVector(velocity, distance);
	AddVectors(velocity, clientEyePos, velocity);
	SubtractVectors(velocity, targetLoc, velocity);
	ScaleVector(velocity, speed * 3 / 5);
	
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, velocity);
	
	targetLoc[2] += 45;
	
	TE_SetupBeamPoints(clientEyePos, targetLoc, g_iLaserBeam, 0, 0, 66, 0.2, 1.0, 10.0, 0, 0.0, {255,255,255,255}, 0);
	TE_SendToAll();
	
	return Plugin_Continue;
}

bool TraceRayTryToHit(int entity, int mask)
{
	if (entity > 0 && entity <= MaxClients)
		return false;
		
	return true;
}