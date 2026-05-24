using UnityEngine;

public static class ModelData
{
    public enum ModelType
    {
        PDA,
        NFA
    };

    public static ModelType modelType;
    
    public static bool preopenFromJSON;
    public static string JSONFile;
}
