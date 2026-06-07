using UnityEngine;

public class TMPopupManager : MonoBehaviour
{
    [SerializeField] private TMGeneralInfoPopup generalInfoPopup;
    [SerializeField] private TMTransitionAddPopup productionAddPopup;
    [SerializeField] private TMTestRunPopup testRunPopup;

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
