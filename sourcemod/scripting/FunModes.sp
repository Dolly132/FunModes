/*
    (). FunModes V2:
        
    @file           FunModes.sp
    @Usage          This is the main plugin file, it contains all the forwards.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <zombiereloaded>

#undef REQUIRE_PLUGIN
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#include "Fun_Modes/Core/Core.sp"

public Plugin myinfo =
{
	name = "FunModes",
	author = "Dolly",
	description = "bunch of fun modes for ze mode",
	version = "2.5.0",
	url = "https://nide.gg"
}

public void OnPluginStart()
{
	/* TRANSLATIONS LAODS */
	LoadTranslations("common.phrases");
	LoadTranslations("FunModes.phrases");

	/* HUD HANDLE */
	g_hHudMsg = CreateHudSynchronizer();

	g_cvHUDChannel = CreateConVar("sm_funmodes_hud_channel", "4", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);

	DECLARE_FM_FORWARD(OnPluginStart);

	DECLARE_FM_FORWARD(InitCvarsValues);

	AutoExecConfig();

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
			OnClientPutInServer(i);
	}
	
	static const char commands[][] = { "sm_fm_cvars", "sm_funmodes", "sm_funmode" };
	for(int i = 0; i < sizeof(commands); i++)
	{
		RegAdminCmd(commands[i], Cmd_FunModes, ADMFLAG_CONVARS, "Show all available funmodes");
	}

	RegAdminCmd("sm_fcvar", Cmd_FunModesCvars, ADMFLAG_CONVARS, "Change a FunModes cvar");

	g_iNetPropAmmoIndex = FindSendPropInfo("CBasePlayer", "m_iAmmo");
	if (g_iNetPropAmmoIndex == -1)
		SetFailState("[FunModes] Could not find offset `CBasePlayer::m_iAmmo`");
		
	GameData gd = new GameData("sdkhooks.games/engine.ep2v");
	if (gd == null)
		LogError("[FunModes] Could not find \"sdkhooks.games/engine.ep2v.txt\" file.");
	else
	{
		int offset = gd.GetOffset("Weapon_Switch");
		if (offset == -1)
		{
			delete gd;
			LogError("[FunModes] Could not find the offset of \"Weapon_Switch\", some features may be neglected");
			return;
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetVirtual(offset);
		
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
		
		g_hSwitchSDKCall = EndPrepSDKCall();
		
		if (g_hSwitchSDKCall == null)
			LogError("[FunModes] Incorrect offset for \"Weapon_Switch\", Cannot get a good SDKCall Handle");
	
		delete gd;
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		OnClientDisconnect(i);
	}
}

public void OnMapStart()
{
	g_LaserSprite = PrecacheModel("sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
	g_iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	PrecacheSound(Beacon_Sound, true);

	DECLARE_FM_FORWARD(OnMapStart);
}

public void OnMapEnd()
{
	DECLARE_FM_FORWARD(OnMapEnd);
}

public void OnClientPutInServer(int client)
{
	DECLARE_FM_FORWARD_PARAM(OnClientPutInServer, client);
}

public void OnClientDisconnect(int client)
{
	g_bSDKHook_OnTakeDamagePost[client] = false;
	g_bSDKHook_OnTakeDamage[client] = false;
	g_bSDKHook_WeaponEquip[client] = false;
	DECLARE_FM_FORWARD_PARAM(OnClientDisconnect, client);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect)
{		
	DECLARE_FM_FORWARD_PARAM(ZR_OnClientInfected, client);
	if (motherInfect && !g_bMotherZombie)
		g_bMotherZombie = true;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	g_bMotherZombie = false;
	DECLARE_FM_FORWARD(Event_RoundStart);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = true;
	g_bMotherZombie = false;
	DECLARE_FM_FORWARD(Event_RoundEnd);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	DECLARE_FM_FORWARD_PARAM(Event_PlayerSpawn, client);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	DECLARE_FM_FORWARD_PARAM(Event_PlayerTeam, event);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	DECLARE_FM_FORWARD_PARAM(Event_PlayerDeath, client);
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	DECLARE_FM_FORWARD_PARAM3(OnTakeDamagePost, victim, attacker, damage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD_PARAM4(OnTakeDamage, victim, attacker, damage, result);
	
	return result;
}

Action OnWeaponEquip(int client, int weapon)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD_PARAM3(OnWeaponEquip, client, weapon, result);
	
	return result;
}

/* Events Hooks functions */
void FunModes_HookEvent(bool &modeBool, const char[] name, EventHook callback)
{
	if (!modeBool)
	{
		modeBool = true;
		HookEvent(name, callback);
	}
}

void FunModes_RestartRound()
{
	// slay all players before terminating the round
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		ForcePlayerSuicide(i);
	}
	
	CS_TerminateRound(3.0, CSRoundEnd_Draw);
}

public void OnAllPluginsLoaded()
{
	g_bPlugin_DynamicChannels = LibraryExists("DynamicChannels");
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		g_bPlugin_DynamicChannels = false;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse)
{
	DECLARE_ONPLAYERRUNCMD_POST(OnPlayerRunCmdPost, client, buttons, impulse);
}

float GetDistanceBetween(int origin, int target, bool squarred = false)
{
	float fOrigin[3], fTarget[3];

	GetEntPropVector(origin, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", fTarget);

	return GetVectorDistance(fOrigin, fTarget, squarred);
}

stock void BeaconPlayer(int client, int mode, float distance = 0.0, int color[4] = {0,0,0,0})
{
	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	if (mode == 0)
	{
		TE_SetupBeamRingPoint(vec, (distance - 10.0), distance, g_LaserSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 0.0, color, 10, 0);
		TE_SendToAll();
	}
	else
	{
		TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, g_ColorCyan, 10, 0);
		TE_SendToAll();

		int rainbowColor[4];
		float f = GetGameTime();
		float frequency = 2.5;
		rainbowColor[0] = RoundFloat(Sine(frequency * f + 0.0) * 127.0 + 128.0);
		rainbowColor[1] = RoundFloat(Sine(frequency * f + 2.0943951) * 127.0 + 128.0);
		rainbowColor[2] = RoundFloat(Sine(frequency * f + 4.1887902) * 127.0 + 128.0);
		rainbowColor[3] = 255;

		TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

		TE_SendToAll();
		EmitAmbientSound(Beacon_Sound, vec, client, SNDLEVEL_RAIDSIREN);
	}
}

Action Cmd_FunModes(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	Menu menu = new Menu(Menu_MainModes);
	menu.SetTitle("[FunModes] Available modes!");

	for (int i = 0; i < g_iLastModeIndex; i++)
	{
		ModeInfo info;
		info = g_ModesInfo[i];

		char index[3];
		IntToString(i, index, sizeof(index));

		menu.AddItem(index, info.name);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Menu_MainModes(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char index[3];
			menu.GetItem(param2, index, sizeof(index));
			DisplayModeInfo(param1, StringToInt(index));
		}
	}
	
	return 0;
}

void DisplayModeInfo(int client, int modeIndex)
{
	g_iPreviousModeIndex[client] = modeIndex;

	Menu menu = new Menu(Menu_DisplayConVars);

	ModeInfo info;
	info = g_ModesInfo[modeIndex];

	FM_ConVar cvar;
	cvar = info.cvars[info.enableIndex];
	bool enabled = FUNMODES_CVAR_GET_VALUE(cvar, Bool);

	menu.SetTitle("%s - Mode Info\nStatus: %s - %s\n", info.name, enabled?"Enabled":"Disabled", info.isOn?"On":"Off");

	menu.AddItem(info.name, "Toggle", enabled?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem(info.name, "Settings");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_DisplayConVars(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_FunModes(param1, 0);
		}
		
		case MenuAction_Select:
		{
			char modeName[32];
			menu.GetItem(param2, modeName, sizeof(modeName));

			char functionName[46];
			FormatEx(functionName, sizeof(functionName), "Cmd_%s%s", modeName, (param2 == 0) ? "Toggle" : "Settings");

			Function myFunction = GetFunctionByName(null, functionName);
			if (myFunction == INVALID_FUNCTION)
				return -1;
				
			Call_StartFunction(null, myFunction);

			Call_PushCell(param1);
			Call_PushCell(0);
			
			Call_Finish();
			
			if (param2 == 0)
				DisplayModeInfo(param1, g_iPreviousModeIndex[param1]);
		}
	}

	return 0;
}

void ShowCvarsInfo(int client, ModeInfo info)
{
	g_iPreviousModeIndex[client] = info.index;

	info = g_ModesInfo[info.index];

	Menu menu = new Menu(Menu_CvarsInfo);

	menu.SetTitle("%s - ConVars List", info.name);

	for (int i = 0; i < sizeof(ModeInfo::cvars); i++)
	{
		if (!FUNMODES_CVAR_ISVALID(info.cvars[i]) || info.cvars[i].type == CONVAR_STRING)
			continue;

		char index[3];
		IntToString(i, index, sizeof(index));

		menu.AddItem(index, info.cvars[i].name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_CvarsInfo(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				DisplayModeInfo(param1, g_iPreviousModeIndex[param1]);
		}

		case MenuAction_Select:
		{
			char indexStr[3];
			menu.GetItem(param2, indexStr, sizeof(indexStr));

			ShowCvarInfo(param1, g_ModesInfo[g_iPreviousModeIndex[param1]].cvars[StringToInt(indexStr)]);
		}
	}

	return 0;
}

void ShowCvarInfo(int client, FM_ConVar thisCvarInfo)
{
	g_iPreviousModeIndex[client] = thisCvarInfo.modeIndex;

	Menu menu = new Menu(Menu_ShowCvarInfo);

	menu.SetTitle("%s\n- %s", thisCvarInfo.name, thisCvarInfo.description);

	int valsCount;
	for (int i = 0; i < sizeof(thisCvarInfo.values); i++)
	{
		if (thisCvarInfo.values[i] == ',')
			valsCount++;
	}

	valsCount++;

	char[][] dataEx = new char[valsCount][8];
	ExplodeString(thisCvarInfo.values, ",", dataEx, valsCount, 8);

	any currentVal = GetValFromCvar(thisCvarInfo, thisCvarInfo.type);

	bool currentValExists = false;
	for (int i = 0; i < valsCount; i++)
	{
		any val = GetValFromCvar(_, thisCvarInfo.type, dataEx[i]);
		if (val == currentVal)
			currentValExists = true;

		char data[22];
		FormatEx(data, sizeof(data), "%d|%d|%s", thisCvarInfo.modeIndex, thisCvarInfo.cvarIndex, dataEx[i]);

		menu.AddItem(data, dataEx[i], val == currentVal ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	if (!currentValExists)
		menu.AddItem(NULL_STRING, FUNMODES_CVAR_GET_VALUE(thisCvarInfo, String), ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_ShowCvarInfo(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowCvarsInfo(param1, g_ModesInfo[g_iPreviousModeIndex[param1]]);
		}

		case MenuAction_Select:
		{
			char data[100];
			menu.GetItem(param2, data, sizeof(data));
			
			char dataEx[3][22];
			ExplodeString(data, "|", dataEx, sizeof(dataEx), sizeof(dataEx[]));

			int modeIndex = StringToInt(dataEx[0]); 
			int cvarIndex = StringToInt(dataEx[1]);

			FM_ConVar cvar;
			cvar = g_ModesInfo[modeIndex].cvars[cvarIndex];
			FUNMODES_CVAR_SET_VALUE(cvar, String, dataEx[2]);

			// Just to avoid some random sourcemod bug...
			g_ModesInfo[modeIndex].cvars[cvarIndex] = cvar;

			CPrintToChat(param1, "{gold}[FunModes]{lightgreen} You have changed {olive}%s {lightgreen}value to {olive}%s.", cvar.name, dataEx[2]);

			ShowCvarInfo(param1, cvar);
		}
	}

	return 0;
}

any GetValFromCvar(FM_ConVar cvar = {}, ConVarType type, const char[] valStr = "")
{
	switch (type)
	{
		case CONVAR_INT: 	return (FUNMODES_CVAR_ISVALID(cvar)) ? FUNMODES_CVAR_GET_VALUE(cvar, Int) 	: StringToInt(valStr);
		case CONVAR_FLOAT: 	return (FUNMODES_CVAR_ISVALID(cvar)) ? FUNMODES_CVAR_GET_VALUE(cvar, Float) : StringToFloat(valStr);
		case CONVAR_BOOL: 	return (FUNMODES_CVAR_ISVALID(cvar)) ? FUNMODES_CVAR_GET_VALUE(cvar, Bool) 	: view_as<bool>(StringToInt(valStr));
	}

	return 0;
}

Action Cmd_FunModesCvars(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[FunModes] Usage: sm_fcvar <cvar> <value>");
		return Plugin_Handled;
	}

	char cvarName[sizeof(FM_ConVar::name)];
	GetCmdArg(1, cvarName, sizeof(cvarName));

	bool exists;
	FM_ConVar cvar;
	for (int i = 0; i < g_iLastModeIndex; i++)
	{
		if (exists)
			break;

		for (int j = 0; j < sizeof(ModeInfo::cvars); j++)
		{
			cvar = g_ModesInfo[i].cvars[j];
			if (!FUNMODES_CVAR_ISVALID(cvar))
				continue;

			if (strcmp(cvar.name, cvarName, false) != 0)
				continue;

			exists = true;
			break;
		}
	}

	if (!exists)
	{
		CReplyToCommand(client, "{gold}[FunModes]{lightgreen} Cannot find the specified cvar.");
		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "{gold}[FunModes]{lightgreen} %s value is: {olive}%s", cvar.name, FUNMODES_CVAR_GET_VALUE(cvar, String));
		return Plugin_Handled;
	}

	char newValue[sizeof(FM_ConVar::defaultValue)];
	GetCmdArg(2, newValue, sizeof(newValue));

	FUNMODES_CVAR_SET_VALUE(cvar, String, newValue);
	g_ModesInfo[cvar.modeIndex].cvars[cvar.cvarIndex] = cvar;

	CReplyToCommand(client, "{gold}[FunModes]{lightgreen} changed %s value to: {olive}%s", cvar.name, newValue);

	return Plugin_Handled;
}

stock void SendHudText(int client, const char[] message, bool isFar = false, int color = -1)
{
	static bool dynamicAvailable;
	int hudChannel = -1;

	if (!dynamicAvailable)
		dynamicAvailable = g_bPlugin_DynamicChannels && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;

	int channel = g_cvHUDChannel.IntValue;
	if (channel < 0 || channel > 5)
		channel = 4;

#if defined _DynamicChannels_included_
	if (dynamicAvailable)
		hudChannel = GetDynamicChannel(channel);
#endif

	if (isFar)
		SetHudTextParams(-0.2, 1.0, 0.7, 255, 13, 55, 255);
	else
		SetHudTextParams(-1.0, 0.1, 2.0, 255, 36, 255, 13);

	switch(color)
	{
		case 0:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 255, 36, 255, 13);
		}
		case 1:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 255, 0, 0, 50);
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.1, 2.0, 124, 252, 0, 50);
		}
	}

	if (dynamicAvailable)
	{
		ShowHudText(client, hudChannel, "%s", message);
		return;
	}

	ClearSyncHud(client, g_hHudMsg);
	ShowSyncHudText(client, g_hHudMsg, "%s", message);
}

public void OnConfigsExecuted()
{
	delete g_hKV;
	g_hKV = new KeyValues("FunModes_Cvars");

	if (!g_hKV.ImportFromFile(FUNMODES_CVAR_CONFIG))
	{
		delete g_hKV;
		return;
	}

	if (!g_hKV.GotoFirstSubKey())
	{
		delete g_hKV;
		return;
	}

	int modeIndex = 0;
	int cvarIndex = 0;
	int maxCvars = g_ModesInfo[modeIndex].GetCvarsCount();
	do
	{
		FM_ConVar cvar;
		cvar = g_ModesInfo[modeIndex].cvars[cvarIndex];

		char defaultValue[sizeof(FM_ConVar::defaultValue)];
		g_hKV.GetString("default", defaultValue, sizeof(defaultValue));
		if (!defaultValue[0])
			continue;

		cvar.defaultValue = defaultValue;

		cvar.autoChange = true;

		char currentValue[sizeof(FM_ConVar::currentValue)];
		g_hKV.GetString("currentvalue", currentValue, sizeof(currentValue));
		if (currentValue[0])			
			FUNMODES_CVAR_SET_VALUE(cvar, String, currentValue);
		else
			FUNMODES_CVAR_SET_VALUE(cvar, String, defaultValue);

		cvar.autoChange = false;

		char description[sizeof(FM_ConVar::description)];
		g_hKV.GetString("description", description, sizeof(description));
		cvar.description = description;

		char values[sizeof(FM_ConVar::values)];
		g_hKV.GetString("values", values, sizeof(values));
		if (values[0])
			cvar.values = values;

		g_ModesInfo[modeIndex].cvars[cvarIndex] = cvar;

		if (++cvarIndex >= maxCvars || ++modeIndex >= g_iLastModeIndex)
			break;

		maxCvars = g_ModesInfo[modeIndex].GetCvarsCount();
	} while (g_hKV.GotoNextKey());

	g_hKV.Rewind();
}
