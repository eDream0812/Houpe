/*
 * CommonComponents.ets
 * Houpe
 *
 * 跨页面复用的 UI 组件。列表行为自绘实心底卡片（宽度完全受控，
 * 与分段按钮等组件严格对齐），其余卡片为实心底 + 系统配色，随深浅色自动切换。
 */

import { Theme } from './Theme';
import { GlassCardModifier } from './CardStyles';
import { FingerprintSignal, SignalEntry, DisplayHint } from '../models/FingerprintSignal';
import { AppSymbols } from '../common/AppSymbols';

/**
 * 分类列表行。
 * 对应 iOS 版 CategoryRowView：图标方块 + 标题 + 副标题 + 状态指示。
 */
@ComponentV2
export struct CategoryRow {
  /** 与详情页表头配对的共享元素 id（为空表示不做转场） */
  @Param
  shareId: string = '';
  @Param
  title: string = '';
  @Param
  subtitle: string = '';
  @Param
  symbol: Resource = $r('sys.symbol.phone');
  @Param
  tint: string = Theme.PASSIVE;
  @Param
  statusText: string = '';
  @Param
  loading: boolean = false;
  @Param
  denied: boolean = false;
  @Param
  onTap: () => void = () => {};

  build() {
    // 自绘卡片行：HdsListItemCard 自带不可关闭的内置外边距，导致行宽
    // 比分段按钮窄一截；改用与 IntroCard 同款的实心底卡片容器，
    // 宽度 100% 铺满父容器，左右边缘与分段按钮严格对齐。
    Row({ space: 12 }) {
      // 图标块：分档配色的圆角方块
      Column() {
        SymbolGlyph(this.symbol)
          .fontSize(20)
          .fontColor([this.tint])
      }
      .width(38)
      .height(38)
      .borderRadius(10)
      .backgroundColor(Theme.alpha(this.tint, 0.15))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 标题 + 副标题
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(Theme.FONT_SUBHEAD)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.subtitle)
          .fontSize(Theme.FONT_CAPTION)
          .fontColor(Theme.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 状态指示：加载中 / 未授权 / 计数 + 箭头 / 纯箭头
      if (this.loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(Theme.TEXT_TERTIARY)
      } else if (this.denied) {
        Text('未授权')
          .fontSize(Theme.FONT_CAPTION)
          .fontColor(Theme.TEXT_TERTIARY)
      } else if (this.statusText.length > 0) {
        Row({ space: 4 }) {
          Text(this.statusText)
            .fontSize(Theme.FONT_CAPTION)
            .fontColor(Theme.TEXT_TERTIARY)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(12)
            .fontColor([Theme.TEXT_TERTIARY])
        }
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(12)
          .fontColor([Theme.TEXT_TERTIARY])
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.CARD_RADIUS)
    // 共享元素转场：与详情页表头绑定同一个 id，跳转时这一行会连续过渡到表头位置。
    // 转场动画由调用方在 animateTo 中执行 pushPath 驱动。
    .geometryTransition(this.shareId)
    .onClick(() => {
      this.onTap();
    })
  }
}

/**
 * 分组标题：图标 + 文字，用分档配色。
 */
@ComponentV2
export struct TierHeader {
  @Param
  symbol: Resource = $r('sys.symbol.eye');
  @Param
  title: string = '';
  @Param
  tint: string = Theme.PASSIVE;

  build() {
    Row({ space: 8 }) {
      SymbolGlyph(this.symbol)
        .fontSize(15)
        .fontColor([this.tint])
      Text(this.title)
        .fontSize(Theme.FONT_SUBHEAD)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tint)
    }
    .width('100%')
    .padding({ left: 4, bottom: 8 })
  }
}

/**
 * 分组底部说明文字。
 */
@ComponentV2
export struct TierFooter {
  @Param
  text: string = '';

  build() {
    Text(this.text)
      .fontSize(Theme.FONT_CAPTION)
      .fontColor(Theme.TEXT_TERTIARY)
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 4 })
  }
}

/**
 * 洞察卡片：图标 + 粗体陈述 + 灰色解释。
 * 对应 iOS 版 NarrativeCardView。
 */
@ComponentV2
export struct NarrativeCard {
  @Param
  symbol: Resource = $r('sys.symbol.bolt');
  @Param
  headline: string = '';
  @Param
  basis: string = '';

  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();

  build() {
    Row({ space: 14 }) {
      SymbolGlyph(this.symbol)
        .fontSize(22)
        .fontColor([Theme.ACCENT])
        .width(28)
        .height(28)

      Column({ space: 4 }) {
        Text(this.headline)
          .fontSize(Theme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')

        Text(this.basis)
          .fontSize(Theme.FONT_CAPTION)
          .fontColor(Theme.TEXT_SECONDARY)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .attributeModifier(this.cardModifier)
  }
}

/**
 * 信号行：信号名 + 值 + 灰色解释。
 * 值按 DisplayHint 分五种形态渲染，与 iOS 版 SignalRowView 一一对应。
 */
@ComponentV2
export struct SignalRow {
  @Param
  signal: FingerprintSignal | null = null;
  @Param
  onCopy: (signal: FingerprintSignal) => void = () => {};

  build() {
    Column({ space: 6 }) {
      if (this.signal !== null) {
        Text(this.signal!.name)
          .fontSize(Theme.FONT_SUBHEAD)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')

        SignalValue({
          hint: this.signal!.hint,
          value: this.signal!.value,
          entries: this.signal!.entries
        })

        if (this.signal!.rationale.length > 0) {
          Text(this.signal!.rationale)
            .fontSize(Theme.FONT_FOOTNOTE)
            .fontColor(Theme.TEXT_SECONDARY)
            .width('100%')
            .margin({ top: 2 })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, bottom: 8 })
  }
}

/**
 * 信号值的渲染器。按 DisplayHint 分派。
 */
@ComponentV2
struct SignalValue {
  @Param
  hint: DisplayHint = DisplayHint.PLAIN;
  @Param
  value: string = '';
  @Param
  entries: SignalEntry[] | null = null;

  build() {
    Column({ space: 10 }) {
      if (this.entries === null || this.entries.length === 0) {
        Text(this.value)
          .fontSize(Theme.FONT_BODY)
          .fontFamily('monospace')
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)
      } else if (this.hint === DisplayHint.KEY_VALUE) {
        ForEach(this.entries, (e: SignalEntry) => {
          Column({ space: 2 }) {
            Text(e.label)
              .fontSize(Theme.FONT_CAPTION)
              .fontColor(Theme.TEXT_SECONDARY)
              .width('100%')
            Text(e.value)
              .fontSize(Theme.FONT_CAPTION)
              .fontFamily('monospace')
              .fontColor(Theme.TEXT_PRIMARY)
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (e: SignalEntry) => e.label + e.value)
      } else if (this.hint === DisplayHint.TAGS) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.entries, (e: SignalEntry) => {
            Text(e.value)
              .fontSize(Theme.FONT_CAPTION)
              .fontFamily('monospace')
              .fontColor(Theme.TEXT_PRIMARY)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(Theme.alpha(Theme.TERTIARY_HEX, 0.18))
              .borderRadius(12)
          }, (e: SignalEntry) => e.label + e.value)
        }
        .width('100%')
      } else {
        Row({ space: 16 }) {
          ForEach(this.entries, (e: SignalEntry) => {
            Column({ space: 2 }) {
              Text(e.label)
                .fontSize(Theme.FONT_CAPTION2)
                .fontColor(Theme.TEXT_SECONDARY)
              Text(e.value)
                .fontSize(Theme.FONT_CAPTION)
                .fontFamily('monospace')
                .fontColor(Theme.TEXT_PRIMARY)
            }
            .alignItems(HorizontalAlign.Start)
          }, (e: SignalEntry) => e.label + e.value)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 分档标签。用于详情页顶部的敏感度徽章。
 */
@ComponentV2
export struct SensitivityBadge {
  @Param
  symbol: Resource = $r('sys.symbol.eye');
  @Param
  title: string = '';
  @Param
  tint: string = Theme.PASSIVE;

  build() {
    Row({ space: 5 }) {
      SymbolGlyph(this.symbol)
        .fontSize(12)
        .fontColor([this.tint])
      Text(this.title)
        .fontSize(Theme.FONT_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tint)
    }
    .padding({ left: 8, right: 10, top: 4, bottom: 4 })
    .backgroundColor(Theme.alpha(this.tint, 0.15))
    .borderRadius(10)
  }
}

/**
 * 空状态提示。
 */
@ComponentV2
export struct EmptyHint {
  @Param
  text: string = '暂无数据';

  build() {
    Column({ space: 8 }) {
      SymbolGlyph(AppSymbols.QUESTION)
        .fontSize(28)
        .fontColor([Theme.TEXT_TERTIARY])
      Text(this.text)
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(Theme.TEXT_TERTIARY)
    }
    .width('100%')
    .padding({ top: 24, bottom: 24 })
  }
}
