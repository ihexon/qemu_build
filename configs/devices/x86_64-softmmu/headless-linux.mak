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
