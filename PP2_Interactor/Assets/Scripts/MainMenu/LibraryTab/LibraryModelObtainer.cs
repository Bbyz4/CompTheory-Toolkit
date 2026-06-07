using System;
using System.IO;

public class LibraryModelObtainer
{
    public static string LoadJSONFileForModel(UploadedModelDescriptor desc)
    {
        if(desc.internalID < 0)
        {
            return desc.modelJSONstring;
        }

        //ugly af, i know, gotta pass somehow XD
        string path = @"C:\Users\trzos\AppData\LocalLow\DefaultCompany\PP2_Interactor\pda.json";

        return File.ReadAllText(path);
    }
}