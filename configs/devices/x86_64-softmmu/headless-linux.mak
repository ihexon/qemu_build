#
# x86_64 system emulator profile for portable, libvirt-managed headless Linux.
# Includes the microvm machine plus common virtio devices.
#

CONFIG_I440FX=y
CONFIG_Q35=y
CONFIG_MICROVM=y

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

# Q35 selects ACPI_CXL/HMAT in QEMU 11.0.0. Keep the corresponding support
# objects linked instead of patching upstream Kconfig.
CONFIG_PXB=y
CONFIG_PCIE_PORT=y
CONFIG_CXL=y
CONFIG_CXL_MEM_DEVICE=y
