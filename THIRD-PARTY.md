# Third-party notices

The classifier jars contain a shared library built from unmodified libexif
0.6.26 source. libexif files are licensed under LGPL-2.1-or-later and
LGPL-2.0-or-later; the complete upstream `COPYING` file and exact build details
ship inside every classifier jar.

- Source: https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2
- NLS is disabled, so the shipped library has no gettext runtime dependency.
- The library is dynamically loaded and user-replaceable through
  `LIBEXIF_FFM_LIBDIR` or `-Dlibexifffm.libdir`, providing the relinking path
  required by the LGPL.

The Java binding and loader code contains no libexif source and is MIT licensed.
