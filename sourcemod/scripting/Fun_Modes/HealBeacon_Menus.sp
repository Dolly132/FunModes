/*
    (). FunModes V2:
        
    @file           HealBeacon_Menus.sp
    @Usage          Menu Functions for the HealBeacon mode.
*/

#pragma semicolon 1
#pragma newdecls required

int g_iClientMenuUserId[MAXPLAYERS + 1] = { -1, ... };

stock void HealBeacon_DisplayMainMenu(int client)
{
	Menu menu = new Menu(MainMenu_Handler);
	menu.SetTitle("Do Actions on the heal beaconed players");

	int count = 0;
	for(int i = 0; i < g_aHBPlayers.Length; i++)
	{
		int random = g_aHBPlayers.Get(i);
		if (!IsClientInGame(random) || !IsPlayerAlive(random))
			continue;

		char info[32], buffer[64];
		Format(info, sizeof(info), "%d", GetClientUserId(random));
		Format(buffer, sizeof(buffer), "%N", random);

		menu.AddItem(info, buffer);
		count++;
	}

	if(count <= 0)
		menu.AddItem("", "None", ITEMDRAW_DISABLED);
	
	menu.AddItem("option2", "Change Heal Beacon Settings");

	menu.Display(client, MENU_TIME_FOREVER);
	menu.ExitButton = true;
}

public int MainMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char buffer[64];
			menu.GetItem(param2, buffer, sizeof(buffer));
			if(strcmp(buffer, "option2") == 0)
			{
				HealBeacon_DisplaySettingsMenu(param1);
				return 0;
			}

			int userid = StringToInt(buffer);
			int random = GetClientOfUserId(userid);
			if (!random)
			{
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
				return 0;
			}

			if(!g_BeaconPlayersData[random].hasHealBeacon)
			{
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIsNot", param1);
				return 0;
			}

			/* save the heal beacon player's userid in the param1 variable so we can get it for later */
			HealBeacon_DisplayActionsMenu(param1, random);
		}
	}

	return 0;
}

/* THE SETTINGS MENUS */
stock void HealBeacon_DisplaySettingsMenu(int client)
{
	Menu menu = new Menu(SettingsMenu_Handler);
	char title[64];
	Format(title, sizeof(title), "Change Heal Beacon Settings");
	menu.SetTitle(title);

	menu.AddItem("0", "Change Heal Beacon Damage");
	menu.AddItem("1", "Change Heal Beacon Heal Per second");
	menu.AddItem("2", "Change The first pick timer");
	menu.AddItem("3", "Toggle better damage mode");
	menu.AddItem("4", "Change Heal Beacon Default Color");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int SettingsMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
				HealBeacon_DisplayMainMenu(param1);
		}

		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
				{
					HealBeacon_DisplayBeaconDamageMenu(param1);
				}
				case 1:
				{
					HealBeacon_DisplayBeaconHealMenu(param1);
				}
				case 2:
				{
					HealBeacon_DisplayBeaconTimerMenu(param1);
				}
				case 3:
				{
					if(g_bIsBetterDamageModeOn)
					{
						g_bIsBetterDamageModeOn = false;
						CPrintToChat(param1, "%s Better Damage Mode is now {olive}OFF!", THIS_MODE_INFO.tag);
					}
					else
					{
						g_bIsBetterDamageModeOn = true;
						CPrintToChat(param1, "%s Better Damage Mode is now {olive}ON!", THIS_MODE_INFO.tag);
					}
				}
				case 4:
				{
					HealBeacon_DisplayBeaconDefaultColorMenu(param1);
				}
			}
		}
	}

	return 0;
}

/* BEACON DAMAGE MENU */
stock void HealBeacon_DisplayBeaconDamageMenu(int client)
{
	Menu menu = new Menu(BeaconDamageMenu_Handler);
	char title[256];
	Format(title, sizeof(title), "Change Heal Beacon Damage\nYou can also change the cvar sm_beacon_damage\nincase you didnt find the good\ndamage in the list\nCurrent HealBeacon Damage: %.2f", THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_DAMAGE].cvar.FloatValue);
	menu.SetTitle(title);

	menu.AddItem("1", "1");
	menu.AddItem("2", "2");
	menu.AddItem("5", "5");
	menu.AddItem("7", "7");
	menu.AddItem("8", "8");
	menu.AddItem("10", "10");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BeaconDamageMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
				HealBeacon_DisplaySettingsMenu(param1);
		}
		case MenuAction_Select:
		{
			char buffer[32];
			menu.GetItem(param2, buffer, sizeof(buffer));
			int num = StringToInt(buffer);

			THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_DAMAGE].cvar.FloatValue = float(num);
			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_DamageChange", param1, num);
			HealBeacon_DisplayBeaconDamageMenu(param1);
		}
	}

	return 0;
}

/* BEACON HEAL MENU */
stock void HealBeacon_DisplayBeaconHealMenu(int client)
{
	Menu menu = new Menu(BeaconHealMenu_Handler);
	char title[256];
	Format(title, sizeof(title), "Change Heal Beacon Heal per second\nYou can also change the cvar sm_beacon_heal\nincase you didnt find the good\nheal in the list\nCurrent HealBeacon Heal: %d", THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_HEAL].cvar.IntValue);
	menu.SetTitle(title);

	for(int i = 1; i <= 7; i++)
	{
		char buffer[5];
		Format(buffer, sizeof(buffer), "%d", i);
		menu.AddItem(buffer, buffer);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BeaconHealMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
				HealBeacon_DisplaySettingsMenu(param1);
		}
		case MenuAction_Select:
		{
			char buffer[32];
			menu.GetItem(param2, buffer, sizeof(buffer));
			int num = StringToInt(buffer);
	
			THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_HEAL].cvar.IntValue = num;
			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_HealChange", param1, num);
			HealBeacon_DisplayBeaconHealMenu(param1);
		}
	}

	return 0;
}

/* BEACON TIMER MENU */
stock void HealBeacon_DisplayBeaconTimerMenu(int client)
{
	Menu menu = new Menu(BeaconTimerMenu_Handler);
	char title[256];
	Format(title, sizeof(title), "Change Heal Beacon Timer\nIt means how many seconds it will start\npicking random players for healbeacon\nafter round start");
	menu.SetTitle(title);

	menu.AddItem("10", "10");
	menu.AddItem("20", "20");
	menu.AddItem("25", "25");
	menu.AddItem("30", "30");
	menu.AddItem("40", "40");
	menu.AddItem("60", "60");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BeaconTimerMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
				HealBeacon_DisplaySettingsMenu(param1);
		}
		case MenuAction_Select:
		{
			char buffer[32];
			menu.GetItem(param2, buffer, sizeof(buffer));
			int num = StringToInt(buffer);

			THIS_MODE_INFO.cvarInfo[HB_CONVAR_BEACON_TIMER].cvar.FloatValue = float(num);
			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_TimerChange", param1, num);
			HealBeacon_DisplaySettingsMenu(param1);
		}
	}

	return 0;
}

/* BEACON DEFAULT COLOR MENU */
stock void HealBeacon_DisplayBeaconDefaultColorMenu(int client)
{
	Menu menu = new Menu(BeaconDefaultColorMenu_Handler);

	/* CHECK DEFAULT COLOR NAME */
	char colorName[32];
	for(int i = 0; i < sizeof(g_ColorsList); i++)
	{
		char buffers[3][5];
		ExplodeString(g_ColorsList[i].rgb, " ", buffers, 3, sizeof(buffers[]));

		if(StringToInt(buffers[0]) == g_ColorDefault[0] && StringToInt(buffers[1]) == g_ColorDefault[1]
		&& StringToInt(buffers[2]) == g_ColorDefault[2] && 255 == g_ColorDefault[3]) {
			Format(colorName, sizeof(colorName), g_ColorsList[i].name);
			break;
		}
	}

	char title[256];
	Format(title, sizeof(title), "Change Heal Beacon Default Color\nDefault Color: %s", colorName);
	menu.SetTitle(title);

	for(int i = 0; i < sizeof(g_ColorsList); i++)
	{
		char index[3];
		IntToString(i, index, sizeof(index));
		menu.AddItem(index, g_ColorsList[i].name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BeaconDefaultColorMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:{
			if(param2 == MenuCancel_ExitBack)
				HealBeacon_DisplaySettingsMenu(param1);
		}
		case MenuAction_Select:
		{
			char info[128];
			menu.GetItem(param2, info, sizeof(info));
			
			int index = StringToInt(info);
			FM_Color myColor; 
			myColor = g_ColorsList[index];
			
			char buffers[3][5]; // the splitted buffers from menu item
			ExplodeString(myColor.rgb, " ", buffers, 3, sizeof(buffers[]));
			
			g_ColorDefault[0] = StringToInt(buffers[0]);
			g_ColorDefault[1] = StringToInt(buffers[1]);
			g_ColorDefault[2] = StringToInt(buffers[2]);
			g_ColorDefault[3] = 255;

			CPrintToChat(param1, "%s You have changed the Default Beacon Color to {%s}%s.", THIS_MODE_INFO.tag, myColor.name, myColor.name);
			HealBeacon_DisplayBeaconDefaultColorMenu(param1);
		}
	}

	return 0;
}

/* ACTIONS MENU */
stock void HealBeacon_DisplayActionsMenu(int client, int random)
{
	Menu menu = new Menu(ActionsMenu_Handler);

	g_iClientMenuUserId[client] = GetClientUserId(random);
	char title[64], buffer[32];
	Format(title, sizeof(title), "Do an Action on %N", random);
	menu.SetTitle(title);

	Format(buffer, sizeof(buffer), "%d", GetClientUserId(random));

	menu.AddItem("", "Repick randomly");
	menu.AddItem("", "Change Beacon Color");
	menu.AddItem("", "Change beacon radius and distance");

	char light[32];
	g_BeaconPlayersData[random].hasNeon ? Format(light, sizeof(light), "Disable Light on the player") : Format(light, sizeof(light), "Enable Light on the player");	
	menu.AddItem("", light);

	menu.AddItem("", "Teleport to player");
	menu.AddItem("", "Bring Player");
	menu.AddItem("", "Remove Heal beacon");
	menu.AddItem("", "Slay Player");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ActionsMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
				HealBeacon_DisplayMainMenu(param1);
		}
		case MenuAction_Select:
		{
			int random = GetClientOfUserId(g_iClientMenuUserId[param1]);
			if(!random)
			{
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
				HealBeacon_DisplayMainMenu(param1);
				return 0;
			}

			if(!g_BeaconPlayersData[random].hasHealBeacon)
			{
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_PlayerIsNot", param1);
				HealBeacon_DisplayMainMenu(param1);
				return 0;
			}
			
			switch(param2)
			{
				case 0: // Repick
				{
					ReplaceBeacon(param1, random, -1);
					HealBeacon_DisplayMainMenu(param1);
				}
				case 1: // Colors Menu
				{
					HealBeacon_DisplayColorsMenu(param1);
				}
				case 2: // Beacon Distance Menu
				{
					HealBeacon_DisplayBeaconDistanceMenu(param1);
				}
				case 3:
				{
					if(g_BeaconPlayersData[random].hasNeon)
					{
						RemoveNeon(random);
						CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_NeonRemove", param1, random);
					}
					else
					{
						SetClientNeon(random);
						CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_NeonAdd", param1, random);
					}

					HealBeacon_DisplayActionsMenu(param1, random);
				}
				case 4: // Teleport To Player
				{
					float fOrigin[3], fAngles[3];
					GetClientAbsOrigin(random, fOrigin);
					GetClientAbsAngles(random, fAngles);

					TeleportEntity(param1, fOrigin, fAngles, NULL_VECTOR);
					LogAction(param1, random, "[FunModes-HealBeacon] \"%L\" teleported to \"%L\"(HealBeacon Player)", param1, random);
					HealBeacon_DisplayActionsMenu(param1, random);
				}
				
				case 5:// Bring player
				{
					float fOrigin[3], fAngles[3];
					GetClientAbsOrigin(param1, fOrigin);
					GetClientAbsAngles(param1, fAngles);

					TeleportEntity(random, fOrigin, fAngles, NULL_VECTOR);
					LogAction(param1, random, "[FunModes-HealBeacon] \"%L\" brought \"%L\"(HealBeacon Player)", param1, random);
					HealBeacon_DisplayActionsMenu(param1, random);
				}
				case 6:
				{
					RemoveBeacon(param1, random);
					HealBeacon_DisplayMainMenu(param1);
				}
				case 7:
				{
					ForcePlayerSuicide(random);
					LogAction(param1, random, "[FunModes-HealBeacon] \"%L\" slayed \"%L\"(HealBeacon Player)", param1, random);
					CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_Slay", param1, random);
					HealBeacon_DisplayMainMenu(param1);
				}
			}
		}
	}

	return 0;
}

stock void HealBeacon_DisplayColorsMenu(int client)
{
	Menu menu = new Menu(ColorsMenu_Handler);
	int random = GetClientOfUserId(g_iClientMenuUserId[client]);
	if (!random)
		return;

	char title[64];
	Format(title, sizeof(title), "Change beacon and neon color on %N", random);
	menu.SetTitle(title);

	for(int i = 0; i < sizeof(g_ColorsList); i++)
	{
		char index[3];
		IntToString(i, index, sizeof(index));
		menu.AddItem(index, g_ColorsList[i].name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ColorsMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
			{
				int random = GetClientOfUserId(g_iClientMenuUserId[param1]);
				if (!random)
				{
					HealBeacon_DisplayMainMenu(param1);
					CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
					return 0;
				}

				HealBeacon_DisplayActionsMenu(param1, random);
			}
		}
		case MenuAction_Select:
		{
			int random = GetClientOfUserId(g_iClientMenuUserId[param1]);
			if (!random)
			{
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
				return 0;
			}

			char info[3]; // The menu item
			menu.GetItem(param2, info, sizeof(info));
			
			int index = StringToInt(info);
			FM_Color myColor;
			myColor = g_ColorsList[index];
			
			char buffers[3][5]; // the splitted buffers from menu item
			ExplodeString(myColor.rgb, " ", buffers, 3, sizeof(buffers[]));
			
			int color[4];
			color[0] = StringToInt(buffers[0]);
			color[1] = StringToInt(buffers[1]);
			color[2] = StringToInt(buffers[2]);
			color[3] = 255;

			g_BeaconPlayersData[random].SetColor(color); // we gotta save the new color in the enum struct

			/* TELL THE CLIENT THAT THIS CHANGE IS APPLIED */
			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_ColorChange", param1, random, myColor.name, myColor.name);
			LogAction(param1, random, "[FunModes-HealBeacon] \"%L\" changed Beacon and Neon colors of \"%L\" to \"%s\"", param1, random, myColor.name);
			HealBeacon_DisplayColorsMenu(param1);
		}
	}

	return 0;
}

stock void HealBeacon_DisplayBeaconDistanceMenu(int client)
{
	Menu menu = new Menu(BeaconDistanceMenu_Handler);
	int random = GetClientOfUserId(g_iClientMenuUserId[client]);
	if (!random)
		return;

	char title[64];
	Format(title, sizeof(title), "Change beacon radius and distance on %N", random);
	menu.SetTitle(title);

	menu.AddItem("200", "200");
	menu.AddItem("400", "400");
	menu.AddItem("600", "600");
	menu.AddItem("800", "800");
	menu.AddItem("1000", "1000");
	menu.AddItem("1500", "1500");

	menu.AddItem("Empty", "These are the available distances please type sm_beacon_distance <Player> <your number> instead", ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BeaconDistanceMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
			{
				int random = GetClientOfUserId(g_iClientMenuUserId[param1]);
				if (!random)
				{
					HealBeacon_DisplayMainMenu(param1);
					CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
					return 0;
				}

				HealBeacon_DisplayActionsMenu(param1, random);
			}
		}
		case MenuAction_Select:
		{
			int random = GetClientOfUserId(g_iClientMenuUserId[param1]);
			if(!random)
			{
				HealBeacon_DisplayMainMenu(param1);
				CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "PlayerNotValid", param1);
				return 0;
			}

			char info[128]; // The menu item
			menu.GetItem(param2, info, sizeof(info));

			int distance = StringToInt(info);
			g_BeaconPlayersData[random].distance = float(distance);

			/* TELL THE CLIENT THAT THIS CHANGE IS APPLIED */
			CPrintToChat(param1, "%s %T", THIS_MODE_INFO.tag, "HealBeacon_DistanceChange", param1, random, distance);
			LogAction(param1, random, "[FunModes-HealBeacon] \"%L\" changed Beacon Distance of \"%L\" to \"%d\"", param1, random, distance);
			HealBeacon_DisplayBeaconDistanceMenu(param1);
		}
	}

	return 0;
}