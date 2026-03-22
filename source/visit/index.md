---
title: 访问统计
date: 2022-06-23 15:29:18
comments: false
preview: /media/external/www.panshenlian.com/images/post/me/share/visit.jpg
introduce: |
    本站访问概况展示（本地演示数据，不依赖第三方统计 API；可自行替换数据源）。
---

<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" crossorigin="anonymous">

> **说明**：本页已改为 **纯前端展示**，使用 `ECharts` 渲染**演示数据**，不连接竹白、`open.zhubai.wiki` 或任何外部统计接口。  
> 若需真实数据，可将下方 `DEMO_STATS` 换为自建接口返回的 JSON，或部署后由 CI 写入静态 `stats.json` 再 `fetch` 加载。

<style>
  .visit-wrap { max-width: 960px; }
  .visit-chart { width: 100%; height: 380px; margin: 1rem 0; }
  #visit-user-track .table { font-size: 14px; }
</style>

## 访客来源（演示）

<div class="visit-chart" id="chart-source"></div>

## 流量趋势（演示）

<div class="visit-chart" id="chart-trend"></div>

## 最近访问轨迹（演示）

<div id="visit-user-track" class="visit-wrap table-responsive"></div>

<script src="https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js" crossorigin="anonymous"></script>
<script>
(function () {
  var DEMO_STATS = {
    source: [
      { name: '直接访问', value: 42 },
      { name: '搜索引擎', value: 28 },
      { name: '外链引荐', value: 18 },
      { name: 'RSS / 订阅', value: 12 }
    ],
    trend: {
      days: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      ip: [12, 18, 15, 22, 19, 8, 14],
      pv: [28, 35, 32, 48, 41, 18, 30]
    },
    tracks: [
      { ip: '192.0.2.*', action: '首页', ref: '直接访问', device: 'Desktop / Chrome', time: '2026-03-21 10:12' },
      { ip: '198.51.100.*', action: '/list/', ref: '搜索引擎', device: 'Mobile / Safari', time: '2026-03-21 09:40' },
      { ip: '203.0.113.*', action: '/2026/03/21/ai-001-latest-trends/', ref: '技术日志', device: 'Desktop / Edge', time: '2026-03-21 08:05' }
    ]
  };

  function pie() {
    var el = document.getElementById('chart-source');
    if (!el || typeof echarts === 'undefined') return;
    var chart = echarts.init(el);
    chart.setOption({
      tooltip: { trigger: 'item' },
      legend: { bottom: 0 },
      series: [{
        name: '来源',
        type: 'pie',
        radius: ['36%', '68%'],
        data: DEMO_STATS.source
      }]
    });
    window.addEventListener('resize', function () { chart.resize(); });
  }

  function line() {
    var el = document.getElementById('chart-trend');
    if (!el || typeof echarts === 'undefined') return;
    var chart = echarts.init(el);
    chart.setOption({
      tooltip: { trigger: 'axis' },
      legend: { data: ['独立访客(演示)', '浏览量(演示)'] },
      xAxis: { type: 'category', data: DEMO_STATS.trend.days },
      yAxis: { type: 'value' },
      series: [
        { name: '独立访客(演示)', type: 'line', smooth: true, data: DEMO_STATS.trend.ip },
        { name: '浏览量(演示)', type: 'line', smooth: true, data: DEMO_STATS.trend.pv }
      ]
    });
    window.addEventListener('resize', function () { chart.resize(); });
  }

  function table() {
    var wrap = document.getElementById('visit-user-track');
    if (!wrap) return;
    var rows = DEMO_STATS.tracks.map(function (r) {
      return '<tr><td>' + r.ip + '</td><td>' + r.action + '</td><td>' + r.ref + '</td><td>' + r.device + '</td><td>' + r.time + '</td></tr>';
    }).join('');
    wrap.innerHTML =
      '<table class="table table-striped table-bordered">' +
      '<thead><tr><th>访问 IP（脱敏）</th><th>页面</th><th>来源</th><th>设备</th><th>时间</th></tr></thead>' +
      '<tbody>' + rows + '</tbody></table>' +
      '<p class="text-muted small mt-2">上表为示例行，非真实日志。接入自有后端时可替换此区域。</p>';
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { pie(); line(); table(); });
  } else {
    pie(); line(); table();
  }
})();
</script>
