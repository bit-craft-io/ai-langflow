using System;
using Unity.Cinemachine;
using UnityEngine;
using UnityEngine.UI;

public class FocalPointSwitcher : MonoBehaviour
{
    [SerializeField] private CinemachineCamera vcam;
    [SerializeField] private Transform focalPoint;
    [SerializeField] private Transform focalPointR;
    [SerializeField] private Button btnDebug;
    [SerializeField] private GameObject answerUI;

    private bool _isSwitched = false;

    public void Enable()
    {
        vcam.Target.TrackingTarget = focalPointR;
        answerUI?.SetActive(true);
    }
    
    public void Disable()
    {
        _isSwitched = false;
        vcam.Target.TrackingTarget = focalPoint;
        answerUI?.SetActive(false);
    }

    private void Start()
    {
        btnDebug?.onClick.AddListener(OnButtonPress);
        answerUI?.SetActive(_isSwitched);
    }

    private void OnButtonPress()
    {
        _isSwitched = !_isSwitched;
        vcam.Target.TrackingTarget = _isSwitched ? focalPointR : focalPoint;
        answerUI?.SetActive(_isSwitched);
    }
}