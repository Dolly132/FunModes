/*
    (). FunModes V2:
        
    @file           Core/ModesInclude.sp
    @Usage          Modes Include, Any new mode that's added should be included to the plugin by this file.
*/

#pragma newdecls required
#pragma semicolon 1

/* For the existing FunModes, you can remove or comment the line where it includes the mode file if you want get rid of it. */
#include "../HealBeacon.sp"
#include "../VIPMode.sp"
#include "../Fog.sp"
#include "../RedLightGreenLight.sp"
#include "../DoubleJump.sp"
#include "../InvertedControls.sp"
#include "../DamageGame.sp"
#include "../BlindMode.sp"
#include "../SlapMode.sp"
#include "../ChaosWeapons.sp"
#include "../GunGame.sp"
#include "../MathGame.sp"
#include "../CrazyShop.sp"
#include "../RealityShift.sp"
#include "../PullGame.sp"

/*
* Called on plugin start, kindly put your new mode's OnPluginStart call here if you are willing to add a new mode.
*
* @noparams
*/
public void Forwards_OnPluginStart()
{
#if defined _FM_HealBeacon
    OnPluginStart_HealBeacon();
#endif

#if defined _FM_VIPMode
    OnPluginStart_VIPMode();
#endif

#if defined _FM_Fog
    OnPluginStart_Fog();
#endif

#if defined _FM_RLGL
    OnPluginStart_RLGL();
#endif

#if defined _FM_DoubleJump
    OnPluginStart_DoubleJump();
#endif

#if defined _FM_IC
    OnPluginStart_IC();
#endif

#if defined _FM_DamageGame
    OnPluginStart_DamageGame();
#endif

#if defined _FM_BlindMode
    OnPluginStart_BlindMode();
#endif

#if defined _FM_SlapMode
    OnPluginStart_SlapMode();
#endif

#if defined _FM_ChaosWeapons
    OnPluginStart_ChaosWeapons();
#endif

#if defined _FM_GunGame
    OnPluginStart_GunGame();
#endif

#if defined _FM_MathGame
    OnPluginStart_MathGame();
#endif

#if defined _FM_CrazyShop
    OnPluginStart_CrazyShop();
#endif

#if defined _FM_RealityShift
    OnPluginStart_RealityShift();
#endif

#if defined _FM_PullGame
    OnPluginStart_PullGame();
#endif
}
