using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

public class ListenerFloatClipEditor : MonoBehaviour
{
    public AnimationClip targetClip;
    public GameObject targetObject;
    public float amplitude = 0.2f;
    public float duration = 2f;

    private GameObject _previousTarget;
    
    void Start()
    {
        Fix();
    }
    
#if UNITY_EDITOR
    void Fix()
    {
        if (_previousTarget != null && _previousTarget != targetObject)
        {
            var oldAnim = _previousTarget.GetComponent<Animation>();
            if (oldAnim != null) Destroy(oldAnim);
        }
        _previousTarget = targetObject;
        
        targetClip.ClearCurves();

        var posCurve = new AnimationCurve();
        posCurve.AddKey(new Keyframe(0f, 0f, 0f, 0f));
        posCurve.AddKey(new Keyframe(duration * 0.5f, amplitude, 0f, 0f));
        posCurve.AddKey(new Keyframe(duration, 0f, 0f, 0f));
        targetClip.SetCurve("", typeof(Transform), "localPosition.y", posCurve);

        targetClip.legacy = true;
        targetClip.wrapMode = WrapMode.Loop;

        EditorUtility.SetDirty(targetClip);
        AssetDatabase.SaveAssets();

        var anim = targetObject.GetComponent<Animation>();
        if (anim == null) anim = targetObject.AddComponent<Animation>();

        anim.AddClip(targetClip, targetClip.name);
        anim.clip = targetClip;
        anim.wrapMode = WrapMode.Loop;
        anim.playAutomatically = true;
        anim.Play(targetClip.name);
    }
#endif
}