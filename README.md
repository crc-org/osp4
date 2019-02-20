# Run OpenShift 4.0 locally

Note: Experimental for Mac and Linux

## macOS

### Prerequisites 
* Virtualbox (>= 5.2.x)
* [oc 4.0.0](https://mirror.openshift.com/pub/openshift-v3/clients/4.0.0-0.154.0/macosx/)

### Steps
* set up environment:
```
$ export KUBECONFIG=/path/to/minishit_virtualbox_0.9.1/
$ chmod +x ./minishift_virtualbox.sh
```
* create and start cluster:
```
$ ./minishift_virtualbox.sh create
$ ./minishift_virtualbox.sh start
```
The script is using a sudo command you'll be prompted for your root password.

> NOTE: the script run some verification that port 53 is not already in used, double check is the port is not in used with `sudo lsof -i -n -P | grep TCP`

> NOTE: to verify coredns is running, look at log `sudo cat /tmp/coredns.log`

### How to expose the webconsole
* You need to wait till the cluster is in healthy state, check if all pods are running:
```
$ oc get pods --all-namespaces
```
wait untill `CrashLoopBackOff` pods are up restarted.

## Linux
### Prerequisites 
- Currently script prerequisite part only support RHEL/Fedora/CentOS.
- If you using a different distribution then you need to edit the script around how to install the libvirt packages and make the config changes.

### Steps

### How to expose the webconsole
- You need to wait till the cluster is in healthy state, check if all pods are running `oc get pods --all-namespaces` after exporting the kubeconfig file.
- https://github.com/openshift/installer/issues/411#issuecomment-445165262 

Get the routes and add bind them to 127.0.0.1 in /etc/hosts:

```
$ oc get --all-namespaces routes
NAMESPACE           NAME      HOST/PORT                                         PATH      SERVICES   PORT      TERMINATION          WILDCARD
openshift-console   console   console-openshift-console.apps.test1.tt.testing             console    https     reencrypt/Redirect   None
```
Use `console-openshift-console.apps.test1.tt.testing` from the `get routes` above in the `hosts` file below.

```
$ echo "127.0.0.1 console-openshift-console.apps.test1.tt.testing" | sudo tee -a /etc/hosts
```

Allow kubectl to bind to privileged ports:

```
$ sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/kubectl
```

Note: If you omit the above, you have to start `kubectl` using `sudo`. Next, port-forward the `router-default` service:

```
$ kubectl -n openshift-ingress port-forward svc/router-default 443
```
Leave this running in the terminal.

## Running it
In the browser use `https://console-openshift-console.apps.test1.tt.testing`

To login use:
- admin: kubeadmin
- password: [look in kubeadmin-password]

## Community

Contributions, questions, and comments are all welcomed and encouraged!

- You can talk to the community at #codeready channel on [Freenode IRC](https://freenode.net/)

