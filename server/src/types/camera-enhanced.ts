/**
 * 摄像头方向类型
 * 表示摄像头的拍摄方向
 */
export enum CameraDirection {
  EAST_WEST = 'east_west',      // 东向西
  WEST_EAST = 'west_east',      // 西向东
  SOUTH_NORTH = 'south_north',  // 南向北
  NORTH_SOUTH = 'north_south',  // 北向南
  EAST = 'east',                // 向东
  WEST = 'west',                // 向西
  SOUTH = 'south',              // 向南
  NORTH = 'north',              // 向北
  UNKNOWN = 'unknown',           // 未知方向
}

/**
 * 摄像头类型 (aa 字段) — 来自 jinjing365.com LabelsData
 * 1 = 只拍晚高峰（301 条）
 * 2 = 六环内全时段（4615 条，最多）
 * 4 = 待核实/特殊情况（60 条，含辅路/需进一步确认等）
 * 5 = 晚高峰 + 六环内（67 条）
 * 6 = 六环外（782 条）
 */
export enum CameraType {
  PEAK_HOUR_ONLY = 1,           // 只拍晚高峰
  INSIDE_SIXTH_RING = 2,        // 六环内（全时段）
  UNVERIFIED = 4,               // 待核实/特殊情况
  PEAK_HOUR_INSIDE_RING = 5,    // 晚高峰 + 六环内
  OUTSIDE_SIXTH_RING = 6,       // 六环外
}

/**
 * 摄像头状态标识
 * 从 name 字段中解析出来
 */
export interface CameraStatus {
  /** 是否处于试用期 */
  isPilot: boolean;
  /** 是否位置待确认 */
  isLocationUnconfirmed: boolean;
  /** 是否仅在高峰期拍摄 */
  isPeakHourOnly: boolean;
  /** 是否在六环外 (aa=6) */
  isOutsideSixthRing: boolean;
  /** 是否为待核实/特殊情况 (aa=4) */
  isUnverified: boolean;
  /** 是否为最近7天新增 (time 字段距今 < 7天) */
  isNewlyAdded: boolean;
  /** 其他特殊标识 */
  otherFlags: string[];
}

/**
 * 增强的摄像头数据模型
 */
export interface EnhancedCamera {
  // 基本信息
  id: string;
  name: string;
  /** 经度 (GCJ-02) */
  lng: number;
  /** 纬度 (GCJ-02) */
  lat: number;

  // 详细信息
  /** 摄像头类型 (aa): 1=只拍晚高峰, 2=六环内, 5=晚高峰+六环内, 6=六环外 */
  type: CameraType;
  /** 摄像头拍摄方向 */
  direction: CameraDirection;
  /** 更新日期 */
  date: string;
  /** 编辑时间 */
  editTime?: string;
  /** 详情页链接 */
  href: string;

  // 解析的状态信息
  status: CameraStatus;

  // 从 name 中提取的信息
  /** 区名称 */
  district?: string;
  /** 具体位置描述 */
  location?: string;
  /** 道路名称 */
  road?: string;
}

/**
 * 向量方向（用于计算路线是否会被摄像头拍到）
 */
export interface VectorDirection {
  /** 起点坐标 */
  from: { lat: number; lng: number };
  /** 终点坐标 */
  to: { lat: number; lng: number };
  /** 方向角度（0-360度，0=正北，90=正东） */
  bearing: number;
}

/**
 * 摄像头拍摄方向的向量表示
 */
export const CAMERA_DIRECTION_VECTORS: Record<CameraDirection, number> = {
  [CameraDirection.EAST_WEST]: 270,    // 西
  [CameraDirection.WEST_EAST]: 90,     // 东
  [CameraDirection.SOUTH_NORTH]: 0,    // 北
  [CameraDirection.NORTH_SOUTH]: 180,  // 南
  [CameraDirection.EAST]: 90,          // 东
  [CameraDirection.WEST]: 270,         // 西
  [CameraDirection.SOUTH]: 180,        // 南
  [CameraDirection.NORTH]: 0,          // 北
  [CameraDirection.UNKNOWN]: -1,       // 未知
};
