using UnityEngine;
using UnityEngine.SceneManagement;

public class FreeEditorCanvas : MonoBehaviour
{
    public void LoadEditor(int modelID)
    {
        ModelData.preopenFromJSON = false;
        ModelData.JSONFile = null;

        switch(modelID)
        {
            case 0:
                ModelData.modelType = ModelData.ModelType.NFA;
                SceneManager.LoadScene("DiGraphEditor");
                break;
            case 1:
                ModelData.modelType = ModelData.ModelType.PDA;
                SceneManager.LoadScene("DiGraphEditor");
                break;
            case 2:
                ModelData.modelType = ModelData.ModelType.CFG;
                SceneManager.LoadScene("CFGEditor");
                break;
            case 3:
                ModelData.modelType = ModelData.ModelType.TM;
                SceneManager.LoadScene("TMEditor");
                break;
            default:
                break;
        }
    }
}
