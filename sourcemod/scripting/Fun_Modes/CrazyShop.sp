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

#define CRAZYSHOP_CONVAR_DAMAGE				0
#define CRAZYSHOP_CONVAR_CREDITS			1
#define CRAZYSHOP_CONVAR_SAVECREDITS		2
#define CRAZYSHOP_CONVAR_SLOWBEACON_RADIUS	3
#define CRAZYSHOP_CONVAR_DISABLE_SHOP		4
#define CRAZYSHOP_CONVAR_TOGGLE 			5

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
		"More HP", 1, 5, 100.0, 0.0, DATATYPE_AMOUNT, "HP Amount to Add"
	},
	{
		"Infect Protection", 1, 10, 0.0, 15.0, DATATYPE_TIME, ""
	},
	{
		"Super Weapon", 1, 30, 2.5, 15.0, DATATYPE_BOTH, "Damage Scale"
	},
	{
		"Laser Protection", 1, 10, 0.0, 20.0, DATATYPE_TIME, ""
	},
	{
		"Unlimited Ammo", 1, 10, 0.0, 15.0, DATATYPE_TIME, ""
	},
	{
		"Buy a smokegrenade", 1, 10, 0.0, 0.0, DATATYPE_NONE, ""
	},
	{
		"Slow Beacon", 1, 30, 0.01, 15.0, DATATYPE_BOTH, "Speed Value (absolute)"
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
		"Hurting Machine", 0, 20, 20.0, 15.0, DATATYPE_BOTH, "Damage"
	},
	{
		"Ignite Immunity", 0, 10, 0.0, 20.0, DATATYPE_TIME, ""
	},
	{
		"Invisibility", 0, 30, 0.0, 15.0, DATATYPE_TIME, ""
	},
	{
		"Human Pull", 0, 30, 0.0, 15.0, DATATYPE_TIME, ""
	}
};

#define ITEMS_COUNT 14

enum struct CrazyShop_PlayerData
{
	int credits;
	int itemsCount[ITEMS_COUNT];
	int originalItemsCount[ITEMS_COUNT];
	bool isItemActive[ITEMS_COUNT];
	
	int dealtDamage;
	bool isInDB;
	
	/* Temp Vars, Basically the vars that the item activations use */
	bool infectionProtect;
	bool superWeapon;
	char superWeaponName[32];
	char originalWeapon[32];
	bool laserProtect;
	bool kbProtect;
	bool igniteImmunity;
	bool protectLaser;
	bool unlimitedAmmo;
	Handle slowBeaconTimer;
	float originalSpeed;
	bool gotSlowed;
	int grabbedTarget;
	float originalTargetMaxSpeed;
	float lastUse;
	
	void Reset(bool tempVarsOnly = false)
	{
		if (!tempVarsOnly)
		{
			this.credits = 0;
			this.dealtDamage = 0;
			this.isInDB = false;
			for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
			{
				this.itemsCount[i] = 0;
				this.originalItemsCount[i] = 0;
			}
		}
		
		this.infectionProtect = false;
		this.superWeapon = false;
		this.superWeaponName[0] = '\0';
		this.laserProtect = false;
		this.kbProtect = false;
		this.igniteImmunity = false;
		this.protectLaser = false;
		this.unlimitedAmmo = false;
		delete this.slowBeaconTimer;
		this.originalSpeed = 0.0;
		this.gotSlowed = false;
		this.grabbedTarget = -1;
		this.lastUse = 0.0;
	}
}

CrazyShop_PlayerData g_CrazyShopPlayerData[MAXPLAYERS + 1];

int g_iCrazyShopPreviousItem[MAXPLAYERS + 1];
int g_iCrazyShopProps;

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
#define PLAYER_RESET_TEMP_VARS(%1)	g_CrazyShopPlayerData[%1].Reset(true)
#define PLAYER_TEMP_VAR(%1,%2)		g_CrazyShopPlayerData[%1].%2
/***************************************************************/
#define PROP_MODEL              "models/props/cs_office/vending_machine.mdl"

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
		"sm_crazyshop_damage", "5000", "The needed damage for humans to be rewarded with credits",
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
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_SLOWBEACON_RADIUS,
		"sm_crazyshop_slowbeacon_radius", "400.0", "Slow Beacon Radius",
		("300.0,400.0,500.0,600.0,700.0"), "float"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_DISABLE_SHOP,
		"sm_crazyshop_disable_shop", "0", "Enable/Disable the !crazyshop command",
		("0,1"), "bool"
	);
	
	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, CRAZYSHOP_CONVAR_TOGGLE,
		"sm_crazyshop_enable", "1", "Enable/Disable CrazyShop Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);
	
	THIS_MODE_INFO.enableIndex = CRAZYSHOP_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;
	
	THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_TOGGLE].cvar.AddChangeHook(OnCrazyShopModeToggle);
}

void OnCrazyShopModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_CrazyShop()
{
	PrecacheModel(PROP_MODEL);
}

stock void OnMapEnd_CrazyShop()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	
	g_iCrazyShopProps = 0;
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
	for (int i = 1; i <= MaxClients; i++)
	{
		if (PLAYER_TEMP_VAR(i, grabbedTarget) == client)
			PLAYER_TEMP_VAR(i, grabbedTarget) = -1;
	}
	
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

stock void Event_RoundStart_CrazyShop()
{
	g_iCrazyShopProps = 0;
	
	for (int i = 1; i <= MaxClients; i++)
		PLAYER_RESET_TEMP_VARS(i);
}

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

// CrazyShop is the only mode that hooks this event, so it's fine
stock void Event_WeaponFire_CrazyShop(Event event, const char[] name, bool dontBroadcast)
{
	if (!THIS_MODE_INFO.isOn)
		return;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!PLAYER_TEMP_VAR(client, superWeapon) && !PLAYER_TEMP_VAR(client, unlimitedAmmo))
		return;
		
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
		return;
	
	if (weapon != GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) && weapon != GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY))
		return;
	
	int clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (GetEntProp(weapon, Prop_Send, "m_iState", 4, 0) != 2 || !clip1)
		return;
		
	int toAdd = 1;
	char weaponClassname[32];
	GetEntityClassname(weapon, weaponClassname, sizeof(weaponClassname));
	
	if (strcmp(weaponClassname, "weapon_glock") == 0 || strcmp(weaponClassname, "weapon_famas") == 0)
	{
		if (GetEntProp(weapon, Prop_Send, "m_bBurstMode"))
			toAdd = clip1;
	}
	
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip1 + toAdd);
}

stock void OnTakeDamagePost_CrazyShop(int victim, int attacker, float damage)
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!(1<=attacker<=MaxClients) || !IsPlayerAlive(victim) || !IsPlayerAlive(attacker) || !ZR_IsClientZombie(victim) || !ZR_IsClientHuman(attacker))
		return;
		
	if (PLAYER_TEMP_VAR(attacker, superWeapon))
		return;
		
	DAMAGE_DEALT(attacker) += RoundToNearest(damage);
	
	if (DAMAGE_DEALT(attacker) >= THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_DAMAGE].cvar.IntValue)
	{
		int credits = THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_CREDITS].cvar.IntValue;
		if (credits <= 0)
			return;
			
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
	
	bool isVictimAlive = IsPlayerAlive(victim);
	bool isAttackerAlive = (1 <= attacker <= MaxClients) && IsPlayerAlive(attacker);
	
	bool isVictimZombie = ZR_IsClientZombie(victim);
	bool isAttackerZombie = (1 <= attacker <= MaxClients) && ZR_IsClientZombie(attacker);
	
	// victim is for sure gonna be a real player, so no need to check
	
	// check if victim is a human and has laser protect
	if (PLAYER_TEMP_VAR(victim, laserProtect) && !isVictimAlive && !isVictimZombie)
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
	
	// check if victim is a zombie and attacker is human for ignite immunity and kb protection
	if ((PLAYER_TEMP_VAR(victim, igniteImmunity) || PLAYER_TEMP_VAR(victim, kbProtect)) && isVictimAlive && isVictimZombie)
	{
		if (isAttackerZombie)
			return;
		
		if (PLAYER_TEMP_VAR(victim, kbProtect))
		{
			damage -= damage * 0.9;
			result = Plugin_Changed;
			return;
		}
		
		RequestFrame(CrazyShop_CheckIgnite, GetClientUserId(victim));
	}
	
	if (isAttackerAlive && !isAttackerZombie && PLAYER_TEMP_VAR(attacker, superWeapon))
	{
		if (!isVictimAlive || !isVictimZombie)
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

void CrazyShop_CheckIgnite(int userid)
{
	int victim = GetClientOfUserId(userid);
	if (!victim)
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

stock void OnPlayerRunCmdPost_CrazyShop(int client, int buttons, int impulse)
{
	#pragma unused buttons
	
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if (!IsPlayerAlive(client))
		return;
		
	float currentTime = GetGameTime();
	if (currentTime <= PLAYER_TEMP_VAR(client, lastUse))
		return;
		
	// https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/server/player.cpp#L6073
	if (impulse == 100)
	{	
		PLAYER_TEMP_VAR(client, lastUse) = currentTime + 2;
		CrazyShop_OpenAvailableItems(client);	
	}
}

/* TODO: Handle this in FunModes.sp */
/* This should be in FunModes.sp, but crazyshop is the only mode that's using it for now */
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
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
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
		
		if (THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_SAVECREDITS].cvar.BoolValue && THIS_MODE_DB == null)
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
		
		// Restart the round
		CS_TerminateRound(2.0, CSRoundEnd_Draw);
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
		
		for (int i = item.price, count; i <= item.price * 2; i += item.price / 4)
		{
			if (count <= 1)
				i = item.price - item.price / 4;
			
			count++;
			
			if (i <= 0)
			{
				i += 2*(item.price / 4);
				count--;
				continue;
			}
			
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
		
		for (float f = item.time, count; f <= item.time * 2.0; f += item.time / 4.0)
		{
			if (count <= 1.0)
				f = item.time - (item.time / 4.0);
				
			count++;
			
			if (f <= 0.0)
			{
				f += 2*(item.time / 4.0);
				count--;
				continue;
			}
			
			char thisVal[6];
			FloatToString(f, thisVal, sizeof(thisVal));
			
			char data[sizeof(thisVal) + 2];
			FormatEx(data, sizeof(data), "2|%s", thisVal);
			
			menu.AddItem(data, thisVal);
		}
	}
	
	if (action == 1)
	{
		if (item.type == DATATYPE_TIME)
		{
			menu.SetTitle("[CrazyShop] %s - Time\nCurrent Time: %.2f", item.name, item.time);
			
			for (float f = item.time, count; f <= item.time * 2.0; f += item.time / 4.0)
			{
				if (count <= 1.0)
					f = item.time - (item.time / 4.0);
				
				count++;
				
				if (f <= 0.0)
				{
					f += 2*(item.time / 4.0);
					count--;
					continue;
				}
				
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
			
			for (float f = item.amount, count; f <= item.amount * 2; f += item.amount / 4.0)
			{
				if (count <= 1.0)
					f = item.amount - (item.amount / 4.0);
					
				if (f <= 0.0)
				{
					f += 2*(item.amount / 4.0);
					count--;
					continue;
				}
				
				count++;
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
				case 0: CrazyShop_UpdateItemData(param1, g_iCrazyShopPreviousItem[param1], "price", data[1]);
				case 1: CrazyShop_UpdateItemData(param1, g_iCrazyShopPreviousItem[param1], "amount", data[1]);
				case 2: CrazyShop_UpdateItemData(param1, g_iCrazyShopPreviousItem[param1], "time", data[1]);
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
	
	if (THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_DISABLE_SHOP].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s The shop is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	
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
			if (!THIS_MODE_INFO.isOn)
				return -1;
			
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
			CPrintToChat(param1, "{lightgreen}You can also press the {olive}FlashLight {lightgreen}button to see your inventory!");
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
			if (!THIS_MODE_INFO.isOn)
				return -1;
				
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
	if (!g_bMotherZombie || g_bRoundEnd)
		return;
	
	bool found = false;
	
	Menu menu;
	
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s you have to be alive to use this command!", THIS_MODE_INFO.tag);
		return;
	}
	
	for (int i = 0; i < sizeof(CrazyShop_PlayerData::itemsCount); i++)
	{
		if (((g_CrazyShopItems[i].team == 0 && ZR_IsClientZombie(client)) || 
			(g_CrazyShopItems[i].team == 1 && ZR_IsClientHuman(client))) && PLAYER_ITEM_COUNT(client, i))
		{
			found = true;
			
			if (menu == null)
			{
				menu = new Menu(Menu_AvailableItems);
				menu.SetTitle("[CrazyShop] Your Available Items!");
			}
		
			if (menu)
			{
				char item[64];
				FormatEx(item, sizeof(item), "%s - Activate", g_CrazyShopItems[i].name);
				
				char data[3];
				IntToString(i, data, sizeof(data));
				menu.AddItem(data, item);
			}
		}
	}
	
	if (!found)
	{
		CPrintToChat(client, "%s You have no available items!", THIS_MODE_INFO.tag);
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
			if (!THIS_MODE_INFO.isOn)
				return -1;
				
			char data[3];
			menu.GetItem(param2, data, sizeof(data));
			
			int itemNum = StringToInt(data);
			
			if (PLAYER_ITEM_COUNT(param1, itemNum) <= 0)
			{
				CPrintToChat(param1, "%s You do not have this item in your inventory", THIS_MODE_INFO.tag);
				return 0;
			}
			
			if (!IsPlayerAlive(param1))
			{
				CPrintToChat(param1, "%s You have to be alive to activate items!", THIS_MODE_INFO.tag);
				return -1;
			}
			
			CrazyShop_Item item;
			item = g_CrazyShopItems[itemNum];
			bool isZombie = ZR_IsClientZombie(param1);
			if (item.team == 0 && !isZombie)
			{
				CPrintToChat(param1, "%s This item is for zombies only!", THIS_MODE_INFO.tag);
				return -1;
			}
		
			if (item.team == 1 && isZombie)
			{	
				CPrintToChat(param1, "%s This item is for humans only!", THIS_MODE_INFO.tag);
				return -1;
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
			
			int health = RoundToNearest(item.amount);
			SetEntityHealth(client, GetClientHealth(client) + health);
			
			CPrintToChat(client, "%s You have given yourself {olive}%d {lightgreen}more HP", THIS_MODE_INFO.tag, health);
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
			
			int wp = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			if (IsValidEntity(wp))
				GetEntityClassname(wp, PLAYER_TEMP_VAR(client, originalWeapon), sizeof(CrazyShop_PlayerData::originalWeapon));
				
			if (strcmp(PLAYER_TEMP_VAR(client, originalWeapon), PLAYER_TEMP_VAR(client, superWeaponName)) == 0)
				PLAYER_TEMP_VAR(client, originalWeapon)[0] = '\0';
			else
			{
			#if defined _FM_GunGame
				GunGame_EquipWeapon(client, PLAYER_TEMP_VAR(client, superWeaponName), true);
			#endif
			}
			
			FunModes_HookEvent(g_bEvent_WeaponFire, "weapon_fire", Event_WeaponFire_CrazyShop);
			
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, superWeapon) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_SuperWeapon, pack, TIMER_FLAG_NO_MAPCHANGE);
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
		
		// Unlimited Ammo - Humans
		case 4:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			PLAYER_TEMP_VAR(client, unlimitedAmmo) = true;
			
			FunModes_HookEvent(g_bEvent_WeaponFire, "weapon_fire", Event_WeaponFire_CrazyShop);
			
			DataPack pack = new DataPack();
			
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_UnlimitedAmmo, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You have activated unlimited Ammo, Go Hunt the Zombies!", THIS_MODE_INFO.tag);
		}
		
		// Buy a smokegrenade
		case 5:
		{
			GiveGrenadesToClient(client, GrenadeType_Smokegrenade, 1);
			
			int wp = GivePlayerItem(client, "weapon_smokegrenade");
			EquipPlayerWeapon(client, wp);
			
			CPrintToChat(client, "%s You have given yourself a smokegrenade! {olive}Freeze the zombies now!", THIS_MODE_INFO.tag);
		}
		
		// Slow Beacon
		case 6:
		{
			int userid = GetClientUserId(client);
			
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			delete PLAYER_TEMP_VAR(client, slowBeaconTimer);
			PLAYER_TEMP_VAR(client, slowBeaconTimer) = CreateTimer(0.1, Timer_SlowBeaconRepeat, userid, TIMER_REPEAT);
			
			CreateTimer(item.time, Timer_CrazyShop_SlowBeacon, userid, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You have activated slow beacon, you can slow down the zombies if they got close to your beacon!", THIS_MODE_INFO.tag);
		}
		
		// More Speed - Zombies
		case 7:
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
		case 8:
		{
			PLAYER_TEMP_VAR(client, kbProtect) = true;
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_KBProtection, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You have activated KB protection, your knockback will be much less now!", THIS_MODE_INFO.tag);
		}
		
		// Lower Gravity - Zombies
		case 9:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			SetEntityGravity(client, 1.0 + item.amount);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_LowerGravity, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You have been given lower gravity, use it wisely!", THIS_MODE_INFO.tag);
		}
		
		// Hurting Machine - Zombies
		case 10:
		{
			if (g_iCrazyShopProps >= 2)
			{
				CPrintToChat(client, "%s Please wait until the older hurting machines die!", THIS_MODE_INFO.tag);
				return;
			}
			
			int userid = GetClientOfUserId(client);
			char propName[64];
			FormatEx(propName, sizeof(propName), "%d_FM_PROP_%d_%d", RoundToNearest(item.amount), userid, GetGameTime());

			int prop = CrazyShop_CreateProp(propName);
			if (prop == -1)
			{
				CPrintToChat(client, "%s Failed to activate this item, try again later", THIS_MODE_INFO.tag);
				return;
			}
			
			CrazyShop_ThrowProp(client, prop);
			
			DataPack pack = new DataPack();
			pack.WriteCell(userid);
			pack.WriteCell(EntIndexToEntRef(prop));
			
			CreateTimer(item.time, Timer_CrazyShop_HurtingMachine, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// Ignite Immunity - Zombies
		case 11:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			PLAYER_TEMP_VAR(client, igniteImmunity) = true;
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_IgniteImmunity, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You have activated ignite immunity, you won't be on fire for now!", THIS_MODE_INFO.tag);
		}
		
		// Invisibility - Zombies
		case 12:
		{
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			int nodraw = 0x20;
			
			SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") | nodraw);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_Invisibility, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You are invisibile now, shhh!", THIS_MODE_INFO.tag);
		}
		
		// Human Pull - Zombies
		case 13:
		{
			int target = GetClientAimTarget(client);
			if (target == -1 || !IsPlayerAlive(target) || !ZR_IsClientHuman(target))
			{
				CPrintToChat(client, "%s Canceling the activation of this item, please aim at a human!", THIS_MODE_INFO.tag);
				return;
			}
			
			PLAYER_ITEM_ACTIVE(client, itemNum) = true;
			
			CrazyShop_StartGrab(client, target);
			
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(client));
			pack.WriteCell(itemNum);
			
			CreateTimer(item.time, Timer_CrazyShop_Pull, pack, TIMER_FLAG_NO_MAPCHANGE);
			
			CPrintToChat(client, "%s You are now pulling a human xD", THIS_MODE_INFO.tag);
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
	
	if (!THIS_MODE_INFO.isOn || g_bRoundEnd)
		return Plugin_Stop;
	
	if (IsPlayerAlive(client) && ZR_IsClientHuman(client) && PLAYER_TEMP_VAR(client, originalWeapon)[0])
	{
	#if defined _FM_GunGame
		GunGame_EquipWeapon(client, PLAYER_TEMP_VAR(client, originalWeapon), true);
	#endif
			
		PLAYER_TEMP_VAR(client, originalWeapon)[0] = '\0';
	}

	return Plugin_Stop;
}

Action Timer_CrazyShop_LaserProtection(Handle timer, DataPack pack)
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
	
	PLAYER_TEMP_VAR(client, laserProtect) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_UnlimitedAmmo(Handle timer, DataPack pack)
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
	PLAYER_TEMP_VAR(client, unlimitedAmmo) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_CrazyShop_SlowBeacon(Handle timer, int userid)
{	
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		CrazyShop_ResetSpeed();
		return Plugin_Stop;
	}
	
	PLAYER_TEMP_VAR(client, slowBeaconTimer) = null;
	PLAYER_ITEM_ACTIVE(client, 6) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

Action Timer_SlowBeaconRepeat(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
	{
		CrazyShop_ResetSpeed();
		return Plugin_Stop;
	}
	
	int itemNum = 6;
	
	if (!THIS_MODE_INFO.isOn || g_bRoundEnd)
	{
		PLAYER_ITEM_ACTIVE(client, itemNum) = false;
		CrazyShop_ResetSpeed();
		PLAYER_TEMP_VAR(client, slowBeaconTimer) = null;
		return Plugin_Stop;
	}
	
	if (!IsPlayerAlive(client) || ZR_IsClientZombie(client))
	{
		PLAYER_ITEM_ACTIVE(client, itemNum) = false;
		CrazyShop_ResetSpeed();
		PLAYER_TEMP_VAR(client, slowBeaconTimer) = null;
		return Plugin_Stop;
	}
	
	if (!PLAYER_ITEM_ACTIVE(client, itemNum))
	{
		CrazyShop_ResetSpeed();
		PLAYER_TEMP_VAR(client, slowBeaconTimer) = null;
		return Plugin_Stop;
	}
	
	float beaconRadius = THIS_MODE_INFO.cvarInfo[CRAZYSHOP_CONVAR_SLOWBEACON_RADIUS].cvar.FloatValue;
	BeaconPlayer(client, 0, beaconRadius, { 255, 255, 255, 255 } );
	
	// check for distance
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || !ZR_IsClientZombie(i))
			continue;
		
		float squarredDistance = GetDistanceBetween(client, i, true);
		if (!PLAYER_TEMP_VAR(i, gotSlowed) && squarredDistance <= ((beaconRadius/2.0)*(beaconRadius/2.0)))
		{
			PLAYER_TEMP_VAR(i, gotSlowed) = true;
			PLAYER_TEMP_VAR(i, originalSpeed) = GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue");
			SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", g_CrazyShopItems[itemNum].amount);
		}
		else
		{
			if (PLAYER_TEMP_VAR(i, gotSlowed) && PLAYER_TEMP_VAR(i, originalSpeed) > 0.0)
			{
				// More Speed - 4
				if (PLAYER_ITEM_ACTIVE(i, 4))
					continue;
					
				PLAYER_TEMP_VAR(i, gotSlowed) = false;
				SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", PLAYER_TEMP_VAR(i, originalSpeed));
			}
		}
	}
	
	return Plugin_Continue;
}

void CrazyShop_ResetSpeed()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (PLAYER_TEMP_VAR(i, gotSlowed) && PLAYER_TEMP_VAR(i, originalSpeed) > 0.0)
		{
			// More Speed - 4
			if (PLAYER_ITEM_ACTIVE(i, 4))
				continue;
				
			PLAYER_TEMP_VAR(i, gotSlowed) = false;
			SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", PLAYER_TEMP_VAR(i, originalSpeed));
		}
	}
}

Action Timer_CrazyShop_MoreSpeed(Handle timer, DataPack pack)
{	
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}
	
	int itemNum = pack.ReadCell();
	float speed = pack.ReadFloat();
	
	PLAYER_ITEM_ACTIVE(client, itemNum) = false;
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	
	delete pack;
	
	if (!THIS_MODE_INFO.isOn || g_bRoundEnd)
		return Plugin_Stop;
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
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
	
	PLAYER_TEMP_VAR(client, kbProtect) = false;
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

Action Timer_CrazyShop_Pull(Handle timer, DataPack pack)
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
	int target = PLAYER_TEMP_VAR(client, grabbedTarget);
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	
	if (target == -1)
		return Plugin_Stop;
	
	PLAYER_TEMP_VAR(client, grabbedTarget) = -1;
	
	PLAYER_ITEM_ACTIVE(target, 1) = false;
	PLAYER_TEMP_VAR(target, infectionProtect) = false;
			
	SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", PLAYER_TEMP_VAR(client, originalTargetMaxSpeed));
	
	return Plugin_Stop;
}

void CrazyShop_StartGrab(int client, int target)
{
	PLAYER_ITEM_ACTIVE(target, 1) = true;
	PLAYER_TEMP_VAR(target, infectionProtect) = true;
	
	PLAYER_TEMP_VAR(client, grabbedTarget) = target;
	
	PLAYER_TEMP_VAR(client, originalTargetMaxSpeed) = GetEntPropFloat(target, Prop_Send, "m_flMaxspeed");
	SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", 0.01);
	
	CreateTimer(0.05, CrazyShop_Timer_Grabbing, client, TIMER_REPEAT);
}

Action CrazyShop_Timer_Grabbing(Handle timer, int client)
{
	int itemNum = 13;
	if (!PLAYER_ITEM_ACTIVE(client, itemNum))
		return Plugin_Stop;
	
	int target = PLAYER_TEMP_VAR(client, grabbedTarget);
	if (target == -1 || !IsPlayerAlive(target) || !ZR_IsClientHuman(target) || !IsPlayerAlive(client) || ZR_IsClientHuman(client))
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
		ScaleVector(velocity, 300.0);
		TeleportEntity(target, _, _, velocity);
	}
	
	TE_SetupBeamPoints(clientEyePos, targetEyePos, g_iLaserBeam, 0, 0, 66, 0.2, 1.0, 10.0, 0, 0.0, {255,255,255,255}, 0);
	TE_SendToAll();
	
	return Plugin_Continue;
}

stock bool TraceRayTryToHit(int entity, int mask)
{
	#pragma unused mask
	if (entity > 0 && entity <= MaxClients)
		return false;
		
	return true;
}

/*******************************************************************/
Action Timer_CrazyShop_HurtingMachine(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	int prop = EntRefToEntIndex(pack.ReadCell());
	
	delete pack;
	
	g_iCrazyShopProps--;
	
	if (prop == INVALID_ENT_REFERENCE)
		return Plugin_Stop;
	
	RemoveEntity(prop);
	
	if (!client)
		return Plugin_Stop;
		
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	return Plugin_Stop;
}

void CrazyShop_ThrowProp(int client, int prop)
{
	float vecEyeAngles[3];
	float vecEyePos[3];
	
	GetClientEyeAngles(client, vecEyeAngles);
	GetClientEyePosition(client, vecEyePos);
	
	float vecForward[3];
	GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	ScaleVector(vecForward, 100.0);
	
	float spawnOrigin[3];
	AddVectors(vecEyePos, vecForward, spawnOrigin);

	TeleportEntity(prop, spawnOrigin, vecEyeAngles, vecEyeAngles);
	
	DispatchSpawn(prop);
	
	g_iCrazyShopProps++;
}

stock int CrazyShop_CreateProp(const char[] name)
{
	int ent = CreateEntityByName("prop_physics_override"); 
	if (ent == -1)
		return -1;
	
	DispatchKeyValue(ent, "targetname", name);
	DispatchKeyValue(ent, "solid", "0");
	DispatchKeyValue(ent, "model", PROP_MODEL);
	DispatchKeyValue(ent, "disableshadows", "1");
	DispatchKeyValue(ent, "disablereceiveshadows", "1");
	
	SDKHook(ent, SDKHook_SpawnPost, Prop_Spawn);
	
	return ent;
}

void Prop_Spawn(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, Hook_PropHit);
	SDKHook(entity, SDKHook_OnTakeDamage, Hook_PropDamage);
}

public Action Hook_PropDamage(int entity, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	return Plugin_Handled;
}

Action Hook_PropHit(int entity, int other)
{	
	if (!(1<=other<=MaxClients))
		return Plugin_Continue;
	
	if (!IsPlayerAlive(other) || ZR_IsClientZombie(other))
		return Plugin_Continue;
		
	if (PLAYER_TEMP_VAR(other, protectLaser))
		return Plugin_Continue;
	
	char name[64];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	
	char vals[5][10];
	ExplodeString(name, "_", vals, sizeof(vals), sizeof(vals[]));
	
	int damage = StringToInt(vals[0]);
	if (damage == 0)
		return Plugin_Continue;
	
	// Decide what to do:
	if (damage > 100)
	{
		ForcePlayerSuicide(other);
		return Plugin_Continue;
	}
	
	SDKHooks_TakeDamage(other, 0, 0, float(damage));
	
	return Plugin_Continue;
}

/****************************************************************/
/* TODO: Maybe move this to FunModes.sp? */
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