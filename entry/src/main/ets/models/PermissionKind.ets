/*
 * PermissionKind.ets
 * Houpe
 *
 * 权限种类。每种权限都带一段"这个权限能泄漏什么"的教育文案，
 * 展示在权限门禁页上。
 */

import { Sensitivity, SensitivityInfo, sensitivityInfo } from './Sensitivity';

export enum PermissionKind {
  /** 传感器与计步 */
  MOTION = 'motion',
  /** 位置 */
  LOCATION = 'location',
  /** 摄像头 */
  CAMERA = 'camera',
  /** 麦克风与音频输入 */
  MICROPHONE = 'microphone',
  /** 已安装应用 */
  BUNDLE = 'bundle'
}

/**
 * 取权限的展示名。
 */
export function permissionTitle(kind: PermissionKind): string {
  switch (kind) {
    case PermissionKind.MOTION:
      return '运动与传感器';
    case PermissionKind.LOCATION:
      return '位置信息';
    case PermissionKind.CAMERA:
      return '摄像头';
    case PermissionKind.MICROPHONE:
      return '麦克风';
    default:
      return '已安装应用';
  }
}

/**
 * 取权限的风险说明文案。这段话会直接展示给用户，
 * 是整个权限门禁页最重要的一行字。
 */
export function permissionRationale(kind: PermissionKind): string {
  switch (kind) {
    case PermissionKind.MOTION:
      return '读取加速度计、陀螺仪等传感器的原始读数。静止时这些数值几乎相同，一旦你拿起手机，模式立刻改变。任何应用只要在你移动时连续采样，就能用运动模式识别出这是不是你。';
    case PermissionKind.LOCATION:
      return '读取你的精确坐标、海拔、速度与航向。位置是最直接的识别手段，两次采样就能把你的活动轨迹勾勒出来。应用不需要知道你的名字。';
    case PermissionKind.CAMERA:
      return '读取摄像头硬件的型号、位置与视场角。即使不拍照，硬件清单本身在同款机型上是相同的，可以用来缩小你的设备范围。';
    case PermissionKind.MICROPHONE:
      return '读取当前音频输入设备与音频路由信息。搭配录音权限，应用能判断你周围是否有声音、在什么音量下。';
    case PermissionKind.BUNDLE:
      return '查询你设备上已安装的应用清单。装了什么应用，往往比任何表单都更能说明你是谁、你在意什么。';
    default:
      return '';
  }
}

/**
 * 取权限对应的系统权限名列表（ohos.permission.*）。
 * 精确定位要求同时申请模糊与精确两个权限，因此返回数组。
 */
export function permissionSystemNames(kind: PermissionKind): string[] {
  switch (kind) {
    case PermissionKind.MOTION:
      return ['ohos.permission.ACTIVITY_MOTION'];
    case PermissionKind.LOCATION:
      // 单独申请 LOCATION 会失败，必须与 APPROXIMATELY_LOCATION 同请求
      return ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    case PermissionKind.CAMERA:
      return ['ohos.permission.CAMERA'];
    case PermissionKind.MICROPHONE:
      return ['ohos.permission.MICROPHONE'];
    default:
      return ['ohos.permission.GET_BUNDLE_INFO'];
  }
}

/**
 * 取权限对应的敏感度分档。所有需授权的分类统一归入"需要授权"档。
 */
export function permissionSensitivity(kind: PermissionKind): SensitivityInfo {
  return sensitivityInfo(Sensitivity.PERMISSIONED);
}

/**
 * 取门禁页底部状态提示。
 */
export function permissionStatusHint(): string {
  return '点击下方按钮会弹出系统授权提示。你随时可以在系统设置里撤回授权。';
}

/**
 * 取被拒绝后的补充提示。
 */
export function permissionDeniedHint(): string {
  return '你也可以稍后在「设置 - 隐私」里重新开启这个权限。';
}
