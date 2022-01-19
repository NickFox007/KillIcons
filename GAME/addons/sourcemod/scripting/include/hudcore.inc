#if defined _hudcore_included
    #endinput
#endif
#define _hudcore_included  

native void HC_AddEndPanelInfo(const char[] text);
native void HC_ShowPanelInfo(int client, const char[] text, float duration);
native void HC_ShowPanelStatus(int client, const char[] text, int duration);

native bool HC_ShowTimer(int iClient, float fTime);
native bool HC_ResetTimer(int iClient);
native bool HC_IsBusy(int iClient);