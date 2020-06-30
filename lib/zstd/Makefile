obj-$(CONFIG_ZSTD_COMPRESS) += zstd_compress.o
obj-$(CONFIG_ZSTD_DECOMPRESS) += zstd_decompress.o

ccflags-y += -O3

# optimise for size
ccflags-y += $(call cc-option, -g0)
ccflags-y += $(call cc-option, -Os)

# Object files unique to zstd_compress and zstd_decompress
zstd_compress-y := fse_compress.o huf_compress.o compress.o
zstd_decompress-y := huf_decompress.o decompress.o

# These object files are shared between the modules.
# Always add them to zstd_compress.
# Unless both zstd_compress and zstd_decompress are built in
# then also add them to zstd_decompress.
zstd_compress-y += entropy_common.o fse_decompress.o zstd_common.o

ifneq ($(CONFIG_ZSTD_COMPRESS)$(CONFIG_ZSTD_DECOMPRESS),yy)
	zstd_decompress-y += entropy_common.o fse_decompress.o zstd_common.o
endif
