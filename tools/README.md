# tools/

`jextract/gen-bindings.sh` expects jextract 22 unpacked as
`tools/jextract-22`:

```sh
curl -sfL https://download.java.net/java/early_access/jextract/22/6/openjdk-22-jextract+6-47_macos-aarch64_bin.tar.gz | tar xz -C tools/
```

jextract 22 emits the finalized FFM API used by every JDK version from 22
onward. Stub generation runs on macOS; a post-generation ABI adjustment keeps
libexif's C `unsigned long` entry field correct on Win64 as well.
