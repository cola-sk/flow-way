export interface Camera {
  /** 摄像头名称/位置描述 */
  name: string;
  /** 经度 (GCJ-02) */
  lng: number;
  /** 纬度 (GCJ-02) */
  lat: number;
  /** 类型 (aa): 1=只拍晚高峰, 2=六环内, 5=晚高峰+六环内, 6=六环外 */
  type: number;
  /** 更新日期 (time 字段) */
  date: string;
  /** 编辑时间 (edittime 字段) */
  edittime?: string;
  /** 详情页路径 */
  href: string;
}

export interface CamerasResponse {
  cameras: Camera[];
  updatedAt: string;
  total: number;
}
