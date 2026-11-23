// 手机上的浮动控制面板：不接电脑，直接在微信界面上叠一排按钮
// 点「张嘴」→ ActionStore 立刻切到 mouth.mov，摄像头画面跟着变

#import <UIKit/UIKit.h>
#import "ActionStore.h"

static UIWindow *gPanel = nil;
static UILabel *gTitle = nil;

static NSArray<NSArray<NSString *> *> *VCButtons(void) {
    return @[
        @[@"正脸", @"front"], @[@"抬头", @"up"],   @[@"低头", @"down"],
        @[@"左转", @"left"],  @[@"右转", @"right"], @[@"张嘴", @"mouth"],
        @[@"眨眼", @"blink"], @[@"点头", @"nod"],   @[@"摇头", @"shake"],
        @[@"念数", @"digits"]
    ];
}

static void VCRefreshTitle(void) {
    if (!gTitle) return;
    gTitle.text = [NSString stringWithFormat:@"vcam · %@", [[ActionStore shared] currentAction]];
}

static void VCPanelShow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPanel) { gPanel.hidden = NO; VCRefreshTitle(); return; }

        CGRect scr = UIScreen.mainScreen.bounds;
        CGFloat w = MIN(scr.size.width - 20, 430);
        CGFloat btn = (w - 5 * 8 - 16) / 5.0;
        CGFloat h = 34 + btn * 2 + 8 * 3 + 26;

        UIWindow *win = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                win = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)s];
                break;
            }
        }
        if (!win) win = [[UIWindow alloc] initWithFrame:scr];

        win.frame = CGRectMake((scr.size.width - w) / 2.0,
                               scr.size.height - h - 120,
                               w, h);
        win.windowLevel = UIWindowLevelAlert + 1;
        win.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.93];
        win.layer.cornerRadius = 16;
        win.layer.masksToBounds = YES;
        win.hidden = NO;
        UIViewController *vc = [UIViewController new];
        vc.view.frame = win.bounds;
        vc.view.backgroundColor = [UIColor clearColor];
        win.rootViewController = vc;

        UIView *root = win.rootViewController.view;
        root.backgroundColor = [UIColor clearColor];

        gTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, w - 20, 20)];
        gTitle.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
        gTitle.textColor = [UIColor colorWithRed:0.24 green:0.86 blue:0.52 alpha:1];
        [root addSubview:gTitle];

        // 隐藏按钮（右上角小字）
        UIButton *hide = [UIButton buttonWithType:UIButtonTypeSystem];
        hide.frame = CGRectMake(w - 54, 4, 48, 24);
        [hide setTitle:@"收起" forState:UIControlStateNormal];
        hide.titleLabel.font = [UIFont systemFontOfSize:11];
        [hide setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [hide addTarget:win action:NSSelectorFromString(@"vcHide") forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:hide];

        NSArray<NSArray<NSString *> *> *btns = VCButtons();
        for (NSUInteger i = 0; i < btns.count; i++) {
            NSUInteger row = i / 5, col = i % 5;
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(8 + col * (btn + 8), 34 + row * (btn + 8), btn, btn);
            [b setTitle:btns[i][0] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
            b.layer.cornerRadius = 12;
            b.tag = (NSInteger)i;
            [b addTarget:win action:NSSelectorFromString(@"vcTap:") forControlEvents:UIControlEventTouchUpInside];
            [root addSubview:b];
        }

        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(8, h - 26, w - 16, 20)];
        tip.text = @"拖动可移位 · 点按钮切动作 · 「收起」隐藏";
        tip.font = [UIFont systemFontOfSize:10];
        tip.textColor = [UIColor grayColor];
        [root addSubview:tip];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:win
                                                                            action:NSSelectorFromString(@"vcPan:")];
        [root addGestureRecognizer:pan];

        gPanel = win;
        VCRefreshTitle();
        NSLog(@"[vcam] 控制面板已显示，动作=%@", [[ActionStore shared] currentAction]);
    });
}

static void VCPanelHide(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ gPanel.hidden = YES; });
}

// 给 UIWindow 挂三个方法，避免再建类
@interface UIWindow (VCamPanel)
- (void)vcTap:(UIButton *)sender;
- (void)vcHide;
- (void)vcPan:(UIPanGestureRecognizer *)g;
@end

@implementation UIWindow (VCamPanel)

- (void)vcTap:(UIButton *)sender {
    NSArray *b = VCButtons();
    if (sender.tag < 0 || sender.tag >= (NSInteger)b.count) return;
    NSString *name = b[sender.tag][1];
    [[ActionStore shared] setAction:name];
    VCRefreshTitle();

    [UIView animateWithDuration:0.12 animations:^{
        sender.backgroundColor = [UIColor colorWithRed:0.09 green:0.55 blue:0.27 alpha:1];
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.25 animations:^{
            sender.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
        }];
    }];
}

- (void)vcHide { self.hidden = YES; }

- (void)vcPan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v];
    CGRect f = self.frame;
    f.origin.x += t.x;
    f.origin.y += t.y;
    CGRect scr = UIScreen.mainScreen.bounds;
    f.origin.x = MAX(0, MIN(f.origin.x, scr.size.width - f.size.width));
    f.origin.y = MAX(0, MIN(f.origin.y, scr.size.height - f.size.height));
    self.frame = f;
    [g setTranslation:CGPointZero inView:v];
}

@end
