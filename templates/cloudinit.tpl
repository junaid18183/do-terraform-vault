#cloud-config

coreos:
  units:
  - name: format-media-vault.service
    command: start
    content: |
      [Unit]
      Before=docker.service media-vault.mount
      # woudl be great to use blkid to only mkfs.ext4 if its not already formatted
      # $ sudo blkid /dev/disk/by-id/scsi-0DO_Volume_vault-data
      # /dev/disk/by-id/scsi-0DO_Volume_vault-data: UUID="c45f826a-8df0-48a3-9144-c9fd07fe3747" TYPE="ext4"
      ConditionPathExists=!/media/vault
      [Service]
      Type=oneshot
      ExecStart=/bin/sh -c "lsblk -nd -o FSTYPE /dev/disk/by-id/scsi-0DO_Volume_${volume_name} | grep ext4 && echo 'ok' || /usr/sbin/mkfs.ext4 /dev/disk/by-id/scsi-0DO_Volume_${volume_name}"
  - name: media-vault.mount
    enabled: true
    command: start
    content: |
      [Unit]
      Before=docker.service
      After=format-media-vault.service
      Requires=format-media-vault.service
      [Install]
      RequiredBy=docker.service
      [Mount]
      What=/dev/disk/by-id/scsi-0DO_Volume_${volume_name}
      Where=/media/vault
      Type=ext4
  - name: vault.service
    command: start
    content: |
      [Unit]
      Description=Vault Service
      After=docker.service
      [Service]
      TimeoutStartSec=0
      KillMode=none
      EnvironmentFile=/etc/environment
      ExecStartPre=-/usr/bin/docker kill vault
      ExecStartPre=-/usr/bin/docker rm vault
      ExecStartPre=/usr/bin/docker pull vault:0.6.1
      ExecStart=/usr/bin/docker run --cap-add IPC_LOCK --name vault --volume /media/vault:/vault/file -e 'VAULT_LOCAL_CONFIG={"backend": {"file": {"path": "/vault/file"}}, "listener": {"tcp":{"address":"0.0.0.0:8200", "tls_disable":1}}}' -p 8200:8200 vault:0.6.1 server
      ExecStop=/usr/bin/docker stop vault
