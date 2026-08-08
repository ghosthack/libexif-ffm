#!/usr/bin/env perl
use strict;
use warnings;

my $file = shift @ARGV or die "usage: $0 _ExifEntry.java\n";
local $/;
open my $in, '<', $file or die "$file: $!";
my $java = <$in>;
close $in;

my $changes = 0;
$changes += $java =~ s{
\x20{4}private\ static\ final\ GroupLayout\ \$LAYOUT\ =\ MemoryLayout\.structLayout\(
.*?
    \)\.withName\("_ExifEntry"\);
}{    private static final boolean WINDOWS = System.getProperty("os.name", "").toLowerCase().contains("win");

    /* C long is 32-bit on Windows x64 and 64-bit on the other supported ABIs. */
    private static final GroupLayout \$LAYOUT = WINDOWS
        ? MemoryLayout.structLayout(
            LibExif.C_INT.withName("tag"),
            LibExif.C_INT.withName("format"),
            LibExif.C_INT.withName("components"),
            MemoryLayout.paddingLayout(4),
            LibExif.C_POINTER.withName("data"),
            LibExif.C_INT.withName("size"),
            MemoryLayout.paddingLayout(4),
            LibExif.C_POINTER.withName("parent"),
            LibExif.C_POINTER.withName("priv")
        ).withName("_ExifEntry")
        : MemoryLayout.structLayout(
            LibExif.C_INT.withName("tag"),
            LibExif.C_INT.withName("format"),
            LibExif.C_LONG.withName("components"),
            LibExif.C_POINTER.withName("data"),
            LibExif.C_INT.withName("size"),
            MemoryLayout.paddingLayout(4),
            LibExif.C_POINTER.withName("parent"),
            LibExif.C_POINTER.withName("priv")
        ).withName("_ExifEntry");
}sxm;
$changes += $java =~ s/private static final OfLong components\$LAYOUT = \(OfLong\)\$LAYOUT\.select/private static final ValueLayout components\$LAYOUT = (ValueLayout)\$LAYOUT.select/;
$changes += $java =~ s/public static final OfLong components\$layout\(\)/public static final ValueLayout components\$layout()/;
$changes += $java =~ s/return struct\.get\(components\$LAYOUT, components\$OFFSET\);/return WINDOWS\n                ? Integer.toUnsignedLong(struct.get((OfInt) components\$LAYOUT, components\$OFFSET))\n                : struct.get((OfLong) components\$LAYOUT, components\$OFFSET);/;
$changes += $java =~ s/struct\.set\(components\$LAYOUT, components\$OFFSET, fieldValue\);/if (WINDOWS) {\n            if (fieldValue < 0 || fieldValue > 0xffff_ffffL) {\n                throw new IllegalArgumentException("components does not fit Windows unsigned long: " + fieldValue);\n            }\n            struct.set((OfInt) components\$LAYOUT, components\$OFFSET, (int) fieldValue);\n        } else {\n            struct.set((OfLong) components\$LAYOUT, components\$OFFSET, fieldValue);\n        }/;

die "expected 5 ExifEntry portability edits, made $changes\n" unless $changes == 5;
open my $out, '>', $file or die "$file: $!";
print {$out} $java;
close $out;
