# Trying KEDA | Kubernetes Event-driven Autoscaling

Tiny lab for spyke purpose about  [`Keda`](https://keda.sh/) 

---
***Prerequisites:***
1. [`docker`](https://www.docker.com/): docker daemon for containerization purpose
2. [`kubectl`](https://kubernetes.io/docs/tasks/tools/): docker cli
3. [`minikube`](https://minikube.sigs.k8s.io/docs/): in order to apply against local [`kubernetes`](https://kubernetes.io/) environment
4. [`yq`](https://github.com/mikefarah/yq): [`yaml`](https://en.wikipedia.org/wiki/YAML) parser
5. [`jq`](https://stedolan.github.io/jq/download/)
---

The lab is composed by:
- [`prometheus`](https://prometheus.io/)
- Simple node application using  [`express`](https://www.npmjs.com/package/express) as rest srv along with [`express-prometheus-middleware`](https://www.npmjs.com/package/express-prometheus-middleware) for metrics
- [`keda`](https://keda.sh/) itself

**Main makefile targets:** \

Installing the whole stack
```bash
make install-all
```

Installing prometheus
```bash
make prometheus-install-all
```
Building, pushing and installing node app
```bash
make app-install-all
```

Installing `keda` as well as `ScaledObject` custom resource for node application deployment
```bash
make keda-install-all
```

Uninstalling the whole stack along with minikube cluster
```bash
make uninstall-all
```
