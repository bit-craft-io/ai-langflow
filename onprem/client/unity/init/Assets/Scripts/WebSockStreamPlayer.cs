using System;
using System.Collections.Generic;
using UnityEngine;

public class WebSockStreamPlayer : MonoBehaviour
{
    public AudioSource AudioSource => audioSource;
    [SerializeField] private AudioSource audioSource;
    private readonly Queue<AudioClip> _audioQueue = new();
    
    public bool IsPlaying => audioSource.isPlaying || _audioQueue.Count > 0;

    /// <summary>キューから新規クリップがPlay()された瞬間に発火</summary>
    public event Action OnClipStart;

    // WebSocket等で音声(AudioClip)を受信した時に呼ぶ
    public void EnqueueAudio(AudioClip clip)
    {
        _audioQueue.Enqueue(clip);
    }

    private void Update()
    {
        if (!audioSource.isPlaying && _audioQueue.Count > 0)
        {
            audioSource.clip = _audioQueue.Dequeue();
            audioSource.Play();
            OnClipStart?.Invoke();
        }
    }
}