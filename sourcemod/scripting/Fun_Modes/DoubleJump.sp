#pragma semicolon 1
#pragma newdecls required

#include <sdktools_functions>

/* CALLED on Plugin Start */
stock void PluginStart_DoubleJump() {
	/* ADMIN COMMANDS */
	RegAdminCmd("sm_fm_doublejump", Cmd_DoubleJump, ADMFLAG_CONVARS, "Enable/Disable Double Jump mode.");

	/* CONVARS HANDLES */
	g_cvDoubleJumpBoost			= CreateConVar("sm_doublejump_boost", "260", "The amount of vertical boost to apply to double jumps.", _, true, 260.0, true, 4095.0);
	g_cvDoubleJumpMaxJumps		= CreateConVar("sm_doublejump_max_jumps", "1", "How many re-jumps the player can do while he is in the air.");
	g_cvDoubleJumpHumansEnable 	= CreateConVar("sm_doublejump_humans", "1", "Enable/Disable Double jump for humans.");
	g_cvDoubleJumpZombiesEnable = CreateConVar("sm_doublejump_zombies", "0", "Enable/Disable Double jump for Zombies.");
}

Action Cmd_DoubleJump(int client, int args) {
	g_bIsDoubleJumpOn = !g_bIsDoubleJumpOn;
	CPrintToChatAll("%s Double Jump is now {olive}%s. %s", DoubleJump_Tag, (g_bIsDoubleJumpOn) ? "Enabled" : "Disabled",
													(g_bIsDoubleJumpOn) ? "You can re-jump while you are in the air." : "");
	
	if(g_bIsDoubleJumpOn) {
		CPrintToChatAll("%s Humans Double Jump: {olive}%s\n%s Zombies Double Jump: {olive}%s.", 
						DoubleJump_Tag, 
						(g_cvDoubleJumpHumansEnable.BoolValue) ? "Enabled" : "Disabled",
						DoubleJump_Tag,
						(g_cvDoubleJumpZombiesEnable.BoolValue) ? "Enabled" : "Disabled");
	}
					
	return Plugin_Handled;
}

/* SM DOUBLEJUMP 1.1.0, ALL CREDITS GO TO - https://forums.alliedmods.net/showpost.php?p=2759524&postcount=37 */
public Action OnPlayerRunCmd(int client, int& buttons)
{
	if(!g_bIsDoubleJumpOn) {
		return Plugin_Continue;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	if((!g_cvDoubleJumpHumansEnable.BoolValue && GetClientTeam(client) == CS_TEAM_CT) || 
		(!g_cvDoubleJumpZombiesEnable.BoolValue && GetClientTeam(client) == CS_TEAM_T)) {
			
		return Plugin_Continue;
	}
	
	static bool inGround;
	static bool inJump;
	static bool wasJump[MAXPLAYERS + 1];
	static bool landed[MAXPLAYERS + 1];
	
	inGround 	= !!(GetEntityFlags(client) & FL_ONGROUND);
	inJump 		= !!(GetClientButtons(client) & IN_JUMP);

	if(!landed[client])
	{
		if(g_cvDoubleJumpMaxJumps.IntValue) {
			static int jumps[MAXPLAYERS+1];
			if(inGround) {
				jumps[client] = 0;
			} else if(!wasJump[client] && inJump && jumps[client]++ <= g_cvDoubleJumpMaxJumps.IntValue) {
				ApplyNewJump(client);
			}
		} else if(!inGround && !wasJump[client] && inJump) {
			ApplyNewJump(client);
		}			
	}

	landed[client]	= inGround;
	wasJump[client]	= inJump;

	return Plugin_Continue;
}

stock void ApplyNewJump(int client)
{
	static float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	vel[2] = g_cvDoubleJumpBoost.FloatValue;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
}

stock void DoubleJump_GetConVars(ConVar cvars[4]) {
	cvars[0] = g_cvDoubleJumpBoost;
	cvars[1] = g_cvDoubleJumpMaxJumps;
	cvars[2] = g_cvDoubleJumpHumansEnable;
	cvars[3] = g_cvDoubleJumpZombiesEnable;
}
