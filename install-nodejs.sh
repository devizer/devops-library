#!/usr/bin/env bash
# Here is one line installer : export NODE_VER=v16.20.2
# script=https://raw.githubusercontent.com/devizer/glist/master/install-dotnet-and-nodejs.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash -s dotnet node pwsh

# NODE_VER=${NODE_VER:-v14.19.1}
NODE_VER=${NODE_VER:-v16.20.2}
NODE_VER_JESSIE=${NODE_VER_JESSIE:-v10.21.0}
SKIP_NPM_UPGRADE="${SKIP_NPM_UPGRADE:True}"

if [[ -n "${1:-}" ]]; then
  NODE_VER="${1:-}"
fi

set -ue

TMPDIR="${TMPDIR:-/tmp}"
echo Download buffer location: $TMPDIR

is_jessie=false
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "${VERSION_ID:-}" == "8" && "$ID" == "debian" ]]; then
  	is_jessie=true
  fi
fi

# ARM 64
export link_node_arm64='https://nodejs.org/dist/'$NODE_VER'/node-'$NODE_VER'-linux-arm64.tar.xz'
test "$is_jessie" == "true" && export link_node_arm64='https://nodejs.org/dist/'$NODE_VER_JESSIE'/node-'$NODE_VER_JESSIE'-linux-arm64.tar.xz'

# X64
export link_node_x64='https://nodejs.org/dist/'$NODE_VER'/node-'$NODE_VER'-linux-x64.tar.xz'
# on x64 12x also works?
test "$is_jessie" == "true" && export link_node_x64='https://nodejs.org/dist/'$NODE_VER_JESSIE'/node-'$NODE_VER_JESSIE'-linux-x64.tar.gz'

# ARM
export link_node_arm32='https://nodejs.org/dist/'$NODE_VER'/node-'$NODE_VER'-linux-armv7l.tar.xz'
test "$is_jessie" == "true" && export link_node_arm32='https://nodejs.org/dist/'$NODE_VER_JESSIE'/node-'$NODE_VER_JESSIE'-linux-armv7l.tar.gz'


# OSX
osx_machine="$(sysctl -n hw.machine 2>/dev/null || true)"
osx_suffix="x64"; [[ "$osx_machine" == *"arm"* ]] && osx_suffix="arm64"
export link_node_osx='https://nodejs.org/dist/'$NODE_VER'/node-'$NODE_VER'-darwin-'$osx_suffix'.tar.gz'

rid=$(Get-NET-RID)
if [[ "$rid" == "win-x64" ]]; then
  url_suffix=win-x64.7z
elif [[ "$rid" == "win" ]]; then
  url_suffix=win-x86.7z
elif [[ "$rid" == "win-arm64" ]]; then
  url_suffix=win-arm64.7z
elif [[ "$rid" == "osx-arm64" ]]; then
  url_suffix=darwin-arm64.tar.xz
elif [[ "$rid" == "osx-x64" ]]; then
  url_suffix=darwin-x64.tar.xz
elif [[ "$rid" == "linux-x64" ]]; then
  url_suffix=linux-x64.tar.gz
elif [[ "$rid" == "linux-arm64" ]]; then
  url_suffix=linux-arm64.tar.gz
elif [[ "$rid" == "linux-arm" ]]; then
  url_suffix=linux-armv7l.tar.gz
else
  url_suffix=unknown
  echo "Warning! Unknown nodejs platform '$rid'" >&2
fi

link_node='https://nodejs.org/dist/'$NODE_VER'/node-'$NODE_VER'-'$url_suffix



header() { LightGreen='\033[1;32m';Yellow='\033[1;33m';RED='\033[0;31m'; NC='\033[0m'; printf "${LightGreen}$1${NC} ${Yellow}${2:-}${NC}\n"; }


header "The current OS node download: '$url_suffix'"
echo "Download url: '$link_node'"

sudo=$(command -v sudo || true)
sudo=$(Get-Sudo-Command)

function extract () {
  url=$1
  todir=$2
  symlinks_pattern=$3
  filename=$(basename $1)
  $sudo mkdir -p $TMPDIR/node-tmp
  
  # DOWNLOADING
  counter=$((counter+1))
  header "[Step $counter] Downloading" $filename
  if [[ "$(command -v curl)" == "" ]]; then
    $sudo wget --no-check-certificate -O $TMPDIR/node-tmp/$filename $url
  else
    $sudo curl -kfsSL -o $TMPDIR/node-tmp/$filename $url
  fi
  $sudo mkdir -p $todir
  pushd $todir >/dev/null
  
  # EXTRACTING
  counter=$((counter+1))
  header "[Step $counter] Extracting" $filename
  if [[ "$rid" != win* ]]; then
      if [[ $filename =~ .tar.gz$ ]]; then tarcmd=xzf; else tarcmd=xJf; fi
      if [[ ! -z "$(command -v pv)" ]]; then
        pv $TMPDIR/node-tmp/$filename | $sudo tar $tarcmd -
      else
        $sudo tar $tarcmd $TMPDIR/node-tmp/$filename
      fi
  else
    7z -y x $TMPDIR/node-tmp/$filename
  fi
  popd >/dev/null
  $sudo rm -f $TMPDIR/node-tmp/$filename
  # add_symlinks $symlinks_pattern $todir
}

function add_symlinks() { 
  pattern=$1
  dir=$2
  if [[ "$rid" == osx* ]]; then $sudo mkdir -p /usr/local/bin; fi
  if [ -d "/usr/local/bin" ]; then target="/usr/local/bin"; else target="/usr/bin"; fi;
  pushd "$dir" >/dev/null
  files=$(eval echo $pattern)
  for f in $files; do
    # echo Creating a link in $target/ to: $PWD/$f
    if [[ -x $f ]]; then 
      $sudo ln -s -f "$PWD/$f" "$target/$(basename $f)"; 
      header "Created a link in $target/ to:" "$PWD/$f"; 
    fi
  done
  popd >/dev/null
}

counter=0;total=4;

# node, npm and yarn
install_node() {
  $sudo rm -rf /opt/node >/dev/null 2>&1
  echo node url: $link_node
  extract $link_node "/opt/node" 'skip-symlinks'

  # adding support for global packages
  npm=$(ls -1 /opt/node/node*/bin/npm 2>/dev/null || ls -1 /opt/node/node*/npm)
  nodePath=$(dirname "$npm")
  export PATH="$nodePath:$PATH"
  printf "\n\n"'export PATH="'$nodePath':$PATH"'"\n\n" | tee -a ~/.bashrc >/dev/null

  echo "Upgrading and installing: yarn"
  other_packages="npm-check-updates"; if [[ -n "${SKIP_NPM_UPGRADE:-}" ]]; then other_packages=""; fi
  other_packages=""
  $sudo bash -c "PATH=\"$nodePath:$PATH\"; npm install yarn $other_packages --global"
  $sudo rm -rf ~/.npm
  if [[ "$(Get-OS-Platform)" != Windows ]]; then
     add_symlinks 'node*/bin/*' /opt/node
  else
     cd /opt/node/node*
     export win_folder_for_path="$(pwd -W)"
     ps1_script=$(mktemp)
     cat <<'EOFADDPATH' > "$ps1_script"
                $folder = $ENV:win_folder_for_path
                $target = "User"
                $thePath = [Environment]::GetEnvironmentVariable("PATH", "$target");
                $arr = $thePath.Split(";")
                $has = $null -ne ($arr | ? { $_ -eq $folder })
                if ($has) {
                  Write-Host "Folder $folder already in the $($target) path"
                }
                else {
                  $arr += "$folder"
                  $newPath = $arr -join ";"
                  & setx "PATH" "$newPath"
                  Write-Host "New $($target) Path: '$newPath'"
                }
EOFADDPATH
     powershell -ExecutionPolicy Bypass -f "$ps1_script"
     rm -f "$ps1_script"
  fi
}


install_node

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
[[ ! -z "$(command -v node)" ]]   && header "Installed node:" "$(node --version)"                            || echo node is not found
[[ ! -z "$(command -v npm)" ]]    && header "Installed npm:" "$(npm --version)"                              || echo npm is not found
[[ ! -z "$(command -v yarn)" ]]   && header "Installed yarn:" "$(yarn --version)"                            || echo yarn is not found
[[ ! -z "$(command -v dotnet)" ]] && (header "Installed dotnet:" "$(dotnet --version):"; dotnet --list-sdks) || echo dotnet is not found
psCode='"$($PSVersionTable.PSVersion) using $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)"'
[[ ! -z "$(command -v pwsh)" ]]   && header "Installed pwsh:" "$(pwsh -c $psCode)"                           || echo pwsh is not found
