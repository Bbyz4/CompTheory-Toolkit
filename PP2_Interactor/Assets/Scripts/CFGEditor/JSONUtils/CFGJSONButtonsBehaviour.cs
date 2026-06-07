using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using System;
using SimpleFileBrowser;

public class CFGJSONButtonsBehaviour : MonoBehaviour
{
    [SerializeField] private CFGManager cfgManager;
    [SerializeField] private CFGProductionListManager cfgplm;

    void Start()
    {
        FileBrowser.SetFilters(true, new FileBrowser.Filter("JSON Files", ".json"));
        FileBrowser.SetDefaultFilter(".json");
    }

    public void ExportToJSON()
    {
        string defaultName = "CFG";

        FileBrowser.ShowSaveDialog(
            (paths) =>
            {
                if(paths == null || paths.Length == 0)
                    return;

                SaveGrammarToPath(paths[0]);
            },
            () => { },
            FileBrowser.PickMode.Files,
            false,
            Application.persistentDataPath,
            defaultName,
            "json"
        );
    }

    public void ImportFromJSON()
    {
        FileBrowser.ShowLoadDialog(
            (paths) =>
            {
                if(paths == null || paths.Length == 0)
                    return;

                LoadGrammarFromPath(paths[0]);
            },
            () => { },
            FileBrowser.PickMode.Files,
            false,
            Application.persistentDataPath,
            null,
            "json"
        );
    }

    private void LoadGrammarFromPath(string path)
    {
        try
        {
            string json = File.ReadAllText(path);

            CFGJsonForm data = JsonConvert.DeserializeObject<CFGJsonForm>(json);

            if(data != null && data.type == "CFG")
            {
                CFGJsonConverter.ApplyCFGFromJSON(cfgManager, data);

                Debug.Log("CFG imported successfully.");

                cfgplm.UpdateDisplay();
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
    }

    private void SaveGrammarToPath(string path)
    {
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
    }
}