# helm-oci-ecr

Recipe to push both

* docker image
* helm chart

into a **single** ECR repo, like this:

```
image:       aws_account_id.dkr.ecr.region.amazonaws.com/miniapi:1.0.6
chart: oci://aws_account_id.dkr.ecr.region.amazonaws.com/miniapi --version 1.1.0
```

We could also use distinct repo names:

| image repo | chart repo | comment |
| - | - | - |
| miniapi/image | miniapi | This works, but image repo name is ugly. |
| miniapi | miniapi-chart | ECR requires the chart name should be `miniapi-chart`, even uglier. |
| miniapi | miniapi | Distinct tag spaces are required. |

The trick is to use distinct tags.

Notice how karpenter stores image under `0.27.5` while chart lies under `v0.27.5`.

```
helm show chart oci://public.ecr.aws/karpenter/karpenter --version v0.27.5 | grep -i version
Pulled: public.ecr.aws/karpenter/karpenter:v0.27.5
Digest: sha256:9491ba645592ab9485ca8ce13f53193826044522981d75975897d229b877d4c2
apiVersion: v2
appVersion: 0.27.5
version: v0.27.5
```

# Requirement: helm

Install helm: https://helm.sh/docs/intro/install/

```
helm version
version.BuildInfo{Version:"v3.12.0", GitCommit:"c9f554d75773799f72ceef38c51210f1842a1dea", GitTreeState:"clean", GoVersion:"go1.20.3"}
```

# Run the demo

```
./push.sh
```

# Documentation

https://docs.aws.amazon.com/AmazonECR/latest/userguide/push-oci-artifact.html
