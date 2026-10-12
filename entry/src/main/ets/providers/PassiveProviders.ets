/*
 * PassiveProviders.ets
 * Houpe
 *
 * 被动分类的采集实现：无需任何权限，应用启动后即可读取。
 * 每个 Provider 只调用 PlatformShim 暴露的入口，
 * 采集失败时返回空数组而不是抛异常。
 */

import { deviceInfo, batteryInfo, power, thermal } from '@kit.BasicServicesKit';
import { font } from '@kit.ArkUI';
import { connection } from '@kit.NetworkKit';
import { audio } from '@kit.AudioKit';
import statfs from '@ohos.file.statvfs';
import { FingerprintSignal, SignalEntry, makeSignal, DisplayHint } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { SignalProvider, LiveSignalProvider } from '../models/SignalProvider';
import { PlatformDevice, PlatformScreen, PlatformLocale, PlatformPasteboard, PlatformContext } from '../support/PlatformShim';

/**
 * 把字节数格式化为人类可读的字符串。
 */
export function formatBytes(bytes: number): string {
  if (bytes <= 0) {
    return '未知';
  }
  const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];
  let value: number = bytes;
  let idx: number = 0;
  while (value >= 1024 && idx < units.length - 1) {
    value = value / 1024;
    idx++;
  }
  return `${value.toFixed(2)} ${units[idx]}`;
}

/**
 * 设备标识：厂商分配的硬件与应用身份。
 */
export class DeviceIdentityProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.DEVICE_IDENTITY;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('manufacturer', cat, '设备厂商',
        PlatformDevice.manufacture,
        '厂商名称直接写在设备里。应用不需要申请任何权限就能读到，它能立刻告诉你这是不是华为设备。'));

      out.push(makeSignal('marketName', cat, '市场名称',
        PlatformDevice.readableName,
        '设备的销售名称。它和型号一起，能把一台设备缩小到很小的范围内。'));

      out.push(makeSignal('model', cat, '硬件型号',
        PlatformDevice.productModel,
        '型号代码是硬件的身份证。同型号的设备在识别时会被归为一类，但它能排除掉绝大部分其他设备。'));

      out.push(makeSignal('series', cat, '产品系列',
        PlatformDevice.productSeries,
        '系列与硬件型号组合起来，足以推断出你的大致购机年份和定价档位。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('产品系列', PlatformDevice.productSeries),
          new SignalEntry('硬件型号', PlatformDevice.hardwareModel),
          new SignalEntry('软件型号', PlatformDevice.softwareModel)
        ]));

      out.push(makeSignal('deviceType', cat, '设备类型',
        PlatformDevice.deviceType,
        '手机还是平板，这是最粗糙也最容易读取的一个字段。'));

      out.push(makeSignal('odid', cat, '开放设备标识（ODID）',
        PlatformDevice.odid,
        '这串数字对每个开发者都不一样，同一个开发者的不同应用读到的是同一个。它不需要敏感权限，却足以把你稳定地认出来。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 系统与运行时。
 */
export class SystemInfoProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.SYSTEM_INFO;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('osVersion', cat, '系统版本',
        PlatformDevice.osFullName,
        '完整的系统版本串包含构建号。构建号越新，能匹配到的设备就越少。'));

      out.push(makeSignal('apiVersion', cat, 'SDK API 版本',
        String(PlatformDevice.sdkApiVersion),
        'API 版本暴露应用是为哪个系统版本开发的，用它能推断出你的系统更新进度。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('API 版本', String(PlatformDevice.sdkApiVersion)),
          new SignalEntry('主版本号', String(deviceInfo.majorVersion)),
          new SignalEntry('次版本号', String(deviceInfo.seniorVersion)),
          new SignalEntry('特性版本号', String(deviceInfo.featureVersion)),
          new SignalEntry('构建版本号', String(deviceInfo.buildVersion))
        ]));

      out.push(makeSignal('chip', cat, '芯片与架构',
        PlatformDevice.chipType,
        'CPU 型号是硬件指纹的核心。它和 GPU 型号一起，几乎可以唯一确定一台设备的芯片代际。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('芯片类型', PlatformDevice.chipType),
          new SignalEntry('ABI 列表', PlatformDevice.abiList)
        ]));

      out.push(makeSignal('build', cat, '系统构建信息',
        PlatformDevice.buildType,
        '构建类型与版本标识组合起来，是一个具体的系统镜像指纹。多数普通设备相同，但定制系统各不相同。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('构建类型', PlatformDevice.buildType),
          new SignalEntry('版本标识', deviceInfo.versionId),
          new SignalEntry('安全补丁', PlatformDevice.securityPatchTag)
        ]));

      out.push(makeSignal('bootCount', cat, '开机次数',
        String(PlatformDevice.bootCount),
        '设备累计重启了多少次，是一个几乎不会重复的计数。它不能直接指向你，但能刻画这台设备的"年龄"和稳定性。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 电池与电源。
 */
export class BatteryProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.BATTERY;
  readonly intervalMs: number = 5000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('level', cat, '电量',
        `${batteryInfo.batterySOC}%`,
        '电量变化很慢。应用在你充电前后各读一次，就能用两次读数把你认出来，这是时间域上的指纹。'));

      out.push(makeSignal('state', cat, '充电状态',
        BatteryProvider.chargeStateText(batteryInfo.chargingStatus),
        '正在充电、充满还是没插电。这三个状态能推断出你一天里的大致作息。'));

      out.push(makeSignal('temperature', cat, '电池温度',
        `${(batteryInfo.batteryTemperature / 10).toFixed(1)} °C`,
        '电池温度会因为充电、玩游戏、天气而变化，是一个连续的、几乎不会重复的实时数值。'));

      out.push(makeSignal('plugged', cat, '充电方式',
        BatteryProvider.pluggedText(batteryInfo.pluggedType),
        '交流电、USB 还是无线充电，能看出你用的是哪种充电设备。'));

      out.push(makeSignal('capacity', cat, '电量等级',
        BatteryProvider.capacityText(batteryInfo.batteryCapacityLevel),
        '系统把电量分成几个等级。当电量进入低电区间时，系统行为会变化，这个区间本身就是一个信号。'));

      out.push(makeSignal('powerMode', cat, '电源状态',
        power.isActive() ? '活跃' : '待机',
        '设备是否处于省电模式，反映了你的使用习惯。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('设备活跃', power.isActive() ? '是' : '否'),
          new SignalEntry('电源模式', String(power.getPowerMode())),
          new SignalEntry('是否省电', power.getPowerMode() === 1 ? '是' : '否')
        ]));

      out.push(makeSignal('thermal', cat, '热控等级',
        BatteryProvider.thermalText(thermal.getLevel()),
        '热控等级会告诉你这台设备当前的发热状况。长时间游戏或录像会把它推到更高的档位。'));
    } catch (e) {
    }
    return out;
  }

  private static chargeStateText(s: number): string {
    if (s === 2) {
      return '充电中';
    }
    if (s === 3) {
      return '已充满';
    }
    if (s === 1) {
      return '未充电';
    }
    return '未知';
  }

  private static pluggedText(t: number): string {
    if (t === 1) {
      return '交流电';
    }
    if (t === 2) {
      return 'USB';
    }
    if (t === 3) {
      return '无线充电';
    }
    return '未充电';
  }

  private static capacityText(l: number): string {
    const names: string[] = ['无', '满', '高', '正常', '低', '警告', '危急', '即将关机'];
    return names[l] ?? '未知';
  }

  private static thermalText(l: number): string {
    const names: string[] = ['凉', '正常', '温', '热', '过热', '警戒', '紧急', '危险'];
    return names[l] ?? '未知';
  }
}

/**
 * 存储空间。
 */
export class StorageProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.STORAGE;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const dir: string | undefined = PlatformContext.appFilesDir();
      if (dir === undefined) {
        return out;
      }
      const total: number = statfs.getTotalSizeSync(dir);
      const free: number = statfs.getFreeSizeSync(dir);
      const used: number = total - free;

      out.push(makeSignal('capacity', cat, '卷总容量',
        formatBytes(total),
        '总容量能判断你的机型和购机年份。同型号设备相同，但配合其他字段可以缩小范围。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('总容量', formatBytes(total)),
          new SignalEntry('已使用', formatBytes(used)),
          new SignalEntry('可用', formatBytes(free))
        ]));

      out.push(makeSignal('usage', cat, '已用空间比例',
        `${total > 0 ? ((used / total) * 100).toFixed(1) : '0.0'} %`,
        '使用比例比"已用多少 G"更能刻画你。装满 256G 和装到 64G 的两台同款设备，靠这个比例就能分开。'));

      out.push(makeSignal('freeSpace', cat, '可用空间',
        formatBytes(free),
        '可用空间的变化很慢。应用记录你两次启动之间的差值，就能推断出这段时间你拍了多少照片。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 屏幕与显示。
 */
export class DisplayProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.DISPLAY;
  readonly intervalMs: number = 1000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('resolution', cat, '物理分辨率',
        PlatformScreen.nativeBounds,
        '物理像素尺寸加上屏幕比例，能推断出你的机型档位。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('物理宽度', `${PlatformScreen.pixelWidth} px`),
          new SignalEntry('物理高度', `${PlatformScreen.pixelHeight} px`),
          new SignalEntry('可用宽度', `${PlatformScreen.availableWidth} px`),
          new SignalEntry('可用高度', `${PlatformScreen.availableHeight} px`)
        ]));

      out.push(makeSignal('density', cat, '屏幕密度',
        `${PlatformScreen.densityPixels} (${PlatformScreen.densityDPI} DPI)`,
        '逻辑密度系数决定了界面看起来多大。不同机型的密度值往往不同。'));

      out.push(makeSignal('refreshRate', cat, '刷新率上限',
        `${PlatformScreen.refreshRate} Hz`,
        '高刷新率屏幕是近年新机的特征。它把你的设备限制在很小的范围内。'));

      out.push(makeSignal('aspectRatio', cat, '宽高比与色彩能力',
        PlatformScreen.aspectRatio,
        '宽高比加上分辨率，基本就能反推出具体机型。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('宽高比', PlatformScreen.aspectRatio),
          new SignalEntry('色彩空间数', String(PlatformScreen.colorSpaceCount)),
          new SignalEntry('HDR 格式数', String(PlatformScreen.hdrFormatCount))
        ]));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 区域与语言。
 */
export class LocaleProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.LOCALE;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      out.push(makeSignal('region', cat, '系统区域',
        PlatformLocale.systemRegion,
        '区域设置直接写在系统里。用代理软件也改不了它，因为很多应用读的是这个值而不是网络位置。'));

      out.push(makeSignal('language', cat, '系统语言',
        PlatformLocale.systemLanguage,
        '系统语言是少数几个低熵字段之一。中文用户占了很大比例，所以单独看区分度不高。'));

      out.push(makeSignal('preferred', cat, '首选语言列表',
        PlatformLocale.preferredLanguages.join('、'),
        '首选语言是一个列表，顺序有含义。装了几种语言的用户，列表组合起来就有区分度了。',
        DisplayHint.TAGS,
        PlatformLocale.preferredLanguages.map((l: string, i: number) => new SignalEntry(`${i + 1}`, l))));

      out.push(makeSignal('timeZone', cat, '时区',
        PlatformLocale.timeZone,
        '时区暴露你当前在哪。系统可以手动改，但大多数人没改过，真实度很高。'));

      out.push(makeSignal('clock', cat, '时钟制式与周起始日',
        `${PlatformLocale.is24HourClock ? '24 小时制' : '12 小时制'} / 周起始于${PlatformLocale.firstDayOfWeek}`,
        '时钟制式与一周从哪天开始，是地区习惯的直接体现，组合起来可以区分出不同文化圈的用户。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('时钟制式', PlatformLocale.is24HourClock ? '24 小时制' : '12 小时制'),
          new SignalEntry('周起始日', String(PlatformLocale.firstDayOfWeek)),
          new SignalEntry('日历体系', PlatformLocale.calendar),
          new SignalEntry('区域设置', PlatformLocale.locale)
        ]));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 剪贴板。
 */
export class PasteboardProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.PASTEBOARD;
  readonly intervalMs: number = 2000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const count: number = PlatformPasteboard.changeCount;
      out.push(makeSignal('changeCount', cat, '剪贴板变更次数',
        count >= 0 ? `${count} 次` : '不可用',
        '每一次复制或剪切都会让这个数字加一，它对所有应用都可见。系统重启后归零，所以它反映的是本次开机以来你的复制次数。'));

      out.push(makeSignal('hasData', cat, '剪贴板是否有内容',
        PlatformPasteboard.hasData ? '有' : '无',
        '判断剪贴板是否为空不需要读内容，因此不会打扰你。只要读一下这个标记，你就知道刚才有没有复制东西。'));

      const types: string[] = await PlatformPasteboard.mimeTypesAsync();
      out.push(makeSignal('types', cat, '内容类型',
        types.length > 0 ? types.join('、') : '空',
        '剪贴板里放的是文字、链接还是图片，这本身就是一种意图信号。只读类型不读内容，系统不会记录你。',
        DisplayHint.TAGS,
        types.map((t: string) => new SignalEntry('类型', t))));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 网络接口。
 */
export class NetworkProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.NETWORK;
  readonly intervalMs: number = 5000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const net: connection.NetHandle = connection.getDefaultNetSync();
      const props: connection.ConnectionProperties = connection.getConnectionPropertiesSync(net);
      const caps: connection.NetCapabilities = connection.getNetCapabilitiesSync(net);

      const bearers: string[] = caps.bearerTypes.map((b: connection.NetBearType) => NetworkProvider.bearerText(b));
      out.push(makeSignal('bearer', cat, '连接类型',
        bearers.length > 0 ? bearers.join('、') : '未知',
        '当前是 Wi-Fi、蜂窝还是以太网。蜂窝连接说明你不在固定场所，这在统计用户分布时是个有用信号。',
        DisplayHint.TAGS,
        bearers.map((b: string) => new SignalEntry('类型', b))));

      out.push(makeSignal('interface', cat, '网卡接口名',
        props.interfaceName,
        '接口名暴露了系统内部的网络命名方式。连同时用了虚拟网卡，名字里会出现对应痕迹。'));

      out.push(makeSignal('addresses', cat, '本地 IP 地址',
        props.linkAddresses.length > 0 ?
          props.linkAddresses.map((a: connection.LinkAddress) => a.address.address).join('、') : '未获取',
        '本地 IP 在同一个网络里往往唯一。用它可以把不同设备区分开，即便你不告诉任何人你的名字。',
        DisplayHint.KEY_VALUE,
        props.linkAddresses.map((a: connection.LinkAddress) =>
          new SignalEntry(a.address.address, `前缀长度 ${a.prefixLength}`))));

      const dns: string[] = props.dnses.map((d: connection.NetAddress) => d.address);
      out.push(makeSignal('dns', cat, 'DNS 服务器',
        dns.length > 0 ? dns.join('、') : '未获取',
        '你用的 DNS 服务器往往能暴露你的运营商、是否用了广告过滤，或者你用的是公共 DNS。'));

      out.push(makeSignal('mtu', cat, 'MTU 与带宽',
        `MTU ${props.mtu}`,
        'MTU 值能反映你走的是以太网、Wi-Fi 还是隧道。虚拟网络的 MTU 往往和物理网络不同。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('MTU', String(props.mtu)),
          new SignalEntry('上行带宽', caps.linkUpBandwidthKbps !== undefined ?
            `${caps.linkUpBandwidthKbps} Kbps` : '未知'),
          new SignalEntry('下行带宽', caps.linkDownBandwidthKbps !== undefined ?
            `${caps.linkDownBandwidthKbps} Kbps` : '未知')
        ]));
    } catch (e) {
    }
    return out;
  }

  private static bearerText(b: number): string {
    if (b === 0) {
      return '蜂窝网络';
    }
    if (b === 1) {
      return 'Wi-Fi';
    }
    if (b === 2) {
      return '蓝牙';
    }
    if (b === 3) {
      return '以太网';
    }
    if (b === 4) {
      return 'VPN';
    }
    return '未知';
  }
}

/**
 * 系统字体。
 */
export class FontsProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.FONTS;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const list: string[] = font.getSystemFontList();
      out.push(makeSignal('count', cat, '系统字体数量',
        `${list.length} 个`,
        '字体数量在同型号设备上是一致的。但只要你额外装过字体，数量就会变，应用一比就知道。'));

      if (list.length > 0) {
        const shown: string[] = list.slice(0, Math.min(list.length, 30));
        out.push(makeSignal('list', cat, '字体列表',
          shown.join('、') + (list.length > shown.length ? ' …' : ''),
          '完整字体清单是一项很强的识别依据。同型号设备相同，但装过第三方字体的用户会立刻不同。',
          DisplayHint.TAGS,
          shown.map((f: string) => new SignalEntry('字体', f))));
      } else {
        out.push(makeSignal('unavailable', cat, '字体列表',
          '本机未提供',
          '在手机与平板上，系统不向普通应用开放完整字体清单。这本身就是一条信息：说明这个字段被系统刻意隐藏了。'));
      }
    } catch (e) {
    }
    return out;
  }
}

/**
 * 音频设备。
 */
export class AudioRouteProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.AUDIO_ROUTE;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const outputs: audio.AudioDeviceDescriptors =
        audio.getAudioManager().getRoutingManager().getDevicesSync(audio.DeviceFlag.OUTPUT_DEVICES_FLAG);
      const inputs: audio.AudioDeviceDescriptors =
        audio.getAudioManager().getRoutingManager().getDevicesSync(audio.DeviceFlag.INPUT_DEVICES_FLAG);

      out.push(makeSignal('outputs', cat, '音频输出设备',
        outputs.length > 0 ? outputs.map((d: audio.AudioDeviceDescriptor) => d.name).join('、') : '未知',
        '你现在接的是哪副耳机，有时连名字都带着主人的信息。蓝牙耳机命名成自己名字是很常见的情况。',
        DisplayHint.KEY_VALUE,
        outputs.map((d: audio.AudioDeviceDescriptor) =>
          new SignalEntry(d.name, AudioRouteProvider.deviceTypeText(d.deviceType)))));

      out.push(makeSignal('inputs', cat, '音频输入设备',
        inputs.length > 0 ? inputs.map((d: audio.AudioDeviceDescriptor) => d.name).join('、') : '未知',
        '输入设备清单能告诉你这台设备配了麦克风还是线性耳机。'));

      out.push(makeSignal('count', cat, '设备数量',
        `输出 ${outputs.length} 个 / 输入 ${inputs.length} 个`,
        '可用的音频设备数量能反映你平时怎么听声音：只有手机扬声器，还是常备外放。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('输出设备数', String(outputs.length)),
          new SignalEntry('输入设备数', String(inputs.length))
        ]));
    } catch (e) {
    }
    return out;
  }

  private static deviceTypeText(t: number): string {
    const names: string[] = ['未知', '内置扬声器', '内置听筒', '有线耳机', '蓝牙设备',
      '内置麦克风', '外接麦克风', 'HDMI', 'USB 设备', '其他'];
    return names[t] ?? '其他';
  }
}
