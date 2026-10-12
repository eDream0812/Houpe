/*
 * OnboardingContent.ets
 * Houpe
 *
 * 引导页内容。共六页，结构与 iOS 原版一致：
 * 欢迎 → 什么是指纹 → 你的数据长什么样 → 已装应用 → 三档分层 → 一切留在本地。
 */

import { AppSymbols } from '../common/AppSymbols';
import { Theme } from '../common/Theme';

/**
 * 单页的展示形态。
 */
export enum PageKind {
  /** 图标 + 标题 + 正文 */
  STANDARD = 'standard',
  /** 洞察卡片列表 */
  HIGHLIGHTS = 'highlights',
  /** 三档分层说明 */
  TIERS = 'tiers',
  /** 应用推断卡片 */
  APPS = 'apps'
}

/**
 * 一个引导页的模型。
 */
export class OnboardingPage {
  id: string;
  kind: PageKind;
  /** 顶部图标，为空则不显示 */
  symbol: Resource | null;
  title: string;
  body: string;

  constructor(id: string, kind: PageKind, symbol: Resource | null, title: string, body: string) {
    this.id = id;
    this.kind = kind;
    this.symbol = symbol;
    this.title = title;
    this.body = body;
  }
}

/**
 * 分档说明卡片的数据。
 */
export class TierCard {
  symbol: Resource;
  title: string;
  tint: string;
  body: string;

  constructor(symbol: Resource, title: string, tint: string, body: string) {
    this.symbol = symbol;
    this.title = title;
    this.tint = tint;
    this.body = body;
  }
}

/**
 * 引导页内容表。
 */
export class OnboardingContent {
  static readonly PAGES: OnboardingPage[] = [
    new OnboardingPage('welcome', PageKind.STANDARD, AppSymbols.ADVANCED_ALT,
      '欢迎使用 Houpe',
      '追踪你的应用不需要你的名字、邮箱，也不需要知道你在哪里。' +
      '它们只要读一读你手机上早就公开的那些设置，就足以把你认出来。'),

    new OnboardingPage('fingerprinting', PageKind.STANDARD, AppSymbols.PASSIVE,
      '什么是设备指纹',
      '每一条读数单看都不算什么，比如语言是中文、电量是 68%。' +
      '但把它们全部组合起来，就形成了一个跟着你穿过各个应用与网站的指纹。'),

    new OnboardingPage('highlights', PageKind.HIGHLIGHTS, null,
      '你的应用能读到什么',
      '下面这些都是应用可以拿到的信息。单独一条并不独特，' +
      '但组合起来足以把你认出来。'),

    new OnboardingPage('apps', PageKind.APPS, null,
      '你装的应用也在说话',
      '应用可以查询你装了哪些第三方应用。装了什么，' +
      '往往比任何一份填过的表单都更能说明你是谁、你在意什么。'),

    new OnboardingPage('tiers', PageKind.TIERS, null,
      'Houpe 把所有数据放在一起',
      '有的数据不需要任何提示就能被读到，有的必须先获得你的授权，' +
      '还有的来自对公开 API 的巧妙用法。'),

    new OnboardingPage('stays-local', PageKind.STANDARD, AppSymbols.PERMISSIONED,
      '一切留在你的设备上',
      'Houpe 只读取，不上传。你看到的每一个数值都直接来自本机，' +
      '不会离开这台设备，也不需要注册账号。')
  ];

  /**
   * 按 id 取页面。
   */
  static pageById(id: string): OnboardingPage {
    for (const p of OnboardingContent.PAGES) {
      if (p.id === id) {
        return p;
      }
    }
    return OnboardingContent.PAGES[0];
  }

  static readonly TIERS: TierCard[] = [
    new TierCard(AppSymbols.PASSIVE, '被动读取', Theme.PASSIVE,
      '你手机上的任何应用都能读到这些数据。没有任何弹窗，也没有任何东西需要你确认。'),
    new TierCard(AppSymbols.PERMISSIONED, '需要授权', Theme.PERMISSIONED,
      'HarmonyOS 会在应用第一次请求时弹出权限提示。你随时可以撤回。'),
    new TierCard(AppSymbols.ADVANCED, '高阶技巧', Theme.ADVANCED,
      '用公开 API 巧妙提取出比设计意图更多的细节。这一档最值得留意。')
  ];
}
