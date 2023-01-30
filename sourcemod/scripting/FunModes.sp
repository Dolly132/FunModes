#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

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

enum struct BeaconPlayers {
	bool hasHealBeacon;
	bool hasNeon;
	int color[4];
	float distance;
	int neonEntity;
	
	void SetColor(int setColor[4]) {
		this.color[0] = setColor[0];
		this.color[1] = setColor[1];
		this.color[2] = setColor[2];
		this.color[3] = setColor[3];
	}
	
	void ResetColor() {
		this.color[0] = g_ColorDefault[0];
		this.color[1] = g_ColorDefault[1];
		this.color[2] = g_ColorDefault[2];
		this.color[3] = g_ColorDefault[3];
	}
	
	void ResetValues() {
		this.hasHealBeacon = false;
		this.ResetColor();
		this.distance = g_cvDefaultDistance.FloatValue;
		this.neonEntity = -1;
	}
}

BeaconPlayers g_BeaconPlayersData[MAXPLAYERS + 1];

enum struct fogData {
	bool fogEnable;
	float fogStart;
	float fogEnd;
	int fogColor[4];
	
	void SetColor(int setColor[4]) {
		this.fogColor[0] = setColor[0];
		this.fogColor[1] = setColor[1];
		this.fogColor[2] = setColor[2];
		this.fogColor[3] = setColor[3];
	}
}

fogData g_FogData;

int g_iFogEntity = -1;

char colorsList[][] = {
	"255 255 255 255 White",
	"255 0 0 255 Red", 
	"0 255 0 255 Lime", 
	"0 0 255 255 Blue", 
	"255 255 0 255 Yellow", 
	"0 255 255 255 Cyan", 
	"255 215 0 255 Gold"
};

/* VIP MODE CONVARS */
ConVar g_cvVIPModeCount;
ConVar g_cvVIPModeLaser;
ConVar g_cvVIPModeTimer;

/* RLGL CONVARS */
ConVar g_cvRLGLDetectTimer;
ConVar g_cvRLGLFinishDetectTime;
ConVar g_cvRLGLDetectTimerRepeat;
ConVar g_cvRLGLDamage;
ConVar g_cvRLGLWarningTime;

/* DOUBLE JUMP CONVARS */
ConVar g_cvDoubleJumpBoost;
ConVar g_cvDoubleJumpMaxJumps;
ConVar g_cvDoubleJumpHumansEnable;
ConVar g_cvDoubleJumpZombiesEnable;

enum ConVarType {
	CONVAR_TYPE_HEALBEACON = 0,
	CONVAR_TYPE_VIPMode = 1,
	CONVAR_TYPE_RLGL = 2,
	CONVAR_TYPE_DOUBLEJUMP = 3
}

/* TIMERS */
Handle g_hKillAllTimer = null;
Handle g_hVIPRoundStartTimer = null;
Handle g_hVIPBeaconTimer[MAXPLAYERS + 1] = { null, ... };
Handle g_hRLGLTimer = null;
Handle g_hRLGLDetectTimer;

int g_iVIPUserid = -1;

/* CUSTOM SP INCLUDE FILES */
#include "Fun_Modes/HealBeacon.sp"
#include "Fun_Modes/HealBeacon_Menus.sp"
#include "Fun_Modes/VIPMode.sp"
#include "Fun_Modes/Fog.sp"
#include "Fun_Modes/RedLightGreenLight.sp"
#include "Fun_Modes/DoubleJump.sp"
#include "Fun_Modes/InvertedControls.sp"

public Plugin myinfo =  {
	name = "FunModes",
	author = "Dolly",
	description = "bunch of fun modes for ze mode",
	version = "1.3",
	url = "https://nide.gg"
}

public void OnPluginStart()
{
	/* TRANSLATIONS LAODS */
	LoadTranslations("common.phrases");
	LoadTranslations("FunModes.phrases");
	
	/* EVENTS HOOKS */
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);	
	
	/* HUD HANDLE */
	g_hHudMsg = CreateHudSynchronizer();
	
	PluginStart_HealBeacon();
	PluginStart_VIPMode();
	PluginStart_Fog();
	PluginStart_RLGL();
	PluginStart_DoubleJump();
	PluginStart_IC();
	
	AutoExecConfig();
	
	for(int i = 1; i <= MaxClients; i++) {
		if(IsValidClient(i)) {
			OnClientPutInServer(i);
		}
	}
	
	static const char commands[][] = { "sm_fm_cvars", "sm_funmodes", "sm_funmode" };
	for(int i = 0; i < sizeof(commands); i++) {
		RegAdminCmd(commands[i], Cmd_Cvars, ADMFLAG_CONVARS, "Shows All fun modes cvars");
	}
}

public void OnMapStart() {
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
}

public void OnMapEnd() {
	g_hRLGLTimer = null;
	g_hRLGLDetectTimer = null;
}

public void OnClientPutInServer(int client) {
	if(!g_bIsVIPModeOn) {
		return;
	}
	
	if(IsFakeClient(client) || IsClientSourceTV(client)) {
		return;
	}
	
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
} 

/*
*** EVENTS HOOKS CALLBACKS ***
*/

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bRoundEnd = false;
	RequestFrame(RoundStart_Frame);
}

void RoundStart_Frame() {
	RoundStart_HealBeacon();
	RoundStart_Fog();
	RoundStart_VIPMode();
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	
	PlayerDeath_HealBeacon(userid);
	PlayerDeath_VIPMode(userid);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int team = event.GetInt("team");
	
	PlayerTeam_HealBeacon(userid, team);
	PlayerTeam_VIPMode(userid, team);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if(!g_FogData.fogEnable) {
		return;
	}
	
	int userid = event.GetInt("userid");
	
	PlayerSpawn_Fog(userid);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_bRoundEnd = true;
}

public void OnClientDisconnect(int client) {
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

stock void BeaconPlayer(int client, int mode) {
	float fvec[3];
	GetClientAbsOrigin(client, fvec);
	fvec[2] += 10;
	
	if(mode == BeaconMode_HealBeacon) {
		TE_SetupBeamRingPoint(fvec, (g_BeaconPlayersData[client].distance - 10.0), g_BeaconPlayersData[client].distance, g_LaserSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 0.0, g_BeaconPlayersData[client].color, 10, 0);
		TE_SendToAll();
	}
	else if(mode == BeaconMode_VIP) {
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

Action Cmd_Cvars(int client, int args) {
	if(!client) {
		return Plugin_Handled;
	}
	
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

int Menu_MainCvars(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_End: {
			delete menu;
		}
		
		case MenuAction_Select: {
			ConVarType type;
			switch(param2) {
				case 0: {
					type = CONVAR_TYPE_HEALBEACON;
				}
				
				case 1: {
					type = CONVAR_TYPE_VIPMode;
				}
				
				case 2: {
					type = CONVAR_TYPE_RLGL;
				}
				
				case 3: {
					type = CONVAR_TYPE_DOUBLEJUMP;
				}
			}
			
			DisplayConVarsListMenu(param1, type);
		}
	}
	
	return 0;
}

void DisplayConVarsListMenu(int client, ConVarType type) {
	Panel panel = new Panel();
	
	char title[64];
	GetTypeTitle(type, title, sizeof(title));
	panel.SetTitle(title);
	
	GetTypeConVarsList(panel, type);
	
	panel.CurrentKey = 9;
	panel.DrawItem("Back");
	
	panel.Send(client, Menu_CvarsList, MENU_TIME_FOREVER);
}

int Menu_CvarsList(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_End: {
			delete menu;
		}
		
		case MenuAction_Select: {
			if(param2 == 9) {
				Cmd_Cvars(param1, 0);
				return 0;
			}
		}
	}
	
	return 0;
}

void GetTypeTitle(ConVarType type, char[] title, int maxlen) {
	switch(type) {
		case CONVAR_TYPE_HEALBEACON: {
			FormatEx(title, maxlen, "HealBeacon Cvars List");
		}
		
		case CONVAR_TYPE_VIPMode: {
			FormatEx(title, maxlen, "VIPMode Cvars List");
		}
		
		case CONVAR_TYPE_RLGL: {
			FormatEx(title, maxlen, "RedLightGreenLight Cvars List");
		}
		
		case CONVAR_TYPE_DOUBLEJUMP: {
			FormatEx(title, maxlen, "DoubleJump Cvars List");
		}
	}
	
	return;
}

void GetTypeConVarsList(Panel panel, ConVarType type) {
	switch(type) {
		case CONVAR_TYPE_HEALBEACON: {
			ConVar cvars[6];
			HealBeacon_GetConVars(cvars);
			for(int i = 0; i < sizeof(cvars); i++) {
				GetConVarNameAndDescription(panel, cvars[i]);
			}
		}
		
		case CONVAR_TYPE_VIPMode: {
			ConVar cvars[3];
			VIPMode_GetConVars(cvars);
			for(int i = 0; i < sizeof(cvars); i++) {
				GetConVarNameAndDescription(panel, cvars[i]);
			}
		}
		
		case CONVAR_TYPE_RLGL: {
			ConVar cvars[5];
			RLGL_GetConVars(cvars);
			for(int i = 0; i < sizeof(cvars); i++) {
				GetConVarNameAndDescription(panel, cvars[i]);
			}
		}
		
		case CONVAR_TYPE_DOUBLEJUMP: {
			ConVar cvars[4];
			DoubleJump_GetConVars(cvars);
			for(int i = 0; i < sizeof(cvars); i++) {
				GetConVarNameAndDescription(panel, cvars[i]);
			}
		}
	}
}

void GetConVarNameAndDescription(Panel panel, ConVar cvar) {
	char cvarName[90];
	cvar.GetName(cvarName, sizeof(cvarName));
	panel.DrawItem(cvarName);
	
	char cvarDescription[128];
	cvar.GetDescription(cvarDescription, sizeof(cvarDescription));
	panel.DrawText(cvarDescription);
}
