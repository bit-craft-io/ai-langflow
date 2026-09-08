using UnityEngine;

public static class WebSockWavLoader
{
    public static AudioClip ToAudioClip(byte[] wavBytes)
    {
        // WAVヘッダー（一般的に44バイト）をスキップしてデータ部分を取得
        int headerSize = 44;
        if (wavBytes.Length <= headerSize) return null;

        int samplesCount = (wavBytes.Length - headerSize) / 2; // 16bit PCMの場合
        float[] sampleData = new float[samplesCount];

        for (int i = 0; i < samplesCount; i++)
        {
            // 16bit Short (PCM) を -1.0f 〜 1.0f の float に変換
            short sample = (short)(wavBytes[headerSize + i * 2] | (wavBytes[headerSize + i * 2 + 1] << 8));
            sampleData[i] = sample / 32768.0f;
        }

        // AudioClipの生成 (サンプルレート: 24000Hz ※VOICEVOXのデフォルト等に合わせて調整)
        AudioClip clip = AudioClip.Create("StreamAudio", samplesCount, 1, 24000, false);
        clip.SetData(sampleData, 0);
        return clip;
    }
}