/*
 * AppInferenceEngine.ets
 * Houpe
 *
 * 从"已安装了哪些应用"推断用户的画像。
 *
 * 这是 Loupe 里最有意思的一环：装了什么应用，
 * 往往比任何一份表单都更能说明你是谁。
 */

import { NarrativeItem } from './FingerprintNarrative';
import { AppSymbols } from '../common/AppSymbols';

/**
 * 一条应用推断规则。
 */
export class InferenceRule {
  /** 命中数量阈值，达到才生成结论 */
  threshold: number;
  /** 结论图标 */
  symbol: Resource;
  /** 结论陈述 */
  headline: string;
  /** 依据说明 */
  basis: string;
  /** 探针包名列表 */
  probes: string[];

  constructor(threshold: number, symbol: Resource, headline: string, basis: string, probes: string[]) {
    this.threshold = threshold;
    this.symbol = symbol;
    this.headline = headline;
    this.basis = basis;
    this.probes = probes;
  }
}

/**
 * 应用推断引擎。
 */
export class AppInferenceEngine {
  /**
   * 推断规则表。每条规则对应一种用户画像。
   */
  private static readonly RULES: InferenceRule[] = [
    new InferenceRule(2, AppSymbols.PERMISSIONED, '你的应用列表里有好几个强调隐私的工具。',
      '隐私工具、加密通讯、密码管理器的存在，通常说明你在意自己的数据被谁看到。',
      ['com.protonmail.android', 'com.protonvpn.android', 'com.duckduckgo.mobile.android',
        'com.onepassword.android', 'com.lastpass.lpandroid', 'org.torproject.torbrowser',
        'com.signal.android', 'com.whatsapp']),

    new InferenceRule(2, AppSymbols.BATTERY, '你装了不少办公协作类的应用。',
      '会议、文档、协作工具同时出现，多半是团队工作的一部分。',
      ['com.tencent.wework', 'com.alibaba.android.rimet', 'com.microsoft.teams',
        'com.slack', 'com.tencent.docs', 'com.tencent.meeting', 'com.zoom.us']),

    new InferenceRule(1, AppSymbols.CAMERA, '你装了视频社区和短视频应用。',
      '社交与短视频应用是碎片时间的主要去处，装了哪几个能看出你的内容偏好。',
      ['com.ss.android.ugc.aweme', 'com.sina.weibo', 'com.xingin.xhs',
        'com.zhihu.android', 'com.threads.net', 'com.reddit.frontpage',
        'com.pinterest', 'com.linkedin.android']),

    new InferenceRule(2, AppSymbols.PERMISSIONED, '你装了几个音乐与流媒体应用。',
      '音乐和流媒体的组合，反映出你平时用什么消磨时间。',
      ['com.tencent.qqmusic', 'com.netease.cloudmusic', 'com.kugou.android',
        'com.spotify.music', 'com.netflix.mediaclient', 'com.bilibili.app.in',
        'com.qiyi.video', 'com.youku.phone']),

    new InferenceRule(2, AppSymbols.GRAPHICS, '你装了几个游戏或游戏平台。',
      '游戏客户端和直播平台的组合，是明显的休闲时间信号。',
      ['com.tencent.tmgp.sgame', 'com.netease.gl', 'com.miHoYo.Yuanshen',
        'com.blizzard.wtcg.hearthstone']),

    new InferenceRule(2, AppSymbols.STORAGE, '你装了购物与支付类的应用。',
      '电商和支付应用能反映出你的消费习惯，也可能被用来推断你的收入区间。',
      ['com.taobao.taobao', 'com.jingdong.app.mall', 'com.xunmeng.pinduoduo',
        'com.eg.android.AlipayGphone']),

    new InferenceRule(1, AppSymbols.PASTEBOARD, '你装了在线文档或协作工具。',
      '文档与协作工具的存在，说明你经常在手机上处理文字内容。',
      ['com.tencent.docs', 'com.alibaba.android.calendar', 'com.microsoft.office.outlook',
        'com.netease.mail']),

    new InferenceRule(2, AppSymbols.DEVICE, '你装了导航与出行类应用。',
      '地图和打车应用常常透露你的活动范围，以及你是否经常跨城移动。',
      ['com.autonavi.minimap', 'com.baidu.BaiduMap', 'com.tencent.map',
        'com.sdu.didi.psnger', 'me.didi.passenger'])
  ];

  /**
   * 依据探测到的应用列表生成推断结论。
   */
  static infer(detected: string[]): NarrativeItem[] {
    const out: NarrativeItem[] = [];
    if (detected.length === 0) {
      return out;
    }

    for (const rule of AppInferenceEngine.RULES) {
      const hits: string[] = rule.probes.filter(p => detected.indexOf(p) >= 0);
      if (hits.length >= rule.threshold) {
        out.push(new NarrativeItem(
          `infer_${rule.headline.substring(0, 6)}`,
          rule.symbol,
          rule.headline,
          `推断依据：探测到 ${hits.length} 个相关应用已安装（${AppInferenceEngine.shortNames(hits)}）。`
        ));
      }
    }

    return out;
  }

  /**
   * 把包名列表转成简短名称展示。
   */
  private static shortNames(probes: string[]): string {
    const names: string[] = probes.map(p => {
      const parts: string[] = p.split('.');
      return parts.length > 1 ? parts[1] : p;
    });
    if (names.length <= 3) {
      return names.join('、');
    }
    return names.slice(0, 3).join('、') + ` 等 ${names.length} 个`;
  }
}
