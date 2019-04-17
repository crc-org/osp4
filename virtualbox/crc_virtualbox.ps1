# Append the path to be able to run vboxmanage.exe commands without absolute path
$env:Path += ";C:\Program Files\Oracle\Virtualbox"
$hostonlyif = (VBoxManage.exe list hostonlyifs)[0].Split(":")[1].Trim()
$hostonlyifIP = (VBoxManage.exe list hostonlyifs)[3].Split(":")[1].Trim()

$user_home = $HOME

function prerequisite()
{
	# Backup original Corefile and test1-api file.
    cp Corefile Corefile_bak
    cp test1-api test1-api_bak
    
    # Copy the disk image in the Virtualbox Folder
    mkdir -p  "$HOME\VirtualBox VMs\crc"
    rm "$user_home\VirtualBox VMs\crc\crc.vmdk"
    echo "Copying the vmdk files to ~/VirtualBox\ VMs/ location ..."
    cp crc.vmdk "$user_home\VirtualBox VMs\crc"
}

function cluster_create()
{    
    # Create the hostonly address if not exit
    if ( (VBoxManage.exe list hostonlyifs).Length -eq 0 )
	{
       VBoxManage hostonlyif create
    }
    # Master configuration
    VBoxManage createvm --name crc --ostype Fedora_64 --register 
    VBoxManage modifyvm crc --cpus 4 --memory 11240 --vram 16
    VBoxManage modifyvm crc --nic1 hostonly
    VBoxManage modifyvm crc --nictype1 virtio
    VBoxManage modifyvm crc --hostonlyadapter1 "$hostonlyif"
    VBoxManage modifyvm crc --nic2 nat
    VBoxManage modifyvm crc --nictype2 virtio
    VBoxManage modifyvm crc --macaddress1 3aceb1219fb2
    VBoxManage storagectl crc --name "SATA Controller" --add sata --bootable on --portcount 1 
    VBoxManage storageattach crc --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$user_home\VirtualBox VMs\crc\crc.vmdk"
    update_corefile
}

function cluster_start()
{
	check_cluster
    set_dns_config
    VBoxManage startvm crc --type headless
    sleep 10
    
	if (!(Get-Process coredns -ErrorAction SilentlyContinue))
    {
        modify_zone_file
        start_coredns
    }
}

function cluster_stop()
{
	check_cluster
    VBoxManage controlvm crc poweroff
}

function check_cluster()
{
    if ( !((VBoxManage.exe list vms).Contains("crc")) )
	{
        echo "Cluster is not present"
        usage
        exit 1
    }
}

function cluster_delete()
{
    check_cluster
    cluster_stop
    VBoxManage unregistervm crc --delete
    stop_coredns
    if ( Test-Path -Path Corefile_bak )
	{
		rm Corefile
		mv Corefile_bak Corefile
    }
    if ( Test-Path -Path test1-api_bak )
	{
		rm test1-api
		mv test1-api_bak test1-api
    }
}

function modify_zone_file()
{
	foreach ($entry in $(arp -a))
	{
		if ($entry.Contains("3a-ce-b1-21-9f-b2"))
		{
			$crcIp=$entry.Split(" ")[2].Trim()
            # Run Coredns after editing tt.testing file.
	        echo "Master ip address: $crcIp"
            Add-Content test1-api "*.apps.tt.testing.`t`tIN`t`tA`t`t$crcIp"
            Add-Content test1-api "api.test1.tt.testing.`t`tIN`t`tA`t`t$crcIp"
            Add-Content test1-api "test1-989ds-master-0.tt.testing.`t`tIN`t`tA`t`t$crcIp"
            Add-Content test1-api "etcd-0.test1.tt.testing.`t`tIN`t`tA`t`t10.0.3.15"
			break;
		}
	}
	
}

function set_dns_config()
{
    $vbInterface = (Get-NetAdapter -Name *VirtualBox*).Name
	$hostInterfaces = (Get-NetAdapter -Physical).Name
	echo "VBox Hostonly interface: $vbInterface"
	echo "Host interfaces: $hostInterfaces"
	
	#set dns server on the host interface (requires elevated shell, run as administrator
    foreach ($adapter in $hostInterfaces)
    {
	    Set-DnsClientServerAddress -InterfaceAlias "$adapter" -ServerAddresses "$hostonlyifIP"
	}
	#set dns server on the VB interface
	Set-DnsClientServerAddress -InterfaceAlias "$vbInterface" -ServerAddresses "$hosonlyifIP"
}

function update_corefile()
{
    $dnsAddresses = (Get-DnsClientServerAddress).ServerAddresses
    foreach($address in $dnsAddresses)
    {
        $ns = nslookup.exe google.com $address
        foreach($line in $ns)
        {
            if($line.Contains("Addresses"))
            {
                (Get-Content .\Corefile).Replace("mynameserver", $address) | Set-Content .\Corefile
                break;
            }
        }
    }
}

function start_coredns()
{
	# start coredns process
	echo "Starting Coredns as backgroud process"
    echo "Coredns logs are in $env:TEMP\.coredns.log & $env:TEMP\.corednsErr.log file"
	Start-Process -FilePath ".\coredns.exe" -RedirectStandardOutput "$env:TEMP\.coredns.log" -RedirectStandardError "$env:TEMP\.corednsErr.log" -NoNewWindow
}

function stop_coredns()
{
	Stop-Process -Name coredns
}

function usage()
{
	$usage="crc_virtualbox.ps1 [[create | start | stop | delete] | [-h]]
where:
    create - Create the cluster resources
    start  - Start the cluster
    stop   - Stop the cluster
    delete - Delete the cluster
    -h     - Usage message
    "

    echo "$usage"
}

function main($arg)
{
	if ($arg.Length -ne 1 )
	{
		usage
		exit 1
	}
	switch($arg) {
	create {prerequisite; cluster_create; break;}
	start  {cluster_start; break;}
	stop   {cluster_stop; break;}
	delete {cluster_delete; break;}
	-h 	   {usage; break;}
	default {usage; break;}
	}
}

main($args)