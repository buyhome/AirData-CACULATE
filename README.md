AirData-CACULATE
================

International freight data operation



#数据校验
判断SEGMENTS的航段数量
判断farePERIODS的数量

同时满足后继续

#计算farekey

ORG+DST+BASE_AIRLINE+CITY_PATH+SELL_START_DATE+SELL_END_DATE+TRAVELER_TYPE_ID

#get对应farekey的id
if nil then 
red:incr("next.fare.id")
red:setnx("fare:" .. farekey .. ":id", farecounter)
判断setnx的执行结果Get the fid = fare:[farekey]:id

#解析Json赋值
1、插入basefare information.
2、插入baseSEGMENTS information.（hashes）

#



#题外话：如何为字符串获取唯一标识

在标签的例子里，我们用到了标签ID，却没有提到ID从何而来。基本上你得为每个加入系统的标签分配一个唯一标识。你也希望在多个客户端同时试着添加同样的标签时不要出现竞争的情况。此外，如果标签已存在，你希望返回他的ID，否则创建一个新的唯一标识并将其与此标签关联。

Redis 1.4将增加Hash类型。有了它，字符串和唯一ID关联的事儿将不值一提，但如今我们如何用现有Redis命令可靠的解决它呢？

我们首先的尝试（以失败告终）可能如下。假设想为标签“redis”获取一个唯一ID：

为了让算法是二进制安全的（意即不考虑字符串的编码或空格等等，只将注意力放在标签上）我们对标签做SHA1签名。SHA1(redis)=b840fc02d524045429941cc15f59e41cb7be6c52。
检查这个标签是否已与一个唯一ID关联，
用命令GET tag:b840fc02d524045429941cc15f59e41cb7be6c52:id
如果上面的GET操作返回一个ID，则将其返回给用户。标签已经存在了。
否则… 用INCR next.tag.id命令生成一个新的唯一ID（假定它返回123456）。
最后关联标签和新的ID，
SET tag:b840fc02d524045429941cc15f59e41cb7be6c52:id 123456
并将新ID返回给调用者。
多美妙，或许更好…等等！当两个客户端同时使用这组指令尝试为标签“redis”获取唯一ID时会发生什么呢？如果时间凑巧，他们俩都会从GET操作获得nil，都将对next.tag.id key做自增操作，这个key会被自增两次。其中一个客户端会将错误的ID返回给调用者。幸运的是修复这个算法并不难，这是明智的版本：

为了让算法是二进制安全的（意即不考虑字符串的编码或空格等等，只将注意力放在标签上）我们对标签做SHA1签名。SHA1(redis)=b840fc02d524045429941cc15f59e41cb7be6c52。
检查这个标签是否已与一个唯一ID关联，
用命令GET tag:b840fc02d524045429941cc15f59e41cb7be6c52:id
如果上面的GET操作返回一个ID，则将其返回给用户。标签已经存在了。
否则… 用INCR next.tag.id命令生成一个新的唯一ID（假定它返回123456）。
下面关联标签和新的ID，(注意用到一个新的命令)
SETNX tag:b840fc02d524045429941cc15f59e41cb7be6c52:id 123456。如果另一个客户端比当前客户端更快，SETNX将不会设置key。而且，当key被成功设置时SETNX返回1，否则返回0。那么…让我们再做最后一步运算。
如果SETNX返回1（key设置成功）则将123456返回给调用者，这就是我们的标签ID，否则执行GET tag:b840fc02d524045429941cc15f59e41cb7be6c52:id 并将其结果返回给调用者。



#TO DO
