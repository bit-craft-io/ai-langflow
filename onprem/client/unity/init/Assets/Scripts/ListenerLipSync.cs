using System.Linq;
using UnityEngine;

// [RequireComponent(typeof(AudioSource))]
public class ListenerLipSync : MonoBehaviour
{
    // public AudioSource audioSource;
    public WebSockStreamPlayer streamPlayer; // ← Inspectorでドラッグ
    public Transform mouthCube;
    public float sensitivity = 20f;
    public float minScaleY = 0.06f;
    public float maxScaleY = 0.16f;
    public float smoothing = 15f;

    private AudioSource _audioSource;
    private readonly float[] _samples = new float[256];
    private float _currentScaleY = 0.1f;

    // void Start() => audioSource = GetComponent<AudioSource>();
    void Start()
    {
        _audioSource = streamPlayer.AudioSource;
        _currentScaleY = minScaleY;
    }

    void Update()
    {
        if (_audioSource is null)
        {
            Debug.LogError("audioSource is NULL!");
            return;
        }
        _audioSource.GetOutputData(_samples, 0);
        var sum = _samples.Sum(s => s * s);
        var rms = Mathf.Sqrt(sum / _samples.Length);
        var targetScaleY = Mathf.Clamp(rms * sensitivity, minScaleY, maxScaleY);

        _currentScaleY = Mathf.Lerp(_currentScaleY, targetScaleY, Time.deltaTime * smoothing);

        Vector3 scale = mouthCube.localScale;
        scale.y = _currentScaleY;
        mouthCube.localScale = scale;
    }
}