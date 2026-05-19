using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LaunchAlgPopup : MonoBehaviour
{
    void Awake()
    {
        transform.Find("Confirm").GetComponent<Button>().onClick.AddListener(() => GameObject.Find("TestMain").GetComponent<TestMain2>().LaunchForGivenWord(transform.Find("EdgeLetter").GetComponent<TMP_InputField>().text));
    }
}
