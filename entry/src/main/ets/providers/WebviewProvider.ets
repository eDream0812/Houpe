/*
 * WebviewProvider.ets
 * Houpe
 *
 * 「高阶技巧」档的第一个分类：网页视图指纹。
 *
 * 原理：在页面里放一个不可见的 Web 组件，加载 rawfile 里的空白探测页，
 * 等页面就绪后用 WebviewController.runJavaScript 注入一段脚本，
 * 把浏览器侧（canvas / WebGL / navigator / screen）能读到的标识取回来。
 *
 * 两条硬约束：
 * 1) 全程离线——只加载本地 rawfile，脚本不发起任何网络请求；
 * 2) 单向取值——只用 runJavaScript 的回调把字符串取回，
 *    不使用 javaScriptProxy 建立 JS → ArkTS 的反向通道。
 */

import { webview } from '@kit.ArkWeb';
import { FingerprintSignal, SignalEntry, makeSignal, DisplayHint } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { SignalProvider } from '../models/SignalProvider';

/** 等待网页就绪的上限，超时则放弃等待返回空结果（毫秒）。 */
const WEBVIEW_TIMEOUT_MS: number = 8000;

/** 字段分隔符。必须可打印且不会出现在任何取值里（base64/UA/时区均无 "~"）。 */
const FIELD_SEP: string = '~';

/**
 * 采集脚本。以 IIFE 形式执行并把结果作为字符串返回。
 *
 * canvas 部分是真的在算哈希：先按固定指令绘制一段图形（渐变块 + 文字 + 圆弧），
 * 取 toDataURL 得到字节级的像素数据，再用 djb2 求哈希——
 * 不同设备的 GPU、字体栅格化与抗锯齿差异会让这段数据稳定地不同。
 *
 * 结果用 "key=value" 拼接、字段间以 "~" 分隔——
 * 刻意不用 JSON.parse（规避 ArkTS 动态对象类型限制），也不用控制字符
 * （\u0001 会被 ArkWeb 的回传序列化剥掉或转成字面文本，导致所有键值黏死在一起）。
 * "~" 在 base64、UA、时区等所有取值里都不会出现，是安全的分隔符。
 */
const SCRIPT_LINES: string[] = [
  '(function () {',
  '  var R = {};',
  '  function set(k, v) { R[k] = String(v); }',
  '  function djb2(s) { var h = 5381; for (var i = 0; i < s.length; i++) { h = ((h << 5) + h) + s.charCodeAt(i); h = h | 0; } return (h >>> 0).toString(16); }',
  '  var c = null;',
  '  try {',
  '    c = document.createElement("canvas");',
  '    c.width = 280; c.height = 60;',
  '    var g = c.getContext("2d");',
  '    if (g) {',
  '      g.textBaseline = "top";',
  '      g.font = "14px Arial";',
  '      g.fillStyle = "#f60";',
  '      g.fillRect(0, 0, 120, 30);',
  '      g.fillStyle = "#069";',
  '      g.fillText("Houpe fingerprint probe", 2, 15);',
  '      g.strokeStyle = "rgba(0, 255, 0, 0.7)";',
  '      g.beginPath();',
  '      g.arc(50, 50, 25, 0, Math.PI * 2);',
  '      g.stroke();',
  '      var url = c.toDataURL();',
  '      set("canvasLength", url.length);',
  '      set("canvasHash", djb2(url));',
  '      set("canvasPrefix", url.substring(0, 40));',
  '    } else { set("canvasError", "no 2d context"); }',
  '  } catch (e) { set("canvasError", e); }',
  '  try {',
  '    var gl = null;',
  '    if (c) { gl = c.getContext("webgl") || c.getContext("experimental-webgl"); }',
  '    if (gl) {',
  '      var dbg = gl.getExtension("WEBGL_debug_renderer_info");',
  '      set("glVendor", dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR));',
  '      set("glRenderer", dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER));',
  '      set("glShading", gl.getParameter(gl.SHADING_LANGUAGE_VERSION));',
  '    } else { set("glError", "no webgl context"); }',
  '  } catch (e) { set("glError", e); }',
  '  try { set("userAgent", navigator.userAgent); } catch (e) {}',
  '  try { set("language", navigator.language); } catch (e) {}',
  '  try { set("languages", (navigator.languages || []).join(",")); } catch (e) {}',
  '  try { set("platform", navigator.platform || ""); } catch (e) {}',
  '  try { set("cores", navigator.hardwareConcurrency || 0); } catch (e) {}',
  '  try { set("touchPoints", navigator.maxTouchPoints || 0); } catch (e) {}',
  '  try { set("cookieEnabled", navigator.cookieEnabled); } catch (e) {}',
  '  try { set("doNotTrack", navigator.doNotTrack || ""); } catch (e) {}',
  '  try { set("screen", screen.width + "x" + screen.height); } catch (e) {}',
  '  try { set("dpr", window.devicePixelRatio || 0); } catch (e) {}',
  '  try { set("colorDepth", screen.colorDepth || 0); } catch (e) {}',
  '  try { set("timezone", Intl.DateTimeFormat().resolvedOptions().timeZone); } catch (e) {}',
  '  try { set("jsHeapLimit", (performance && performance.memory) ? performance.memory.jsHeapSizeLimit : 0); } catch (e) {}',
  '  var parts = [];',
  '  for (var k in R) { parts.push(k + "=" + R[k]); }',
  '  return parts.join("~");',
  '})()'
];

const HARVEST_SCRIPT: string = SCRIPT_LINES.join('\n');

/**
 * 把网页回传的 "k=v" 序列解析成键值表。
 * 只在第一个等号处切分，避免值里出现等号时被截断。
 *
 * 兼容两种序列化怪癖：
 * 1) 部分版本会把字符串结果按 JSON 形式回传——首尾多包一对引号；
 * 2) 回传管道可能改动内容（历史上控制字符分隔符被剥掉过）。
 */
function toEntries(rawInput: string): Map<string, string> {
  const out: Map<string, string> = new Map<string, string>();
  let raw: string = rawInput.trim();
  while (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
    raw = raw.substring(1, raw.length - 1).trim();
  }
  if (raw.length === 0) {
    return out;
  }
  const parts: string[] = raw.split(FIELD_SEP);
  for (const part of parts) {
    const idx: number = part.indexOf('=');
    if (idx <= 0) {
      continue;
    }
    out.set(part.substring(0, idx), part.substring(idx + 1));
  }
  return out;
}

/**
 * 把网页侧取回的原始字段组装成可展示的信号列表。
 */
function buildSignals(raw: string): FingerprintSignal[] {
  const m: Map<string, string> = toEntries(raw);
  const cat: string = SignalCategory.WEBVIEW as string;
  const out: FingerprintSignal[] = [];

  const hash: string = m.get('canvasHash') ?? '';
  const canvasErr: string = m.get('canvasError') ?? '';
  if (hash.length > 0) {
    out.push(makeSignal('canvasHash', cat, 'Canvas 指纹哈希',
      hash,
      '同一段绘制指令在不同设备的 GPU、字体栅格化与抗锯齿实现下，会产生肉眼不可见、但字节级稳定的差异。把画出来的像素做哈希，就得到一个几乎唯一的设备编号——不需要任何权限，清缓存也清不掉。',
      DisplayHint.KEY_VALUE,
      [
        new SignalEntry('指纹哈希', hash),
        new SignalEntry('像素数据长度', `${m.get('canvasLength') ?? '未知'} 字符`),
        new SignalEntry('差异来源', 'GPU 渲染 + 字体栅格化 + 抗锯齿')
      ]));

    const prefix: string = m.get('canvasPrefix') ?? '';
    if (prefix.length > 0) {
      out.push(makeSignal('canvasData', cat, 'Canvas 原始数据片段',
        prefix,
        '这就是被拿去做哈希的原始像素数据（data URL）的开头。不同设备正是在这里产生分歧——哪怕只差一个字节，算出来的哈希就完全不同。'));
    }
  } else if (canvasErr.length > 0) {
    out.push(makeSignal('canvasError', cat, 'Canvas 采集受限',
      canvasErr,
      '这个网页视图没有交出 2D 画布。受限本身也是一种信号：能画出画布的设备被归为一类，画不出的会被单独记住。'));
  }

  const renderer: string = m.get('glRenderer') ?? '';
  if (renderer.length > 0) {
    out.push(makeSignal('webglRenderer', cat, 'WebGL 渲染器',
      renderer,
      '网页能通过 WebGL 直接问到显卡的真实型号与驱动版本。这往往比系统 API 暴露得更细——驱动版本能定位到具体的系统更新批次。',
      DisplayHint.KEY_VALUE,
      [
        new SignalEntry('显卡厂商', m.get('glVendor') ?? '未知'),
        new SignalEntry('渲染器', renderer),
        new SignalEntry('着色语言', m.get('glShading') ?? '未知')
      ]));
  }

  const ua: string = m.get('userAgent') ?? '';
  if (ua.length > 0) {
    out.push(makeSignal('userAgent', cat, '网页视图 UA',
      ua,
      '每一个网页请求都会带上的身份串。它把系统版本、设备型号与网页引擎版本打包在一起，是最廉价、也最普及的追踪标识。'));
  }

  out.push(makeSignal('navigator', cat, '浏览器环境',
    `${m.get('language') ?? '未知'} · ${m.get('screen') ?? '未知'}`,
    '语言、平台、CPU 核心数、触摸点数、是否允许 Cookie——单看哪一项都不敏感，但十几项拼在一起，就足以把一台设备从人群里挑出来。',
    DisplayHint.KEY_VALUE,
    [
      new SignalEntry('界面语言', m.get('language') ?? '未知'),
      new SignalEntry('语言偏好', m.get('languages') ?? '未知'),
      new SignalEntry('平台', m.get('platform') ?? '未知'),
      new SignalEntry('CPU 核心数', m.get('cores') ?? '未知'),
      new SignalEntry('最大触摸点数', m.get('touchPoints') ?? '未知'),
      new SignalEntry('允许 Cookie', m.get('cookieEnabled') ?? '未知'),
      new SignalEntry('Do Not Track', (m.get('doNotTrack') ?? '') === '' ? '未设置' : (m.get('doNotTrack') ?? ''))
    ]));

  out.push(makeSignal('screenJS', cat, '网页视角的屏幕',
    `${m.get('screen') ?? '未知'} @${m.get('dpr') ?? '?'}x`,
    '网页拿到的是逻辑像素，再乘上像素密度。它与原生读到的物理参数互为印证，让"这是块什么屏"的判断更加确定。',
    DisplayHint.KEY_VALUE,
    [
      new SignalEntry('逻辑分辨率', m.get('screen') ?? '未知'),
      new SignalEntry('像素密度', `${m.get('dpr') ?? '未知'}x`),
      new SignalEntry('色彩深度', `${m.get('colorDepth') ?? '未知'} bit`)
    ]));

  const tz: string = m.get('timezone') ?? '';
  if (tz.length > 0) {
    out.push(makeSignal('timezoneJS', cat, '网页读到的时区',
      tz,
      '网页不需要任何定位权限，只要问一句"现在几点、按哪个时区显示"，就能推断你大致在哪个城市。'));
  }

  const heap: string = m.get('jsHeapLimit') ?? '';
  if (heap.length > 0 && heap !== '0') {
    out.push(makeSignal('jsHeap', cat, 'JS 堆上限',
      heap,
      '浏览器能使用的内存上限由设备的物理内存决定。它反过来泄露了这台机器装了多大的内存。'));
  }

  // 兜底诊断：网页执行了脚本但一个键都没解析出来。
  // 正常情况下不出现；一旦出现，说明回传内容的序列化方式变了。
  if (out.length === 0 && m.size === 0) {
    const trimmed: string = raw.trim();
    if (trimmed.length > 0) {
      out.push(makeSignal('probeEcho', cat, '回传内容无法解析',
        trimmed.substring(0, 80),
        '网页确实执行了探测脚本并回传了内容，但格式与约定不符——通常意味着这个网页引擎改动了结果的序列化方式。看到这段原始内容，就能定位它变成了什么样。'));
    }
  }

  return out;
}

/**
 * 网页视图指纹采集器。
 *
 * 采集依赖一个真实渲染的 Web 组件（见下方 WebviewHarvester），
 * 因此 collect() 在结果就绪前会挂起等待，由 Harvester 回写后兑现。
 */
export class WebviewProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.WEBVIEW;

  /** 已采集的结果；null 表示尚未就绪 */
  private result: FingerprintSignal[] | null = null;
  private waiter: ((signals: FingerprintSignal[]) => void) | null = null;
  private timer: number = -1;

  async collect(): Promise<FingerprintSignal[]> {
    if (this.result !== null) {
      return this.result;
    }
    const self: WebviewProvider = this;
    return new Promise<FingerprintSignal[]>((resolve: (signals: FingerprintSignal[]) => void) => {
      self.waiter = resolve;
      // 兜底：网页迟迟不回调时不要让采集永久挂起
      self.timer = setTimeout(() => {
        self.settle([]);
      }, WEBVIEW_TIMEOUT_MS);
    });
  }

  /** 由 Harvester 在 runJavaScript 回调里写入结果。 */
  complete(raw: string): void {
    const signals: FingerprintSignal[] = buildSignals(raw);
    this.result = signals;
    this.settle(signals);
  }

  /** 网页加载失败时的收尾。 */
  fail(): void {
    this.result = [];
    this.settle([]);
  }

  private settle(signals: FingerprintSignal[]): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
    const w: ((signals: FingerprintSignal[]) => void) | null = this.waiter;
    this.waiter = null;
    if (w !== null) {
      w(signals);
    }
  }
}

/** 全局单例：Harvester 与 CategoryStore 必须共用同一个实例。 */
export const webviewProvider: WebviewProvider = new WebviewProvider();

/**
 * 隐藏的探测页。1vp 见方、完全透明、绝对定位（不参与父容器布局），
 * 页面加载完成后注入脚本，把结果单向写回 Provider。
 */
@ComponentV2
export struct WebviewHarvester {
  private controller: webview.WebviewController = new webview.WebviewController();
  private done: boolean = false;

  build() {
    Web({ src: $rawfile('houpe_probe.html'), controller: this.controller })
      .width(1)
      .height(1)
      .opacity(0)
      .position({ x: 0, y: 0 })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .onPageEnd(() => {
        this.runHarvest();
      })
  }

  /**
   * 注入脚本并把结果单向写回 Provider。
   * webview.WebviewController 在本 SDK 上只有
   * `runJavaScript(script): Promise<string>` 与 AsyncCallback 两种形态，
   * 这里取 Promise 版，避免引入 BusinessError 类型。
   */
  private async runHarvest(): Promise<void> {
    if (this.done) {
      return;
    }
    try {
      const result: string = await this.controller.runJavaScript(HARVEST_SCRIPT);
      this.done = true;
      webviewProvider.complete(result);
    } catch (e) {
      webviewProvider.fail();
    }
  }
}
