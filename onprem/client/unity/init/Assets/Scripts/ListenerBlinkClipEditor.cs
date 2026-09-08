using UnityEngine;
using System.Collections;
#if UNITY_EDITOR
using UnityEditor;
#endif

public class ListenerBlinkClipEditor : MonoBehaviour
{
    public AnimationClip targetClip; // テンプレート(複製元)
    public GameObject[] targetObjects; // EyeR, EyeL
    public float blinkDuration = 0.15f;
    public float minInterval = 2f;
    public float maxInterval = 5f;

    void Start()
    {
        Fix();
        StartCoroutine(BlinkLoop());
    }

#if UNITY_EDITOR
    void Fix()
    {
        foreach (var target in targetObjects)
        {
            if (target == null) continue;

            // オブジェクトごとにClip複製(元Scale値の違いに対応)
            var clip = Instantiate(targetClip);
            clip.name = targetClip.name + "_" + target.name;

            var s = target.transform.localScale;

            var xCurve = ConstKeyCurve(s.x, blinkDuration);
            var zCurve = ConstKeyCurve(s.z, blinkDuration);
            var yCurve = new AnimationCurve();
            yCurve.AddKey(new Keyframe(0f, s.y, 0f, 0f));
            yCurve.AddKey(new Keyframe(blinkDuration * 0.5f, 0f, 0f, 0f));
            yCurve.AddKey(new Keyframe(blinkDuration, s.y, 0f, 0f));

            clip.ClearCurves();
            clip.SetCurve("", typeof(Transform), "localScale.x", xCurve);
            clip.SetCurve("", typeof(Transform), "localScale.y", yCurve);
            clip.SetCurve("", typeof(Transform), "localScale.z", zCurve);

            clip.legacy = true;
            clip.wrapMode = WrapMode.Once;

            var anim = target.GetComponent<Animation>();
            if (anim == null) anim = target.AddComponent<Animation>();
            anim.AddClip(clip, clip.name);
            anim.clip = clip;
            anim.wrapMode = WrapMode.Once;
            anim.playAutomatically = false;
        }
    }

    AnimationCurve ConstKeyCurve(float value, float duration)
    {
        var curve = new AnimationCurve();
        curve.AddKey(new Keyframe(0f, value, 0f, 0f));
        curve.AddKey(new Keyframe(duration * 0.5f, value, 0f, 0f));
        curve.AddKey(new Keyframe(duration, value, 0f, 0f));
        return curve;
    }
#endif

    IEnumerator BlinkLoop()
    {
        while (true)
        {
            float wait = Random.Range(minInterval, maxInterval);
            yield return new WaitForSeconds(wait);

            foreach (var target in targetObjects)
            {
                if (target == null) continue;
                var anim = target.GetComponent<Animation>();
                if (anim != null) anim.Play();
            }
        }
    }
}