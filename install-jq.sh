#!/usr/bin/env bash
# Here is one line installer 
# Run-Remote-Script https://devizer.github.io/devops-library/install-jq.sh --target-folder /usr/local/bin --version 1.8.1
set -eu; set -o pipefail
set -o pipefail

INSTALL_DIR=""
JQ_VERSION="1.8.1"

rid=$(Get-NET-RID)
suffix="unknown"
if [[ "$rid" == "linux"*"x64" ]]; then suffix="linux-amd64"; fi
if [[ "$rid" == "linux"*"arm64" ]]; then suffix="linux-arm64"; fi
if [[ "$rid" == "linux"*"arm" ]]; then suffix="linux-armhf"; fi
if [[ "$rid" == "linux"*"i386" ]]; then suffix="linux-i386"; fi
if [[ "$rid" == "linux"*"armel" ]]; then suffix="linux-armel"; fi
url="https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION/jq-$suffix"

while [ $# -gt 0 ]; do
  case "$1" in
    --target-folder)
      if [ -z "${2:-}" ]; then
        echo "Error: --target-folder requires a non-empty argument" >&2
        exit 1
      fi
      INSTALL_DIR="$2"
      shift 2
      ;;
    --version)
      if [ -z "${2:-}" ]; then
        echo "Error: --version requires a non-empty argument" >&2
        exit 1
      fi
      JQ_VERSION="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

sudo=$(command -v sudo || true)

if [[ "$(uname -s)" != Linux ]]; then
  echo "A Linux OS is expected for jq, platform is not supported"
  exit 0
fi

export TMPDIR="${TMPDIR:-/tmp}"
if [[ -z "${INSTALL_DIR:-}" ]]; then
  $sudo mkdir -p /usr/local/bin;
  if [[ -d /usr/local/bin ]]; then 
     INSTALL_DIR=/usr/local/bin
  elif [[ "$(Is-Termux)" ]]; then
     INSTALL_DIR=$PREFIX/bin
  else
    echo "Unable to auto-detect target bin folder for jq"
    exit 1
  fi
fi

Colorize Yellow "Downloading static jq version '$JQ_VERSION' into folder '$INSTALL_DIR'"
file="$(MkTemp-File-Smarty "$(basename "$url")")"
echo "Download url: '$url' as '$file'"
Download-File "$url" "$file"

$sudo cp -v "$file" "$INSTALL_DIR"/jq
$sudo chmod +x "$file"
echo "Validating jq ..."
ver=$("$INSTALL_DIR"/jq --version || true)
if [[ -n "$ver" ]]; then Colorize Green "OK: $ver"
else Colorize Red "Fail. jq binary '$INSTALL_DIR/jq'' is invalid"
fi
