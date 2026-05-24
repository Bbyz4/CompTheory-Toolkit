using UnityEngine;

public class CFGPopupManager : MonoBehaviour
{
    [SerializeField] private CFGGeneralInfoPopup generalInfoPopup;
    [SerializeField] private CFGProductionAddPopup productionAddPopup;
    [SerializeField] private CFGTestRunPopup testRunPopup;

    void Awake()
    {
        ResetToGeneralInfoPopup();
    }

    public void ResetToGeneralInfoPopup()
    {
        generalInfoPopup.Activate();

        productionAddPopup.gameObject.SetActive(false);
        testRunPopup.gameObject.SetActive(false);
    }

    public void ActivateProductionAddPopup()
    {
        productionAddPopup.Activate();
    }

    public void ActivateTestRunPopup()
    {
        testRunPopup.Activate();
    }
}
