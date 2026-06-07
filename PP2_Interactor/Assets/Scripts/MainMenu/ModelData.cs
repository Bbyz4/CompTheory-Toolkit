using UnityEngine;

public static class ModelData
{
    public enum ModelType
    {
        PDA,
        NFA,
        CFG,
        TM,
        LBA
    };

    public static ModelType modelType;
    
    public static bool preopenFromJSON;
    public static string JSONFile;
}
