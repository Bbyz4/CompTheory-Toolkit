using System;
using UnityEngine;

public static class ApplicationData
{
    public static Color mainColor1;
    public static Color mainColor2;
    public static Sprite backgroundSprite;
    public static bool wasColorEverModified = false;

    public static event Action ColorSettingsChanged;

    public static void InvokeColorSettingsChanged()
    {
        wasColorEverModified = true;
        ColorSettingsChanged?.Invoke();
    }

    //------------------USER----------------------

    public static bool isUserLogged = false;
    public static int loggedUserID = -1;
    public static string loggedUserName = "";
    public static string accessToken = "";
}