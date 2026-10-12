/*
 * PermissionGatePage.ets
 * Houpe
 *
 * 权限门禁页：大图标 + 权限风险说明 + 授权按钮 + 状态提示。
 * 结构与 iOS 版 PermissionGateView 一致。
 */

import { HdsNavDestination, hdsMaterial, HdsNavigationTitleBarOptions, TitleBarContentOptions, HdsNavigationTitle, HdsListItemCard, PrefixIcon, SuffixTextAndArrow, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { showHdsToast } from '../common/HdsFeedback';
import { SignalCategory, categoryInfo, CATEGORY_ORDER } from '../models/SignalCategory';
import { PermissionKind, permissionTitle, permissionRationale, permissionSystemNames } from '../models/PermissionKind';
import { store } from '../models/CategoryStore';
import { PermissionCenter, AuthStatus } from '../support/PermissionCenter';

@ComponentV2
export struct PermissionGatePage {
  /** 要申请权限的分类 */
  @Param
  category: SignalCategory = SignalCategory.LOCATION;
  @Local status: AuthStatus = AuthStatus.NOT_DETERMINED;
  @Local message: string = '';
  @Local requesting: boolean = false;
  /** 授权成功后的回调 */
  @Param
  onGranted: () => void = () => {};
  /** 切换到其它分类的回调 */
  @Param
  onSwitchCategory: (category: SignalCategory) => void = () => {};
  /** 滚动器，绑定给标题栏做滚动模糊效果（与首页一致） */
  scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    const info = categoryInfo(this.category);
    if (info !== null && info.permission !== null) {
      this.status = await PermissionCenter.checkAll(permissionSystemNames(info.permission));
    }
  }

  private kind(): PermissionKind {
    const info = categoryInfo(this.category);
    return info !== null && info.permission !== null ? info.permission : PermissionKind.LOCATION;
  }

  private tint(): string {
    return Theme.PERMISSIONED;
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          this.categorySwitcher()

          // 大图标：72pt 图标置于 15% 透明底的圆形里
          Stack() {
            SymbolGlyph(categoryInfo(this.category)?.symbol ?? AppSymbols.PERMISSIONED)
              .fontSize(56)
              .fontColor([this.tint()])
          }
          .width(140)
          .height(140)
          .backgroundColor(Theme.alpha(this.tint(), Theme.ICON_TINT_ALPHA))
          .borderRadius(70)

          // 分类名
          Text(categoryInfo(this.category)?.title ?? '')
            .fontSize(Theme.FONT_TITLE - 8)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)

          // 权限风险说明
          Text(permissionRationale(this.kind()))
            .fontSize(Theme.FONT_BODY)
            .fontColor(Theme.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .lineHeight(24)
            .padding({ left: 8, right: 8 })
            .width('100%')

          // 授权按钮
          if (this.requesting) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.tint())
          } else if (this.status === AuthStatus.DENIED) {
            Column({ space: 12 }) {
              Button('重试', { type: ButtonType.Normal })
                .width('100%')
                .height(46)
                .fontSize(Theme.FONT_BODY)
                .fontColor(this.tint())
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: this.tint() })
                .borderRadius(Theme.CARD_RADIUS)
                .onClick(() => { this.request(); })

              if (this.message.length > 0) {
                Text(this.message)
                  .fontSize(Theme.FONT_CAPTION)
                  .fontColor('#E5484D')
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
          } else {
            Button('开启' + permissionTitle(this.kind()), { type: ButtonType.Normal })
              .width('100%')
              .height(48)
              .fontSize(Theme.FONT_HEADLINE)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor(this.tint())
              .borderRadius(Theme.CARD_RADIUS)
              .onClick(() => { this.request(); })
          }

          // 状态提示
          Text(this.hintText())
            .fontSize(Theme.FONT_CAPTION)
            .fontColor(Theme.TEXT_TERTIARY)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24, top: 96, bottom: 40 })
      }
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOptions())
    // 迷你标题栏：56vp 单行，标题与菜单按钮同排对齐（华为 titlebar 设计规范）
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .backgroundColor(Theme.PAGE_BG)
  }

  /**
   * 原生标题栏：分类名 + 默认返回键。
   */
  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const title: HdsNavigationTitle = { mainTitle: categoryInfo(this.category)?.title ?? '授权' };
    const content: TitleBarContentOptions = { title: title };
    // 与首页同一套悬浮透明标题栏方案：avoidLayoutSafeArea/enableComponentSafeArea
    // 均为 false，标题栏不悬浮避让由内容区 top padding 让位（状态栏 + 56vp 标题栏）。
    return {
      content: content,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            // 渐变颜色必须与页面背景色一致，否则滚到标题栏下方会出现色差接缝
            backgroundColor: Theme.PAGE_BG,
            // 渐变模糊层比标题栏底边再高出 32vp（实际遮罩高度 = 标题栏高度 + 32），
            // 与"跟手隐藏"情况下的高度保持一致
            maskExtraHeight: 32
          }
        }
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    };
  }

  /**
   * 在所有需授权的分类之间切换。用 TextPickerDialog，
   * 因为分类数量不定（鸿蒙上可能多于 iOS），弹窗选择比平铺更合适。
   */
  @Builder
  categorySwitcher() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({ iconValue: { symbol: AppSymbols.MORE } }),
      textItem: {
        primaryText: { text: '切换到其它分类' }
      },
      suffixItem: new SuffixTextAndArrow({ text: `${PermissionGatePage.gatedCategories().length} 个需授权` }),
      onClick: () => {
        this.openPicker();
      }
    })
    .width('100%')
  }

  /**
   * 弹出分类选择器。
   */
  private openPicker(): void {
    const gated: SignalCategory[] = PermissionGatePage.gatedCategories();
    const labels: string[] = gated.map((id: SignalCategory) =>
      categoryInfo(id)?.title ?? '');
    const currentIndex: number = gated.indexOf(this.category);
    const options: TextPickerDialogOptions = {
      range: labels,
      selected: currentIndex >= 0 ? currentIndex : 0,
      canLoop: false,
      onAccept: (result: TextPickerResult) => {
        const idx: number = typeof result.index === 'number' ? result.index : 0;
        if (idx >= 0 && idx < gated.length) {
          this.onSwitchCategory(gated[idx]);
        }
      }
    };
    this.getUIContext().showTextPickerDialog(options);
  }

  /**
   * 所有需授权的分类。
   */
  private static gatedCategories(): SignalCategory[] {
    return CATEGORY_ORDER.filter((id: SignalCategory) => {
      const info = categoryInfo(id);
      return info !== null && info.permission !== null;
    });
  }

  private hintText(): string {
    if (this.status === AuthStatus.DENIED) {
      return '你也可以稍后在「设置 - 隐私」里重新开启这个权限。';
    }
    if (this.status === AuthStatus.GRANTED) {
      return '你已经授权了这一类数据。';
    }
    return '点击上方按钮会弹出系统授权提示。授权后 Houpe 只会读取上面说明的这些数值。';
  }

  private async request(): Promise<void> {
    this.requesting = true;
    this.message = '';
    const result = await PermissionCenter.request(permissionSystemNames(this.kind()));
    this.status = result.status;
    this.message = result.message;
    this.requesting = false;

    if (result.status === AuthStatus.GRANTED) {
      await store.refresh(this.category);
      this.onGranted();
      showHdsToast(this.getUIContext(), '已获得授权', AppSymbols.GRANTED);
    } else if (result.status === AuthStatus.DENIED) {
      showHdsToast(this.getUIContext(), '未获得授权');
    }
  }
}
