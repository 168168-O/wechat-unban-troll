// Frida：在越狱机上摸微信活体 SDK 的判定出口
// 用法：frida -U -f com.tencent.xin -l probe_liveness.js --no-pause
// 目标：找到「活体结果」那个方法，改成恒过，比喂帧稳

Java  = null;   // iOS 下不用
var hits = [];

function log(s) { console.log("[probe] " + s); }

if (ObjC.available) {
  // 1. 枚举类名和协议名里跟活体/人脸相关的
  Object.keys(ObjC.classes)
    .filter(function (n) { return /face|liveness|alive|detect|verify|yt|youtu|tencent/i.test(n); })
    .slice(0, 400)
    .forEach(function (n) {
      var c = ObjC.classes[n];
      var ms = c.$ownMethods.filter(function (m) {
        return /alive|liveness|verify|result|pass|detect|score|finish/i.test(m);
      });
      if (ms.length) {
        log("类 " + n);
        ms.forEach(function (m) { log("    " + m); });
      }
    });

  // 2. 对所有返回 BOOL 且名字带 alive/liveness/pass 的方法挂钩，打印调用与返回值
  var hooked = 0;
  Object.keys(ObjC.classes).forEach(function (cn) {
    var c = ObjC.classes[cn];
    var ms = c.$ownMethods.filter(function (m) {
      return /^-\s*\(BOOL\)/.test(m) && /alive|liveness|pass|isReal|antiSpoof/i.test(m);
    });
    ms.forEach(function (m) {
      var sel = m.replace(/^-\s*\(BOOL\)\s*/, "").split(" ")[0];
      try {
        var impl = c[sel].implementation;
        Interceptor.attach(impl, {
          onLeave: function (ret) {
            log("命中 " + cn + " " + sel + " -> " + ret);
            // 恒过：直接改成 YES
            ret.replace(ptr(1));
          }
        });
        hooked++;
        log("已挂钩 " + cn + " " + sel);
      } catch (e) { }
    });
  });
  log("共挂钩 " + hooked + " 个 BOOL 活体方法");

  // 3. 顺带看人脸检测入口，确认走的是哪套 SDK
  ["YTFaceDetector", "TXLivenessDetector", "FaceLiveDetect", "WXFaceVerify"].forEach(function (n) {
    if (ObjC.classes[n]) log("存在类： " + n);
  });
} else {
  log("ObjC runtime 不可用，检查是否注入了 SpringBoard 而不是 Weixin");
}
