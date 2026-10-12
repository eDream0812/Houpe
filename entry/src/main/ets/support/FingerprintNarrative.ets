/*
 * FingerprintNarrative.ets
 * Houpe
 *
 * 洞察引擎：把原始读数翻译成人话结论。
 *
 * 这是整个 App 的灵魂——单看一个数值没什么意义，
 * 但把它放进人的语境里，用户才能意识到自己暴露了什么。
 */

import { FingerprintSignal } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { PlatformDevice, PlatformLocale, PlatformContext, PlatformPasteboard } from './PlatformShim';
import { batteryInfo } from '@kit.BasicServicesKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { AppSymbols } from '../common/AppSymbols';
import { Theme } from '../common/Theme';

/**
 * 一条洞察。
 */
export class NarrativeItem {
  /** 稳定标识，用于 ForEach 的 key */
  id: string;
  /** 图标 */
  symbol: Resource;
  /** 加粗的结论句 */
  headline: string;
  /** 灰色的解释句：这条结论是怎么来的 */
  basis: string;

  constructor(id: string, symbol: Resource, headline: string, basis: string) {
    this.id = id;
    this.symbol = symbol;
    this.headline = headline;
    this.basis = basis;
  }
}

/**
 * 从已采集的信号里推导洞察。
 */
export class FingerprintNarrative {

  /**
   * 依据当前 Store 里的信号生成洞察列表。
   * 任何一条推导不出结论，就不生成对应卡片——不编造内容。
   */
  static build(signals: Map<SignalCategory, FingerprintSignal[]>): NarrativeItem[] {
    const out: NarrativeItem[] = [];

    const region: string = FingerprintNarrative.regionName();
    if (region.length > 0) {
      out.push(new NarrativeItem(
        'region', AppSymbols.GLOBE_INSIGHT,
        `你的系统区域设置为${region}。`,
        '读自系统区域设置。用代理软件也改不了它，因为应用读的是这个值而不是网络位置。'
      ));
    }

    const languages: string[] = FingerprintNarrative.languageNames(signals);
    if (languages.length >= 2) {
      out.push(new NarrativeItem(
        'languages', AppSymbols.KEYBOARD_INSIGHT,
        `你的首选语言包括${languages.join('、')}。`,
        '读自系统的首选语言列表。装了几种语言的用户，列表组合起来就有很强的区分度。'
      ));
    }

    const journey: string = FingerprintNarrative.travelHint();
    if (journey.length > 0) {
      out.push(new NarrativeItem(
        'travel', AppSymbols.JOURNEY_INSIGHT,
        `你的时区可能不在你设置的系统区域内。`,
        `读自系统时区${PlatformLocale.timeZone}。时区暴露你当前在哪，和区域设置不一致时，通常意味着你在旅行或者手动改过时区。`
      ));
    }

    const setup: string = FingerprintNarrative.setupHint(signals);
    if (setup.length > 0) {
      out.push(new NarrativeItem(
        'storage', AppSymbols.GIFT_INSIGHT,
        setup,
        '读自存储空间的已用比例。同型号设备容量相同，但用得满不满，每个人差别很大。'
      ));
    }

    const clipboard: string = FingerprintNarrative.clipboardHint(signals);
    if (clipboard.length > 0) {
      out.push(new NarrativeItem(
        'pasteboard', AppSymbols.CLIPBOARD_INSIGHT,
        clipboard,
        '读自系统剪贴板的变更计数。每一次复制或剪切都会让这个数字加一，对所有应用都可见。'
      ));
    }

    const scale: string = FingerprintNarrative.accessibilityHint();
    if (scale.length > 0) {
      out.push(new NarrativeItem(
        'accessibility', AppSymbols.ACCESSIBILITY_INSIGHT,
        scale,
        '读自系统字体缩放与外观设置。大字体和深色外观各自只覆盖一部分用户，组合起来能分出不同使用习惯的人。'
      ));
    }

    const deviceAge: string = FingerprintNarrative.deviceHint(signals);
    if (deviceAge.length > 0) {
      out.push(new NarrativeItem(
        'device', AppSymbols.DEVICE,
        deviceAge,
        '读自设备的机型、芯片与系统构建信息。它们共同刻画了这台设备的身份。'
      ));
    }

    const power: string = FingerprintNarrative.powerHint(signals);
    if (power.length > 0) {
      out.push(new NarrativeItem(
        'power', AppSymbols.BATTERY,
        power,
        '读自电池的电量、充电状态与温度。电量变化很慢，短时间回访就能拿到相同的值来重识别你。'
      ));
    }

    const net: string = FingerprintNarrative.networkHint(signals);
    if (net.length > 0) {
      out.push(new NarrativeItem(
        'network', AppSymbols.NETWORK,
        net,
        '读自当前网络的接口名、IP 与 DNS。同一网络里的本地 IP 往往唯一，能把设备区分开。'
      ));
    }

    return out;
  }

  /**
   * 取一个"指纹串"，展示几个关键字段拼在一起的样子。
   */
  static fingerprintChip(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const parts: string[] = [];

    const name: string = PlatformDevice.readableName;
    if (name.length > 0) {
      parts.push(name);
    }
    parts.push(PlatformLocale.systemLanguage + '-' + PlatformLocale.systemRegion);
    parts.push(PlatformLocale.timeZone);
    parts.push(PlatformDevice.chipType);
    parts.push(`API ${PlatformDevice.sdkApiVersion}`);
    parts.push(PlatformLocale.is24HourClock ? '24h' : '12h');

    return parts.join(' · ');
  }

  /* ---------- 单条推导 ---------- */

  private static regionName(): string {
    const code: string = PlatformLocale.systemRegion;
    if (code === undefined || code.length === 0 || code === '001') {
      return '';
    }
    return RegionNames.text(code);
  }

  private static languageNames(signals: Map<SignalCategory, FingerprintSignal[]>): string[] {
    const list: FingerprintSignal[] | undefined = signals.get(SignalCategory.LOCALE);
    if (list === undefined) {
      return [];
    }
    const preferred: FingerprintSignal | undefined =
      list.find(s => s.id.endsWith('.preferred'));
    if (preferred === undefined || preferred.entries === null) {
      return [];
    }
    const names: string[] = [];
    for (const e of preferred.entries) {
      names.push(LanguageNames.text(e.value));
    }
    return names;
  }

  /**
   * 仅对"非地理时区"给出提示：UTC / Etc/* / 无法识别 通常不是设备默认设置，
   * 往往意味着手动改过时区或走了代理。
   * 普通地理时区（如 Asia/Shanghai）在没有"国家→洲"映射表的情况下无法可靠判断是否
   * 与区域设置不一致，为避免误报一律不提示。
   */
  private static travelHint(): string {
    const tz: string = PlatformLocale.timeZone;
    if (!tz || tz === '未知' || tz === 'UTC' || tz === 'GMT' || tz.startsWith('Etc/')) {
      const label: string = (tz === '未知') ? '无法识别' : tz;
      return `你的时区是${label}，属于非地理时区，通常不是设备默认设置，可能手动改过或使用了 VPN/代理。`;
    }
    return '';
  }

  private static setupHint(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const list: FingerprintSignal[] | undefined = signals.get(SignalCategory.STORAGE);
    if (list === undefined) {
      return '';
    }
    const usage: FingerprintSignal | undefined = list.find(s => s.id.endsWith('.usage'));
    if (usage === undefined) {
      return '';
    }
    return `这台设备的存储空间已经用掉了 ${usage.value}。`;
  }

  private static clipboardHint(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const count: number = PlatformPasteboard.changeCount;
    if (count < 2) {
      return '';
    }
    return `本次开机以来，你的剪贴板内容被改动过 ${count} 次。`;
  }

  private static accessibilityHint(): string {
    const scale: number = PlatformContext.fontScale();
    const dark: boolean = PlatformContext.colorMode() === '深色';
    const parts: string[] = [];
    if (scale > 1.0) {
      parts.push(`系统字体被放大到 ${scale.toFixed(2)} 倍`);
    }
    if (dark) {
      parts.push('使用深色外观');
    }
    if (parts.length === 0) {
      return '';
    }
    return `你的系统设置里开启了这些：无障碍相关的选项（${parts.join('、')}）。`;
  }

  private static deviceHint(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const name: string = PlatformDevice.readableName;
    if (name.length === 0) {
      return '';
    }
    return `你正在使用一台 ${PlatformDevice.manufacture} ${name}，芯片是 ${PlatformDevice.chipType}。`;
  }

  private static powerHint(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const soc: number = batteryInfo.batterySOC;
    if (soc < 0) {
      return '';
    }
    const level: string = soc <= 20 ? '偏低' : (soc >= 90 ? '充足' : '正常');
    return `当前电量 ${soc}%，处于${level}状态，电池温度 ${(batteryInfo.batteryTemperature / 10).toFixed(1)} °C。`;
  }

  private static networkHint(signals: Map<SignalCategory, FingerprintSignal[]>): string {
    const list: FingerprintSignal[] | undefined = signals.get(SignalCategory.NETWORK);
    if (list === undefined) {
      return '';
    }
    const addr: FingerprintSignal | undefined = list.find(s => s.id.endsWith('.addresses'));
    if (addr === undefined || addr.value === '未获取') {
      return '';
    }
    const bearer: FingerprintSignal | undefined = list.find(s => s.id.endsWith('.bearer'));
    const b: string = bearer === undefined ? '' : bearer.value;
    return `你现在通过${b}连接，本地地址是 ${addr.value}。`;
  }
}

/**
 * 区域码转中文名。只覆盖常见区域，未知时回退到原码。
 */
export class RegionNames {
  private static readonly TABLE: Map<string, string> = new Map<string, string>([
    ['CN', '中国'], ['US', '美国'], ['JP', '日本'], ['KR', '韩国'],
    ['GB', '英国'], ['DE', '德国'], ['FR', '法国'], ['CA', '加拿大'],
    ['AU', '澳大利亚'], ['SG', '新加坡'], ['MY', '马来西亚'], ['TH', '泰国'],
    ['VN', '越南'], ['ID', '印度尼西亚'], ['PH', '菲律宾'], ['IN', '印度'],
    ['RU', '俄罗斯'], ['IT', '意大利'], ['ES', '西班牙'], ['NL', '荷兰'],
    ['BR', '巴西'], ['MX', '墨西哥'], ['ZA', '南非'], ['AE', '阿联酋'],
    ['SA', '沙特阿拉伯'], ['TR', '土耳其'], ['PL', '波兰'], ['SE', '瑞典'],
    ['CH', '瑞士'], ['AT', '奥地利'], ['BE', '比利时'], ['NZ', '新西兰'],
    ['HK', '中国香港'], ['MO', '中国澳门'], ['TW', '中国台湾']
  ]);

  static text(code: string): string {
    const name: string | undefined = RegionNames.TABLE.get(code);
    return name ?? code;
  }
}

/**
 * 语言码转中文名。
 */
export class LanguageNames {
  private static readonly TABLE: Map<string, string> = new Map<string, string>([
    ['zh', '中文'], ['en', '英语'], ['ja', '日语'], ['ko', '韩语'],
    ['ar', '阿拉伯语'], ['fr', '法语'], ['de', '德语'], ['es', '西班牙语'],
    ['ru', '俄语'], ['pt', '葡萄牙语'], ['it', '意大利语'], ['th', '泰语'],
    ['vi', '越南语'], ['id', '印尼语'], ['ms', '马来语'], ['hi', '印地语'],
    ['tr', '土耳其语'], ['pl', '波兰语'], ['nl', '荷兰语'], ['sv', '瑞典语']
  ]);

  static text(code: string): string {
    // 取语言码主体（去掉地区后缀）
    const primary: string = code.split('-')[0];
    const name: string | undefined = LanguageNames.TABLE.get(primary);
    return name ?? code;
  }
}
