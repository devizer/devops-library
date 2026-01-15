#!/usr/bin/env bash
set -eu; set -o pipefail


DEMAND_TOOLS="${DEMAND_TOOLS:-go codeql swift jvm ghcup android dotnet apple-simulator msvc}"

Delete-One() {
    local dir="${1:-}"
    if [[ -n "$dir" ]] && [[ -d "$dir" ]]; then
      local mode;
      mode="size-by-du"
      mode="size-by-df"
      local probe_dir="$(mktemp -d)"
      if df -Pk "$probe_dir" >/dev/null 2>&1; then mode="size-by-df"; else mode="size-by-du"; fi
      local sz
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
      # global total size
      totalSize=$((totalSize + sz))
      rm -rf "$probe_dir" 2>/dev/null || true
    fi
}

Delete-Many() {
  local dirs=$1
  while IFS= read -r dir; do
    Delete-One "$dir"
  done <<< "$dirs"
}

Is-Tool-Enabled() {
  local idTool="${1:-}"
  local found="$(echo "$DEMAND_TOOLS" | awk -F '[,; ]' -v ID="$idTool" '{ for(i=1; i<=NF; i++) if (tolower($i) == tolower(ID)) { print $i } }')"
  if [[ -n "$found" ]]; then echo True; else echo False; fi
}
# DEMAND_TOOLS="go, codeql; swift;; jvm android; dotnet apple-simulator msvc"; for id in go codeql swift android msvc ghcup dotnet apple-simulator; do echo "ID=[$id] Enabled: $(Is-Tool-Enabled "$id")"; done;

FOLDERS_TO_CLEAN='
_____________________MAC_OS_________________________________
/System/Volumes/Data/Users/runner/Library/Android/sdk
/Users/runner/Library/Android/sdk/ndk/26.3.11579264


# Simulators
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_watchOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_xrOSSimulatorRuntime
/Library/Developer/CoreSimulator/Caches/dyld
/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
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

[[ "$(Is-Tool-Enabled go)" == False ]]      && Delete-Many '/opt/hostedtoolcache/go'
[[ "$(Is-Tool-Enabled android)" == False ]] && Delete-Many '
/System/Volumes/Data/Users/runner/Library/Android/sdk
/Users/runner/Library/Android/sdk/ndk/26.3.11579264
C:\Program Files (x86)\Android\android-sdk
/usr/local/lib/android/sdk'
[[ "$(Is-Tool-Enabled dotnet)" == False ]] && Delete-Many '
/System/Volumes/Data/Users/runner/.dotnet/shared
/System/Volumes/Data/Users/runner/.dotnet/packs
/System/Volumes/Data/Users/runner/.dotnet/sdk
C:\Program Files\dotnet
/usr/share/dotnet
'$HOME/.dotnet/sdk'
'$HOME/.nuget/packages'
C:\Program Files\dotnet'
[[ "$(Is-Tool-Enabled msvc)" == False ]] && Delete-Many 'C:\Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools'
[[ "$(Is-Tool-Enabled apple-simulator)" == False ]] && Delete-Many '
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_watchOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime
/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_xrOSSimulatorRuntime
/Library/Developer/CoreSimulator/Caches/dyld
/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime
/System/Library/AssetsV2/com_apple_MobileAsset_appleTVOSSimulatorRuntime'
[[ "$(Is-Tool-Enabled codeql)" == False ]] && Delete-Many '/opt/hostedtoolcache/CodeQL'
[[ "$(Is-Tool-Enabled swift)" == False ]] && Delete-Many '/usr/share/swift'
[[ "$(Is-Tool-Enabled jvm)" == False ]] && Delete-Many '/usr/lib/jvm'
[[ "$(Is-Tool-Enabled ghcup)" == False ]] && Delete-Many '/usr/local/.ghcup'
  
  Say "Tools Cleap up complete. Total freed: $(Format-Thousand "$totalSize") MB"

  if [[ "$(command -v docker)" ]] && [[ "$(Is-Tool-Enabled docker-images)" == False ]]; then
    Say "CLEAN UP Docker Images"
    docker image prune -a -f | { grep -v "sha256:"; } || true
  fi
fi
