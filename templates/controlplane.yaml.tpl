machine:
  time:
    servers:
      - 169.254.169.254
  certSANs:
  - ${endpoint_ipv4}
  features:
    kubePrism:
      enabled: true
      port: 7445
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
  apiServer:
    certSANs: 
    - ${endpoint_ipv4}
  allowSchedulingOnControlPlanes: ${allowSchedulingOnControlPlanes}
