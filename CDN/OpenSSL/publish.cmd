gh release delete openssl --cleanup-tag --yes
gh release create openssl W:\Cloud\MEGA\OpenSSL3-Binaries\public\*.* ^
  -t "OpenSSL 1.1.1 and 3.* binaries for linux" ^
  -F RELEASE_NOTES.md

start https://github.com/devizer/devops-library/releases
