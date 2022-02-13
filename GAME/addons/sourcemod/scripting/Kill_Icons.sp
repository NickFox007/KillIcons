#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <shop>
#include <vip_core>
#include <hudcore>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "[VIP+SHOP] Kill Icons",
	description = "Allow players to choose theirs own kill icon",
	author = "Nick Fox",
	version = "1.1.1",
	url = "https://vk.com/nf_dev"
}


Handle
	g_hCookie;
Menu
	g_hMainMenu,
	g_hChooseMenu;

CategoryId g_iCategory_id;

#define ICON_LEN 128
#define ICON_LIMIT 128

bool
	g_bVipLoaded[MAXPLAYERS+1],
	g_bShopLoaded[MAXPLAYERS+1],
	g_bCookieLoaded[MAXPLAYERS+1],
	g_bFullyLoaded[MAXPLAYERS+1],
	g_bVipCore,
	g_bShopCore,
	g_bLateLoad,
	g_bHudCore,
	g_bAllUse;

char
	g_sIcon[ICON_LIMIT][ICON_LEN],
	g_sIconName[ICON_LIMIT][ICON_LEN],
	g_sMainName[128];
	//g_sFastDL[1024];
	
int
	g_iIconCount,
	g_iSelected[MAXPLAYERS+1],
	g_iIconBuyPrice[MAXPLAYERS+1],
	g_iIconSellPrice[MAXPLAYERS+1],
	g_iIconBuyTime[MAXPLAYERS+1];

ConVar
	CVARShop,
	CVARVIP,
	CVARAll;
	//CVARFastDL;
	
ItemId
	g_iItems[ICON_LIMIT];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("vip_modules.phrases");
	g_hCookie = RegClientCookie("killicon", "Kill Icon",  CookieAccess_Private);
	HookEvent("player_death",Death,EventHookMode_Pre);
	LoadConfig();
	if (GetFeatureStatus(FeatureType_Native, "Shop_IsStarted") == FeatureStatus_Available && Shop_IsStarted()) Shop_Started();
	RegConsoleCmd("sm_icons", CmdMenu);
	g_sIconName[0] = "Выключить";
	
	if(g_bLateLoad) for(int i = 1; i < MAXPLAYERS; i++) if(IsClientInGame(i)&&!IsFakeClient(i))
	{
		g_bCookieLoaded[i] = true;
		OnClientPostAdminCheck(i);
	}	
}

bool hasRights(int client, int icon)
{
	if(g_bAllUse || icon == 0) return true;
	if(g_bVipCore)
	{
		char sVip[1024];
		VIP_GetClientFeatureString(client, g_sMainName, sVip, sizeof(sVip));
	
		if(StrContains(sVip, g_sIconName[icon])>-1) return true;
	}
	if(g_bShopCore)
	{
		if(Shop_IsClientItemToggled(client, g_iItems[icon])) return true;
	}
	return false;
}

int FindIconIndex(const char[] sIcon)
{
	for(int i; i < g_iIconCount; i++) if(StrEqual(g_sIconName[i], sIcon)) return i;
	
	return -1;
}


public void OnClientPostAdminCheck(int client)
{
	CreateTimer(2.0,Timer_Check,client);
}

public void OnLibraryAdded(const char[] szName) 
{
	if(StrEqual(szName,"vip_core") && CVARVIP.IntValue==1) LoadVIPCore();
	if(StrEqual(szName,"hudcore")) g_bHudCore = true;
}

public void OnLibraryRemoved(const char[] szName) 
{	
	if(StrEqual(szName,"vip_core"))	g_bVipCore = false;
	if(StrEqual(szName,"shop"))	g_bShopCore = false;
	if(StrEqual(szName,"hudcore")) g_bHudCore = false;
}

public void Shop_Started()
{
	LoadShopCore();
}


Action Timer_DelayVIPCore(Handle hTimer)
{
	LoadVIPCore();
}

Action Timer_DelayShopCore(Handle hTimer)
{
	LoadShopCore();
}



void LoadVIPCore()
{
	if(!VIP_IsVIPLoaded()) CreateTimer(1.0, Timer_DelayVIPCore);
	if(g_bVipCore || CVARVIP.IntValue == 0) return;

	VIP_RegisterFeature(g_sMainName, STRING, SELECTABLE, OnVipItemSelect);
	
	if(g_bLateLoad)	for(int i = 1; i<MAXPLAYERS+1;i++) if(IsValidClient(i)) VIP_OnClientLoaded(i,true);

	g_bVipCore = true;
}

public bool OnVipItemSelect(int client, const char[] cFeature)
{
	DisplayMainMenu(client);	
	return false;
}

void UnloadVIPCore()
{
	if(!g_bVipCore) return;

	VIP_UnregisterFeature(g_sMainName);

	g_bVipCore = false;

}

void LoadShopCore()
{
	if(!Shop_IsStarted()) CreateTimer(1.0, Timer_DelayShopCore);

	if(g_bShopCore || CVARShop.IntValue == 0) return;

	
	g_iCategory_id = Shop_RegisterCategory("kill_icons", g_sMainName, "");
	
	for(int i = 1; i < g_iIconCount; i++)
	{
		
		if (g_iIconBuyPrice[i]>-1 && Shop_StartItem(g_iCategory_id, g_sIconName[i]))
		{		
			Shop_SetInfo(g_sIconName[i], "Иконка, показываемая при убийстве", g_iIconBuyPrice[i], g_iIconSellPrice[i], Item_Togglable, g_iIconBuyTime[i]); //Item_Togglable
			Shop_SetCallbacks(OnItemRegistered, OnEquipItem, _, _, _, OnPreviewItem, OnBuyItem);
			Shop_EndItem();
		}
		
	}
	if(g_bLateLoad) for(int i = 1; i<MAXPLAYERS+1;i++) if(IsValidClient(i)) g_bShopLoaded[i] = true;
	
	g_bShopCore = true;

}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	g_iItems[FindIconIndex(item)] = item_id;
}

public bool OnBuyItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int price, int sell_price, int value)
{
	return true;
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (elapsed)
	{
		return Shop_UseOff;
	}
	else if(isOn) PrintToChat(client, "Доступ к иконке нельзя выключить!");

	return Shop_UseOn;
}

public void OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	IconPreview(client, FindIconIndex(item));
	
}

int GetVictimClient(int client)
{	
	for(int i = 1; i< MAXPLAYERS; i++) if(client != i && IsClientInGame(i)) return i;
	return -1;
}

/*
void FixFastDL()
{
	if(g_sFastDL[0])
	{
		if(g_sFastDL[strlen(g_sFastDL)-1]!='/') Format(g_sFastDL, sizeof(g_sFastDL), "%s/", g_sFastDL);
	}
}*/

void GetPathIcon(int icon, char[] sText, int maxlen)
{	
	FormatEx(sText, maxlen, "file://{images}/icons/equipment/%s.svg", g_sIcon[icon]);
}

void IconPreview(int client, int icon)
{
	if(g_bHudCore)
	{
		char sText[1024];
		GetPathIcon(icon, sText, sizeof(sText));		
		Format(sText, sizeof(sText), "<pre><font class='fontSize-x'><font color='#ffffff'>Данная иконка будет отображаться в килл-чате</font></font><br><font><img src='%s'/></font></pre>", sText);
		HC_ShowPanelInfo(client, sText, 5.0);
	}
	else
	{
		bool isBot;	
		int victim = GetVictimClient(client);
		if(victim == -1)
		{
			victim = CreateFakeClient("Preview");
			isBot = true;
		}
		
		Event event = CreateEvent("player_death", true);
		event.SetInt("userid", GetClientUserId(victim));
		event.SetInt("attacker", GetClientUserId(client));
				
		event.SetString("weapon", g_sIcon[icon]);
		event.FireToClient(client);
		event.Cancel();
		
		if(isBot) KickClient(victim,"");
	}
	
}


void UnloadShopCore()
{	
	if(!g_bShopCore||!Shop_IsStarted()) return;
	Shop_UnregisterMe();
	g_bShopCore = false;

}


public void ChangeCvar_ShopCore(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar.IntValue==1) LoadShopCore();
	else UnloadShopCore();
	
}

public void ChangeCvar_VIPCore(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar.IntValue==1) LoadVIPCore();
	else UnloadVIPCore();
	
}

public void ChangeCvar_All(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bAllUse = convar.BoolValue;
	
}

/*
public void ChangeCvar_FastDL(ConVar convar, const char[] oldValue, const char[] newValue)
{
	FormatEx(g_sFastDL,sizeof(g_sFastDL),"%s", newValue);	
	FixFastDL();
}
*/
bool IsValidClient(int client)
{
	if(client>0&&client<65&&IsClientInGame(client)&&!IsFakeClient(client)) return true;
	else return false;

}

public void OnClientDisconnect(int client)
{
	g_bShopLoaded[client] = false;
	g_bVipLoaded[client] = false;
	g_bCookieLoaded[client] = false;
	g_bFullyLoaded[client] = false;

}

public Action Timer_Check(Handle timer, any client)
{

	if((g_bShopLoaded[client]||!g_bShopCore)&&(g_bVipLoaded[client]||!g_bVipCore)&&g_bCookieLoaded[client]) OnPlayerJoin(client);
	
	else CreateTimer(2.0,Timer_Check,client);
	
	return Plugin_Handled;

}

public void OnPluginEnd()
{
	delete g_hMainMenu;
	delete g_hChooseMenu;
	UnhookEvent("player_death",Death,EventHookMode_Pre);
	
	UnloadShopCore();
	UnloadVIPCore();
	
}

Action CmdMenu(int client, int args)
{
	if(g_bFullyLoaded[client]) DisplayMainMenu(client);
	else PrintToChat(client, "Данные пока не загружены, ожидайте...");
	
	return Plugin_Handled;
}


public void Shop_OnAuthorized(int client)
{
	
	//g_bUseSB[client] = Shop_IsClientItemToggled(client, g_iID);

	g_bShopLoaded[client] = true;
	
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP)
{
	g_bVipLoaded[iClient] = true;
}


public void OnPlayerJoin(int client)
{	
	char cInfo[4];
	GetClientCookie(client, g_hCookie, cInfo, sizeof(cInfo));
	g_iSelected[client] = StringToInt(cInfo);
	g_bFullyLoaded[client] = true;
	
}


public void OnClientCookiesCached(int client)
{
	g_bCookieLoaded[client] = true;	
}


void DisplayChooseMenu(int client)
{
	g_hChooseMenu.Display(client, MENU_TIME_FOREVER);
}

void DisplayMainMenu(int client)
{
	g_hMainMenu.Display(client, MENU_TIME_FOREVER);
}



public void LoadConfig()
{
	g_hChooseMenu = new Menu(ChooseMenuHandler,MenuAction_Cancel|MenuAction_Select|MenuAction_DrawItem|MenuAction_DisplayItem);
	g_hChooseMenu.SetTitle("Выбор иконки");
	g_hChooseMenu.ExitBackButton = true;	
	g_hChooseMenu.AddItem(NULL_STRING, "Выключить");
	
	
	
	char sPath[1024];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/kill_icons.ini"); 
	
	KeyValues kv = new KeyValues("Icons");
	if(!kv.ImportFromFile(sPath))
		SetFailState("ERROR: ImportFromFile config");
	
	//(CVARFastDL = FindConVar("sv_downloadurl")).AddChangeHook(ChangeCvar_FastDL);	
	//CVARFastDL.GetString(g_sFastDL, sizeof(g_sFastDL));
	//FixFastDL();
	
	kv.Rewind();
	if(kv.GotoFirstSubKey())
	{
		kv.GetSectionName(g_sMainName, sizeof(g_sMainName));		
		
		kv.GotoFirstSubKey();
		do
		{
			g_iIconCount++;			
			if(kv.GetSectionName(g_sIconName[g_iIconCount], ICON_LEN))
			{
				kv.GetString("name", g_sIcon[g_iIconCount], ICON_LEN);
				g_iIconBuyPrice[g_iIconCount] = kv.GetNum("price");
				g_iIconSellPrice[g_iIconCount] = kv.GetNum("sellprice");
				g_iIconBuyTime[g_iIconCount] = kv.GetNum("duration");
				char sNum[4]; FormatEx(sNum, sizeof(sNum),"%i",g_iIconCount);
				g_hChooseMenu.AddItem(sNum,g_sIconName[g_iIconCount]);
				//FormatEx(sPath,sizeof(sPath),"materials/panorama/images/icons/equipment/%s.svg",g_sIcon[g_iIconCount]);
				//AddFileToDownloadsTable(sPath);				
			}			
		}
		while(kv.GotoNextKey());
	}
	
	g_hMainMenu = new Menu(MainMenuHandler,MenuAction_Cancel|MenuAction_Select|MenuAction_DrawItem|MenuAction_DisplayItem);
	g_hMainMenu.SetTitle(g_sMainName);
	g_hMainMenu.ExitBackButton = true;	
	g_hMainMenu.AddItem("select", "Выбор иконки\n   ");
	g_hMainMenu.AddItem("shop", "Магазин\n   Приобрети и пользуйся!");
		
	(CVARShop = CreateConVar("sm_killicon_shop_use", "1", "Использовать ядро Shop.", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_ShopCore);
	(CVARVIP = CreateConVar("sm_killicon_vip_use", "1", "Использовать ядро VIP.", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_VIPCore);
	(CVARAll = CreateConVar("sm_killicon_all_use", "0", "Доступ по умолчанию у всех.", _, true, 0.0, true, 1.0)).AddChangeHook(ChangeCvar_All);	
	
	
	g_bAllUse = CVARAll.BoolValue;
	
	
	AutoExecConfig(true, "kill_icon", "sourcemod");	
}

public void OnMapStart()
{
	char sPath[1024];
	for(int i = 1; i <= g_iIconCount; i++)
	{
		FormatEx(sPath,sizeof(sPath),"materials/panorama/images/icons/equipment/%s.svg",g_sIcon[i]);
		AddFileToDownloadsTable(sPath);	
	}
}

public int ChooseMenuHandler(Menu menu, MenuAction action, int client, int button)
{
	char sBuf[ICON_LEN], sSelect[ICON_LEN];
	switch(action)
	{		
		case MenuAction_DisplayItem:
		{			
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));
			
			if(g_iSelected[client] == StringToInt(sSelect)) Format(sBuf, sizeof(sBuf), "%s [X]", sBuf);			
			return RedrawMenuItem(sBuf);
		}
		case MenuAction_DrawItem:
		{
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));			
			int iSelect = StringToInt(sSelect);

			if(hasRights(client, iSelect))
			return (g_iSelected[client] ==  iSelect) ? ITEMDRAW_DISABLED: ITEMDRAW_DEFAULT;
			else return ITEMDRAW_RAWLINE;
		}
		case MenuAction_Select:
		{			
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));
			//iSelect = StringToInt(sSelect);			
			
			SetIcon(client, sSelect);
			
			menu.DisplayAt(client, GetMenuSelectionPosition(), 0);
		}
		case MenuAction_Cancel: DisplayMainMenu(client);
	}
	return 0;
}


public int MainMenuHandler(Menu menu, MenuAction action, int client, int button)
{
	char sBuf[ICON_LEN], sSelect[ICON_LEN];
	switch(action)
	{		
		case MenuAction_DisplayItem:
		{			
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));
			
			if(StrEqual(sSelect, "select")) Format(sBuf, sizeof(sBuf), "%sТекущий выбор: %s", sBuf, g_sIconName[g_iSelected[client]]);			
			return RedrawMenuItem(sBuf);
		}
		case MenuAction_DrawItem:
		{
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));

			if(StrEqual(sSelect, "shop") && !g_bShopCore) return ITEMDRAW_RAWLINE;
			
			return ITEMDRAW_DEFAULT;
		}
		case MenuAction_Select:
		{			
			menu.GetItem(button, sSelect, sizeof(sSelect),_,sBuf,sizeof(sBuf));
			
			if(StrEqual(sSelect,"select")) DisplayChooseMenu(client);
			
			if(StrEqual(sSelect,"shop")) GoToShop(client);
		}
	}
	return 0;
}

void GoToShop(int client)
{
	if(g_bShopCore) Shop_ShowItemsOfCategory(client, g_iCategory_id);
}

void SetIcon(int client, const char[] sSelect)
{
	g_iSelected[client] = StringToInt(sSelect);
	
	SetClientCookie(client, g_hCookie, sSelect);
}

public Action Death(Event hEvent,const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker")),
		client = GetClientOfUserId(hEvent.GetInt("userid"));

	if(client != attacker && g_iSelected[attacker] && hasRights(attacker, g_iSelected[attacker]))
	{
		hEvent.BroadcastDisabled = true;
		Event event = CreateEvent("player_death", true);
		event.SetInt("userid", hEvent.GetInt("userid"));
		event.SetInt("attacker", hEvent.GetInt("attacker"));
			
		event.SetInt("assister", hEvent.GetInt("assister"));
		event.SetInt("penetrated", hEvent.GetInt("penetrated"));
				
		event.SetBool("assistedflash",hEvent.GetBool("assistedflash"));
		event.SetBool("headshot",hEvent.GetBool("headshot"));
		event.SetBool("noreplay",hEvent.GetBool("noreplay"));
		event.SetBool("noscope",hEvent.GetBool("noscope"));
		event.SetBool("thrusmoke",hEvent.GetBool("thrusmoke"));
		event.SetBool("attackerblind",hEvent.GetBool("attackerblind"));
			
		event.SetString("weapon", g_sIcon[g_iSelected[attacker]]);
		
		for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
			event.FireToClient(i);
		event.Cancel();
	}
	
	return Plugin_Changed;
}