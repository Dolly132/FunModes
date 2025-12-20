#pragma semicolon 1
#pragma newdecls required

ModeInfo g_DamageGameInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_DamageGameInfo

int g_iDealtDamage[MAXPLAYERS + 1] = {-1, ...};
Handle g_hDamageGameTimer;

#define DAMAGEGAME_CONVAR_TIME_INTERVAL	0
#define DAMAGEGAME_CONVAR_DAMAGE		1
#define DAMAGEGAME_CONVAR_TOGGLE		2

/* CALLED on Plugin Start */
stock void OnPluginStart_DamageGame()
{
	THIS_MODE_INFO.name = "DamageGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-DamageGame]{lightgreen}";

	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_damage", Cmd_DamageGameToggle, ADMFLAG_CONVARS, "Enable/Disable Damage Game mode.");
	RegAdminCmd("sm_fm_damagegame", Cmd_DamageGameToggle, ADMFLAG_CONVARS, "Enable/Disable Damage Game mode.");
	RegAdminCmd("sm_fm_dg", Cmd_DamageGameToggle, ADMFLAG_CONVARS, "Enable/Disable Damage Game mode.");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DAMAGEGAME_CONVAR_TIME_INTERVAL,
		"sm_damagegame_time_interval", "15.0", "Damage Game Timer Interval",
		("15.0,20.0,30.0,40.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DAMAGEGAME_CONVAR_DAMAGE,
		"sm_damagegame_damage", "15.0", "The amount of damage to apply to players who don't shoot zombies",
		("5.0,10.0,15.0,20.0"), "float"
	);

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, DAMAGEGAME_CONVAR_TOGGLE,
		"sm_damagegame_enable", "1", "Enable/Disable Damage Game",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.index = g_arModesInfo.Length;
	g_arModesInfo.PushArray(THIS_MODE_INFO);

	THIS_MODE_INFO.cvarInfo[DAMAGEGAME_CONVAR_TOGGLE].cvar.AddChangeHook(OnDamageGameModeToggle);
}

void OnDamageGameModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, enabled, cvar.BoolValue, THIS_MODE_INFO.index);
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnMapStart_DamageGame() {}
stock void OnMapEnd_DamageGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);

	g_hDamageGameTimer = null;
}

stock void OnClientPutInServer_DamageGame(int client)
{
	if (g_bSDKHook_OnTakeDamagePost[client])
		return;
	
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	g_bSDKHook_OnTakeDamagePost[client] = true;
}

stock void OnClientDisconnect_DamageGame(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	g_iDealtDamage[client] = -1;
}

stock void ZR_OnClientInfected_DamageGame(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_DamageGame()
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	for (int i = 1; i <= MaxClients; i++)
		g_iDealtDamage[i] = -1;
		
	DamageGame_StartTimers();
}

stock void Event_RoundEnd_DamageGame() {}
stock void Event_PlayerSpawn_DamageGame(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_DamageGame(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_DamageGame(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	g_iDealtDamage[client] = -1;
}

stock void OnTakeDamagePost_DamageGame(int victim, int attacker, float damage)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	if (!(IsPlayerAlive(victim) && ZR_IsClientZombie(victim)))
		return;
	
	if (!(0 < attacker <= MaxClients && IsPlayerAlive(attacker) && ZR_IsClientHuman(attacker)))
		return;
	
	g_iDealtDamage[attacker] += RoundToNearest(damage);
}

stock void OnWeaponEquip_DamageGame(int client, int weapon, Action &result)
{
	#pragma unused client
	#pragma unused weapon
	#pragma unused result
}

public Action Cmd_DamageGameToggle(int client, int args)
{
	if (THIS_MODE_INFO.enabled)
	{
		CReplyToCommand(client, "%s Damage Game mode is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);

	CPrintToChatAll("%s Damage Game is now {olive}%s.", THIS_MODE_INFO.tag, (THIS_MODE_INFO.isOn) ? "Enabled" : "Disabled");

	if (THIS_MODE_INFO.isOn)
	{
		/* Events Hooks */
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;
			
			OnClientPutInServer_DamageGame(i);
		}
		
		DamageGame_StartTimers();
		
		CPrintToChatAll("%s Humans with lowest damage dealt to zombies will get damaged every %.2f seconds!", THIS_MODE_INFO.tag, THIS_MODE_INFO.cvarInfo[DAMAGEGAME_CONVAR_TIME_INTERVAL].cvar.FloatValue);
	}
	else
	{
		delete g_hDamageGameTimer;
	}
			
	return Plugin_Handled;
}

void DamageGame_StartTimers()
{
	delete g_hDamageGameTimer;
	g_hDamageGameTimer = CreateTimer(THIS_MODE_INFO.cvarInfo[DAMAGEGAME_CONVAR_TIME_INTERVAL].cvar.FloatValue, Timer_DamageGame, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_DamageGame(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hDamageGameTimer = null;
		return Plugin_Stop;
	}

	if (!g_bMotherZombie || g_bRoundEnd)
		return Plugin_Handled;
		
	int lowestDamage = 999999, count, clients[MAXPLAYERS + 1];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		int thisDamage = 0;
		if (g_iDealtDamage[i] < 0)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || ZR_IsClientZombie(i))
				continue;
				
			g_iDealtDamage[i] = 0;
		}
		else
		{
			thisDamage = g_iDealtDamage[i];
		}
		
		if (thisDamage >= 0 && thisDamage < lowestDamage)
		{
			lowestDamage = thisDamage;
		}
	}
	
	if (lowestDamage == 999999)
		return Plugin_Continue;
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (lowestDamage == g_iDealtDamage[i])
		{
			clients[count] = i;
			count++;
		}
	}

	// We got the players who dealt the lowest damage, Lets damage THEM!
	for (int i = 0; i < count; i++)
	{
		int client = clients[i];
		int health = GetClientHealth(client);
		int newHealth = health - THIS_MODE_INFO.cvarInfo[DAMAGEGAME_CONVAR_DAMAGE].cvar.IntValue;
		if (newHealth <= 0)
			ForcePlayerSuicide(client);
		else 
			SetEntityHealth(client, newHealth);
			
		CPrintToChat(client, "%s You have been damaged for being a bad defender", THIS_MODE_INFO.tag);
		CPrintToChatAll("%s %N {olive}got damaged for being a bad defender!", THIS_MODE_INFO.tag, client);
	}

	return Plugin_Continue;
}

/* DamageGame Settings */
public void Cmd_DamageGameSettings(int client)
{
	Menu menu = new Menu(Menu_DamageGameSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_DamageGameSettings(Menu menu, MenuAction action, int param1, int param2)
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