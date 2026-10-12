/*
 * GatedProviders.ets
 * Houpe
 *
 * 需要授权的分类采集实现：位置、摄像头、麦克风、媒体库、
 * 运动计步、已安装应用。
 *
 * 所有实现遵循同一原则：只读取计数、类型、型号等元数据，
 * 绝不读取内容本身——联系人姓名、照片像素、录音内容都不碰。
 */

import { geoLocationManager } from '@kit.LocationKit';
import { camera } from '@kit.CameraKit';
import { audio } from '@kit.AudioKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { sensor } from '@kit.SensorServiceKit';
import { bundleManager, common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { FingerprintSignal, SignalEntry, makeSignal, DisplayHint } from '../models/FingerprintSignal';
import { SignalCategory } from '../models/SignalCategory';
import { SignalProvider, LiveSignalProvider, PickerSignalProvider } from '../models/SignalProvider';
import { PlatformContext } from '../support/PlatformShim';
import { formatBytes } from './PassiveProviders';

/**
 * 位置。需 ohos.permission.LOCATION。
 */
export class LocationProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.LOCATION;
  readonly intervalMs: number = 3000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const loc: geoLocationManager.Location | undefined =
        await geoLocationManager.getCurrentLocation({
          priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
          scenario: geoLocationManager.LocationRequestScenario.UNSET,
          timeoutMs: 10000
        });
      if (loc === undefined) {
        out.push(makeSignal('unavailable', cat, '位置', '暂未取到定位结果',
          '系统没有返回坐标。这可能是因为你刚拒绝了授权，或者当前环境没有可用信号。'));
        return out;
      }

      out.push(makeSignal('coordinate', cat, '坐标',
        `${loc.latitude.toFixed(6)}, ${loc.longitude.toFixed(6)}`,
        '位置是最直接的识别手段。两次采样就能把你的活动轨迹勾勒出来，应用不需要知道你的名字。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('纬度', loc.latitude.toFixed(6)),
          new SignalEntry('经度', loc.longitude.toFixed(6)),
          new SignalEntry('精度半径', `${loc.accuracy.toFixed(1)} 米`)
        ]));

      out.push(makeSignal('altitude', cat, '海拔与精度',
        `${loc.altitude.toFixed(1)} 米`,
        '海拔加上精度半径，能推断出你在室内还是室外、处于什么地形。'));

      if (loc.speed >= 0) {
        out.push(makeSignal('speed', cat, '移动速度',
          `${loc.speed.toFixed(2)} 米/秒`,
          '速度值能区分出你是走路、骑车还是在开车。一个持续移动的应用，用这个就能判断你的通勤方式。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('速度', `${loc.speed.toFixed(2)} m/s`),
            new SignalEntry('方向', loc.direction >= 0 ? `${loc.direction.toFixed(0)}°` : '未知')
          ]));
      }
    } catch (e) {
    }
    return out;
  }
}

/**
 * 摄像头。需 ohos.permission.CAMERA。
 */
export class CameraProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.CAMERA;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const ctx = PlatformContext.abilityContext();
      if (ctx === undefined) {
        out.push(makeSignal('none', cat, '摄像头', '无法获取应用上下文',
          '摄像头查询需要应用上下文。当前拿不到，因此没有读取任何信息。'));
        return out;
      }
      const devices: camera.CameraDevice[] = camera.getCameraManager(ctx).getSupportedCameras();
      if (devices.length === 0) {
        out.push(makeSignal('none', cat, '摄像头', '未检测到摄像头',
          '系统没有返回摄像头信息，通常意味着还没授权，或者系统限制了对摄像头清单的查询。'));
        return out;
      }

      const rear: number = devices.filter((c: camera.CameraDevice) =>
        c.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK).length;

      out.push(makeSignal('count', cat, '摄像头数量',
        `${devices.length} 个（后置 ${rear} / 前置 ${devices.length - rear}）`,
        '摄像头数量基本等同于机型的序列号。前摄一颗、后摄几颗，能直接分出机型档位。'));

      out.push(makeSignal('list', cat, '摄像头标识',
        devices.map((c: camera.CameraDevice) => CameraProvider.cameraKey(c)).join('、'),
        '摄像头标识是硬件指纹。它和传感器参数一起，几乎可以唯一确定一台设备的机型。',
        DisplayHint.KEY_VALUE,
        devices.map((c: camera.CameraDevice) =>
          new SignalEntry(CameraProvider.cameraKey(c), `宿主设备 ${c.hostDeviceName}`))));

      out.push(makeSignal('optics', cat, '镜头等效焦距',
        CameraProvider.focalLengthText(devices),
        '等效焦距能反映出这颗镜头的视角范围。它是硬件光学参数，同型号设备完全一致。'));

      out.push(makeSignal('privacy', cat, '本应用的边界',
        '只读硬件清单，不拍照',
        'Houpe 只读取摄像头硬件清单。它不会创建摄像头输入，不会拍下一张照片。'));
    } catch (e) {
    }
    return out;
  }

  private static cameraKey(c: camera.CameraDevice): string {
    const pos: string = c.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT ? '前置' : '后置';
    return `${pos}/${c.cameraType}`;
  }

  private static focalLengthText(devices: camera.CameraDevice[]): string {
    const parts: string[] = [];
    for (const c of devices) {
      const lens: number[] | undefined = c.lensEquivalentFocalLength;
      if (lens !== undefined && lens.length > 0) {
        parts.push(lens.map(v => v.toFixed(0)).join('/'));
      }
    }
    return parts.length > 0 ? parts.join('、') + ' mm' : '未提供';
  }
}

/**
 * 麦克风与音频输入。需 ohos.permission.MICROPHONE。
 */
export class MicrophoneProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.MICROPHONE;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const inputs: audio.AudioDeviceDescriptors =
        audio.getAudioManager().getRoutingManager().getDevicesSync(audio.DeviceFlag.INPUT_DEVICES_FLAG);

      out.push(makeSignal('inputs', cat, '音频输入设备',
        inputs.length > 0 ? inputs.map((d: audio.AudioDeviceDescriptor) => d.name).join('、') : '未知',
        '输入设备清单能告诉你这台设备配了麦克风还是线性耳机，也暴露了你插着什么东西。',
        DisplayHint.KEY_VALUE,
        inputs.map((d: audio.AudioDeviceDescriptor) => new SignalEntry(d.name, `类型 ${d.deviceType}`))));

      out.push(makeSignal('capability', cat, '录音参数',
        '需实际开启录音才能读取',
        '采样率、声道数这类录音参数，要创建录音通道后才可查询。Houpe 承诺不创建任何录音器，因此不读这一项。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('输入设备数', String(inputs.length))
        ]));

      out.push(makeSignal('privacy', cat, '录音提示',
        '本应用不录音',
        'Houpe 申请麦克风权限只是为了展示硬件参数，不会创建任何录音器，也不会读取任何声音。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 媒体选择器（Picker）。
 *
 * 不再申请 READ_IMAGEVIDEO / READ_AUDIO —— 改用系统选择器：
 * 由用户亲手选中哪几项，应用才看得到哪几项。
 * 采集必须由 UI 上的显式点击触发（Picker 不能被后台静默唤起）。
 */
export class MediaPickerProvider implements SignalProvider, PickerSignalProvider {
  readonly category: SignalCategory = SignalCategory.MEDIA;

  /** 最近一次选中的照片 / 视频 URI */
  private photoUris: string[] = [];
  /** 最近一次选中的音频 URI */
  private audioUris: string[] = [];
  /** 用户在选择器里是否勾选了「原图」 */
  private isOriginalPhoto: boolean = false;
  /** 是否已经发生过一次选择（取消也算，用于区分"没选过"与"选了但为空"） */
  private picked: boolean = false;

  /** 唤起系统照片 / 视频选择器。 */
  async pickPhotos(): Promise<void> {
    try {
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE,
        maxSelectNumber: 12
      };
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      this.photoUris = result.photoUris ?? [];
      this.isOriginalPhoto = result.isOriginalPhoto;
      this.picked = true;
    } catch (e) {
      // 用户取消或选择器不可用：不写入任何结果
    }
  }

  /** 唤起系统音频选择器。 */
  async pickAudio(): Promise<void> {
    try {
      const audioPicker: picker.AudioViewPicker = new picker.AudioViewPicker();
      const uris: string[] = await audioPicker.select();
      this.audioUris = uris ?? [];
      this.picked = true;
    } catch (e) {
      // 同上
    }
  }

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;

    // 无论有没有选过，都先把这条路径的边界讲清楚
    out.push(makeSignal('boundary', cat, '这条路径的边界',
      this.picked ? '只看得见你选中的那几项' : '尚未选择任何文件',
      'Houpe 不申请媒体库权限，因此看不到你的媒体库里有什么。' +
      '由系统选择器出面：你选中哪几项，应用才拿得到哪几项，拿到的是临时只读授权。' +
      '对你交出来的这几项，应用能读到文件本身——内容、EXIF、拍摄地点都在里面；' +
      '但对库里其余的一切，它一无所知。'));

    if (!this.picked) {
      return out;
    }

    const uris: string[] = this.photoUris.concat(this.audioUris);
    if (uris.length === 0) {
      out.push(makeSignal('empty', cat, '本次选择结果', '你取消了选择',
        '你没有选中任何文件。这本身就是答案：既不授权、也不选择，应用就什么都拿不到。'));
      return out;
    }

    out.push(makeSignal('counts', cat, '你交出了多少',
      `照片/视频 ${this.photoUris.length} 个 / 音频 ${this.audioUris.length} 个`,
      '交给谁、交多少，是你自己决定的。但每多交出一项，就多一份可被读取的真实数据。',
      DisplayHint.KEY_VALUE,
      [
        new SignalEntry('照片 / 视频', `${this.photoUris.length} 个`),
        new SignalEntry('音频', `${this.audioUris.length} 个`),
        new SignalEntry('合计', `${uris.length} 个`)
      ]));

    if (this.photoUris.length > 0) {
      out.push(makeSignal('originalPhoto', cat, '是否选择「原图」',
        this.isOriginalPhoto ? '是（原图）' : '否（压缩图）',
        '选择器会把你是否勾选原图一并回传。这个开关本身也带信息：' +
        '愿意交原图的人往往也在意画质——一个微小的偏好画像，就是从这里开始的。'));
    }

    // 真实文件名：直接来自磁盘，不是你改过的标题
    const names: SignalEntry[] = [];
    const nameLimit: number = Math.min(uris.length, 8);
    for (let i: number = 0; i < nameLimit; i++) {
      names.push(new SignalEntry(`文件 ${i + 1}`, MediaPickerProvider.baseName(uris[i])));
    }
    out.push(makeSignal('fileNames', cat, '真实文件名',
      MediaPickerProvider.baseName(uris[0]),
      '这是文件在磁盘上的真名，不是相册里你给它改的标题。命名规则本身就是指纹：' +
      '像 P20240915-143012 这种格式，直接交代了设备序列与精确到秒的拍摄时间。',
      DisplayHint.KEY_VALUE,
      names));

    // 媒体库内部 URI：暴露存储位置与稳定编号
    out.push(makeSignal('uris', cat, '媒体库内部路径',
      uris[0],
      '选择器返回的是媒体库内部 URI，暴露了文件的真实存储位置与编号。' +
      '同一台设备上这个编号是稳定的——跨应用串联数据时，它可以当半个身份证用。',
      DisplayHint.KEY_VALUE,
      MediaPickerProvider.uriEntries(uris)));

    // 文件大小：Picker 授予的是临时读权限，能 stat 到真实字节数
    const sizes: SignalEntry[] = [];
    let totalBytes: number = 0;
    for (const uri of uris) {
      const size: number = MediaPickerProvider.sizeOf(uri);
      if (size > 0) {
        totalBytes += size;
        sizes.push(new SignalEntry(MediaPickerProvider.baseName(uri), formatBytes(size)));
      }
    }
    if (sizes.length > 0) {
      out.push(makeSignal('sizes', cat, '文件大小',
        formatBytes(totalBytes),
        '能 stat 到字节数，就意味着能打开文件本身。到了这一步，你选中的那张照片里的' +
        '拍摄时间、设备型号、甚至 GPS 坐标，对应用而言都是可读的。',
        DisplayHint.KEY_VALUE,
        sizes));
    }

    return out;
  }

  /** 取 URI 的末段作为文件名。 */
  private static baseName(uri: string): string {
    const idx: number = uri.lastIndexOf('/');
    return idx >= 0 ? uri.substring(idx + 1) : uri;
  }

  /** 最多列出前 3 条完整 URI，避免列表过长。 */
  private static uriEntries(uris: string[]): SignalEntry[] {
    const out: SignalEntry[] = [];
    const limit: number = Math.min(uris.length, 3);
    for (let i: number = 0; i < limit; i++) {
      out.push(new SignalEntry(`第 ${i + 1} 项`, uris[i]));
    }
    return out;
  }

  /**
   * 读选中文件的真实字节数。
   * Picker 授予临时读权限，因此可以直接 open + stat；失败返回 -1。
   */
  private static sizeOf(uri: string): number {
    try {
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      fs.closeSync(file);
      return stat.size;
    } catch (e) {
      return -1;
    }
  }
}

/**
 * 运动与计步。需 ohos.permission.ACTIVITY_MOTION。
 * 只读取活动类型与当天的步数区间，不读运动轨迹。
 */
export class MotionProvider implements LiveSignalProvider {
  readonly category: SignalCategory = SignalCategory.MOTION;
  readonly intervalMs: number = 10000;

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const pedometer: sensor.Sensor | undefined = sensor.getSingleSensorSync(sensor.SensorId.PEDOMETER);
      const barometer: sensor.Sensor | undefined = sensor.getSingleSensorSync(sensor.SensorId.BAROMETER);

      if (pedometer !== undefined) {
        out.push(makeSignal('pedometerInfo', cat, '计步传感器参数',
          `量程 ${pedometer.maxRange} 步 / 精度 ${pedometer.precision}`,
          '计步器由硬件负责计数，从出厂开始累加，卸载应用也不会清零。它是你活动量的一个长期刻度。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('量程', `${pedometer.maxRange} 步`),
            new SignalEntry('精度', String(pedometer.precision)),
            new SignalEntry('厂商', pedometer.vendorName),
            new SignalEntry('固件版本', pedometer.firmwareVersion)
          ]));
      }

      if (barometer !== undefined) {
        out.push(makeSignal('altimeter', cat, '气压传感器参数',
          `量程 ${barometer.maxRange} / 精度 ${barometer.precision}`,
          '气压计能测出气压变化，从而推断出你所在的海拔。它是硬件参数，同型号设备完全一致。',
          DisplayHint.KEY_VALUE,
          [
            new SignalEntry('量程', String(barometer.maxRange)),
            new SignalEntry('分辨率', String(barometer.precision)),
            new SignalEntry('最小采样周期', `${barometer.minSamplePeriod} ns`),
            new SignalEntry('厂商', barometer.vendorName)
          ]));
      }

      out.push(makeSignal('activity', cat, '活动类型传感器',
        '需更高权限读取',
        '系统把"你在走路还是在开车"这类判断交给了独立的活动识别通道。' +
        '这类数据的识别力很强，因此系统做了更严格的授权控制。'));

      out.push(makeSignal('privacy', cat, '本应用的边界',
        '只读步数总量，不读轨迹',
        'Houpe 只读取累计步数与气压计硬件参数。它不会记录你走过哪条路、去了哪里。'));
    } catch (e) {
    }
    return out;
  }
}

/**
 * 已安装应用探测。需 ohos.permission.GET_BUNDLE_INFO。
 *
 * 这一类对应 iOS 版本里的 URL scheme 探测：应用能查询到你装了哪些
 * 第三方应用，进而推断你的兴趣、职业与消费习惯。
 */
export class InstalledAppsProvider implements SignalProvider {
  readonly category: SignalCategory = SignalCategory.INSTALLED_APPS;

  /**
   * 探测清单：常见第三方应用的 bundleName 前缀。
   * 系统只允许查询已上架应用，且不返回应用名称以外的信息。
   */
  private static readonly PROBES: string[] = [
    'com.tencent.mm', 'com.tencent.mobileqq', 'com.tencent.wework',
    'com.ss.android.ugc.aweme', 'com.sina.weibo', 'com.xingin.xhs',
    'com.zhihu.android', 'com.douban.frodo', 'com.taobao.taobao',
    'com.jingdong.app.mall', 'com.xunmeng.pinduoduo', 'com.alibaba.android.rimet',
    'com.tencent.qqmusic', 'com.netease.cloudmusic', 'com.kugou.android',
    'com.smile.gifmaker', 'com.ss.android.ugc.aweme.lite',
    'com.microsoft.office.outlook', 'com.tencent.docs', 'com.alibaba.android.calendar',
    'com.autonavi.minimap', 'com.baidu.BaiduMap', 'com.tencent.map',
    'com.unionpay', 'com.icbc', 'com.chinamworld.main',
    'com.youku.phone', 'com.qiyi.video', 'com.tencent.qqlive',
    'com.hunantv.imgo.activity', 'com.netease.mail',
    'com.eg.android.AlipayGphone', 'com.alipay.android.app',
    'com.zoom.us', 'com.tencent.meeting',
    'com.microsoft.teams', 'com.slack', 'com.google.android.apps.messaging',
    'com.whatsapp', 'com.zhiliaoapp.musically', 'com.facebook.katana',
    'com.instagram.android', 'com.twitter.android', 'com.reddit.frontpage',
    'com.linkedin.android', 'com.pinterest', 'com.tiktok',
    'com.spotify.music', 'com.netflix.mediaclient', 'com.bilibili.app.in',
    'com.duolingo', 'com.github.android', 'com.termux',
    'com.paypal.android.p2pmobile', 'com.coinbase.android'
  ];

  async collect(): Promise<FingerprintSignal[]> {
    const out: FingerprintSignal[] = [];
    const cat: string = this.category as string;
    try {
      const installed: string[] = [];
      for (const probe of InstalledAppsProvider.PROBES) {
        const found: boolean = await InstalledAppsProvider.isInstalled(probe);
        if (found) {
          installed.push(probe);
        }
      }

      out.push(makeSignal('count', cat, '探测到的应用数',
        `${installed.length} / ${InstalledAppsProvider.PROBES.length}`,
        '应用可以通过包管理接口探测你装了哪些应用。这是 iOS 版本里用 URL scheme 探测的等价手段，' +
        '目的都是知道你的兴趣与习惯。',
        DisplayHint.KEY_VALUE,
        [
          new SignalEntry('探测目标', `${InstalledAppsProvider.PROBES.length} 个常见应用`),
          new SignalEntry('探测到', `${installed.length} 个`)
        ]));

      if (installed.length > 0) {
        out.push(makeSignal('list', cat, '已探测到的应用',
          installed.join('、'),
          '装了什么应用，往往比任何一份表单都更能说明你是谁。你装了哪些社交、办公、理财应用，' +
          '直接反映了你的职业、生活方式和关注点。',
          DisplayHint.TAGS,
          installed.map((p: string) => new SignalEntry('应用', p))));
      } else {
        out.push(makeSignal('none', cat, '已探测到的应用',
          '未探测到任何已上架应用',
          '系统可能限制了包信息查询的范围，也可能这些应用都不在你的设备上。'));
      }

      out.push(makeSignal('privacy', cat, '本应用的边界',
        '只判断是否安装',
        'Houpe 只判断应用是否存在，不读取任何应用的数据、不启动它们、不获取它们的通知内容。'));
    } catch (e) {
    }
    return out;
  }

  /**
   * 判断某个 bundleName 是否已安装。
   */
  private static async isInstalled(bundleName: string): Promise<boolean> {
    try {
      const info: bundleManager.BundleInfo = await bundleManager.getBundleInfo(bundleName,
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE);
      return info !== undefined && info.name !== undefined;
    } catch (e) {
      return false;
    }
  }
}
