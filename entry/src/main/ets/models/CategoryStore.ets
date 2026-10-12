/*
 * CategoryStore.ets
 * Houpe
 *
 * 全局单一状态源。首页与所有详情页共享这里的数据。
 *
 * 采集全部在本机完成，不发起任何网络请求。
 */

import { FingerprintSignal } from './FingerprintSignal';
import { SignalCategory, CATEGORY_ORDER, categoryInfo, categoriesFor } from './SignalCategory';
import { LoadState } from './LoadState';
import { PermissionKind, permissionSystemNames } from './PermissionKind';
import { Sensitivity } from './Sensitivity';
import { SignalProvider, LiveSignalProvider, PickerSignalProvider } from './SignalProvider';
import { PermissionCenter, AuthStatus } from '../support/PermissionCenter';
import { DeviceIdentityProvider, SystemInfoProvider, BatteryProvider, StorageProvider, DisplayProvider,
  AudioRouteProvider, LocaleProvider, PasteboardProvider, NetworkProvider, FontsProvider } from '../providers/PassiveProviders';
import { AccessibilityProvider, DeviceMotionProvider, GraphicsProvider, WirelessProvider, AppInfoProvider } from '../providers/DeviceProviders';
import { MotionProvider, LocationProvider, CameraProvider, MicrophoneProvider, MediaPickerProvider,
  InstalledAppsProvider } from '../providers/GatedProviders';
import { webviewProvider } from '../providers/WebviewProvider';

/**
 * 全局状态容器。用 @ObservedV2 让 UI 组件自动感知变化。
 */
@ObservedV2
export class CategoryStore {
  /** 分类 id -> 信号列表 */
  signals: Map<SignalCategory, FingerprintSignal[]> = new Map();
  /** 分类 id -> 加载状态 */
  loadStates: Map<SignalCategory, LoadState> = new Map();
  /** 分类 id -> 授权状态 */
  authStates: Map<SignalCategory, AuthStatus> = new Map();
  /**
   * 数据版本号。每次采集完成后自增。
   * UI 侧 @Local 组件读取它即可触发刷新——
   * V2 的 @Trace 不追踪 Map 内部变更，用版本号显式驱动更可靠。
   */
  @Trace revision: number = 0;

  /** 全部 Provider 注册表 */
  private providers: Map<SignalCategory, SignalProvider> = new Map();
  /** 正在运行的实时重采样定时器 */
  private timers: Map<SignalCategory, number> = new Map();

  constructor() {
    this.register(new DeviceIdentityProvider());
    this.register(new SystemInfoProvider());
    this.register(new BatteryProvider());
    this.register(new StorageProvider());
    this.register(new DisplayProvider());
    this.register(new AudioRouteProvider());
    this.register(new LocaleProvider());
    this.register(new AccessibilityProvider());
    this.register(new DeviceMotionProvider());
    this.register(new NetworkProvider());
    this.register(new FontsProvider());
    this.register(new AppInfoProvider());
    this.register(new PasteboardProvider());
    this.register(new GraphicsProvider());
    this.register(new WirelessProvider());
    this.register(new MotionProvider());
    this.register(new LocationProvider());
    this.register(new CameraProvider());
    this.register(new MicrophoneProvider());
    this.register(new MediaPickerProvider());
    this.register(new InstalledAppsProvider());
    // 网页视图指纹：单例，与首页里的隐藏探测页共用同一实例
    this.register(webviewProvider);

    // 初始状态全部为未读取
    for (const id of CATEGORY_ORDER) {
      this.loadStates.set(id, LoadState.IDLE);
      this.signals.set(id, []);
    }
  }

  private register(p: SignalProvider): void {
    this.providers.set(p.category, p);
  }

  /* ---------- 读取访问器 ---------- */

  /**
   * 取某分类已采集的信号。
   */
  signalsFor(id: SignalCategory): FingerprintSignal[] {
    return this.signals.get(id) ?? [];
  }

  /**
   * 取某分类的加载状态。
   */
  loadStateFor(id: SignalCategory): LoadState {
    return this.loadStates.get(id) ?? LoadState.IDLE;
  }

  /**
   * 取某分类的授权状态。
   */
  authStateFor(id: SignalCategory): AuthStatus {
    return this.authStates.get(id) ?? AuthStatus.NOT_DETERMINED;
  }

  /**
   * 取某分类的信号数量。
   */
  countFor(id: SignalCategory): number {
    return this.signalsFor(id).length;
  }

  /**
   * 已成功读到信号的总数。首页介绍卡会展示这个数字。
   */
  totalSignalCount(): number {
    let sum: number = 0;
    for (const id of CATEGORY_ORDER) {
      sum += this.countFor(id);
    }
    return sum;
  }

  /**
   * 取某分档下的分类列表。
   */
  categoriesOf(s: Sensitivity): SignalCategory[] {
    return categoriesFor(s);
  }

  /* ---------- 采集调度 ---------- */

  /**
   * 并行刷新所有被动分类。应用启动时调用，不会触发任何权限弹窗。
   */
  async refreshPassive(): Promise<void> {
    const jobs: Promise<void>[] = [];
    for (const id of CATEGORY_ORDER) {
      const info = categoryInfo(id);
      if (info !== null && info.sensitivity === Sensitivity.PASSIVE) {
        jobs.push(this.refresh(id));
      }
    }
    await Promise.all(jobs);
  }

  /**
   * 刷新单个分类。
   */
  async refresh(id: SignalCategory): Promise<void> {
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return;
    }
    this.loadStates.set(id, LoadState.LOADING);
    this.revision++;
    try {
      const result: FingerprintSignal[] = await provider.collect();
      this.signals.set(id, result);
      this.loadStates.set(id, LoadState.LOADED);
      this.revision++;
    } catch (e) {
      this.signals.set(id, []);
      this.loadStates.set(id, LoadState.FAILED);
      this.revision++;
    }
  }

  /**
   * 请求权限并采集。用于需授权的分类。
   * 返回是否成功。
   */
  async enableAndRefresh(id: SignalCategory): Promise<boolean> {
    const info = categoryInfo(id);
    if (info === null || info.permission === null) {
      await this.refresh(id);
      return true;
    }

    this.loadStates.set(id, LoadState.LOADING);
    this.revision++;
    const kind: PermissionKind = info.permission;

    // 先看是否已经授权过，避免重复弹窗
    const current: AuthStatus = await PermissionCenter.checkAll(permissionSystemNames(kind));
    this.authStates.set(id, current);

    if (current !== AuthStatus.GRANTED) {
      const result = await PermissionCenter.request(permissionSystemNames(kind));
      this.authStates.set(id, result.status);
      if (result.status !== AuthStatus.GRANTED) {
        this.signals.set(id, []);
        this.loadStates.set(id, LoadState.DENIED);
        this.revision++;
        return false;
      }
    }

    await this.refresh(id);
    return true;
  }

  /**
   * 判断某分类是否已授权（不触发弹窗）。
   */
  async checkAuth(id: SignalCategory): Promise<AuthStatus> {
    const info = categoryInfo(id);
    if (info === null || info.permission === null) {
      return AuthStatus.GRANTED;
    }
    const status: AuthStatus = await PermissionCenter.checkAll(permissionSystemNames(info.permission));
    this.authStates.set(id, status);
    this.revision++;
    return status;
  }

  /* ---------- 实时重采样 ---------- */

  /**
   * 为「活信号」分类启动周期性重采样。
   */
  startLive(id: SignalCategory): void {
    if (this.timers.has(id)) {
      return;
    }
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return;
    }
    const live = provider as LiveSignalProvider;
    if (live.intervalMs === undefined || live.intervalMs <= 0) {
      return;
    }
    const timer: number = setInterval(() => {
      this.refresh(id);
    }, live.intervalMs);
    this.timers.set(id, timer);
  }

  /**
   * 停止某分类的周期性重采样。
   */
  stopLive(id: SignalCategory): void {
    const timer: number | undefined = this.timers.get(id);
    if (timer !== undefined) {
      clearInterval(timer);
      this.timers.delete(id);
    }
  }

  /**
   * 停止全部重采样。页面退出时调用。
   */
  stopAllLive(): void {
    for (const id of this.timers.keys()) {
      this.stopLive(id);
    }
  }

  /* ---------- 系统 Picker 采集 ---------- */

  /**
   * 判断某分类是否需要用户亲手选择（系统 Picker）才能采集。
   * 这类分类不申请任何权限，必须由 UI 上的点击触发。
   */
  supportsPicker(id: SignalCategory): boolean {
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return false;
    }
    const picker = provider as PickerSignalProvider;
    return picker.pickPhotos !== undefined && picker.pickAudio !== undefined;
  }

  /**
   * 唤起照片 / 视频选择器，选择完成后刷新该分类。
   */
  async pickPhotos(id: SignalCategory): Promise<void> {
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return;
    }
    await (provider as PickerSignalProvider).pickPhotos();
    await this.refresh(id);
  }

  /**
   * 唤起音频选择器，选择完成后刷新该分类。
   */
  async pickAudio(id: SignalCategory): Promise<void> {
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return;
    }
    await (provider as PickerSignalProvider).pickAudio();
    await this.refresh(id);
  }

  /**
   * 判断某分类是否支持实时刷新。
   */
  supportsLive(id: SignalCategory): boolean {
    const provider: SignalProvider | undefined = this.providers.get(id);
    if (provider === undefined) {
      return false;
    }
    const live = provider as LiveSignalProvider;
    return live.intervalMs !== undefined && live.intervalMs > 0;
  }
}

/**
 * 全局单例。首页创建一次，详情页直接复用。
 */
export const store: CategoryStore = new CategoryStore();
