<h1 align="center">Welcome to Docker Register Cloud</h1>
<p>
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/workflow/status/xausky/DockerRegisterCloud/Build Command Tools">
  <img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/xausky/DockerRegisterCloud">
  <img alt="GitHub All Releases" src="https://img.shields.io/github/downloads/xausky/DockerRegisterCloud/total">
  <img alt="GitHub issues" src="https://img.shields.io/github/issues/xausky/DockerRegisterCloud">
  <img alt="GitHub closed issues" src="https://img.shields.io/github/issues-closed/xausky/DockerRegisterCloud">
</p>

> 基于 Docker 仓库协议的网盘客户端，可以将目前众多的免费容器仓库服务用于网盘存储，下载和分享。

## :rocket: 安装

下载 [Release](https://github.com/xausky/DockerRegisterCloud/releases) 内预编译好的客户端工具。

## :dvd: 演示

> 演示中的服务 drc.xausky.cn 只是临时使用，请使用下述的仓库服务代替。

[![asciicast](https://asciinema.org/a/96yOa8vCRp4U5NjsNHJdEAq85.svg)](https://asciinema.org/a/96yOa8vCRp4U5NjsNHJdEAq85)

## :zap: 直接下载

在支持的仓库上可以通过浏览器实现无客户端下载功能，对直接下载服务的服务器端压力很小。  
目前有部署公共服务器： [http://drcd.xausky.cn/](http://drcd.xausky.cn/)  
也可以使用[此 Docker 镜像](https://hub.docker.com/repository/docker/xausky/drcd)自行部署，端口为 3000

> 公共服务器请认准 http://drcd.xausky.cn/ 其他的 https 形式的或者是跳转后的域名都不要长期存储使用。  
> 对于大使用量或者对稳定性有高要求的请自建服务器。

## :dart: 功能

* [x] 命令行工具基本功能，登录，文件列表，上传文件，下载文件
* [x] 直接下载，在支持的仓库服务中可以直接在浏览器中实现下载而无需客户端
* [x] 命令行功能优化，重命名文件以及删除文件
* [x] GUI 客户端，客户端使用 Flutter，iOS 客户端作者无能进行上架，可自行编译部署。
* [x] 直接下载支持到仓库可以用 Web 版客户端复制永久直链，可用于图床等。

## :thumbsup: 测试可用的仓库服务

> 如果你测试的仓库服务器有问题欢迎提交 [问题](https://github.com/xausky/DockerRegisterCloud/issues) 如果没有问题欢迎提交 PR 加到本列表

服务提供商|无需成本|直接下载支持
-|-|-
[Docker Register](https://docs.docker.com/registry/)|:heavy_multiplication_x:|:heavy_multiplication_x:
[Docker Hub](https://hub.docker.com/)|:heavy_check_mark:|:heavy_check_mark:
[Harbor](https://goharbor.io/)|:heavy_multiplication_x:|:heavy_check_mark:
[百度智能云](https://console.bce.baidu.com/ccr/)|:heavy_check_mark:|:heavy_multiplication_x:
[阿里云](https://cr.console.aliyun.com/)|:heavy_check_mark:|:heavy_check_mark:
[华为云](https://console.huaweicloud.com/swr/)|:heavy_check_mark:|:heavy_check_mark:
[腾讯云](https://console.cloud.tencent.com/tke2/registry/user)|:heavy_check_mark:|:heavy_check_mark:

## :hearts: 关注我

* Github: [@xausky](https://github.com/xausky)
* BiliBili: [@xausky](https://space.bilibili.com/8419077)

## :handshake: 贡献

QQ群: [1073732514](https://jq.qq.com/?_wv=1027&k=5Whgj7Y)  
欢迎各种问题，需求，BUG报告和代码PR!<br />提交到这里就可以 [问题页面](https://github.com/xausky/DockerRegisterCloud/issues).  

感谢以下网友对仓库的贡献：  
A . s ℡ & 嘀哩嘀哩 -- 重制项目图标  

同时感谢其他网友在其他方面的贡献。

# :joy: 免责声明

本项目编写仅基于 [Docker Registry HTTP API V2](https://docs.docker.com/registry/spec/api/) 未曾尝试破解或者逆向任何公司服务，用户存储的内容以及隐私性和安全性由用户自己负责以及仓库服务提供商保证，本项目未曾也没有能力负责和保证。

### :star: 如果这个项目帮到你的话欢迎点个星
