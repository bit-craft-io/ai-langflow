using UnityEngine;

public class FocalPointInitialize : MonoBehaviour
{
    [SerializeField] private Transform focalPoint;
    [SerializeField] private Transform actor;

    private void Start()
    {
        // 疎結合なオブジェクト同士を実行時に組み立てる
        if (focalPoint != null && actor != null)
        {
            actor.SetParent(focalPoint);
        }
    }
}
