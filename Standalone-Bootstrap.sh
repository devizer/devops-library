#!/usr/bin/env bash

cat <<'EOFHELP' > /dev/null

# For Host
script=https://devizer.github.io/devops-library/Standalone-Bootstrap.sh;
file="${TMPDIR:-/tmp}/$(basename "$script")";
cmd="wget -q -nv --no-check-certificate -O \"$file\" \"$script\" 2>/dev/null 1>&2 || curl -kfsSL -o \"$file\" \"$script\"";
eval $cmd || eval $cmd || eval $cmd || echo "ERROR: Download bootstrapper failed";
bash "$file"

# For Container
saveTo="$(mktemp -d)";
Download() {
  local url="$1"; local file="$(basename "$url")"
  echo "Downloading '$url' as $saveTo/$file"
  try1="wget -q -nv --no-check-certificate -O \"$saveTo\"/$file $url 2>/dev/null 1>&2 || curl -kfsSL -o \"$saveTo\"/$file $url 2>/dev/null 1>&2"
  eval $try1 || eval $try1 || eval $try1 || { echo "Error downloading $url"; return 1; }
}
Download https://devizer.github.io/Install-DevOps-Library.sh
Download https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh
Download https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1
docker run -it -v "$saveTo":/tmp/bootstrap -w /tmp/bootstrap alpine sh -c "apk update; apk add bash; bash install-build-tools-bundle.sh; bash Install-DevOps-Library.sh; Wait-For-HTTP https://google-777.com 1; Wait-For-HTTP https://google.com 1; bash"

EOFHELP

        if [[ "$(uname -s)" == "Darwin" ]]; then
            echo '#!/bin/bash
            set -eu;
            sysctl -n hw.logicalcpu
            ' | sudo tee /usr/local/bin/nproc >/dev/null
            sudo chmod +x /usr/local/bin/nproc
        fi

        set -eu; set -o pipefail

        if [[ -z "${TARGET_DIR:-}" ]]; then
           if [[ "$(uname -s)" == "MSYS"* || "$(uname -s)" == "MINGW"* ]]; then
             export TARGET_DIR=/usr/bin
             echo "[Info] On Windows bash scripts targets to '$TARGET_DIR' (default)"
           fi
        fi

        if [[ -n "${TARGET_DIR:-}" ]]; then
          echo "[DevOps Library Setup] Checking explicit TARGET_DIR: '${TARGET_DIR:-}'"
          sudo="sudo"; if [[ -z "$(command -v sudo)" ]] || [[ "$(uname -s)" == "MSYS"* || "$(uname -s)" == "MINGW"* ]]; then sudo=""; fi
          mkdir -p "${TARGET_DIR:-}" 2>/dev/null || $sudo mkdir -p "${TARGET_DIR:-}" 2>/dev/null || true
          if [[ ! -d "${TARGET_DIR:-}" ]]; then
            echo "[DevOps Library Setup] Warning! Explicit TARGET_DIR '${TARGET_DIR:-}' cannot be created"
          fi
        fi
        
        pushd "${TMPDIR:-/tmp}" >/dev/null

        Download-File-Failover() {
          local url="$1"
          local file="$(basename "$url")"
          try1="wget -q -nv --no-check-certificate -O $file $url 2>/dev/null 1>&2 || curl -kfsSL -o $file $url 2>/dev/null 1>&2"
          eval $try1 || eval $try1 || eval $try1 || { echo "Error downloading $url"; return 1; }
        }

        Download-File-Failover "https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh"
        bash install-build-tools-bundle.sh
        rm -f install-build-tools-bundle.sh || true
        if [[ -n "$(command -v Get-CpuName)" ]]; then
          Say --Reset-Stopwatch
          Say "CPU: $(Get-CpuName)"
        fi

        printf "Installing DevOps-Library.sh ... "
        Download-File-Failover "https://devizer.github.io/Install-DevOps-Library.sh"
        bash Install-DevOps-Library.sh # >/dev/null
        # echo done
        rm -f Install-DevOps-Library.sh || true

        unset TARGET_DIR


        # time Say-Definition "NET RID is" $(Get-NET-RID)
        Download-File-Failover "https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1"
        Version-Brute() {
              cmdPowershell=""
              if [[ -n "$(command -v pwsh)" ]]; then pwsh Install-SqlServer-Version-Management.ps1; cmdPowershell=pwsh; fi
              if [[ -n "$(command -v powershell)" ]]; then powershell -f Install-SqlServer-Version-Management.ps1; cmdPowershell=powershell; fi
              rm -f Install-SqlServer-Version-Management.ps1 || true
              [[ -n "$cmdPowershell" ]] && $cmdPowershell -c 'Write-Line -TextYellow "['$cmdPowershell'] $((Get-Memory-Info).Description)"'
        }
        Version-Fast() {
              # on github priority is powershell because of 5 seconds
              cmdPowershell="";
              if [[ -n "$(command -v powershell)" ]]; then cmdPowershell="powershell";
              elif [[ -n "$(command -v pwsh)" ]]; then cmdPowershell="pwsh"; fi
              if [[ -n "$cmdPowershell" ]]; then
                 _IsWindows=False; [[ "$(uname -s)" == "MSYS"* || "$(uname -s)" == "MINGW"* ]] && _IsWindows=True
                 if [[ "${_IsWindows}" == 'True' ]]; then
                   # for 5 seconds install into both pwsh and powershell using single process
                   PS_Script='
                               $docs = [System.Environment]::GetFolderPath("MyDocuments");
                               foreach($subFolder in "WindowsPowerShell", "PowerShell") {
                                 $target = "$docs\$subFolder\Modules";
                                 try { [System.IO.Directory]::CreateDirectory($target) | Out-Null } catch {}
                                 if ([System.IO.Directory]::Exists($target)) {
                                   # echo "EXISTS: [$target]";
                                   .\Install-SqlServer-Version-Management.ps1 -InstallTo "$target"
                                 }
                               }
                   '

                   echo "$PS_Script" | $cmdPowershell -c -
                 else
                   # Linux/MacOS
                   $cmdPowershell -c "./Install-SqlServer-Version-Management.ps1"
                 fi
              fi
              wait
        }
        Version-Fast

        popd >/dev/null
