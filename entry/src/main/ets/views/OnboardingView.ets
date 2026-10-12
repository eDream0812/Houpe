/*
 * OnboardingView.ets
 * Houpe
 *
 * 六页引导流程：Swiper 翻页 + 系统底色 + 底部按钮条。
 * 结构与 iOS 版 OnboardingView 一致。
 */

import { Theme } from '../common/Theme';
import { GlassCardModifier } from '../common/CardStyles';
import { NarrativeCard } from '../common/CommonComponents';
import { OnboardingPage as Page, PageKind, OnboardingContent, TierCard } from '../support/OnboardingContent';
import { NarrativeItem, FingerprintNarrative } from '../support/FingerprintNarrative';
import { store } from '../models/CategoryStore';
import { AppSymbols } from '../common/AppSymbols';

/**
 * 三档分层说明卡片。
 */
@ComponentV2
struct TierCardView {
  @Param
  symbol: Resource = $r('sys.symbol.eye');
  @Param
  title: string = '';
  @Param
  tint: string = Theme.PASSIVE;
  @Param
  body: string = '';
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();

  build() {
    Row({ space: 14 }) {
      SymbolGlyph(this.symbol)
        .fontSize(20)
        .fontColor([this.tint])
        .width(28)
        .height(28)

      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(Theme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')
        Text(this.body)
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
 * 单页内容渲染器。按 PageKind 分派。
 */
@ComponentV2
struct OnboardingPageView {
  @Param
  pageId: string = 'welcome';
  @Param
  highlights: NarrativeItem[] = [];
  /** 当前是否为可见页：切换时让主图标弹跳一下（参考 NGF 底栏 symbolEffect 写法） */
  @Param
  isActive: boolean = false;
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();

  private page(): Page {
    return OnboardingContent.pageById(this.pageId);
  }

  build() {
    Scroll() {
      // 居中容器：宽屏（2in1 / PC）下限宽 720vp 居中，避免正文一行被拉得过宽难读
      Row() {
        Column({ space: 22 }) {
          Column()
            .height(16)
            .width('100%')

          if (this.page().kind === PageKind.STANDARD) {
            this.standardBody()
          } else {
            this.listBody()
          }

          Column()
            .height(16)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
  }

  @Builder
  standardBody() {
    Column({ space: 18 }) {
      if (this.page().symbol !== null) {
        SymbolGlyph(this.page().symbol)
          .fontSize(84)
          .fontColor([Theme.ACCENT])
          // 成为当前页时弹跳一次，给用户翻页的即时反馈
          .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.isActive)
      }

      Text(this.page().title)
        .fontSize(Theme.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(this.page().body)
        .fontSize(Theme.FONT_BODY + 2)
        .fontColor(Theme.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .lineHeight(28)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  listBody() {
    Column({ space: 16 }) {
      Text(this.page().title)
        .fontSize(Theme.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(this.page().body)
        .fontSize(Theme.FONT_BODY)
        .fontColor(Theme.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .lineHeight(26)
        .width('100%')

      if (this.page().kind === PageKind.TIERS) {
        ForEach(OnboardingContent.TIERS, (tier: TierCard) => {
          TierCardView({
            symbol: tier.symbol,
            title: tier.title,
            tint: tier.tint,
            body: tier.body
          })
        }, (tier: TierCard) => tier.title)
      } else if (this.page().kind === PageKind.HIGHLIGHTS) {
        this.highlightCards()
      } else {
        this.appsNotice()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  highlightCards() {
    Column({ space: 12 }) {
      if (this.highlights.length === 0) {
        Text('这些洞察会根据你打开应用时的真实数据生成。')
          .fontSize(Theme.FONT_SUBHEAD)
          .fontColor(Theme.TEXT_TERTIARY)
          .textAlign(TextAlign.Center)
          .width('100%')
      } else {
        ForEach(this.highlights, (item: NarrativeItem) => {
          NarrativeCard({
            symbol: item.symbol,
            headline: item.headline,
            basis: item.basis
          })
        }, (item: NarrativeItem) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  appsNotice() {
    Column({ space: 8 }) {
      SymbolGlyph(AppSymbols.INSTALLED_APPS)
        .fontSize(24)
        .fontColor([Theme.ACCENT])

      Text('需要你授权后才能探测')
        .fontSize(Theme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Text('Houpe 不会默认查询你装了什么。你可以随时在首页的「已安装应用探测」分类里主动开启。')
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(Theme.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .attributeModifier(this.cardModifier)
  }
}

/**
 * 引导页容器。展示六页内容，使用 Swiper 内置圆点指示器（橙色）与前后翻页按钮。
 */
@ComponentV2
struct OnboardingContainer {
  @Local current: number = 0;
  @Local highlights: NarrativeItem[] = [];
  /** 整页入场标记：首帧后再置 true，触发淡入 + 轻微上移 */
  @Local appeared: boolean = false;
  /** 当前被按下的按钮，用于按压缩放反馈 */
  @Local pressedBtn: string = '';
  @Param
  onFinish: () => void = () => {};

  aboutToAppear(): void {
    this.highlights = FingerprintNarrative.build(store.signals);
    // 入场动画：首帧渲染后再触发，整页淡入并轻微上移（参考 NGF 子窗 animateTo 写法）
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.appeared = true;
      });
    }, 30);
  }

  private lastIndex(): number {
    return OnboardingContent.PAGES.length - 1;
  }

  build() {
    Column() {
      Column()
        .height(40)
        .width('100%')

      // 跳过按钮
      Row() {
        Blank()
        Button('跳过', { type: ButtonType.Normal })
          .height(32)
          .fontSize(Theme.FONT_SUBHEAD)
          .fontColor(Theme.TEXT_SECONDARY)
          .backgroundColor(Color.Transparent)
          .scale(this.pressedBtn === 'skip' ? { x: 0.94, y: 0.94 } : { x: 1, y: 1 })
          .opacity(this.pressedBtn === 'skip' ? 0.7 : 1)
          .animation({ duration: 120, curve: Curve.EaseOut })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.pressedBtn = 'skip';
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedBtn = '';
            }
          })
          .onClick(() => {
            this.onFinish();
          })
      }
      .width('100%')
      .padding({ right: Theme.PAGE_PADDING })

      Swiper() {
        ForEach(OnboardingContent.PAGES, (page: Page, idx: number) => {
          OnboardingPageView({
            pageId: page.id,
            highlights: this.highlights,
            isActive: this.current === idx
          })
        }, (page: Page) => page.id)
      }
      .index(this.current)
      .loop(false)
      // 使用 Swiper 内置圆点指示器，并改为橙色（当前页 ACCENT，其余半透明灰）
      .indicator(new DotIndicator()
        .selectedColor(Theme.ACCENT)
        .color(Theme.alpha(Theme.TERTIARY_HEX, 0.5))
        .bottom(16))
      .onChange((index: number) => {
        this.current = index;
      })
      .layoutWeight(1)
      .width('100%')

      // 底部按钮条
      Row({ space: 12 }) {
        if (this.current > 0) {
          Button('上一步', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(48)
            .fontSize(Theme.FONT_BODY)
            .fontColor(Theme.ACCENT)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: Theme.alpha(Theme.ACCENT_HEX, 0.5) })
            .borderRadius(Theme.CARD_RADIUS)
            .scale(this.pressedBtn === 'prev' ? { x: 0.97, y: 0.97 } : { x: 1, y: 1 })
            .opacity(this.pressedBtn === 'prev' ? 0.85 : 1)
            .animation({ duration: 120, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressedBtn = 'prev';
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.pressedBtn = '';
              }
            })
            .onClick(() => {
              this.current = this.current - 1;
            })
        }

        Button(this.current === this.lastIndex() ? '开始体验' : '下一步', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(48)
          .fontSize(Theme.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.ACCENT)
          .borderRadius(Theme.CARD_RADIUS)
          .scale(this.pressedBtn === 'next' ? { x: 0.97, y: 0.97 } : { x: 1, y: 1 })
          .opacity(this.pressedBtn === 'next' ? 0.9 : 1)
          .animation({ duration: 120, curve: Curve.EaseOut })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.pressedBtn = 'next';
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedBtn = '';
            }
          })
          .onClick(() => {
            if (this.current === this.lastIndex()) {
              this.onFinish();
            } else {
              this.current = this.current + 1;
            }
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    // 整页入场：从透明 + 下移 24vp 淡入到位
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 24 })
    .animation({ duration: 350, curve: Curve.EaseOut })
  }
}

/**
 * 引导页入口：系统底色。
 */
@ComponentV2
export struct OnboardingView {
  @Param
  onFinish: () => void = () => {};

  build() {
    Stack() {
      // 全屏背景层：扩展进状态栏与导航条安全区（沉浸式），仅做底色出血
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.PAGE_BG)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 内容层：不扩展安全区，保留顶部间距与底部内边距，避免被状态栏/导航条遮挡
      OnboardingContainer({
        onFinish: () => {
          this.onFinish();
        }
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
