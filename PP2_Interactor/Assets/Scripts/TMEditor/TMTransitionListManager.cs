using UnityEngine;
using UnityEngine.UI;

public class TMTransitionListManager : MonoBehaviour
{
    [SerializeField] private GameObject transitionDisplayParent;
    [SerializeField] private GameObject transitionDisplayPrefab;
    [SerializeField] private Button transitionAddButton;

    private TMManager tmm;
    private TMPopupManager tmpm;

    void Awake()
    {
        tmm = GameObject.FindWithTag("TMManager").GetComponent<TMManager>();

        tmpm = GameObject.FindWithTag("TMPopupManager").GetComponent<TMPopupManager>();

        transitionAddButton.onClick.RemoveAllListeners();

        transitionAddButton.onClick.AddListener(() =>
        {
            tmpm.ActivateProductionAddPopup();
        });
    }

    public void UpdateDisplay()
    {
        var transitionList = tmm.GetTransitions();

        foreach(Transform child in transitionDisplayParent.transform)
        {
            Destroy(child.gameObject);
        }

        foreach(var tran in transitionList)
        {
            var newProdObj = Instantiate(transitionDisplayPrefab, transitionDisplayParent.transform);   
            newProdObj.GetComponent<TMTransitionPrefabBehaviour>().FillData(tran.entryState, tran.entrySymbol, tran.newState, tran.newSymbol, tran.headMovement, tmm);
        }
    }
}