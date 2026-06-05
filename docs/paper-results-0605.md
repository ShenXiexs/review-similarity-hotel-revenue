# Results-0605

## Route A 思考

M0.1 Baseline

- `sim_mean = -0.1570`, `p = 0.007`
- 结论：基线主效应显著负向。含义：在这批 `focus100` 市场边界样本里，ARS 越高，RevPAR 越低。

### 竞争机制？

M0.2 `hi_compavg 在 `focus100 ` 样本里按中位数切成低组 / 高组`

这个是竞争者的利润

- `sim_mean = .7777166`, `p = 0.019`
- `sim_mean × ln_avg_com_RevPAR = -.216636`, `p = 0.004`
- 结论：交互显著负向。含义：周围竞争者平均 RevPAR 越高，ARS 的负效应越强。
- 分组回归的结果：低竞争 sim_mean |  -.0847985   .0700577    -1.21   0.227；高竞争 sim_mean |  -.1531395   .0601196    -2.55   0.011

M1 `high_comp_zip_focus100 在 `focus100 `样本里按`zip_n_full ` 中位数切成 0/1（M3做的是直接拿连续的来）`

这个是同zip内酒店的数量！

- `sim_mean = -.17338`, `p = 0.005`
- `sim_mean × high_comp_zip_focus100 = .0651003`, `p = 0.445`
- 结论：ZIP 高竞争 dummy 没有显著改变 ARS slope。

分组回归：

- 低 ZIP competition：`sim_mean = -.0569126`, `p = 0.377`
- 高 ZIP competition：`sim_mean = -.2103785`, `p = 0.004`

这说明高 ZIP competition 组里 ARS 更负，但交互项本身不显著，分组回归差异明显，组间差异通过0.05

M2 `high_comp_city_focus100 在 `focus100 `样本里按`city_n_full ` 中位数切成 0/1（M4类似，只是做了连续的，差异不大)`

这个是同City内酒店的数量！

结果不好，差异不明显，我的理解是按照city分细粒度不够，没有zip好

M5 ZIP competitor RevPAR

- 变量基础：`ln_comp_zip_mean_excl_full，减去mean得到ln_comp_zip_full_c`
- 含义：同 ZIP 其他酒店的平均 RevPAR 水平，分组方式：中位数切组
- 解释：低 ZIP competitor RevPAR 环境 vs 高 ZIP competitor RevPAR 环境
- `c.sim_mean × c.ln_comp_zip_full_c =  -.2398413`, `p = 0.029`

  分组回归，都显著为负，无法区分
- 低 ZIP competitor RevPAR：`sim_mean = -.1434568`, `p = 0.035`
- 高 ZIP competitor RevPAR：`sim_mean = -.1912956 `, `p = 0.020`

M6 City competitor RevPAR

- 就是刚刚的zip换成city
- 解释：低 City competitor RevPAR 环境 vs 高 City competitor RevPAR 环境
- `c.sim_mean × c.ln_comp_city_full_c =  -.4363411`, `p = 0.007`

  分组回归，都显著为负，无法区分
- 低 ZIP competitor RevPAR：`sim_mean = -.1255386`, `p = 0.034`
- 高 ZIP competitor RevPAR：`sim_mean = -.1870382 `, `p = 0.011`

M7 ZIP positioning gap

- `sim_mean × gap_zip_full_c = 0.0763`, `p = 0.800`
- 结论：ZIP 相对定位偏离没有显著调节 slope。

  分组回归：
- 低 ZIP gap：`sim_mean = -0.2695`, `p = 0.002`
- 高 ZIP gap：`sim_mean = -0.1020`, `p = 0.115`

这里最有意思的不是交互项，而是分组结果：越贴近本地 ZIP 竞争带的酒店，ARS 负效应越强。

M8 ZIP positioning gap

- `sim_mean × gap_city_full_c = 0.7054`, `p = 0.119`
- 结论：方向上像是 city gap 越大，ARS 负效应越弱，但交互不显著。

  分组回归：
- 低 city gap：`sim_mean = -0.1976`, `p = 0.024`
- 高 city gap：`sim_mean = -0.1111`, `p = 0.087`

  和 M7 一样，更贴近本地竞争均值的酒店，ARS 伤害更强。

M9 revenue gap

- `sim_mean × price_gap_c = -0.1258`, `p = 0.179`
- 结论：交互不显著。

    分组回归：

- 低 price gap：`sim_mean = -0.2890`, `p < 0.001`
- 高 price gap：`sim_mean = -0.0761`, `p = 0.284`

    这条也和 M7-M8 一致：价格位置更贴近市场主流带时，ARS 的负效应更强。

### 酒店异质性？

M0-4 Chain or Independent

- 交互做不出来，因为数据集中可以确认的chain数量太少
- 分组结果：
- chain：`sim_mean = -.0747849`, `p = 0.366`
- independent：`sim_mean =  -.2034301`, `p = 0.003`

M5-7 Star

- `sim_mean × star_class 交互效果不好！`
- 分组回归：
- 低于4星：`sim_mean = -.1960289`, `p = 0.009`
- 高于等于4星：`sim_mean = -.0320783`, `p = 0.817`

M8 Quality 1

- 只做ym，不区分city或者zip
- 交互项不显著，分组回归无差异，都很负面显著

M9 Quality 2

- 做city ym
- 交互项不显著，分组回归无差异，都很负面显著
- 低于4星：`sim_mean = -.1960289`, `p = 0.009`
- 高于等于4星：`sim_mean = -.0320783`, `p = 0.817`

M10 Quality 3

- 做zip ym
- 交互项不显著，分组回归差异不够显著：
- 低质量：`sim_mean = -.1896466`, `p = 0.012`
- 高于等于4星：`sim_mean = -.1015184`, `p = 0.259`

M11 Rank

- 交互项不显著
- 分组回归差异不够显著：
- 低Rank：`sim_mean = -.2519876`, `p = 0.006`
- 高Rank：`sim_mean = -.1319709`, `p = 0.105`

M12 Evaluation

- 交互项不显著
- 分组回归无差异：

M13 Popularity

- 交互项不显著
- 分组回归无论是ym，还是Zip-ym还是City-ym，差异均显著通过，这里记录Zip ym：
- 低Popularity：`sim_mean = -.0627773`, `p = 0.355`
- 高Popularity：`sim_mean = -.1728831`, `p = 0.012`

### 产品异质性？（比酒店维度更加细）

Vertical1 Star 见上M5-7 Star

Vertical2 tp_quality_index 结果与上面的M10 Quality 3类似

egen double tp_quality_index = rowmean(
    hotel_avg_rating
    hotel_location_rating
    hotel_rooms_rating
    hotel_value_rating
    hotel_cleanliness_rating
    hotel_service_rating
    hotel_sleep_quality_rating
)

- 交互项不显著，只有在根据zip-ym分组中位数时才有分组差异，但差异不显著
- 低quality：`sim_mean = -.2112566 `, `p = 0.028`
- 高quality：`sim_mean = -.1474416`, `p = 0.036`

Vertical3 tp_rank_pct，类似前面的M11 Rank，不过M11是直接根据0.5来划分

* 数值越小，排名越靠前，酒店地位越高
  * 例如 2/7 = 0.286
* 数值越大，排名越靠后，酒店地位越低
  * 例如 80/120 = 0.667

- 交互项不显著
- 分组回归无论是ym，还是Zip-ym还是City-ym，差异均显著通过，其中Zip ym最好！这里记录Zip ym：
- 低Rank：`sim_mean = -.1978401`, `p = 0.036`
- 高Rank：`sim_mean = -.0750179`, `p = 0.423`

Horizontal1 hotel_amenities

* **hotel_amenities** 里每个设施通常用逗号分隔
* 就通过“逗号个数 + 1”来近似设施条目数

- 交互项不显著
- 分组回归无论是ym，还是Zip-ym还是City-ym，差异均显著通过，其中Zip ym最好！这里记录Zip ym：
- 低：`sim_mean = -.0785471`, `p = 0.342`
- 高：`sim_mean = -.1916255`, `p = 0.016`
- 越多amenities，不确定反而更强，因为产品内容变丰富了

Horizontal2-4 是对amenities细分，结果都不太行，也不好做

Horizontal5 Upscale-style boundary

* **style_upscale = 1**
  * **hotel_style** 文本里出现了偏高端/精品/现代时尚的风格标签
  * gen byte style_luxury = regexm(hotel_style_lc, "luxury|romantic|boutique")
    gen byte style_modern = regexm(hotel_style_lc, "modern|trendy")
* 交互项在0.1水平显著 style_upscale x sim_mean `= -.1465048`, `p = 0.097`
* 分组组间差异不通过
* 不提及：`sim_mean = -.1398467`, `p = 0.062`
* 提及：`sim_mean = -.2439263`, `p = 0.022`

Horizontal6 Luxury 最后因为样本差距过大没有出结果，但是从系数上推测，确实是luxury的负面效应更强

Horizontal7 Travelers' choice

* 交互项为正不显著
* 分组组间差异通过，choice那个不确定性更小，当然效应小
* No：`sim_mean = -.2196253`, `p = 0.003`
* Yes：`sim_mean = -.0429212`, `p = 0.820`

Price1 ln_tp_price_mid

* 交互项为正不显著
* 分组Zip ym，组间差异通过
* No：`sim_mean = -.0615404`, `p = 0.535`
* Yes：`sim_mean = -.2696573`, `p = 0.006`
* 同一个Zip下同一个ym，在其他条件控制的前提下，高价酒店期望更高也更需要降低不确定性

Price1 ln_tp_price_mid

* 交互项为正不显著
* 分组Zip ym，组间差异通过
* No：`sim_mean = -.0615404`, `p = 0.535`
* Yes：`sim_mean = -.2696573`, `p = 0.006`
* 同一个Zip下同一个ym，在其他条件控制的前提下，高价酒店期望更高也更需要降低不确定性
