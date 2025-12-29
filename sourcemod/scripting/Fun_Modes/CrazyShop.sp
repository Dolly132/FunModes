/*
    (). FunModes V2:
        
    @file           CrazyShop.sp
    @Usage         	Functions for the CrazyShop Mode.
    				
*/

/*
	Super DOLLYS shop: This is a shop where you get rewarded for shooting the zombies. 
	The shop consists using the credits you earn when shooting zombies to buy upgrades of your liking, 
	such as more hp, one knife protection (Is like a shield where you get protected from being killed 1 time), 
	golden weapon (This weapon fires the zombies when you shoot with it), even laser protection for some maps. 
	Of course the zombies would have some upgrades too, such as more speed, 
	kevlar (this would protect them from full knockback, being more difficult to push them, 100 bullets), 
	700 gravity, poison ball(Got this idea from lardy's limitless map), a laser that damages cts or slows them, 
	and even a grenade that would burn the humans, or one that flashes them.
	
	By @kiku-san
*/

/* 
	Based on the suggestion above, there wll be these rewards (depending on the team):
	- Humans Rewards:
		- More HP (+x) (Integer)
		- Infect Protection (For x seconds) (Integer)
		- Golden Weapon (Sets zombie on fire) (For x seconds) (String + Integer)
		- Laser Protection (For x seconds) (Integer)
		
	- Zombies Rewards:
		- More speed (+x.y) (Float)
		- KB Protection (for x seconds) (Integer)
		- Lower Gravtiy (-x.y) (Float)
		- Ignite Immunity (for x seconds) (Integer)
		- Chat Command (x times) (Integer)
		- Invisibility (for x seconds) (Integer)
		- Weapons Killer (x times) (Integer)
		- Magical Laser (x times) (Integer) (It will either be a slowing laser or a hurting one)
		- Magical Killing Laser (x times) (Integer) (It will be a laser that humans need to dodge, the price of this is gonna be high)
*/

#define _FM_CrazyShop

#if !defined _KnockbackRestrict_included_
	#undef REQUIRE_PLUGIN
	#tryinclude <KnockbackRestrict>
	#define REQUIRE_PLUGIN
#endif

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_CrazyShopInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_CrazyShopInfo

#define CRAZYSHOP_CONVAR_DAMAGE			0
#define CRAZYSHOP_CONVAR_CREDITS		1
#define CRAZYSHOP_CONVAR_SAVECREDITS	2
#define CRAZYSHOP_CONVAR_TOGGLE 		3

enum CrazyShop_DataType
{
	DATATYPE_NONE = 0,
	DATATYPE_AMOUNT,
	DATATYPE_TIME,
	DATATYPE_BOTH /* first one is amount and second is time */
}

enum struct CrazyShop_Item
{
	char name[32];
	int team;
	int price;
	float amount;
	float time;
	CrazyShop_DataType type;
	char amountName[32];
}

static CrazyShop_Item g_CrazyShopItems[] =
{
	/* Name, Team, Price */
	
	/* Humans Items (Team = 1) */
	{
		"More HP", 1, 10, 100.0, 0.0, DATATYPE_AMOUNT, "HP Amount to Add"
	},
	{
		"Infect Protection", 1, 15, 0.0, 15.0, DATATYPE_TIME, ""
	},
	{
		"Super Weapon", 1, 12, 2.5, 15.0, DATATYPE_BOTH, "Damage Scale"
	},
	{
		"Laser Protection", 1, 15, 0.0, 20.0, DATATYPE_TIME, ""
	},
	
	/* Zombies Items (Team = 0) */
	{
		"More Speed", 0, 10, 0.2, 15.0, DATATYPE_BOTH, "Speed Value (+)"
	},
	{
		"KB Protection", 0, 20, 0.2, 15.0, DATATYPE_BOTH, "Knockback Value (absolute)"
	},
	{
		"Lower Gravity", 0, 10, -0.2, 15.0, DATATYPE_BOTH, "Gravity Value (-)"
	},
	{
		"Magical Laser Thrower", 0, 15, 20.0, 0.0, DATATYPE_AMOUNT, "Laser Damage"
	},
	{
		"Magical Killing Laser", 0, 50, 0.0, 0.0, DATATYPE_NONE, ""
	},
	{
		"Ignite Immunity", 0, 10, 0.0, 20.0, DATATYPE_TIME, ""
	},
	{
		"Invisibility", 0, 15, 0.0, 15.0, DATATYPE_TIME, ""
	}
};

#define ITEMS_COUNT 11

enum struct CrazyShop_PlayerData
{
	int credits;
	int itemsCount[ITEMS_COUNT];
	int originalItemsCount[ITEMS_COUNT];
	bool isItemActive[ITEMS_COUNT];
	
	int dealtDamage;
	bool isInDB;
	bool infectionProtect;
	bool superWeapon;
	char superWeaponName[32];
	bool laserProtect;
	bool igniteImmunity;
	bool protectLaser;
	
	void Reset()
	{
		this.credits = 0;
		this.dealtDamage = 0;
		this.isInDB = false;
		this.infectionProtect = false;
		this.superWeapon = false;
		this.superWeaponName[0] = '\0';
		this.laserProtect = false;
		this.igniteImmunity = false;
		this.protectLaser = false;
		
		for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
		{
			this.itemsCount[i] = 0;
			this.originalItemsCount[i] = 0;
		}
	}
}

CrazyShop_PlayerData g_CrazyShopPlayerData[MAXPLAYERS + 1];

int g_iCrazyShopPreviousItem[MAXPLAYERS + 1];

Database g_hCrazyShop_DB;

/* Macros */
/***************************************************************/
#define THIS_MODE_DB					g_hCrazyShop_DB
#define CRAZYSHOP_DB_NAME				"FM_CrazyShop" // Only SQLITE is supported
#define CRAZYSHOP_DB_DATA_COLUMN		"clients_data"
#define CRAZYSHOP_DB_ITEMS_DATA_COLUMN	"shop_items_data"
/***************************************************************/
#define PLAYER_CREDITS(%1) 			g_CrazyShopPlayerData[%1].credits
#define PLAYER_ITEM_COUNT(%1,%2)	g_CrazyShopPlayerData[%1].itemsCount[%2]
#define PLAYER_ITEM_COUNT_OG(%1,%2)	g_CrazyShopPlayerData[%1].originalItemsCount[%2]
#define PLAYER_ITEM_ACTIVE(%1,%2)	g_CrazyShopPlayerData[%1].isItemActive[%2]
#define DAMAGE_DEALT(%1)			g_CrazyShopPlayerData[%1].dealtDamage
#define PLAYER_IN_DB(%1)			g_CrazyShopPlayerData[%1].isInDB
#define PLAYER_RESET(%1)			g_CrazyShopPlayerData[%1].Reset()
#define PLAYER_TEMP_VAR(%1,%2)		g_CrazyShopPlayerData[%1].%2
/***************************************************************/
/* Laser attributes constatns: */
#define PROP_MODEL              "models/nide/laser/laser.mdl"
#define PRECACHE_MOVE_SND       "nide/laser.wav"
#define MOVE_SND                "sound/nide/laser.wav"

#define LASER_DISTANCE_START    250.0
#define LASER_DISTANCE_END      2000.0

#define LASER_SPEED             1000

#define LASER_HEIGHT            30

#define LASER_KILL_TIMER        2.5
#define LASER_REPEAT_TIMER      2.0

#define LASER_ENABLE_DMG        true
#define LASER_DAMAGE            999999.0

#define SF_NOUSERCONTROL        2
#define SF_PASSABLE             8
/***************************************************************/

stock void OnPluginStart_CrazyShop()
{
	THIS_MODE_INFO.name = "CrazyShop";
	THIS_MODE_INFO.tag = "{gold}[FunModes-CrazyShop]{lightgreen}";
	
	/* COMMANDS */
	/* THESE ARE THE STANDARD COMMANDS THAT ALL MODES SHOULD HAVE */
	RegAdminCmd("sm_fm_crazyshop", Cmd_CrazyShopToggle, ADMFLAG_CONVARS, "Turn CrazyShop Mode On/Off");
	RegAdminCmd("sm_crazyshop_settings", Cmd_CrazyShopSettings, ADMFLAG_CONVARS, "Open CrazyShop Sttings Menu");
	RegConsoleCmd("sm_crazyshop", Cmd_CrazyShopMenu, "Open the CrazyShop Menu");
	RegConsoleCmd("sm_myitems", Cmd_CrazyShopMyItems, "Open the Available Items Menu");
	
	/* CONVARS */
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_DAMAGE,
		"sm_crazyshop_damage", "200", "The needed damage for humans to be rewarded with credits",
		("200,500,1000,1500,2000"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_CREDITS,
		"sm_crazyshop_credits", "1", "How many credits to reward the human when they reach the needed damage?",
		("1,2,3,4,5"), "int"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_SAVECREDITS,
		"sm_crazyshop_savecredits", "1", "Save credits to a database or not",
		("0,1"), "bool"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_TOGGLE,
		"sm_crazyshop_enable", "1", "Enable/Disable CrazyShop Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enabled = true;
	
	THIS_MODE_INFO.index = g_arModesInfo.Length;
	g_arModesInfo.PushArray(THIS_MODE_INFO);
	
	THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_TOGGLE].cvar.AddChangeHook(OnCrazyShopModeToggle);
}

void OnCrazyShopModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, enabled, cvar.BoolValue, THIS_MODE_INFO.index);
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnMapStart_CrazyShop()
{
	PrecacheModel(PROP_MODEL);
	PrecacheSound(PRECACHE_MOVE_SND);
	
	AddFileToDownloadsTable(MOVE_SND);
	AddFileToDownloadsTable(PROP_MODEL);
	
	AddFileToDownloadsTable("models/nide/laser/laser.phy");
	AddFileToDownloadsTable("models/nide/laser/laser.vvd");
	AddFileToDownloadsTable("models/nide/laser/laser.sw.vtx");
	AddFileToDownloadsTable("models/nide/laser/laser.dx80.vtx");
	AddFileToDownloadsTable("models/nide/laser/laser.dx90.vtx");
	
	AddFileToDownloadsTable("materials/models/nide/laser/laser1.vmt");
	AddFileToDownloadsTable("materials/models/nide/laser/laser1.vtf");
	AddFileToDownloadsTable("materials/models/nide/laser/laser2.vmt");
	AddFileToDownloadsTable("materials/models/nide/laser/laser2.vtf");
	AddFileToDownloadsTable("materials/models/nide/laser/white.vtf");
}

stock void OnMapEnd_CrazyShop()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
}

stock void OnClientPutInServer_CrazyShop(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!g_bSDKHook_OnTakeDamagePost[client])
	{
		SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		g_bSDKHook_OnTakeDamagePost[client] = true;
	}
	
	if (!g_bSDKHook_OnTakeDamage[client])
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		g_bSDKHook_OnTakeDamage[client] = true;
	}
}

stock void OnClientDisconnect_CrazyShop(int client)
{
	if (!THIS_MODE_INFO.isOn || THIS_MODE_DB == null)
		return;
	
	if (!PLAYER_IN_DB(client))
		CrazyShop_DB_AddPlayer(client);
	else
		CrazyShop_DB_SaveCredits(client);

	CrazyShop_DB_CheckItems(client);
	
	PLAYER_RESET(client);
}

stock void ZR_OnClientInfected_CrazyShop(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_CrazyShop() {}
stock void Event_RoundEnd_CrazyShop() {}
stock void Event_PlayerSpawn_CrazyShop(int client)
{
	#pragma unused client
}

stock void Event_PlayerTeam_CrazyShop(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_CrazyShop(int client)
{
	#pragma unused client
}

stock void OnTakeDamagePost_CrazyShop(int victim, int attacker, float damage)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!(1<=attacker<=MaxClients) || !ZR_IsClientZombie(victim) || !ZR_IsClientHuman(attacker))
		return;
		
	DAMAGE_DEALT(attacker) += RoundToNearest(damage);
	
	if (DAMAGE_DEALT(attacker) >= THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_DAMAGE].cvar.IntValue)
	{
		int credits = THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_CREDITS].cvar.IntValue;
		CPrintToChat(attacker, "%s You have been given {olive}%d credits {lightgreen}for damaging the zombies!", THIS_MODE_INFO.tag, credits);
		
		PLAYER_CREDITS(attacker) += credits;
		DAMAGE_DEALT(attacker) = 0;
	}
}

stock void OnWeaponEquip_CrazyShop(int client, int weapon, Action &result)
{
	#pragma unused client
	#pragma unused weapon
	#pragma unused result
}

stock void OnTakeDamage_CrazyShop(int victim, int &attacker, float &damage, Action &result)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	// victim is for sure gonna be a real player, so no need to check
	// check if victim is a human and has laser protect
	if (PLAYER_TEMP_VAR(victim, laserProtect) && ZR_IsClientHuman(victim))
	{
		if (!IsValidEntity(attacker))
			return;
			
		char classname[32];
		if (!GetEntityClassname(attacker, classname, sizeof(classname)))
			return;
	
		/* if attacker entity is not trigger_hurt */
		if (strcmp(classname, "trigger_hurt") != 0)
			return;
	
		/* we should now check if trigger_hurt is from a laser */
		int parent = GetEntPropEnt(attacker, Prop_Data, "m_hParent");	
		if (!IsValidEntity(parent))
			return;
	
		bool isFromLaser = false;
		char parentClassName[64];
		if (!GetEntityClassname(parent, parentClassName, sizeof(parentClassName)))
			return;
	
		if (strcmp(parentClassName, "func_movelinear") == 0 || strcmp(parentClassName, "func_door") == 0)
			isFromLaser = true;
			
		if (!isFromLaser)
			return;
			
		damage = 0.0;
		result = Plugin_Changed;
		return;
	}
	
	// check if victim is a zombie and attacker is human for ignite immunity
	if (PLAYER_TEMP_VAR(victim, igniteImmunity) && ZR_IsClientZombie(victim))
	{
		if (!(1<=attacker<=MaxClients) || !ZR_IsClientHuman(attacker))
			return;
			
		int flags = GetEntityFlags(victim);
		
		if (flags & FL_ONFIRE)
		{
			flags &= ~FL_ONFIRE;
			int effect = GetEntPropEnt(victim, Prop_Send, "m_hEffectEntity");
			if (IsValidEntity(effect))
			{
				char className[12];
				GetEntityClassname(effect, className, sizeof(className));
				
				if (strcmp(className, "entityflame") == 0)
					RemoveEntity(effect);
			}
		}
		
	}
	
	if ((1<=attacker<=MaxClients) && PLAYER_TEMP_VAR(attacker, superWeapon))
	{
		if (!ZR_IsClientZombie(victim) || !ZR_IsClientHuman(attacker))
			return;

		char weaponName[32];
		GetClientWeapon(attacker, weaponName, sizeof(weaponName));
		if (strcmp(weaponName, PLAYER_TEMP_VAR(attacker, superWeaponName)) != 0)
			return;
		
		damage *= g_CrazyShopItems[2].amount;
		int flags = GetEntityFlags(victim);
		
		if (!(flags & FL_ONFIRE))
			IgniteEntity(victim, 5.0);
			
		result = Plugin_Changed;
	}
}

/* This should be in FunModes.sp */
public void OnClientPostAdminCheck(int client)
{
	if (!THIS_MODE_INFO.isOn || THIS_MODE_DB == null)
		return;
		
	if (IsFakeClient(client))
		return;
		
	CrazyShop_DB_GetData(client, CRAZYSHOP_DB_DATA_COLUMN, "credits");
	CrazyShop_DB_GetData(client, CRAZYSHOP_DB_ITEMS_DATA_COLUMN, "item,count");
}

void CrazyShop_DB_OnConnect(Database db, const char[] error, any data)
{
	// We are not bothered to reconnect
	if (db == null || error[0])
	{
		LogError("[FM-%s] Couldn't connect to database, error: %s", THIS_MODE_INFO.name, error);
		return;
	}
	
	THIS_MODE_DB = db;
	THIS_MODE_DB.SetCharset("utf8mb4");
	
	CrazyShop_DB_CreateTables();
}

void CrazyShop_DB_CreateTables()
{
	char driver[10];
	THIS_MODE_DB.Driver.GetIdentifier(driver, sizeof(driver));
	
	if (strcmp(driver, "sqlite", false) != 0)
	{
		delete THIS_MODE_DB;
		LogError("[FM-%s] Only SQLITE is supported", THIS_MODE_INFO.name);
		return;
	}
	
	Transaction tr = SQL_CreateTransaction();

	char query[1024];
	THIS_MODE_DB.Format(query, sizeof(query), 
					"CREATE TABLE IF NOT EXISTS `%s` ("
				... "`client_steamid` INTEGER PRIMARY KEY NOT NULL,"
				... "`credits` INTEGER NOT NULL)", CRAZYSHOP_DB_DATA_COLUMN);
				
	tr.AddQuery(query);
	
	THIS_MODE_DB.Format(query, sizeof(query),
					"CREATE TABLE IF NOT EXISTS `%s` ("
				... "`client_steamid` INTEGER NOT NULL,"
				... "`item` INTEGER NOT NULL,"
				... "`count` INTEGER NOT NULL,"
				... "UNIQUE(`client_steamid`, `item`))", CRAZYSHOP_DB_ITEMS_DATA_COLUMN);
				
	tr.AddQuery(query);
	
	THIS_MODE_DB.Execute(tr, DB_CrazyShop_TablesOnSuccess, DB_CrazyShop_TablesOnError, _, DBPrio_High);
}

void DB_CrazyShop_TablesOnSuccess(Database database, any data, int queries, Handle[] results, any[] queryData)
{
	LogMessage("[FM-%s] Successfully created tables (SQLITE)", THIS_MODE_INFO.name);
	
	// here is where we get players' credits and items:
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		CrazyShop_DB_GetData(i, CRAZYSHOP_DB_DATA_COLUMN, "credits");
		CrazyShop_DB_GetData(i, CRAZYSHOP_DB_ITEMS_DATA_COLUMN, "item,count");
	}
}

void DB_CrazyShop_TablesOnError(Database database, any data, int queries, const char[] error, int failIndex, any[] queryData)
{
	LogError("[FM-%s] Error while creating tables (SQLITE): %s", error);
}

void CrazyShop_DB_GetData(int client, const char[] table, const char[] column)
{
	int steamID = GetSteamAccountID(client);
	if (!steamID)
		return;
	
	char query[1024];
	THIS_MODE_DB.Format(query, sizeof(query), "SELECT %s FROM `%s` WHERE `client_steamid`=%d", column, table, steamID);
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(column[0]);
	
	THIS_MODE_DB.Query(DB_CrazyShop_OnGetData, query, pack, DBPrio_Normal);
}

void DB_CrazyShop_OnGetData(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (error[0])
	{
		LogError("[FM-%s] Error getting client data: %s", THIS_MODE_INFO.name, error);
		delete pack;
		return;
	}
	
	if (results == null || !results.RowCount)
	{
		delete pack;
		return;
	}
	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}
	
	bool isCredits = pack.ReadCell() == 'c';
	delete pack;
	
	if (!results.FetchRow())
		return;
	
	if (isCredits)
	{
		PLAYER_IN_DB(client) = true;
		PLAYER_CREDITS(client) = results.FetchInt(0);
	}
	else
	{
		// 2 fields here (item and count)
		results.Rewind();
		while (results.FetchRow())
		{
			int item = results.FetchInt(0);
			int count = results.FetchInt(1);
			
			PLAYER_ITEM_COUNT(client, item) = count;
			PLAYER_ITEM_COUNT_OG(client, item) = count;
		}
	}
}

void CrazyShop_DB_AddPlayer(int client)
{
	int steamID = GetSteamAccountID(client);
	if (!steamID)
		return;
		
	char query[1024];
	THIS_MODE_DB.Format(query, sizeof(query), 	"INSERT INTO `%s` (`client_steamid`, `credits`) VALUES (%d, %d) "
										    ... "ON CONFLICT(`client_steamid`) DO UPDATE SET `credits`=excluded.credits",
										    	CRAZYSHOP_DB_DATA_COLUMN, steamID, PLAYER_CREDITS(client));
	
	THIS_MODE_DB.Query(DB_CrazyShop_OnAddPlayer, query, _, DBPrio_High);
}

void DB_CrazyShop_OnAddPlayer(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (error[0])
		LogError("[FM-%s] Error while inserting data: %s", THIS_MODE_INFO.name, error);
}

void CrazyShop_DB_SaveCredits(int client)
{
	int steamID = GetSteamAccountID(client);
	if (!steamID)
		return;
		
	char query[1024];
	THIS_MODE_DB.Format(query, sizeof(query), 	"UPDATE `%s` SET `credits`=%d WHERE `client_steamid`=%d",
										    	CRAZYSHOP_DB_DATA_COLUMN, PLAYER_CREDITS(client), steamID);
	
	THIS_MODE_DB.Query(DB_CrazyShop_OnSaveCredits, query, _, DBPrio_High);
}

void DB_CrazyShop_OnSaveCredits(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (error[0])
		LogError("[FM-%s] Error while saving player credits: %s", THIS_MODE_INFO.name, error);
}

void CrazyShop_DB_CheckItems(int client)
{
	int steamID = GetSteamAccountID(client);
	if (!steamID)
		return;
		
	char query[1024];
	bool hasItems = false;
	for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
	{
		if (PLAYER_ITEM_COUNT(client, i) > 0)
		{
			hasItems = true;
			break;
		}
	}
	
	if (!hasItems)
	{
		THIS_MODE_DB.Format(query, sizeof(query), 	"DELETE FROM `%s` WHERE `client_steamid`=%d",
											    	CRAZYSHOP_DB_ITEMS_DATA_COLUMN, steamID);
		
		THIS_MODE_DB.Query(DB_CrazyShop_OnCheckItems, query, _, DBPrio_High);
	}
	else
	{
		for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
		{
			THIS_MODE_DB.Format(query, sizeof(query), 	"INSERT INTO `%s` (`client_steamid`, `item`, `count`) VALUES "
													... "(%d, %d, %d) ON CONFLICT(`client_steamid`, `item`) DO UPDATE SET "
													... "`count` = excluded.count WHERE `count` != excluded.count",
												    	CRAZYSHOP_DB_ITEMS_DATA_COLUMN, steamID, i, PLAYER_ITEM_COUNT(client, i));
			
			THIS_MODE_DB.Query(DB_CrazyShop_OnCheckItems, query, _, DBPrio_High);
		}
	}
}

void DB_CrazyShop_OnCheckItems(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (error[0])
		LogError("[FM-%s] Error while checking player credits: %s", THIS_MODE_INFO.name, error);
}

public Action Cmd_CrazyShopToggle(int client, int args)
{
	if (!THIS_MODE_INFO.enabled)
	{
		CReplyToCommand(client, "%s CrazyShop Mode is currently Disabled", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	/* You can change whatever you want here */
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, !THIS_MODE_INFO.isOn, THIS_MODE_INFO.index);
	
	CPrintToChatAll("%s CrazyShop Mode is now %s!", THIS_MODE_INFO.tag, THIS_MODE_INFO.isOn ? "On" : "Off");
	
	if (THIS_MODE_INFO.isOn)
	{
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_RoundEnd, "round_end", Event_RoundEnd);
		
		CPrintToChatAll("%s Earn credits by defending and shooting the zombies!", THIS_MODE_INFO.tag);
		CPrintToChatAll("%s Type {olive}!crazyshop {lightgreen}to open the Shop Menu and buy powerful items!", THIS_MODE_INFO.tag);
		
		if (THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_SAVECREDITS].cvar.BoolValue)
			Database.Connect(CrazyShop_DB_OnConnect, CRAZYSHOP_DB_NAME);
			
		CrazyShop_GetItems();
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsClientSourceTV(i))
				continue;
			
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			g_bSDKHook_OnTakeDamagePost[i] = true;
			g_bSDKHook_OnTakeDamage[i] = true;
		}
	}
	else
		delete THIS_MODE_DB;
	
	return Plugin_Handled;
}

/* CrazyShop Settings */
void CrazyShop_GetItems()
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/FM_CrazyShop.cfg");
	
	KeyValues kv = new KeyValues("Items");
	
	if (!kv.ImportFromFile(filePath))
	{
		delete kv;
		return;
	}
	
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}
	
	int i = 0;
	do 
	{
		char name[sizeof(CrazyShop_Item::name)];
		kv.GetString("name", name, sizeof(name)); 
		
		int price = kv.GetNum("price");
		g_CrazyShopItems[i].name = name;
		g_CrazyShopItems[i].price = price;
		
		CrazyShop_DataType type = view_as<CrazyShop_DataType>(kv.GetNum("type", g_CrazyShopItems[i].type));
		switch (type)
		{
			case DATATYPE_AMOUNT: g_CrazyShopItems[i].amount = kv.GetFloat("amount", g_CrazyShopItems[i].amount);
			case DATATYPE_TIME: g_CrazyShopItems[i].time = kv.GetFloat("time", g_CrazyShopItems[i].time);
			case DATATYPE_BOTH:
			{
				g_CrazyShopItems[i].amount = kv.GetFloat("amount", g_CrazyShopItems[i].amount);
				g_CrazyShopItems[i].time = kv.GetFloat("time", g_CrazyShopItems[i].time);
			}
		}
		
		i++;
	} while (kv.GotoNextKey());
	
	delete kv;
}

void CrazyShop_AdminPanel(int client)
{
	Menu menu = new Menu(Menu_CrazyShop_AdminPanel);
	
	menu.SetTitle("[CrazyShop] Admin Panel (The secret place, shhh!)");
	
	for (int i = 0; i < sizeof(g_CrazyShopItems); i++)
	{
		char item[128];
		FormatEx(item, sizeof(item), "%s - Edit", g_CrazyShopItems[i].name);
		
		menu.AddItem(NULL_STRING, item);
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CrazyShop_AdminPanel(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
			CrazyShop_OpenItemSettings(param1, param2);
	}

	return 0;
}

void CrazyShop_OpenItemSettings(int client, int item)
{
	g_iCrazyShopPreviousItem[client] = item;
	
	Menu menu = new Menu(Menu_CrazyShop_ItemSettings);
	
	CrazyShop_DataType type = g_CrazyShopItems[item].type;
	char valuesString[sizeof(CrazyShop_Item::amountName)+32];
	switch (type)
	{
		case DATATYPE_AMOUNT: FormatEx(valuesString, sizeof(valuesString), "%s: %.2f", g_CrazyShopItems[item].amountName, g_CrazyShopItems[item].amount);
		case DATATYPE_TIME: FormatEx(valuesString, sizeof(valuesString), "Time: %.2fs", g_CrazyShopItems[item].time);
		case DATATYPE_BOTH: FormatEx(valuesString, sizeof(valuesString), "%s: %.2f\nTime: %.2fs", g_CrazyShopItems[item].amountName, g_CrazyShopItems[item].amount, g_CrazyShopItems[item].time);
	}
	
	menu.SetTitle("[CrazyShop] %s - Settings\nPrice: %d\n%s", g_CrazyShopItems[item].name, g_CrazyShopItems[item].price, valuesString);
	
	menu.AddItem(NULL_STRING, "Change Price");
	
	if (type == DATATYPE_AMOUNT || type == DATATYPE_BOTH)
	{
		char itemText[sizeof(CrazyShop_Item::amountName) + 20];
		FormatEx(itemText, sizeof(itemText), "Change %s", g_CrazyShopItems[item].amountName);
		
		menu.AddItem(NULL_STRING, itemText);
	}
	
	if (type == DATATYPE_TIME || type == DATATYPE_BOTH)
		menu.AddItem(NULL_STRING, "Change Time");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CrazyShop_ItemSettings(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				CrazyShop_AdminPanel(param1);
		}
		
		case MenuAction_Select:
			CrazyShop_OpenItemAction(param1, param2);
	}

	return 0;
}

void CrazyShop_OpenItemAction(int client, int action)
{
	CrazyShop_Item item;
	item = g_CrazyShopItems[g_iCrazyShopPreviousItem[client]];
	
	/* 0 = price, 1 = amount (if type is amount or all), time (if type is time), 2 = time (if found) */
	Menu menu = new Menu(Menu_CrazyShop_ItemAction);
	
	if (action == 0)
	{
		menu.SetTitle("[CrazyShop] %s - Price\nCurrent Price: %d", item.name, item.price);
		
		for (int i = item.price; i <= item.price * 2; i += item.price / 2)
		{
			char thisVal[3];
			IntToString(i, thisVal, sizeof(thisVal));
			
			char data[sizeof(thisVal) + 2];
			FormatEx(data, sizeof(data), "0|%s", thisVal);
			
			menu.AddItem(data, thisVal);
		}
	}
	
	/* this is 100% time */
	if (action == 2)
	{
		menu.SetTitle("[CrazyShop] %s - Time\nCurrent Time: %.2f", item.name, item.time);
		
		for (float f = item.time; f <= item.time * 1.5; f += item.time / 1.5)
		{
			char thisVal[6];
			FloatToString(f, thisVal, sizeof(thisVal));
			
			char data[sizeof(thisVal) + 2];
			FormatEx(data, sizeof(data), "2|%s", thisVal);
			
			menu.AddItem(data, thisVal);
		}
	}
	
	if (action == 1)
	{
		if (item.type != DATATYPE_AMOUNT)
		{
			menu.SetTitle("[CrazyShop] %s - Time\nCurrent Time: %.2f", item.name, item.time);
			
			for (float f = item.time; f <= item.time * 1.5; f += item.time / 1.5)
			{
				char thisVal[6];
				FloatToString(f, thisVal, sizeof(thisVal));
				
				char data[sizeof(thisVal) + 2];
				FormatEx(data, sizeof(data), "2|%s", thisVal);
				
				menu.AddItem(data, thisVal);
			}
		}
		else
		{
			menu.SetTitle("[CrazyShop] %s - %s\nCurrent %s: %.2f", item.name, item.amountName, item.amountName, item.amount);
			
			for (float f = item.amount; f <= item.amount * 2; f += item.amount / 2)
			{
				char thisVal[6];
				FloatToString(f, thisVal, sizeof(thisVal));
				
				char data[sizeof(thisVal) + 2];
				FormatEx(data, sizeof(data), "1|%s", thisVal);
				
				menu.AddItem(data, thisVal);
			}
		}
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CrazyShop_ItemAction(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				CrazyShop_OpenItemSettings(param1, g_iCrazyShopPreviousItem[param1]);
		}
		
		case MenuAction_Select:
		{
			char info[15];
			menu.GetItem(param2, info, sizeof(info));
			
			char data[2][10];
			ExplodeString(info, "|", data, sizeof(data), sizeof(data[]));
			
			int itemAction = StringToInt(data[0]);
			
			switch (itemAction)
			{
				case 0: CrazyShop_UpdateItemData(param1, itemAction, "price", data[1]);
				case 1: CrazyShop_UpdateItemData(param1, itemAction, "amount", data[1]);
				case 2: CrazyShop_UpdateItemData(param1, itemAction, "time", data[1]);
			}
		}
	}

	return 0;
}

void CrazyShop_UpdateItemData(int client, int item, const char[] key, const char[] value)
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/FM_CrazyShop.cfg");
	
	KeyValues kv = new KeyValues("Items");
	
	if (!kv.ImportFromFile(filePath))
	{
		CPrintToChat(client, "%s Sorry, no settings file was found, Changes will not be saved (Report this to the server manager).", THIS_MODE_INFO.tag);
		delete kv;
	}
	
	if (kv != null)
	{
		char keyNum[3];
		IntToString(item, keyNum, sizeof(keyNum));
		
		if (kv.JumpToKey(keyNum))
		{	
			kv.SetString(key, value);
			kv.Rewind();
			kv.ExportToFile(filePath);
		}
		else
			CPrintToChat(client, "%s Sorry, the item is not in the settings file, changes will not be saved, (Report this to the server manager)", THIS_MODE_INFO.tag);
	}
	
	delete kv;
	
	if (key[0] == 'p') 
		g_CrazyShopItems[item].price = StringToInt(value);
	else if (key[0] == 'a') 
		g_CrazyShopItems[item].amount = StringToFloat(value);
	else 
		g_CrazyShopItems[item].time = StringToFloat(value);

	CPrintToChat(client, "%s You have successfully changed {olive}%s {lightgreen}of %s {olive}to %s", THIS_MODE_INFO.tag, key, g_CrazyShopItems[item].name, value);
}

public Action Cmd_CrazyShopSettings(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	Menu menu = new Menu(Menu_CrazyShopSettings);

	menu.SetTitle("%s - Settings", THIS_MODE_INFO.name);

	menu.AddItem(NULL_STRING, "Show Cvars\n ");
	menu.AddItem(NULL_STRING, "Manage Shop Items");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int Menu_CrazyShopSettings(Menu menu, MenuAction action, int param1, int param2)
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
			if (param2 == 0)
				ShowCvarsInfo(param1, THIS_MODE_INFO);
			else
				CrazyShop_AdminPanel(param1);
		}
	}

	return 0;
}

Action Cmd_CrazyShopMenu(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s The CrazyShop Mode is currently OFF!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (!client)
		return Plugin_Handled;
		
	CrazyShop_OpenMenu(client);
	return Plugin_Handled;
}

Action Cmd_CrazyShopMyItems(int client, int args)
{
	if (!THIS_MODE_INFO.isOn)
	{
		CReplyToCommand(client, "%s The CrazyShop Mode is currently OFF!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
	if (!client)
		return Plugin_Handled;
	
	CrazyShop_OpenAvailableItems(client);
	return Plugin_Handled;
}

void CrazyShop_OpenMenu(int client)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	Menu menu = new Menu(Menu_CrazyShop);
	
	menu.SetTitle("[CrazyShop] Items List\nYour credits: %d$", PLAYER_CREDITS(client));
	
	for (int i = 0; i < sizeof(g_CrazyShopItems); i++)
	{
		char team[10]; 
		team = (g_CrazyShopItems[i].team == 0) ? "Zombies" : "Humans";
		
		char[] item = new char[sizeof(CrazyShop_Item::name) + strlen(team)];
		FormatEx(item, sizeof(CrazyShop_Item::name) + strlen(team), "%s - %d$ [%s]%s", g_CrazyShopItems[i].name, g_CrazyShopItems[i].price, team, i == (sizeof(g_CrazyShopItems)-1) ? "\n ":"");
		
		menu.AddItem(NULL_STRING, item, PLAYER_CREDITS(client) >= g_CrazyShopItems[i].price ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	menu.AddItem(NULL_STRING, "Gift 5 credits", PLAYER_CREDITS(client) >= 5 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CrazyShop(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			// Gift 5 credits
			if (param2 == sizeof(g_CrazyShopItems))
			{
				CrazyShop_OpenGiftMenu(param1);
				return -1;
			}
			
			if (PLAYER_CREDITS(param1) < g_CrazyShopItems[param2].price)
			{
				CPrintToChat(param1, "%s You have insufficent credits to buy this item.", THIS_MODE_INFO.tag);
				return -1;
			}
			
			PLAYER_CREDITS(param1) -= g_CrazyShopItems[param2].price;
			PLAYER_ITEM_COUNT(param1, param2) += 1;
			CPrintToChat(param1, "%s You have successfully bought {olive}%s, {lightgreen}Type !myitems to activate it!", THIS_MODE_INFO.tag, g_CrazyShopItems[param2].name);
			CrazyShop_OpenMenu(param1);
		}
	}
	
	return -1;
}

void CrazyShop_OpenGiftMenu(int client)
{
	Menu menu = new Menu(Menu_CrazyShop_Gift);
	
	menu.SetTitle("[CrazyShop] Select Player to gift 5 credits");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || i == client)
			continue;
		
		char userId[10];
		IntToString(GetClientUserId(i), userId, sizeof(userId));
		
		char item[64];
		FormatEx(item, sizeof(item), "%N - [%d$]", i, PLAYER_CREDITS(i));
		
		menu.AddItem(userId, item);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CrazyShop_Gift(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				CrazyShop_OpenMenu(param1);
		}
		
		case MenuAction_Select:
		{
			if (PLAYER_CREDITS(param1) < 5)
			{
				CPrintToChat(param1, "%s You do not have 5 credits to gift.", THIS_MODE_INFO.tag);
				return -1;
			}
			
			char userId[10];
			menu.GetItem(param2, userId, sizeof(userId));
			
			int target = GetClientOfUserId(StringToInt(userId));
			if (!target)
			{
				CPrintToChat(param1, "%s Player is no longer available!", THIS_MODE_INFO.tag);
				return -1;
			}
			
			PLAYER_CREDITS(target) += 5;
			PLAYER_CREDITS(param1) -= 5;
			CPrintToChat(param1, "%s You have gifted {olive}%N {lightgreen}5 credits, you are so generous!", THIS_MODE_INFO.tag, target);
			CPrintToChat(target, "%s %N {olive}has gifted you 5 credits! What a generous man!", THIS_MODE_INFO.tag, param1);
		}
	}
	
	return -1;
}

void CrazyShop_OpenAvailableItems(int client)
{
	int itemsCount = false;
	
	Menu menu;
	int lastItem;
	
	for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
	{
		if (PLAYER_ITEM_COUNT(client, i))
		{
			lastItem = i;
			itemsCount++;
		}
		
		if (menu == null && itemsCount > 1)
		{
			menu = new Menu(Menu_AvailableItems);
			menu.SetTitle("[CrazyShop] Your Available Items!");
		}
		
		if (menu && itemsCount > 1 && PLAYER_ITEM_COUNT(client, i) > 0)
		{
			char item[64];
			FormatEx(item, sizeof(item), "%s - Activate", g_CrazyShopItems[i].name);
			
			char data[3];
			IntToString(i, data, sizeof(data));
			menu.AddItem(data, item);
		}
	}
	
	if (!itemsCount)
	{
		CPrintToChat(client, "%s You have no available items!", THIS_MODE_INFO.tag);
		return;
	}
	
	if (itemsCount == 1)
	{
		CrazyShop_Activate(client, lastItem);
		return;
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_AvailableItems(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			char data[3];
			menu.GetItem(param2, data, sizeof(data));
			
			int itemNum = StringToInt(data);
			
			if (PLAYER_ITEM_COUNT(param1, itemNum) <= 0)
			{
				CPrintToChat(param1, "%s You do not have this item in your inventory", THIS_MODE_INFO.tag);
				return 0;
			}
			
			CrazyShop_Activate(param1, itemNum);
			CrazyShop_OpenAvailableItems(param1);
		}
	}
	
	return -1;
}

void CrazyShop_Activate(int client, int itemNum)
{
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s You are not alive to activate this item.", THIS_MODE_INFO.tag);
		return;
	}
	
	CrazyShop_Item item;
	item = g_CrazyShopItems[itemNum];
		
	if (item.team == 1 && !ZR_IsClientHuman(client))
	{
		CPrintToChat(client, "%s This is a human item, you cannot use it right now!", THIS_MODE_INFO.tag);
		return;
	}
	
	if (item.team == 0 && !ZR_IsClientZombie(client))
	{
		CPrintToChat(client, "%s This is a zombie item, you cannot use it right now!", THIS_MODE_INFO.tag);
		return;
	}
	
	if (PLAYER_ITEM_ACTIVE(client, itemNum))
	{
		CPrintToChat(client, "%s You cannot activate the same item again unless the old ones' effect ended", THIS_MODE_INFO.tag);
		return;
	}
	
	switch (itemNum)
	{
		// HP - Humans
		case 0:
		{
			int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
			SetEntProp(client, Prop_Data, "m_iMaxHealth", maxHealth + RoundToNearest(item.amount));
			
			SetEntityHealth(client, GetClientHealth(client) + RoundToNearest(item.amount));
		}
		
		// Infection Protection - Humans
		case 1:
		{	
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, infectionProtect) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_InfectionProtection, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// Super Weapon - Humans
		case 2:
		{
		#if defined _KnockbackRestrict_included_
			if (KR_ClientStatus(client))
			{
				CPrintToChat(client, "%s You cannot use this item while you are kbanned!", THIS_MODE_INFO.tag);
				return;
			}
		#endif
			
			static const char weaponsList[][] =
			{
			    "weapon_mac10", "weapon_tmp", "weapon_mp5navy", "weapon_ump45", "weapon_p90",
			    "weapon_galil", "weapon_famas", "weapon_ak47", "weapon_m4a1", "weapon_sg552", "weapon_aug",
			    "weapon_m249"
			};
			
			strcopy(PLAYER_TEMP_VAR(client, superWeaponName), sizeof(CrazyShop_PlayerData::superWeaponName), 
									weaponsList[GetRandomInt(0, sizeof(weaponsList) - 1)]);
			
			int weapon = GivePlayerItem(client, PLAYER_TEMP_VAR(client, superWeaponName));
			EquipPlayerWeapon(client, weapon);
			
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, superWeapon) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_SuperWeapon, pack, TIMER_FLAG_NO_MAPCHANGE);
			CPrintToChat(client, "u have activated super weapon bro Time %f", item.time);
		}
		
		// Laser Protection - Humans
		case 3:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, laserProtect) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_LaserProtection, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// More Speed - Zombies
		case 4:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			float originalSpeed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
			
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", originalSpeed + item.amount);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			pack.WriteFloat(originalSpeed);
			
			CreateTimer(item.time, Timer_CrazyShop_MoreSpeed, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// KB Protection - Zombies
		case 5:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			// Default value for ZR_SetClientKnockbackScale is 1.0
			ZR_SetClientKnockbackScale(client, item.amount);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_KBProtection, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// Lower Gravity - Zombies
		case 6:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			SetEntityGravity(client, 1.0 + item.amount);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_LowerGravity, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// Magical Laser - Zombies
		case 7:
		{	
			CrazyShop_ThrowLaser(client, RoundToNearest(item.amount));
		}
		
		// Magical Killing Laser - Zombies
		case 8:
		{
			CrazyShop_ThrowLaser(client, 99999);
		}
		
		// Ignite Immunity - Zombies
		case 9:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, igniteImmunity) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_IgniteImmunity, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// Invisibility
		case 10:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			int nodraw = 0x20;
			
			SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") | nodraw);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_Invisibility, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	if (item.time > 0.0)
	{
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntProp(client, Prop_Send, "m_iProgressBarDuration", RoundToNearest(item.time));
	}
	
	PLAYER_ITEM_COUNT(client, itemNum)--;
}

Action Timer_CrazyShop_InfectionProtection(Handle timer, DataPack pack)
{
	if (g_bRoundEnd)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	PLAYER_TEMP_VAR(client, infectionProtect) = false;
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_SuperWeapon(Handle timer, DataPack pack)
{
	if (g_bRoundEnd)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	PLAYER_TEMP_VAR(client, superWeaponName)[0] = '\0';
	PLAYER_TEMP_VAR(client, superWeapon) = false;
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_LaserProtection(Handle timer, DataPack pack)
{
	if (g_bRoundEnd)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	PLAYER_TEMP_VAR(client, laserProtect) = false;
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_MoreSpeed(Handle timer, DataPack pack)
{
	if (g_bRoundEnd)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	float speed = pack.ReadFloat();
	
	delete pack;
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_KBProtection(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	ZR_SetClientKnockbackScale(client, 1.0);
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_LowerGravity(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	SetEntityGravity(client, 1.0);
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_IgniteImmunity(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	PLAYER_TEMP_VAR(client, igniteImmunity) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_Invisibility(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	delete pack;
	
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	
	int nodraw = 0x20;
	SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") & ~nodraw);
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

/* Special Thanks to https://github.com/srcdslab/sm-plugin-Laser */
/* Minor Edits by Dolly */
/*******************************************************************/
void CrazyShop_ThrowLaser(int client, int damage)
{
	float vecEyeAngles[3];
	float startPos[3];
	
	GetClientEyeAngles(client, vecEyeAngles);
	
	float height = float(GetRandomInt(0, 1) ? LASER_HEIGHT : LASER_HEIGHT * 2);
	
	float vecAbsOrigin[3];
	GetClientAbsOrigin(client, vecAbsOrigin);
	startPos[0] = vecAbsOrigin[0];
	startPos[1] = vecAbsOrigin[1];
	startPos[2] = vecAbsOrigin[2] + height;
	
	int moveLinear = CreateEntityByName("func_movelinear");
	if (moveLinear == -1)
		return;
	
	float currentTime = GetGameTime();
	
	char propName[32];
	FormatEx(propName, sizeof(propName), "%d_FM_PROP_LASER_%d_%f", damage, GetClientUserId(client), currentTime);
	int prop = CrazyShop_CreateProp(propName, moveLinear);
	if (prop == -1)
	{
		RemoveEntity(moveLinear);
		return;
	}
		
	char targetName[20];
	FormatEx(targetName, sizeof(targetName), "FM_LASER_%d_%f", GetClientUserId(client), currentTime);
	
	DispatchKeyValue(moveLinear, "targetname", targetName);
	DispatchKeyValueInt(moveLinear, "spawnflags", 8);
	DispatchKeyValueVector(moveLinear, "movedir", vecEyeAngles);
	DispatchKeyValueInt(moveLinear, "speed", LASER_SPEED);
	DispatchKeyValue(moveLinear, "startsound", PRECACHE_MOVE_SND);
	DispatchKeyValueFloat(moveLinear, "startposition", 0.0);
	
	char output[sizeof(propName) + 15];
	FormatEx(output, sizeof(output), "%s:Kill::0:-1", propName);
	
	DispatchKeyValue(moveLinear, "OnFullyOpen", output);
	
	FormatEx(output, sizeof(output), "!self:Kill::0:-1");
	DispatchKeyValue(moveLinear, "OnFullyOpen", output);
	
	TeleportEntity(moveLinear, startPos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchSpawn(moveLinear);
	
	AcceptEntityInput(moveLinear, "Open");
}

stock int CrazyShop_CreateProp(const char[] name, int moveLinear)
{
	int ent = CreateEntityByName("prop_dynamic_override"); 
	if (ent == -1)
		return -1;
	
	DispatchKeyValue(ent, "targetname", name);
	DispatchKeyValue(ent, "solid", "0");
	DispatchKeyValue(ent, "model", PROP_MODEL);
	DispatchKeyValue(ent, "disableshadows", "1");
	DispatchKeyValue(ent, "disablereceiveshadows", "1");
	
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
	SetEntProp(ent, Prop_Data, "m_nSolidType", 2);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);
	SDKHook(ent, SDKHook_StartTouch, Hook_PropHit);
	
	SetVariantInt(moveLinear);
	AcceptEntityInput(ent, "SetParent");
	
	return ent;
}

Action Hook_PropHit(int entity, int other)
{
	if (!(1<=other<=MaxClients))
		return Plugin_Continue;
	
	if (!IsPlayerAlive(other) || ZR_IsClientZombie(other))
		return Plugin_Continue;
		
	if (PLAYER_TEMP_VAR(other, protectLaser))
		return Plugin_Continue;
	
	char damageStr[5];
	
	char name[32];
	GetEntPropString(entity, Prop_Data, "m_nName", name, sizeof(name));
	
	for (int i = 0; i < strlen(name); i++)
	{
		if (name[i] == '_')
		{
			strcopy(damageStr, sizeof(damageStr), name[i]);
			break;
		}
	}
	
	int damage = StringToInt(damageStr);
	if (damage == 0)
		return Plugin_Continue;
	
	// Decide what to do:
	if (damage > 100)
	{
		ForcePlayerSuicide(other);
		return Plugin_Continue;
	}
	
	bool shouldDamage = view_as<bool>(GetRandomInt(0, 1));
	if (shouldDamage)
		SDKHooks_TakeDamage(other, 0, 0, view_as<float>(damage));
	else
	{
		float originalSpeed = GetEntPropFloat(other, Prop_Data, "m_flLaggedMovementValue");
		
		SetEntPropFloat(other, Prop_Data, "m_flLaggedMovementValue", 0.2);
		
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(other));
		pack.WriteFloat(originalSpeed);
		
		CreateTimer(float(damage / 2), Timer_LaserHit, pack, TIMER_FLAG_NO_MAPCHANGE);
		CPrintToChat(other, "%s A laser has hit you, you are being slowed down now!", THIS_MODE_INFO.tag);
	}
	
	return Plugin_Continue;
}

Action Timer_LaserHit(Handle timer, DataPack pack)
{
	if (g_bRoundEnd)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client || !IsPlayerAlive(client) || !ZR_IsClientHuman(client))
	{
		delete pack;
		return Plugin_Stop;
	}
	
	float originalSpeed = pack.ReadFloat();
	delete pack;
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", originalSpeed);
	return Plugin_Stop;
}
/****************************************************************/
/* Maybe move this to FunModes.sp? */
public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect)
{
	if (!THIS_MODE_INFO.isOn)
		return Plugin_Continue;
		
	if (!PLAYER_TEMP_VAR(client, infectionProtect))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

#undef THIS_MODE_DB
#undef CRAZYSHOP_DB_NAME
#undef PLAYER_CREDITS
#undef PLAYER_ITEM_COUNT
#undef PLAYER_ITEM_ACTIVE
#undef DAMAGE_DEALT
#undef PLAYER_IN_DB
#undef PLAYER_RESET