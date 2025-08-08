#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <adt_array>

#undef REQUIRE_PLUGIN
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#pragma newdecls required

/* COLORS VARIABLES */
int g_ColorCyan[4] =  {0, 255, 255, 255}; // cyan
int g_ColorDefault[4] = {255, 215, 55, 255}; // default color

int g_iClientMenuUserId[MAXPLAYERS + 1] = { -1, ... };

int g_LaserSprite = -1;
int g_HaloSprite = -1;

bool g_bIsVIPModeOn;
bool g_bIsHealBeaconOn;
bool g_bIsBetterDamageModeOn;
bool g_bIsRLGLEnabled;
bool g_bRoundEnd;
bool g_bEnableDetecting;
bool g_bIsDoubleJumpOn;
bool g_bPlugin_DynamicChannels = false;

#define HealBeacon_Tag "{gold}[FunModes-HealBeacon]{lightgreen}"
#define BeaconMode_HealBeacon 0

#define VIPMode_Tag "{gold}[FunModes-VIPMode]{lightgreen}"
#define BeaconMode_VIP 1

#define Fog_Tag "{gold}[FunModes-FOG]{lightgreen}"
#define FOGInput_Color 0
#define FOGInput_Start 1
#define FOGInput_End 2
#define FOGInput_Toggle 3

#define RLGL_Tag "{gold}[FunModes-RedLightGreenLight]{lightgreen}"

#define DoubleJump_Tag "{gold}[FunModes-DoubleJump]{lightgreen}"

#define IC_TAG "{gold}[FunModes-InvertedControls]{lightgreen}"

#define Beacon_Sound        "buttons/blip1.wav"

/* Arraylist to save client indexes of the heal beaconed players */
ArrayList g_aHBPlayers;

/* HUD HANDLER AND TIMERS HANDLERS */
Handle g_hHudMsg = null;

Handle g_hRoundStart_Timer[2] = { null, ... };
Handle g_hDamageTimer = null;
Handle g_hHealTimer = null;
Handle g_hBeaconTimer[MAXPLAYERS + 1] = { null, ... };

/* NORMAL VARIABLES */
int g_iCounter = 0;

/* HEALBEACON CONVARS */
ConVar g_cvHealBeaconTimer = null;
ConVar g_cvAlertTimer = null;
ConVar g_cvHealBeaconDamage = null;
ConVar g_cvHealBeaconHeal = null;
ConVar g_cvRandoms = null;
ConVar g_cvDefaultDistance = null;

enum struct BeaconPlayers
{
	bool hasHealBeacon;
	bool hasNeon;
	int color[4];
	float distance;
	int neonEntity;
	
	void SetColor(int setColor[4])
	{
		this.color[0] = setColor[0];
		this.color[1] = setColor[1];
		this.color[2] = setColor[2];
		this.color[3] = setColor[3];
	}
	
	void ResetColor()
	{
		this.color[0] = g_ColorDefault[0];
		this.color[1] = g_ColorDefault[1];
		this.color[2] = g_ColorDefault[2];
		this.color[3] = g_ColorDefault[3];
	}
	
	void ResetValues()
	{
		this.hasHealBeacon = false;
		this.ResetColor();
		this.distance = g_cvDefaultDistance.FloatValue;
		this.neonEntity = -1;
	}
}

BeaconPlayers g_BeaconPlayersData[MAXPLAYERS + 1];

enum struct fogData
{
	bool fogEnable;
	float fogStart;
	float fogEnd;
	int fogColor[4];
	
	void SetColor(int setColor[4])
	{
		this.fogColor[0] = setColor[0];
		this.fogColor[1] = setColor[1];
		this.fogColor[2] = setColor[2];
		this.fogColor[3] = setColor[3];
	}
}


/* FOR CONVAR LIST PURPOSE */
enum struct ConVarInfo
{
	ConVar cvar;
	char values[32];
	char type[10];
}

fogData g_FogData;

int g_iFogEntity = -1;

char colorsList[][] =
{
	"255 255 255 255 White",
	"255 0 0 255 Red", 
	"0 255 0 255 Lime", 
	"0 0 255 255 Blue", 
	"255 255 0 255 Yellow", 
	"0 255 255 255 Cyan", 
	"255 215 0 255 Gold"
};

/* GLOBAL CONVARS */
ConVar g_cvHUDChannel;

/* VIP MODE CONVARS */
ConVar g_cvVIPModeCount;
ConVar g_cvVIPModeLaser;
ConVar g_cvVIPModeTimer;
ConVar g_cvVIPMax;

/* RLGL CONVARS */
ConVar g_cvRLGLDetectTimer;
ConVar g_cvRLGLFinishDetectTime;
ConVar g_cvRLGLDetectTimerRepeatMin;
ConVar g_cvRLGLDetectTimerRepeatMax;
ConVar g_cvRLGLDamage;
ConVar g_cvRLGLWarningTime;
ConVar g_cvCountdownFolder;
ConVar g_cvRLGLZombiesSpeed;

/* DOUBLE JUMP CONVARS */
ConVar g_cvDoubleJumpBoost;
ConVar g_cvDoubleJumpMaxJumps;
ConVar g_cvDoubleJumpHumansEnable;
ConVar g_cvDoubleJumpZombiesEnable;

enum ConVarType
{
	CONVAR_TYPE_HEALBEACON = 0,
	CONVAR_TYPE_VIPMode = 1,
	CONVAR_TYPE_RLGL = 2,
	CONVAR_TYPE_DOUBLEJUMP = 3
};

ConVarType g_iCurrentConVarType;

/* TIMERS */
Handle g_hKillAllTimer = null;
Handle g_hVIPRoundStartTimer = null;
Handle g_hVIPBeaconTimer[MAXPLAYERS + 1] = { null, ... };
Handle g_hRLGLTimer = null;
Handle g_hRLGLDetectTimer;
Handle g_hRLGLWarningTime;

bool g_bIsVIP[MAXPLAYERS + 1];

/* Event Hooks Booleans */
bool g_bEvent_RoundStart;
bool g_bEvent_RoundEnd;
bool g_bEvent_PlayerDeath;
bool g_bEvent_PlayerTeam;
bool g_bEvent_PlayerSpawn;

/* CUSTOM SP INCLUDE FILES */
#include "Fun_Modes/HealBeacon.sp"
#include "Fun_Modes/HealBeacon_Menus.sp"
#include "Fun_Modes/VIPMode.sp"
#include "Fun_Modes/Fog.sp"
#include "Fun_Modes/RedLightGreenLight.sp"
#include "Fun_Modes/DoubleJump.sp"
#include "Fun_Modes/InvertedControls.sp"

public Plugin myinfo =
{
	name = "FunModes",
	author = "Dolly",
	description = "bunch of fun modes for ze mode",
	version = "1.4.7",
	url = "https://nide.gg"
}

public void OnPluginStart()
{
	/* TRANSLATIONS LAODS */
	LoadTranslations("common.phrases");
	LoadTranslations("FunModes.phrases");
	
	/* HUD HANDLE */
	g_hHudMsg = CreateHudSynchronizer();

	g_cvHUDChannel = CreateConVar("sm_funmodes_hud_channel", "4", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);
	
	PluginStart_HealBeacon();
	PluginStart_VIPMode();
	PluginStart_Fog();
	PluginStart_RLGL();
	PluginStart_DoubleJump();
	PluginStart_IC();
	
	AutoExecConfig();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			OnClientPutInServer(i);
	}
	
	static const char commands[][] = { "sm_fm_cvars", "sm_funmodes", "sm_funmode" };
	for(int i = 0; i < sizeof(commands); i++)
	{
		RegAdminCmd(commands[i], Cmd_Cvars, ADMFLAG_CONVARS, "Shows All fun modes cvars");
	}
}

/* Events Hooks functions */
void FunModes_HookEvent(bool &modeBool, const char[] name, EventHook callback) {
	if(!modeBool) {
		modeBool = true;
		HookEvent(name, callback);
	}
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

public void OnMapStart()
{
	g_LaserSprite = PrecacheModel("sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");

	PrecacheSound(Beacon_Sound, true);

	g_FogData.fogStart 	= 50.0;
	g_FogData.fogEnd 	= 250.0;
	g_FogData.fogEnable = false;

	g_bIsVIPModeOn 			= false;
	g_bIsHealBeaconOn 		= false;
	g_bIsRLGLEnabled 		= false;
	g_bIsDoubleJumpOn 		= false;
	g_bIsBetterDamageModeOn = false;
	g_bEnableDetecting 		= false;

	/* DELETE HEALBEACON ARRAYLIST */
	delete g_aHBPlayers;
	
	MapStart_RLGL();
}

public void OnMapEnd()
{
	g_hRLGLTimer = null;
	g_hRLGLDetectTimer = null;
	g_hRLGLWarningTime = null;
}

public void OnClientPutInServer(int client)
{
	if(!g_bIsVIPModeOn || IsFakeClient(client) || IsClientSourceTV(client))
		return;

	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
} 

/*
*** EVENTS HOOKS CALLBACKS ***
*/

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	RequestFrame(RoundStart_Frame);
}

void RoundStart_Frame()
{
	RoundStart_HealBeacon();
	RoundStart_Fog();
	RoundStart_VIPMode();
	RoundStart_RLGL();
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");

	PlayerDeath_HealBeacon(userid);
	PlayerDeath_VIPMode(userid);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int team = event.GetInt("team");

	PlayerTeam_HealBeacon(userid, team);
	PlayerTeam_VIPMode(userid, team);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_FogData.fogEnable)
		return;

	int userid = event.GetInt("userid");

	PlayerSpawn_Fog(userid);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = true;
}

public void OnClientDisconnect(int client)
{
	ClientDisconnect_HealBeacon(client);
	ClientDisconnect_VIPMode(client);
}

float GetDistanceBetween(int origin, int target)
{
	float fOrigin[3], fTarget[3];

	GetEntPropVector(origin, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", fTarget);

	return GetVectorDistance(fOrigin, fTarget);
}

bool IsValidClient(int client)
{
	return (1 <= client && client <= MaxClients && IsClientInGame(client) && !IsClientSourceTV(client));
}

stock void BeaconPlayer(int client, int mode)
{
	float fvec[3];
	GetClientAbsOrigin(client, fvec);
	fvec[2] += 10;

	if(mode == BeaconMode_HealBeacon)
	{
		TE_SetupBeamRingPoint(fvec, (g_BeaconPlayersData[client].distance - 10.0), g_BeaconPlayersData[client].distance, g_LaserSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 0.0, g_BeaconPlayersData[client].color, 10, 0);
		TE_SendToAll();
	}
	else if(mode == BeaconMode_VIP)
	{
		TE_SetupBeamRingPoint(fvec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, g_ColorCyan, 10, 0);
		TE_SendToAll();

		int rainbowColor[4];
		float i = GetGameTime();
		float Frequency = 2.5;
		rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
		rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
		rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
		rainbowColor[3] = 255;

		TE_SetupBeamRingPoint(fvec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

		TE_SendToAll();
		EmitAmbientSound(Beacon_Sound, fvec, client, SNDLEVEL_RAIDSIREN);
	}

	GetClientEyePosition(client, fvec);
}

Action Cmd_Cvars(int client, int args)
{
	if(!client)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_MainCvars);
	menu.SetTitle("[FunModes] FunModes Cvars List!");

	menu.AddItem("0", "- HealBeacon Cvars");
	menu.AddItem("1", "- VIP Mode Cvars");
	menu.AddItem("2", "- RedLightGreenLight Cvars");
	menu.AddItem("3", "- DoubleJump Cvars");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

 int Menu_MainCvars(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			ConVarType type;
			switch(param2)
			{
				case 0:
				{
					type = CONVAR_TYPE_HEALBEACON;
				}
				case 1:
				{
					type = CONVAR_TYPE_VIPMode;
				}
				case 2:
				{
					type = CONVAR_TYPE_RLGL;
				}
				case 3:
				{
					type = CONVAR_TYPE_DOUBLEJUMP;
				}
			}
			
			DisplayConVarsListMenu(param1, type);
		}
	}
	
	return 0;
}

void DisplayConVarsListMenu(int client, ConVarType type)
{
	Menu menu = new Menu(Menu_DisplayConVars);

	char title[64];
	GetTypeTitle(type, title, sizeof(title));
	menu.SetTitle(title);

	GetTypeConVarsList(menu, type);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_DisplayConVars(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				Cmd_Cvars(param1, 0);
		}
		
		case MenuAction_Select:
		{
			char data[8];
			menu.GetItem(param2, data, sizeof(data));
			
			char dataEx[2][5];
			ExplodeString(data, "|", dataEx, 2, 5);
			
			ConVarType type = view_as<ConVarType>(StringToInt(dataEx[0]));
			int index = StringToInt(dataEx[1]);
					
			int len = GetConVarInfoSize(type);
			ConVarInfo[] info = new ConVarInfo[len];
			CopyStructArray(type, info, len);
			
			ShowConVarInfo(param1, info[index], type);
		}
	}

	return 0;
}

void ShowConVarInfo(int client, ConVarInfo info, ConVarType type)
{
	g_iCurrentConVarType = type;
	Menu menu = new Menu(Menu_ShowConVarInfo);
	
	char convarName[32];
	info.cvar.GetName(convarName, sizeof(convarName));
	
	char convarDescription[98];
	info.cvar.GetDescription(convarDescription, sizeof(convarDescription));
	
	char title[sizeof(convarName) + sizeof(convarDescription) + 2];
	FormatEx(title, sizeof(title), "%s\n%s", convarName, convarDescription);
	menu.SetTitle(title);
	
	int valsCount;
	for (int i = 0; i < sizeof(info.values); i++)
	{
		if(info.values[i] == ',')
			valsCount++;
	}
	
	valsCount++;
	
	char[][] dataEx = new char[valsCount][8];
	ExplodeString(info.values, ",", dataEx, valsCount, 8);
	
	any currentVal = GetValFromCvar(info.cvar, info.type);

	bool currentValExists = false;
	for (int i = 0; i < valsCount; i++)
	{
		any val = GetValFromCvar(null, info.type, dataEx[i]);
		if(val == currentVal) {
			currentValExists = true;
		}
		
		char data[100];
		FormatEx(data, sizeof(data), "%d|%s|%s|%s", view_as<int>(info.cvar), dataEx[i], info.type, info.values);
		
		menu.AddItem(data, dataEx[i], val == currentVal ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	if(!currentValExists)
	{
		char val[10];
		info.cvar.GetString(val, sizeof(val));
		menu.AddItem(NULL_STRING, val, ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_ShowConVarInfo(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
			
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				DisplayConVarsListMenu(param1, g_iCurrentConVarType);
		}
		
		case MenuAction_Select:
		{
			char data[100];
			menu.GetItem(param2, data, sizeof(data));
			
			char dataEx[4][22];
			ExplodeString(data, "|", dataEx, 4, 22);
			
			ConVar cvar = view_as<ConVar>(StringToInt(dataEx[0]));
			SetCvarVal(cvar, dataEx[2], dataEx[1]);
			
			char cvarName[32];
			cvar.GetName(cvarName, sizeof(cvarName));
			CPrintToChat(param1, "{gold}[FunModes]{lightgreen} You have changed {olive}%s {lightgreen}value to {olive}%s.", cvarName, dataEx[1]);
			
			ConVarInfo info;
			info.cvar = cvar;
			strcopy(info.values, sizeof(ConVarInfo::values), dataEx[3]);
			strcopy(info.type, sizeof(ConVarInfo::type), dataEx[2]);
			
			ShowConVarInfo(param1, info, g_iCurrentConVarType);
		}
	}
	
	return 0;
}

void SetCvarVal(ConVar cvar, const char[] type, const char[] valStr)
{
	if(strcmp(type, "int") == 0)
		cvar.IntValue = StringToInt(valStr);
	
	else if(strcmp(type, "float") == 0)
		cvar.FloatValue = StringToFloat(valStr);

	else if(strcmp(type, "bool") == 0)
		cvar.BoolValue = view_as<bool>(StringToInt(valStr));
}

any GetValFromCvar(ConVar cvar = null, const char[] type, const char[] valStr = "") {
	if(strcmp(type, "int") == 0)
	{
		if(cvar != null)
			return cvar.IntValue;
		else
			return StringToInt(valStr);
	}
	else if(strcmp(type, "float") == 0)
	{
		if(cvar != null)
			return cvar.FloatValue;
		else
			return StringToFloat(valStr);
	}

	else if(strcmp(type, "bool") == 0)
	{
		if(cvar != null)
			return cvar.BoolValue;
		else
			return view_as<bool>(StringToInt(valStr));
	}	
	
	return 0;
}

int GetConVarInfoSize(ConVarType type) 
{
	switch(type)
	{
		case CONVAR_TYPE_HEALBEACON:
			return sizeof(g_cvInfoHealBeacon); 
		
		case CONVAR_TYPE_VIPMode:
			return sizeof(g_cvInfoVIP);
		
		case CONVAR_TYPE_RLGL:
			return sizeof(g_cvInfoRLGL);
		
		case CONVAR_TYPE_DOUBLEJUMP:
			return sizeof(g_cvInfoDoubleJump);
	}
	
	return 1;
}

void CopyStructArray(ConVarType type, ConVarInfo[] info, int len)
{
	switch(type)
	{
		case CONVAR_TYPE_HEALBEACON:
		{
			for (int i = 0; i < len; i++)
			{
				ConVarInfo infoEx;
				infoEx.cvar = g_cvInfoHealBeacon[i].cvar;
				strcopy(infoEx.values, sizeof(ConVarInfo::values), g_cvInfoHealBeacon[i].values);
				strcopy(infoEx.type, sizeof(ConVarInfo::type), g_cvInfoHealBeacon[i].type);
				
				info[i] = infoEx;
			}
		}
		
		case CONVAR_TYPE_VIPMode:
		{
			for (int i = 0; i < len; i++)
			{
				ConVarInfo infoEx;
				infoEx.cvar = g_cvInfoVIP[i].cvar;
				strcopy(infoEx.values, sizeof(ConVarInfo::values), g_cvInfoVIP[i].values);
				strcopy(infoEx.type, sizeof(ConVarInfo::type), g_cvInfoVIP[i].type);
				
				info[i] = infoEx;
			}
		}
		
		case CONVAR_TYPE_RLGL:
		{
			for (int i = 0; i < len; i++)
			{
				ConVarInfo infoEx;
				infoEx.cvar = g_cvInfoRLGL[i].cvar;
				strcopy(infoEx.values, sizeof(ConVarInfo::values), g_cvInfoRLGL[i].values);
				strcopy(infoEx.type, sizeof(ConVarInfo::type), g_cvInfoRLGL[i].type);
				
				info[i] = infoEx;
			}
		}
		
		case CONVAR_TYPE_DOUBLEJUMP:
		{
			for (int i = 0; i < len; i++)
			{
				ConVarInfo infoEx;
				infoEx.cvar = g_cvInfoDoubleJump[i].cvar;
				strcopy(infoEx.values, sizeof(ConVarInfo::values), g_cvInfoDoubleJump[i].values);
				strcopy(infoEx.type, sizeof(ConVarInfo::type), g_cvInfoDoubleJump[i].type);
				
				info[i] = infoEx;
			}
		}
	}
}

void GetTypeTitle(ConVarType type, char[] title, int maxlen)
{
	switch(type)
	{
		case CONVAR_TYPE_HEALBEACON:
		{
			FormatEx(title, maxlen, "HealBeacon Cvars List");
		}
		case CONVAR_TYPE_VIPMode:
		{
			FormatEx(title, maxlen, "VIPMode Cvars List");
		}
		case CONVAR_TYPE_RLGL:
		{
			FormatEx(title, maxlen, "RedLightGreenLight Cvars List");
		}
		case CONVAR_TYPE_DOUBLEJUMP:
		{
			FormatEx(title, maxlen, "DoubleJump Cvars List");
		}
	}
	
	return;
}

void GetTypeConVarsList(Menu menu, ConVarType type)
{
	switch(type)
	{
		case CONVAR_TYPE_HEALBEACON:
			DisplayThisConVars(menu, g_cvInfoHealBeacon, sizeof(g_cvInfoHealBeacon), type);
		
		case CONVAR_TYPE_VIPMode:
			DisplayThisConVars(menu, g_cvInfoVIP, sizeof(g_cvInfoVIP), type);
			
		case CONVAR_TYPE_RLGL:
			DisplayThisConVars(menu, g_cvInfoRLGL, sizeof(g_cvInfoRLGL), type);

		case CONVAR_TYPE_DOUBLEJUMP:
			DisplayThisConVars(menu, g_cvInfoDoubleJump, sizeof(g_cvInfoDoubleJump), type);
	}
}

void DisplayThisConVars(Menu menu, ConVarInfo[] info, int len, ConVarType type)
{
	for (int i = 0; i < len; i++)
	{
		char data[8];
		FormatEx(data, sizeof(data), "%d|%d", view_as<int>(type), i);

		char convarName[32];
		info[i].cvar.GetName(convarName, sizeof(convarName));
		
		menu.AddItem(data, convarName);
	}
}

stock void SendHudText(int client, const char[] sMessage, bool isFar = false, int icolor = -1)
{
	bool bDynamicAvailable = false;
	int iHUDChannel = -1;

	int iChannel = g_cvHUDChannel.IntValue;
	if (iChannel < 0 || iChannel > 5) {
		iChannel = 4;
	}

	bDynamicAvailable = g_bPlugin_DynamicChannels && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;

#if defined _DynamicChannels_included_
	if (bDynamicAvailable)
		iHUDChannel = GetDynamicChannel(iChannel);
#endif

	if (isFar)
		SetHudTextParams(-0.2, 1.0, 0.7, 255, 13, 55, 255);
	else
		SetHudTextParams(-0.2, 1.0, 2.0, 255, 36, 255, 13);

	switch(icolor)
	{
		case 0:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 255, 36, 255, 13);
		}
		case 1:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 255, 0, 0, 50);
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 124, 252, 0, 50);
		}
	}

	if (bDynamicAvailable)
	{
		ShowHudText(client, iHUDChannel, "%s", sMessage);
	}
	else
	{
		ClearSyncHud(client, g_hHudMsg);
		ShowSyncHudText(client, g_hHudMsg, "%s", sMessage);
	}
}
