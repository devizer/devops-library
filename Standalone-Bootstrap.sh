#!/usr/bin/env bash

cat <<'EOFHELP' > /dev/null

# For Host
script=https://devizer.github.io/devops-library/Standalone-Bootstrap.sh; file="${TMPDIR:-/tmp}/$(basename "$script")"; cmd="curl -kfsSL -o $file $script"; $cmd || $cmd || $cmd || echo "ERROR"; bash "$file"

# For Container
Download() {
  local url="$1"; local file="$(basename "$url")"
  echo "Downloading '$url' as $(pwd -P)/$file"
  try1="wget -q -nv --no-check-certificate -O $file $url 2>/dev/null 1>&2 || curl -kfsSL -o $file $url 2>/dev/null 1>&2"
  eval $try1 || eval $try1 || eval $try1
}
saveTo="$(mktemp -d)"; cd "$saveTo"
Download https://devizer.github.io/Install-DevOps-Library.sh
Download https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh
Download https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1
docker run -it -v $(pwd -P):/app -w /app alpine sh -c "apk update; apk add bash; bash install-build-tools-bundle.sh; bash Install-DevOps-Library.sh; Wait-For-HTTP https://google-777.com 1; bash"

EOFHELP

        set -eu; set -o pipefail
        cd /tmp
        Download-File-Failover() {
          local url="$1"
          local file="$(basename "$url")"
          try1="wget -q -nv --no-check-certificate -O $file $url 2>/dev/null 1>&2 || curl -kfsSL -o $file $url 2>/dev/null 1>&2"
          eval $try1 || eval $try1 || eval $try1
        }

        Download-File-Failover "https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh"
        bash install-build-tools-bundle.sh >/dev/null
        rm -f install-build-tools-bundle.sh || true
        Say --Reset-Stopwatch
        Say "CPU: $(Get-CpuName)"

        printf "Installing DevOps-Library.sh ... "
        Download-File-Failover "https://devizer.github.io/Install-DevOps-Library.sh"
        bash Install-DevOps-Library.sh >/dev/null
        echo done
        rm -f Install-DevOps-Library.sh || true


        # time Say-Definition "NET RID is" $(Get-NET-RID)

        Download-File-Failover "https://devizer.github.io/SqlServer-Version-Management/Install-SqlServer-Version-Management.ps1"
        # on github pririty is powershell because of 5 seconds
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
        rm -f Install-SqlServer-Version-Management.ps1 || true
        [[ -n "$cmdPowershell" ]] && $cmdPowershell -c 'Write-Line -TextYellow "['$cmdPowershell'] $((Get-Memory-Info).Description)"'

