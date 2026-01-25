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

#include "Fun_Modes/Core.sp"

public Plugin myinfo =
{
	name = "FunModes",
	author = "Dolly",
	description = "bunch of fun modes for ze mode",
	version = "2.0.0",
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
	
	GameData gd = new GameData("sdkhooks.games/engine.ep2v");
	if (gd == null)
		LogError("[FunModes] Could not find \"sdkhooks.games/engine.ep2v.txt\" file.");
	else
	{
		int offset = gd.GetOffset("Weapon_Switch");
		if (offset == -1)
		{
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
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bSDKHook_OnTakeDamagePost[i] = false;
		g_bSDKHook_WeaponEquip[i] = false;
		g_bSDKHook_OnTakeDamage[i] = false;
	}

	DECLARE_FM_FORWARD(OnMapEnd);
}

public void OnClientPutInServer(int client)
{
	DECLARE_FM_FORWARD_PARAM(OnClientPutInServer, client);
}

public void OnClientDisconnect(int client)
{
	g_bSDKHook_OnTakeDamagePost[client] = false;
	g_bSDKHook_WeaponEquip[client] = false;
	g_bSDKHook_OnTakeDamage[client] = false;
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

Action OnWeaponEquip(int client, int weapon)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD_PARAM3(OnWeaponEquip, client, weapon, result);
	
	return result;
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Action result = Plugin_Continue;
	
	DECLARE_FM_FORWARD_PARAM4(OnTakeDamage, victim, attacker, damage, result);
	
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
	float fvec[3];
	GetClientAbsOrigin(client, fvec);
	fvec[2] += 10;

	if (mode == 0)
	{
		TE_SetupBeamRingPoint(fvec, (distance - 10.0), distance, g_LaserSprite, g_HaloSprite, 0, 15, 0.1, 10.0, 0.0, color, 10, 0);
		TE_SendToAll();
	}
	else if (mode == 1)
	{
		TE_SetupBeamRingPoint(fvec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, g_ColorCyan, 10, 0);
		TE_SendToAll();

		int rainbowColor[4];
		float i = GetGameTime();
		float Frequency = 2.5;
		rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
		rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
		rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
		rainbowColor[3] = 255;

		TE_SetupBeamRingPoint(fvec, 10.0, 375.0, g_LaserSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

		TE_SendToAll();
		EmitAmbientSound(Beacon_Sound, fvec, client, SNDLEVEL_RAIDSIREN);
	}
}

void GiveGrenadesToClient(int client, WeaponAmmoGrenadeType type, int amount)
{
	int ammo = FindSendPropInfo("CBasePlayer", "m_iAmmo");
	if (ammo != -1)
	{
		int grenadesCount = GetEntData(client, ammo + (view_as<int>(type) * 4));
		SetEntData(client, ammo + (view_as<int>(type) * 4), grenadesCount + amount, _, true);
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
		{
			delete menu;
		}
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
	
	bool enabled = info.cvarInfo[info.enableIndex].cvar.BoolValue;
	
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
	Menu menu = new Menu(Menu_CvarsInfo);

	menu.SetTitle("%s - ConVars List", info.name);

	for (int i = 0; i < sizeof(ModeInfo::cvarInfo); i++)
	{
		if (info.cvarInfo[i].cvar == null || info.cvarInfo[i].type[0] == '\0')
			continue;

		char index[3];
		IntToString(i, index, sizeof(index));

		char cvarName[64];
		info.cvarInfo[i].cvar.GetName(cvarName, sizeof(cvarName));

		menu.AddItem(index, cvarName);
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

			ShowCvarInfo(param1, g_ModesInfo[g_iPreviousModeIndex[param1]].cvarInfo[StringToInt(indexStr)]);
		}
	}
	
	return 0;
}

void ShowCvarInfo(int client, ConVarInfo thisCvarInfo)
{
	Menu menu = new Menu(Menu_ShowCvarInfo);
	
	char convarName[32];
	thisCvarInfo.cvar.GetName(convarName, sizeof(convarName));
	
	char convarDescription[120];
	thisCvarInfo.cvar.GetDescription(convarDescription, sizeof(convarDescription));
	
	char title[sizeof(convarName) + sizeof(convarDescription) + 2];
	FormatEx(title, sizeof(title), "%s\n%s", convarName, convarDescription);
	menu.SetTitle(title);
	
	int valsCount;
	for (int i = 0; i < sizeof(thisCvarInfo.values); i++)
	{
		if (thisCvarInfo.values[i] == ',')
			valsCount++;
	}

	valsCount++;
	
	char[][] dataEx = new char[valsCount][8];
	ExplodeString(thisCvarInfo.values, ",", dataEx, valsCount, 8);
	
	any currentVal = GetValFromCvar(thisCvarInfo.cvar, thisCvarInfo.type);

	bool currentValExists = false;
	for (int i = 0; i < valsCount; i++)
	{
		any val = GetValFromCvar(null, thisCvarInfo.type, dataEx[i]);
		if (val == currentVal) {
			currentValExists = true;
		}
		
		char data[100];
		FormatEx(data, sizeof(data), "%d|%s|%s|%s", view_as<int>(thisCvarInfo.cvar), dataEx[i], thisCvarInfo.type, thisCvarInfo.values);
		
		menu.AddItem(data, dataEx[i], val == currentVal ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	if (!currentValExists)
	{
		char val[10];
		thisCvarInfo.cvar.GetString(val, sizeof(val));
		menu.AddItem(NULL_STRING, val, ITEMDRAW_DISABLED);
	}

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
			
			char dataEx[4][22];
			ExplodeString(data, "|", dataEx, 4, 22);
			
			ConVar cvar = view_as<ConVar>(StringToInt(dataEx[0]));
			SetCvarVal(cvar, dataEx[2], dataEx[1]);
			
			char cvarName[32];
			cvar.GetName(cvarName, sizeof(cvarName));
			CPrintToChat(param1, "{gold}[FunModes]{lightgreen} You have changed {olive}%s {lightgreen}value to {olive}%s.", cvarName, dataEx[1]);
			
			ConVarInfo info;
			info.cvar = cvar;
			strcopy(info.values, sizeof(ConVarInfo::values), dataEx[3]);
			strcopy(info.type, sizeof(ConVarInfo::type), dataEx[2]);
			
			ShowCvarInfo(param1, info);
		}
	}
	
	return 0;
}

void SetCvarVal(ConVar cvar, const char[] type, const char[] valStr)
{
	if (strcmp(type, "int") == 0)
		cvar.IntValue = StringToInt(valStr);
	
	else if (strcmp(type, "float") == 0)
		cvar.FloatValue = StringToFloat(valStr);

	else if (strcmp(type, "bool") == 0)
		cvar.BoolValue = view_as<bool>(StringToInt(valStr));
}

any GetValFromCvar(ConVar cvar = null, const char[] type, const char[] valStr = "")
{	
	if (strcmp(type, "int") == 0)
	{
		if (cvar != null)
			return cvar.IntValue;
		else
			return StringToInt(valStr);
	}
	else if (strcmp(type, "float") == 0)
	{
		if (cvar != null)
			return cvar.FloatValue;
		else
			return StringToFloat(valStr);
	}

	else if (strcmp(type, "bool") == 0)
	{
		if (cvar != null)
			return cvar.BoolValue;
		else
			return view_as<bool>(StringToInt(valStr));
	}	
	
	return 0;
}

stock void SendHudText(int client, const char[] sMessage, bool isFar = false, int icolor = -1)
{
	bool bDynamicAvailable = false;
	int iHUDChannel = -1;

	int iChannel = g_cvHUDChannel.IntValue;
	if (iChannel < 0 || iChannel > 5) {
		iChannel = 4;
	}

	bDynamicAvailable = g_bPlugin_DynamicChannels && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;

#if defined _DynamicChannels_included_
	if (bDynamicAvailable)
		iHUDChannel = GetDynamicChannel(iChannel);
#endif

	if (isFar)
		SetHudTextParams(-0.2, 1.0, 0.7, 255, 13, 55, 255);
	else
		SetHudTextParams(-1.0, 0.1, 2.0, 255, 36, 255, 13);

	switch(icolor)
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

	if (bDynamicAvailable)
	{
		ShowHudText(client, iHUDChannel, "%s", sMessage);
	}
	else
	{
		ClearSyncHud(client, g_hHudMsg);
		ShowSyncHudText(client, g_hHudMsg, "%s", sMessage);
	}
}