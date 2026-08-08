# libexif-ffm

Panama FFM (jextract) bindings for libexif with bundled, from-source natives.
One Maven coordinate, batteries included: no user-installed libexif and no JNI.

| Artifact | Contents | License |
|---|---|---|
| `io.github.ghosthack:libexif-ffm` | Complete public libexif API + runtime loader (pure Java, JDK ≥ 22) | MIT |
| `io.github.ghosthack:libexif-ffm-natives` (`macos-arm64`, `windows-x64`, `linux-x64`) | libexif 0.6.26 shared library built from unmodified source | LGPL-2.1-or-later and LGPL-2.0-or-later |

The generated surface covers file and memory loading, streaming loaders,
IFD/entry traversal and mutation, endian-aware primitive helpers, tag tables,
thumbnails, MakerNotes, logging callbacks, custom allocators, and the variadic
`exif_log.makeInvoker(...)` API.

## Use

```xml
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libexif-ffm</artifactId>
  <version>0.6.26-0.1.0-SNAPSHOT</version>
</dependency>
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libexif-ffm-natives</artifactId>
  <version>0.6.26-0.1.0-SNAPSHOT</version>
  <classifier>macos-arm64</classifier> <!-- or windows-x64 / linux-x64 -->
  <scope>runtime</scope>
</dependency>
```

On the module path, declare `requires libexif.ffm;` and run with
`--enable-native-access=libexif.ffm`. On the class path, use
`--enable-native-access=ALL-UNNAMED`.

```java
import io.github.ghosthack.libexifffm.libexif.ExifContent;
import io.github.ghosthack.libexifffm.libexif.ExifData;
import io.github.ghosthack.libexifffm.libexif.LibExif;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;

try (Arena arena = Arena.ofConfined()) {
    MemorySegment data = LibExif.exif_data_new_from_file(
            arena.allocateFrom("photo.jpg")); // native loads on first call
    if (data.equals(MemorySegment.NULL)) throw new IllegalArgumentException("no EXIF data");
    try {
        MemorySegment struct = data.reinterpret(ExifData.layout().byteSize());
        MemorySegment ifd0 = ExifData.ifd(struct)
                .getAtIndex(ValueLayout.ADDRESS, LibExif.EXIF_IFD_0())
                .reinterpret(ExifContent.layout().byteSize());
        MemorySegment entry = LibExif.exif_content_get_entry(ifd0, LibExif.EXIF_TAG_MAKE());
        MemorySegment value = arena.allocate(256);
        LibExif.exif_entry_get_value(entry, value, 256);
        System.out.println(value.getString(0));
    } finally {
        LibExif.exif_data_unref(data);
    }
}
```

See `core/src/test/java/.../SmokeTest.java` for memory parsing, streaming loads,
callbacks, raw struct access, and endian helpers.

### Library resolution

1. `-Dlibexifffm.libdir=<dir>` or `LIBEXIF_FFM_LIBDIR` uses a compatible
   existing libexif installation;
2. otherwise the classifier jar is extracted once to
   `~/.cache/libexif-ffm/<version>-<platform>/`;
3. libraries already loaded by the host application are the final fallback.

### Native memory

Pointers passed to C must reference native memory. Copy Java byte arrays with
`arena.allocateFrom(ValueLayout.JAVA_BYTE, bytes)` rather than passing
`MemorySegment.ofArray(bytes)` directly. Keep upcall stubs and their arenas
alive for as long as native code can invoke them.

libexif owns objects returned by `exif_*_new`; release them with the matching
`exif_*_unref`. Consult the generated C snippets and the upstream libexif API
documentation for borrowed-pointer and allocator rules.

## Building

Fetch the pinned source, build this platform's native, regenerate stubs on
macOS, and install:

```sh
mkdir -p build
curl -sfL https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2 | tar xj -C build
build-natives/macos-arm64.sh
jextract/gen-bindings.sh
mvn clean install
```

The Windows script runs in an MSYS2 MINGW64 shell. The Linux script targets
x86-64. Each script disables NLS to produce a self-contained shared library and
rejects unexpected runtime dependencies before staging it.

Generated bindings are checked in; `tools/jextract-22` is not. See
`tools/README.md` for the pinned generator download. Native staging directories
are build outputs and are not committed.
