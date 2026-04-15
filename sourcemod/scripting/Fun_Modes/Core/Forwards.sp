#pragma newdecls required
#pragma semicolon 1

#define CALL_MODE_FUNC_PARAM0(%1) %1()

#define DECLARE_FM_FORWARD0(%1) \
	FM_FOR_EACH_MODE(FM_CALL_%1)

/**********************************************************************************/
/**********************************************************************************/
/**********************************************************************************/
/* Forwards */
public void OnPluginStart()
{
	/* TRANSLATIONS LAODS */
	LoadTranslations("common.phrases");
	LoadTranslations("FunModes.phrases");
	
	/* HUD HANDLE */
	g_hHudMsg = CreateHudSynchronizer();

	g_cvHUDChannel = CreateConVar("sm_funmodes_hud_channel", "4", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);

	DECLARE_FM_FORWARD(OnPluginStart)

	AutoExecConfig();

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
			OnClientPutInServer(i);
	}
	
	static const char commands[][] = { "sm_fm_cvars", "sm_funmodes", "sm_funmode" };
	for(int i = 0; i < sizeof(commands); i++)
	{
		RegAdminCmd(commands[i], Cmd_FunModes, ADMFLAG_CONVARS, "Show all available funmodes");
	}

	RegAdminCmd("sm_fcvar", Cmd_FunModesCvars, ADMFLAG_CONVARS, "Change a FunModes cvar's value.");

	g_iNetPropAmmoIndex = FindSendPropInfo("CBasePlayer", "m_iAmmo");
	if (g_iNetPropAmmoIndex == -1)
		SetFailState("[FunModes] Could not find offset `CBasePlayer::m_iAmmo`");
		
	GameData gd = new GameData("sdkhooks.games/engine.ep2v");
	if (gd == null)
		LogError("[FunModes] Could not find \"sdkhooks.games/engine.ep2v.txt\" file.");
	else
	{
		int offset = gd.GetOffset("Weapon_Switch");
		if (offset == -1)
		{
			LogError("[FunModes] Could not find the offset of \"Weapon_Switch\", some features may be neglected");
			return;
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetVirtual(offset);
		
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
		
		g_hSwitchSDKCall = EndPrepSDKCall();
		
		if (g_hSwitchSDKCall == null)
			LogError("[FunModes] Incorrect offset for \"Weapon_Switch\", Cannot get a good SDKCall Handle");
	
		delete gd;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		OnClientDisconnect(i);
	}

	DECLARE_FM_FORWARD(OnPluginEnd)
}

public void OnMapStart()
{
	g_LaserSprite = PrecacheModel("sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
	g_iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	PrecacheSound(Beacon_Sound, true);

	DECLARE_FM_FORWARD(OnMapStart)
}

public void OnMapEnd()
{
	DECLARE_FM_FORWARD(OnMapEnd)
}

public void OnClientPutInServer(int client)
{
	DECLARE_FM_FORWARD(OnClientPutInServer)
}

public void OnClientDisconnect(int client)
{
	g_bSDKHook_OnTakeDamagePost[client] = false;
	g_bSDKHook_OnTakeDamage[client] = false;
	g_bSDKHook_WeaponEquip[client] = false;
	DECLARE_FM_FORWARD(OnClientDisconnect)
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect)
{		
	DECLARE_FM_FORWARD(ZR_OnClientInfected)
	if (motherInfect && !g_bMotherZombie)
		g_bMotherZombie = true;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	g_bMotherZombie = false;
	DECLARE_FM_FORWARD(Event_RoundStart)
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = true;
	g_bMotherZombie = false;
	DECLARE_FM_FORWARD(Event_RoundEnd)
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	DECLARE_FM_FORWARD(Event_PlayerSpawn)
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	DECLARE_FM_FORWARD(Event_PlayerTeam)
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	DECLARE_FM_FORWARD(Event_PlayerDeath)
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	DECLARE_FM_FORWARD(OnTakeDamagePost)
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD(OnTakeDamage)
	
	return result;
}

Action OnWeaponEquip(int client, int weapon)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD(OnWeaponEquip)
	
	return result;
}

public void OnAllPluginsLoaded()
{
	g_bPlugin_DynamicChannels = LibraryExists("DynamicChannels");
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = false;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse)
{
	DECLARE_FM_FORWARD(OnPlayerRunCmdPost)
}
