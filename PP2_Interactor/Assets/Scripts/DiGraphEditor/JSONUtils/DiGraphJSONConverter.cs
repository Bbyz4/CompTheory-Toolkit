using System;
using System.Collections.Generic;
using UnityEngine;

public class DiGraphJSONConverter : MonoBehaviour
{
    public static PDAJsonForm ConvertGraphicPDAToJSON(DiGraphManager manager)
    {
        var V = manager.GetV();
        var E = manager.GetE();

        PDAJsonForm result = new PDAJsonForm();

        result.type = "PDA";

        result.model = new PDAJsonModel();

        result.model.states = new List<string>();

        foreach(var node in V.Values)
        {
            result.model.states.Add(node.nodeName);
        }

        result.model.inputAlphabet = new List<string>(manager.GetInputAlphabet());
        result.model.stackAlphabet = new List<string>(manager.GetStackAlphabet());

        //assuming there is only one, manager will validate it soon
        foreach(var node in V.Values)
        {
            if(node.isStarting)
            {
                result.model.startState = node.nodeName;
                break;
            }
        }

        result.model.startStackSymbol = manager.GetStartingStackSymbol();

        result.model.acceptStates = new List<string>();

        foreach(var node in V.Values)
        {
            if(node.isAccepting)
            {
                result.model.acceptStates.Add(node.nodeName);
            }
        }

        result.model.acceptanceMode = "ACC_STATE";

        result.model.transitions = new List<PDATransition>();

        foreach(var edgeList in E.Values)
        {
            foreach(var edge in edgeList)
            {
                PDATransition t = new PDATransition();

                t.from = edge.begin.nodeName;
                t.to = edge.end.nodeName;

                t.inputSymbol = string.IsNullOrEmpty(edge.inputSymbol) ? null : edge.inputSymbol;
                
                t.stackSymbol = edge.stackSymbol;

                t.pushedToStack = new List<string>(edge.toPush);

                result.model.transitions.Add(t);
            }
        }

        result.nodePlacements = new List<PDAJsonNodePlacement>();

        foreach(var node in V.Values)
        {
            PDAJsonNodePlacement placement = new PDAJsonNodePlacement();

            placement.nodeName = node.nodeName;

            Vector3 pos = node.transform.position;

            placement.posX = pos.x;
            placement.posY = pos.y;

            result.nodePlacements.Add(placement);
        }

        return result;
    }

    public static NFAJsonForm ConvertGraphicNFAToJSON(DiGraphManager manager)
    {
        var V = manager.GetV();
        var E = manager.GetE();

        NFAJsonForm result = new NFAJsonForm();

        result.type = "NFA";

        result.model = new NFAJsonModel();

        result.model.states = new List<string>();

        foreach(var node in V.Values)
        {
            result.model.states.Add(node.nodeName);
        }

        result.model.inputAlphabet = new List<string>(manager.GetInputAlphabet());

        result.model.startStates = new List<string>();
        result.model.acceptStates = new List<string>();

        foreach(var node in V.Values)
        {
            if(node.isStarting)
            {
                result.model.startStates.Add(node.nodeName);
            }

            if(node.isAccepting)
            {
                result.model.acceptStates.Add(node.nodeName);
            }
        }

        result.model.transitions = new List<NFATransition>();

        foreach(var edgeList in E.Values)
        {
            foreach(var edge in edgeList)
            {
                NFATransition t = new NFATransition();

                t.from = edge.begin.nodeName;
                t.to = edge.end.nodeName;

                t.symbol = string.IsNullOrEmpty(edge.inputSymbol) ? null : edge.inputSymbol;

                result.model.transitions.Add(t);
            }
        }

        result.nodePlacements = new List<NFAJsonNodePlacement>();

        foreach(var node in V.Values)
        {
            NFAJsonNodePlacement placement = new NFAJsonNodePlacement();

            placement.nodeName = node.nodeName;

            Vector3 pos = node.transform.position;

            placement.posX = pos.x;
            placement.posY = pos.y;

            result.nodePlacements.Add(placement);
        }

        return result;
    }

    public static void ApplyPDAFromJSON(DiGraphManager manager, PDAJsonForm jsonForm)
    {
        manager.Clear();

        foreach(string symbol in jsonForm.model.inputAlphabet)
        {
            manager.AddInputSymbol(symbol);
        }
        foreach(string symbol in jsonForm.model.stackAlphabet)
        {
            manager.AddStackSymbol(symbol);
        }
        manager.ChangeStartingStackSymbol(jsonForm.model.startStackSymbol);

        Dictionary<string, int> nameToID = new Dictionary<string, int>();

        foreach(var placement in jsonForm.nodePlacements)
        {
            bool isStarting = (placement.nodeName == jsonForm.model.startState);
            bool isAccepting = jsonForm.model.acceptStates.Contains(placement.nodeName);

            Vector2 position = new Vector2(placement.posX, placement.posY);

            int newID = manager.AddNode(position, placement.nodeName, isStarting, isAccepting);

            nameToID[placement.nodeName] = newID;
        }

        foreach(var transition in jsonForm.model.transitions)
        {
            int fromID = nameToID[transition.from];
            int toID = nameToID[transition.to];

            string input = transition.inputSymbol != null ? transition.inputSymbol : "";

            manager.AddEdge(fromID, toID, input, transition.stackSymbol, transition.pushedToStack);
        }
    }

    public static void ApplyNFAFromJSON(DiGraphManager manager, NFAJsonForm jsonForm)
    {
        manager.Clear();

        foreach(string symbol in jsonForm.model.inputAlphabet)
        {
            manager.AddInputSymbol(symbol);
        }

        Dictionary<string, int> nameToID = new Dictionary<string, int>();

        foreach(var placement in jsonForm.nodePlacements)
        {
            bool isStarting = jsonForm.model.startStates.Contains(placement.nodeName);
            bool isAccepting = jsonForm.model.acceptStates.Contains(placement.nodeName);

            Vector2 position = new Vector2(placement.posX, placement.posY);

            int newID = manager.AddNode(position, placement.nodeName, isStarting, isAccepting);

            nameToID[placement.nodeName] = newID;
        }

        foreach(var transition in jsonForm.model.transitions)
        {
            int fromID = nameToID[transition.from];
            int toID = nameToID[transition.to];

            string input = transition.symbol != null ? transition.symbol : "";

            manager.AddEdge(fromID, toID, input, null, null);
        }
    }
}