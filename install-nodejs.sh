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



# RHEL6
export link_node_rhel6=$link_node_x64


header() { LightGreen='\033[1;32m';Yellow='\033[1;33m';RED='\033[0;31m'; NC='\033[0m'; printf "${LightGreen}$1${NC} ${Yellow}$2${NC}\n"; }

m=$(uname -m)
if [[ $m == armv7* ]]; then arch=arm32; elif [[ $m == aarch64* ]] || [[ $m == armv8* ]]; then arch=arm64; elif [[ $m == x86_64 ]]; then arch=x64; fi; if [[ $(uname -s) == Darwin ]]; then arch=osx; fi;
if [ ! -e /etc/os-release ] && [ -e /etc/redhat-release ]; then
  redhatRelease=$(</etc/redhat-release)
  if [[ $redhatRelease == "CentOS release 6."* || $redhatRelease == "Red Hat Enterprise Linux Server release 6."* ]]; then
    arch=rhel6;
  fi
fi


header "The current OS architecture" $arch
# if [ -f check-links.sh ]; then (. check-links.sh); fi; exit

eval link_node='$'link_node_$arch

sudo=$(command -v sudo || true)

function extract () {
  url=$1
  todir=$2
  symlinks_pattern=$3
  filename=$(basename $1)
  $sudo mkdir -p $TMPDIR/dotnet-tmp
  
  # DOWNLOADING
  counter=$((counter+1))
  header "[Step $counter] Downloading" $filename
  if [[ "$(command -v curl)" == "" ]]; then
    $sudo wget --no-check-certificate -O $TMPDIR/dotnet-tmp/$filename $url
  else
    $sudo curl -kfsSL -o $TMPDIR/dotnet-tmp/$filename $url
  fi
  $sudo mkdir -p $todir
  pushd $todir >/dev/null
  
  # EXTRACTING
  counter=$((counter+1))
  header "[Step $counter] Extracting" $filename
  if [[ $filename =~ .tar.gz$ ]]; then tarcmd=xzf; else tarcmd=xJf; fi
  if [[ ! -z "$(command -v pv)" ]]; then
    pv $TMPDIR/dotnet-tmp/$filename | $sudo tar $tarcmd -
  else
    $sudo tar $tarcmd $TMPDIR/dotnet-tmp/$filename
  fi
  popd >/dev/null
  $sudo rm -f $TMPDIR/dotnet-tmp/$filename
  add_symlinks $symlinks_pattern $todir
}

function add_symlinks() { 
  pattern=$1
  dir=$2
  if [[ $arch == osx ]]; then $sudo mkdir -p /usr/local/bin; fi
  if [ -d "/usr/local/bin" ]; then target="/usr/local/bin"; else target="/usr/bin"; fi;
  pushd "$dir" >/dev/null
  files=$(eval echo $pattern)
  for f in $files; do
    # echo Creating a link in $target/ to: $PWD/$f
    if [[ -x $f ]]; then $sudo ln -s -f "$PWD/$f" "$target/$(basename $f)"; header "Created a link in $target/ to:" "$PWD/$f"; fi
  done
  popd >/dev/null
}

counter=0;total=4;

# node, npm and yarn
function install_node() {
  $sudo rm -rf /opt/node >/dev/null 2>&1
  echo node url: $link_node
  extract $link_node "/opt/node" 'skip-symlinks'

  # adding support for global packages
  npm=$(ls -1 /opt/node/node*/bin/npm)
  nodePath=$(dirname $(ls /opt/node/node*/bin/node))
  export PATH="$nodePath:$PATH"
  printf "\n\n"'export PATH="'$nodePath':$PATH"'"\n\n" | tee -a ~/.bashrc >/dev/null

  header "Upgrading and installing" 'npm & yarn (latest)'
  other_packages="npm-check-updates"; if [[ -n "${SKIP_NPM_UPGRADE:-}" ]]; then other_packages=""; fi
  sudo bash -c "PATH=\"$nodePath:$PATH\"; npm install yarn $other_packages --global"
  sudo rm -rf ~/.npm
  add_symlinks 'node*/bin/*' /opt/node
}


install_node

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
[[ ! -z "$(command -v node)" ]]   && header "Installed node:" "$(node --version)"                            || echo node is not found
[[ ! -z "$(command -v npm)" ]]    && header "Installed npm:" "$(npm --version)"                              || echo npm is not found
[[ ! -z "$(command -v yarn)" ]]   && header "Installed yarn:" "$(yarn --version)"                            || echo yarn is not found
[[ ! -z "$(command -v dotnet)" ]] && (header "Installed dotnet:" "$(dotnet --version):"; dotnet --list-sdks) || echo dotnet is not found
psCode='"$($PSVersionTable.PSVersion) using $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)"'
[[ ! -z "$(command -v pwsh)" ]]   && header "Installed pwsh:" "$(pwsh -c $psCode)"                           || echo pwsh is not found
