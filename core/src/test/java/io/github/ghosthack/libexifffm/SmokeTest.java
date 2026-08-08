package io.github.ghosthack.libexifffm;

import io.github.ghosthack.libexifffm.libexif.ExifContent;
import io.github.ghosthack.libexifffm.libexif.ExifData;
import io.github.ghosthack.libexifffm.libexif.ExifDataForeachContentFunc;
import io.github.ghosthack.libexifffm.libexif.ExifEntry;
import io.github.ghosthack.libexifffm.libexif.LibExif;
import org.junit.jupiter.api.Test;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** End-to-end checks against the bundled native library. */
class SmokeTest {

    @Test
    void exposesTagAndFormatTables() {
        assertEquals("Make", cString(LibExif.exif_tag_get_name_in_ifd(
                LibExif.EXIF_TAG_MAKE(), LibExif.EXIF_IFD_0())));
        assertEquals(2, Byte.toUnsignedInt(LibExif.exif_format_get_size(LibExif.EXIF_FORMAT_SHORT())));
        assertTrue(LibExif.exif_tag_table_count() > 100);
    }

    @Test
    void parsesExifFromJpegAndReadsEntries() {
        byte[] jpeg = jpegWithExif();
        MemorySegment data;
        try (Arena arena = Arena.ofConfined()) {
            data = LibExif.exif_data_new_from_data(
                    arena.allocateFrom(ValueLayout.JAVA_BYTE, jpeg), jpeg.length);
        }
        assertNotEquals(MemorySegment.NULL, data);
        try {
            assertEquals(LibExif.EXIF_BYTE_ORDER_INTEL(), LibExif.exif_data_get_byte_order(data));
            assertEquals("Canon", entryValue(data, LibExif.EXIF_TAG_MAKE()));
            assertEquals("TestCam", entryValue(data, LibExif.EXIF_TAG_MODEL()));

            MemorySegment struct = data.reinterpret(ExifData.layout().byteSize());
            MemorySegment ifd0 = ExifData.ifd(struct).getAtIndex(ValueLayout.ADDRESS, LibExif.EXIF_IFD_0())
                    .reinterpret(ExifContent.layout().byteSize());
            // The default FOLLOW_SPECIFICATION option adds mandatory IFD0 tags.
            assertTrue(ExifContent.count(ifd0) >= 2);
            MemorySegment make = LibExif.exif_content_get_entry(ifd0, LibExif.EXIF_TAG_MAKE())
                    .reinterpret(ExifEntry.layout().byteSize());
            assertEquals(LibExif.EXIF_FORMAT_ASCII(), ExifEntry.format(make));
            assertEquals(6, ExifEntry.components(make));

            AtomicInteger visited = new AtomicInteger();
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment callback = ExifDataForeachContentFunc.allocate(
                        (content, ignored) -> visited.incrementAndGet(), arena);
                LibExif.exif_data_foreach_content(data, callback, MemorySegment.NULL);
            }
            assertEquals(LibExif.EXIF_IFD_COUNT(), visited.get());
        } finally {
            LibExif.exif_data_unref(data);
        }
    }

    @Test
    void streamingLoaderParsesTheSameJpeg() {
        MemorySegment loader = LibExif.exif_loader_new();
        assertNotEquals(MemorySegment.NULL, loader);
        try {
            byte[] jpeg = jpegWithExif();
            int split = jpeg.length / 2;
            try (Arena arena = Arena.ofConfined()) {
                MemorySegment bytes = arena.allocateFrom(ValueLayout.JAVA_BYTE, jpeg);
                assertNotEquals(0, LibExif.exif_loader_write(loader, bytes.asSlice(0, split), split));
                LibExif.exif_loader_write(loader, bytes.asSlice(split), jpeg.length - split);
            }
            MemorySegment data = LibExif.exif_loader_get_data(loader);
            assertNotEquals(MemorySegment.NULL, data);
            try {
                assertEquals("TestCam", entryValue(data, LibExif.EXIF_TAG_MODEL()));
            } finally {
                LibExif.exif_data_unref(data);
            }
        } finally {
            LibExif.exif_loader_unref(loader);
        }
    }

    @Test
    void endianHelpersRoundTripPrimitiveValues() {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment bytes = arena.allocate(8);
            LibExif.exif_set_short(bytes, LibExif.EXIF_BYTE_ORDER_MOTOROLA(), (short) 0xabcd);
            assertEquals(0xabcd, Short.toUnsignedInt(
                    LibExif.exif_get_short(bytes, LibExif.EXIF_BYTE_ORDER_MOTOROLA())));
            LibExif.exif_set_long(bytes, LibExif.EXIF_BYTE_ORDER_INTEL(), 0x78563412);
            assertEquals(0x78563412, LibExif.exif_get_long(bytes, LibExif.EXIF_BYTE_ORDER_INTEL()));
        }
    }

    private static String entryValue(MemorySegment data, int tag) {
        MemorySegment struct = data.reinterpret(ExifData.layout().byteSize());
        MemorySegment ifd0 = ExifData.ifd(struct).getAtIndex(ValueLayout.ADDRESS, LibExif.EXIF_IFD_0());
        MemorySegment entry = LibExif.exif_content_get_entry(ifd0, tag);
        assertNotEquals(MemorySegment.NULL, entry, "tag 0x" + Integer.toHexString(tag));
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment value = arena.allocate(128);
            assertNotEquals(MemorySegment.NULL, LibExif.exif_entry_get_value(entry, value, 128));
            return value.getString(0);
        }
    }

    private static String cString(MemorySegment value) {
        assertNotEquals(MemorySegment.NULL, value);
        return value.reinterpret(Long.MAX_VALUE).getString(0);
    }

    /** Minimal JPEG carrying a little-endian TIFF with Make and Model tags. */
    private static byte[] jpegWithExif() {
        ByteBuffer tiff = ByteBuffer.allocate(52).order(ByteOrder.LITTLE_ENDIAN);
        tiff.put((byte) 'I').put((byte) 'I').putShort((short) 42).putInt(8);
        tiff.putShort((short) 2);
        tiff.putShort((short) 0x010f).putShort((short) 2).putInt(6).putInt(38);
        tiff.putShort((short) 0x0110).putShort((short) 2).putInt(8).putInt(44);
        tiff.putInt(0);
        tiff.put("Canon\0".getBytes(StandardCharsets.US_ASCII));
        tiff.put("TestCam\0".getBytes(StandardCharsets.US_ASCII));

        byte[] exif = new byte[6 + tiff.capacity()];
        System.arraycopy("Exif\0\0".getBytes(StandardCharsets.US_ASCII), 0, exif, 0, 6);
        System.arraycopy(tiff.array(), 0, exif, 6, tiff.capacity());
        ByteBuffer jpeg = ByteBuffer.allocate(exif.length + 8).order(ByteOrder.BIG_ENDIAN);
        jpeg.putShort((short) 0xffd8).putShort((short) 0xffe1)
                .putShort((short) (exif.length + 2)).put(exif).putShort((short) 0xffd9);
        return jpeg.array();
    }
}
