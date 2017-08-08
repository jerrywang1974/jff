# 开源 ETL 工具调研

数据的 ETL(Extract, Transform, Load) 是一个繁琐的过程，可以自行写脚本做(比如基于 Spark），也可以用一些商业工具做，幸运的是有些商业公司为了提升影响力，提供了其商业工具的开源版本，有可视化的 IDE 以 workflow 的形式构造 ETL 程序。

总的来说，只有 Talend Open Studio Data Integration 和  Pentaho Data Integration(aka. Kettle) 值得考虑，个人倾向于 PDI，虽然其文档略少，ETL系列产品线单薄不太注意 Data Schema 管理，但其并发执行、远程执行、集群化执行很吸引人，而且 UI 设计很友好，使用 JavaScript 语言写自定义逻辑很喜人，Pentaho 家还有配套免费 BI 产品（Talend 没有做 BI 产品）。

一篇很详尽的 TOS vs PDI 文档：http://blog.csdn.net/magichydra/article/details/6827220

## Talend Open Studio Data Integration

Talend 公司的 Talend Open Studio 基于 Eclipse，比较坑爹的是把每一个 perspective 当作单独产品卖，所幸都有开源免费版本。// TOS 有个 Data Fabric 版本把所有 perspective 打包了，但不提供下载。

    * Talend Open Studio Data Integration: 这是最核心最重要的版本，专注 ETL 功能，有 900 左右的 data connectors，有可视化的 IDE 编辑 workflow，可以把 workflow 编译成单线程的 Java或者Perl程序独立运行（并行版本据说只有收费版本提供），使用 Java 和 Groovy 实现自定义逻辑。
    * Talend Open Studio Big Data:  TOS DI 的增强版，可以向 Hadoop + Oozie 提交 ETL job。
    * Talend Open Studio Data Preparation: TOS DI 的阉割版，只能操作 CSV 和 Excel 文件。
    * Talend Open Studio Data Quality:  提供一些预定义逻辑统计数据指标（总记录数，NULL 记录数，空记录数等），以及用增则表达式校验数据。个人觉得很鸡肋的独立产品。
    * Talend Open Studio Enterprise Service Bus:  基于 OSGi 技术的 SOAP web service 运行容器，可以在其上部署 ETL 服务。个人觉得太重。
    * Talend Open Studio Master Data Management:  类似 Hive 里的  HCatalog 角色，用来管理 data schema。

## Pentaho Data Integration (aka. Kettle)

PDI 只有这个版本，专注于 ETL，data connector 比 TOS 少，但也相当多。UI 基于 SWT 库自行实现，产品设计比较友好，容易上手。workflow 以 XML 形式存储，依靠 runtime engine 执行，可以并行化，可以分发到远程 carte server 运行，可以集群化。使用 JavaScript 编写自定义逻辑。

## CloverETL

基于 Eclipse，workflow 也是 XML 格式存储，使用 CloverETL runtime engine 执行（这部分开源：https://sourceforge.net/projects/cloveretl/files/cloveretl.engine/rel-4.2.1/)，跟 PDI 类似可以远程集群化运行，但 designer 部分没有免费版，名气也没有 TOS 和 PDI 大，作罢。

## JasperSoft ETL

JasperSoft 跟  Talend 是合作伙伴，JasperSoft ETL 就是 TOS 加了一些插件。JasperSoft 的强项在于其报表产品。

## KETL

http://ketl.org/，最后版本是 2008 年发布的，感觉已经死掉了。

## Apatar

http://www.apatarforge.org/ ，最后版本是 2011 年发布的，感觉已经死掉了。

## Sqoop

做 RDBMS 和 HDFS/HBase 之间数据搬迁。

## Jedox

http://www.jedox.com/en/product/architecture，产品线很全，但没有免费版。。。

## HPCC Systems

https://hpccsystems.com/why-hpcc-systems/how-it-works，看起来很厉害，快玩脱了的感觉，自己做分布式存储，采用自己发明的语言 ECL，可以编译成 C++（一看 C++ 就被吓尿了。。。)

