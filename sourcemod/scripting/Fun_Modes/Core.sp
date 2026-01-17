/*
    (). FunModes V2:
        
    @file           Core.sp
    @Usage          Global variables, and modes definition, add the mode names in the end of the file
*/

/* Important Variables */

/* Event Hooks Booleans */
bool g_bEvent_RoundStart;
bool g_bEvent_RoundEnd;
bool g_bEvent_PlayerDeath;
bool g_bEvent_PlayerTeam;
bool g_bEvent_PlayerSpawn;
bool g_bEvent_WeaponFire;

/* Client SDKHook Boolens */
bool g_bSDKHook_OnTakeDamagePost[MAXPLAYERS + 1] = { false, ... };
bool g_bSDKHook_WeaponEquip[MAXPLAYERS + 1] =  { false, ... };
bool g_bSDKHook_OnTakeDamage[MAXPLAYERS + 1] =  { false, ... };

/* Round Checking Booleans */
bool g_bRoundEnd;

/* COLORS VARIABLES */
int g_ColorCyan[4] =  {0, 255, 255, 255}; // cyan
int g_ColorDefault[4] = {255, 215, 55, 255}; // default color

/* Sprites Indexes Integers */
int g_LaserSprite = -1;
int g_HaloSprite = -1;
int g_iLaserBeam = -1;

/* Library Checking Booleans */
bool g_bPlugin_DynamicChannels = false;
bool g_bMotherZombie = false;

/* HUD HANDLER */
Handle g_hHudMsg = null;

/* NORMAL VARIABLES */
int g_iCounter = 0;

/* GLOBAL CONVARS */
ConVar g_cvHUDChannel;
int g_iPreviousModeIndex[MAXPLAYERS+1];

/* SDKCall Handles */
Handle g_hSwitchSDKCall;

#define Beacon_Sound        "buttons/blip1.wav"

#define FFADE_IN       (0x0001) // Fade in
#define FFADE_OUT      (0x0002) // Fade out
#define FFADE_MODULATE (0x0004) // Modulate (Don't blend)
#define FFADE_STAYOUT  (0x0008) // Ignores the duration, stays faded out until a new fade message is received
#define FFADE_PURGE    (0x0010) // Purges all other fades, replacing them with this one

/* Mode Management structs */
#define MAX_MODES_NUM 32
#define MAX_CVARS_NUM 10

enum struct ConVarInfo
{
	ConVar cvar;
	char values[32];
	char type[10];
}

enum struct ModeInfo 
{
	int index;
	char name[32];
	char tag[64];
	ConVarInfo cvarInfo[MAX_CVARS_NUM];
	bool isOn;
	int enableIndex;
}

ModeInfo g_ModesInfo[MAX_MODES_NUM];
int g_iLastModeIndex;

enum struct FM_Color
{
	char name[10];
	char rgb[14];
}

FM_Color g_ColorsList[] =
{
	{ "White", "255 255 255" },
	{ "Red", "255 0 0" },
	{ "Lime", "0 255 0" },
	{ "Blue", "0 0 255" },
	{ "Yellow", "255 255 0" },
	{ "Cyan", "0 255 255" },
	{ "Gold", "255 215 0" }
};

enum WeaponAmmoGrenadeType
{
	GrenadeType_HEGrenade           = 11,   /** CSS - HEGrenade slot */
	GrenadeType_Flashbang           = 12,   /** CSS - Flashbang slot. */
	GrenadeType_Smokegrenade        = 13,   /** CSS - Smokegrenade slot. */
};

/* 
- New FunModes Update
	* The plugin will now use macros to define the main functions and forwards
	* Macros are the only way possible for this as sourcepawn is too weak
	* Do not edit the macros unless you know what you are doing

- Things that are useful by macros:
	* Only add the mode inside the DECLARE_FM_FORWARD macro, and the mode wll be included
	* The include files will still need to be included by a macro
	* Flexibility and more funcitonality
*/
/* Edit the macros when you add a new mode */
#define CALL_MODE_FUNC(%1,%2) %1_%2()
#define DECLARE_FM_FORWARD(%1) \
		CALL_MODE_FUNC(%1, HealBeacon); \ 
		CALL_MODE_FUNC(%1, VIPMode); \ 
		CALL_MODE_FUNC(%1, IC); \ 
		CALL_MODE_FUNC(%1, Fog); \
		CALL_MODE_FUNC(%1, RLGL); \
		CALL_MODE_FUNC(%1, DoubleJump); \ 
		CALL_MODE_FUNC(%1, DamageGame); \
		CALL_MODE_FUNC(%1, BlindMode); \
		CALL_MODE_FUNC(%1, SlapMode); \
		CALL_MODE_FUNC(%1, ChaosWeapons); \
		CALL_MODE_FUNC(%1, GunGame); \
		CALL_MODE_FUNC(%1, MathGame); \
		CALL_MODE_FUNC(%1, CrazyShop); \
		CALL_MODE_FUNC(%1, RealityShift); \
		CALL_MODE_FUNC(%1, PullGame)

#define CALL_MODE_FUNC_PARAM(%1,%2,%3) %1_%2(%3)
#define DECLARE_FM_FORWARD_PARAM(%1,%2) \
		CALL_MODE_FUNC_PARAM(%1, HealBeacon, %2); \ 
		CALL_MODE_FUNC_PARAM(%1, VIPMode, %2); \
		CALL_MODE_FUNC_PARAM(%1, IC, %2); \
		CALL_MODE_FUNC_PARAM(%1, Fog, %2); \
		CALL_MODE_FUNC_PARAM(%1, RLGL, %2); \
		CALL_MODE_FUNC_PARAM(%1, DoubleJump, %2); \
		CALL_MODE_FUNC_PARAM(%1, DamageGame, %2); \
		CALL_MODE_FUNC_PARAM(%1, BlindMode, %2); \
		CALL_MODE_FUNC_PARAM(%1, GunGame, %2); \
		CALL_MODE_FUNC_PARAM(%1, CrazyShop, %2); \
		CALL_MODE_FUNC_PARAM(%1, RealityShift, %2); \
		CALL_MODE_FUNC_PARAM(%1, PullGame, %2)

/*
these commented macros are not used for now
#define CALL_MODE_FUNC_PARAM2(%1,%2,%3,%4) %1_%2(%3,%4)
#define DECLARE_FM_FORWARD_PARAM2(%1,%2,%3) \
		CALL_MODE_FUNC_PARAM2(%1, HealBeacon, %2, %3); \ 
		CALL_MODE_FUNC_PARAM2(%1, VIPMode, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, RLGL, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, IC, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, Fog, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, DoubleJump, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, DamageGame, %2, %3)
*/
/* for now there are only 4 modes that use 3 params functions */
#define CALL_MODE_FUNC_PARAM3(%1,%2,%3,%4,%5) %1_%2(%3,%4,%5)
#define DECLARE_FM_FORWARD_PARAM3(%1,%2,%3,%4) \
		CALL_MODE_FUNC_PARAM3(%1, VIPMode, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, DamageGame, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, GunGame, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, CrazyShop, %2, %3, %4)

/* For 4 params-functions, only crazyshop and vipmode use it for now */
#define CALL_MODE_FUNC_PARAM4(%1,%2,%3,%4,%5,%6) %1_%2(%3,%4,%5,%6)
#define DECLARE_FM_FORWARD_PARAM4(%1,%2,%3,%4,%5) \
		CALL_MODE_FUNC_PARAM4(%1, VIPMode, %2, %3, %4, %5); \
		CALL_MODE_FUNC_PARAM4(%1, CrazyShop, %2, %3, %4, %5)

/* OnPlayerRunCmdPost Calls (Since this is called every frame, we gotta watch out for performance :p) */
#define DECLARE_ONPLAYERRUNCMD_POST(%1,%2,%3,%4) \
		CALL_MODE_FUNC_PARAM3(%1, DoubleJump, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, CrazyShop, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, PullGame, %2, %3, %4)
		
/* %0: ConVarInfo[], %1: index, %2: name, %3: default value, %4: description 
	%5: cvar values, %6: cvar value type
*/ 
#define DECLARE_FM_CVAR(%1,%2,%3,%4,%5,%6,%7) \
		%1[%2].cvar = CreateConVar(%3, %4, %5); \
		%1[%2].values = %6; \
		%1[%2].type = %7

/* %1: mode struct, %2: variable, %3: value, %4: index */
#define CHANGE_MODE_INFO(%1,%2,%3,%4) \ 
		%1.%2 = %3; \
		g_ModesInfo[%4] = %1

#define THIS_MODE_INFO

/* Add the mode's include file here */
#include "Fun_Modes/HealBeacon.sp"
#include "Fun_Modes/VIPMode.sp"
#include "Fun_Modes/Fog.sp"
#include "Fun_Modes/RedLightGreenLight.sp"
#include "Fun_Modes/DoubleJump.sp"
#include "Fun_Modes/InvertedControls.sp"
#include "Fun_Modes/DamageGame.sp"
#include "Fun_Modes/BlindMode.sp"
#include "Fun_Modes/SlapMode.sp"
#include "Fun_Modes/ChaosWeapons.sp"
#include "Fun_Modes/GunGame.sp"
#include "Fun_Modes/MathGame.sp"
#include "Fun_Modes/CrazyShop.sp"
#include "Fun_Modes/RealityShift.sp"
#include "Fun_Modes/PullGame.sp"