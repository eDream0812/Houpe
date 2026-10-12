/*
 * PlatformShim.ets
 * Houpe
 *
 * 平台差异收敛层。所有 Provider 只调用这里的入口，
 * 不直接触碰具体系统 API。
 */

import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * 设备标识。
 */
export class PlatformDevice {
  static get manufacture(): string {
    return deviceInfo.manufacture;
  }

  static get brand(): string {
    return deviceInfo.brand;
  }

  /** 市场名，如 Mate 70 Pro */
  static get marketName(): string {
    return deviceInfo.marketName;
  }

  /** 型号，如 TAS-AL00 */
  static get productModel(): string {
    return deviceInfo.productModel;
  }

  /** 产品系列 */
  static get productSeries(): string {
    return deviceInfo.productSeries;
  }

  static get hardwareModel(): string {
    return deviceInfo.hardwareModel;
  }

  static get softwareModel(): string {
    return deviceInfo.softwareModel;
  }

  /** phone / tablet / wearable 等 */
  static get deviceType(): string {
    return deviceInfo.deviceType;
  }

  static get osFullName(): string {
    return deviceInfo.osFullName;
  }

  static get displayVersion(): string {
    return deviceInfo.displayVersion;
  }

  static get sdkApiVersion(): number {
    return deviceInfo.sdkApiVersion;
  }

  /** CPU 芯片类型，API 21+ */
  static get chipType(): string {
    return deviceInfo.chipType;
  }

  /** 开机次数，API 21+ */
  static get bootCount(): number {
    return deviceInfo.bootCount;
  }

  /** 支持的 ABI 列表，如 arm64-v8a */
  static get abiList(): string {
    return deviceInfo.abiList;
  }

  /** 开放设备标识，按开发者隔离，无需敏感权限 */
  static get odid(): string {
    return deviceInfo.ODID;
  }

  /** 安全补丁标签 */
  static get securityPatchTag(): string {
    return deviceInfo.securityPatchTag;
  }

  /** 系统构建类型 */
  static get buildType(): string {
    return deviceInfo.buildType;
  }

  /**
   * 设备的可读名称。优先用市场名，缺失时回退到型号。
   */
  static get readableName(): string {
    const name: string = PlatformDevice.marketName;
    if (name !== undefined && name.length > 0) {
      return name;
    }
    return PlatformDevice.productModel;
  }

  /**
   * 系统名称。
   */
  static get systemName(): string {
    return 'HarmonyOS';
  }
}

/**
 * 屏幕与显示。
 */
export class PlatformScreen {
  static get nativeBounds(): string {
    const d: display.Display = display.getDefaultDisplaySync();
    return `${d.width} x ${d.height}`;
  }

  static get pixelWidth(): number {
    return display.getDefaultDisplaySync().width;
  }

  static get pixelHeight(): number {
    return display.getDefaultDisplaySync().height;
  }

  static get refreshRate(): number {
    return display.getDefaultDisplaySync().refreshRate;
  }

  static get densityPixels(): number {
    return display.getDefaultDisplaySync().densityPixels;
  }

  static get densityDPI(): number {
    return display.getDefaultDisplaySync().densityDPI;
  }

  static get availableWidth(): number {
    return display.getDefaultDisplaySync().availableWidth;
  }

  static get availableHeight(): number {
    return display.getDefaultDisplaySync().availableHeight;
  }

  /** 宽高比，保留两位小数 */
  static get aspectRatio(): string {
    const d: display.Display = display.getDefaultDisplaySync();
    if (d.height === 0) {
      return '未知';
    }
    return (d.width / d.height).toFixed(2);
  }

  /** 支持的 HDR 格式数量 */
  static get hdrFormatCount(): number {
    return display.getDefaultDisplaySync().hdrFormats.length;
  }

  /** 支持的色彩空间数量 */
  static get colorSpaceCount(): number {
    return display.getDefaultDisplaySync().colorSpaces.length;
  }
}

/**
 * 区域与语言。
 */
export class PlatformLocale {
  static get systemLanguage(): string {
    return i18n.System.getSystemLanguage();
  }

  static get systemRegion(): string {
    return i18n.System.getSystemRegion();
  }

  /** 首选语言列表 */
  static get preferredLanguages(): string[] {
    return i18n.System.getPreferredLanguageList();
  }

  static get is24HourClock(): boolean {
    return i18n.System.is24HourClock();
  }

  static get firstDayOfWeek(): number {
    return i18n.System.getFirstDayOfWeek();
  }

  /** 时区标识符，如 Asia/Shanghai */
  static get timeZone(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch (e) {
      return '未知';
    }
  }

  /** 区域设置字符串 */
  static get locale(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().locale;
    } catch (e) {
      return i18n.System.getSystemLanguage();
    }
  }

  /** 日历体系 */
  static get calendar(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().calendar;
    } catch (e) {
      return 'gregory';
    }
  }

  /** 取 IANA 时区的洲/地区部分（"/" 之前），如 Asia/Shanghai → Asia。仅作展示/粗判，不代表国家码。 */
  static get timeZoneRegion(): string {
    const tz: string = PlatformLocale.timeZone;
    const slash: number = tz.indexOf('/');
    if (slash > 0) {
      return tz.substring(0, slash);
    }
    return tz;
  }
}

/**
 * 剪贴板。
 */
export class PlatformPasteboard {
  /**
   * 剪贴板内容变更计数。系统重启后从 0 开始，
   * 重复复制相同内容也计为一次变更。
   */
  static get changeCount(): number {
    try {
      return pasteboard.getSystemPasteboard().getChangeCount();
    } catch (e) {
      return -1;
    }
  }

  /** 是否有任何剪贴板数据 */
  static get hasData(): boolean {
    try {
      return pasteboard.getSystemPasteboard().hasDataSync();
    } catch (e) {
      return false;
    }
  }

  /**
   * 剪贴板当前承载的内容类型。
   * 只读类型不读内容本身，是不会被系统记录的高级信号。
   */
  static async mimeTypesAsync(): Promise<string[]> {
    try {
      return await pasteboard.getSystemPasteboard().getMimeTypes();
    } catch (e) {
      return [];
    }
  }
}

/**
 * 应用上下文。
 *
 * Context 与 Configuration 由 EntryAbility 在启动时写入 AppStorage，
 * Provider 只读这里，不直接持有 Ability 引用。
 */
export class PlatformContext {
  /**
   * 取当前 Ability 的上下文，用于权限申请等需要上下文的地方。
   */
  static abilityContext(): common.UIAbilityContext | undefined {
    return AppStorage.get<common.UIAbilityContext>('abilityContext') as common.UIAbilityContext | undefined;
  }

  /**
   * 供 Provider 读取设备识别信息的沙箱路径。
   */
  static appFilesDir(): string | undefined {
    return AppStorage.get<string>('filesDir') as string | undefined;
  }

  /**
   * 读取系统当前的颜色模式。
   * 由 EntryAbility 从 Configuration 写入，未写入时返回"未知"。
   */
  static colorMode(): string {
    const mode: string = AppStorage.get<string>('colorMode') as string;
    return mode === undefined || mode.length === 0 ? '未知' : mode;
  }

  /**
   * 字体缩放系数，由 EntryAbility 写入。
   */
  static fontScale(): number {
    const scale: number = AppStorage.get<number>('fontSizeScale') as number;
    return scale === undefined ? 1.0 : scale;
  }

  /**
   * 把 colorMode 枚举转成中文文案。由 EntryAbility 调用。
   */
  static colorModeText(mode: ConfigurationConstant.ColorMode | undefined): string {
    if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return '深色';
    }
    if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return '浅色';
    }
    return '跟随系统';
  }
}
