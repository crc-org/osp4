#!/bin/sh

set +x

prerequisites()
{
    # Check if virtualization is supported
    ls /dev/kvm 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo "Your system doesn't support virtualization"
        exit 1
    fi

    # Install required dependecies
    sudo yum install -y libvirt libvirt-devel libvirt-daemon-kvm qemu-kvm

    # Enable IP forwarding
    sudo sysctl net.ipv4.ip_forward=1

    # Configure libvirt to accept TCP connections
    sudo sed -i.bak -e 's/^[#]*\s*listen_tls.*/listen_tls = 0/' -e 's/^[#]*\s*listen_tcp.*/listen_tcp = 1/' -e 's/^[#]*\s*auth_tcp.*/auth_tcp = "none"/' -e 's/^[#]*\s*tcp_port.*/tcp_port = "16509"/' /etc/libvirt/libvirtd.conf

    # Configure the service runner to pass --listen to libvirtd
    sudo sed -i.bak -e 's/^[#]*\s*LIBVIRTD_ARGS.*/LIBVIRTD_ARGS="--listen"/' /etc/sysconfig/libvirtd

    # Restart the libvirtd service
    sudo systemctl restart libvirtd

    # Get active Firewall zone option
    systemctl is-active firewalld
    if [ $? -ne 0 ]
    then
        echo "Your system doesn't have firewalld service running"
        exit 1
    fi

    activeZone=$(firewall-cmd --get-active-zones | head -n 1)
    sudo firewall-cmd --zone=$activeZone --add-source=192.168.126.0/24
    sudo firewall-cmd --zone=$activeZone --add-port=16509/tcp

    # Configure default libvirt storage pool
    sudo virsh --connect qemu:///system pool-list | grep -q 'default'
    if [ $? -ne 0 ]
    then
        sudo virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
    sudo virsh pool-start default
    sudo virsh pool-autostart default
    fi

    # Set up NetworkManager DNS overlay
    dnsconf=/etc/NetworkManager/conf.d/crc-libvirt-dnsmasq.conf
    local dnschanged=""
    if ! [ -f "${dnsconf}" ]; then
        echo -e "[main]\ndns=dnsmasq" | sudo tee "${dnsconf}"
        dnschanged=1
    fi
    dnsmasqconf=/etc/NetworkManager/dnsmasq.d/openshift.conf
    if ! [ -f "${dnsmasqconf}" ]; then
        echo server=/tt.testing/192.168.126.1 | sudo tee "${dnsmasqconf}"
        dnschanged=1
    fi
    if [ -n "$dnschanged" ]; then
        sudo systemctl restart NetworkManager
    fi

    # Create an entry in the /etc/host
    grep -q 'libvirt.default' /etc/hosts
    if [ $? -ne 0 ]
    then
        echo '192.168.126.1   libvirt.default' | sudo tee --append /etc/hosts
    fi
}

cluster_create()
{
    cat << EOF > ./network.xml
<network>
  <name>test1</name>
  <uuid>9b9c62ae-2afd-4418-841a-6ca4f266933e</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='tt0' stp='on' delay='0'/>
  <mac address='52:54:00:b7:8a:a5'/>
  <domain name='tt.testing' localOnly='yes'/>
  <dns>
    <srv service='etcd-server-ssl' protocol='tcp' domain='test1.tt.testing' target='test1-etcd-0.tt.testing' port='2380' weight='10'/>
    <host ip='192.168.126.11'>
      <hostname>test1-api</hostname>
      <hostname>test1-etcd-0</hostname>
    </host>
  </dns>
  <ip family='ipv4' address='192.168.126.1' prefix='24'>
    <dhcp>
      <host mac='66:4f:16:3f:5f:0f' name='test1-master-0' ip='192.168.126.11'/>
      <host mac='b6:6a:7a:e9:d8:d6' name='test1-worker-0-98nsr' ip='192.168.126.51'/>
    </dhcp>
  </ip>
</network>
EOF

    sudo virsh net-define ./network.xml
    sudo virsh net-start test1

    size=$(stat -Lc%s test1-base)
    sudo virsh vol-create-as default test1-base $size --format qcow2
    sudo virsh vol-upload --pool default test1-base test1-base

    size=$(stat -Lc%s test1-master-0)
    sudo virsh vol-create-as default test1-master-0 $size --format qcow2
    sudo virsh vol-upload --pool default test1-master-0 test1-master-0

    size=$(stat -Lc%s test1-worker-0-98nsr)
    sudo virsh vol-create-as default test1-worker-0-98nsr $size --format qcow2
    sudo virsh vol-upload --pool default test1-worker-0-98nsr test1-worker-0-98nsr

    cat << EOF > ./master-0.xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>test1-master-0</name>
  <uuid>ff0ec75e-3255-49e2-a074-de8104f34c24</uuid>
  <memory unit='KiB'>8388608</memory>
  <currentMemory unit='KiB'>8388608</currentMemory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.11'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    <disk type='volume' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source pool='default' volume='test1-master-0'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='piix3-uhci'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <interface type='network'>
      <mac address='66:4f:16:3f:5f:0f'/>
      <source network='test1'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='pty'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </memballoon>
    <rng model='virtio'>
      <backend model='random'>/dev/random</backend>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </rng>
  </devices>
</domain>
EOF
    sudo virsh define ./master-0.xml

    cat << EOF > ./test1-worker-0-98nsr.xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>test1-worker-0-98nsr</name>
  <uuid>2b2654c8-cb52-4847-b131-e06861e81c80</uuid>
  <memory unit='KiB'>2097152</memory>
  <currentMemory unit='KiB'>2097152</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.11'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/test1-worker-0-98nsr'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='piix3-uhci'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <interface type='network'>
      <mac address='b6:6a:7a:e9:d8:d6'/>
      <source network='test1'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <console type='pty'>
      <target type='virtio' port='0'/>
    </console>
    <channel type='pty'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </memballoon>
    <rng model='virtio'>
      <backend model='random'>/dev/random</backend>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </rng>
  </devices>
</domain>
EOF
    sudo virsh define ./test1-worker-0-98nsr.xml
    echo "Cluster created successfully use '$0 start' to start it"
}


cluster_start()
{
    sudo virsh start test1-master-0
    sudo virsh start test1-worker-0-98nsr
    echo "You need to wait around 4-5 mins till cluster is in healthy state"
    echo "Use provided kubeconfig to check pods status before using this cluster"
}


cluster_stop()
{
    sudo virsh shutdown test1-master-0
    sudo virsh shutdown test1-worker-0-98nsr
    echo "Cluster stopped"
}


cluster_delete()
{
    sudo virsh destroy test1-master-0
    sudo virsh destroy test1-worker-0-98nsr

    sudo virsh undefine test1-master-0
    sudo virsh undefine test1-worker-0-98nsr
    
    sudo virsh vol-delete --pool default test1-master-0
    sudo virsh vol-delete --pool default test1-worker-0-98nsr
    sudo virsh vol-delete --pool default test1-base

    sudo virsh net-destroy test1
    sudo virsh net-undefine test1
}


usage()
{
    usage="$(basename "$0") [[create | start | stop | delete] | [-h]]

where:
    create - Create the cluster resources
    start  - Start the cluster
    stop   - Stop the cluster
    delete - Delete the cluster
    -h     - Usage message
    "

    echo "$usage"

}

main()
{
    if [ "$#" -ne 1 ]; then
        usage
        exit 0
    fi

    while [ "$1" != "" ]; do
        case $1 in
            create )           prerequisites
                               cluster_create
                               ;;
            start )            cluster_start
                               ;;
            stop )             cluster_stop
                               ;;
            delete )           cluster_delete
                               ;;
            -h | --help )      usage
                               exit
                               ;;
            * )                usage
                               exit 1
        esac
        shift
    done
}

main "$@"; exit
