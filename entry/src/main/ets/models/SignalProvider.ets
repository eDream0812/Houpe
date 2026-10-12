/*
 * SignalProvider.ets
 * Houpe
 *
 * 采集协议。每个隐私面对应一个 Provider 实现，
 * 由 CategoryStore 统一调度。
 *
 * 全部实现只读取本机数据，不发起任何网络请求。
 */

import { FingerprintSignal } from './FingerprintSignal';
import { SignalCategory } from './SignalCategory';

/**
 * 采集协议。
 */
export interface SignalProvider {
  /** 本 Provider 负责的分类 */
  readonly category: SignalCategory;

  /**
   * 执行采集。所有实现必须同步返回或以 Promise 返回，
   * 不得抛出未捕获异常——失败请返回空数组。
   */
  collect(): Promise<FingerprintSignal[]>;
}

/**
 * 支持周期性重采样的"活信号" Provider。
 * 电量、网络这类值会随时间变化，采集一次意义不大。
 */
export interface LiveSignalProvider extends SignalProvider {
  /** 重采样间隔，毫秒 */
  readonly intervalMs: number;
}

/**
 * 需要用户亲手选择才能采集的 Provider（系统 Picker）。
 *
 * 这类采集不申请任何权限：由系统选择器出面，用户选中哪几项，
 * 应用才看得到哪几项——看不到媒体库里其余的任何东西。
 * 采集必须由 UI 上的显式点击触发（Picker 不能被后台静默唤起）。
 */
export interface PickerSignalProvider extends SignalProvider {
  /** 唤起系统照片/视频选择器，并把结果写入 Provider */
  pickPhotos(): Promise<void>;

  /** 唤起系统音频选择器，并把结果写入 Provider */
  pickAudio(): Promise<void>;
}
