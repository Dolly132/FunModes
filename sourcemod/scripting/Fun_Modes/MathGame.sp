/*
    (). FunModes V2:
        
    @file           MathGame.sp
    @Usage         	Functions for the MathGame Mode.
    				
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_MathGameInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_MathGameInfo

#define MATHGAME_CONVAR_TIMER_INTERVAL_EASY		0
#define MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM	1
#define MATHGAME_CONVAR_TIMER_INTERVAL_HARD		2
#define MATHGAME_CONVAR_EASY_DAMAGE				3
#define MATHGAME_CONVAR_MEDIUM_DAMAGE			4
#define MATHGAME_CONVAR_HARD_DAMAGE				5
#define MATHGAME_CONVAR_INCLUDE_ZOMBIE			6
#define MATHGAME_CONVAR_MAX_TRIES				7
#define MATHGAME_CONVAR_TOGGLE 					8

Handle g_hMathGameTimer;

bool g_bMathGameHasQuestion[MAXPLAYERS + 1];
int g_iMathGameAnswer[MAXPLAYERS + 1];
int g_iMathGameFailedAnswers[MAXPLAYERS + 1];
bool g_bMathGameDisableRespawn[MAXPLAYERS + 1];

stock void OnPluginStart_MathGame()
{
	THIS_MODE_INFO.name = "MathGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-MathGame]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_mathgame", Cmd_MathGameToggle, ADMFLAG_CONVARS, "Turn MathGame Mode On/Off");
	RegAdminCmd("sm_mathgame_settings", Cmd_MathGameSettings, ADMFLAG_CONVARS, "Open MathGame Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_TIMER_INTERVAL_EASY,
		"sm_mathgame_easy_time", "15.0", "The time needed to answer easy math questions",
		("20.0,30.0,50.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM,
		"sm_mathgame_medium_time", "30.0", "The time needed to answer medium math questions",
		("20.0,30.0,50.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_TIMER_INTERVAL_HARD,
		"sm_mathgame_hard_time", "60.0", "The time needed to answer hard math questions",
		("20.0,30.0,50.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_EASY_DAMAGE,
		"sm_mathgame_easy_damage", "50.0", "The amount of damage to apply to those who can't answer easy questions",
		("10.0,20.0,25.0,35.0,50.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_MEDIUM_DAMAGE,
		"sm_mathgame_medium_damage", "35.0", "The amount of damage to apply to those who can't answer medium questions",
		("10.0,20.0,25.0,35.0,50.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_HARD_DAMAGE,
		"sm_mathgame_hard_damage", "20.0", "The amount of damage to apply to those who can't answer hard questions",
		("10.0,20.0,25.0,35.0,50.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_INCLUDE_ZOMBIE,
		"sm_mathgame_include_zombies", "0", "Include zombies to the math game (1 = Enabled, 0 = Disabled)",
		("0,1"), "bool"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_MAX_TRIES,
		"sm_mathgame_max_tries", "3", "How many failed tries for zombies to answer question until they can never respawn again?",
		("1,2,3,4,5"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, MATHGAME_CONVAR_TOGGLE,
		"sm_mathgame_enable", "1", "Enable/Disable MathGame Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enabled = true;
	
	THIS_MODE_INFO.index = g_arModesInfo.Length;
	g_arModesInfo.PushArray(THIS_MODE_INFO);
	
	THIS_MODE_INFO.cvarInfo[MATHGAME_CONVAR_TOGGLE].cvar.AddChangeHook(OnMathGameModeToggle);
}

void OnMathGameModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, enabled, cvar.BoolValue, THIS_MODE_INFO.index);
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnMapStart_MathGame() {}
stock void OnMapEnd_MathGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	
	g_hMathGameTimer = null;
}

stock void OnClientPutInServer_MathGame(int client)
{
	g_bMathGameHasQuestion[client] = false;
	g_iMathGameFailedAnswers[client] = 0;
	g_bMathGameDisableRespawn[client] = false;
}

stock void OnClientDisconnect_MathGame(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_MathGame(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_MathGame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bMathGameHasQuestion[i] = false;
		g_iMathGameAnswer[i] = 0;
		g_iMathGameFailedAnswers[i] = 0;
		g_bMathGameDisableRespawn[i] = false;
	}
}
stock void Event_RoundEnd_MathGame() {}
stock void Event_PlayerSpawn_MathGame(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_MathGame(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_MathGame(int client)
{
	#pragma unused client
}

public Action ZR_OnClientRespawn(int &client, ZR_RespawnCondition &condition)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Continue;
		
	if (condition != ZR_Respawn_Zombie)
		return Plugin_Continue;
	
	if (!g_bMathGameDisableRespawn[client])
		return Plugin_Continue;
		
	return Plugin_Handled;
}

public Action Cmd_MathGameToggle(int client, int args)
{
	if (!THIS_MODE_INFO.enabled)
	{
		CReplyToCommand(client, "%s MathGame Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s MathGame Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		MathGame_Ask();
	}
	else
		delete g_hMathGameTimer;
		
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
	if (!g_bMathGameHasQuestion[client])
		return Plugin_Continue;
		
	if (!IsCharNumeric(args[0]))
		return Plugin_Continue;
	
	int num;
	if (!StringToIntEx(args, num))
		return Plugin_Continue;
	
	if (num == g_iMathGameAnswer[client])
	{
		CPrintToChat(client, "%s Congratuations, you have answered the math question, nothing bad will hurt you now!", THIS_MODE_INFO.tag);
		CPrintToChatAll("%s {olive}%N {lightgreen}turns to be a smart boy and answered their question!", THIS_MODE_INFO.tag, client);
		g_bMathGameHasQuestion[client] = false;
		g_iMathGameAnswer[client] = 0;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void MathGame_Ask()
{
	int level = GetRandomInt(0, 2);
	
	static const char levels[][] =  { "Easy", "Medium", "Hard" };
	
	int time = THIS_MODE_INFO.cvarInfo[level].cvar.IntValue;
	CPrintToChatAll("%s Alright gentlemen, Each player will now receive a math question to answer, You have got only {olive}%d seconds", THIS_MODE_INFO.tag, time);
	CPrintToChatAll("%s Question Level: {olive}%s", THIS_MODE_INFO.tag, levels[level]);
	
	bool includeZombies = THIS_MODE_INFO.cvarInfo[MATHGAME_CONVAR_INCLUDE_ZOMBIE].cvar.BoolValue;
	int maxTries = THIS_MODE_INFO.cvarInfo[MATHGAME_CONVAR_MAX_TRIES].cvar.IntValue;
	
	if (includeZombies)
		CPrintToChatAll("%s Zombies will have {olive}%d maximum tries {lightgreen}to survive or they will be stuck on spec!", THIS_MODE_INFO.tag, maxTries);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;
		
		if (ZR_IsClientHuman(i) || (includeZombies && ZR_IsClientZombie(i)))
			MathGame_SendQuestion(i, level);
	}
	
	g_hMathGameTimer = CreateTimer(float(time), MathGame_Timer, level, TIMER_FLAG_NO_MAPCHANGE);
}

void MathGame_SendQuestion(int client, int level)
{
	char oper[2];
	int numbers[2];
	
	int min, max;
	
	if (level == 0 || level == 1)
	{
		min = 1;
		max = (level == 0) ? 99 : 299;
		oper = (GetRandomInt(0,1) == 0)?"+":"-";
	}
	else
	{
		min = 0; // include 0 so the lucky person can easily answer it haha
		max = 44;
		oper = "*";
	}
	
	numbers[0] = GetRandomInt(min, max);
	numbers[1] = GetRandomInt(min, max);
	
	int answer;
	switch (oper[0])
	{
		case '+': answer = numbers[0] + numbers[1];
		case '-': answer = numbers[0] - numbers[1];
		default: answer = numbers[0] * numbers[1];
	}
	
	g_iMathGameAnswer[client] = answer;
	CPrintToChat(client, "%s What is [ {white}%d {olive}%s {white}%d {lightgreen}]?", THIS_MODE_INFO.tag, numbers[0], oper, numbers[1]);
}

Action MathGame_Timer(Handle timer, int level)
{
	g_hMathGameTimer = null;
	
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;
		
	CPrintToChatAll("%s Time is Up! Players who failed to answer will now be punished!");
	
	float damage = THIS_MODE_INFO.cvarInfo[level + 3].cvar.FloatValue;
	bool includeZombies = THIS_MODE_INFO.cvarInfo[MATHGAME_CONVAR_INCLUDE_ZOMBIE].cvar.BoolValue;
	int maxTries = THIS_MODE_INFO.cvarInfo[MATHGAME_CONVAR_MAX_TRIES].cvar.IntValue;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bMathGameHasQuestion[i])
		{
			if (ZR_IsClientHuman(i))
			{
				CPrintToChatAll("%s {olive}%N {lightgreen}has been damaged for not answering their math question!", i);
				SDKHooks_TakeDamage(i, 0, 0, damage);
			}
			else
			{
				if (!includeZombies)
					continue;
					
				g_iMathGameFailedAnswers[i]++;
				if (g_iMathGameFailedAnswers[i] >= maxTries)
				{
					ForcePlayerSuicide(i);
					CPrintToChat(i, "%s You will not be able to respawn for failing to answer math questions {olive}%d in a row", THIS_MODE_INFO.tag, maxTries);
					g_bMathGameDisableRespawn[i] = true;
					g_iMathGameFailedAnswers[i] = 0;
				}	
			}
		}
	}
	
	CreateTimer(5.0, MathGame_TimerDelay, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

Action MathGame_TimerDelay(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;
		
	MathGame_Ask();
	return Plugin_Continue;
}

/* MathGame Settings */
public Action Cmd_MathGameSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_MathGameSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_MathGameSettings(Menu menu, MenuAction action, int param1, int param2)
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