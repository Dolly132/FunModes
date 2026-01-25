/*
    (). FunModes V2:
        
    @file           BlindMode.sp
    @Usage         	Functions for the Blind mode.
*/

/*
	Could add a mode that gives a bunch of random zombies 1 flashbang to blind cts. 
	Like for example if there is 20 zombies, 5 of them gets a flashbang, 
	and after an amount of time, another 5 random zombies gets flashbangs again
	
	By @LowParty
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_BlindModeInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_BlindModeInfo

#define BLINDMODE_CONVAR_TIMER_INTERVAL	0
#define BLINDMODE_CONVAR_PERCENTAGE		1
#define BLINDMODE_CONVAR_MAX_DISTANCE	2
#define BLINDMODE_CONVAR_BLIND_TIME		3
#define BLINDMODE_CONVAR_TOGGLE 		4

Handle g_hBlindModeTimer;
bool g_bHasFlash[MAXPLAYERS + 1];

stock void OnPluginStart_BlindMode()
{
	THIS_MODE_INFO.name = "BlindMode";
	THIS_MODE_INFO.tag = "{gold}[FunModes-BlindMode]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_blindmode", Cmd_BlindModeToggle, ADMFLAG_CONVARS, "Turn BlindMode Mode On/Off");
	RegAdminCmd("sm_blindmode_settings", Cmd_BlindModeSettings, ADMFLAG_CONVARS, "Open BlindMode Sttings Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, BLINDMODE_CONVAR_TIMER_INTERVAL,
		"sm_blindmode_time_interval", "20.0", "Every how many seconds to keep giving the zombies flashbang?",
		("15.0,20.0,30.0,40.0,60.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, BLINDMODE_CONVAR_PERCENTAGE,
		"sm_blindmode_percentage", "33.0", "Percentage value of zombies to give flashbang to",
		("10.0,20.0,50.0,70.0,100.0"), "float"
	);
	
	THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_PERCENTAGE].cvar.SetBounds(ConVarBound_Lower, false, 0.0);
	THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_PERCENTAGE].cvar.SetBounds(ConVarBound_Upper, false, 100.0);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, BLINDMODE_CONVAR_MAX_DISTANCE,
		"sm_blindmode_max_distance", "300.0", "Max distance between humans and flashbang to apply blind in units",
		("200.0,300.0,500.0,700.0,1000.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, BLINDMODE_CONVAR_BLIND_TIME,
		"sm_blindmode_blind_time", "5", "How many seconds should the humans be blind for?",
		("2,3,5,7,10"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, BLINDMODE_CONVAR_TOGGLE,
		"sm_blindmode_enable", "1", "Enable/Disable BlindMode Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = BLINDMODE_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_TOGGLE].cvar.AddChangeHook(OnBlindModeModeToggle);
}

void OnBlindModeModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_BlindMode() {}
stock void OnMapEnd_BlindMode()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	
	g_hBlindModeTimer = null;
}

stock void OnClientPutInServer_BlindMode(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_BlindMode(int client)
{
	g_bHasFlash[client] = false;
}

stock void ZR_OnClientInfected_BlindMode(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_BlindMode()
{
	for (int i = 1; i <= MaxClients; i++)
		g_bHasFlash[i] = false;
}

stock void Event_RoundEnd_BlindMode() {}
stock void Event_PlayerSpawn_BlindMode(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_BlindMode(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_BlindMode(int client)
{
	g_bHasFlash[client] = false;
}

public Action Cmd_BlindModeToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s BlindMode Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s BlindMode Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		
		float interval = THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_TIMER_INTERVAL].cvar.FloatValue;
		
		CPrintToChatAll("%s Zombies will get a {olive}flashbang {lightgreen}that can blind humans.", THIS_MODE_INFO.tag);
		CPrintToChatAll("%s %d%% of the zombies team will get the {olive}flashbang {lightgreen}every %.2f seconds", THIS_MODE_INFO.tag,
																	THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_PERCENTAGE].cvar.IntValue,
																	interval
		);
		
		g_hBlindModeTimer = CreateTimer(interval, Timer_BlindMode, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	else
	{
		delete g_hBlindModeTimer;
	}
	
	return Plugin_Handled;
}

/* BlindMode Settings */
public Action Cmd_BlindModeSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_BlindModeSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_BlindModeSettings(Menu menu, MenuAction action, int param1, int param2)
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

void ApplyBlind(int client)
{
	int color[4];
	color[3] = 255;

	int flags = FFADE_OUT;
	
	int clients[1];
	clients[0] = client;
	
	int time = THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_BLIND_TIME].cvar.IntValue;
	
	Handle message = StartMessage("Fade", clients, 1, 1);
	if(GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", time * 1000);
		pb.SetInt("hold_time", time * 1000);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(time * 1000);
		bf.WriteShort(time * 1000);
		bf.WriteShort(flags);		
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}

Action Timer_BlindMode(Handle timer)
{
	if (!THIS_MODE_INFO.isOn)
	{
		g_hBlindModeTimer = null;
		return Plugin_Stop;
	}
	
	if (g_bRoundEnd || !g_bMotherZombie)
		return Plugin_Handled;
		
	int zombiesCount = 0;
	int zombies[MAXPLAYERS + 1];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || !ZR_IsClientZombie(i))
			continue;
		
		zombies[zombiesCount++] = i;
	}
	
	if (zombiesCount == 0)
		return Plugin_Handled;
		
	float percentage = THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_PERCENTAGE].cvar.FloatValue;
	int neededZombies = RoundToCeil(zombiesCount * (percentage / 100));
	
	int enough = 0;
	do 
	{
		int zombie = zombies[GetRandomInt(0, zombiesCount - 1)];
		if (g_bHasFlash[zombie])
			zombie = zombies[GetRandomInt(0, zombiesCount - 1)];
			
		g_bHasFlash[zombie] = true;
		int entity = GivePlayerItem(zombie, "weapon_flashbang");
		EquipPlayerWeapon(zombie, entity);
		SetEntData(zombie, FindSendPropInfo("CBasePlayer", "m_iAmmo") + (view_as<int>(GrenadeType_Flashbang) * 4), 1, _, true);
		CPrintToChat(zombie, "%s You have been granted a FlashBang!!!\nBlind some humans.", THIS_MODE_INFO.tag);
		enough++;
	} while (enough <= neededZombies);
	
	CPrintToChatAll("%s %d zombies have been granted a Blind grenade (Flashbang), watch out humans!", THIS_MODE_INFO.tag, neededZombies);
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "flashbang_projectile") == 0)
		CreateTimer(1.2, Timer_ApplyBlind, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ApplyBlind(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (!IsValidEntity(entity))
		return Plugin_Stop;
	
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (!owner)
		return Plugin_Stop;
	
	if (!IsPlayerAlive(owner) || !ZR_IsClientZombie(owner))
		return Plugin_Stop;
		
	float origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

	float maxDistance = THIS_MODE_INFO.cvarInfo[BLINDMODE_CONVAR_MAX_DISTANCE].cvar.FloatValue;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || !ZR_IsClientHuman(i))
			continue;
		
		float plOrigin[3];
		GetClientAbsOrigin(i, plOrigin);
		
		float distance = GetVectorDistance(origin, plOrigin);
		if(distance > maxDistance)
			continue;
		
		ApplyBlind(i);
	}
	
	g_bHasFlash[owner] = false;
	return Plugin_Handled;
}