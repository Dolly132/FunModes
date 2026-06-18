/*
    (). FunModes V2:
        
    @file           Core/ModesDefinition.sp
    @Usage          Modes definition, Any new mode that's added should also be declared and defined in this file.
*/

#pragma newdecls required
#pragma semicolon 1

/*
* Call specific mode functions with no param.
*
* @param %1		The name of the forward.
* @param %2		The name of the mode.
*/
#define CALL_MODE_FUNC(%1,%2) %1_%2()

/*
* Declares all available function calls for a forward with no param.
*
* @param %1		The name of the forward.
*/
#define DECLARE_FM_FORWARD(%1) \
		CALL_MODE_FUNC(%1, HealBeacon); \
		CALL_MODE_FUNC(%1, VIPMode); \
		CALL_MODE_FUNC(%1, Fog); \
		CALL_MODE_FUNC(%1, RLGL); \
		CALL_MODE_FUNC(%1, DoubleJump); \
		CALL_MODE_FUNC(%1, IC); \
		CALL_MODE_FUNC(%1, DamageGame); \
		CALL_MODE_FUNC(%1, BlindMode); \
		CALL_MODE_FUNC(%1, SlapMode); \
		CALL_MODE_FUNC(%1, ChaosWeapons); \
		CALL_MODE_FUNC(%1, GunGame); \
		CALL_MODE_FUNC(%1, MathGame); \
		CALL_MODE_FUNC(%1, CrazyShop); \
		CALL_MODE_FUNC(%1, RealityShift); \
		CALL_MODE_FUNC(%1, PullGame)

/*
* Call specific mode functions with 1 param.
*
* @param %1		The name of the forward.
* @param %2		The name of the mode.
* @param %3		The first param.
*/
#define CALL_MODE_FUNC_PARAM(%1,%2,%3) %1_%2(%3)

/*
* Declares all available function calls for a forward with 1 param.
*
* @param %1		The name of the forward.
* @param %2		The first param.
*/
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
* Call specific mode functions with 2 params.
*
* @param %1		The name of the forward.
* @param %2		The name of the mode.
* @param %3		The first param.
* @param %4		The second param.
*/
#define CALL_MODE_FUNC_PARAM2(%1,%2,%3,%4) %1_%2(%3,%4)

/*
* Declares all available function calls for a forward with 2 params. (Not used for now)
*
* @param %1		The name of the forward.
* @param %2		The first param.
* @param %3		The second param.
*/
/*
#define DECLARE_FM_FORWARD_PARAM2(%1,%2,%3) \
		CALL_MODE_FUNC_PARAM2(%1, HealBeacon, %2, %3); \ 
		CALL_MODE_FUNC_PARAM2(%1, VIPMode, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, RLGL, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, IC, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, Fog, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, DoubleJump, %2, %3); \
		CALL_MODE_FUNC_PARAM2(%1, DamageGame, %2, %3)
*/

/*
* Call specific mode functions with 3 params.
*
* @param %1		The name of the forward.
* @param %2		The name of the mode.
* @param %3		The first param.
* @param %4		The second param.
* @param %5		The third param.
*/
#define CALL_MODE_FUNC_PARAM3(%1,%2,%3,%4,%5) %1_%2(%3,%4,%5)

/*
* Declares all available function calls for a forward with 3 params.
*
* @param %1		The name of the forward.
* @param %2		The first param.
* @param %3		The second param.
* @param %4		The third param.
*/
#define DECLARE_FM_FORWARD_PARAM3(%1,%2,%3,%4) \
		CALL_MODE_FUNC_PARAM3(%1, VIPMode, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, DamageGame, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, GunGame, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, CrazyShop, %2, %3, %4)

/*
* Call specific mode functions with 4 params.
*
* @param %1		The name of the forward.
* @param %2		The name of the mode.
* @param %3		The first param.
* @param %4		The second param.
* @param %5		The third param.
* @param %6		The fourth param.
*/
#define CALL_MODE_FUNC_PARAM4(%1,%2,%3,%4,%5,%6) %1_%2(%3,%4,%5,%6)

/*
* Declares all available function calls for a forward with 4 params.
*
* @param %1		The name of the forward.
* @param %2		The first param.
* @param %3		The second param.
* @param %4		The third param.
* @param %5		The fourth param.
*/
#define DECLARE_FM_FORWARD_PARAM4(%1,%2,%3,%4,%5) \
		CALL_MODE_FUNC_PARAM4(%1, VIPMode, %2, %3, %4, %5); \
		CALL_MODE_FUNC_PARAM4(%1, CrazyShop, %2, %3, %4, %5)

/*
* Declares all available function calls for OnPlayerRunCmdPost.
*
* @param %1		The name of the forward.
* @param %2		The first param (client).
* @param %3		The second param (buttons).
* @param %4		The third param (impulse).
*/
#define DECLARE_ONPLAYERRUNCMD_POST(%1,%2,%3,%4) \
		CALL_MODE_FUNC_PARAM3(%1, DoubleJump, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, CrazyShop, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, PullGame, %2, %3, %4); \
		CALL_MODE_FUNC_PARAM3(%1, ChaosWeapons, %2, %3, %4)
