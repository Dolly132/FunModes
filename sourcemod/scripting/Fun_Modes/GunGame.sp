/*
    (). FunModes V2:
        
    @file           GunGame.sp
    @Usage         	Functions for the GunGame Mode.
    				
*/

/*
	GunGame Escape: Humans start with pistols like in a gg game, and every 1 thousand damage, 
	the gun automatically upgrades to the next one, making it into pistols, smgs, rifles and ending in m249. 
	After 1 complete cycle (If the map is long enough to cycle), 
	the human will get a random advantage such as 3 extra grenades, more speed, more grav... etc
	
	By @kiku-san
*/

#pragma semicolon 1
#pragma newdecls required

#undef REQUIRE_PLUGIN
#tryinclude <EntWatch>
#define REQUIRE_PLUGIN

#define _FM_GunGame

ModeInfo g_GunGameInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_GunGameInfo

#define GUNGAME_CONVAR_PISTOLS_DAMAGE	0
#define GUNGAME_CONVAR_SHOTGUNS_DAMAGE	1
#define GUNGAME_CONVAR_SMGS_DAMAGE		2
#define GUNGAME_CONVAR_RIFLES_DAMAGE	3
#define GUNGAME_CONVAR_M249_DAMAGE		4
#define GUNGAME_CONVAR_ENTWATCH			5
#define GUNGAME_CONVAR_HEGRENADES_COUNT 6
#define GUNGAME_CONVAR_REWARD_GRAVITY	7
#define GUNGAME_CONVAR_REWARD_SPEED		8
#define GUNGAME_CONVAR_TOGGLE 			9

static const char g_GunGameWeaponsList[][][] =
{
    { "weapon_glock", "weapon_usp", "weapon_p228", "weapon_deagle", "weapon_elite", "weapon_fiveseven" }, /* Pistols */
    { "weapon_m3", "weapon_xm1014", "", "", "", "" }, /* Shotguns */
    { "weapon_mac10", "weapon_ump45", "weapon_tmp", "weapon_mp5navy", "weapon_p90", "" }, /* SMGs */
    { "weapon_galil", "weapon_famas", "weapon_sg552", "weapon_aug", "weapon_ak47", "weapon_m4a1" }, /* Rifles */
    { "weapon_m249", "", "", "", "", "" } /* The one and only :) */
};

enum GunGame_Reward
{
	REWARD_SPEED = 0,
	REWARD_GRAVITY,
	REWARD_HEGRENADES,
	REWARD_NONE
};

enum struct GunGame_Data
{
	int level[2]; // [0] = weapon type, [1] = weapon index
	int dealtDamage;
	
	bool completedCycle;
	bool allowEquip;
	
	float originalSpeed;
	float originalGravity;
	
	GunGame_Reward reward;
	Handle rewardTimer;
	
	void ResetLevel()
	{
		this.level[0] = 0;
		this.level[1] = 0;
	}
}

GunGame_Data g_GunGameData[MAXPLAYERS + 1];

stock void OnPluginStart_GunGame()
{
	THIS_MODE_INFO.name = "GunGame";
	THIS_MODE_INFO.tag = "{gold}[FunModes-GunGame]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_gungame", Cmd_GunGameToggle, ADMFLAG_CONVARS, "Turn GunGame Mode On/Off");
	RegAdminCmd("sm_gungame_settings", Cmd_GunGameSettings, ADMFLAG_CONVARS, "Open GunGame Sttings Menu");
	
	RegConsoleCmd("sm_gungame", Cmd_GunGame, "Get your original weapons");

	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_PISTOLS_DAMAGE,
		"sm_gungame_pistols_damage", "1200", "The required damage needed for pistols to upgrade",
		("800,1000,1500,2000,2500"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_SHOTGUNS_DAMAGE,
		"sm_gungame_shotguns_damage", "2200", "The required damage needed for shotguns to upgrade",
		("800,1000,1500,2000,2500"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_SMGS_DAMAGE,
		"sm_gungame_smgs_damage", "4200", "The required damage needed for smgs to upgrade",
		("800,1000,1500,2000,2500"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_RIFLES_DAMAGE,
		"sm_gungame_rifles_damage", "3800", "The required damage needed for rifles to upgrade",
		("800,1000,1500,2000,2500"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_M249_DAMAGE,
		"sm_gungame_m249_damage", "8000", "The required damage needed for m249 to finish the gungame cycle",
		("800,1000,1500,2000,2500"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_ENTWATCH,
		"sm_gungame_allow_entwatch", "0", "Allow entwatch items to be picked up (1 = Enabled, 0 = Disabled)",
		("0,1"), "bool"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_HEGRENADES_COUNT,
		"sm_gungame_hegrenades_reward", "3", "How many hegrenades to give to the player when completing a cycle",
		("1,3,5,10,15"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_REWARD_GRAVITY,
		"sm_gungame_gravity_reward", "100.0", "How many seconds can the player keep their low gravity hold",
		("20.0,30.0,40.0,60.0,80.0,100.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_REWARD_SPEED,
		"sm_gungame_speed_reward", "100.0", "How many seconds can the player keep their high speed hold",
		("20.0,30.0,40.0,60.0,80.0,100.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, GUNGAME_CONVAR_TOGGLE,
		"sm_gungame_enable", "1", "Enable/Disable GunGame Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = GUNGAME_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_TOGGLE].cvar.AddChangeHook(OnGunGameModeToggle);
}

void OnGunGameModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_GunGame() {}
stock void OnMapEnd_GunGame()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	
	for (int i = 1; i <= MaxClients; i++)
		g_GunGameData[i].rewardTimer = null;
}

stock void OnClientPutInServer_GunGame(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	g_GunGameData[client].allowEquip = true;
	g_GunGameData[client].ResetLevel();
	
	if (!g_bSDKHook_WeaponEquip[client])
	{
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		g_bSDKHook_WeaponEquip[client] = true;
	}
	
	if (!g_bSDKHook_OnTakeDamagePost[client])
	{
		SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		g_bSDKHook_OnTakeDamagePost[client] = true;
	}
}

stock void OnClientDisconnect_GunGame(int client)
{
	delete g_GunGameData[client].rewardTimer;
}

stock void ZR_OnClientInfected_GunGame(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_GunGame() {}
stock void Event_RoundEnd_GunGame()
{
	for (int i = 1; i <= MaxClients; i++)
		g_GunGameData[i].allowEquip = true;
}

stock void Event_PlayerSpawn_GunGame(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	CreateTimer(2.0, Timer_GunGame_CheckPlayerSpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_GunGame_CheckPlayerSpawn(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;
		
	GunGame_GiveReward(client, REWARD_NONE);
	g_GunGameData[client].ResetLevel();
	
	if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
		return Plugin_Stop;
		
	GunGame_EquipWeapon(client, g_GunGameWeaponsList[0][GetRandomInt(0, 1)]);
	return Plugin_Stop;
}

stock void Event_PlayerTeam_GunGame(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_GunGame(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	GunGame_GiveReward(client, REWARD_NONE);
}

stock void OnTakeDamagePost_GunGame(int victim, int attacker, float damage)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	if (!(1<=attacker<=MaxClients) || !IsPlayerAlive(attacker) || !IsPlayerAlive(victim) || !ZR_IsClientZombie(victim) || !ZR_IsClientHuman(attacker))
		return;
	
	if (THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue && EntWatch_HasSpecialItem(attacker))
		return;
		
	int neededDamage = THIS_MODE_INFO.cvarInfo[g_GunGameData[attacker].level[0]].cvar.IntValue;
	
	if (g_GunGameData[attacker].dealtDamage >= neededDamage)
	{
		g_GunGameData[attacker].dealtDamage = 0;
		GunGame_GiveWeapon(attacker);
		return;
	}
	
	g_GunGameData[attacker].dealtDamage += RoundToNearest(damage);
}

stock void OnWeaponEquip_GunGame(int client, int weapon, Action &result)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!IsPlayerAlive(client) || ZR_IsClientZombie(client))
		return;
	
	if (THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue)
	{
	#if !defined _EntWatch_include
		THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue = false;
		return;
	#else
		if (EntWatch_IsSpecialItem(weapon))
			return;
	#endif
	}
	
	if (!g_GunGameData[client].allowEquip)
	{
		result = Plugin_Handled;
		return;
	}
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Continue;
		
	if (THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue)
	{
	#if !defined _EntWatch_include
		THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue = false;
		return Plugin_Continue;
	#else
		if (!EntWatch_HasSpecialItem(client))
			return Plugin_Continue;
	#endif
	}
	
	if (!g_GunGameData[client].allowEquip)
	{
		CPrintToChat(client, "%s You cannot buy/equip weapons during GunGame Escape Mode", THIS_MODE_INFO.tag);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action Cmd_GunGameToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s GunGame Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s GunGame Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	static bool cvarsValues[2];
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		FunModes_HookEvent(g_bEvent_PlayerSpawn, "player_spawn", Event_PlayerSpawn);
		FunModes_HookEvent(g_bEvent_PlayerDeath, "player_death", Event_PlayerDeath);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))	
				continue;
			
			OnClientPutInServer_GunGame(i);
			if (view_as<int>(g_GunGameData[i].reward) < view_as<int>(REWARD_HEGRENADES))
				GunGame_GiveReward(i, REWARD_NONE);
		}
		
		CPrintToChatAll("%s Your weapon will be upgraded when you reach the required damage for each weapon type!", THIS_MODE_INFO.tag);
		CS_TerminateRound(3.0, CSRoundEnd_Draw);
		
		ConVar cvar = FindConVar("zr_weapons_zmarket_rebuy");
		if (cvar != null)
		{
			cvarsValues[0] = cvar.BoolValue;
			cvar.BoolValue = false;
			delete cvar;
		}
		
		cvar = FindConVar("zr_weapons_zmarket");
		if (cvar != null)
		{
			cvarsValues[1] = cvar.BoolValue;
			cvar.BoolValue = false;
			delete cvar;
		}
	}
	else
	{
		ConVar cvar = FindConVar("zr_weapons_zmarket_rebuy");
		if (cvar != null)
		{
			cvar.BoolValue = cvarsValues[0];
			delete cvar;
		}
		
		cvar = FindConVar("zr_weapons_zmarket");
		if (cvar != null)
		{
			cvar.BoolValue = cvarsValues[1];
			delete cvar;
		}
	}
	
	return Plugin_Handled;
}

/* GunGame Settings */
public Action Cmd_GunGameSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_GunGameSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_GunGameSettings(Menu menu, MenuAction action, int param1, int param2)
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

Action Cmd_GunGame(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s GunGame is currently Off!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
	{
		CReplyToCommand(client, "%s You have to be an alive human to use this command!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_ENTWATCH].cvar.BoolValue)
	{
	#if defined _EntWatch_include
		if (EntWatch_HasSpecialItem(client))
		{
			static const char weapons[][] =  { "weapon_p90", "weapon_tmp", "weapon_ak47", "weapon_m4a1" };
			GunGame_EquipWeapon(client, weapons[GetRandomInt(0, sizeof(weapons)-1)], true);
			return Plugin_Handled;
		}
	#endif
	}
	
	int weaponType = g_GunGameData[client].level[0];
	int weaponIndex = g_GunGameData[client].level[1];
	if (weaponType > 0)
	{
		if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
			GunGame_EquipWeapon(client, g_GunGameWeaponsList[0][0], true);
	}
	
	GunGame_EquipWeapon(client, g_GunGameWeaponsList[weaponType][weaponIndex], true);
	
	return Plugin_Handled;
}

void GunGame_GiveWeapon(int client)
{
	int weaponType = g_GunGameData[client].level[0];
	int weaponIndex = g_GunGameData[client].level[1];
	
	/* If weapon type is still pistols */
	if (weaponType == 0)
	{
		int secondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		if (!IsValidEntity(secondary))
		{
			GunGame_EquipWeapon(client, g_GunGameWeaponsList[0][0]);
			g_GunGameData[client].level[0] = 0; g_GunGameData[client].level[1] = 0;
			return;
		}
		
		char weaponName[32];
		GetEntityClassname(secondary, weaponName, sizeof(weaponName));
		
		bool hasGlock = !strcmp(weaponName, "weapon_glock");
		
		if (hasGlock || strcmp(weaponName, "weapon_usp") == 0)
		{
			if (weaponIndex == 0)
			{
				GunGame_EquipWeapon(client, hasGlock ? "weapon_usp" : "weapon_glock");
				g_GunGameData[client].level[1] = 1;
				return;
			}
		}
	}
	
	if (weaponType == sizeof(g_GunGameWeaponsList) - 1)
	{
		weaponType = 0;
		weaponIndex = 0;
		
		/* Reward player with shits */
		g_GunGameData[client].completedCycle = true;
		GunGame_ShowRewardsMenu(client);
	}
	else if (++weaponIndex >= sizeof(g_GunGameWeaponsList[]) || g_GunGameWeaponsList[weaponType][weaponIndex][0] == '\0')
	{
		weaponType++;
		weaponIndex = 0;
	}

	g_GunGameData[client].level[0] = weaponType;
	g_GunGameData[client].level[1] = weaponIndex;
	
	GunGame_EquipWeapon(client, g_GunGameWeaponsList[weaponType][weaponIndex], weaponType > 0);
}

void GunGame_EquipWeapon(int client, const char[] weaponName, bool keepSecondary = false)
{
	int weapon = GivePlayerItem(client, weaponName);
	if (!IsValidEntity(weapon))
		return;
	
	GunGame_StripPlayer(client, keepSecondary);
	
	g_GunGameData[client].allowEquip = true;
	EquipPlayerWeapon(client, weapon);

	if (g_hSwitchSDKCall != null)
		SDKCall(g_hSwitchSDKCall, client, weapon, 0);

	g_GunGameData[client].allowEquip = false;
}

void GunGame_StripPlayer(int client, bool keepSecondary = false, bool giveSecondary = false)
{
	for (int i = 0; i <= 5; i++)
	{
		if (i == CS_SLOT_KNIFE || i == CS_SLOT_GRENADE)
			continue;
			
		if (keepSecondary && i == CS_SLOT_SECONDARY)
			continue;
			
		int wp = GetPlayerWeaponSlot(client, i);
		if (!IsValidEntity(wp))
		{
			if (i == CS_SLOT_SECONDARY && giveSecondary)
				GunGame_EquipWeapon(client, g_GunGameWeaponsList[0][0], true);
				
			continue;
		}
		
		SDKHooks_DropWeapon(client, wp);
		RemoveEntity(wp);
	}
}

void GunGame_ShowRewardsMenu(int client)
{
	GunGame_GiveReward(client, REWARD_SPEED);
	
	Menu menu = new Menu(Menu_GunGame_ShowRewards);
	menu.SetTitle("[GunGame Escape] You have completed a gungame cycle! Choose your reward!\nYou only have 60s to switch your rewards");
	
	menu.AddItem("0", "More Speed", g_GunGameData[client].reward == REWARD_SPEED ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("1", "Lower Gravity", g_GunGameData[client].reward == REWARD_GRAVITY ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("2", "More hegrenades", g_GunGameData[client].reward == REWARD_HEGRENADES ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	menu.ExitBackButton = true;
	menu.Display(client, 60);
}

int Menu_GunGame_ShowRewards(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char data[3];
			menu.GetItem(param2, data, sizeof(data));
			
			GunGame_Reward reward = view_as<GunGame_Reward>(StringToInt(data));
			GunGame_GiveReward(param1, reward);
		}
	}
	
	return 0;
}

void GunGame_GiveReward(int client, GunGame_Reward reward)
{
	g_GunGameData[client].reward = reward;
	
	/* Delete Timer */
	delete g_GunGameData[client].rewardTimer;
			
	switch (reward)
	{
		case REWARD_SPEED:
		{
			/* Reset Gravity */
			if (g_GunGameData[client].originalGravity != 0.0)
			{
				SetEntityGravity(client, g_GunGameData[client].originalGravity);
				g_GunGameData[client].originalGravity = 0.0;
			}
			
			if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
				return;
				
			g_GunGameData[client].originalSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_GunGameData[client].originalSpeed + 0.3);
			
			CPrintToChat(client, "%s You have been granted an extra speed for finishing a gungame cycle!", THIS_MODE_INFO.tag);
			
			delete g_GunGameData[client].rewardTimer;
			g_GunGameData[client].rewardTimer = CreateTimer(THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_REWARD_SPEED].cvar.FloatValue, Timer_GunGameReward, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		
		case REWARD_GRAVITY:
		{
			/* Reset Speed */
			if (g_GunGameData[client].originalSpeed != 0.0)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_GunGameData[client].originalSpeed);
				g_GunGameData[client].originalSpeed = 0.0;
			}
			
			if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
				return;
				
			g_GunGameData[client].originalGravity = GetEntityGravity(client);
			SetEntityGravity(client, 0.5);
			
			CPrintToChat(client, "%s You have been granted a lower gravity for finishing a gungame cycle!", THIS_MODE_INFO.tag);
			
			delete g_GunGameData[client].rewardTimer;
			g_GunGameData[client].rewardTimer = CreateTimer(THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_REWARD_GRAVITY].cvar.FloatValue, Timer_GunGameReward, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		
		case REWARD_HEGRENADES:
		{
			/* Reset Gravity */
			if (g_GunGameData[client].originalGravity != 0.0)
			{
				SetEntityGravity(client, g_GunGameData[client].originalGravity);
				g_GunGameData[client].originalGravity = 0.0;
			}
			
			/* Reset Speed */
			if (g_GunGameData[client].originalSpeed != 0.0)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_GunGameData[client].originalSpeed);
				g_GunGameData[client].originalSpeed = 0.0;
			}
			
			if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
				return;
				
			g_GunGameData[client].allowEquip = true;
			GivePlayerItem(client, "weapon_hegrenade");
			int count = THIS_MODE_INFO.cvarInfo[GUNGAME_CONVAR_HEGRENADES_COUNT].cvar.IntValue;
			GiveGrenadesToClient(client, GrenadeType_HEGrenade, count-1);
			g_GunGameData[client].allowEquip = false;
			
			CPrintToChat(client, "%s You have been granted {olive}%d extra hegrenades {lightgreen}for finishing a gungame cycle!", THIS_MODE_INFO.tag, count);
		}
		
		default:
		{	
			/* Reset Gravity */
			if (g_GunGameData[client].originalGravity != 0.0)
			{
				SetEntityGravity(client, g_GunGameData[client].originalGravity);
				g_GunGameData[client].originalGravity = 0.0;
			}
				
			/* Reset Speed */
			if (g_GunGameData[client].originalSpeed != 0.0)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_GunGameData[client].originalSpeed);
				g_GunGameData[client].originalSpeed = 0.0;
			}
		}
	}
}

Action Timer_GunGameReward(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;
	
	g_GunGameData[client].rewardTimer = null;
	
	CPrintToChat(client, "%s Sorry, your reward has ended!", THIS_MODE_INFO.tag);
	GunGame_GiveReward(client, REWARD_NONE);
	return Plugin_Stop;
}