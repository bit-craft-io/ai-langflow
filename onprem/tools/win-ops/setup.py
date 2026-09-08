import subprocess

subprocess.run([
    "powershell.exe",
    "-Command",
    "Install-Module AudioDeviceCmdlets -Scope CurrentUser -Force"
])
