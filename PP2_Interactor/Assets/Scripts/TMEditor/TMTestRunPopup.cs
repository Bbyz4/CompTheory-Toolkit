using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;
using System.Linq;


public class TMTestRunPopup : MonoBehaviour
{
    private TMManager tmm;

    [SerializeField] private TMP_InputField startWordField;
    [SerializeField] private Button startVisButton;

    [SerializeField] private TMFreeRunManager tmfrm;

    void Awake()
    {
        tmm = GameObject.FindWithTag("TMManager").GetComponent<TMManager>();
    }

    public void Activate()
    {
        gameObject.SetActive(true);

        startVisButton.onClick.RemoveAllListeners();

        startVisButton.onClick.AddListener(() =>
        {
            string text = startWordField.text;

            List<string> values = text
                .Split(',')
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            var alphabet = tmm.GetInputAlphabet();

            foreach(string v in values)
            {
                if(!alphabet.Contains(v))
                {
                    return;
                }
            }

            tmfrm.Initialize(values);
        });
    }

    void OnDisable()
    {
        tmfrm.CleanUp();
    }
}