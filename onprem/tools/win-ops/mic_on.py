import subprocess

subprocess.run([
    "powershell.exe",
    "-Command",
    "Set-AudioDevice -RecordingMute $false"
])
