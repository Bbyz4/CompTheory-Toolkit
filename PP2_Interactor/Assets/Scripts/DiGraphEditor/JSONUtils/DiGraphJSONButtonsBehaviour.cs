using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using TMPro;
using System;
using SimpleFileBrowser;

public class DiGraphJSONButtonsBehaviour : MonoBehaviour
{
    [SerializeField] private DiGraphManager graphManager;

    void Start()
    {
        FileBrowser.SetFilters(true, new FileBrowser.Filter("JSON Files", ".json"));
        FileBrowser.SetDefaultFilter(".json");
    }

    public void ExportToJSON()
    {
        string defaultName =  (ModelData.modelType == ModelData.ModelType.PDA ? "PDA" : "DFA");

        FileBrowser.ShowSaveDialog(
            (paths) => 
            {
                if(paths == null || paths.Length == 0)
                {
                    return;
                }

                SaveGraphToPath(paths[0]);
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
                {
                    return;
                }

                LoadGraphFromPath(paths[0]);
            },
            () => { },
            FileBrowser.PickMode.Files,
            false,
            Application.persistentDataPath,
            null,
            "json"
        );
    }

    private void SaveGraphToPath(string path)
    {
        try
        {
            if(ModelData.modelType == ModelData.ModelType.PDA)
            {
                PDAJsonForm data =
                    DiGraphJSONConverter.ConvertGraphicPDAToJSON(graphManager);

                string json =
                    JsonConvert.SerializeObject(data, Formatting.Indented);

                File.WriteAllText(path, json);
            }
            else
            {
                NFAJsonForm data =
                    DiGraphJSONConverter.ConvertGraphicNFAToJSON(graphManager);

                string json =
                    JsonConvert.SerializeObject(data, Formatting.Indented);

                File.WriteAllText(path, json);
            }
        }
        catch(Exception e)
        {
            Debug.LogError($"Export error: {e}");
        }
    }

    private void LoadGraphFromPath(string path)
    {
        try
        {
            string json = File.ReadAllText(path);

            if(ModelData.modelType == ModelData.ModelType.PDA)
            {
                PDAJsonForm data =
                    JsonConvert.DeserializeObject<PDAJsonForm>(json);

                if(data != null && data.type == "PDA")
                    DiGraphJSONConverter.ApplyPDAFromJSON(graphManager, data);
                else
                    Debug.Log("Incorrect PDA file");
            }
            else
            {
                NFAJsonForm data =
                    JsonConvert.DeserializeObject<NFAJsonForm>(json);

                if(data != null && data.type == "NFA")
                    DiGraphJSONConverter.ApplyNFAFromJSON(graphManager, data);
                else
                    Debug.Log("Incorrect NFA file");
            }
        }
        catch(Exception e)
        {
            Debug.LogError($"Import error: {e}");
        }
    }
}
