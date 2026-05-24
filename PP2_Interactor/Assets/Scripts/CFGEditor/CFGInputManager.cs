using UnityEngine;

public class CFGInputManager : MonoBehaviour
{
    private int INPUT_MODE;

    void Awake()
    {
        INPUT_MODE = 0;
    }

    public void ChangeInputMode(int newInputMode)
    {
        INPUT_MODE = newInputMode;
    }

    public int GetInputMode()
    {
        return INPUT_MODE;
    }
}
