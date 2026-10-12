/*
 * Sensitivity.ets
 * Houpe
 *
 * 采集侵入程度的分档。整个 App 的教育价值都建立在这三档上：
 * passive 任何应用都能静默读到、permissioned 首次会弹窗、advanced
 * 用公开 API 做巧妙的侧信道。
 */

import { AppSymbols } from '../common/AppSymbols';
import { Theme } from '../common/Theme';

/**
 * 敏感度分档。
 */
export enum Sensitivity {
  /** 被动：无需任何弹窗即可读取 */
  PASSIVE = 'passive',
  /** 需授权：首次访问触发系统权限弹窗 */
  PERMISSIONED = 'permissioned',
  /** 高阶：巧妙利用公开 API 提取本不该暴露的细节 */
  ADVANCED = 'advanced'
}

/** 分档的展示顺序，首页按此顺序分组。 */
export const SENSITIVITY_ORDER: Sensitivity[] = [
  Sensitivity.PASSIVE,
  Sensitivity.PERMISSIONED,
  Sensitivity.ADVANCED
];

/**
 * 分档元数据。
 */
export class SensitivityInfo {
  sensitivity: Sensitivity;
  title: string;
  shortTitle: string;
  blurb: string;
  symbol: Resource;
  tint: string;

  constructor(sensitivity: Sensitivity, title: string, shortTitle: string, blurb: string,
    symbol: Resource, tint: string) {
    this.sensitivity = sensitivity;
    this.title = title;
    this.shortTitle = shortTitle;
    this.blurb = blurb;
    this.symbol = symbol;
    this.tint = tint;
  }
}

/**
 * 分档元数据表。文案语气与 iOS 原版一致：冷静、第二人称、陈述事实。
 */
const TABLE: Map<string, SensitivityInfo> = new Map<string, SensitivityInfo>([
  [Sensitivity.PASSIVE, new SensitivityInfo(
    Sensitivity.PASSIVE,
    '被动读取',
    '被动',
    '你手机上的任何应用都能读到这些数据。没有任何弹窗，也没有任何东西需要你查看或确认。',
    AppSymbols.PASSIVE,
    Theme.PASSIVE
  )],
  [Sensitivity.PERMISSIONED, new SensitivityInfo(
    Sensitivity.PERMISSIONED,
    '需要授权',
    '需授权',
    'HarmonyOS 会在应用第一次请求时弹出权限提示；个别分类改用系统选择器，由你亲手选中即可。',
    AppSymbols.PERMISSIONED,
    Theme.PERMISSIONED
  )],
  [Sensitivity.ADVANCED, new SensitivityInfo(
    Sensitivity.ADVANCED,
    '高阶技巧',
    '高阶',
    '用公开 API 巧妙提取出比设计意图更多的细节。',
    AppSymbols.ADVANCED,
    Theme.ADVANCED
  )]
]);

const FALLBACK: SensitivityInfo = new SensitivityInfo(
  Sensitivity.PASSIVE, '被动读取', '被动', '', AppSymbols.PASSIVE, Theme.PASSIVE
);

/**
 * 取分档元数据。
 */
export function sensitivityInfo(s: Sensitivity): SensitivityInfo {
  const info: SensitivityInfo | undefined = TABLE.get(s as string);
  return info ?? FALLBACK;
}
