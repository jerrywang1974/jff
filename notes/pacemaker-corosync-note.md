# Pacemaker + Corosync

Heartbeat, Corosync 1.x, CMAN 都已经废弃了。

## 安装

安装 pacemaker 和 fence-agents. pacemaker 依赖 pacemaker-cli-utils,
pacemaker-resource-agents, resource-agents, crmsh, cluster-glue,
corosync, openhpid.

```
$ apt install pacemaker fence-agents
```

另一些有用的软件包：

* pcs
* pacemaker-remote
* booth-pacemaker
* sbd   https://github.com/ClusterLabs/sbd

Web UI: http://hawk-ui.github.io/
        http://lcmc.sourceforge.net/

