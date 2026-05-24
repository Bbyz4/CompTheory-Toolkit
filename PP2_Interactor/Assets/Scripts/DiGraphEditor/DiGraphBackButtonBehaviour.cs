using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class DiGraphBackButtonBehaviour : MonoBehaviour
{
    void Awake()
    {
        this.GetComponent<Button>().onClick.RemoveAllListeners();

        this.GetComponent<Button>().onClick.AddListener(() =>
        {
           SceneManager.LoadScene(0); 
        });
    }
}
