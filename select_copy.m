#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <stdio.h>
#import <dispatch/dispatch.h>

// 定义键盘按键 C 的 CGKeyCode
const CGKeyCode kVK_ANSI_C = 0x08;
// 定义 Command 键的 CGKeyCode
const CGKeyCode kVK_Command = 0x37;

// 状态变量
static bool isLeftButtonDown = false;
static CGPoint lastRightClickLocation;
static CFMachPortRef globalEventTap = NULL;

// 显示 "Copied" 提示框
void showCopiedNotification(CGPoint location) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // 获取当前鼠标位置（实时获取，确保准确性）
            NSPoint mouseLocation = [NSEvent mouseLocation];
            
            // 创建一个无边框的窗口，调整位置到鼠标右下方
            CGFloat windowWidth = 90;
            CGFloat windowHeight = 35;
            NSRect windowFrame = NSMakeRect(mouseLocation.x + 15, mouseLocation.y - windowHeight - 15, windowWidth, windowHeight);
            
            // 确保窗口不会超出屏幕边界
            NSScreen *mainScreen = [NSScreen mainScreen];
            NSRect screenFrame = [mainScreen visibleFrame];
            
            // 调整X坐标，防止超出右边界
            if (windowFrame.origin.x + windowFrame.size.width > screenFrame.origin.x + screenFrame.size.width) {
                windowFrame.origin.x = mouseLocation.x - windowWidth - 15;
            }
            
            // 调整Y坐标，防止超出下边界
            if (windowFrame.origin.y < screenFrame.origin.y) {
                windowFrame.origin.y = mouseLocation.y + 15;
            }
            
            NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                           styleMask:NSWindowStyleMaskBorderless
                                                             backing:NSBackingStoreBuffered
                                                               defer:NO];
            
            // 设置窗口属性
            [window setLevel:NSFloatingWindowLevel];
            [window setOpaque:NO];
            [window setHasShadow:YES];
            [window setIgnoresMouseEvents:YES];
            [window setBackgroundColor:[NSColor clearColor]];
            
            // 创建背景视图 - 使用更现代的设计
            NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, windowWidth, windowHeight)];
            [contentView setWantsLayer:YES];
            
            // 设置渐变背景
            CAGradientLayer *gradientLayer = [CAGradientLayer layer];
            gradientLayer.frame = contentView.bounds;
            gradientLayer.colors = @[
                (id)[NSColor colorWithRed:0.15 green:0.75 blue:0.4 alpha:0.95].CGColor,  // 绿色顶部
                (id)[NSColor colorWithRed:0.1 green:0.65 blue:0.35 alpha:0.95].CGColor    // 深绿色底部
            ];
            gradientLayer.cornerRadius = 8.0;
            [contentView.layer addSublayer:gradientLayer];
            
            // 创建文本标签 - 更好的居中和字体
            NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 0, windowWidth - 10, windowHeight)];
            [label setStringValue:@"Copied ✓"];
            [label setAlignment:NSTextAlignmentCenter];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setSelectable:NO];
            [label setTextColor:[NSColor whiteColor]];
            [label setFont:[NSFont boldSystemFontOfSize:13]];
            
            // 确保垂直居中
            [label sizeToFit];
            NSRect labelFrame = label.frame;
            labelFrame.origin.x = (windowWidth - labelFrame.size.width) / 2;
            labelFrame.origin.y = (windowHeight - labelFrame.size.height) / 2;
            labelFrame.size.width = windowWidth - 10;  // 确保有足够的宽度
            [label setFrame:labelFrame];
            
            [contentView addSubview:label];
            [window setContentView:contentView];
            [window makeKeyAndOrderFront:nil];
            
            // 添加淡入动画
            [window setAlphaValue:0.0];
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.2;
                [[window animator] setAlphaValue:1.0];
            } completionHandler:nil];
            
            // 1.5秒后淡出并关闭窗口
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    context.duration = 0.3;
                    [[window animator] setAlphaValue:0.0];
                } completionHandler:^{
                    [window close];
                }];
            });
        }
    });
}

// 模拟 Command-C 复制 操作
void postCommandC() {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef cmdDown = CGEventCreateKeyboardEvent(source, kVK_Command, true);
    CGEventRef cDown = CGEventCreateKeyboardEvent(source, kVK_ANSI_C, true);
    CGEventRef cUp = CGEventCreateKeyboardEvent(source, kVK_ANSI_C, false);
    CGEventRef cmdUp = CGEventCreateKeyboardEvent(source, kVK_Command, false);

    CGEventSetFlags(cDown, kCGEventFlagMaskCommand);
    CGEventSetFlags(cUp, kCGEventFlagMaskCommand);

    CGEventPost(kCGHIDEventTap, cmdDown);
    CGEventPost(kCGHIDEventTap, cDown);
    CGEventPost(kCGHIDEventTap, cUp);
    CGEventPost(kCGHIDEventTap, cmdUp);

    CFRelease(cmdUp);
    CFRelease(cUp);
    CFRelease(cDown);
    CFRelease(cmdDown);
    CFRelease(source);
    
    printf("--> 已异步触发复制 (Command-C)\n");
    fflush(stdout);
}


// 核心回调函数
CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    switch (type) {
        case kCGEventLeftMouseDown:
            isLeftButtonDown = true;
            printf("[DEBUG] 左键按下\n");
            fflush(stdout);
            break;
            
        case kCGEventLeftMouseUp:
            isLeftButtonDown = false;
            printf("[DEBUG] 左键释放\n");
            fflush(stdout);
            break;
            
        case kCGEventRightMouseDown:
            if (isLeftButtonDown) {
                printf("[DEBUG] 检测到拖拽过程中的右键，正在拦截并触发复制...\n");
                fflush(stdout);
                lastRightClickLocation = CGEventGetLocation(event);
            
                dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_MSEC);

                // 1. 使用 GCD 安排 postCommandC 函数在延迟后异步执行
                dispatch_after(delay, dispatch_get_main_queue(), ^{
                    postCommandC();
                    showCopiedNotification(lastRightClickLocation);
                });

                // 2. 立即返回 NULL，阻止这个 RightMouseDown 事件
                return NULL; 
                
            } else {
                printf("[DEBUG] 右键点击（非拖拽状态），允许通过\n");
                fflush(stdout);
            }
            break;
            
        case kCGEventTapDisabledByTimeout:
            printf("Event Tap timed out, re-enabling.\n");
            if (globalEventTap) {
                CGEventTapEnable(globalEventTap, true);
            }
            break;
            
        default:
            break;
    }
    
    return event;
}


int main(int argc, const char * argv[]) {
    // 初始化 NSApplication
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown) |
                            CGEventMaskBit(kCGEventLeftMouseUp)   |
                            CGEventMaskBit(kCGEventRightMouseDown);

    globalEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, eventCallback, NULL);

    if (!globalEventTap) {
        fprintf(stderr, "错误：无法创建 Event Tap。\n");
        fprintf(stderr, "请确保在 '系统设置 > 隐私与安全性 > 辅助功能' 中为您的终端程序授权。\n");
        return 1;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, globalEventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(globalEventTap, true);

    printf("启动成功！\n");
    printf("请保持此终端窗口运行。按 Control-C 退出程序。\n");
    
    CFRunLoopRun();

    CFRelease(globalEventTap);
    CFRelease(runLoopSource);
    
    return 0;
}