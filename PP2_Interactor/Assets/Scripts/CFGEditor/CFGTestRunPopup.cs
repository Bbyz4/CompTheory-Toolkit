using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using System.Linq;

public class CFGTestRunPopup : MonoBehaviour
{
    private CFGManager cfgm;

    [SerializeField] private CFGFreeRunManager cfgfrm;

    void Awake()
    {
        cfgm = GameObject.FindWithTag("CFGManager").GetComponent<CFGManager>();
    }

    public void Activate()
    {
        gameObject.SetActive(true);
        cfgfrm.Initialize();
    }

    void OnDisable()
    {
        cfgfrm.CleanUp();
    }
}