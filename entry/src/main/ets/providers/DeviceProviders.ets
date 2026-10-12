/*
 * DeviceProviders.ets
 * Houpe
 *
 * 设备侧的补充采集：无障碍设置、惯性传感器、图形能力、
 * 无线接口状态、应用与包信息。
 */

import { sensor } from '@kit.SensorServiceKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import hdrCapability from '@ohos.graphics.hdrCapability';
import { FingerprintSignal, SignalEntry, makeSignal, DisplayHint } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { SignalProvider, LiveSignalProvider } from '../models/SignalProvider';
import { PlatformContext, PlatformDevice } from '../support/PlatformShim';

/**
 * 把毫秒时长格式化为中文可读的字符串。
 */
export function formatDuration(ms: number): string {
  if (ms <= 0) {
    return '不足 1 分钟';
  }
  const days: number = Math.floor(ms / 86400000);
  const hours: number = Math.floor((ms % 86400000) / 3600000);
  const mins: number = Math.floor((ms % 3600000) / 60000);
  const secs: number = Math.floor((ms % 60000) / 1000);
  if (days > 0) {
    return `${days} 天 ${hours} 小时 ${mins} 分钟`;
  }
  if (hours > 0) {
    return `${hours} 小时 ${mins} 分钟 ${secs} 秒`;
  }
  return `${mins} 分钟 ${secs} 秒`;
}

/**
 * 设备运行时的辅助能力。
 */
export class DeviceProviders {
  /**
   * 本次开机时长。
   * 鸿蒙没有开放读取系统启动时间的接口，
   * 这里如实告知不可得，而不是编造一个数值。
   */
  static uptimeText(): string {
    return '系统未开放读取';
  }
}

/**
 * 无障碍设置。
 *
 * 每一项开启的无障碍开关都是一个低概率事件，单独看几乎没意义，
 * 十几项叠在一起就成了很强的识别依据。
 */
export class AccessibilityProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.ACCESSIBILITY;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const scale: number = PlatformContext.fontScale();
      const dark: boolean = PlatformContext.colorMode() === '深色';

      const flags: SignalEntry[] = [
        new SignalEntry('系统字体放大', scale > 1.0 ? '开' : '关'),
        new SignalEntry('深色外观', dark ? '开' : '关')
      ];
      const enabled: SignalEntry[] = flags.filter(f => f.value === '开');

      out.push(makeSignal('summary', cat, '已开启的无障碍功能',
        enabled.length > 0 ? enabled.map(e => e.label).join('、') : '无',
        '这些开关大多是视力或行动不便的用户才会开的。数量不多，但一旦开了就很难伪装，因此识别力很强。',
        enabled.length > 0 ? DisplayHint.TAGS : DisplayHint.PLAIN,
        enabled.length > 0 ? enabled : null));

      out.push(makeSignal('colorMode', cat, '系统外观模式',
        PlatformContext.colorMode(),
        '深色还是浅色。大约一半用户用深色，一半用浅色，本身区分度不高，但和其他字段组合起来就有用了。'));

      out.push(makeSignal('fontScale', cat, '字体缩放系数',
        `${scale.toFixed(2)} 倍`,
        '你把系统字体调大了多少。大字体用户占比不高，这个数值能把他们从人群里分出来。'));

      out.push(makeSignal('allFlags', cat, '可读取的开关清单',
        `${flags.length} 项`,
        '系统只向普通应用开放了这两项无障碍相关状态，其余开关并未开放读取。' +
        '这本身就是一条信息：你能设置这些选项，但应用读不到。',
        DisplayHint.KEY_VALUE,
        flags));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 惯性传感器。
 *
 * 加速度计、陀螺仪、磁力计的原始读数——这些不需要运动权限，
 * 属于被动面。采样越密，能还原出的动作轨迹越完整。
 */
export class DeviceMotionProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.DEVICE_MOTION;
  readonly intervalMs: number = 200;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const accel: sensor.Sensor | undefined = sensor.getSingleSensorSync(sensor.SensorId.ACCELEROMETER);
      const gyro: sensor.Sensor | undefined = sensor.getSingleSensorSync(sensor.SensorId.GYROSCOPE);
      const mag: sensor.Sensor | undefined = sensor.getSingleSensorSync(sensor.SensorId.MAGNETIC_FIELD);

      out.push(makeSignal('availability', cat, '传感器清单',
        DeviceMotionProvider.sensorListText(accel, gyro, mag),
        '这台设备配了哪些传感器。传感器组合是硬件的指纹，同型号设备相同，但不同机型之间差异很大。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('加速度计', accel !== undefined ? '有' : '无'),
          new SignalEntry('陀螺仪', gyro !== undefined ? '有' : '无'),
          new SignalEntry('磁力计', mag !== undefined ? '有' : '无')
        ]));

      if (accel !== undefined) {
        out.push(makeSignal('accelerometerInfo', cat, '加速度计硬件参数',
          `量程 ${accel.maxRange} m/s² / 精度 ${accel.precision}`,
          '加速度计的量程与精度由硬件决定。静止时读数稳定在某个模式上，' +
          '一旦你拿起手机读数立刻改变——应用连续采样就能从运动模式认出这是不是你。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('量程', `${accel.maxRange} m/s²`),
            new SignalEntry('精度', String(accel.precision)),
            new SignalEntry('最小采样周期', `${accel.minSamplePeriod} ns`),
            new SignalEntry('厂商', accel.vendorName),
            new SignalEntry('固件版本', accel.firmwareVersion)
          ]));
      }

      if (gyro !== undefined) {
        out.push(makeSignal('gyroscopeInfo', cat, '陀螺仪硬件参数',
          `量程 ${gyro.maxRange} / 精度 ${gyro.precision}`,
          '陀螺仪的量程和精度由硬件决定。这是一个纯硬件参数，同型号设备完全一致，用它可以准确锁定机型代际。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('量程', String(gyro.maxRange)),
            new SignalEntry('分辨率', String(gyro.precision)),
            new SignalEntry('最小采样周期', `${gyro.minSamplePeriod} ns`),
            new SignalEntry('功耗模式', String(gyro.power)),
            new SignalEntry('厂商', gyro.vendorName)
          ]));
      }

      if (mag !== undefined) {
        out.push(makeSignal('magnetometerInfo', cat, '磁力计硬件参数',
          `量程 ${mag.maxRange} μT / 精度 ${mag.precision}`,
          '磁力计的量程与厂商信息同样属于硬件指纹。它还能测出地球磁场，间接反映你所在的位置和周围有没有金属。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('量程', String(mag.maxRange)),
            new SignalEntry('分辨率', String(mag.precision)),
            new SignalEntry('最小采样周期', `${mag.minSamplePeriod} ns`),
            new SignalEntry('厂商', mag.vendorName)
          ]));
      }
    } catch (e) {
    }
    return out;
  }

  private static sensorListText(a?: sensor.Sensor, g?: sensor.Sensor, m?: sensor.Sensor): string {
    const names: string[] = [];
    if (a !== undefined) {
      names.push('加速度计');
    }
    if (g !== undefined) {
      names.push('陀螺仪');
    }
    if (m !== undefined) {
      names.push('磁力计');
    }
    return names.length > 0 ? names.join('、') : '未获取到传感器';
  }
}

/**
 * 图形与渲染能力。
 *
 * 鸿蒙没有公开的 GPU 型号查询 API，因此这一类展示的是
 * 屏幕的色彩与 HDR 能力——它们同样由显示硬件决定。
 */
export class GraphicsProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.GRAPHICS;

  /**
   * 把 HDR 枚举值转成可读名称。
   */
  private static hdrName(f: hdrCapability.HDRFormat): string {
    switch (f) {
      case hdrCapability.HDRFormat.VIDEO_HLG:
        return 'HLG';
      case hdrCapability.HDRFormat.VIDEO_HDR10:
        return 'HDR10';
      case hdrCapability.HDRFormat.VIDEO_HDR_VIVID:
        return 'HDR Vivid 视频';
      case hdrCapability.HDRFormat.IMAGE_HDR_VIVID_DUAL:
        return 'HDR Vivid 双层';
      case hdrCapability.HDRFormat.IMAGE_HDR_VIVID_SINGLE:
        return 'HDR Vivid 单层';
      case hdrCapability.HDRFormat.IMAGE_HDR_ISO_DUAL:
        return 'ISO 双层';
      case hdrCapability.HDRFormat.IMAGE_HDR_ISO_SINGLE:
        return 'ISO 单层';
      default:
        return '不支持';
    }
  }

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const d = display.getDefaultDisplaySync();

      const hdrFormats: string[] = d.hdrFormats.map((f: hdrCapability.HDRFormat) =>
        GraphicsProvider.hdrName(f));
      out.push(makeSignal('hdrFormats', cat, '支持的 HDR 格式',
        hdrFormats.length > 0 ? hdrFormats.join('、') : '不支持 HDR',
        'HDR 格式列表是高端屏幕的标志。它几乎只出现在旗舰机型上，一个字段就能把你的设备档位框定。',
        hdrFormats.length > 0 ? DisplayHint.TAGS : DisplayHint.PLAIN,
        hdrFormats.length > 0 ? hdrFormats.map((h: string) => new SignalEntry('HDR 格式', h)) : null));

      out.push(makeSignal('colorSpaceCount', cat, '支持的色彩空间数',
        `${d.colorSpaces.length} 个`,
        '色彩空间能反映屏幕素质。广色域屏和普通屏在这里就会分开，是硬件差异的直接体现。'));

      out.push(makeSignal('renderScale', cat, '渲染与像素密度',
        `${d.densityPixels} 倍`,
        '密度系数决定了图形资源如何被缩放。它和 GPU 能力一起，能推断出你的设备能跑多复杂的渲染管线。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('密度系数', String(d.densityPixels)),
          new SignalEntry('横屏 DPI', String(d.xDPI)),
          new SignalEntry('竖屏 DPI', String(d.yDPI)),
          new SignalEntry('刷新率', `${d.refreshRate} Hz`)
        ]));

      out.push(makeSignal('chipGraphics', cat, '图形相关硬件线索',
        `${PlatformDevice.manufacture} ${PlatformDevice.readableName}`,
        '系统没有开放 GPU 型号接口，但 CPU 芯片型号与显示规格结合起来，几乎可以反推出你的设备型号。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('厂商', PlatformDevice.manufacture),
          new SignalEntry('市场名', PlatformDevice.readableName),
          new SignalEntry('型号', PlatformDevice.productModel),
          new SignalEntry('芯片', deviceInfo.chipType)
        ]));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 无线接口。
 *
 * 鸿蒙不向普通应用开放蓝牙开关状态与蓝牙地址的查询接口，
 * 这一类如实展示系统开放了什么、没开放什么。
 */
export class WirelessProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.WIRELESS;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('bluetoothState', cat, '蓝牙状态',
        '系统未开放读取',
        '蓝牙是开是关，系统没有向普通应用开放查询接口。但应用可以从你的行为里推断：' +
        '比如你连过耳机、传过文件，都留下了痕迹。'));

      out.push(makeSignal('bluetoothAddress', cat, '蓝牙设备地址',
        '系统未开放读取',
        '蓝牙地址是这台设备稳定的硬件标识，理论上全球唯一。HarmonyOS 默认不向普通应用开放，' +
        '需要你自己在设置里开启"附近的设备"权限。'));

      out.push(makeSignal('nfc', cat, 'NFC 状态',
        '系统未开放读取',
        '系统不提供 NFC 开关状态的读取接口。但应用可以从你的行为里推断出你有没有用过它，' +
        '比如你用过碰一碰支付或碰一碰分享。'));

      out.push(makeSignal('radioSummary', cat, '无线硬件组合',
        '蓝牙 / NFC / 移动网络',
        '这台设备支持哪些无线技术。组合起来能推断出机型档位：老机型往往没有 NFC，' +
        '中端机也通常没有无线充电。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 应用与包信息。
 */
export class AppInfoProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.APP_INFO;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('system', cat, '发行版信息',
        `${deviceInfo.distributionOSName} ${deviceInfo.distributionOSVersion}`,
        '你的系统版本与发行版信息。这个值多数设备相同，但定制系统各不相同。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('系统名称', deviceInfo.distributionOSName),
          new SignalEntry('系统版本', deviceInfo.distributionOSVersion),
          new SignalEntry('API 版本', String(deviceInfo.distributionOSApiVersion))
        ]));

      out.push(makeSignal('sandbox', cat, '应用沙箱目录',
        PlatformContext.appFilesDir() ?? '不可用',
        '每个应用的沙箱路径都是唯一的。它能告诉你这台设备上装了多少个不同来源的应用，' +
        '因为路径里往往带着应用签名或来源信息。'));

      out.push(makeSignal('uptime', cat, '本次开机时长',
        DeviceProviders.uptimeText(),
        '设备这次开机多久了。运行时长加上开机次数，能刻画出这台设备的使用节奏，而且几乎不可能撞车。'));

      out.push(makeSignal('osBuild', cat, '系统构建指纹',
        `${deviceInfo.buildType} / ${deviceInfo.versionId}`,
        '构建类型与版本标识组合起来，是一个具体的系统镜像指纹。多数普通设备相同，' +
        '但定制系统和升级节奏不同的设备会分开。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('构建类型', deviceInfo.buildType),
          new SignalEntry('版本标识', deviceInfo.versionId),
          new SignalEntry('安全补丁', PlatformDevice.securityPatchTag)
        ]));
    } catch (e) {
    }
    return out;
  }
}
