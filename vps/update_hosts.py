#!/usr/bin/env python3
import sys
import subprocess
import base64

if len(sys.argv) < 3:
    sys.exit(1)

action = sys.argv[1]
domain = sys.argv[2]

if action == 'add':
    ps_code = f"""
$hostsFile = 'C:/Windows/System32/drivers/etc/hosts'
if (-not (Select-String -Path $hostsFile -Pattern '{domain}' -SimpleMatch)) {{
    Add-Content -Path $hostsFile -Value "`n127.0.0.1  {domain}"
}}
"""
elif action == 'delete':
    ps_code = f"""
$hostsFile = 'C:/Windows/System32/drivers/etc/hosts'
if (Test-Path $hostsFile) {{
    (Get-Content $hostsFile) | Where-Object {{ $_ -notmatch '{domain}' }} | Set-Content $hostsFile
}}
"""

b64_str = base64.b64encode(ps_code.encode('utf-16le')).decode()

# Try standard powershell
res = subprocess.run(['powershell.exe', '-NoProfile', '-EncodedCommand', b64_str], capture_output=True)

if res.returncode != 0:
    # Try elevated powershell
    ps_cmd = f"Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -EncodedCommand {b64_str}'"
    subprocess.run(['powershell.exe', '-NoProfile', '-Command', ps_cmd], capture_output=True)
