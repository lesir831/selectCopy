#import <ApplicationServices/ApplicationServices.h>
#import <stdio.h>
#import <dispatch/dispatch.h>

// 定义键盘按键 C 的 CGKeyCode
const CGKeyCode kVK_ANSI_C = 0x08;
// 定义 Command 键的 CGKeyCode
const CGKeyCode kVK_Command = 0x37;

// 状态变量
static bool isLeftButtonDown = false;

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
            
                dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_MSEC);

                // 1. 使用 GCD 安排 postCommandC 函数在延迟后异步执行
                dispatch_after(delay, dispatch_get_main_queue(), ^{
                    postCommandC();
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
            CGEventTapEnable(proxy, true);
            break;
            
        default:
            break;
    }
    
    return event;
}


int main(int argc, const char * argv[]) {

    CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown) |
                            CGEventMaskBit(kCGEventLeftMouseUp)   |
                            CGEventMaskBit(kCGEventRightMouseDown);

    CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, eventCallback, NULL);

    if (!eventTap) {
        fprintf(stderr, "错误：无法创建 Event Tap。\n");
        fprintf(stderr, "请确保在 '系统设置 > 隐私与安全性 > 辅助功能' 中为您的终端程序授权。\n");
        return 1;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);

    printf("启动成功！\n");
    printf("请保持此终端窗口运行。按 Control-C 退出程序。\n");
    
    CFRunLoopRun();

    CFRelease(eventTap);
    CFRelease(runLoopSource);
    
    return 0;
}