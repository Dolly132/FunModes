/*
    (). FunModes V2:
        
    @file           Core/Core.sp
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
int g_iNetPropAmmoIndex = -1;

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

ModeInfo g_ModesInfo[MAX_MODES_NUM];
int g_iLastModeIndex;

/* ConVars Section */
KeyValues g_hKV;

#define FUNMODES_CVAR_CONFIG "addons/sourcemod/configs/FunModes/ConVars.cfg"

enum ConVarType
{
	CONVAR_BOOL = 0,
	CONVAR_INT,
	CONVAR_FLOAT,
	CONVAR_STRING,
	CONVAR_NONE
};

void FunModes_CallCvarChange(DataPack pack)
{
	pack.Reset();

	Function hookFunc = pack.ReadFunction();
	int modeIndex = pack.ReadCell();
	int cvarIndex = pack.ReadCell();

	char oldVal[sizeof(FM_ConVar::currentValue)], currentValue[sizeof(FM_ConVar::currentValue)];
	pack.ReadString(oldVal, sizeof(oldVal));
	pack.ReadString(currentValue, sizeof(currentValue));

	delete pack;

	Call_StartFunction(null, hookFunc);

	Call_PushCell(modeIndex);
	Call_PushCell(cvarIndex);
	Call_PushString(oldVal);
	Call_PushString(currentValue);

	Call_Finish();
}

enum struct FM_ConVar
{
	int modeIndex;
	int cvarIndex;

	char name[35];
	char defaultValue[128];
	char description[128];

	char values[32];
	ConVarType type;

	char currentValue[128];

	Function hookFunc;

	bool autoChange;

	void HookChange(Function func)
	{
		this.hookFunc = func;
	}

	void OnChange(const char[] oldVal)
	{
		if (g_hKV && !this.autoChange)
		{
			char key[5];
			IntToString(this.GetPos(), key, sizeof(key));

			if (g_hKV.JumpToKey(key))
			{
				g_hKV.SetString("currentValue", this.currentValue);
				g_hKV.Rewind();
				g_hKV.ExportToFile(FUNMODES_CVAR_CONFIG);
			}
		}

		if (this.hookFunc == INVALID_FUNCTION)
			return;

		// We have to do a RequestFrame to avoid a weird sourcemod bug...
		DataPack pack = new DataPack();
		pack.WriteFunction(this.hookFunc);
		pack.WriteCell(this.modeIndex);
		pack.WriteCell(this.cvarIndex);
		pack.WriteString(oldVal);
		pack.WriteString(this.currentValue);

		RequestFrame(FunModes_CallCvarChange, pack);
	}

	int GetPos()
	{
		int pos = 0;
		for (int i = this.modeIndex - 1; i >= 0; i--)
			pos += g_ModesInfo[i].GetCvarsCount();

		pos += this.cvarIndex;
		return pos;
	}

	void SetBool(bool val)
	{
		this.currentValue = "";
		this.currentValue[0] = val ? '1' : '0';
	}
	
	bool GetBool()
	{
		return this.type == CONVAR_BOOL && this.currentValue[0] == '1';
	}

	void SetInt(int val)
	{
		char oldVal[sizeof(FM_ConVar::currentValue)];
		oldVal = this.currentValue;

		IntToString(val, this.currentValue, sizeof(FM_ConVar::currentValue));

		this.OnChange(oldVal);
	}

	int GetInt()
	{
		if (view_as<int>(this.type) > view_as<int>(CONVAR_FLOAT))
			return -1;

		return StringToInt(this.currentValue);
	}

	void SetFloat(float val)
	{
		char oldVal[sizeof(FM_ConVar::currentValue)];
		oldVal = this.currentValue;

		FloatToString(val, this.currentValue, sizeof(FM_ConVar::currentValue));

		this.OnChange(oldVal);
	}

	float GetFloat()
	{
		if (view_as<int>(this.type) > view_as<int>(CONVAR_FLOAT))
			return -1.0;

		return StringToFloat(this.currentValue);
	}

	void SetString(const char str[sizeof(FM_ConVar::currentValue)])
	{
		char oldVal[sizeof(FM_ConVar::currentValue)];
		oldVal = this.currentValue;

		this.currentValue = str;
		this.OnChange(oldVal);
	}

	char[] GetString()
	{
		return this.currentValue;
	}
}

enum struct ModeInfo 
{
	int index;
	char name[32];
	char tag[64];
	FM_ConVar cvars[MAX_CVARS_NUM];
	bool isOn;
	int enableIndex;

	int GetCvarsCount()
	{
		int count;
		for (int i = 0; i < sizeof(ModeInfo::cvars); i++)
		{
			if (this.cvars[i].name[0] == '\0')
				continue;

			count++;
		}

		return count;
	}
}

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

#define HEGRENADE			11
#define FLASHBANG			12
#define SMOKEGRENADE		13

#define GET_GRENADES_COUNT(%1,%2)		GetEntData(%1, g_iNetPropAmmoIndex + (%2 * 4))
#define SET_GRENADES_COUNT(%1,%2,%3)	SetEntData(%1, g_iNetPropAmmoIndex + (%2 * 4), %3, _, true)			

/* Modes Management Macros */
#define THIS_MODE_INFO
#define NULL -1

/*
* Declares a FunModes cvar related to the current mode the compiler is reading.
*
* @param %1		Cvar index.
* @param %2		Cvar name.
* @param %3		Cvar's default value.
* @param %4		Cvar's description.
* @param %5		Cvar's accepted values.
* @param %6		Cvar's value type.
*/
#define DECLARE_FM_CVAR(%1,%2,%3,%4,%5,%6) \
		THIS_MODE_INFO.cvars[%1].modeIndex = g_iLastModeIndex; \
		THIS_MODE_INFO.cvars[%1].cvarIndex = %1; \
		THIS_MODE_INFO.cvars[%1].name = %2; \
		THIS_MODE_INFO.cvars[%1].defaultValue = %3; \
		THIS_MODE_INFO.cvars[%1].currentValue = %3; \
		THIS_MODE_INFO.cvars[%1].description = %4; \
		THIS_MODE_INFO.cvars[%1].values = %5; \
		THIS_MODE_INFO.cvars[%1].type = %6

/*
* Changes the current mode the compiler is reading's info.
*
* @param %1		The mode's struct.
* @param %2		The variable to chnage.
* @param %3		The new value to assign to the variable.
* @param %4		The mode's index.
*/
#define CHANGE_MODE_INFO(%1,%2,%3,%4) \
		%1.%2 = %3; \
		g_ModesInfo[%4].%2 = %3

/*
* Retrieves a cvar's value. (Using the cvar's enum struct)
*
* @param %1		The cvar's enum struct.
* @param %2		The cvar's data type.
*/
#define FUNMODES_CVAR_GET_VALUE(%1,%2) %1.Get%2()

/*
* Sets a cvar's value to another one. (Using the cvar's enum struct)
*
* @param %1		The cvar's enum struct.
* @param %2		The cvar's data type.
* @param %3		The new value.
*/
#define FUNMODES_CVAR_SET_VALUE(%1,%2,%3) %1.Set%2(%3) \


/*
* Retrieves a cvar's value. (Using the cvar's mode and cvar indexes)
*
* @param %1		The cvar's mode index.
* @param %2		The cvar's index.
* @param %3		The cvar's data type.
*/
#define _FUNMODES_CVAR_GET_VALUE(%1,%2,%3) g_ModesInfo[%1].cvars[%2].Get%3()

/*
* Sets a cvar's value to another one. (Using the cvar's mode and cvar indexes)
*
* @param %1		The cvar's mode index.
* @param %2		The cvar's index.
* @param %3		The cvar's data type.
* @param %4		The new value.
*/
#define _FUNMODES_CVAR_SET_VALUE(%1,%2,%3,%4) g_ModesInfo[%1].cvars[%2].Set%3(%4)

/*
* Checks if the given cvar is a valid funmodes cvar.
*
* @param %1		The cvar's enum struct.
*/
#define FUNMODES_CVAR_ISVALID(%1) !(%1.name[0] == '\0' || %1.type == CONVAR_NONE)

/*
* Registers a FunMode and adds it to the modes array.
*
* @param %1		The name of the mode.
* @param %2		The tag of the mode.
* @param %3		The index of the enable/disable cvar relative to the mode.
*/
#define FUNMODES_REGISTER_MODE() \
		THIS_MODE_INFO.index = g_iLastModeIndex++; \
		g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO

#include "Fun_Modes/Core/ModesInclude.sp"
#include "Fun_Modes/Core/ModesDefinition.sp"
