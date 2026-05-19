using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using System;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class CFGJSONButtonsBehaviour : MonoBehaviour
{
    [SerializeField] private CFGManager cfgManager;

    public void ExportToJSON()
    {
        #if UNITY_EDITOR

        string path = EditorUtility.SaveFilePanel(
            "Save CFG as JSON",
            Application.persistentDataPath,
            "CFG",
            "json"
        );

        if(string.IsNullOrEmpty(path))
        {
            return;
        }

        try
        {
            CFGJsonForm data = CFGJsonConverter.ConvertGraphicCFGToJSON(cfgManager);

            string json = JsonConvert.SerializeObject(data, Formatting.Indented);

            File.WriteAllText(path, json);

            Debug.Log($"CFG exported successfully to: {path}");
        }
        catch(Exception e)
        {
            Debug.LogError($"Error while exporting CFG JSON: {e}");
        }

        #endif
    }

    // This currently only works in the Unity Editor
    public void ImportFromJSON()
    {
        #if UNITY_EDITOR

        string path = EditorUtility.OpenFilePanel(
            "Select CFG JSON file",
            Application.persistentDataPath,
            "json"
        );

        if(string.IsNullOrEmpty(path))
        {
            return;
        }

        try
        {
            string json = File.ReadAllText(path);

            CFGJsonForm data = JsonConvert.DeserializeObject<CFGJsonForm>(json);

            if(data != null && data.type == "CFG")
            {
                CFGJsonConverter.ApplyCFGFromJSON(cfgManager, data);

                Debug.Log("CFG imported successfully.");
            }
            else
            {
                Debug.LogError("Incorrect CFG file.");
            }
        }
        catch(Exception e)
        {
            Debug.LogError($"Error importing CFG JSON: {e.Message}");
        }

        #endif
    }
}