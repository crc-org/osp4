# Run OpenShift 4.0 locally

Note: Experimental for Mac and Linux

Mac
===

- Prerequisite: Virtualbox (>= 5.2.x)

Linux
=====

- Currently script prerequisite part only support RHEL/Fedora/CentOS.
- If you using a different distribution then you need to edit the script around how to install the libvirt packages and make the config changes.


How to expose the webconsole
----------------------------

- You need to wait till the cluster is in healthy state, check if all pods are running `oc get pods --all-namespaces` after exporting the kubeconfig file.
- https://github.com/openshift/installer/issues/411#issuecomment-445165262 

Allow kubectl to bind to privileged ports:

```
$ sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/kubectl
```

Note: If you omit the above, you have to start `kubectl` using `sudo`. Next, port-forward the `router-default` service:

```
$ kubectl -n openshift-ingress port-forward svc/router-default 443
```

Get the routes and add bind them to 127.0.0.1 in /etc/hosts:

```
$ kubectl get routes --all-namespaces
NAMESPACE              NAME             HOST/PORT                                                   PATH   SERVICES         PORT    TERMINATION          WILDCARD
openshift-console      console          console-openshift-console.apps.test1.tt.testing                    console          https   reencrypt/Redirect   None
openshift-monitoring   grafana          grafana-openshift-monitoring.apps.test1.tt.testing                 grafana          https   reencrypt            None
openshift-monitoring   prometheus-k8s   prometheus-k8s-openshift-monitoring.apps.test1.tt.testing          prometheus-k8s   web     reencrypt            None

$ cat /etc/hosts
127.0.0.1 console-openshift-console.apps.test1.tt.testing
127.0.0.1 grafana-openshift-monitoring.apps.test1.tt.testing
127.0.0.1 prometheus-k8s-openshift-monitoring.apps.test1.tt.testing
```

## Community

Contributions, questions, and comments are all welcomed and encouraged!

- You can talk to the community at #codeready channel on [Freenode IRC](https://freenode.net/)

