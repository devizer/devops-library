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

        set -eu; set -o pipefail
        cd /tmp
        Download-File-Failover() {
          local url="$1"
          local file="$(basename "$url")"
          try1="wget -q -nv --no-check-certificate -O $file $url 2>/dev/null 1>&2 || curl -kfsSL -o $file $url 2>/dev/null 1>&2"
          eval $try1 || eval $try1 || eval $try1 || { echo "Error downloading $url"; return 1; }
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
        cmdPowershell=""
        if [[ -n "$(command -v powershell)" ]]; then powershell -f Install-SqlServer-Version-Management.ps1; cmdPowershell=powershell; fi
        if [[ -n "$(command -v pwsh)" ]]; then pwsh Install-SqlServer-Version-Management.ps1; cmdPowershell=pwsh; fi
        rm -f Install-SqlServer-Version-Management.ps1 || true
        [[ -n "$cmdPowershell" ]] && $cmdPowershell -c 'Write-Line -TextYellow "['$cmdPowershell'] $((Get-Memory-Info).Description)"'

