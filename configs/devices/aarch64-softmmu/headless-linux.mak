#
# aarch64 system emulator profile for portable, libvirt-managed headless Linux.
# Boot model: direct Linux kernel/initrd or externally supplied firmware.
#

CONFIG_ARM_VIRT=y
CONFIG_VMAPPLE=n

# Core virtio devices for Linux server workloads.
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_RNG=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_SCSI=y
CONFIG_VIRTIO_SERIAL=y

# libvirt guest-agent channel and virtiofs support.
CONFIG_VHOST_USER_FS=y

# ARM_VIRT selects ACPI_CXL/HMAT in QEMU 11.0.0. Keep the corresponding
# support objects linked instead of patching upstream Kconfig.
CONFIG_PXB=y
CONFIG_PCIE_PORT=y
CONFIG_CXL=y
CONFIG_CXL_MEM_DEVICE=y

