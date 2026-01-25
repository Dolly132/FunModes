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

#define PULLGAME_CONVAR_TIMER_INTERVAL	0
#define PULLGAME_CONVAR_SPEED			1
#define PULLGAME_CONVAR_PULL_TIME		2
#define PULLGAME_CONVAR_RANDOMS_ZOMBIES	3
#define PULLGAME_CONVAR_RANDOMS_HUMANS	4
#define PULLGAME_CONVAR_TOGGLE			5

float g_fPullLastUseTime[MAXPLAYERS + 1];
bool g_bPullState[MAXPLAYERS + 1];
float g_fPullOriginalSpeed[MAXPLAYERS + 1];
float g_fPullOriginalDistance[MAXPLAYERS + 1];
int g_iPullClientTarget[MAXPLAYERS + 1];
bool g_bPullGameHas[MAXPLAYERS + 1];

float g_fPullGameSpeed;

Handle g_hPullGameTimer;

stock void OnPluginStart_PullGame()
{
	THIS_MODE_INFO.name = "PullGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-PullGame]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_pullgame", Cmd_PullGameToggle, ADMFLAG_CONVARS, "Turn PullGame Mode On/Off");
	RegAdminCmd("sm_pullgame_settings", Cmd_PullGameSettings, ADMFLAG_CONVARS, "Open PullGame Sttings Menu");

	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_TIMER_INTERVAL,
		"sm_pullgame_timer_interval", "30.0", "After how many seconds to keep giving pull access to a random zm?",
		("15.0,30.0,40.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_SPEED,
		"sm_pullgame_speed", "300.0", "Pulling Speed Value",
		("100.0,300.0,500.0,700.0,1000.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_PULL_TIME,
		"sm_pullgame_pull_time", "15.0", "Pulling Time",
		("10.0,15.0,30.0,40.0,55.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_RANDOMS_HUMANS,
		"sm_pullgame_humans_count", "3", "Pulling Time",
		("1,2,3,4,5,6,7"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_RANDOMS_ZOMBIES,
		"sm_pullgame_zombies_count", "3", "Pulling Time",
		("1,2,3,4,5,6,7"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, PULLGAME_CONVAR_TOGGLE,
		"sm_pullgame_enable", "1", "Enable/Disable PullGame Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = PULLGAME_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_TOGGLE].cvar.AddChangeHook(OnPullGameModeToggle);
	
	g_fPullGameSpeed = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_SPEED].cvar.FloatValue;
	THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_SPEED].cvar.AddChangeHook(OnPullGameSpeedChange);
}

void OnPullGameModeToggle(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

void OnPullGameSpeedChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	g_fPullGameSpeed = cvar.FloatValue;
}

stock void OnMapStart_PullGame() {}
stock void OnMapEnd_PullGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_PullGame(int client)
{
	PullGame_ResetVariablesClient(client);
}

stock void OnClientDisconnect_PullGame(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iPullClientTarget[i] == client)
			g_iPullClientTarget[i] = -1;
	}
	
	PullGame_ResetVariablesClient(client);
}

stock void ZR_OnClientInfected_PullGame(int client)
{
	#pragma unused client
	
	if (!THIS_MODE_INFO.isOn)
		return;
		
	if (!g_bMotherZombie)
		PullGame_ToggleTimer(true);
}

stock void Event_RoundStart_PullGame()
{
	PullGame_ResetVariables();
}

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
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s PullGame Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s PullGame Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		
		CPrintToChatAll("%s Press (F) {olive} | Flashlight {lightgreen}to use pull, only when you get selected!", THIS_MODE_INFO.tag);
		
		int humansCount = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_RANDOMS_HUMANS].cvar.IntValue;
		int zombiesCount = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_RANDOMS_ZOMBIES].cvar.IntValue;
		int interval = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_TIMER_INTERVAL].cvar.IntValue;
		
		CPrintToChatAll("%s {olive}%d Random Humans {lightgreen}and {olive}%d Random Zombies {lightgreen}will be selected for the pullgame every %d seconds", THIS_MODE_INFO.tag, humansCount, zombiesCount, interval);
		
		CS_TerminateRound(3.0, CSRoundEnd_Draw);
	}
	else
		PullGame_ToggleTimer(false);
		
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

void PullGame_ResetVariablesClient(int client)
{
	g_bPullGameHas[client] = false;
	g_bPullState[client] = false;
	g_fPullOriginalSpeed[client] = 0.0;
	g_fPullOriginalDistance[client] = 0.0;
	g_iPullClientTarget[client] = -1;
	g_fPullLastUseTime[client] = 0.0;
}

void PullGame_ResetVariables()
{
	for (int i = 1; i <= MaxClients; i++)
		PullGame_ResetVariablesClient(i);
}

void PullGame_ToggleTimer(bool toggle)
{
	PullGame_ResetVariables();
	
	delete g_hPullGameTimer;
	
	if (toggle)
		g_hPullGameTimer = CreateTimer(THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_TIMER_INTERVAL].cvar.FloatValue, Timer_PullGame, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PullGame(Handle timer)
{
	if (g_bRoundEnd || !g_bMotherZombie)
	{
		g_hPullGameTimer = null;
		return Plugin_Stop;
	}
	
	int humansMaxCount = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_RANDOMS_HUMANS].cvar.IntValue;
	int zombiesMaxCount = THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_RANDOMS_ZOMBIES].cvar.IntValue;
	
	int zombies[MAXPLAYERS + 1];
	int humans[MAXPLAYERS + 1];
	
	int zombiesCount, humansCount;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		if (ZR_IsClientZombie(i))
			zombies[zombiesCount++] = i;
		else
			humans[humansCount++] = i;
	}
	
	if (zombiesCount)
		PullGame_PickTeamRandoms(zombies, zombiesCount, 0, zombiesMaxCount);
		
	if (humansCount)
		PullGame_PickTeamRandoms(humans, humansCount, 0, humansMaxCount);
		
	return Plugin_Continue;
}

void PullGame_PickTeamRandoms(int[] arr, int len, int min, int max)
{
	for (int i = 0; i < len; i++)
	{
		if (len == max)
			g_bPullGameHas[arr[i]] = true;
		else
		{
			if (++min > max)
				break;
				
			int random;
			int index = PullGame_GetRandomFromArray(arr, len, random);
			if (index == -1)
				continue;
			
			arr[index] = 0;
			g_bPullGameHas[random] = true;
			
			CPrintToChat(random, "%s You have been selected to use pull! Press FlashLight button (F) Now!", THIS_MODE_INFO.tag);
			SendHudText(random, "[FunModes-PullGame] You have been selected to use pull! Press FlashLight button (F) Now!");
		}
	}
}

int PullGame_GetRandomFromArray(int[] arr, int len, int &client)
{
	int count;
	int[] newArr = new int[len];
	
	for (int i = 0; i < len; i++)
	{
		if (arr[i] == 0)
			continue;
		
		if (g_bPullGameHas[arr[i]])
			continue;
			
		newArr[count++] = arr[i];
	}
	
	if (!count)
		return -1;
	
	int index = GetRandomInt(0, count - 1);
	client = newArr[index];
	return index;
}

stock void OnPlayerRunCmdPost_PullGame(int client, int buttons, int impulse)
{
	#pragma unused buttons
	if (!THIS_MODE_INFO.isOn)
		return;
		
	float time = GetGameTime();
	if (g_fPullLastUseTime[client] > time)
		return;
		
	if (impulse == 100)
	{
		Cmd_Pull(client);
		g_fPullLastUseTime[client] = GetGameTime() + 2.0;
	}
}

void Cmd_Pull(int client)
{
	if (!g_bPullGameHas[client])
	{
		CPrintToChat(client, "%s You cannot use this command unless you were randomly chosen for it!", THIS_MODE_INFO.tag);
		return;
	}
	
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s You have to be alive to use this command.", THIS_MODE_INFO.tag);
		return;
	}
	
	if (g_iPullClientTarget[client] != -1)
	{
		CPrintToChat(client, "%s You cannot use this command more than once while you are activating it.", THIS_MODE_INFO.tag);
		return;
	}
	
	int target = GetClientAimTarget(client);
	if (target == -1)
	{
		CPrintToChat(client, "%s You have to aim at a player!", THIS_MODE_INFO.tag);
		return;
	}
	
	bool isClientHuman = ZR_IsClientHuman(client);
	bool isTargetHuman = ZR_IsClientHuman(target);
	
	if (isClientHuman)
	{
		if (!isTargetHuman)
		{
			CPrintToChat(client, "%s You cannot target a zombie!", THIS_MODE_INFO.tag);
			return;
		}
		
		if (!g_bPullState[target])
		{
			CPrintToChat(client, "%s You cannot pull a human that's not being pulled from the zombies!", THIS_MODE_INFO.tag);
			return;
		}
	}
	
	PullGame_StartGrab(client, target);
}

void PullGame_StartGrab(int client, int target)
{
	g_iPullClientTarget[client] = target;
	
	if (!g_bPullState[target])
	{
		g_bPullState[target] = true;
		g_fPullOriginalSpeed[target] = GetEntPropFloat(target, Prop_Send, "m_flMaxspeed");
		SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", 0.01);
	}
	
	CreateTimer(THIS_MODE_INFO.cvarInfo[PULLGAME_CONVAR_PULL_TIME].cvar.FloatValue, Timer_PullGameFinish, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.05, PullGame_Pull_Timer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PullGameFinish(Handle timer, int client)
{
	int target = g_iPullClientTarget[client];
	if (target == -1)
		return Plugin_Stop;
		
	bool reset = true;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i) || !ZR_IsClientHuman(i))
			continue;
		
		if (g_iPullClientTarget[i] == target)
		{
			reset = false;
			break;
		}
	}
	
	if (reset)
	{
		SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", g_fPullOriginalSpeed[target]);
		g_bPullState[target] = false;
	}
	
	g_iPullClientTarget[client] = -1;
	g_bPullGameHas[client] = false;
	return Plugin_Stop;
}

Action PullGame_Pull_Timer(Handle timer, int client)
{
	int target = g_iPullClientTarget[client];
	if (target == -1 || !IsPlayerAlive(target) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	float clientEyePos[3], targetEyePos[3];
	GetClientEyePosition(client, clientEyePos);
	GetClientEyePosition(target, targetEyePos);
	
	float distance = GetVectorDistance(clientEyePos, targetEyePos, true);
	if (distance > 40000.0)
	{
		float velocity[3];
		SubtractVectors(clientEyePos, targetEyePos, velocity);
		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, g_fPullGameSpeed);
		TeleportEntity(target, _, _, velocity);
	}
	
	TE_SetupBeamPoints(clientEyePos, targetEyePos, g_iLaserBeam, 0, 0, 66, 0.2, 1.0, 10.0, 0, 0.0, {255,255,255,255}, 0);
	TE_SendToAll();
	
	return Plugin_Continue;
}