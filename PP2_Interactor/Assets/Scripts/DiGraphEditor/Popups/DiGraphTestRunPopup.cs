using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using System.Linq;

public class DiGraphTestRunPopup : MonoBehaviour
{
    private DiGraphManager dgm;

    [SerializeField] private FreeRunManager frm;

    void Awake()
    {
        dgm = GameObject.FindWithTag("DiGraphManager").GetComponent<DiGraphManager>();  
    }

    public void Activate()
    {
        gameObject.SetActive(true);
        frm.Initialize();
    }

    void OnDisable()
    {
       frm.CleanUp(); 
    }
}