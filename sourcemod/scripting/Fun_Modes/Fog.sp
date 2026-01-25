/*
    (). FunModes V2:
        
    @file           Fog.sp
    @Usage          Functions for the Fog mode.
*/

#pragma semicolon 1
#pragma newdecls required

ModeInfo g_FogInfo;

#undef THIS_MODE_INFO
#define THIS_MODE_INFO g_FogInfo

#define FOGInput_Color 0
#define FOGInput_Start 1
#define FOGInput_End 2
#define FOGInput_Toggle 3

enum struct fogData
{
	float fogStart;
	float fogEnd;
	int fogColor[4];
	
	void SetColor(int setColor[4])
	{
		this.fogColor[0] = setColor[0];
		this.fogColor[1] = setColor[1];
		this.fogColor[2] = setColor[2];
		this.fogColor[3] = setColor[3];
	}
}

fogData g_FogData;

int g_iFogEntity = -1;

#define FOG_CONVAR_TOGGLE 0

/* CALLED ON PLUGIN START */
stock void OnPluginStart_Fog()
{
	THIS_MODE_INFO.name = "Fog";
	THIS_MODE_INFO.tag = "{gold}[FunModes-FOG]{lightgreen}";

	RegAdminCmd("sm_fm_fog", Cmd_FogToggle, ADMFLAG_CONVARS, "Toggle fog on/off");
	RegAdminCmd("sm_fogmode", Cmd_FogSettings, ADMFLAG_CONVARS, "Fog Settings");
	RegAdminCmd("sm_fog_start", Cmd_FogStart, ADMFLAG_CONVARS, "Fog Start");
	RegAdminCmd("sm_fog_end", Cmd_FogEnd, ADMFLAG_CONVARS, "Fog End");

	DECLARE_FM_CVAR(
		THIS_MODE_INFO.cvarInfo, FOG_CONVAR_TOGGLE,
		"sm_fog_enable", "1", "Enable/Disable Fog Mode (This differs from turning it on/off)",
		("0,1"), "bool"
	);

	THIS_MODE_INFO.enableIndex = FOG_CONVAR_TOGGLE;
	
	THIS_MODE_INFO.index = g_iLastModeIndex++;
	g_ModesInfo[THIS_MODE_INFO.index] = THIS_MODE_INFO;

	THIS_MODE_INFO.cvarInfo[FOG_CONVAR_TOGGLE].cvar.AddChangeHook(OnFogModeToggle);	
}

void OnFogModeToggle(ConVar cvar, const char[] newValue, const char[] oldValue)
{
	if (THIS_MODE_INFO.isOn)
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, cvar.BoolValue, THIS_MODE_INFO.index);
}

stock void OnMapStart_Fog()
{
	g_FogData.fogStart 	= 50.0;
	g_FogData.fogEnd 	= 250.0;
	g_iFogEntity = -1;
}

stock void OnMapEnd_Fog()
{
	CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
	g_iFogEntity = -1;
}

stock void OnClientPutInServer_Fog(int client)
{
	#pragma unused client
}

stock void OnClientDisconnect_Fog(int client)
{
	#pragma unused client
}

stock void ZR_OnClientInfected_Fog(int client)
{
	#pragma unused client
}

stock void Event_RoundStart_Fog()
{
	if (!THIS_MODE_INFO.isOn)
		return;
	
	if(IsValidEntity(g_iFogEntity))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;

			SetVariantString("fog_mode_aaa34124n");
			AcceptEntityInput(i, "SetFogController");
		}

		return;
	}

	CreateFogEntity();
}

stock void Event_RoundEnd_Fog() {}
stock void Event_PlayerSpawn_Fog(int client)
{
	CreateTimer(1.0, PlayerSpawn_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

stock void Event_PlayerTeam_Fog(Event event)
{
	#pragma unused event
}

stock void Event_PlayerDeath_Fog(int client)
{
	#pragma unused client
}

Action PlayerSpawn_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client < 1 || !THIS_MODE_INFO.isOn)
		return Plugin_Stop;

	SetVariantString("fog_mode_aaa34124n");
	AcceptEntityInput(client, "SetFogController");
	return Plugin_Continue;
}

stock void CreateFogEntity()
{
	/* CHECK FOR ANY FOG MAP HAS */
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "env_fog_controller")) != -1)
	{
		if(entity == g_iFogEntity)
			continue;

		AcceptEntityInput(entity, "TurnOff");
	}

	char sColor[64];
	Format(sColor, sizeof(sColor), "%i %i %i %i", g_FogData.fogColor[0], g_FogData.fogColor[1], g_FogData.fogColor[2], g_FogData.fogColor[3]);
	
	if(IsValidEntity(g_iFogEntity))
		return;
	
	g_iFogEntity = CreateEntityByName("env_fog_controller");
	if(!IsValidEntity(g_iFogEntity))
		return;
	
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
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		SetVariantString("fog_mode_aaa34124n");
		AcceptEntityInput(i, "SetFogController");
	}
}

stock void AcceptFogInput(int mode)
{
	if(!IsValidEntity(g_iFogEntity))
		return;

	switch(mode)
	{
		case FOGInput_Color:
		{
			char sColor[64];
			Format(sColor, sizeof(sColor), "%i %i %i %i", g_FogData.fogColor[0], g_FogData.fogColor[1], g_FogData.fogColor[2], g_FogData.fogColor[3]);

			SetVariantString(sColor);
			AcceptEntityInput(g_iFogEntity, "SetColor");
		}
		case FOGInput_Start:
		{
			SetVariantFloat(g_FogData.fogStart);
			AcceptEntityInput(g_iFogEntity, "SetStartDist");
		}
		case FOGInput_End:
		{
			SetVariantFloat(g_FogData.fogEnd);
			AcceptEntityInput(g_iFogEntity, "SetEndDist");
		}
		case FOGInput_Toggle:
		{
			bool isOn = THIS_MODE_INFO.isOn;
			if(isOn)
				AcceptEntityInput(g_iFogEntity, "TurnOn");
			else
				AcceptEntityInput(g_iFogEntity, "TurnOff");
		}
	}
}

stock void Fog_DisplaySettingsMenu(int client)
{
	Menu menu = new Menu(FogSettings_Handler);

	char title[256];
	Format(title, sizeof(title), "FOG Settings\nTo change FOG Start Distance type: sm_fog_start <distance>\nTo change FOG End Distance type: sm_fog_end <distance>");
	menu.SetTitle(title);

	menu.AddItem("0", "Change FOG Color");

	char buffer[92];
	Format(buffer, sizeof(buffer), "%s FOG", THIS_MODE_INFO.isOn ? "TurnOff" : "TurnOn");
	menu.AddItem("3", buffer);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int FogSettings_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
				{
					Fog_DisplayColorsMenu(param1);
				}
				case 1:
				{
					bool isOn = THIS_MODE_INFO.isOn;
					if(isOn)
					{
						CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "Fog_Disabled", param1);
						CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
					}
					else
					{
						CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "Fog_Enabled", param1);
						CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, true, THIS_MODE_INFO.index);
					}

					AcceptFogInput(FOGInput_Toggle);
					Fog_DisplaySettingsMenu(param1);
				}
			}
		}
	}

	return 0;
}

stock void Fog_DisplayColorsMenu(int client)
{
	Menu menu = new Menu(FogColorsMenu_Handler);

	/* TO GET FOG COLOR */
	char colorName[64];
	for(int i = 0; i < sizeof(g_ColorsList); i++)
	{
		char buffers[3][5];
		ExplodeString(g_ColorsList[i].rgb, " ", buffers, 3, sizeof(buffers[]));
		
		int color[4];
		color[0] = StringToInt(buffers[0]);
		color[1] = StringToInt(buffers[1]);
		color[2] = StringToInt(buffers[2]);
		color[3] = 255;

		int fogColor[4];
		fogColor[0] = g_FogData.fogColor[0];
		fogColor[1] = g_FogData.fogColor[1];
		fogColor[2] = g_FogData.fogColor[2];
		fogColor[3] = g_FogData.fogColor[3];

		if(fogColor[0] == color[0] && fogColor[1] == color[1] && fogColor[2] == color[2] && fogColor[3] == color[3])
		{
			Format(colorName, sizeof(colorName), g_ColorsList[i].name);
			break;
		}
	}

	char title[256];
	Format(title, sizeof(title), "Change FOG Color\nCurrent Color: %s", colorName);
	menu.SetTitle(title);

	/* TO ADD ITEMS */
	for(int i = 0; i < sizeof(g_ColorsList); i++)
	{
		char index[3];
		IntToString(i, index, sizeof(index));
		menu.AddItem(index, g_ColorsList[i].name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int FogColorsMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				Fog_DisplaySettingsMenu(param1);
		}
		case MenuAction_Select:
		{
			if (!IsValidEntity(g_iFogEntity))
			{
				CPrintToChat(param1, "%s %t", THIS_MODE_INFO.tag, "Fog_EntityInvalid");
				return 0;
			}

			char info[3];
			menu.GetItem(param2, info, sizeof(info));
			
			int index = StringToInt(info);
			FM_Color myColor; 
			myColor = g_ColorsList[index];
			
			char buffers[3][5];
			ExplodeString(myColor.rgb, " ", buffers, 3, sizeof(buffers[]));
			
			int color[4];
			color[0] = StringToInt(buffers[0]);
			color[1] = StringToInt(buffers[1]);
			color[2] = StringToInt(buffers[2]);
			color[3] = 255;

			g_FogData.SetColor(color);

			AcceptFogInput(FOGInput_Color);

			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "Fog_ColorChange", param1, myColor.name, myColor.name);
			LogAction(param1, -1, "[FunModes-FOG] \"%L\" changed FOG color to \"%s\"", param1, myColor.name);
			Fog_DisplayColorsMenu(param1);
		}
	}

	return 0;
}

public Action Cmd_FogToggle(int client, int args)
{
	if (!THIS_MODE_INFO.cvarInfo[THIS_MODE_INFO.enableIndex].cvar.BoolValue)
	{
		CReplyToCommand(client, "%s Fog mode is currently disabled!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if(THIS_MODE_INFO.isOn)
	{
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, false, THIS_MODE_INFO.index);
		AcceptFogInput(FOGInput_Toggle);
		CReplyToCommand(client, "%s FOG Mode is now {olive}OFF!", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}
	else
	{
		CHANGE_MODE_INFO(THIS_MODE_INFO, isOn, true, THIS_MODE_INFO.index);
		FunModes_HookEvent(g_bEvent_RoundStart, "round_start", Event_RoundStart);
		FunModes_HookEvent(g_bEvent_PlayerSpawn, "player_spawn", Event_PlayerSpawn);
		CReplyToCommand(client, "%s FOG Mode is now {olive}ON!", THIS_MODE_INFO.tag);
		CreateFogEntity();
		return Plugin_Handled;
	}
}

Action Cmd_FogSettings(int client, int args)
{
	if(!client)
		return Plugin_Handled;

	Fog_DisplaySettingsMenu(client);
	return Plugin_Handled;
}

public Action Cmd_FogStart(int client, int args)
{
	if(args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_fog_start <distance>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));

	int distance;
	if(!StringToIntEx(arg, distance))
	{
		CReplyToCommand(client, "%s Invalid distance.", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if(distance == 0)
	{
		CReplyToCommand(client, "%s Distance cannot be 0", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	g_FogData.fogStart = float(distance);
	AcceptFogInput(FOGInput_Start);
	CReplyToCommand(client, "%s You have changed FOG Start Distance to %d", THIS_MODE_INFO.tag, distance);
	return Plugin_Handled;
}
	
Action Cmd_FogEnd(int client, int args)
{
	if(args < 1)
	{
		CReplyToCommand(client, "%s Usage: sm_fog_end <distance>", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));

	int distance;
	if(!StringToIntEx(arg, distance))
	{
		CReplyToCommand(client, "%s Invalid distance.", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if(distance == 0)
	{
		CReplyToCommand(client, "%s Distance cannot be 0", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	if(distance < g_FogData.fogStart)
	{
		CReplyToCommand(client, "%s End Distance has to be higher than Start one.", THIS_MODE_INFO.tag);
		return Plugin_Handled;
	}

	g_FogData.fogEnd = float(distance);
	AcceptFogInput(FOGInput_End);
	CReplyToCommand(client, "%s You have changed FOG End Distance to %d", THIS_MODE_INFO.tag, distance);
	return Plugin_Handled;	
}