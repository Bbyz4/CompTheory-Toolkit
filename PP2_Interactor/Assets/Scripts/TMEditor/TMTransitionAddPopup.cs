using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class TMTransitionAddPopup : MonoBehaviour
{
    [SerializeField] private TMP_InputField fromState;
    [SerializeField] private TMP_InputField fromSymbol;
    [SerializeField] private TMP_InputField toState;
    [SerializeField] private TMP_InputField toSymbol;
    [SerializeField] private TMP_InputField headMovement;
    [SerializeField] private Button submitButton;
    [SerializeField] private Button cancelButton;

    private TMManager tmm;
    private TMTransitionListManager tmtlm;

    void Awake()
    {
        tmm = GameObject.FindWithTag("TMManager").GetComponent<TMManager>();
        tmtlm = GameObject.FindWithTag("TMTransitionListManager").GetComponent<TMTransitionListManager>();
    }

    public void Activate()
    {
        gameObject.SetActive(true);

        fromState.text = "";
        fromSymbol.text = "";
        toState.text = "";
        toSymbol.text = "";
        headMovement.text = "";

        submitButton.onClick.RemoveAllListeners();

        submitButton.onClick.AddListener(() =>
        {
            tmm.ValidateAndAddTransition(fromState.text, fromSymbol.text, toState.text, toSymbol.text, Int32.Parse(headMovement.text)); 
            tmtlm.UpdateDisplay();
            gameObject.SetActive(false);
        });

        cancelButton.onClick.RemoveAllListeners();

        cancelButton.onClick.AddListener(() =>
        {
            gameObject.SetActive(false);
        });
    }
}