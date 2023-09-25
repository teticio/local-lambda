#!/usr/bin/env bash

# Configure our firecracker-containerd binary to use our new snapshotter and
# separate storage from the default containerd binary
sudo mkdir -p /etc/firecracker-containerd
sudo mkdir -p /var/lib/firecracker-containerd/containerd
# Create the shim base directory for which firecracker-containerd will run the
# shim from
sudo mkdir -p /var/lib/firecracker-containerd
sudo tee /etc/firecracker-containerd/config.toml <<EOF
version = 2
disabled_plugins = ["io.containerd.grpc.v1.cri"]
root = "/var/lib/firecracker-containerd/containerd"
state = "/run/firecracker-containerd"
[grpc]
  address = "/run/firecracker-containerd/containerd.sock"
[plugins]
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "fc-dev-thinpool"
    base_image_size = "5GB"
    root_path = "/var/lib/firecracker-containerd/snapshotter/devmapper"

[debug]
  level = "debug"
EOF

# Setup device mapper thin pool
sudo mkdir -p /var/lib/firecracker-containerd/snapshotter/devmapper
DIR=/var/lib/firecracker-containerd/snapshotter/devmapper
POOL=fc-dev-thinpool

if [[ ! -f "${DIR}/data" ]]; then
    sudo touch "${DIR}/data"
    sudo truncate -s 10G "${DIR}/data"
fi

if [[ ! -f "${DIR}/metadata" ]]; then
    sudo touch "${DIR}/metadata"
    sudo truncate -s 2G "${DIR}/metadata"
fi

DATADEV="$(sudo losetup --output NAME --noheadings --associated ${DIR}/data)"
if [[ -z "${DATADEV}" ]]; then
    DATADEV="$(sudo losetup --find --show ${DIR}/data)"
fi

METADEV="$(sudo losetup --output NAME --noheadings --associated ${DIR}/metadata)"
if [[ -z "${METADEV}" ]]; then
    METADEV="$(sudo losetup --find --show ${DIR}/metadata)"
fi

SECTORSIZE=512
DATASIZE="$(sudo blockdev --getsize64 -q ${DATADEV})"
LENGTH_SECTORS=$(bc <<< "${DATASIZE}/${SECTORSIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768
THINP_TABLE="0 ${LENGTH_SECTORS} thin-pool ${METADEV} ${DATADEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK} 1 skip_block_zeroing"
echo "${THINP_TABLE}"

if ! $(sudo dmsetup reload "${POOL}" --table "${THINP_TABLE}"); then
    sudo dmsetup create "${POOL}" --table "${THINP_TABLE}"
fi

# Configure the aws.firecracker runtime
# The long kernel command-line configures systemd inside the Debian-based image
# and uses a special init process to create a read-write overlay on top of the
# read-only image.
sudo mkdir -p /var/lib/firecracker-containerd/runtime
sudo cp default-rootfs.img /var/lib/firecracker-containerd/runtime/default-rootfs.img
sudo cp vmlinux /var/lib/firecracker-containerd/runtime/default-vmlinux.bin
sudo mkdir -p /etc/containerd
sudo tee /etc/containerd/firecracker-runtime.json <<EOF
{
  "firecracker_binary_path": "$(which firecracker)",
  "cpu_template": "T2",
  "log_fifo": "fc-logs.fifo",
  "log_levels": ["debug"],
  "metrics_fifo": "fc-metrics.fifo",
  "kernel_args": "console=ttyS0 noapic reboot=k panic=1 pci=off fastboot nomodules ro systemd.unified_cgroup_hierarchy=0 systemd.journald.forward_to_console systemd.unit=firecracker.target init=/sbin/overlay-init",
  "default_network_interfaces": [{
    "CNIConfig": {
      "NetworkName": "fcnet",
      "InterfaceName": "veth0"
    }
  }],
  "jailer": {
    "runc_binary_path": "$(which runc)",
    "runc_config_path": "/etc/containerd/firecracker-runc-config.json"
  }
}
EOF

# Add jailer config
sudo tee /etc/containerd/firecracker-runc-config.json <<EOF
{
    "ociVersion": "1.0.1",
    "process": {
        "terminal": false,
        "user": {
            "uid": 0,
            "gid": 0
        },
        "args": [
            "/firecracker",
            "--api-sock",
            "api.socket"
        ],
        "env": [
            "PATH=/"
        ],
        "cwd": "/",
        "capabilities": {
            "effective": [
            ],
            "bounding": [
            ],
            "inheritable": [
            ],
            "permitted": [
            ],
            "ambient": [
            ]
        },
        "rlimits": [
            {
                "type": "RLIMIT_NOFILE",
                "hard": 1024,
                "soft": 1024
            }
        ],
        "noNewPrivileges": true
    },
    "root": {
        "path": "rootfs",
        "readonly": false
    },
    "hostname": "runc",
    "mounts": [
        {
            "destination": "/proc",
            "type": "proc",
            "source": "proc"
        }
    ],
    "linux": {
        "devices": [
            {
               "path": "/dev/kvm",
               "type": "c",
               "major": 10,
               "minor": 232,
               "fileMode": 438,
               "uid": 0,
               "gid": 0
            },
            {
               "path": "/dev/net/tun",
               "type": "c",
               "major": 10,
               "minor": 200,
               "fileMode": 438,
               "uid": 0,
               "gid": 0
            }
        ],
        "resources": {
            "memory": {
                "limit": 536870912
            },
            "devices": [
                {
                    "allow": false,
                    "access": "rwm"
                },
                {
                    "allow": true,
                    "major": 10,
                    "minor": 232,
                    "access": "rwm"
                },
                {
                    "allow": true,
                    "major": 10,
                    "minor": 200,
                    "access": "rwm"
                }
            ]
        },
        "namespaces": [
            {
                "type": "cgroup"
            },
            {
                "type": "pid"
            },
            {
                "type": "network"
            },
            {
                "type": "ipc"
            },
            {
                "type": "uts"
            },
            {
                "type": "mount"
            }
        ],
        "maskedPaths": [
            "/proc/asound",
            "/proc/kcore",
            "/proc/latency_stats",
            "/proc/timer_list",
            "/proc/timer_stats",
            "/proc/sched_debug",
            "/sys/firmware",
            "/proc/scsi"
        ],
        "readonlyPaths": [
            "/proc/bus",
            "/proc/fs",
            "/proc/irq",
            "/proc/sys",
            "/proc/sysrq-trigger"
        ]
    }
}
EOF
