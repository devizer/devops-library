#!/usr/bin/env bash
set -eu; set -o pipefail

FOLDERS_TO_CLEAN='
_____________________MAC_OS_________________________________
/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/Library/Developer/CoreSimulator/Caches/dyld/24G419/com.apple.CoreSimulator.SimRuntime.watchOS-11-4.22T250
/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime

/Users/runner/Library/Android/sdk/ndk/26.3.11579264

/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_watchOSSimulatorRuntime
/System/Volumes/Data/Users/runner/.dotnet/sdk
/System/Volumes/Data/Users/runner/Library/Android/sdk


___________________________WIndows_______________________________

C:\ghcup
C:\Program Files\dotnet
C:\Program Files (x86)\Android\android-sdk

'$HOME/.dotnet/sdk'
'$HOME/.nuget/packages'


____________________________Linux_________________________________

/opt/hostedtoolcache/go
/opt/hostedtoolcache/CodeQL
/usr/local/lib/android/sdk
/usr/share/swift
/usr/lib/jvm
/usr/local/.ghcup
/usr/share/dotnet
'

Say --Reset-Stopwatch

if [[ "$(Is-Microsoft-Hosted-Build-Agent)" == False ]]; then
  Say "SKIP Clean UP. Not a microsoft hosted agent"
else

  Say "Starting clean up disk on Microsoft Hosted Build Agent"
  totalSize=0
  while IFS= read -r dir; do
    if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
    if [[ "$(uname -s)" == Darwin ]]; then
      sz="$(unset POSIXLY_CORRECT; $(Get-Sudo-Command) du -k -d 0 "$dir" 2>/dev/null | awk '{print $1}' | tail -1 || true)"
    else
      sz="$(unset POSIXLY_CORRECT; $(Get-Sudo-Command) du -k --max-depth=0 "$dir" 2>/dev/null | awk '{print $1}' || true)"
    fi
    sz=$((sz/1024))
    totalSize=$((totalSize + sz))
    Say "Delete '$dir' ($(Format-Thousand "$sz") MB)"
    $(Get-Sudo-Command) rm -rf "$dir"/* || true
    fi
  done <<< "$FOLDERS_TO_CLEAN"

  Say "Tools Cleap up complete. Total freed $(Format-Thousand "$totalSize") MB"

  if [[ "$(command -v docker)" ]]; then
    Say "CLEAN UP Docker Images"
    docker image prune -a -f | { grep -v "sha256:"; } || true
  fi
fi
