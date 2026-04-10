export interface Camera {
  /** 摄像头名称/位置描述 */
  name: string;
  /** 经度 (GCJ-02) */
  lng: number;
  /** 纬度 (GCJ-02) */
  lat: number;
  /** 类型: 1=确认, 2=新增/待确认, 6=六环外 等 */
  type: number;
  /** 更新日期 */
  date: string;
  /** 详情页路径 */
  href: string;
}

export interface CamerasResponse {
  cameras: Camera[];
  updatedAt: string;
  total: number;
}
