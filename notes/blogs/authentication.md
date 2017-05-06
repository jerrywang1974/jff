 认证系统之非专业调研

认证(authentication)和授权(authorization)是经常一起出现的词汇，它俩用
途截然不同，认证解决的是如何确定用户的身份，授权是在认证之后，知道用户
身份的前提下，决定一个用户拥有什么权限。

认证系统包含两个方面：密码存储方案和认证协议，密码如何存储会限制可供选
择的认证协议。

# 密码存储方案 #

很多人都倾向于使用相同或者类似的密码登录不同服务，因此密码存储方案的核
心需求是原始明文密码不能被容易的恢复出来，以免殃及其它服务。可惜实际上
不同服务由不同方控制，同一密码用不同存储方案保存，安全性取决于最弱的那
个。好的服务采用 BCrypt，架不住糟糕的服务用明文保存同一个密码，所以还
是需要用户做到一站一密，或者服务自己做多因子认证，至于采用安全性好的密
码存储方案，这是对一个认证系统的基本要求。

实际工程实现中，密码如何存储经历很多变迁，可惜的是业界并不总是能吸取教
训的，2002 年发布的 Mac OS X 10.2 使用的密码加密算法跟 1979 年 Unix第
七版的算法是一样的，而且没有采用类似 /etc/shadow 的机制，这个机制是
UNIX 在 1987 年引入的，到了 Mac OS X 10.3 的时候，Apple 更改了算法，引
入了 shadow 机制，但却没有使用 salt。大公司尚且如此马虎，何况互联网界
多如牛毛的中小公司了，时至今日，肯定有一小撮公司使用明文存储密码，一大
撮公司用通用摘要算法或者不用 salt，肯定有好大一批公司把用户详细信息跟
密码存储在一起，web server 运行的账户 www 或者 nobody能读取所有密码。

理想的做法是把用户信息（用户名到手机号、邮箱、性别等的映射）和认证信息
（用户名到密码的映射) 分开存放到不同系统里，尤其是跟业务系统分开，因为
业务系统涉及到繁杂的业务逻辑，出问题的概率最大。

Salt 的作用是避免词典攻击，所谓词典就是预先算好的摘要值到密码的
映射表，大家的密码一般比较短，所以这个表文件可以不大但覆盖巨量密码，有了
salt 后，这个映射就成了 password + salt -> hash，变相的提升了密码长度，
只要不同认证系统的 salt 不一样，就没法查表反推原始密码了。看起来有了
salt 后就相当安全了，但其实没有解决暴力破解问题，如果摘要算法是MD5并且密
码长度只有六个字符时，暴力破解一个密码只需要一分钟,
http://blog.codinghorror.com/speed-hashing/ ，这就是为什么会有人设计专
门针对密码的哈希算法。


## 明文 ##

存储明文密码对认证协议的限制是最宽泛的，但此种方案显然是无法满足上面说
的核心需求。

## 摘要值 ##

早期 UNIX 限制密码长度，采用加密算法如 DES 对原始密码加密保存，现在的
认证系统都使用摘要算法，对密码以及一个随机串(称为 salt)应用一个摘要
算法，比如 MD5, SHA1, BCrypt，然后保存摘要值以及salt。这种方式是最广泛
采用的，但在选择摘要算法时要避免通用摘要算法，因为他们的设计考虑了要快
速运算，不利于提高暴力破解的难度，应该选用特别针对密码设计的摘要算法，
这类算法被称为key derivation function(KDF)，其原理都是通过可配置的迭代
次数调节计算量，比通用摘要算法慢几个数量级。

更宽泛点说，依靠生物信息识别用户，也可以认为是把生物信息做了个摘要保存
起来，比如指纹，提取指纹特征很容易，但依据这些特征反推指纹出来是很难的，
而暴力破解就更难了，单次验证的时间已经在秒甚至分钟级别，只能以偷摸
或者暴力的手段直接获取“生物体”本身或其克隆了，这在电影里很常见:-D

下面的三种 KDF，理论上安全强度 SCrypt > BCrypt > PBKDF2，推荐使用
BCrypt。

### PBKDF2 ###

Password-Based Key Derivation Function 2, 由 RSA 实验室提出。这个算法
各个主流语言都有实现(http://en.wikipedia.org/wiki/PBKDF2#Implementations)，应用也非常广泛，比如
WPA/WPA2, WinZip, LastPass, Mac OS X, iOS, Android, Django, Zend,
GRUB 2。

PBKDF2 的缺陷是容易被特制的芯片破解，比如使用 ASIC 或者 GPU，所需的电路和
RAM 都很小。

### BCrypt ###

BCrypt 基于 Blowfish 加密算法设计，Blowfish 是密码学界泰山北斗级人物
Bruce Schneier 的大作。跟所有的 KDF 一样，Bcrypt 也是通过调整迭代次数
降低运算速度。OpenBSD 率先采用 BCrypt 保存 /etc/shadow 里的密码，
PHP 5.5 的 password_hash 函数已经把 BCrypt 作为默认算法，
互联网界各路专家推荐，各家公司采用，俨然已经成为密码摘要存储的标准方案。
http://en.wikipedia.org/wiki/Bcrypt#External_links

BCrypt 被特制芯片破解的难度稍微大点，所需的电路和 RAM 比 PBKDF2 要多些，
但依然是固定的。

### SCrypt ###

SCrypt 特意增大了运算所需内存，因此提高了特制芯片破解的成本，此算法被
莱特币(Litecoin) 所使用，但似乎在互联网界并不广泛，可能是大家刚转向
BCrypt，没工夫搭理尚显年青(2012 年被提出)的SCrypt，或者是采用 SCrypt的
性价比对互联网企业不合算。

### Argon2 ###

Libsodium 采用。

## 一次一密算法的参数 ##

在 OTP(One-time password) 算法中，需要在服务端和客户端储存一些参数或者
状态，随后认证过程中双方才能使用同样的秘钥函数计算出当前秘钥。

## 客户端密码存储 ##

频繁输入密码会让用户很恼火，有两种办法解决：在客户端存储一个 cookie，
标记其登录过，并设置过期时间；让客户端保存密码并自动输入。Web 浏览器
是典型的保存密码并自动输入的例子，可惜的是伊默认不强制要求设置 master
password 以保护那些保存的密码，在设置对话框里就能看到明文密码。。。。

多说两句 cookie。现如今绝大多数网站在用 https 登录后会传给浏览器一个
cookie，记录其 session id 什么的，然后转用 http 协议。这是个非常滑稽
的事情，知道 Firesheep(http://en.wikipedia.org/wiki/Firesheep) 的教训
的人依然非常少，很少人意识到这是个巨大的安全漏洞。在有线局域网内，处于
同一个 VLAN 的用户是可以抓到这个 VLAN 里的所有数据包的。在采用 WEP 认证
的无线网里所有人共用一个秘钥加密网络流量，每个登录成功的人可以破解
所有网络流量。在 WPA/WPA2 认证的网络里，虽然每个用户的会话秘钥
各不相同，但在 WPA-PSK/WPA2-PSK 模式里攻击者可以比较容易的通过 reauth 攻击
得到别人的会话秘钥，被攻击者一般毫不知情（掉线了会自动重连），只有
WPA-Enterprise/WPA2-Enterprise 模式(在无线路由管理界面上一般标记为
WPA/WPA2)没有这个问题，但在家庭网络、咖啡馆、
麦当劳这些地方全都用的 PSK 模式，只要一台机器搞鬼或者中木马，整个网络都
不安全。一旦窃取到 cookie，那就完全可以扮作被害人操作网站，由于这种攻
击是在同一个局域网内，公网 IP 是一样的，服务端也很难区分出来。窃听流量
获取 cookie 还是一种被动攻击，如果主动攻击 http 流量，插入或者替换 JS
脚本，被攻击者上当了都难以发觉。总之，在用 WEP、WPA-PSK/WPA2-PSK
认证的地方使用重要服务时，最好保持 https 或者使用 VPN。Firefox 有两个
插件可以强制对某些域名使用 https:

   * https://addons.mozilla.org/en-US/firefox/addon/force-tls/
   * https://www.eff.org/https-everywhere

可惜，全面默认 https 的风气还没兴盛起来，有的大网站居然都没处理好https，
比如访问 https://www.taobao.com/ 和 https://www.tmall.com/ 就会发现伊
们的 X509 证书是签发给 s.tbcdn.cn的，Web 浏览器发现域名不匹配就会警告，
可怜这还是从 VeriSign 购买的证书，你们没钱买足够的证书就从
http://cert.startcom.org/ 申请个免费的嘛。。。。

BTW，看 Firesheep 介绍时顺带了解了下 WPA 的安全性，居然发现 WPS 有重大
漏洞，无语了：
http://en.wikipedia.org/wiki/Wi-Fi_Protected_Setup#Brute-force_attack
各位看客赶紧检查自己的无线路由。。。。


也有专门的软件保存密码，有些还能自动输入密码到其它软件。LastPass(https://lastpass.com/) 应该是
最有名的了，但把密码放在它的服务器上总是有点不大放心，伊也曾爆过安全
丑闻。类似功能的开源替代品很多，密码被加密后放在本地，虽然迁移不方便，
但终归是蛋捏自己手里：

   * KeePass: http://keepass.info ，1.x 版只能用于 Windows 系统，
     2.x 版本使用 Mono 编写，支持 Windows/Linux/MacOS X，手机上
	 也有它的各种移植、兼容版本：http://keepass.info/download.html
   * KeeFox: http://keefox.org/ ，Firefox扩展，连接 Firefox 和 KeePass
   * KeePassX: https://www.keepassx.org/, KeePass 1.x 的 Linux 移植版，
     使用 Qt 库编写，支持 Windows/Linux/MacOS X
   * KWallet: http://utils.kde.org/projects/kwalletmanager/, KDE 桌面
     环境的密码管理器
   * Seahorse: http://www.gnome.org/projects/seahorse, Gnome 桌面环境的密码管理器
   * Mac OS X keychain:  Mac OS X 自带的密码管理器
   * VIM：VIM 编辑器的 -x 选项可以用来创建加密文件，一旦加密后下次 VIM
     打开时会自动识别出来是加密的文件并询问密码。使用这个特性时记得设
     置 encryptmethod 选项为 blowfish。我一直用这个，查找、编辑都很顺
     手，VIM 做文本操作就是快捷！


# 认证协议 #

用户注册时选择密码并被服务端保存，随后用户访问这个服务时就要经过认证协
议。密码如何存储是服务内部的问题，除非服务被攻破，存储的密码泄露，否则
还是不大容易捅篓子的，而认证协议解决的是在网络两头双方的信息交换，这就
太容易出问题了，所以出现繁多的认证协议也就不足为怪。

## 双方认证和三方认证 ##

从认证涉及的各方来看，认证协议分为双方认证协议，客户端和服务端，这是最
常见的，还有三方认证协议，除了客户端和服务端还引入了一个双方都信任的第
三方，比如 Kerberos, CAS(Central Authentication Service), OpenID。
下面只看双方认证协议，这也是三方认证的基础。

## 单因子认证和多因子认证 ##

双方认证按照认证时提供的凭证个数分为单因子认证(SFA, single-factor
authentication)和多因子认证(MFA, multi-factor authentication)，而
多因子认证里以双因子认证最为常见。

所谓多因子，指认证时需要提供如下凭证：

   1. knowledge factor (something only the user knows)，比如密码，
       某个秘密问题的答案，某个特定模式比如Android上锁屏解锁时的特定滑动序列。
   2. possession factor (something only the user has)，比如银行卡，
       RSA SecurID, 各种银行提供的电子令牌，YubiKey，以及人手一部的手机，
       各种认证系统往手机发送认证码就是假定了持有手机的人是目标用户。
   3. inherence factor (something only the user is)，比如指纹，视网膜，
       语音。

也有人提第四个因子，somebody you know。

单因子认证一般只需要提供第一个因子（也有只需要第二个因子的，譬如通过目
测护照识别身份），双因子一般是提供第一个和第二个因子。多因子认证并不是
绝对安全，只是增加被破解的难度。注意有一些认证系统看起来像是双因子认证，
其实是单因子认证，比如登录时除了密码，还要回答一个秘密问题，或者可以通
过紧急邮箱找回密码，这种做法通过让用户提供多个knowledge factors 提高破
解难度。

在网上登录绝大部分情况下都是单因子认证，一个密码了事。使用网上银行或
者 ATM 机是典型的双因子认证，除了密码之外还要提供电子令牌上的数字或者
银行卡，双因子认证方案里几乎不可能被完全不相关的黑客拿到两个因子。

双因子认证很容易在实现时引入漏洞：丢失密码后使用手机发短信即可重置密码
（要求额外提供身份证号是不保险的，身份证号并不是保密信息），或者手机上
的应用长期缓存第一个因子，只需要提供第二个因子。在安全和方便之间总是难
以皆大欢喜。


## 互相认证 (mutual authentication) ##

关于认证还有另外一个问题，大家都明白客户端需要向服务端证明自己身份，很多
人可能忽视了服务端向客户端证明自己身份的必要性，这点一旦点出，大家自然
明白，好比影视里俩同志接头要互报口令。这也是为什么稍微正经的认证系统
登录时需要用 SSL/TLS 的原因之一（另一个重要原因是加密通讯避免用户密码
在传输时被窃听），利用 SSL/TLS 客户端检查服务端的 X509 证书。

## 协议 ##

具体的认证协议五花八门，可以一刀切分为两类：需要向对方发送密码的，不管
是固定密码还是一次一密；不需要向对方发送密码的。

### 需要向对方发送密码的认证协议 ###

这种协议都需要 SSL/TLS 之类的协议护驾，否则毫无安全可言。

#### HTTP Basic, SMTP PLAIN, SMTP LOGIN ####

把用户名、明文密码或者BASE64编码的密码发送给服务端。这个是最容易实现的，
在 HTML 登录表单里也很好做，服务端可以拿密码跟明文密码比对（不推荐），
或者拿提供的密码与 salt 做摘要再跟期望的摘要值比较。

### 不需要向对方发送密码的认证协议 ###

#### CRAM-MD5 ####

Challenge Response Authentication Mechansim, 所谓的 challenge 就是服务
端发给客户端一个随机字符串，客户端需要用密码或者密码的摘要值对其进行
HMAC-MD5 运算，然后把结果发送给服务端，服务端对随机串做相同运算并比对
结果。

此协议只是客户端向服务端认证，没有服务端向客户端认证，因此一般需要
SSL/TLS 护驾，让客户端验证服务端证书。具体实现时那个 challenge 往往有
比较固定的模式，没有 SSL/TLS 信道加密的话，通讯数据包被窃听后易受词典
攻击。

在服务端，密码要么是存为明文，要么是存为 MD5 摘要值或者中间运算结果，
一是容易被暴力破解，二是存储的值在 CRAM-MD5 认证协议里跟密码等价，
所以拿到这个摘要值其实就是获得了此用户的权限。

#### DIGEST-MD5 ####

相比 CRAM-MD5，在认证过程中允许客户端提供一个随机串添加在服务器给定的
随机串上，因此避免了恶意的服务端做选择明文攻击（CRAM-MD5 中对选定明文，
客户端返回的摘要值是确定的，因此可以被词典攻击）。

DIGEST-MD5 支持互相认证，但协议本身选项比较多，容易实现不当，互操作性
比较差。

虽然攻击难度比 CRAM-MD5 大，但一般也需要用 SSL/TLS 保护信道以免窃听。

跟 CRAM-MD5 一样，密码是 MD5 摘要，而且在认证协议里等价于密码，因此
在服务端存储的密码是相当不安全的。

#### SCRAM (Salted Challenge Response Authentication Mechanism) ####

SCRAM 是一族算法，最常见的是 SCRAM-SHA1，设计用来替换 DIGEST-MD5。
SCRAM 比 DIGEST-MD5 更安全也更容易实现，XMPP 把 SCRAM 列为必须支持的认
证协议。虽然 SCRAM 规定 SHA1 为必须支持的摘要算法，但 SCRAM 并不限制摘要算法，
可以使用 IANA 规定的任何算法：http://www.iana.org/assignments/hash-function-text-names/hash-function-text-names.xhtml

SCRAM 认证是互相认证。存储在服务端的 StoredKey 是 PBKDF2 摘要算法的
结果的再次摘要，在 SCRAM 中不是 password 的等价物，即使泄露也不能
伪装用户，但存储在服务端的 ServerKey 一旦泄露，攻击者可以伪装服务端。
http://tools.ietf.org/html/rfc5802#section-3

SCRAM 需要搭配 channel binding 以避免中间人攻击，可以用 SSHv2 和 TLS。
所谓通道绑定就是应用层的认证协议利用传输层的加密协议，确认在应用层认证
的双方确实是互相通信的双方，避免中间人攻击，注意这里的通道绑定是需要
两层协议的具体实现互相支持的，比如上层协议要获取 SSHv2 的 session ID
或者 TLS 里的握手报文内容(tls-unique binding)、X509 证书
(tls-server-end-point binding) 参与认证过程，举例来说，在 TLS
上做通道绑定的 SCRAM-SHA-1 增强版叫 SCRAM-SHA-1-PLUS, 其实现需要 OpenSSL
或者 GnuTLS 库提供获取握手报文内容、X509 证书的 API。


#### SRP (Secure Remote Password protocol) ####

与 Kerberos 和 SSL X509 不同，SRP 并不依赖第三方的受信秘钥服务或者证书
分发机构，SRP 使用共享密码做互相认证。SRP 有大量优良特性：

   * 容许弱密码，攻击者必需跟服务端或者用户端交互才能暴力破解
   * 服务端存储的 salted password 不是密码的等价物，而是类似于公钥；
   * 认证过程不需要传输层加密
   * 认证过程可以生成一个会话秘钥

参考：

   * http://srp.stanford.edu/
   * http://en.wikipedia.org/wiki/Secure_Remote_Password_protocol

OpenSSL >= 1.0.1 以及 Apache 2.5 mod_ssl, mod_gnutls 支持 TLS-SRP:

   * https://issues.apache.org/bugzilla/show_bug.cgi?id=51075
   * http://sqs.me/security/tls-srp.html (这哥们是 sourcegraph founder...)

但是很不幸 Redhat 为了避免可能的专利纠纷删除了 Fedora、RHEL 中
openssl 软件包里的 srp 代码：

   * http://tiebing.blogspot.tw/2013/09/tls-psk-tls-srp-and-tls-jpake.html
   * http://pkgs.fedoraproject.org/cgit/openssl.git/tree/hobble-openssl?id=291d8a35f7cebdaf8d131f036b6dfa60fd3e543b;id2=HEAD


#### EAP ####

Extensible Authentication Protocol，EAP 是一个认证框架，常用于无线网以
及点对点网络中。具体的认证方法称为 EAP method，目前定义了大约四十种。

EAP-TLS: 使用 client & server X509 certificates互相认证，并用TLS加密信
道

EAP-POTP: 使用 OTP token 做双因子认证

EAP-PSK: 使用 pre-shared key 做互相认证，认证成功后信道被加密

EAP-PWD: 从一系列共享密码中挑选一个做认证，被 Android 4.0, FreeRADIUS, Radiator 支持

EAP-IKEv2

EAP-FAST

EAP-AKA

EAP-GTC: 使用各种令牌比如 RSA SecurID 认证

EAP-TTLS,  PEAP: 为 EAP methods 提供加密保护

#### RADIUS ####

http://freeradius.org/

基于 UDP 协议。在使用 WPA-Enterprise/WPA2-Enterprise 无线网认证方式的
地方就需要 RADIUS 服务。

#### TACACS+ ####

Cisco 开发，基于 TCP 协议，提供 authentication/authorization/accounting.

   * http://my.safaribooksonline.com/book/networking/network-management/1587052113/access-control/ch03lev1sec1
   * http://www.openwall.com/articles/TACACS+-Protocol-Security

#### Diameter ####

http://www.freediameter.net/trac/

代替 RADIUS，提供 authentication, authoriazation, accounting。


### 双因子认证 ###

以前双因子认证还是个高级货，只用在网上银行以及大型企业 IT 系统的登录系
统里，在 Google 推出双因子认证后， Internet 巨头们纷纷支持，加上
智能机普及，双因子认证算是飞入寻常百姓家了。

上面提到 SRP、SCRAM，看起来是很安全了，但是总架不住客户端中了木马导致
密码泄露，或者密码比较二被人猜出来，或者一个密码打天下忽然惊闻常去的某
网站居然是明文存储密码，等等等等，所以牵涉到用户深度隐私或者钱财的服务
必须自觉的支持双因子认证。

一般双因子认证使用这两个因子： knowledge factor，基本都是指密码了，
possession factor，电子令牌上或者手机上的 Google authenticator
应用显示的认证码，或者是服务端通过短信发到手机上的认证码，这个认证码
就是个 one-time password，其生成算法是有业界标准的，并不是个简单的
随机数。

Wikipedia 上对 OTP 的讲解很清楚：

   * http://en.wikipedia.org/wiki/One-time_password
   * http://en.wikipedia.org/wiki/Google_Authenticator

简单来说，TOTP 就是双方共享一个种子，用一个函数对这个种子以及时间
原点到当前逝去的分钟数或者 30s 数目求值，由于种子和时间双方都一致，
所以自然解决了认证码的过期问题，以及跟用户对应的问题。这个算法需要
客户端和服务端的时间偏移不能太大，TOTP 的 RFC 提到如何容忍稍许的
时间不同步，根据用户的输入记录时钟偏移，比如用户连续三次输入上一
分钟的认证码，那么服务端就知道用户的时钟慢了一分钟。

HOTP 是双方定一个种子数字，用同一个摘要函数这个种子求值，对结果再次算摘要
值，如此反复，由于摘要函数的特性，很难从下一个值推算出上一个值，所以
把这些值倒过来就是一个密码表了，每次用下一个密码。

TOTP 比 HOTP 用的更广泛，因为 HOTP 每次使用时都有一个当前状态需要记录，
使用上不大方便，而 TOTP 只需要种子数字以及时间同步，另一个 HOTP 的问题
是一旦用户不小心泄露了后面的密码，那么这个密码之前的密码都泄露了，通过
对后面的密码做摘要即可得到前面的密码。

明白原理后就很容易理解 OTP 是怎么用的了：

   * 起始种子的生成
       - 对硬件形式的电子令牌，生产时会设置好种子到硬件里并备案，管理员
          购买后会把种子数字输入到 OTP server 里。
       - 对手机上的 OTP 软件，服务端可以发短信、语音到用户，或者网站上
          生成种子数字的 QR code，用户拿手机扫描出来，然后这个种子被输入
          到 OTP 软件里;
       - 服务端也可以不把种子发给用户，只是让用户注册手机号，每次用户要
          登录时，用户点击网页上的获取验证码按钮，服务端就会把当前的认证
          码通过短信发送到用户的手机上。 这种方式安全点，不用担心用户方泄
          漏了种子数字；
       - 在生成种子的时候，服务端还可以生成一系列的 backup codes，这些数
          字等价于认证码，用完一个即作废一个。backup codes 是需要用户
          保存好的，比如打印出来，backup codes 的目的是用户在丢失手机后
          可以用 backup code 登录。
   * 认证码的使用：电子令牌或者手机上的 OTP 软件会显示当前的认证码，用
     户在登录服务时需要输入用户名、密码、认证码。注意得到认证码的过程
     是本地算出来的，不需要联系服务器。

Google 的认证系统还有个高级功能，可以为一个账户生成多个副密码，这些密
码不需要双因子认证，这个功能是为了给第三方不支持双因子认证的应用访问
Google 服务。

双因子认证提高了认证系统的安全性，但并不意味着认证过程绝对安全，一旦用户密
码和某次认证码泄露(比如通过键盘钩子记录按键，然后切断用户和服务端连接)，
攻击者可以立马登录然后修改密码重新绑定手机重新生成种子，当然这么搞会被
用户发觉。也可以隐蔽点，如果攻击者和用户在同一个内网里，攻击者和用户先
后登录，并且Web浏览器指纹一样，服务端是没法区分的。

Google authenticator 官方自称 twp-step authentication 而非
two-factor authentication，因为有人诟病它的安全性。传统意义上的
possession factor 是很难复制的，要么拥有要么没有，比如 RSA SecurID
就是抗篡改的(tamper-resistant )，而 Google authenticator 可以同时
在多个设备上运行，只要把种子数字从手机里复制出来，这破坏了
"something only the user has" 的要求。 但总之这种 soft token 还是聊胜
于无，穷人的福利。

### CAPTCHA ###

CAPTCHA 是 Completely Automated Public Turing test to tell Computers
and Humans Apart 的缩写。为了避免脚本自动注册、登录，在注册或者登录
表单里添加一个输入框以及小图片，图片上显示一些扭曲的文字，需要用户肉眼
识别出来并填入那个输入框里。有的 CAPTCHA 也提供语音输出。

原理很简单，实际应用中也很常见，但做好并不容易，需要挖空心思让机器图形
识别困难，但对人肉识别又比较容易，看起来很凌乱的图片，未必难于被机器识别。

顺带八卦一下，某些网站的 CAPTCHA 做成了一个广告图片，要求输入广告里某
个字眼，做法相当高明，用户不得不看广告。


# 无责任推荐 #

依优先级顺序，排在前面的优先级高。

## Kerberos/SPNEGO, OpenID ##

Intranet 使用 Kerberos 和 SPNEGO 做 single sign-on，这个选择已然定论，
支持这些协议的操作系统和应用软件都非常广泛。

Internet 使用 OpenID，不用自己操心认证的事情了。但用 OpenID 也是有些烦
人的因素了，自己网站的用户登录状况被第三方知道多少是有点让人不爽的事情，
蛋捏别人手里。对认证的安全把握也完全没有，我就从来不敢在手机上的非
Google 应用里输入 GMail 账号信息，鬼知道密码是送给李逵还是李鬼了，界面
上也没有什么 OpenID seal 可供识别，在浏览器上还稍微放心点，毕竟浏览器
是个相对安全的中立方（排除个别别有用心的浏览器）。

估计大伙也是这么想的，所以虽然 OpenID 想法很好，但大家都把它当做锦上添
花的特性，不会作为主要的认证方式。

## TLS X509 server certificate + SRP or TLS-SRP ##

SRP 用于认证本身并不需要 SSL/TLS 保护，但实际应用中需要登录往往意味着需要
加密随后的通信，TLS-SRP 是 TLS 协议对 SRP 的直接支持。在 TLS 协议中涉及到四
类密码学算法：

   *  认证：互相识别对方身份，可以用 X509 证书(涉及 RSA or DSA),
       PSK(pre-shared key), SRP，其中 SRP 可以搭配 RSA、DSA 混用增强安全性；
   *  秘钥交换：在不可信通道上交换一个共享的对称加密秘钥，用于随后加密
       连接，可以用 RSA, SRP, DH, ECDH。
   *  加密算法：加密连接，可以用 3DES, AES 等;
   *  摘要算法：在认证和秘钥交换过程会频繁用到摘要算法，比如 MD5, SHA1;

可以看出 SSL/TLS 协议并不一定需要 x509 证书，可惜所有 Web 浏览器只支
持 X509 证书方式的认证，并且对客户端的 x509 证书认证操作比较麻烦，需要
用户自己在浏览器设置里导入客户端自己的证书，所以为了应付 Web 浏览器，
还是需要结合 TLS X509 server cert 做服务端认证然后加密连接，然后再用
HTML 表单以及 JavaScript 做 SRP 认证(这一步不依赖加密连接)，如果是
本地应用，可以直接上 TLS-SRP。

TLS-SRP 要求 OpenSSL >= 1.0.1 或者 GnuTLS。 OpenSSL 1.0.1 在 2012 年 3
月 14 日发布。

SRP 在服务端保存的是 verifier，而非 password 或者 password 的等价物，
verifier 类似公钥认证里的公钥，所以泄露了也没太大问题。


## TLS + SCRAM ##

使用带有 TLS channel binding 的 SCRAM-SHA-1-PLUS。


## TLS X509 server certificate + PLAIN ##

实现简单，理解容易，业界最广泛使用的方案。用 x509 证书验证服务端，然后
在加密连接上传输密码或者其摘要值给服务端以验证客户端。密码存储使用 BCrypt。

使用 TLS 的注意事项：

   * 使用 OpenSSL >= 1.0.0 的 ECDHE 特性获得 perfect forward secrecy 并且保持高性能: http://vincent.bernat.im/en/blog/2011-ssl-perfect-forward-secrecy.html
   * 对 native client 使用 TLS >= 1.1 : http://en.wikipedia.org/wiki/BEAST_(computer_security)#BEAST_attack
   * 对浏览器使用 SSL >= 3.0 (包含了 TLS 1.0，虽然有问题但是老版浏览器不支持 TLS >= 1.1)。
   * 禁用 TLS compression 和 HTTP compression: http://en.wikipedia.org/wiki/BEAST_%28computer_security%29#CRIME_and_BREACH_attacks
   * TLS 秘钥交换算法选择优先次序：ECDH > DH > RSA(不支持 perfect forward secrecy) > ECDSA(不是所有客户端都支持）。
   * 让 server 端决定 cipher 优先级顺序(Apache: SSLHonorCipherOrder On, Apache TrafficServer: proxy.config.ssl.server.honor_cipher_order 1)，而非默认的让 client 决定。
   * 禁止 TLS client 发起的 renegotiation，对于长连接，server 应在一小时之内发起 renegotiation，短连接应禁止 renegotiation。
   * Abbreviated handshake (session ID or session ticket extension)有效时间不超过两小时。
   * 优先使用 AES 加密算法，以利用 AESNI 硬件加速。

如果服务端是一个集群，那么 TLS session ID 需要搭配 memcached 做共享的
session cache，而 session ticket extension 需要集群所有机器使用
同样的ticket key。

这个方案有两个问题，TLS 证书验证由于用户可能盲目信任未知证书而导致中间
人攻击；有可能失误会导致密码被明文传输，譬如客户端逻辑出错没有启用 TLS
连接，譬如登录页面没配置成 https only。

# 实现参考 #

认证协议是个理解起来伤脑筋，要想实现无误也很费神的事情，有人就构建了许多框
架或者 API 来容纳各种认证协议：GSSAPI(Generic Security Services Application
Programming Interface)，SASL(Simple Authentication and Security
Layer), SSPI(Security Support Provider Interface)，其中应用最广的
当属 SASL，众多网络协议以及 Linux 下无数应用都支持 SASL，不过最遗憾的
是 HTTP 协议以及众多 web 浏览器不支持它。

SASL 主流实现有四个：

   * Cyrus SASL: http://cyrusimap.web.cmu.edu/
   * GNU SASL: http://www.gnu.org/software/gsasl/
   * Dovecot SASL: http://wiki2.dovecot.org/Sasl
   * Java SASL: http://docs.oracle.com/javase/7/docs/technotes/guides/security/sasl/sasl-refguide.html

这些 SASL 实现可以从文件、OpenLDAP、关系数据库读取密码信息并进行验证，
也能更改密码，列举用户名，在实现认证系统时最好基于某个 SASL 实现。

## TLS X509 server certificate + SRP or TLS-SRP ##

单纯的 SRP 实现在 wikipedia 页面上列了很多，目前只有 Cyrus-SASL 支持 SRP。
TLS-SRP 需要 OpenSSL >= 1.0.1 或者 GnuTLS 支持。注意 Fedora、RHEL 官方
的 openssl、gnutls 软件包剔除了 SRP 相关代码以避免潜在的专利纠纷。

目前没有 Web 浏览器直接支持 SRP，需要先用 TLS x509 server cert 建立 https 连
接，然后用 HTML 表单以及 JavaScript 做 SRP 认证。虽然这个 x509
server cert 不用于认证，但还是需要正规 CA 签发的证书，以免中间人攻击
替换掉 HTML 表单以及 JavaScript 从而导致明文密码泄露。

非 Web 浏览器场合，可以直接上 TLS-SRP，不需要 X509 证书。

下面是分别用 OpenSSL 和 GnuTLS 演示 TLS-SRP。

### OpenSSL ###

	$ touch srpvfile.txt
	$ openssl srp -srpvfile srpvfile.txt -userinfo "my test user" -add testuser
	$ openssl s_server -nocert -cipher SRP -srpvfile srpvfile.txt -accept 4430
	$ openssl s_client -srpuser testuser -cipher SRP -connect localhost:4430

### GnuTLS ###

http://gnutls.org/manual/gnutls.html#Echo-server-with-SRP-authentication

	$ srptool --create-conf srppasswd.conf
	$ srptool --passwd-conf srppasswd.conf --passwd srppasswd.txt -u testuser
	$ gnutls-serv -p 4430 --http --srppasswdconf srppasswd.conf --srppasswd srppasswd.txt --priority NORMAL:-KX-ALL:+SRP:+SRP-DSS:+SRP-RSA
	$ gnutls-cli -p 4430 localhost --srpusername testuser --srppasswd 123456 --priority NORMAL:-KX-ALL:+SRP:+SRP-DSS:+SRP-RSA
	$ curl --tlsuser testuser --tlspassword 123456 -k https://localhost:4430/

## TLS + SCRAM ##

SCRAM 的支持程度比 SRP 好点，Dovecot SASL 和 Cyrus SASL 支持
SCRAM-SHA-1，GNU SASL 支持 SCRAM-SHA-1 和 SCRAM-SHA-1-PLUS。

跟 TLS-SRP 一样，没有 Web 浏览器直接支持 SCRAM-SHA-1-PLUS, 在 Web 浏览
器上也需要 TLS x509 server cert 先建立 https 连接，然后用 HTML 表单以
及 JavaScript 做 SCRAM-SHA-1 认证。同样，也需要正规 CA 签发的证书以避
免 HTML 和 JS 被中间人替换掉。

非 Web 浏览器场合，可以不需要 X509 证书，在 TLS 上启用 aNULL cipher(https://www.openssl.org/docs/apps/ciphers.html)
加 SCRAM-SHA-1-PLUS(tls-unique channel binding)做认证。

## TLS X509 server certificate + PLAIN ##

需要用正规 CA 签名的 X509 证书，因为这个证书用来验证服务端身份。

各种 SASL 实现都支持 PLAIN 机制，其实自己实现也非常简单了，唯一要注意的是最好把认
证服务跟业务逻辑所在服务分开，避免业务逻辑所在服务出篓子被人爬下整个密码库。

认证系统应该用 https 保护，并设置 HSTS 头部：
http://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security 。

## OTP ##

OTP 的原理并不复杂，自己实现一个也不难，下面是许多现成的实现供参考。

   * S/KEY: 古老的 HOTP 类系统：
      - http://www.ece.northwestern.edu/CSEL/skey/skey_eecs.html,
      - http://www.fatsquirrel.org/veghead/wot/skey.php
   * OPIE: S/KEY 的复制品，Debian/Ubuntu 在 2011 年去除了这个软件包，
      BSD 们还保留着这个古董：
       - http://www.freebsd.org/doc/handbook/one-time-passwords.html
       - http://www.linuxjournal.com/content/configuring-one-time-password-authentication-otpw
   * OTPW: OPIE和S/KEY的替代品，但并不兼容。提供了 PAM module。其原理
     是生成几百个随机数，前头拼一个 prefix password 然后计算RIPEMD-160
     摘要值并按 BASE64 编码显示，用户需要把这个密码表打印出来。这个软
     件设计思路以及给人的使用体验都很古朴:-D
   * Google authenticator: http://code.google.com/p/google-authenticator/ ，
     支持 TOTP 和 HOTP，提供了 PAM module，有 Android, iOS, Blackberry 版本的手机应用。Google 后来不提供它新版
     的源代码了，所以有人做了两个 fork：
      - https://github.com/kaie/otp-authenticator-android
      - https://fedorahosted.org/freeotp/
   * OpenOTP: 商业产品，可以免费供 35 人使用，特性非常丰富的样子。
   * motp: http://motp.sourceforge.net/, 服务端只是个 shell 脚本，客户端支持许多移动设备，客户端的使用体验很像 RSA SecurID。
   * Barada: http://barada.sourceforge.net/, HOTP 实现，提供 PAM module 以及 Android app。
   * LinOTP: http://www.linotp.org/features.html, 特性相当丰富的样子。
   * multiotp: http://www.multiotp.net/ ，用纯 PHP 实现了HOTP/TOTP/mOTP 等算法。
   * python-oath: https://github.com/bdauvergne/python-oath
   * totp-js: https://github.com/bdauvergne/totp-js
   * tiqr: https://tiqr.org/ ，支持 QR code scanning，提供服务端、
     Android app、iOS app
   * oath-toolkit: http://www.nongnu.org/oath-toolkit/ ，实现了 TOTP
     和 HOTP，提供 PAM module。

没有一个提供 backup code 特性，当然，这个不在 OTP 原理里头，只是具体实
现时的一个方便用户的特性。实现时可以参考 Google authenticator 和
oath-toolkit。

使用 oath-toolkit 和 Google authenticator 可以验证两者是一致的，Google
返回的 seed 值是 16 个字符的 base32 编码的字符串，实际上 Google
authenticator 不要求必需是 16 个字符。

	$ oathtool -b --totp 'bkuq 7tya sdbu jlda'  # 字符串的空格被忽略，大小写无关
	200157
	$ oathtool -b --totp 'bkuq 7tya sdbu jlda' 200157   # 验证
	0

将那串 base32 编码字符串输入 Google authenticator 里，可以验证它的结果
跟 oathtool 生成的认证码确实是一致的。Google authenticator 可以用于
Google 之外的服务。

# 总结 #

<table border="1">
<tr>
   <th width="10%">认证协议</th>
   <th width="30%">SRP</th>
   <th width="30%">SCRAM</th>
   <th width="30%">PLAIN</th>
</tr>

<tr>
  <td>Web 浏览器</td>
  <td>https + CA issued X509 certificate + SRP in HTML form and JavaScript</td>
  <td>https + CA issued X509 certificate + SCRAM-SHA-1 in HTML form  and JavaScript</td>
  <td>https + CA issued X509 certificate + password in HTML form</td>
</tr>

<tr>
  <td>本地客户端</td>
  <td>TLS-SRP，不需要 X509 证书</td>
  <td>TLS + SCRAM-SHA-1-PLUS, 不需要 X509 证书，OpenSSL的 cipher list
  里要 *添加*  aNULL cipher，比如使用 ALL cipher (不要修改全局
  openssl.cnf，而是在客户端和服务端的配置文件里配置）</td>
  <td>TLS + CA issued X509 certificate + password</td>
</tr>

<tr>
  <td>服务端密码存储</td>
   <td>SRP verifier，泄露无害</td>
   <td>StoredKey, ServerKey, salt, iteration count，其中ServerKey 泄露
  而且服务端没有使用 CA issued X509 certificate 时，攻击者可以伪装服务
  端，其它数据泄露无害</td>
  <td>Bcrypt，泄露无害</td>
</tr>

<tr>
   <td>双因子认证</td>
   <td>搭配 TOTP</td>
   <td>搭配 TOTP</td>
   <td>搭配 TOTP</td>
</tr>
</table>

<!-- $ pandoc -f markdown -t html --smart --toc --toc-depth 5 -N  -s -o authentication.html authentication.md -->

