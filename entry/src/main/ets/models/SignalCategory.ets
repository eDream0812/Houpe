/*
 * SignalCategory.ets
 * Houpe
 *
 * 可采集隐私面的权威清单。每个 Provider 对应一个分类，
 * 首页按本枚举的声明顺序展示。
 *
 * 与 iOS 原版的差异：iOS 30 个分类里有一部分依赖 CoreTelephony、
 * AVSpeechSynthesisVoice、EventKit、MediaPlayer、iCloud 等 iOS 专属框架，
 * 鸿蒙没有等价 API。按"只保留鸿蒙有等价 API 的分类"的原则，
 * 这些分类不收录——首页出现的每一个分类、每一个信号，
 * 都是应用真能从 HarmonyOS 读到的真实值。
 */

import { PermissionKind } from './PermissionKind';
import { Sensitivity } from './Sensitivity';
import { AppSymbols } from '../common/AppSymbols';

export enum SignalCategory {
  /** 设备标识 */
  DEVICE_IDENTITY = 'deviceIdentity',
  /** 系统与运行时 */
  SYSTEM_INFO = 'systemInfo',
  /** 电池与电源 */
  BATTERY = 'battery',
  /** 存储容量 */
  STORAGE = 'storage',
  /** 屏幕与显示 */
  DISPLAY = 'display',
  /** 音频设备与路由 */
  AUDIO_ROUTE = 'audioRoute',
  /** 区域与语言 */
  LOCALE = 'locale',
  /** 无障碍设置 */
  ACCESSIBILITY = 'accessibility',
  /** 惯性传感器 */
  DEVICE_MOTION = 'deviceMotion',
  /** 硬件接口与网络 */
  NETWORK = 'network',
  /** 系统字体 */
  FONTS = 'fonts',
  /** 应用与包信息 */
  APP_INFO = 'appInfo',
  /** 剪贴板 */
  PASTEBOARD = 'pasteboard',
  /** 图形与渲染能力 */
  GRAPHICS = 'graphics',
  /** 无线接口 */
  WIRELESS = 'wireless',
  /** 运动与计步（需授权） */
  MOTION = 'motion',
  /** 位置（需授权） */
  LOCATION = 'location',
  /** 摄像头（需授权） */
  CAMERA = 'camera',
  /** 麦克风（需授权） */
  MICROPHONE = 'microphone',
  /** 媒体库（需授权） */
  MEDIA = 'media',
  /** 已安装应用（需授权） */
  INSTALLED_APPS = 'installedApps',
  /** 网页视图指纹（高阶技巧：在隐藏网页里读取浏览器侧标识） */
  WEBVIEW = 'webview'
}

/** 分类元数据。 */
export class CategoryInfo {
  id: SignalCategory;
  title: string;
  subtitle: string;
  symbol: Resource;
  sensitivity: Sensitivity;
  permission: PermissionKind | null;

  constructor(id: SignalCategory, title: string, subtitle: string, symbol: Resource,
    sensitivity: Sensitivity, permission: PermissionKind | null) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.symbol = symbol;
    this.sensitivity = sensitivity;
    this.permission = permission;
  }
}

/**
 * 全部分类的元数据表。顺序即首页显示顺序。
 */
const TABLE: CategoryInfo[] = [
  new CategoryInfo(SignalCategory.DEVICE_IDENTITY, '设备标识',
    '厂商分配的硬件标识与应用身份', AppSymbols.DEVICE,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.SYSTEM_INFO, '系统与运行时',
    '内核、方舟运行时与系统版本', AppSymbols.SYSTEM,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.BATTERY, '电池与电源',
    '电量、充电状态与温控状态', AppSymbols.BATTERY,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.STORAGE, '存储空间',
    '卷容量与可用空间元数据', AppSymbols.STORAGE,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.DISPLAY, '屏幕与显示',
    '屏幕规格与渲染能力', AppSymbols.DISPLAY,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.AUDIO_ROUTE, '音频设备',
    '音频输入输出路由与采样参数', AppSymbols.AUDIO,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.LOCALE, '区域与语言',
    '语言、区域与时间设置', AppSymbols.LOCALE,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.ACCESSIBILITY, '无障碍设置',
    '系统无障碍开关状态', AppSymbols.ACCESSIBILITY,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.DEVICE_MOTION, '惯性传感器',
    '加速度计、陀螺仪与磁力计', AppSymbols.SENSOR,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.NETWORK, '网络接口',
    '网络接口、地址与连接类型', AppSymbols.NETWORK,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.FONTS, '系统字体',
    '设备上可用的字体族', AppSymbols.FONTS,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.APP_INFO, '应用与包信息',
    '应用构建版本与首次安装时间', AppSymbols.APP_INFO,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.PASTEBOARD, '剪贴板',
    '剪贴板活动次数与内容类型', AppSymbols.PASTEBOARD,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.GRAPHICS, '图形与渲染',
    'GPU 型号与图形能力', AppSymbols.GRAPHICS,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.WIRELESS, '无线接口',
    '蓝牙与 NFC 硬件状态', AppSymbols.WIRELESS,
    Sensitivity.PASSIVE, null),
  new CategoryInfo(SignalCategory.MOTION, '运动与计步',
    '活动类型、步数与海拔', AppSymbols.MOTION,
    Sensitivity.PERMISSIONED, PermissionKind.MOTION),
  new CategoryInfo(SignalCategory.LOCATION, '位置',
    '坐标与移动数据', AppSymbols.LOCATION,
    Sensitivity.PERMISSIONED, PermissionKind.LOCATION),
  new CategoryInfo(SignalCategory.CAMERA, '摄像头',
    '摄像头数量与硬件能力', AppSymbols.CAMERA,
    Sensitivity.PERMISSIONED, PermissionKind.CAMERA),
  new CategoryInfo(SignalCategory.MICROPHONE, '麦克风',
    '音频输入设备与采样能力', AppSymbols.MICROPHONE,
    Sensitivity.PERMISSIONED, PermissionKind.MICROPHONE),
  // 不再申请 READ_IMAGEVIDEO / READ_AUDIO：改用系统 Picker，由用户亲手选中。
  // 仍留在「需要授权」档，与其余媒体类读数同档；
  // permission 为 null 意味着不弹权限框，首页点进去直达详情页，用按钮唤起选择器。
  new CategoryInfo(SignalCategory.MEDIA, '媒体选择器',
    '你亲手选中的文件暴露了什么', AppSymbols.MEDIA,
    Sensitivity.PERMISSIONED, null),
  new CategoryInfo(SignalCategory.INSTALLED_APPS, '已安装应用探测',
    '查询你装了哪些应用', AppSymbols.INSTALLED_APPS,
    Sensitivity.PERMISSIONED, PermissionKind.BUNDLE),
  new CategoryInfo(SignalCategory.WEBVIEW, '网页视图指纹',
    '在隐藏网页里读到的浏览器侧标识', AppSymbols.WEBVIEW,
    Sensitivity.ADVANCED, null)
];

/** 顺序表，首页按此顺序遍历。 */
export const CATEGORY_ORDER: SignalCategory[] = TABLE.map(c => c.id);

const MAP: Map<string, CategoryInfo> = new Map(TABLE.map(c => [c.id as string, c]));

/**
 * 取分类元数据。未知 id 返回 null。
 */
export function categoryInfo(id: SignalCategory): CategoryInfo | null {
  return MAP.get(id as string) ?? null;
}

/**
 * 取某分档下的全部分类，按声明顺序。
 */
export function categoriesFor(s: Sensitivity): SignalCategory[] {
  return CATEGORY_ORDER.filter(id => {
    const info = categoryInfo(id);
    return info !== null && info.sensitivity === s;
  });
}

/**
 * 分类总数。
 */
export const CATEGORY_COUNT: number = CATEGORY_ORDER.length;
