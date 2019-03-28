### *This repository is only a proof of concepts of CodeReady Containers.* 
### *The actual implementation will be at https://github.com/code-ready/crc*

# Run OpenShift 4.0 locally

Note: Experimental for Mac and Linux, Tarball is shared internally (announced on aos-devel ML)

## Virtualbox on macOS

### Prerequisites 
* Virtualbox (>= 5.2.x)
* [oc 4.0.0](https://mirror.openshift.com/pub/openshift-v3/clients/4.0.22/macosx/)

### Steps

Run these commands from the tarball extracted directory:

* set up environment:
```
$ export KUBECONFIG=[path-to-config]/kubeconfig
$ chmod +x ./crc_virtualbox.sh
```
* create and start cluster:
```
$ ./crc_virtualbox.sh create
$ ./crc_virtualbox.sh start
```
The script is using a sudo command you'll be prompted for your root password.

> NOTE: the script run some verification that port 53 is not already in used, double check is the port is not in used with `sudo lsof -i -n -P | grep TCP`

> NOTE: to verify coredns is running, look at log `sudo cat /tmp/coredns.log`



## hyperkit on macOS
### Prerequisites
* hyperkit (`brew install hyperkit`)
```
$ sudo chown root:wheel $(brew --prefix)/opt/hyperkit/bin/hyperkit
$ sudo chmod u+s $(brew --prefix)/opt/hyperkit/bin/hyperkit
```
* [oc 4.0.0](https://mirror.openshift.com/pub/openshift-v3/clients/4.0.22/macosx/)

### Steps
* set up environment:
```
export KUBECONFIG=<TARBALL_EXTRACT_PATH>/kubeconfig
```

* create and start cluster
```
$ ./crc_hyperkit.sh create
$ ./crc_hyperkit.sh start
```

## libvirt on Linux
### Prerequisites 
- Currently script prerequisite part only support RHEL/Fedora/CentOS.
- If you using a different distribution then you need to edit the script around how to install the libvirt packages and make the config changes.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [oc 4.0.0](https://mirror.openshift.com/pub/openshift-v3/clients/4.0.22/linux/)


### Steps  
Run these commands from the installed/extracted directory:
- `export KUBECONFIG=[path-to-config]/kubeconfig`
- `./crc_libvirt.sh create`
- `./crc_libvirt.sh start`

### How to expose use webconsole
Get the route url from the `openshift-console` namespace
```
$ oc get routes -n openshift-console
NAME        HOST/PORT                                     PATH   SERVICES    PORT    TERMINATION          WILDCARD
console     console-openshift-console.apps.tt.testing            console     https   reencrypt/Redirect   None
downloads   downloads-openshift-console.apps.tt.testing          downloads   http    edge                 None
```

### Running it
In the browser use `https://console-openshift-console.apps.tt.testing`

To login use:
- admin: kubeadmin
- password: [look in kubeadmin-password]

## Community

Contributions, questions, and comments are all welcomed and encouraged!

- You can talk to the community at #codeready channel on [Freenode IRC](https://freenode.net/)

