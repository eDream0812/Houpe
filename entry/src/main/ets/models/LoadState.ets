/*
 * LoadState.ets
 * Houpe
 *
 * 分类的加载状态。
 */

export enum LoadState {
  /** 未开始读取 */
  IDLE = 'idle',
  /** 正在读取 */
  LOADING = 'loading',
  /** 已读取完成 */
  LOADED = 'loaded',
  /** 权限被拒绝 */
  DENIED = 'denied',
  /** 读取失败 */
  FAILED = 'failed'
}
