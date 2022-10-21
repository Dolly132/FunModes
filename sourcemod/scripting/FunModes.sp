#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
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
bool g_bRoundEnd;

#define HealBeacon_Tag "{gold}[FunModes-HealBeacon]{lightgreen}"
#define BeaconMode_HealBeacon 0

#define VIPMode_Tag "{gold}[FunModes-VIPMode]{lightgreen}"
#define BeaconMode_VIP 1

#define Fog_Tag "{gold}[FunModes-FOG]{lightgreen}"
#define FOGInput_Color 0
#define FOGInput_Start 1
#define FOGInput_End 2
#define FOGInput_Toggle 3

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

/* CONVARS */
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
	"255 0 0 255 Red", \
	"0 255 0 255 Lime", \
	"0 0 255 255 Blue", \
	"255 255 0 255 Yellow", \
	"0 255 255 255 Cyan", \
	"255 215 0 255 Gold"
};

ConVar g_cvVIPModeCount;
ConVar g_cvVIPModeLaser;
ConVar g_cvVIPModeTimer;

Handle g_hKillAllTimer = null;
Handle g_hVIPRoundStartTimer = null;
Handle g_hVIPBeaconTimer[MAXPLAYERS + 1] = { null, ... };

int g_iVIPUserid = -1;

/* CUSTOM SP INCLUDE FILES */
#include "Fun_Modes/HealBeacon.sp"
#include "Fun_Modes/HealBeacon_Menus.sp"
#include "Fun_Modes/VIPMode.sp"
#include "Fun_Modes/Fog.sp"

public Plugin myinfo =  {
	name = "FunModes",
	author = "Abandom (aka Dolly)",
	description = "bunch of fun modes for ze mode",
	version = "1.0",
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
	HookEvent("round_end", Event_RoundEnd);	
	
	PluginStart_HealBeacon();
	PluginStart_VIPMode();
	PluginStart_Fog();
	
	AutoExecConfig();
	
	for(int i = 1; i <= MaxClients; i++) {
		if(IsValidClient(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnMapStart() {
	g_LaserSprite = PrecacheModel("sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
	
	PrecacheSound(Beacon_Sound, true);
	
	g_FogData.fogStart = 50.0;
	g_FogData.fogEnd = 250.0;
	g_FogData.fogEnable = false;
	
	g_bIsVIPModeOn = false;
	g_bIsHealBeaconOn = false;
	g_bIsBetterDamageModeOn = false;
	
	/* CREATE HEALBEACON ARRAYLIST */
	g_aHBPlayers = new ArrayList(ByteCountToCells(32));
}

public void OnMapEnd() {
	/* DELETE THE ARRAYLIST HANDLE */
	delete g_aHBPlayers;
}

public void OnClientPutInServer(int client) {
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
