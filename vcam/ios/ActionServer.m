// 极简 HTTP 控制口：电脑或另一台手机的浏览器点按钮 → 手机切动作
// 监听 0.0.0.0:8088
//   GET /act?n=mouth     切动作
//   GET /list            列出所有动作
//   GET /                返回内置控制页

#import "ActionStore.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

static NSString *const kPage =
@"<!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>"
"<style>body{background:#0b0d10;color:#eee;font:15px -apple-system;padding:12px}"
"button{width:48%;margin:1%;padding:22px 0;font-size:19px;border-radius:14px;border:1px solid #2a2f36;"
"background:#151a20;color:#eee}button:active{background:#1f6feb;color:#fff}"
".row{display:flex;flex-wrap:wrap}.hi{background:#124a2b;border-color:#3ddc84}</style>"
"<h3 id=cur>当前：front</h3><div class=row>"
"<button onclick=go('front')>正脸</button><button onclick=go('up')>抬头</button>"
"<button onclick=go('down')>低头</button><button onclick=go('left')>向左转</button>"
"<button onclick=go('right')>向右转</button><button onclick=go('mouth')>张嘴</button>"
"<button onclick=go('blink')>眨眼</button><button onclick=go('nod')>点头</button>"
"<button onclick=go('shake')>摇头</button><button onclick=go('digits')>念数字</button>"
"</div><script>"
"function go(n){fetch('/act?n='+n).then(r=>r.text()).then(t=>document.getElementById('cur').textContent='当前：'+t)}"
"document.onkeydown=e=>{const m={ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',"
"' ':'front',m:'mouth',b:'blink',n:'nod',s:'shake',d:'digits'};if(m[e.key])go(m[e.key])};"
"</script>";

@implementation ActionStore (Server)

- (void)startServer {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        int on = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
        struct sockaddr_in a = {0};
        a.sin_family = AF_INET;
        a.sin_port = htons(8088);
        a.sin_addr.s_addr = INADDR_ANY;
        if (bind(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
            NSLog(@"[vcam] 8088 绑定失败");
            return;
        }
        listen(fd, 8);
        NSLog(@"[vcam] 控制口 http://0.0.0.0:8088/");

        while (1) {
            int c = accept(fd, NULL, NULL);
            if (c < 0) continue;
            char buf[1024] = {0};
            read(c, buf, sizeof(buf) - 1);
            NSString *req = [NSString stringWithUTF8String:buf] ?: @"";

            NSString *body = @"{}";
            NSString *ctype = @"text/plain; charset=utf-8";
            NSString *name = nil;
            if ([req containsString:@"GET /act?n="]) {
                NSRange r = [req rangeOfString:@"GET /act?n="];
                NSString *rest = [req substringFromIndex:r.location + r.length];
                name = [[rest componentsSeparatedByString:@" "] firstObject];
                if (name.length) [self setAction:name];
                body = name.length ? name : @"?";
            } else if ([req containsString:@"GET /list"]) {
                body = [[self actions] componentsJoinedByString:@","];
            } else if ([req hasPrefix:@"GET / "]) {
                body = kPage;
                ctype = @"text/html; charset=utf-8";
            }

            NSData *d = [body dataUsingEncoding:NSUTF8StringEncoding];
            NSString *head = [NSString stringWithFormat:
                @"HTTP/1.1 200 OK\r\nContent-Type: %@\r\nContent-Length: %lu\r\n"
                 "Access-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n",
                ctype, (unsigned long)d.length];
            write(c, head.UTF8String, strlen(head.UTF8String));
            write(c, d.bytes, d.length);
            close(c);
        }
    });
}

@end
