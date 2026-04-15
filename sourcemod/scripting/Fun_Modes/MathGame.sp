/*
    (). FunModes V2:

    @file           MathGame.sp
    @Usage          Functions for the MathGame Mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_MathGameInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_MathGameInfo

#define MATHGAME_CONVAR_TIMER_INTERVAL_EASY     0
#define MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM   1
#define MATHGAME_CONVAR_TIMER_INTERVAL_HARD     2
#define MATHGAME_CONVAR_EASY_DAMAGE             3
#define MATHGAME_CONVAR_MEDIUM_DAMAGE           4
#define MATHGAME_CONVAR_HARD_DAMAGE             5
#define MATHGAME_CONVAR_INCLUDE_ZOMBIE          6
#define MATHGAME_CONVAR_MAX_TRIES               7
#define MATHGAME_CONVAR_TIME_DELAY              8
#define MATHGAME_CONVAR_TOGGLE                  9

Handle g_hMathGameTimer;
Handle g_hMathGameTimerRepeat;
Handle g_hMathGameTimerDelay;

bool g_bMathGameHasQuestion[MAXPLAYERS + 1];
int g_iMathGameAnswer[MAXPLAYERS + 1];
int g_iMathGameFailedAnswers[MAXPLAYERS + 1];
bool g_bMathGameDisableRespawn[MAXPLAYERS + 1];
char g_sMathGameQuestion[MAXPLAYERS + 1][32];
int g_iMathGameTime;

float g_fMathGame_TimerIntervals[3];
float g_fMathGame_Damages[3];
bool g_bMathGame_IncludeZombies;
int g_iMathGame_MaxTries;
float g_fMathGame_TimeDelay;
bool g_bMathGame_Enabled;

stock void OnPluginStart_MathGame()
{
	THIS_MODE_INFO.name = "MathGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-MathGame]{lightgreen}";

	RegAdminCmd("sm_fm_mathgame", Cmd_MathGameToggle, ADMFLAG_CONVARS, "Turn MathGame Mode On/Off");
	RegAdminCmd("sm_mathgame_settings", Cmd_MathGameSettings, ADMFLAG_CONVARS, "Open MathGame Sttings Menu");

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_TIMER_INTERVAL_EASY, "sm_mathgame_easy_time",
		"15.0", "The time needed to answer easy math questions",
		("20.0,30.0,50.0,60.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_TIMER_INTERVAL_EASY].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM, "sm_mathgame_medium_time",
		"30.0", "The time needed to answer medium math questions",
		("20.0,30.0,50.0,60.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_TIMER_INTERVAL_HARD, "sm_mathgame_hard_time",
		"60.0", "The time needed to answer hard math questions",
		("20.0,30.0,50.0,60.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_TIMER_INTERVAL_HARD].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_EASY_DAMAGE, "sm_mathgame_easy_damage",
		"50.0", "The amount of damage to apply to those who can't answer easy questions",
		("10.0,20.0,25.0,35.0,50.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_EASY_DAMAGE].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_MEDIUM_DAMAGE, "sm_mathgame_medium_damage",
		"35.0", "The amount of damage to apply to those who can't answer medium questions",
		("10.0,20.0,25.0,35.0,50.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_MEDIUM_DAMAGE].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_HARD_DAMAGE, "sm_mathgame_hard_damage",
		"20.0", "The amount of damage to apply to those who can't answer hard questions",
		("10.0,20.0,25.0,35.0,50.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_HARD_DAMAGE].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_INCLUDE_ZOMBIE, "sm_mathgame_include_zombies",
		"0", "Include zombies to the math game (1 = Enabled, 0 = Disabled)",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_INCLUDE_ZOMBIE].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_MAX_TRIES, "sm_mathgame_max_tries",
		"3", "How many failed tries for zombies to answer question until they can never respawn again?",
		("1,2,3,4,5"), CONVAR_INT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_MAX_TRIES].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_TIME_DELAY, "sm_mathgame_time_delay",
		"15.0", "The delayed time after each math question",
		("15.0,20.0,30.0,35.0"), CONVAR_FLOAT
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_TIME_DELAY].HookChange(MathGame_OnConVarChange);

	DECLARE_FM_CVAR(
		MATHGAME_CONVAR_TOGGLE, "sm_mathgame_enable",
		"1", "Enable/Disable MathGame Mode (This differs from turning it on/off)",
		("0,1"), CONVAR_BOOL
	);
	THIS_MODE_INFO.cvars[MATHGAME_CONVAR_TOGGLE].HookChange(MathGame_OnConVarChange);

	THIS_MODE_INFO.enableIndex = MATHGAME_CONVAR_TOGGLE;

	FUNMODES_REGISTER_MODE();
}

void InitCvarsValues_MathGame()
{
	int modeIndex = THIS_MODE_INFO.index;

	g_fMathGame_TimerIntervals[0] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_TIMER_INTERVAL_EASY, Float);
	g_fMathGame_TimerIntervals[1] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM, Float);
	g_fMathGame_TimerIntervals[2] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_TIMER_INTERVAL_HARD, Float);

	g_fMathGame_Damages[0] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_EASY_DAMAGE, Float);
	g_fMathGame_Damages[1] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_MEDIUM_DAMAGE, Float);
	g_fMathGame_Damages[2] = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_HARD_DAMAGE, Float);

	g_bMathGame_IncludeZombies = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_INCLUDE_ZOMBIE, Bool);
	g_iMathGame_MaxTries = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_MAX_TRIES, Int);
	g_fMathGame_TimeDelay = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_TIME_DELAY, Float);
	g_bMathGame_Enabled = _FUNMODES_CVAR_GET_VALUE(modeIndex, MATHGAME_CONVAR_TOGGLE, Bool);
}

void MathGame_OnConVarChange(int modeIndex, int cvarIndex, const char[] oldValue, const char[] newValue)
{
	switch (cvarIndex)
	{
		case MATHGAME_CONVAR_TIMER_INTERVAL_EASY:
			g_fMathGame_TimerIntervals[0] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_TIMER_INTERVAL_MEDIUM:
			g_fMathGame_TimerIntervals[1] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_TIMER_INTERVAL_HARD:
			g_fMathGame_TimerIntervals[2] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_EASY_DAMAGE:
			g_fMathGame_Damages[0] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_MEDIUM_DAMAGE:
			g_fMathGame_Damages[1] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_HARD_DAMAGE:
			g_fMathGame_Damages[2] = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_INCLUDE_ZOMBIE:
			g_bMathGame_IncludeZombies = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);

		case MATHGAME_CONVAR_MAX_TRIES:
			g_iMathGame_MaxTries = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Int);

		case MATHGAME_CONVAR_TIME_DELAY:
			g_fMathGame_TimeDelay = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Float);

		case MATHGAME_CONVAR_TOGGLE:
		{
			bool val = _FUNMODES_CVAR_GET_VALUE(modeIndex, cvarIndex, Bool);
			if (THIS_MODE_INFO.isOn)
				CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, val, THIS_MODE_INFO.index);

			g_bMathGame_Enabled = val;
		}
	}
}

stock void OnMapStart_MathGame() {}

stock void OnMapEnd_MathGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);

	g_hMathGameTimer = null;
	g_hMathGameTimerRepeat = null;
	g_hMathGameTimerDelay = null;
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
	if (!THIS_MODE_INFO.isOn)
		return;

	delete g_hMathGameTimer;
	delete g_hMathGameTimerRepeat;
	delete g_hMathGameTimerDelay;

	MathGame_ResetPlayers();
	CreateTimer(30.0, Timer_StartMathGame, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_StartMathGame(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	MathGame_Ask();
	return Plugin_Stop;
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
	if (!g_bMathGame_Enabled)
	{
		CReplyToCommand(client, "%s MathGame Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll("%s MathGame Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");

	if (THIS_MODE_INFO.isOn)
	{
		MathGame_ResetPlayers();
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		MathGame_Ask();
	}
	else
	{
		MathGame_ResetPlayers();
		delete g_hMathGameTimer;
		delete g_hMathGameTimerRepeat;
		delete g_hMathGameTimerDelay;
	}

	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
	#pragma unused command
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Continue;

	if (!g_bMathGameHasQuestion[client])
		return Plugin_Continue;

	if (!IsCharNumeric(args[0]) && args[0] != '-' && args[0] != '+')
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

	static const char levels[][] = { "Easy", "Medium", "Hard" };

	int time = RoundToNearest(g_fMathGame_TimerIntervals[level]);
	CPrintToChatAll("%s Alright gentlemen, Each player will now receive a math question to answer, You have got only {olive}%d seconds", THIS_MODE_INFO.tag, time);
	CPrintToChatAll("%s Question Level: {olive}%s", THIS_MODE_INFO.tag, levels[level]);

	if (g_bMathGame_IncludeZombies)
		CPrintToChatAll("%s Zombies will have {olive}%d maximum tries {lightgreen}to survive or they will be stuck on spec!", THIS_MODE_INFO.tag, g_iMathGame_MaxTries);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		if (ZR_IsClientHuman(i) || (g_bMathGame_IncludeZombies && ZR_IsClientZombie(i)))
			MathGame_SendQuestion(i, level);
	}

	delete g_hMathGameTimer;
	g_hMathGameTimer = CreateTimer(float(time), MathGame_Timer, level, TIMER_FLAG_NO_MAPCHANGE);

	g_iMathGameTime = 0;

	delete g_hMathGameTimerRepeat;
	g_hMathGameTimerRepeat = CreateTimer(1.0, MathGame_TimerRepeat, time, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

void MathGame_SendQuestion(int client, int level)
{
	g_bMathGameHasQuestion[client] = true;

	char oper[2];
	int numbers[2];

	int min, max;

	if (level == 0 || level == 1)
	{
		min = 1;
		max = (level == 0) ? 99 : 299;
		oper = (GetRandomInt(0, 1) == 0) ? "+" : "-";

		numbers[0] = GetRandomInt(min, max);
		numbers[1] = GetRandomInt(min, max);
	}
	else
	{
		numbers[0] = GetRandomInt(11, 44);
		numbers[1] = GetRandomInt(0, 9);
		oper = "*";
	}

	int answer;
	switch (oper[0])
	{
		case '+': answer = numbers[0] + numbers[1];
		case '-': answer = numbers[0] - numbers[1];
		default: answer = numbers[0] * numbers[1];
	}

	g_iMathGameAnswer[client] = answer;
	FormatEx(g_sMathGameQuestion[client], sizeof(g_sMathGameQuestion[]), "%d %s %d", numbers[0], oper, numbers[1]);

	CPrintToChat(client, "%s What is [ {white}%d {olive}%s {white}%d {lightgreen}]?", THIS_MODE_INFO.tag, numbers[0], oper, numbers[1]);
}

Action MathGame_Timer(Handle timer, int level)
{
	g_hMathGameTimer = null;

	if (!THIS_MODE_INFO.isOn)
	{
		delete g_hMathGameTimerRepeat;
		return Plugin_Stop;
	}

	delete g_hMathGameTimerRepeat;

	CPrintToChatAll("%s Time is Up! Players who failed to answer will now be punished!", THIS_MODE_INFO.tag);

	float damage = g_fMathGame_Damages[level];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bMathGameHasQuestion[i])
		{
			if (ZR_IsClientHuman(i))
			{
				CPrintToChatAll("%s {olive}%N {lightgreen}has been damaged for not answering their math question!", THIS_MODE_INFO.tag, i);
				SDKHooks_TakeDamage(i, 0, 0, damage);
			}
			else
			{
				if (!g_bMathGame_IncludeZombies)
					continue;

				g_iMathGameFailedAnswers[i]++;
				if (g_iMathGameFailedAnswers[i] >= g_iMathGame_MaxTries)
				{
					ForcePlayerSuicide(i);
					CPrintToChat(i, "%s You will not be able to respawn for failing to answer math questions {olive}%d in a row", THIS_MODE_INFO.tag, g_iMathGame_MaxTries);
					g_bMathGameDisableRespawn[i] = true;
					g_iMathGameFailedAnswers[i] = 0;
				}
			}
		}
	}

	MathGame_ResetPlayers();

	delete g_hMathGameTimerDelay;
	g_hMathGameTimerDelay = CreateTimer(g_fMathGame_TimeDelay, MathGame_TimerDelay, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

Action MathGame_TimerDelay(Handle timer)
{
	g_hMathGameTimerDelay = null;

	if (!THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	MathGame_Ask();
	return Plugin_Continue;
}

Action MathGame_TimerRepeat(Handle timer, int time)
{
	char message[128];
	FormatEx(message, sizeof(message), "[MathGame] Time Left: %ds\n", time - g_iMathGameTime - 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		char thisMsg[256];
		strcopy(thisMsg, sizeof(thisMsg), message);

		if (g_bMathGameHasQuestion[i])
			FormatEx(thisMsg, sizeof(thisMsg), "%s\n[ %s ]", thisMsg, g_sMathGameQuestion[i]);

		SendHudText(i, thisMsg);
	}

	g_iMathGameTime++;
	return Plugin_Continue;
}

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

void MathGame_ResetPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bMathGameHasQuestion[i] = false;
		g_iMathGameAnswer[i] = 0;
		g_iMathGameFailedAnswers[i] = 0;
		g_bMathGameDisableRespawn[i] = false;
	}
}
