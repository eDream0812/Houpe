/*
 * LayoutUtil.ets
 * Houpe
 *
 * 多端响应式断点工具。基于「窗口宽度（vp）」划分 sm/md/lg：
 *  - 折叠屏开合会改变窗口宽度；
 *  - 2in1 / PC 的自由窗口缩放也会改变窗口宽度；
 * 二者都会驱动布局在「手机单栏」↔「平板 / PC 分栏」之间自适应。
 *
 * 阈值与 HarmonyOS 规一批：sm < 600vp，md 600~839vp，lg >= 840vp。
 */

/** 手机竖屏 / 折叠态：< 600vp */
export const BP_SM: string = 'sm';
/** 手机横屏 / 平板竖屏 / 折叠屏展开：600~839vp */
export const BP_MD: string = 'md';
/** 平板横屏 / 2in1 / PC：>= 840vp */
export const BP_LG: string = 'lg';

const BREAKPOINT_SM_MAX: number = 600;
const BREAKPOINT_MD_MAX: number = 840;

/**
 * 根据窗口宽度（vp）返回断点。
 */
export function breakpointForWidth(widthVp: number): string {
  if (widthVp < BREAKPOINT_SM_MAX) {
    return BP_SM;
  }
  if (widthVp < BREAKPOINT_MD_MAX) {
    return BP_MD;
  }
  return BP_LG;
}

/**
 * 内容最大宽度（vp）。超出时内容居中，避免大屏被拉伸到铺满。
 */
export function contentMaxWidthFor(bp: string): number {
  if (bp === BP_LG) {
    return 960;
  }
  if (bp === BP_MD) {
    return 720;
  }
  return Number.MAX_SAFE_INTEGER;
}

/**
 * 页面左右内边距（vp）。宽屏给更大留白。
 */
export function sidePaddingFor(bp: string): number {
  if (bp === BP_LG) {
    return 32;
  }
  if (bp === BP_MD) {
    return 24;
  }
  return 16;
}

/**
 * 分类卡片栅格的单个列宽。
 * sm 单列、md 两列、lg 三列。
 */
export function categoryItemWidth(bp: string): string {
  if (bp === BP_LG) {
    return '33.33%';
  }
  if (bp === BP_MD) {
    return '50%';
  }
  return '100%';
}

/**
 * 是否启用导航分栏（左右主从）模式。
 * 仅在 lg（平板横屏 / 2in1 / PC）下分栏，其余保持单栏栈式导航。
 */
export function isSplitMode(bp: string): boolean {
  return bp === BP_LG;
}

/**
 * 断点可观察单例。
 *
 * EntryAbility 在窗口尺寸变化时把最新断点写入这里，
 * 各 @ComponentV2 页面通过订阅拿到实时断点并自适应布局。
 * 之所以不直接用 AppStorage.@StorageProp，是因为 @StorageProp 是 V1 装饰器，
 * 无法在 @ComponentV2 结构体上使用；这里用轻量订阅绕开 V1/V2 边界。
 */

type BreakpointListener = (bp: string) => void;

let currentBp: string = BP_SM;
const bpListeners: BreakpointListener[] = [];

/**
 * 由窗口宽度（vp）计算并广播断点。值不变时不触发通知。
 */
export function setBreakpointForWidth(widthVp: number): void {
  const bp: string = breakpointForWidth(widthVp);
  if (bp !== currentBp) {
    currentBp = bp;
    for (const listener of bpListeners) {
      listener(bp);
    }
  }
}

/**
 * 读取当前断点（页面初始化时使用）。
 */
export function getBreakpoint(): string {
  return currentBp;
}

/**
 * 订阅断点变化；返回用于注销的函数。
 */
export function subscribeBreakpoint(listener: BreakpointListener): void {
  if (bpListeners.indexOf(listener) < 0) {
    bpListeners.push(listener);
  }
}

/**
 * 注销断点订阅。
 */
export function unsubscribeBreakpoint(listener: BreakpointListener): void {
  const index: number = bpListeners.indexOf(listener);
  if (index >= 0) {
    bpListeners.splice(index, 1);
  }
}
