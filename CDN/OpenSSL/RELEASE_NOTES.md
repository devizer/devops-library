## OpenSSL 1.1.1 and 3.* binaries intended for glibc and musl Linux.

The main purposes of the release are:
1. End-to-end and integration testing of .NET applications.
2. Distribution of a .NET service/application without requiring users to install OpenSSL libraries. 

### End-To-End testing scenario
```
Run-Remote-Script https://devizer.github.io/devops-library/install-libssl.sh \
    <version> \
    --target-folder /opt/libssl-3.5 \
    --register [--first|--last] \
    [--force]
```
It downloads OpenSSL binaries into the specified folder and registers them with the dynamic linker. 
Options **--first** and **--last** define the position in the dynamic loader configuration.

By default the command does nothing if OpenSSL libraries are already registered. The **--force** option overrides this behavior

Supported version arguments:
1.1.1, 3.5 or any X.Y.Z from the assets below. Default is 1.1.1

### Software distribution scenario:
For example, assume you have built self-contained portable binaries of your own application into 6 folders: ./superapp-linux-{arm,arm64,x64,musl-arm,musl-arm64,musl-x64}
To distribute it, include OpenSSL 3.5 LTS as part of the application side-by-side:
```
runtimes="arm arm64 x64 musl-arm musl-arm64 musl-x64"
for rid in $runtimes; do
  Run-Remote-Script https://devizer.github.io/devops-library/install-libssl.sh \
      v3.5 --target-folder "./superapp-linux-$rid/libssl-v3.5"
done 
```

It will create a libssl-v3.5 subfolder for each package and will download the appropriate builds of libcrypto.so.3 and libssl.so.3 into the corresponding folder.
Later, in your application launcher, you can explicitly enforce the use of these private binaries, even if the system already has preinstalled OpenSSL 3 binaries.
```
LD_LIBRARY_PATH=/path/to/superapp/libssl-v3.5 ./superapp
```

Another way is to prefer the system version of libssl 3 if it is preinstalled
```
libssl_exists=False
if [[ -n "$(command -v ldconfig)" ]]; then
  if [[ -n "$(ldconfig -p | grep libssl.so.3)" && -n "$(ldconfig -p | grep libcrypto.so.3)" ]]; then
    libssl_exists=True
  fi
fi
if [[ "$libssl_exists" == True ]]; then
  echo "The system already has libssl.so.3 and libcrypto.so.3" 
  echo "Starting superapp using them"
else
  echo "The system misses libssl.so.3 and libcrypto.so.3
  echo "Starting superapp using libssl 3.5 from libssl-v3.5 folder"
  export LD_LIBRARY_PATH=/path/to/superapp/libssl-v3.5
fi
/path/to/superapp/superapp
```

### Build Notes

* Minimum glibc version: 2.19
* Minimum musl libc version: 1.1.18
* All OpenSSL binaries are built with runtime CPU feature detection to maximize performance.
* Minimum x86_64 CPU requirements: An SSE2-capable processor. AVX2 and AES instructions are optional but recommended.
* Minimum 32-bit ARM CPU requirements: ARMv7. NEON instructions are optional but recommended.
* ARM64: No specific CPU requirements.
* Version 3.5 LTS binaries will be rebuilt until EOL on April 8, 2030.
