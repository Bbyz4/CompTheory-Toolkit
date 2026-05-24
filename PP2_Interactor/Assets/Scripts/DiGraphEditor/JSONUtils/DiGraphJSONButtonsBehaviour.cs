using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using TMPro;
using System;

#if UNITY_EDITOR
using UnityEditor;
#endif

public class DiGraphJSONButtonsBehaviour : MonoBehaviour
{
    [SerializeField] private DiGraphManager graphManager;

    public void ExportToJSON()
    {
        #if UNITY_EDITOR

        string defaultName =  (ModelData.modelType == ModelData.ModelType.PDA ? "PDA" : "DFA");

        string path = EditorUtility.SaveFilePanel(
            "Save automaton as JSON",
            Application.persistentDataPath,
            defaultName,
            "json"
        );

        if(string.IsNullOrEmpty(path))
        {
            return;
        }

        try
        {
            if(ModelData.modelType == ModelData.ModelType.PDA)
            {
                PDAJsonForm data = DiGraphJSONConverter.ConvertGraphicPDAToJSON(graphManager);

                string json = JsonConvert.SerializeObject(data, Formatting.Indented);

                File.WriteAllText(path, json);
            }
            else
            {
                NFAJsonForm data = DiGraphJSONConverter.ConvertGraphicNFAToJSON(graphManager);

                string json = JsonConvert.SerializeObject(data, Formatting.Indented);

                File.WriteAllText(path, json);
            }   
        }
        catch(Exception e)
        {
            Debug.LogError($"Error while exporting JSON: {e}");
        }

        #endif
    }

    //This for now will only work in the unity editor
    public void ImportFromJSON()
    {
        #if UNITY_EDITOR

        string path = EditorUtility.OpenFilePanel("Select JSON file", Application.persistentDataPath, "json");

        if(!string.IsNullOrEmpty(path))
        {
            try
            {
                if(ModelData.modelType == ModelData.ModelType.PDA)
                {                   
                    string json = File.ReadAllText(path);

                    PDAJsonForm data = JsonConvert.DeserializeObject<PDAJsonForm>(json);

                    if(data != null && data.type == "PDA")
                    {
                        DiGraphJSONConverter.ApplyPDAFromJSON(graphManager, data);
                    }
                    else
                    {
                        Debug.Log("Incorrect PDA file");
                    }
                }
                else
                {
                    string json = File.ReadAllText(path);

                    NFAJsonForm data = JsonConvert.DeserializeObject<NFAJsonForm>(json);

                    if(data != null && data.type == "NFA")
                    {
                        DiGraphJSONConverter.ApplyNFAFromJSON(graphManager, data);
                    }
                    else
                    {
                        Debug.Log("Incorrect NFA file");
                    }   
                }
            }
            catch(Exception e)
            {
                Debug.LogError($"Error importing JSON: {e.Message}");
            }
        }

        #endif
    }
}
