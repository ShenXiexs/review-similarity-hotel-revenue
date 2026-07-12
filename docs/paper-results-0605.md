# Results-0605

## Route A 思考

M0.1 Baseline

- `sim_mean = -0.1570`, `p = 0.007`
- 结论：基线主效应显著负向。含义：在这批 `focus100` 市场边界样本里，ARS 越高，RevPAR 越低。

### 竞争机制？

M0.2 `hi_compavg 在 `focus100 ` 样本里按中位数切成低组 / 高组`

这个作为价格可能更好

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
- 低 ZIP num：`sim_mean = -.1434568`, `p = 0.035`
- 高 ZIP num：`sim_mean = -.1912956 `, `p = 0.020`

M6 City competitor RevPAR

- 就是刚刚的zip换成city
- 解释：低 City competitor RevPAR 环境 vs 高 City competitor RevPAR 环境
- `c.sim_mean × c.ln_comp_city_full_c =  -.4363411`, `p = 0.007`

  分组回归，都显著为负，无法区分
- 低 City revenue：`sim_mean = -.1255386`, `p = 0.034`
- 高 City revenue：`sim_mean = -.1870382 `, `p = 0.011`

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

样本差太大

- 交互做不出来，因为数据集中可以确认的chain数量太少
- 分组结果：
- chain：`sim_mean = -.0747849`, `p = 0.366`
- independent：`sim_mean =  -.2034301`, `p = 0.003`

M5-7 Star

暂时保留

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

酒店排位/总数

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

*选择维度，或者分类，看哪个维度影响更大*

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

风格偏向：商务要求没那么高，经济型要求没那么高

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

比星级更好

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

### Review探索

E1 recent_sd

和sim_mean构建共线

* 交互项为正不显著
* 分组Zip ym，组间差异通过
* 低SD：`sim_mean = -.2966674 `, `p = 0.003`
* 高SD：`sim_mean = -.1367903`, `p = 0.228`

E2 sd_acc

* 交互项为正不显著
* 分组Zip ym，组间差异通过
* 低SD：`sim_mean = -.0687084 `, `p = 0.494`
* 高SD：`sim_mean = -.1367903`, `p = 0.029`

E3 sent_net_pos_bing

* **Bing 文本情感的净正向指标**，越高正面文本明显多于负面文本，评论语气更净正向
* 交互项不显著
* 组间差异在0.05水平显著
* 低：`sim_mean =  -.2444491 `, `p = 0.009`
* 高：`sim_mean = -.0669176`, `p = 0.480`

E4 prevvis_sent_avg_bing

* Previous-visible-month average-Bing
* 交互项不显著
* 组间差异不够显著
* 低：`sim_mean =  -.0790583 `, `p = 0.435`
* 高：`sim_mean = -.1896518`, `p = 0.032`

E5 prevvis_sent_avg_bing

* prevvis_sent_net_pos_bing
* 交互项不显著
* 组间差异不够显著
* 低：`sim_mean =  -.2593557 `, `p = 0.007`
* 高：`sim_mean = -.1305891`, `p = 0.216`

## Route B 思考

### Management Response

G1 lag_mr_any

* 上月是否有回复
* 交互项不显著
* 组间无差异
* No：`sim_mean =  -.2593557 `, `p = 0.007`
* Yes：`sim_mean = -.1305891`, `p = 0.216`

G2 lag reply rate

* 上月回复的比率
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean =  -.3070832 `, `p = 0.005`
* 高：`sim_mean = -.129462`, `p = 0.235`
* 回复可以削弱simi的负面作用

G3 lag reply count

* 上月回复的数量
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean =  -.3041511 `, `p = 0.003`
* 高：`sim_mean = -.1061554`, `p = 0.334`
* 回复可以削弱simi的负面作用

G4 ln_lag_mr_words

* 上月回复的单词总数
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean =  -.2567747 `, `p = 0.010`
* 高：`sim_mean = -.0977821`, `p = 0.367`
* 回复长度可以削弱simi的负面作用

G5 ln_lag_mr_avg_words

* 上月回复的单词平均数
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean =  -.2805658 `, `p = 0.005`
* 高：`sim_mean = -.1626935`, `p = 0.114`
* 回复长度可以削弱simi的负面作用

G6 lag_mr_quick7_share

* 七天内回复的比例（回复速度）
* 交互项不显著
* Zip ym 组间无差异

G7 lag_mr_quick30_share

* 三十天内回复的比例（回复速度）
* 交互项不显著
* Zip ym 组间差异不够显著
* 低：`sim_mean =  -.2393193 `, `p = 0.062`
* 高：`sim_mean = -.1454523`, `p = 0.319`
* 回复快速可以削弱simi的负面作用

G8 lag_mr_avg_resp_days

* 平均回复天数（回复速度）
* 交互项不显著
* Zip ym 组间差异显著
* 慢：`sim_mean =  -.2671112 `, `p = 0.009`
* 快：`sim_mean = -.0666561`, `p = 0.522`
* 回复快速可以削弱simi的负面作用

G9 Reply Tone: thanks wording

* 感谢词组在回复中的占比
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean = -.365763 `, `p = 0.002`
* 高：`sim_mean = -.1680314`, `p = 0.149`
* 回复包含感谢语气可以削弱simi的负面作用

G10 Reply Tone: apology wording

* 道歉词组在回复中的占比
* 交互项不显著
* Zip ym 组间无差异显著

G11 Reply Tone: welcome wording

    先在 reply-level 文本里识别每条 management response 是否包含**invite** 话术
	也就是类似：

* welcome back
* look forward to seeing you again
* visit us again
* come back soon
  这一类 pattern
* 平均回复天数（回复速度）
* 交互项显著：`sim_mean x lag_mr_invite_share = .49511 `, `p = 0.006`
* Zip ym 组间差异不显著

G12 Reply Tone: recovery-wording

* **所有管理回复里，有多大比例是在用“补救/善后”风格回应评论**的占比
* pology / sorry
* regret
* please contact us
* make it right
* resolve the issue
* address your concern
* 交互项不显著
* Zip ym 组间无差异显著，样本量太少了

G13 Reply Tone: positive-wording

* **所有管理回复里，有多大比例是在积极风格回应评论**的占比
* 交互项不显著
* Zip ym 组间无差异显著

G14 Reply Tone: negative-wording

* **所有管理回复里，有多大比例是**问题导向回应评论的占比
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean = -.4843193`, `p = 0.060`
* 高：`sim_mean = -.1184456`, `p = 0.369`
* 回复包含问题导向即解决问题，可以削弱simi的负面作用

G15 Personalization

* 提到顾客名称，提到具体入住经历/具体问题
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean = -.2922835`, `p = 0.022`
* 高：`sim_mean = -.1714735`, `p = 0.283`

G16 Manager-signed wording

* Best Name ...
* 交互项不显著
* Zip ym 组间差异显著
* 低：`sim_mean = ` `p = 0.022`
* 高：`sim_mean = `, `p = 0.283`

### Learning Effect

L1. Learning effect on next-month topic similarity.

* 对下一期评论相似度的影响，取两期相似度的差值为dv：d_topic_similarity
* 主效应：`sim_mean = -.2357008`, `p = 0.000`
* 交互项显著：`sim_mean x learn_hi_ars =  -.0572037 `, `p = 0.000`
* 更相似了，而且越高相似度，下期的相似性越高

L2. Learning effect on next-month review length.

* 对评论平均长度的影响，dv：ln_sent_avg_text_words
* 主效应：`sim_mean = -3.283516`, `p = 0.000`
* 交互项显著：`sim_mean x learn_hi_ars = .5659135 `, `p = 0.048`
* 更相似的评论前提下，读者写得内容相比没那么相似时会更短，信息已经初步形成共识，新增内容边际效应变小

### Management Response 拓展

T1 Complaint-heavy reply targeting

* 上一月酒店的回复对象里，有多大比例是 complaint-heavy 的评论。lag_mr_rep_complaint_share
* 交互项不显著
* 低：`sim_mean = -.2218614`, `p = 0.041`
* 高：`sim_mean = -.0584194`, `p = 0.612`
* 回复complaint内容的review可以缓解simi的负面作用

T2 service-targeting

* **上个月所有被回复的评论里，属于 service issue 的那部分占比**。lag_mr_rep_service_share
* 交互项不显著
* 低：`sim_mean = -.2024809`, `p = 0.037`
* 高：`sim_mean = -.0755733`, `p = 0.401`
* 回复service issue内容的review可以缓解simi的负面作用

T3 room-targeting

* **上个月所有被回复的评论里，属于 service issue 的那部分占比**。lag_mr_rep_service_share
* 交互项不显著
* 低：`sim_mean = -.2278172`, `p = 0.036`
* 高：`sim_mean = -.0696026`, `p = 0.518`
* 回复room issue内容的review可以缓解simi的负面作用

T7 Next-month review volume

* 看的是 reply targeting 会不会影响下一期评论流入量，DV 是 `ln_recent_volumn`
* `lag_mr_rep_complaint_share = -.0328382`, `p = 0.012`
* `lag_mr_rep_service_share = .0011841`, `p = 0.836`
* `lag_mr_rep_room_share = -.0107529`, `p = 0.072`
* `lag_mr_rep_clean_share = -.0286749`, `p = 0.000`
* `lag_mr_rep_value_share = -.0171382`, `p = 0.021`
* 同时：
* `lag_mr_rate = -.0280649`, `p = 0.000`
* `lag_mr_count = .0081084`, `p = 0.000`
* `ln_lag_mr_words = .0167411`, `p = 0.000`
* 结论：如果酒店更把回复对象集中在 complaint / clean / value 这类问题评论上，下一期评论量会更少；单纯提高回复覆盖率也会压低后续评论量，但回复条数更多、回复文本更长时，后续评论量反而会上升。

T8 Next-month ARS

* 看的是 reply targeting 会不会改变下一期评论相似性，DV 是 `sim_mean`
* `lag_mr_rep_complaint_share = .0042509`, `p = 0.006`
* `lag_mr_rep_service_share = -.0039685`, `p = 0.000`
* `lag_mr_rep_room_share = -.0079715`, `p = 0.000`
* `lag_mr_rep_clean_share = -.0005355`, `p = 0.544`
* `lag_mr_rep_value_share = -.0033823`, `p = 0.000`
* 同时：
* `lag_mr_count = -.0000805`, `p = 0.035`
* `ln_lag_mr_words = .0008633`, `p = 0.001`
* 结论：如果酒店更把回复对象集中在 complaint-heavy 评论上，下一期评论相似度会更高；如果更偏向 service / room / value 这几类具体问题评论，下一期评论相似度反而会下降。也就是说，不同 targeting 策略会把后续评论往“更趋同”或“更分散”的方向推。

T9 Next-month review sentiment

* 看的是 reply targeting 会不会影响下一期评论语气，DV 是 `sent_net_pos_bing`
* `lag_mr_rep_complaint_share = .0198116`, `p = 0.367`
* `lag_mr_rep_service_share = .0073512`, `p = 0.603`
* `lag_mr_rep_room_share = -.0102191`, `p = 0.445`
* `lag_mr_rep_clean_share = -.0313519`, `p = 0.008`
* `lag_mr_rep_value_share = -.0329623`, `p = 0.044`
* 同时：
* `lag_mr_rate = -.0042897`, `p = 0.095`
* `ln_lag_mr_words = .0076516`, `p = 0.008`
* 结论：reply targeting 对后续情感的影响主要体现在 clean 和 value 两类问题评论上。酒店如果更集中回复 clean / value issue 评论，下一期评论净正向情感会下降，也就是后续评论语气更负；而 complaint / service / room targeting 对后续 sentiment 没有稳定影响。
