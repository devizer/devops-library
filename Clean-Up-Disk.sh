#!/usr/bin/env bash
set -eu; set -o pipefail

FOLDERS_TO_CLEAN='
_____________________MAC_OS_________________________________
/System/Volumes/Data/Users/runner/Library/Android/sdk
/Users/runner/Library/Android/sdk/ndk/26.3.11579264

/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_watchOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_xrOSSimulatorRuntime

/Library/Developer/CoreSimulator/Caches/dyld
/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/Library/Developer/CoreSimulator/Caches/dyld/24G419/com.apple.CoreSimulator.SimRuntime.watchOS-11-4.22T250
/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime

/System/Volumes/Data/Users/runner/.dotnet/shared
/System/Volumes/Data/Users/runner/.dotnet/packs
/System/Volumes/Data/Users/runner/.dotnet/sdk


___________________________WIndows_______________________________

C:\ghcup
C:\Program Files\dotnet
C:\Program Files (x86)\Android\android-sdk
C:\hostedtoolcache/windows/CodeQL
C:\Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools

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
      
      mode="size-by-du"
      mode="size-by-df"
      probe_dir="$(mkdtemp -d)"
      if df -Pk "$probe_dir" >/dev/null 2>&1; then mode="size-by-df"; else mode="size-by-du"; fi
      if [[ "$mode" == "size-by-du" ]]; then
           if [[ "$(uname -s)" == Darwin ]]; then
             sz="$(unset POSIXLY_CORRECT; $(Get-Sudo-Command) du -k -d 0 "$dir" 2>/dev/null | awk '{print $1}' | tail -1 || true)"
           else
             sz="$(unset POSIXLY_CORRECT; $(Get-Sudo-Command) du -k --max-depth=0 "$dir" 2>/dev/null | awk '{print $1}' || true)"
           fi
           sz=$((sz/1024))
           Say "Deleting '$dir' ($(Format-Thousand "$sz") MB)"
           $(Get-Sudo-Command) rm -rf "$dir"/* || true
      else
           freeSizeKbBefore="$(df -Pk "$dir" | awk 'NR==2 {print $4}')"
           $(Get-Sudo-Command) rm -rf "$dir"/* || true
           freeSizeKbAfter="$(df -Pk "$dir" | awk 'NR==2 {print $4}')"
           sz=$((freeSizeKbAfter - freeSizeKbBefore))
           sz=$((sz/1024))
           Say "Deleted '$dir' ($(Format-Thousand "$sz") MB)"
      fi
      totalSize=$((totalSize + sz))
    fi
  done <<< "$FOLDERS_TO_CLEAN"

  Say "Tools Cleap up complete. Total freed: $(Format-Thousand "$totalSize") MB"

  if [[ "$(command -v docker)" ]]; then
    Say "CLEAN UP Docker Images"
    docker image prune -a -f | { grep -v "sha256:"; } || true
  fi
fi
