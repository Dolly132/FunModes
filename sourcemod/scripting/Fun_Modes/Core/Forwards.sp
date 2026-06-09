/*
    (). FunModes V2:
        
    @file           Core/Forwards.sp
    @Usage          Modes Forwards Management, don't touch it if you don't know what you are doing!
*/

#pragma semicolon 1

/* Forwards Flags */
#define FWD_InitCvarsValues          (1 << 0)
#define FWD_OnPluginEnd              (1 << 1)
#define FWD_OnMapStart               (1 << 2)
#define FWD_OnMapEnd                 (1 << 3)
#define FWD_OnClientPutInServer      (1 << 4)
#define FWD_OnClientDisconnect       (1 << 5)
#define FWD_ZR_OnClientInfected      (1 << 6)
#define FWD_Event_RoundStart         (1 << 7)
#define FWD_Event_RoundEnd           (1 << 8)
#define FWD_Event_PlayerSpawn        (1 << 9)
#define FWD_Event_PlayerTeam         (1 << 10)
#define FWD_Event_PlayerDeath        (1 << 11)
#define FWD_OnTakeDamagePost         (1 << 12)
#define FWD_OnTakeDamage             (1 << 13)
#define FWD_OnWeaponEquip            (1 << 14)
#define FWD_OnPlayerRunCmdPost       (1 << 15)

/* 
* Checks whether a given forward can be executed for the current mode the compiler is reading.
*
* @param %1		The forward name.
*/
#define CHECK_FORWARD_FLAG(%1) \
		if (this.flags != 0 && !(this.flags & FWD_%1)) return;

/* 
* Executes a specific forward with no params for the current FM_Forwards enum struct.
*
* @param %1		The forward name.
*/
#define CALL_FUNCTION_PARAM0(%1) \
		CHECK_FORWARD_FLAG(%1) \
		Call_StartFunction(null, this.fn_%1); \
		Call_Finish();

/* 
* Executes a specific forward with one param for the current FM_Forwards enum struct.
*
* @param %1		The forward name.
* @param %2		The first param.
* @param %3		The type of the first param. That's used for Call_Push*
*/
#define CALL_FUNCTION_PARAM1(%1,%2,%3) \
		CHECK_FORWARD_FLAG(%1) \
		Call_StartFunction(null, this.fn_%1); \
		Call_Push%3(%2); \
		Call_Finish();

/* 
* Executes a specific forward with three params for the current FM_Forwards enum struct.
*
* @param %1		The forward name.
* @param %2		The first param.
* @param %3		The type of the first param. That's used for Call_Push*
* @param %4		The second param.
* @param %5		The type of the second param. That's used for Call_Push*
* @param %6		The third param.
* @param %7		The type of the third param. That's used for Call_Push*
*/
#define CALL_FUNCTION_PARAM3(%1,%2,%3,%4,%5,%6,%7) \
		CHECK_FORWARD_FLAG(%1) \
		Call_StartFunction(null, this.fn_%1); \
		Call_Push%3(%2); \
		Call_Push%5(%4); \
		Call_Push%7(%6); \
		Call_Finish();

/* 
* Executes a specific forward with four params for the current FM_Forwards enum struct.
*
* @param %1		The forward name.
* @param %2		The first param.
* @param %3		The type of the first param. That's used for Call_Push*
* @param %4		The second param.
* @param %5		The type of the second param. That's used for Call_Push*
* @param %6		The third param.
* @param %7		The type of the third param. That's used for Call_Push*
* @param %6		The fourth param.
* @param %7		The type of the fourth param. That's used for Call_Push*
*/
#define CALL_FUNCTION_PARAM4(%1,%2,%3,%4,%5,%6,%7,%8,%9) \
		CHECK_FORWARD_FLAG(%1) \
		Call_StartFunction(null, this.fn_%1); \
		Call_Push%3(%2); \
		Call_Push%5(%4); \
		Call_Push%7(%6); \
		Call_Push%9(%8); \
		Call_Finish();

/*
* Declares a specific forward with no params to prepare all modes forwards execution.
*
* @param %1		The forward name.
*/
#define DECLARE_FM_FORWARD_PARAM0(%1) \
		for (int i = 0; i < g_iLastModeIndex; i++) \
		{ \
			g_ModesInfo[i].forwards.Call_%1(); \
		}

/*
* Declares a specific forward with one param to prepare all modes forwards execution.
*
* @param %1		The forward name.
* @param %2		The first param.
*/
#define DECLARE_FM_FORWARD_PARAM1(%1,%2) \
		for (int i = 0; i < g_iLastModeIndex; i++) \
		{ \
			g_ModesInfo[i].forwards.Call_%1(%2); \
		}

/*
* Declares a specific forward with three params to prepare all modes forwards execution.
*
* @param %1		The forward name.
* @param %2		The first param.
* @param %3		The second param.
* @param %4		The third param.
*/
#define DECLARE_FM_FORWARD_PARAM3(%1,%2,%3,%4) \
		for (int i = 0; i < g_iLastModeIndex; i++) \
		{ \
			g_ModesInfo[i].forwards.Call_%1(%2,%3,%4); \
		}

/*
* Declares a specific forward with four params to prepare all modes forwards execution.
*
* @param %1		The forward name.
* @param %2		The first param.
* @param %3		The second param.
* @param %4		The third param.
* @param %5		The fourth param.
*/
#define DECLARE_FM_FORWARD_PARAM4(%1,%2,%3,%4,%5) \
		for (int i = 0; i < g_iLastModeIndex; i++) \
		{ \
			g_ModesInfo[i].forwards.Call_%1(%2,%3,%4,%5); \
		}

/*
* Validates whether the current mode the compiler is reading can execute this specific forward.
*
* @param %1		The forward name.
* @param %2		The forward name as char[].
*/
#define VALIDATE_FM_ONE_FORWARD(%1,%2) \
		THIS_MODE_INFO.forwards.fn_%1 = GetFunctionByName(null, %2 ... "_" ... THIS_MODE_NAME); \
		if (THIS_MODE_INFO.forwards.fn_%1 != INVALID_FUNCTION) \
		{ \
			THIS_MODE_INFO.forwards.flags |= FWD_%1; \
		}

/*
* Gets the function ID for all available forwards for the current mode the compiler is reading.
*
* @noparams
*/
#define VALIDATE_FM_FORWARDS() \
		VALIDATE_FM_ONE_FORWARD(InitCvarsValues, "InitCvarsValues") \
		VALIDATE_FM_ONE_FORWARD(OnPluginEnd, "OnPluginEnd") \
		VALIDATE_FM_ONE_FORWARD(OnMapStart, "OnMapStart") \
		VALIDATE_FM_ONE_FORWARD(OnMapEnd, "OnMapEnd") \
		VALIDATE_FM_ONE_FORWARD(OnClientPutInServer, "OnClientPutInServer") \
		VALIDATE_FM_ONE_FORWARD(OnClientDisconnect, "OnClientDisconnect") \
		VALIDATE_FM_ONE_FORWARD(ZR_OnClientInfected, "ZR_OnClientInfected") \
		VALIDATE_FM_ONE_FORWARD(Event_RoundStart, "Event_RoundStart") \
		VALIDATE_FM_ONE_FORWARD(Event_RoundEnd, "Event_RoundEnd") \
		VALIDATE_FM_ONE_FORWARD(Event_PlayerSpawn, "Event_PlayerSpawn") \
		VALIDATE_FM_ONE_FORWARD(Event_PlayerTeam, "Event_PlayerTeam") \
		VALIDATE_FM_ONE_FORWARD(Event_PlayerDeath, "Event_PlayerDeath") \
		VALIDATE_FM_ONE_FORWARD(OnTakeDamagePost, "OnTakeDamagePost") \
		VALIDATE_FM_ONE_FORWARD(OnTakeDamage, "OnTakeDamage") \
		VALIDATE_FM_ONE_FORWARD(OnWeaponEquip, "OnWeaponEquip") \
		VALIDATE_FM_ONE_FORWARD(OnPlayerRunCmdPost, "OnPlayerRunCmdPost")

enum struct FM_Forwards
{
	int flags;

	Function fn_InitCvarsValues;
	void Call_InitCvarsValues()
	{
		CALL_FUNCTION_PARAM0(InitCvarsValues)
	}

	Function fn_OnPluginEnd;
	void Call_OnPluginEnd()
	{
		CALL_FUNCTION_PARAM0(OnPluginEnd)
	}

	Function fn_OnMapStart;
	void Call_OnMapStart()
	{
		CALL_FUNCTION_PARAM0(OnMapStart)
	}

	Function fn_OnMapEnd;
	void Call_OnMapEnd()
	{
		CALL_FUNCTION_PARAM0(OnMapEnd)
	}

	Function fn_OnClientPutInServer;
	void Call_OnClientPutInServer(int client)
	{
		CALL_FUNCTION_PARAM1(OnClientPutInServer, client, Cell)
	}

	Function fn_OnClientDisconnect;
	void Call_OnClientDisconnect(int client)
	{
		CALL_FUNCTION_PARAM1(OnClientDisconnect, client, Cell)
	}

	Function fn_ZR_OnClientInfected;
	void Call_ZR_OnClientInfected(int client)
	{
		CALL_FUNCTION_PARAM1(ZR_OnClientInfected, client, Cell)
	}

	Function fn_Event_RoundStart;
	void Call_Event_RoundStart()
	{
		CALL_FUNCTION_PARAM0(Event_RoundStart)
	}

	Function fn_Event_RoundEnd;
	void Call_Event_RoundEnd()
	{
		CALL_FUNCTION_PARAM0(Event_RoundEnd)
	}

	Function fn_Event_PlayerSpawn;
	void Call_Event_PlayerSpawn(int client)
	{
		CALL_FUNCTION_PARAM1(Event_PlayerSpawn, client, Cell)
	}

	Function fn_Event_PlayerTeam;
	void Call_Event_PlayerTeam(Event event)
	{
		CALL_FUNCTION_PARAM1(Event_PlayerTeam, event, Cell)
	}

	Function fn_Event_PlayerDeath;
	void Call_Event_PlayerDeath(int client)
	{
		CALL_FUNCTION_PARAM1(Event_PlayerDeath, client, Cell)
	}
	
	Function fn_OnTakeDamagePost;
	void Call_OnTakeDamagePost(int victim, int attacker, float damage)
	{
		CALL_FUNCTION_PARAM3(OnTakeDamagePost, victim, Cell, attacker, Cell, damage, Cell)
	}

	Function fn_OnTakeDamage;
	void Call_OnTakeDamage(int victim, int attacker, float damage, Action &result)
	{
		CALL_FUNCTION_PARAM4(OnTakeDamage, victim, Cell, attacker, Cell, damage, Cell, result, CellRef)
	}

	Function fn_OnWeaponEquip;
	void Call_OnWeaponEquip(int client, int weapon, Action &result)
	{
		CALL_FUNCTION_PARAM3(OnWeaponEquip, client, Cell, weapon, Cell, result, CellRef)
	}

	Function fn_OnPlayerRunCmdPost;
	void Call_OnPlayerRunCmdPost(int client, int buttons, int impulse)
	{
		CALL_FUNCTION_PARAM3(OnPlayerRunCmdPost, client, Cell, buttons, Cell, impulse, Cell)
	}
}
