using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using System;
using SimpleFileBrowser;

public class TMJSONButtonsBehaviour : MonoBehaviour
{
    [SerializeField] private TMManager tmManager;
    [SerializeField] private TMTransitionListManager tmtlm;

    void Start()
    {
        FileBrowser.SetFilters(true, new FileBrowser.Filter("JSON Files", ".json"));
        FileBrowser.SetDefaultFilter(".json");
    }

    public void ExportToJSON()
    {
        string defaultName = "TM";

        FileBrowser.ShowSaveDialog(
            (paths) =>
            {
                if(paths == null || paths.Length == 0)
                    return;

                SaveMachineToPath(paths[0]);
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

                LoadMachineFromPath(paths[0]);
            },
            () => { },
            FileBrowser.PickMode.Files,
            false,
            Application.persistentDataPath,
            null,
            "json"
        );
    }

    private void LoadMachineFromPath(string path)
    {
        try
        {
            string json = File.ReadAllText(path);

            TMJsonForm data = JsonConvert.DeserializeObject<TMJsonForm>(json);

            if(data != null && data.type == "TM")
            {
                TMJsonConverter.ApplyTMFromJSON(tmManager, data);

                Debug.Log("TM imported successfully.");

                tmtlm.UpdateDisplay();
            }
            else
            {
                Debug.LogError("Incorrect TM file.");
            }
        }
        catch(Exception e)
        {
            Debug.LogError($"Error importing TM JSON: {e.Message}");
        }
    }

    private void SaveMachineToPath(string path)
    {
        try
        {
            TMJsonForm data = TMJsonConverter.ConvertGraphicTMToJSON(tmManager);

            string json = JsonConvert.SerializeObject(data, Formatting.Indented);

            File.WriteAllText(path, json);

            Debug.Log($"TM exported successfully to: {path}");
        }
        catch(Exception e)
        {
            Debug.LogError($"Error while exporting TM JSON: {e}");
        }
    }
}