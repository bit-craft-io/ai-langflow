using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using Whisper;
using Debug = UnityEngine.Debug;

/// <summary>
/// マイク録音(無音3秒で自動終了)→whisper.unity(WhisperManager)でローカル推論→結果表示
/// 前提: シーンにWhisperManagerコンポーネント配置済み、モデルロード済み
/// </summary>
public class VoiceToTextRecorder : MonoBehaviour
{
    [Header("UI")]
    public Button recordButton;
    public Text resultText; // TMP_Text使う場合は差し替え

    [Header("Whisper")]
    public WhisperManager whisperManager; // シーン上のWhisperManager参照

    [Header("無音検知設定")]
    public float silenceThreshold = 0.01f; // RMS閾値、環境音次第で調整
    public float silenceDuration = 3f;     // 無音継続でストップ(秒)
    public int maxRecordSeconds = 30;      // 保険用最大録音時間
    private const int SampleRate = 16000;
    private const int CheckIntervalSamples = 1024; // 監視ウィンドウ幅

    private AudioClip _clip;
    private string _micDevice;
    private bool _isRecording;

    private void Start()
    {
        if (Microphone.devices.Length == 0)
        {
            Debug.LogError("マイクデバイス未検出");
            return;
        }
        _micDevice = Microphone.devices[0];
        recordButton.onClick.AddListener(OnRecordButtonPressed);
    }

    private void OnRecordButtonPressed()
    {
        if (_isRecording) return;
        StartCoroutine(RecordAndTranscribe());
    }

    private IEnumerator RecordAndTranscribe()
    {
        _isRecording = true;
        resultText.text = "録音中...";

        // ループ録音(max秒確保)→無音3秒で手動End
        _clip = Microphone.Start(_micDevice, true, maxRecordSeconds, SampleRate);

        var silenceTimer = 0f;
        var lastPos = 0;
        var buffer = new float[CheckIntervalSamples];

        while (true)
        {
            var pos = Microphone.GetPosition(_micDevice);
            if (pos < lastPos) pos = _clip.samples; // ラップ対策(基本maxRecordSeconds内で収まる想定)

            var available = pos - lastPos;
            if (available >= CheckIntervalSamples)
            {
                _clip.GetData(buffer, lastPos % _clip.samples);
                var rms = CalcRms(buffer);

                if (rms < silenceThreshold)
                    silenceTimer += CheckIntervalSamples / (float)SampleRate;
                else
                    silenceTimer = 0f;

                lastPos = pos;

                if (silenceTimer >= silenceDuration)
                    break;
            }

            if (Microphone.GetPosition(_micDevice) >= _clip.samples - 1) break; // maxRecordSeconds到達

            yield return null;
        }

        var recordedSamples = Microphone.GetPosition(_micDevice);
        Microphone.End(_micDevice);

        _clip = TrimClip(_clip, recordedSamples);
        resultText.text = "認識中...";

        // whisper.unity直接推論(外部プロセス不要)
        var task = whisperManager.GetTextAsync(_clip);
        yield return new WaitUntil(() => task.IsCompleted);

        var result = task.IsFaulted ? null : task.Result?.Result;
        resultText.text = string.IsNullOrEmpty(result) ? "認識失敗" : result;
        _isRecording = false;
    }

    private float CalcRms(float[] samples)
    {
        var sum = 0f;
        foreach (var s in samples) sum += s * s;
        return Mathf.Sqrt(sum / samples.Length);
    }

    private AudioClip TrimClip(AudioClip source, int length)
    {
        if (length <= 0) length = source.samples;
        var data = new float[length * source.channels];
        source.GetData(data, 0);
        var trimmed = AudioClip.Create("trimmed", length, source.channels, source.frequency, false);
        trimmed.SetData(data, 0);
        return trimmed;
    }
}