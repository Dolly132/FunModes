#pragma semicolon 1
#pragma newdecls required

/* CALLED ON PLUGIN START */
stock void PluginStart_IC() {
	static const char commands[][] = {
		"sm_invertedcon",
		"sm_invertcon",
		"sm_invertedcontrols",
		"sm_fm_ic"
	};
	
	for(int i = 0; i < sizeof(commands); i++) {
		RegAdminCmd(commands[i], Cmd_IC, ADMFLAG_CONVARS, "Enable/Disable Inverted controls");
	}
}

Action Cmd_IC(int client, int args) {
	ConVar cvar = FindConVar("sv_accelerate");
	if(cvar == null) {
		// it should never happen though
		return Plugin_Handled;
	}
	
	if(cvar.IntValue == -5) {
		CPrintToChatAll("%s Inverted Controls is now {olive}Disabled!", IC_TAG);
		cvar.IntValue = 5;
		delete cvar;
		return Plugin_Handled;
	}
	
	CPrintToChatAll("%s Inverted Controls is now {olive}Enabled!", IC_TAG);
	cvar.IntValue = -5;
	delete cvar;
	return Plugin_Handled;
}
