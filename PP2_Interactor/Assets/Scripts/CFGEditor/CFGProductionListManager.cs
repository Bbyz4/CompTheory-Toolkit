using UnityEngine;
using UnityEngine.UI;

public class CFGProductionListManager : MonoBehaviour
{
    [SerializeField] private GameObject productionDisplayParent;
    [SerializeField] private GameObject productionDisplayPrefab;
    [SerializeField] private Button productionAddButton;

    private CFGManager cfgm;
    private CFGPopupManager cfgpm;

    void Awake()
    {
        cfgm = GameObject.FindWithTag("CFGManager").GetComponent<CFGManager>();
    
        cfgpm = GameObject.FindWithTag("CFGPopupManager").GetComponent<CFGPopupManager>();

        productionAddButton.onClick.RemoveAllListeners();

        productionAddButton.onClick.AddListener(() =>
        {
            cfgpm.ActivateProductionAddPopup();
        });
    }

    public void UpdateDisplay()
    {
        var prodList = cfgm.GetP();

        foreach(Transform child in productionDisplayParent.transform)
        {
            Destroy(child.gameObject);
        }

        foreach(var prodSet in prodList)
        {
            foreach(var prodOutput in prodSet.Value)
            {
                var newProdObj = Instantiate(productionDisplayPrefab, productionDisplayParent.transform);   
                newProdObj.GetComponent<CFGProductionPrefabBehaviour>().FillData(prodSet.Key, prodOutput, cfgm);
            }
        }
    }
}
