/*
 * FingerprintSummaryPage.ets
 * Houpe
 *
 * 高亮洞察页：把原始读数翻译成人话结论。
 * 对应 iOS 版的 FingerprintSummaryView，作为半模态弹层展示，靠下拉关闭，没有返回按钮。
 */

import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { GlassCardModifier } from '../common/CardStyles';
import { NarrativeCard } from '../common/CommonComponents';
import { NarrativeItem, FingerprintNarrative } from '../support/FingerprintNarrative';
import { AppInferenceEngine } from '../support/AppInferenceEngine';
import { store } from '../models/CategoryStore';
import { FingerprintSignal } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { PlatformDevice } from '../support/PlatformShim';

@ComponentV2
export struct FingerprintSummaryPage {
  @Local items: NarrativeItem[] = [];
  @Local chip: string = '';
  /** 卡片错位入场标记：弹层打开后逐张淡入上移 */
  @Local appeared: boolean = false;
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();

  aboutToAppear(): void {
    this.items = FingerprintNarrative.build(store.signals);
    this.chip = FingerprintNarrative.fingerprintChip(store.signals);
    // 弹层内容逐张淡入（首帧后触发，参考 NGF 子窗 animateTo 写法）
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.appeared = true;
      });
    }, 30);
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 22 }) {
          this.header()
          this.explainer()
          this.cards()
          this.closing()
          Column()
            .height(24)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 20 })
      }
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.PAGE_BG)
  }

  @Builder
  header() {
    Column({ space: 12 }) {
      SymbolGlyph(AppSymbols.ADVANCED_ALT)
        .fontSize(44)
        .fontColor([Theme.ACCENT])

      Text(`你的 ${PlatformDevice.readableName} 透露了什么`)
        .fontSize(Theme.FONT_TITLE - 8)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .width('100%')

      Text('下面每一条都是从这台设备刚刚读到的真实数据推导出来的。' +
        '单看任何一条都不算什么，但它们摆在一起就是一份完整的画像。')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  explainer() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph(AppSymbols.QUESTION)
          .fontSize(17)
          .fontColor([Theme.ACCENT])
        Text('什么是指纹识别')
          .fontSize(Theme.FONT_HEADLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      .width('100%')

      Text('追踪者不需要你的名字、邮箱，也不需要知道你在哪里。设备上一些看起来无害的设置，组合起来就成了一个跟着你穿过各个应用与网站的指纹。')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Theme.CARD_PADDING)
    .attributeModifier(this.cardModifier)
  }

  @Builder
  cards() {
    Column({ space: 12 }) {
      if (this.items.length === 0) {
        Text('还没有采集到足够的数据。回到首页下拉刷新后，这里会显示推断结论。')
          .fontSize(Theme.FONT_SUBHEAD)
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
      } else {
        ForEach(this.items, (item: NarrativeItem, index: number) => {
          Column() {
            NarrativeCard({ symbol: item.symbol, headline: item.headline, basis: item.basis })
          }
          .width('100%')
          // 逐张错位淡入：从透明 + 下移 12vp 落到原位
          .opacity(this.appeared ? 1 : 0)
          .translate({ y: this.appeared ? 0 : 12 })
          .animation({ duration: 280, delay: index * 50, curve: Curve.EaseOut })
        }, (item: NarrativeItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  closing() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        SymbolGlyph(AppSymbols.CHAIN_INSIGHT)
          .fontSize(17)
          .fontColor([Theme.ACCENT])
        Text('把它们拼在一起')
          .fontSize(Theme.FONT_HEADLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      .width('100%')

      if (this.chip.length > 0) {
        Text(this.chip)
          .fontSize(Theme.FONT_FOOTNOTE)
          .fontFamily('monospace')
          .fontColor(Theme.ACCENT)
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(Theme.alpha(Theme.ACCENT_HEX, 0.12))
          .borderRadius(10)
          .border({ width: 1, color: Theme.alpha(Theme.ACCENT_HEX, 0.35) })
          .copyOption(CopyOptions.LocalDevice)
      }

      Text('Houpe 已经在本机读到这些数据，只存在于这台设备上，没有上传，也没有同步。')
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(Theme.TEXT_TERTIARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Theme.CARD_PADDING)
    .attributeModifier(this.cardModifier)
  }
}
