#pragma semicolon 1
#pragma newdecls required

/* CALLED ON PLUGIN START */
stock void PluginStart_Fog() {
	RegAdminCmd("sm_fm_fog", Cmd_FogEnable, ADMFLAG_CONVARS, "Enable/Disable fog");
	RegAdminCmd("sm_fogmode", Cmd_FogSettings, ADMFLAG_CONVARS, "Fog Settings");
	RegAdminCmd("sm_fog_start", Cmd_FogStart, ADMFLAG_CONVARS, "Fog Start");
	RegAdminCmd("sm_fog_end", Cmd_FogEnd, ADMFLAG_CONVARS, "Fog End");
}

stock void PlayerSpawn_Fog(int userid) {
	CreateTimer(1.0, PlayerSpawn_Timer, userid);
}

Action PlayerSpawn_Timer(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if(client < 1 || !g_FogData.fogEnable) {
		return Plugin_Stop;
	}
	
	SetVariantString("fog_mode_aaa34124n");
	AcceptEntityInput(client, "SetFogController");
	return Plugin_Continue;
}

stock void RoundStart_Fog() {
	if(!g_FogData.fogEnable) {
		return;
	}
		
	if(IsValidEntity(g_iFogEntity)) {
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i)) {
				continue;
			}
			
			SetVariantString("fog_mode_aaa34124n");
			AcceptEntityInput(i, "SetFogController");
		}
		
		return;
	}
	
	CreateFogEntity();
}

stock void CreateFogEntity() {
	/* CHECK FOR ANY FOG MAP HAS */
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "env_fog_controller")) != -1) {
		if(entity == g_iFogEntity) {
			continue;
		}
		
		AcceptEntityInput(entity, "TurnOff");
	}
	
	char sColor[64];
	Format(sColor, sizeof(sColor), "%i %i %i %i", g_FogData.fogColor[0], g_FogData.fogColor[1], g_FogData.fogColor[2], g_FogData.fogColor[3]);
	
	if(IsValidEntity(g_iFogEntity)) {
		return;
	}
	
	g_iFogEntity = CreateEntityByName("env_fog_controller");
	if(!IsValidEntity(g_iFogEntity)) {
		return;
	}
	
	DispatchKeyValue(g_iFogEntity, "targetname", "fog_mode_aaa34124n");
	DispatchKeyValue(g_iFogEntity, "fogenable", "1");
	DispatchKeyValue(g_iFogEntity, "fogblend", "1");
	DispatchKeyValueFloat(g_iFogEntity, "fogstart", g_FogData.fogStart);
	DispatchKeyValueFloat(g_iFogEntity, "fogend", g_FogData.fogEnd);
	DispatchKeyValueFloat(g_iFogEntity, "fogmaxdensity", 1.0);
	DispatchKeyValue(g_iFogEntity, "fogcolor", sColor);
	DispatchKeyValue(g_iFogEntity, "fogcolor2", "255 255 255 255");
	
	DispatchSpawn(g_iFogEntity);
	AcceptEntityInput(g_iFogEntity, "TurnOn");
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		SetVariantString("fog_mode_aaa34124n");
		AcceptEntityInput(i, "SetFogController");
	}
}

stock void AcceptFogInput(int mode) {
	if(!IsValidEntity(g_iFogEntity)) {
		return;
	}
	
	switch(mode) {
		case FOGInput_Color: {
			char sColor[64];
			Format(sColor, sizeof(sColor), "%i %i %i %i", g_FogData.fogColor[0], g_FogData.fogColor[1], g_FogData.fogColor[2], g_FogData.fogColor[3]);
			
			SetVariantString(sColor);
			AcceptEntityInput(g_iFogEntity, "SetColor");
		}
		
		case FOGInput_Start: {
			SetVariantFloat(g_FogData.fogStart);
			AcceptEntityInput(g_iFogEntity, "SetStartDist");
		}
		
		case FOGInput_End: {
			SetVariantFloat(g_FogData.fogEnd);
			AcceptEntityInput(g_iFogEntity, "SetEndDist");
		}
		
		case FOGInput_Toggle: {
			bool isOn = g_FogData.fogEnable;
			if(isOn) {
				AcceptEntityInput(g_iFogEntity, "TurnOn");
			}
			else {
				AcceptEntityInput(g_iFogEntity, "TurnOff");
			}
		}
	}
}

stock void Fog_DisplaySettingsMenu(int client) {
	Menu menu = new Menu(FogSettings_Handler);
	
	char title[256];
	Format(title, sizeof(title), "FOG Settings\nTo change FOG Start Distance type: sm_fog_start <distance>\nTo change FOG End Distance type: sm_fog_end <distance>");
	menu.SetTitle(title);
	
	menu.AddItem("0", "Change FOG Color");
	
	char buffer[92];
	Format(buffer, sizeof(buffer), "%s FOG", g_FogData.fogEnable ? "TurnOff" : "TurnOn");
	menu.AddItem("3", buffer);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int FogSettings_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_End: {
			delete menu;
		}
		
		case MenuAction_Select: {
			switch(param2) {
				case 0: {
					Fog_DisplayColorsMenu(param1);
				}
				
				case 1: {
					bool isOn = g_FogData.fogEnable;
					if(isOn) {
						CPrintToChat(param1, "%s %T", Fog_Tag, "Fog_Disabled", param1);
						g_FogData.fogEnable = false;
					}
					else {
						CPrintToChat(param1, "%s %T", Fog_Tag, "Fog_Enabled", param1);
						g_FogData.fogEnable = true;
					}
					
					AcceptFogInput(FOGInput_Toggle);
				}
			}
		}
	}
	
	return 0;
}

stock void Fog_DisplayColorsMenu(int client) {
	Menu menu = new Menu(FogColorsMenu_Handler);
	
	/* TO GET FOG COLOR */
	char colorName[64];
	for(int i = 0; i < sizeof(colorsList); i++) {
		char buffers[5][64];
		ExplodeString(colorsList[i], " ", buffers, 5, sizeof(buffers[]));
		int color[4];
		color[0] = StringToInt(buffers[0]);
		color[1] = StringToInt(buffers[1]);
		color[2] = StringToInt(buffers[2]);
		color[3] = StringToInt(buffers[3]);
		
		int fogColor[4];
		fogColor[0] = g_FogData.fogColor[0];
		fogColor[1] = g_FogData.fogColor[1];
		fogColor[2] = g_FogData.fogColor[2];
		fogColor[3] = g_FogData.fogColor[3];
		
		if(fogColor[0] == color[0] && fogColor[1] == color[1] && fogColor[2] == color[2] && fogColor[3] == color[3]) {
			Format(colorName, sizeof(colorName), buffers[4]);
			break;
		}
	}
	
	char title[256];
	Format(title, sizeof(title), "Change FOG Color\nCurrent Color: %s", colorName);
	menu.SetTitle(title);
	
	/* TO ADD ITEMS */
	for(int i = 0; i < sizeof(colorsList); i++) {
		char buffers[5][64];
		ExplodeString(colorsList[i], " ", buffers, 5, sizeof(buffers[]));
		menu.AddItem(colorsList[i], buffers[4]);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int FogColorsMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_End: {
			delete menu;
		}
		
		case MenuAction_Cancel: {
			if(param2 == MenuCancel_ExitBack) {
				Fog_DisplaySettingsMenu(param1);
			}
		}
		
		case MenuAction_Select: {
			if(!IsValidEntity(g_iFogEntity)) {
				CPrintToChat(param1, "%s %T", Fog_Tag, "Fog_EntityInvalid", param1);
				return 0;
			}
			
			char info[128];
			menu.GetItem(param2, info, sizeof(info));
			
			char buffers[5][64];
			ExplodeString(info, " ", buffers, 5, sizeof(buffers[]));
			int color[4];
			color[0] = StringToInt(buffers[0]);
			color[1] = StringToInt(buffers[1]);
			color[2] = StringToInt(buffers[2]);
			color[3] = StringToInt(buffers[3]);
			
			g_FogData.SetColor(color);
			
			AcceptFogInput(FOGInput_Color);
			
			CPrintToChat(param1, "%s %T", Fog_Tag, "Fog_ColorChange", param1, buffers[4], buffers[4]);
			LogAction(param1, -1, "[FunModes-FOG] \"%L\" changed FOG color to \"%s\"", param1, buffers[4]);
		}
	}
	
	return 0;
}

Action Cmd_FogEnable(int client, int args) {
	if(g_FogData.fogEnable) {
		g_FogData.fogEnable = false;
		AcceptFogInput(FOGInput_Toggle);
		CReplyToCommand(client, "%s FOG Mode is now {olive}OFF!", Fog_Tag);
		return Plugin_Handled;
	}
	else {
		g_FogData.fogEnable = true;
		CReplyToCommand(client, "%s FOG Mode is now {olive}ON!", Fog_Tag);
		CreateFogEntity();
		return Plugin_Handled;
	}
}

Action Cmd_FogSettings(int client, int args) {
	if(!client) {
		return Plugin_Handled;
	}
	
	Fog_DisplaySettingsMenu(client);
	return Plugin_Handled;
}

Action Cmd_FogStart(int client, int args) {
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_fog_start <distance>", Fog_Tag);
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	int distance;
	if(!StringToIntEx(arg, distance)) {
		CReplyToCommand(client, "%s Invalid distance.", Fog_Tag);
		return Plugin_Handled;
	}
	
	if(distance == 0) {
		CReplyToCommand(client, "%s Distance cannot be 0", Fog_Tag);
		return Plugin_Handled;
	}
	
	g_FogData.fogStart = float(distance);
	AcceptFogInput(FOGInput_Start);
	CReplyToCommand(client, "%s You have changed FOG Start Distance to %d", Fog_Tag, distance);
	return Plugin_Handled;
}
	
Action Cmd_FogEnd(int client, int args) {
	if(args < 1) {
		CReplyToCommand(client, "%s Usage: sm_fog_end <distance>", Fog_Tag);
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	int distance;
	if(!StringToIntEx(arg, distance)) {
		CReplyToCommand(client, "%s Invalid distance.", Fog_Tag);
		return Plugin_Handled;
	}
	
	if(distance == 0) {
		CReplyToCommand(client, "%s Distance cannot be 0", Fog_Tag);
		return Plugin_Handled;
	}
	
	if(distance < g_FogData.fogStart) {
		CReplyToCommand(client, "%s End Distance has to be higher than Start one.", Fog_Tag);
		return Plugin_Handled;
	}
	
	g_FogData.fogEnd = float(distance);
	AcceptFogInput(FOGInput_End);
	CReplyToCommand(client, "%s You have changed FOG End Distance to %d", Fog_Tag, distance);
	return Plugin_Handled;	
}
