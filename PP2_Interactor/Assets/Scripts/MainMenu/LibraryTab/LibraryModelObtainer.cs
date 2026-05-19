using System;
using System.IO;

public class LibraryModelObtainer
{
    public static string LoadJSONFileForModel(int modelID)
    {
        string path = @"C:\Users\trzos\AppData\LocalLow\DefaultCompany\PP2_Interactor\pda.json";

        return File.ReadAllText(path);
    }
}