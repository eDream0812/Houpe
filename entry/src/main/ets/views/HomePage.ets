/*
 * HomePage.ets
 * Houpe
 *
 * 首页：介绍卡 + 三个敏感度分组 + 分类行。
 * 结构与 iOS 版 HomeView 一致：左侧关于按钮、中间标题、右侧刷新按钮。
 */

import { HdsNavigation, HdsNavigationTitleBarOptions, TitleBarContentOptions, HdsNavigationTitle, HdsNavigationMenuContentOptions, HdsNavigationTitleMode, IconStyleMode, hdsMaterial, ScrollEffectType } from '@kit.UIDesignKit';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, LengthMetrics, ColorMetrics } from '@kit.ArkUI';
import { BP_SM, contentMaxWidthFor, sidePaddingFor, categoryItemWidth, isSplitMode, getBreakpoint, subscribeBreakpoint, unsubscribeBreakpoint } from '../common/LayoutUtil';
import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { GlassCardModifier } from '../common/CardStyles';
import { CategoryRow, TierHeader, TierFooter } from '../common/CommonComponents';
import { SignalCategory, CATEGORY_ORDER, categoryInfo } from '../models/SignalCategory';
import { SENSITIVITY_ORDER, sensitivityInfo, Sensitivity } from '../models/Sensitivity';
import { store } from '../models/CategoryStore';
import { LoadState } from '../models/LoadState';
import { PermissionGatePage } from './PermissionGatePage';
import { CategoryDetailPage } from './CategoryDetailPage';
import { PermissionRationalePage } from './PermissionRationalePage';
import { AboutPage } from './AboutPage';
import { categoryShareId } from './CategoryDetailPage';
import { FingerprintSummaryPage } from './FingerprintSummaryPage';
import { replayOnboarding } from '../common/OnboardingCoordinator';
import { WebviewHarvester } from '../providers/WebviewProvider';

/**
 * 分档筛选器。用 CapsuleSegmentButtonV2 在三档间切换。
 * 支持手指拖动（iOS 风格 scrub）：按住并左右滑动时根据落点实时切换档位，
 * 与点击选择共用同一套 onSwitch 回调。
 */
const TIER_SEGMENT_LABELS: string[] = ['被动读取', '需要授权', '高阶技巧'];

@ComponentV2
struct TierFilter {
  @Param
  selectedIndex: number = 0;
  @Param
  onSwitch: (index: number) => void = () => {};
  /** 胶囊实测宽度（px），用于把触摸 x 坐标换算成档位下标 */
  @Local
  segWidthPx: number = 0;

  private items: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '被动读取' },
    { text: '需要授权' },
    { text: '高阶技巧' }
  ]);

  build() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.selectedIndex,
      // 系统默认是蓝紫色胶囊，改为品牌橙：选中项橙底白字，未选中项次要色文字
      itemSelectedBackgroundColor: ColorMetrics.resourceColor(Theme.ACCENT),
      itemSelectedFontColor: ColorMetrics.resourceColor('#FFFFFF'),
      itemSelectedFontWeight: FontWeight.Medium,
      itemFontColor: ColorMetrics.resourceColor(Theme.TEXT_SECONDARY),
      onItemClicked: (index: number) => {
        this.onSwitch(index);
      }
    })
    .width('100%')
    .margin({ bottom: 18 })
    // 测量胶囊实际宽度，供拖动落点换算使用
    .onAreaChange((_oldSize, newSize) => {
      const w = newSize.width;
      if (typeof w === 'number') {
        this.segWidthPx = w;
      }
    })
    // 手指按下/滑动时根据水平落点实时切换档位
    .onTouch((event: TouchEvent) => {
      this.scrubTo(event);
    })
  }

  /**
   * 把触摸事件的水平落点换算成档位下标。
   * 胶囊内各档等宽，因此用 x / (宽度 / 档数) 取整即可。
   */
  private scrubTo(event: TouchEvent): void {
    if (this.segWidthPx <= 0) {
      return;
    }
    const touch = event.touches[0];
    if (touch === undefined) {
      return;
    }
    const count = TIER_SEGMENT_LABELS.length;
    const step = this.segWidthPx / count;
    let idx = Math.floor(touch.x / step);
    idx = Math.max(0, Math.min(count - 1, idx));
    if (idx !== this.selectedIndex) {
      this.onSwitch(idx);
    }
  }
}

/**
 * 首页介绍卡：橙色图标 + 标题 + 说明 + 查看重点按钮。
 */
@ComponentV2
struct IntroCard {
  @Local showingSummary: boolean = false;
  /** 按钮按压标记，做按压缩放反馈 */
  @Local pressing: boolean = false;
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier(Theme.CARD_RADIUS_LG);

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        SymbolGlyph(AppSymbols.PASSIVE)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor([Theme.ACCENT])
        Text('你的应用能读到什么')
          .fontSize(Theme.FONT_HEADLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
        Blank()
      }
      .width('100%')

      Text('下面每一个分类都对应一组公开的系统接口，任何第三方应用都能调用它们。点进一个分类，看看这台设备给出了什么。')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')

      Button('看看重点', { type: ButtonType.Normal })
        .width('100%')
        .height(46)
        .fontSize(Theme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.ACCENT)
        .borderRadius(Theme.CARD_RADIUS)
        .scale(this.pressing ? { x: 0.97, y: 0.97 } : { x: 1, y: 1 })
        .opacity(this.pressing ? 0.9 : 1)
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressing = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressing = false;
          }
        })
        .onClick(() => {
          this.showingSummary = true;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Theme.CARD_PADDING)
    .margin({ top: 8, bottom: 20 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.CARD_RADIUS_LG)
    .bindSheet($$this.showingSummary, this.summarySheet(), this.sheetOptions())
  }

  @Builder
  summarySheet() {
    FingerprintSummaryPage()
  }

  private sheetOptions(): SheetOptions {
    const opts: SheetOptions = {
      height: '92%',
      dragBar: true
    };
    return opts;
  }
}

/**
 * 一个敏感度分组的完整区块：标题 + 分类行卡片 + 底部说明。
 */
@ComponentV2
struct TierSection {
  /** 订阅 store 的版本号，采集完成后自动重绘 */
  @Param
  revision: number = 0;
  @Param
  sensitivity: Sensitivity = Sensitivity.PASSIVE;
  /** 选中后跳转的回调 */
  @Param
  onOpen: (category: SignalCategory) => void = () => {};
  /** 多端断点：sm 单列 / md 两列 / lg 三列 */
  @Param
  bp: string = BP_SM;

  build() {
    Column({ space: 8 }) {
      TierHeader({
        symbol: sensitivityInfo(this.sensitivity).symbol,
        title: sensitivityInfo(this.sensitivity).title,
        tint: sensitivityInfo(this.sensitivity).tint
      })

      // 响应式栅格：sm 单列；md/lg 用 Flex 换行做多列卡片，避免大屏一行被拉得过长
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
        ForEach(this.categories(), (id: SignalCategory) => {
          Column() {
            CategoryRow({
              shareId: categoryShareId(id),
              title: categoryInfo(id)?.title ?? '',
              subtitle: categoryInfo(id)?.subtitle ?? '',
              symbol: categoryInfo(id)?.symbol ?? AppSymbols.DEVICE,
              tint: sensitivityInfo(this.sensitivity).tint,
              statusText: this.statusText(id),
              loading: store.loadStateFor(id) === LoadState.LOADING,
              denied: store.loadStateFor(id) === LoadState.DENIED,
              onTap: () => { this.onOpen(id); }
            })
          }
          .width(categoryItemWidth(this.bp))
          // sm 单列时行宽与分段按钮对齐（无额外边距）；
          // md/lg 多列栅格才加 6vp 侧边距作为列间距
          .padding(this.bp === BP_SM ? 0 : { left: 6, right: 6 })
          .margin({ bottom: 8 })
        }, (id: SignalCategory) => id)
      }
      .width('100%')

      TierFooter({ text: sensitivityInfo(this.sensitivity).blurb })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  private categories(): SignalCategory[] {
    return CATEGORY_ORDER.filter((id: SignalCategory) => {
      const info = categoryInfo(id);
      return info !== null && info.sensitivity === this.sensitivity;
    });
  }

  private statusText(id: SignalCategory): string {
    const state: LoadState = store.loadStateFor(id);
    if (state === LoadState.LOADED) {
      return `${store.countFor(id)} 项`;
    }
    if (state === LoadState.FAILED) {
      return '读取失败';
    }
    return '';
  }
}

/**
 * 首页主体。使用 HdsNavigation 承载导航与沉浸材质。
 */
@ComponentV2
export struct HomePage {
  pathStack: NavPathStack = new NavPathStack();
  /** 首页滚动器，绑定给标题栏做滚动模糊效果（HarmonySend 同款） */
  scroller: Scroller = new Scroller();
  /** 当前选中的敏感度档位下标 */
  @Local selectedTier: number = 0;
  /** 首页内容入场标记：首帧后淡入 */
  @Local entered: boolean = false;
  /** 分档切换的内容过渡标记：切档后重新播放淡入 */
  @Local tierEntered: boolean = true;
  /** 多端断点：sm / md / lg，由 EntryAbility 从窗口宽度实时写入 */
  @Local bp: string = getBreakpoint();
  /** 断点订阅回调，窗口尺寸变化时刷新 bp 并重绘 */
  private onBpChange: (bp: string) => void = (bp: string) => {
    this.bp = bp;
  };

  async aboutToAppear(): Promise<void> {
    // 订阅断点变化，折叠屏开合 / 2in1·PC 自由窗口缩放都能实时重绘
    subscribeBreakpoint(this.onBpChange);
    // 被动分类无需任何权限，进首页即可读取
    await store.refreshPassive();
    // 高阶档：网页视图指纹要等隐藏探测页就绪，异步采集不阻塞首页入场
    store.refresh(SignalCategory.WEBVIEW);
    // 内容淡入（首帧后触发，参考 NGF 子窗 animateTo 写法）
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.entered = true;
      });
    }, 30);
  }

  onPageHide(): void {
    store.stopAllLive();
  }

  aboutToDisappear(): void {
    unsubscribeBreakpoint(this.onBpChange);
  }

  /**
   * 首页内容。必须是成员 @Builder 并直接读 this.selectedTier：
   * 全局 @Builder 按值传参时，参数变化不会触发 Builder 内的 UI 刷新。
   */
  @Builder
  homeBody() {
    Scroll(this.scroller) {
      // 居中容器：宽屏下内容限宽居中，避免 PC / 平板横屏被拉伸到铺满
      Row() {
        Column({ space: 0 }) {
          IntroCard()

          // 分档筛选器：一次只看一档，与 iOS 原版的分组顺序一致
          TierFilter({
            selectedIndex: this.selectedTier,
            onSwitch: (index: number) => {
              if (index === this.selectedTier) {
                return;
              }
              // 先把分档内容置为透明，下一帧再淡入，形成切档的内容过渡
              this.tierEntered = false;
              this.selectedTier = index;
              setTimeout(() => {
                this.getUIContext()?.animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
                  this.tierEntered = true;
                });
              }, 20);
            }
          })

          // 分档内容过渡容器：整块从透明 + 下移 8vp 淡入落位
          Column() {
            ForEach([SENSITIVITY_ORDER[this.selectedTier]], (s: Sensitivity) => {
              TierSection({
                revision: store.revision,
                sensitivity: s,
                bp: this.bp,
                onOpen: (id: SignalCategory) => { this.openCategory(id); }
              })
            }, (s: Sensitivity) => s)
          }
          .width('100%')
          .opacity(this.tierEntered ? 1 : 0)
          .translate({ y: this.tierEntered ? 0 : 8 })
          .animation({ duration: 240, curve: Curve.EaseOut })

          Column()
            .height(40)
            .width('100%')
        }
        .width('100%')
        // 宽屏限宽居中；窄屏不限制（maxWidth 取到极大值）
        .constraintSize({ maxWidth: contentMaxWidthFor(this.bp) })
        // 顶部 padding 让出状态栏 + 56vp 标题栏的空间（标题栏为悬浮透明层，
        // HarmonySend 同款做法：其内容区 top=128 含 48vp 筛选条，此处无筛选条取 96）
        .padding({ left: sidePaddingFor(this.bp), right: sidePaddingFor(this.bp), top: 96 })
        // 首页内容淡入：从透明 + 下移 16vp 落到位
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 16 })
        .animation({ duration: 300, curve: Curve.EaseOut })
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

  build() {
    HdsNavigation(this.pathStack) {
      Column() {
        // 读取 revision 建立依赖，数据变化时首页自动重绘
        Text(store.revision.toString()).visibility(Visibility.None)
        // 隐藏的探测页：加载本地空白页后注入脚本，取回浏览器侧指纹
        WebviewHarvester()
        this.homeBody()
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOptions())
    // 以下属性链与 HarmonySend IndexPage 完全一致：
    // 迷你标题栏 56vp 单行（华为 titlebar 设计规范）
    .titleMode(HdsNavigationTitleMode.MINI)
    // 华为规范：一级页标题栏左侧不可出现返回图标（Mini 模式默认带返回，必须显式隐藏）
    .hideBackButton(true)
    // 多端分栏：lg（平板横屏 / 2in1 / PC）用左右主从分栏，其余单栏栈式导航
    .mode(isSplitMode(this.bp) ? NavigationMode.Split : NavigationMode.Stack)
    .backgroundColor(Theme.PAGE_BG)
    // 绑定首页滚动器：内容滚过标题栏下方时触发渐变模糊（HarmonySend 同款）
    .bindToScrollable([this.scroller])
    // 组件扩展到系统栏区域，标题栏避让由 HDS 内部处理（HarmonySend 同款组合，
    // 配合 titleBar 的 avoidLayoutSafeArea/enableComponentSafeArea=false 使用）
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .navDestination(this.routes)
    .width('100%')
    .height('100%')
  }

  /**
   * 原生标题栏：左对齐主标题 + 右侧最多三个菜单图标。
   */
  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const menu: HdsNavigationMenuContentOptions = {
      value: [
        { content: { icon: AppSymbols.ABOUT, label: '关于', type: IconStyleMode.NORMAL, action: () => { this.pathStack.pushPath({ name: 'about', param: '' }); } } },
        { content: { icon: AppSymbols.PERMISSION_INFO, label: '权限说明', type: IconStyleMode.NORMAL, action: () => { this.pathStack.pushPath({ name: 'permissionInfo', param: '' }); } } },
        { content: { icon: AppSymbols.REFRESH, label: '刷新', type: IconStyleMode.NORMAL, action: () => { store.refreshPassive(); } } }
      ]
    };
    const title: HdsNavigationTitle = { mainTitle: 'Houpe' };
    const content: TitleBarContentOptions = { title: title, menu: menu };
    // 华为 titlebar 规范：一级页标题栏 = 标题 + 右侧功能图标，左侧不可出现返回。
    // style 与 HarmonySend 完全一致：自适应材质 + 滚动渐变模糊 + 透明原始背景，
    // 滚动时内容从标题栏下穿过不会与标题文字重叠。
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

  @Builder
  routes(name: string, param: Object) {
    if (name === 'detail') {
      CategoryDetailPage({ category: param as SignalCategory })
    } else if (name === 'gate') {
      PermissionGatePage({
        category: param as SignalCategory,
        onGranted: () => {
          this.pathStack.pop();
        },
        onSwitchCategory: (next: SignalCategory) => {
          // 用 replacePath 替换掉当前门禁页，避免门禁页层层堆叠
          this.pathStack.replacePath({ name: 'gate', param: next });
        }
      })
    } else if (name === 'permissionInfo') {
      PermissionRationalePage()
    } else if (name === 'about') {
      AboutPage({
        onReplayOnboarding: () => {
          this.pathStack.pop();
          replayOnboarding();
        },
        onShowPermissions: () => {
          this.pathStack.replacePath({ name: 'permissionInfo', param: '' });
        }
      })
    }
  }

  /**
   * 打开一个分类。
   * 需授权且尚未读取的分类先走权限门禁，其余直接进详情页。
   *
   * 跳转必须包在 animateTo 里：详情页表头与首页分类行通过 geometryTransition
   * 做共享元素转场，而共享元素转场只能由 animateTo 驱动。
   */
  private openCategory(id: SignalCategory): void {
    let target: string = 'detail';
    const info = categoryInfo(id);
    if (info !== null && info.permission !== null) {
      const state: LoadState = store.loadStateFor(id);
      if (state === LoadState.IDLE || state === LoadState.DENIED) {
        target = 'gate';
      }
    }
    this.getUIContext()?.animateTo({ duration: 380, curve: Curve.EaseOut }, () => {
      this.pathStack.pushPath({ name: target, param: id });
    });
  }
}
