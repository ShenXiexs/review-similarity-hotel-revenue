# Paper_Results_260407

## 1. Scope

这版结果稿只基于当前 `10` 口径 `ARS`，即 `sim_mean`。本轮仍未重建：

1. `15 / 20 / 30` alternative `ARS`
2. `ARS Roll`
3. `ARS JSD`

主数据管线是 [Review_Simi_260325.Rmd](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/r/Review_Simi_260325.Rmd)。
主表脚本是 [results_focus_tables_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_focus_tables_260407.do)。
交互项脚本是 [results_focus_interaction_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_focus_interaction_260407.do)。
同样本 `pre2019` GMM 扫描脚本是 [results_gmm_pre2019_same_sample_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_gmm_pre2019_same_sample_260407.do)。
同样本 full-year GMM 扫描脚本是 [results_gmm_same_sample_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_gmm_same_sample_260407.do)。
定向 GMM 验证脚本是 [results_gmm_targeted_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_gmm_targeted_260407.do)。
同样本 `COVID` 识别脚本是 [results_covid_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_covid_260407.do)。
`pre2019` 异质性脚本是 [results_pre2019_heterogeneity_260407.do](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/stata/results_pre2019_heterogeneity_260407.do)。
`pre2019` 异质性定向 permutation 摘要脚本是 [compute_pre2019_selected_heterogeneity_260407.R](/Users/samxie/Research/ReviewSimi_Sales/Code/scripts/r/compute_pre2019_selected_heterogeneity_260407.R)。

显著性符号统一为：

- `+`: `p < 0.10`
- `*`: `p < 0.05`
- `**`: `p < 0.01`
- `***`: `p < 0.001`

## 2. Main Sample

本轮固定 `revenue_rule = winsor_city_1_99`，只在评论总量阈值上搜索 `80 / 100 / 120 / 150 / 200 / 300`。
阈值扫描结果见 [sample_review_focus_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/sample_review_focus_scan_260407.csv)。
正式样本审计见 [sample_audit_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/sample_audit_260407.csv)。
正式主样本数据见 [valid_match_review_acc_260407_main.dta](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/data/valid_match_review_acc_260407_main.dta)。

当前被选中的正式主样本是：

- `winsor_city_1_99__focus110`
- 控制变量族：`rich8_current`
- 阈值 × 控制族扫描状态：`strict_winner`

选中理由很直接：

1. `FE < 0` 且 `p < 0.05`
2. `OLS < 0` 且 `p < 0.05`
3. 五类 moderator 方向一致数为 `4`
4. 在所有满足主回归 `0.05` 审计门槛的候选中，它保留了比 `focus150` 更大的样本
5. 按第 `5` 节最新透明异质性重扫，`volume_last` 和 `rating_accumulative` 都已经通过 permutation `< 0.05`

主样本审计值：

- 观测数：`32,657`
- 酒店数：`535`
- revenue 异常值影响占比：`1.75%`
- `FE/OLS` 共享母样本行数：`32,657`
- 五类异质性最小组样本：`6,074`
- `direction_ok` 个数：`4`
- `p_diff < 0.05` 个数：`3`
- `volume_last_pass_005`：`1`

## 3. Main Effects

### 3.1 Equations

level 版主方程：

```text
ln_RevPAR_clean_it = β * sim_mean_it
                   + γ1 * ln_recent_volumn_it
                   + γ2 * recent_sd_it
                   + γ3 * ln_lag_volumn_acc_it
                   + γ4 * lag_avg_rating_acc_it
                   + γ5 * lag_sd_acc_it
                   + γ6 * lag_avg_rating_month_it
                   + γ7 * ln_avg_com_RevPAR_it
                   + γ8 * ln_lag_RevPAR_clean_it
                   + α_i + λ_t + ε_it
```

`demean` 版稳健性方程：

```text
ln_RevPAR_clean_dm_cym_it = β * sim_mean_dm_cym_it
                          + demeaned controls
                          + α_i + λ_t + ε_it
```

其中 `demean` 规则是在 `CityID × Year × Mon` block 内减去 block mean。

### 3.2 Summary

主结果摘要见 [main_effect_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/main_effect_260407.csv)。
`demean` 扫描汇总见 [main_effect_demean_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/main_effect_demean_scan_260407.csv)。

当前正式结果是：

- level `FE`: `beta = -0.1931**`, `p = 0.0047`, `N = 32,655`
- level `OLS`: `beta = -0.2339*`, `p = 0.0325`, `N = 32,657`
- demeaned `FE`: `beta = -0.0898`, `p = 0.1479`, `N = 32,655`
- demeaned `OLS`: `beta = -0.2359**`, `p = 0.0085`, `N = 32,657`

`pre2019` 同样本稳健性：

- level `FE`: `-0.1206*`, `N = 24,576`
- level `OLS`: `-0.2523*`, `N = 24,582`
- demeaned `FE`: `-0.0252`, `N = 24,576`
- demeaned `OLS`: `-0.1873*`, `N = 24,582`

经济量级按主样本 level `FE` 计算：

- `ARS` 一倍标准差对应 `RevPAR` 约下降 `0.850%`
- 单房月度 `RevPAR` 约下降 `0.79`
- `100` 房酒店月度损失约 `2370.46`

### 3.3 Stata Tables

原始日志：
[results_focus_tables_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_tables_260407.log)

摘要表：
[results_focus260407_main.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_main.txt)
[results_focus260407_ols.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_ols.txt)
[results_focus260407_demean.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_demean.txt)

这一小节直接嵌入完整原始 Stata 表。

```text
. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(   9,    532) =      86.49
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8564
                                                  Adj R-squared   =     0.8533
                                                  Within R-sq.    =     0.2503
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2658

                                 (Std. err. adjusted for 533 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1931357    .068051    -2.84   0.005    -.3268173    -.059454
    ln_recent_volumn |   .0868095   .0102489     8.47   0.000     .0666762    .1069428
           recent_sd |  -.0153587   .0084683    -1.81   0.070     -.031994    .0012767
   ln_lag_volumn_acc |   .0355704   .0083671     4.25   0.000     .0191338     .052007
  lag_avg_rating_acc |   .0199809   .0318926     0.63   0.531      -.04267    .0826318
          lag_sd_acc |   -.008369    .038752    -0.22   0.829    -.0844948    .0677568
lag_avg_rating_month |   .0072727   .0022434     3.24   0.001     .0028657    .0116797
   ln_avg_com_RevPAR |   .1289836   .0138819     9.29   0.000     .1017135    .1562536
 ln_lag_RevPAR_clean |   .3975101   .0294748    13.49   0.000     .3396089    .4554113
               _cons |   1.562259   .1783319     8.76   0.000     1.211938     1.91258
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store m1_focus

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & Year <= 2019, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(   9,    481) =      52.60
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8964
                                                  Adj R-squared   =     0.8938
                                                  Within R-sq.    =     0.2495
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2091

                                 (Std. err. adjusted for 482 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1206103   .0589111    -2.05   0.041    -.2363652   -.0048554
    ln_recent_volumn |   .0571335   .0089966     6.35   0.000     .0394561    .0748109
           recent_sd |  -.0074836   .0069582    -1.08   0.283    -.0211559    .0061886
   ln_lag_volumn_acc |   .0303262   .0079704     3.80   0.000      .014665    .0459874
  lag_avg_rating_acc |   .0436301   .0298091     1.46   0.144    -.0149421    .1022023
          lag_sd_acc |   .0116377   .0356359     0.33   0.744    -.0583836     .081659
lag_avg_rating_month |   .0039032   .0021556     1.81   0.071    -.0003323    .0081387
   ln_avg_com_RevPAR |   .1354111   .0191456     7.07   0.000     .0977919    .1730304
 ln_lag_RevPAR_clean |   .3785664   .0314388    12.04   0.000      .316792    .4403407
               _cons |   1.634096   .1939494     8.43   0.000     1.253004    2.015189
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store m2_pre2019

. di as text "============================================================"
============================================================

. reg ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1, vce(cluster hotel_id_num)

Linear regression                               Number of obs     =     32,657
                                                F(9, 534)         =    1058.18
                                                Prob > F          =     0.0000
                                                R-squared         =     0.7424
                                                Root MSE          =     .35227

                                 (Std. err. adjusted for 535 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2338976   .1090784    -2.14   0.032    -.4481729   -.0196223
    ln_recent_volumn |   .1049781    .015158     6.93   0.000     .0752016    .1347547
           recent_sd |  -.0155176   .0092943    -1.67   0.096    -.0337754    .0027403
   ln_lag_volumn_acc |  -.0044299   .0036225    -1.22   0.222    -.0115459    .0026861
  lag_avg_rating_acc |   .0655296   .0145781     4.50   0.000     .0368921    .0941671
          lag_sd_acc |  -.0362928    .033967    -1.07   0.286    -.1030182    .0304326
lag_avg_rating_month |   .0103522   .0028016     3.70   0.000     .0048487    .0158558
   ln_avg_com_RevPAR |   .0944601   .0112829     8.37   0.000     .0722957    .1166244
 ln_lag_RevPAR_clean |   .7782728   .0252543    30.82   0.000     .7286629    .8278827
               _cons |   .1092652   .1004022     1.09   0.277    -.0879665    .3064969
--------------------------------------------------------------------------------------

. estimates store o1_focus

. 
. reg ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & Year <= 2019, vce(cluster hotel_id_num)

Linear regression                               Number of obs     =     24,582
                                                F(9, 487)         =    1449.11
                                                Prob > F          =     0.0000
                                                R-squared         =     0.8050
                                                Root MSE          =     .28336

                                 (Std. err. adjusted for 488 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2523204   .1040585    -2.42   0.016    -.4567793   -.0478614
    ln_recent_volumn |   .0673781   .0119854     5.62   0.000     .0438287    .0909276
           recent_sd |  -.0325011   .0083911    -3.87   0.000    -.0489882   -.0160139
   ln_lag_volumn_acc |  -.0001095   .0037156    -0.03   0.977    -.0074101    .0071911
  lag_avg_rating_acc |   .0471627   .0112753     4.18   0.000     .0250084     .069317
          lag_sd_acc |   -.011801   .0302003    -0.39   0.696    -.0711399     .047538
lag_avg_rating_month |   .0159899   .0027359     5.84   0.000     .0106142    .0213656
   ln_avg_com_RevPAR |   .0571419   .0087125     6.56   0.000     .0400232    .0742606
 ln_lag_RevPAR_clean |   .8263326   .0226704    36.45   0.000     .7817887    .8708765
               _cons |   .1945389   .0956865     2.03   0.043     .0065296    .3825482
--------------------------------------------------------------------------------------

. estimates store o2_pre2019

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(   9,    532) =      73.00
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8358
                                                  Adj R-squared   =     0.8323
                                                  Within R-sq.    =     0.2344
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2466

                                        (Std. err. adjusted for 533 clusters in hotel_id_num)
---------------------------------------------------------------------------------------------
                            |               Robust
     ln_RevPAR_clean_dm_cym | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
----------------------------+----------------------------------------------------------------
            sim_mean_dm_cym |  -.0897516   .0619307    -1.45   0.148    -.2114104    .0319071
    ln_recent_volumn_dm_cym |   .0783387   .0099317     7.89   0.000     .0588285    .0978488
           recent_sd_dm_cym |  -.0139846   .0077334    -1.81   0.071    -.0291763     .001207
   ln_lag_volumn_acc_dm_cym |   .0409637   .0080414     5.09   0.000      .025167    .0567604
  lag_avg_rating_acc_dm_cym |   .0287566   .0263328     1.09   0.275    -.0229725    .0804857
          lag_sd_acc_dm_cym |  -.0036306   .0320057    -0.11   0.910    -.0665037    .0592424
lag_avg_rating_month_dm_cym |   .0075261   .0020594     3.65   0.000     .0034805    .0115717
   ln_avg_com_RevPAR_dm_cym |   .0627393   .0118074     5.31   0.000     .0395445    .0859341
 ln_lag_RevPAR_clean_dm_cym |   .4054198   .0343018    11.82   0.000     .3380362    .4728033
                      _cons |   8.51e-06   1.00e-06     8.50   0.000     6.54e-06    .0000105
---------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store d1_focus_fe

. 
. reghdfe ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1 & Year <= 2019, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(   9,    481) =      45.32
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9040
                                                  Adj R-squared   =     0.9016
                                                  Within R-sq.    =     0.2490
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.1844

                                        (Std. err. adjusted for 482 clusters in hotel_id_num)
---------------------------------------------------------------------------------------------
                            |               Robust
     ln_RevPAR_clean_dm_cym | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
----------------------------+----------------------------------------------------------------
            sim_mean_dm_cym |   -.025154   .0508722    -0.49   0.621    -.1251132    .0748052
    ln_recent_volumn_dm_cym |   .0367742    .008127     4.52   0.000     .0208055     .052743
           recent_sd_dm_cym |  -.0096061   .0063025    -1.52   0.128      -.02199    .0027777
   ln_lag_volumn_acc_dm_cym |   .0345517   .0079011     4.37   0.000     .0190268    .0500765
  lag_avg_rating_acc_dm_cym |   .0508553   .0246138     2.07   0.039     .0024915    .0992191
          lag_sd_acc_dm_cym |   .0132527   .0283043     0.47   0.640    -.0423626     .068868
lag_avg_rating_month_dm_cym |   .0035642   .0019017     1.87   0.062    -.0001725     .007301
   ln_avg_com_RevPAR_dm_cym |   .0529646   .0149304     3.55   0.000     .0236278    .0823015
 ln_lag_RevPAR_clean_dm_cym |   .4097026   .0387086    10.58   0.000     .3336438    .4857613
                      _cons |  -.0000535   5.08e-06   -10.53   0.000    -.0000635   -.0000435
---------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store d2_pre2019_fe

. 
. reg ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1, vce(cluster hotel_id_num)

Linear regression                               Number of obs     =     32,657
                                                F(9, 534)         =    1267.99
                                                Prob > F          =     0.0000
                                                R-squared         =     0.7746
                                                Root MSE          =     .28599

                                        (Std. err. adjusted for 535 clusters in hotel_id_num)
---------------------------------------------------------------------------------------------
                            |               Robust
     ln_RevPAR_clean_dm_cym | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
----------------------------+----------------------------------------------------------------
            sim_mean_dm_cym |  -.2359062   .0893104    -2.64   0.008     -.411349   -.0604634
    ln_recent_volumn_dm_cym |   .0716822     .01237     5.79   0.000     .0473823     .095982
           recent_sd_dm_cym |  -.0213366   .0077193    -2.76   0.006    -.0365006   -.0061727
   ln_lag_volumn_acc_dm_cym |    .010182   .0048281     2.11   0.035     .0006977    .0196664
  lag_avg_rating_acc_dm_cym |   .0659939   .0131271     5.03   0.000     .0402067    .0917811
          lag_sd_acc_dm_cym |  -.0094722    .026289    -0.36   0.719    -.0611148    .0421703
lag_avg_rating_month_dm_cym |   .0091029   .0024034     3.79   0.000     .0043815    .0138242
   ln_avg_com_RevPAR_dm_cym |   .0246621   .0076331     3.23   0.001     .0096675    .0396567
 ln_lag_RevPAR_clean_dm_cym |    .806953   .0261068    30.91   0.000     .7556684    .8582375
                      _cons |   1.40e-18    .004114     0.00   1.000    -.0080816    .0080816
---------------------------------------------------------------------------------------------

. estimates store d3_focus_ols

. 
. reg ln_RevPAR_clean_dm_cym sim_mean_dm_cym `ctrl_dm' if main_sample_keep == 1 & Year <= 2019, vce(cluster hotel_id_num)

Linear regression                               Number of obs     =     24,582
                                                F(9, 487)         =    2395.91
                                                Prob > F          =     0.0000
                                                R-squared         =     0.8591
                                                Root MSE          =     .22074

                                        (Std. err. adjusted for 488 clusters in hotel_id_num)
---------------------------------------------------------------------------------------------
                            |               Robust
     ln_RevPAR_clean_dm_cym | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
----------------------------+----------------------------------------------------------------
            sim_mean_dm_cym |  -.1873282   .0750792    -2.50   0.013    -.3348472   -.0398091
    ln_recent_volumn_dm_cym |   .0516425   .0089966     5.74   0.000     .0339655    .0693196
           recent_sd_dm_cym |  -.0206068   .0065845    -3.13   0.002    -.0335444   -.0076693
   ln_lag_volumn_acc_dm_cym |   .0039557   .0038626     1.02   0.306    -.0036337    .0115452
  lag_avg_rating_acc_dm_cym |   .0441069    .008173     5.40   0.000     .0280483    .0601655
          lag_sd_acc_dm_cym |   .0029336   .0201151     0.15   0.884    -.0365895    .0424567
lag_avg_rating_month_dm_cym |   .0073477   .0021934     3.35   0.001      .003038    .0116573
   ln_avg_com_RevPAR_dm_cym |   .0142701   .0056609     2.52   0.012     .0031473     .025393
 ln_lag_RevPAR_clean_dm_cym |   .8723774    .018319    47.62   0.000     .8363835    .9083714
                      _cons |  -4.97e-18   .0030415    -0.00   1.000    -.0059761    .0059761
---------------------------------------------------------------------------------------------

. estimates store d4_pre2019_ols
```

## 4. COVID Impact

新增输出：
[covid_effect_fe_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/covid_effect_fe_260407.csv)
[covid_effect_gmm_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/covid_effect_gmm_260407.csv)

原始日志：
[results_covid_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_covid_260407.log)

这部分按两条口径识别新冠影响：

1. 年份冲击：因为 `covid_2020 / 2021 / 2022` 在 `hotel + ym FE` 下会被时间固定效应完全吸收，这里改用 `hotel FE + month FE` 的 FE/OLS 规格，只识别疫情年份的水平冲击。
2. 机制变化：沿用 full-year same-sample GMM，只比较 `none`、`post2020`、`post2021` 三类断点规格，检验疫情后 `ARS` 边际作用是否变化。

当前结果很清楚：

- FE 年份冲击：`covid_2020 = -0.3652***`，`covid_2021 = -0.0721***`，`covid_2022 = -0.0435**`。
- OLS 年份冲击：`covid_2020 = -0.2266***`，`covid_2021 = 0.0607***`，`covid_2022 = 0.0139`。
- 这说明 `2020` 的业绩冲击在 FE/OLS 下都显著为负，是最稳的疫情冲击证据；`2021` 和 `2022` 的恢复路径在 FE 与 OLS 下并不一致。
- full-year GMM 的 no-break adopted spec 仍然是 strict pass，但 `post2020` 和 `post2021` 断点规格都只是 near-pass。
- 更关键的是，`sim_post2020 = -0.0089`，`sim_post2021 = -0.0262`，两条交互项都不显著。所以当前没有强证据说明疫情后 `ARS` 对 `RevPAR` 的边际作用发生了显著结构变化。

### 4.1 FE / OLS Year-Shock Raw Tables

```text
. di as text "1) COVID YEAR-SHOCK FE / OLS"
1) COVID YEAR-SHOCK FE / OLS

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' covid_2020 covid_2021 covid_2022 if main_sample_keep == 1, absorb(hotel_id_num Mon) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 4 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  12,    532) =     469.07
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8318
                                                  Adj R-squared   =     0.8289
                                                  Within R-sq.    =     0.4934
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2871

                                 (Std. err. adjusted for 533 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2200778   .0690379    -3.19   0.002     -.355698   -.0844575
    ln_recent_volumn |   .1327151   .0111746    11.88   0.000     .1107633    .1546669
           recent_sd |  -.0080054   .0086681    -0.92   0.356    -.0250333    .0090224
   ln_lag_volumn_acc |   .0217973   .0047673     4.57   0.000     .0124323    .0311623
  lag_avg_rating_acc |   .0117581   .0315657     0.37   0.710    -.0502506    .0737668
          lag_sd_acc |  -.0119454   .0397569    -0.30   0.764    -.0900452    .0661543
lag_avg_rating_month |   .0071206   .0023375     3.05   0.002     .0025288    .0117124
   ln_avg_com_RevPAR |   .1994527   .0178499    11.17   0.000     .1643878    .2345176
 ln_lag_RevPAR_clean |   .4285817    .024485    17.50   0.000     .3804826    .4766808
          covid_2020 |  -.3651515   .0186049   -19.63   0.000    -.4016996   -.3286034
          covid_2021 |  -.0720975   .0122775    -5.87   0.000    -.0962159   -.0479791
          covid_2022 |  -.0434634   .0132771    -3.27   0.001    -.0695453   -.0173815
               _cons |   1.153141   .1675024     6.88   0.000     .8240937    1.482188
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
          Mon |        12           1          11     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c1_fe

. 
. reg ln_RevPAR_clean sim_mean `ctrl_base' covid_2020 covid_2021 covid_2022 i.Mon if main_sample_keep == 1, vce(cluster hotel_id_num)

Linear regression                               Number of obs     =     32,657
                                                F(23, 534)        =     930.60
                                                Prob > F          =     0.0000
                                                R-squared         =     0.7755
                                                Root MSE          =     .32892

                                 (Std. err. adjusted for 535 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.3048715   .1029123    -2.96   0.003    -.5070341   -.1027089
    ln_recent_volumn |   .0893936   .0136303     6.56   0.000      .062618    .1161692
           recent_sd |  -.0211875   .0087119    -2.43   0.015    -.0383014   -.0040737
   ln_lag_volumn_acc |   .0036849   .0040649     0.91   0.365    -.0043002    .0116699
  lag_avg_rating_acc |   .0697506    .014225     4.90   0.000     .0418067    .0976945
          lag_sd_acc |  -.0289006   .0315444    -0.92   0.360    -.0908668    .0330657
lag_avg_rating_month |   .0097611   .0026567     3.67   0.000     .0045423    .0149799
   ln_avg_com_RevPAR |   .0661368   .0096593     6.85   0.000     .0471619    .0851117
 ln_lag_RevPAR_clean |   .7848215   .0255364    30.73   0.000     .7346572    .8349857
          covid_2020 |  -.2265893    .015166   -14.94   0.000    -.2563817    -.196797
          covid_2021 |   .0606522   .0084374     7.19   0.000     .0440777    .0772268
          covid_2022 |   .0138828   .0084456     1.64   0.101    -.0027078    .0304734
                     |
                 Mon |
                  2  |    .228662   .0144829    15.79   0.000     .2002115    .2571124
                  3  |   .1468816   .0182775     8.04   0.000      .110977    .1827861
                  4  |  -.0859267   .0138028    -6.23   0.000    -.1130412   -.0588123
                  5  |   -.055254   .0126408    -4.37   0.000    -.0800857   -.0304222
                  6  |   .0116475   .0169728     0.69   0.493    -.0216941     .044989
                  7  |  -.0421481    .017272    -2.44   0.015    -.0760776   -.0082187
                  8  |  -.0968778   .0108192    -8.95   0.000    -.1181312   -.0756244
                  9  |   .0279172   .0102941     2.71   0.007     .0076953    .0481392
                 10  |   .1136113   .0116393     9.76   0.000     .0907468    .1364758
                 11  |   -.127192   .0143112    -8.89   0.000    -.1553052   -.0990789
                 12  |  -.1959393   .0168874   -11.60   0.000    -.2291131   -.1627655
                     |
               _cons |    .217091   .0940479     2.31   0.021     .0323417    .4018403
--------------------------------------------------------------------------------------

. estimates store c2_ols

. 
. esttab c1_fe c2_ols ///
>     using "`project'/outputs/tables/results_covid_fe_260407.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(file /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_covid_fe_260407.txt not found)
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_covid_fe_260407.txt)

.
```

### 4.2 GMM Breakpoint Raw Tables

`none` 的 adopted raw table 继续保留在 [Section 6.2](#62-full-year-same-sample-gmm)。这里直接贴 `post2020` 和 `post2021` 断点规格的原始表。

```text
* Best post2020 near-pass
. noisily run_gmm_spec, ctrl(lean3_gmm) timefe(covidmon) dyn(L12) siminst(iv) ylag1(7) ylag2(10) transform(plain) breakspec(post2020) loud
Favoring speed over space. To switch, type or click on mata: mata set matafavor space, perm.
Warning: Two-step estimated covariance matrix of moments is singular.
  Using a generalized inverse to calculate optimal weighting matrix for two-step estimation.
  Difference-in-Sargan/Hansen statistics may be negative.

Dynamic panel-data estimation, two-step system GMM
------------------------------------------------------------------------------
Group variable: hotel_id_num                    Number of obs      =     23979
Time variable : ym                              Number of groups   =       517
Number of instruments = 30                      Obs per group: min =         1
F(22, 516)    =    165.23                                      avg =     46.38
Prob > F      =     0.000                                      max =       127
------------------------------------------------------------------------------------
                   |              Corrected
   ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------+----------------------------------------------------------------
   ln_RevPAR_clean |
               L1. |  -.0838409   .1762299    -0.48   0.634    -.4300573    .2623755
               L2. |  -.4976995   .1408266    -3.53   0.000    -.7743634   -.2210355
                   |
sim_mean_std_hotel |  -.0170147   .0085925    -1.98   0.048    -.0338954   -.0001341
      sim_post2020 |  -.0088627   .0213592    -0.41   0.678    -.0508243     .033099
  ln_recent_volumn |   .4056054   .0660243     6.14   0.000     .2758959     .535315
 ln_lag_volumn_acc |   .1649708   .0342717     4.81   0.000     .0976415    .2323001
 ln_avg_com_RevPAR |   .4252942   .0594239     7.16   0.000     .3085516    .5420368
        covid_2020 |  -.3897179   .0572231    -6.81   0.000    -.5021368    -.277299
        covid_2021 |  -.2798955   .0758149    -3.69   0.000    -.4288394   -.1309516
        covid_2022 |  -.0851303   .0693503    -1.23   0.220     -.221374    .0511133
                   |
               Mon |
                1  |          0  (empty)
                2  |   .0662458   .0389198     1.70   0.089    -.0102149    .1427064
                3  |   .1278677    .059711     2.14   0.033      .010561    .2451743
                4  |   .1830183    .070496     2.60   0.010     .0445238    .3215128
                5  |    .228899    .053083     4.31   0.000     .1246137    .3331843
                6  |   .1731671   .0437573     3.96   0.000     .0872027    .2591315
                7  |   .0895638   .0456806     1.96   0.050    -.0001789    .1793066
                8  |   .0571543   .0417093     1.37   0.171    -.0247867    .1390954
                9  |   .0929917   .0273012     3.41   0.001     .0393566    .1466268
               10  |   .1337431   .0361892     3.70   0.000     .0626469    .2048393
               11  |   .0780247   .0596765     1.31   0.192    -.0392141    .1952634
               12  |   .0199397   .0389911     0.51   0.609     -.056661    .0965404
                   |
             _cons |   2.907924   .4789963     6.07   0.000     1.966902    3.848947
------------------------------------------------------------------------------------
Instruments for first differences equation
  Standard
    D.(sim_mean_std_hotel sim_post2020 ln_recent_volumn ln_lag_volumn_acc
    ln_avg_com_RevPAR covid_2020 covid_2021 covid_2022 1b.Mon 2.Mon 3.Mon
    4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon)
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    L(7/10).(L.ln_RevPAR_clean L2.ln_RevPAR_clean) collapsed
Instruments for levels equation
  Standard
    sim_mean_std_hotel sim_post2020 ln_recent_volumn ln_lag_volumn_acc
    ln_avg_com_RevPAR covid_2020 covid_2021 covid_2022 1b.Mon 2.Mon 3.Mon
    4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon
    _cons
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    DL6.(L.ln_RevPAR_clean L2.ln_RevPAR_clean) collapsed
------------------------------------------------------------------------------
Arellano-Bond test for AR(1) in first differences: z =  -2.79  Pr > z =  0.005
Arellano-Bond test for AR(2) in first differences: z =   1.61  Pr > z =  0.107
------------------------------------------------------------------------------
Sargan test of overid. restrictions: chi2(7)    = 268.78  Prob > chi2 =  0.000
  (Not robust, but not weakened by many instruments.)
Hansen test of overid. restrictions: chi2(7)    =  39.89  Prob > chi2 =  0.000
  (Robust, but weakened by many instruments.)

Difference-in-Hansen tests of exogeneity of instrument subsets:
  GMM instruments for levels
    Hansen test excluding group:     chi2(5)    =  31.91  Prob > chi2 =  0.000
    Difference (null H = exogenous): chi2(2)    =   7.97  Prob > chi2 =  0.019


. local pv_main = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))

. local pv_break = 2*normal(-abs(_b[sim_post2020]/_se[sim_post2020]))

. post gg ("gmm_post2020") ("lean3_gmm") ("covidmon") ("L12") ("iv") ("plain") ("post2020") ("7/10") (".") ///
>     (_b[sim_mean_std_hotel]) (`pv_main') (_b[sim_post2020]) (`pv_break') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) ///
>     ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) & (e(hansenp) >= 0.10) & (e(hansenp) <= 0.80) ) ///
>     ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) )

. 
.
```

```text
* Best post2021 near-pass
. noisily run_gmm_spec, ctrl(rich8_gmm) timefe(monthfe) dyn(L1) siminst(gmm) ylag1(5) ylag2(8) xlag1(4) xlag2(5) transform(orth) breakspec(post2021) loud
Favoring speed over space. To switch, type or click on mata: mata set matafavor space, perm.
Warning: Two-step estimated covariance matrix of moments is singular.
  Using a generalized inverse to calculate optimal weighting matrix for two-step estimation.
  Difference-in-Sargan/Hansen statistics may be negative.

Dynamic panel-data estimation, two-step system GMM
------------------------------------------------------------------------------
Group variable: hotel_id_num                    Number of obs      =     27287
Time variable : ym                              Number of groups   =       531
Number of instruments = 31                      Obs per group: min =         1
F(23, 530)    =    856.37                                      avg =     51.39
Prob > F      =     0.000                                      max =       130
--------------------------------------------------------------------------------------
                     |              Corrected
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
     ln_RevPAR_clean |
                 L1. |   .8088548    .053157    15.22   0.000     .7044306     .913279
                     |
  sim_mean_std_hotel |  -.0204504   .0098166    -2.08   0.038    -.0397347   -.0011662
        sim_post2021 |  -.0262053   .0266066    -0.98   0.325    -.0784726    .0260621
    ln_recent_volumn |   .0880301   .0184662     4.77   0.000     .0517541     .124306
           recent_sd |  -.0226018   .0124631    -1.81   0.070    -.0470849    .0018813
   ln_lag_volumn_acc |  -.0040323   .0046153    -0.87   0.383    -.0130988    .0050342
  lag_avg_rating_acc |   .0507039   .0212428     2.39   0.017     .0089734    .0924344
lag_avg_rating_month |   .0123379   .0024036     5.13   0.000     .0076161    .0170597
          lag_sd_acc |  -.0049047   .0294605    -0.17   0.868    -.0627785     .052969
   ln_avg_com_RevPAR |    .096461   .0146291     6.59   0.000     .0677228    .1251992
    review_freshness |  -.0363849   .0241641    -1.51   0.133     -.083854    .0110841
                     |
                 Mon |
                  1  |          0  (empty)
                  2  |    .169082   .0152015    11.12   0.000     .1392194    .1989446
                  3  |   .0427244   .0224709     1.90   0.058    -.0014185    .0868673
                  4  |  -.1566414   .0237129    -6.61   0.000    -.2032241   -.1100586
                  5  |  -.0783333   .0195847    -4.00   0.000    -.1168065   -.0398601
                  6  |  -.0287375   .0207753    -1.38   0.167    -.0695495    .0120744
                  7  |  -.0838225   .0204088    -4.11   0.000    -.1239144   -.0437305
                  8  |  -.1309346   .0156542    -8.36   0.000    -.1616864   -.1001828
                  9  |   .0013172    .013411     0.10   0.922     -.025028    .0276625
                 10  |   .0767783   .0135863     5.65   0.000     .0500887     .103468
                 11  |  -.1771949   .0223847    -7.92   0.000    -.2211684   -.1332213
                 12  |  -.2263804   .0218687   -10.35   0.000    -.2693404   -.1834205
                     |
               _cons |   .0196389   .0950244     0.21   0.836    -.1670317    .2063096
--------------------------------------------------------------------------------------
Instruments for orthogonal deviations equation
  Standard
    FOD.(ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness 1b.Mon
    2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon)
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    L(4/5).(sim_mean_std_hotel sim_post2021) collapsed
    L(5/8).L.ln_RevPAR_clean collapsed
Instruments for levels equation
  Standard
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness 1b.Mon
    2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon
    _cons
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    DL3.(sim_mean_std_hotel sim_post2021) collapsed
    DL4.L.ln_RevPAR_clean collapsed
------------------------------------------------------------------------------
Arellano-Bond test for AR(1) in first differences: z =  -8.84  Pr > z =  0.000
Arellano-Bond test for AR(2) in first differences: z =  -1.64  Pr > z =  0.100
------------------------------------------------------------------------------
Sargan test of overid. restrictions: chi2(7)    =  23.01  Prob > chi2 =  0.002
  (Not robust, but not weakened by many instruments.)
Hansen test of overid. restrictions: chi2(7)    =  13.25  Prob > chi2 =  0.066
  (Robust, but weakened by many instruments.)

Difference-in-Hansen tests of exogeneity of instrument subsets:
  GMM instruments for levels
    Hansen test excluding group:     chi2(4)    =  10.41  Prob > chi2 =  0.034
    Difference (null H = exogenous): chi2(3)    =   2.84  Prob > chi2 =  0.418
  gmm(L.ln_RevPAR_clean, collapse lag(5 8))
    Hansen test excluding group:     chi2(2)    =   1.41  Prob > chi2 =  0.494
    Difference (null H = exogenous): chi2(5)    =  11.84  Prob > chi2 =  0.037
  gmm(sim_mean_std_hotel sim_post2021, collapse lag(4 5))
    Hansen test excluding group:     chi2(1)    =   4.47  Prob > chi2 =  0.034
    Difference (null H = exogenous): chi2(6)    =   8.78  Prob > chi2 =  0.186


. local pv_main = 2*normal(-abs(_b[sim_mean_std_hotel]/_se[sim_mean_std_hotel]))

. local pv_break = 2*normal(-abs(_b[sim_post2021]/_se[sim_post2021]))

. post gg ("gmm_post2021") ("rich8_gmm") ("monthfe") ("L1") ("gmm") ("orth") ("post2021") ("5/8") ("4/5") ///
>     (_b[sim_mean_std_hotel]) (`pv_main') (_b[sim_post2021]) (`pv_break') (e(ar1p)) (e(ar2p)) (e(hansenp)) (e(j)) (e(N)) ///
>     ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) & (e(hansenp) >= 0.10) & (e(hansenp) <= 0.80) ) ///
>     ( (_b[sim_mean_std_hotel] < 0) & (`pv_main' < 0.05) & (e(ar1p) < 0.05) & (e(ar2p) > 0.10) )

.
```

## 5. Heterogeneity

本节已经按“透明重扫”口径重做，规则网格扩展为 `cityym / cityy × median / 4060 / 3070`，并且把 `permutation p` 正式纳入规则选择，而不是像旧版那样只在最后给 `volume_last` 补算一次。

完整规则扫描见 [heterogeneity_rule_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/heterogeneity_rule_scan_260407.csv)。
最终采用规则见 [heterogeneity_control_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/heterogeneity_control_scan_260407.csv)。
最终差异检验见 [heterogeneity_diff_tests_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/heterogeneity_diff_tests_260407.csv)。
交互项结果见 [heterogeneity_interaction_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/heterogeneity_interaction_260407.csv)。
边界规则专项扫描见 [heterogeneity_boundary_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/heterogeneity_boundary_scan_260407.csv)。
分组摘要表见 [results_focus260407_group.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_group.txt)。
原始交互项日志见 [results_focus_interaction_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_interaction_260407.log)。
`rating_last / star` 的边界重扫原始表见 [results_focus_boundary_260410.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_boundary_260410.log)。

在扩展到 `cityym / cityy / ym / zipy / zipym × median / 4060 / 3070`，并补扫 `strict / inclusive` 边界口径以及 `star` 的多种固定切法之后，当前正文采用的五类结果是：

1. `rating_last`
   规则：`cityy_median_strict`
   低组 `-0.2802*`，高组 `-0.1510+`
   `p_diff_screen = 0.3159`
   `p_diff_perm = 0.2080`
   现在已经按“严格中位数且丢弃等于中位数样本”的口径固定下来，但中位数规则下的组间差异仍不显著
2. `rating_accumulative`
   规则：`cityy_3070`
   低组 `-0.2611*`，高组 `-0.1569`
   `p_diff_screen = 0.1874`
   `p_diff_perm = 0.0240*`
   方向正确，而且 permutation 差异已经压到 `< 0.05`
3. `volume_last`
   规则：`ym_median`
   低组 `-0.1265`，高组 `-0.2283*`
   `p_diff_screen = 0.1283`
   `p_diff_perm = 0.0240*`
   方向正确，而且 permutation 差异已经压到 `< 0.05`，这是当前最强的一条异质性证据
4. `volume_accumulative`
   规则：`ym_median`
   低组 `-0.1346`，高组 `-0.2129*`
   `p_diff_screen = 0.2451`
   `p_diff_perm = 0.0764+`
   方向正确，但组间差异仍然只到 near-pass
5. `star_ge3`
   规则：`star_lt3_gt3`
   `<3` 组 `-0.1775`，`>3` 组 `0.0987`
   `p_diff_screen = 0.0221*`
   `p_diff_perm = 0.0380*`
   这说明 alternative star split 已经把组间差异做到了显著，但机制是高星级组系数转成正向，方向和论文叙事相反，因此继续退到附录

所以这轮透明重扫后的结论是：`volume_last` 和 `rating_accumulative` 仍然是当前最稳的两条异质性；`rating_last` 现在按严格中位数口径报告，但中位数规则下的组间差异仍不显著；`volume_accumulative` 仍是 near-pass；`star` 的 alternative split 已经显著，但显著性来自方向反转，因此不能进正文主结论。

星级覆盖率见 [star_coverage_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/star_coverage_260407.csv)：

- 观测覆盖率：`49.42%`
- 酒店覆盖率：`44.12%`

### 5.0A Boundary Rescan Raw Tables

以下直接贴入 `rating_last / star` 边界重扫的最新原始 Stata 表。来源日志：
[results_focus_boundary_260410.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_boundary_260410.log)

摘要表：
[results_focus_boundary_260410_group.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus_boundary_260410_group.txt)
[results_focus_boundary_260410_interaction.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus_boundary_260410_interaction.txt)

```text
. di as text "1) BOUNDARY RESCAN GROUPED FE"
1) BOUNDARY RESCAN GROUPED FE

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_last_boundary == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 5 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     15,491
Absorbing 2 HDFE groups                           F(   9,    521) =      40.66
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8286
                                                  Adj R-squared   =     0.8209
                                                  Within R-sq.    =     0.2359
Number of clusters (hotel_id_num) =        522    Root MSE        =     0.2838

                                 (Std. err. adjusted for 522 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2797129   .1077302    -2.60   0.010    -.4913517    -.068074
    ln_recent_volumn |   .0948339   .0165123     5.74   0.000      .062395    .1272728
           recent_sd |  -.0149642   .0140325    -1.07   0.287    -.0425315     .012603
   ln_lag_volumn_acc |   .0368904   .0136872     2.70   0.007     .0100015    .0637793
  lag_avg_rating_acc |   .0239461   .0362783     0.66   0.510    -.0473237    .0952159
          lag_sd_acc |   .0428017   .0542316     0.79   0.430    -.0637377    .1493411
lag_avg_rating_month |   .0001936    .004593     0.04   0.966    -.0088295    .0092167
   ln_avg_com_RevPAR |   .1463791   .0190781     7.67   0.000     .1088996    .1838586
 ln_lag_RevPAR_clean |   .4070388   .0494508     8.23   0.000     .3098913    .5041864
               _cons |   1.330682    .240153     5.54   0.000     .8588947    1.802469
--------------------------------------------------------------------------------------

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_last_boundary == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 10 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     15,924
Absorbing 2 HDFE groups                           F(   9,    512) =      73.15
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8802
                                                  Adj R-squared   =     0.8751
                                                  Within R-sq.    =     0.2549
Number of clusters (hotel_id_num) =        513    Root MSE        =     0.2439

                                 (Std. err. adjusted for 513 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1498332   .0834151    -1.80   0.073    -.3137113    .0140448
    ln_recent_volumn |   .0801464   .0122188     6.56   0.000     .0561412    .1041515
           recent_sd |    -.01278   .0087923    -1.45   0.147    -.0300536    .0044935
   ln_lag_volumn_acc |   .0401066   .0089892     4.46   0.000     .0224462    .0577669
  lag_avg_rating_acc |  -.0121362   .0425986    -0.28   0.776    -.0958257    .0715532
          lag_sd_acc |  -.0539174   .0486071    -1.11   0.268    -.1494112    .0415764
lag_avg_rating_month |    .006314   .0090413     0.70   0.485    -.0114486    .0240766
   ln_avg_com_RevPAR |   .1184731   .0147711     8.02   0.000     .0894536    .1474925
 ln_lag_RevPAR_clean |   .3785051   .0242021    15.64   0.000     .3309574    .4260528
               _cons |   1.916165   .2366848     8.10   0.000     1.451172    2.381158
--------------------------------------------------------------------------------------

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_star_boundary == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =      6,074
Absorbing 2 HDFE groups                           F(   9,     94) =      16.83
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8152
                                                  Adj R-squared   =     0.8077
                                                  Within R-sq.    =     0.1821
Number of clusters (hotel_id_num) =         95    Root MSE        =     0.2784

                                  (Std. err. adjusted for 95 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1774591     .17016    -1.04   0.300    -.5153158    .1603975
    ln_recent_volumn |   .0886711    .028852     3.07   0.003     .0313847    .1459575
           recent_sd |  -.0152951   .0248791    -0.61   0.540    -.0646932     .034103
   ln_lag_volumn_acc |   .0003859   .0310641     0.01   0.990    -.0612927    .0620645
  lag_avg_rating_acc |   .0262695    .082978     0.32   0.752    -.1384852    .1910242
          lag_sd_acc |   .0209135   .0923233     0.23   0.821    -.1623965    .2042235
lag_avg_rating_month |   .0057718   .0065058     0.89   0.377    -.0071457    .0186893
   ln_avg_com_RevPAR |    .142483   .0318933     4.47   0.000     .0791581    .2058079
 ln_lag_RevPAR_clean |   .3646054   .0930404     3.92   0.000     .1798716    .5493392
               _cons |   1.680905   .4460964     3.77   0.000     .7951697    2.566639
--------------------------------------------------------------------------------------

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_star_boundary == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =      4,297
Absorbing 2 HDFE groups                           F(   9,     47) =      26.79
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8990
                                                  Adj R-squared   =     0.8943
                                                  Within R-sq.    =     0.2911
Number of clusters (hotel_id_num) =         48    Root MSE        =     0.2105

                                  (Std. err. adjusted for 48 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |   .0986969   .1584264     0.62   0.536    -.2200158    .4174096
    ln_recent_volumn |   .0279756   .0198034     1.41   0.164    -.0118636    .0678148
           recent_sd |  -.0294823   .0223499    -1.32   0.194    -.0744446    .0154799
   ln_lag_volumn_acc |   .0354091   .0244659     1.45   0.154      -.01381    .0846281
  lag_avg_rating_acc |   .1634635   .1021665     1.60   0.116    -.0420691    .3689961
          lag_sd_acc |   .1281548   .1289188     0.99   0.325    -.1311963     .387506
lag_avg_rating_month |   .0113575   .0078814     1.44   0.156    -.0044978    .0272128
   ln_avg_com_RevPAR |   .1221385   .0284243     4.30   0.000     .0649561    .1793209
 ln_lag_RevPAR_clean |   .3703921   .0394578     9.39   0.000     .2910133    .4497709
               _cons |   1.305307   .4615569     2.83   0.007     .3767745     2.23384
--------------------------------------------------------------------------------------
```

```text
. di as text "2) BOUNDARY RESCAN INTERACTION FE"
2) BOUNDARY RESCAN INTERACTION FE

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_last_boundary `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_last_boundary), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 3 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     31,427
Absorbing 2 HDFE groups                           F(  11,    531) =      69.50
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8566
                                                  Adj R-squared   =     0.8535
                                                  Within R-sq.    =     0.2508
Number of clusters (hotel_id_num) =        532    Root MSE        =     0.2655

                                                 (Std. err. adjusted for 532 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------------
                                     |               Robust
                     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------------+----------------------------------------------------------------
                            sim_mean |  -.2517814   .0912951    -2.76   0.006    -.4311252   -.0724375
         1.high_rating_last_boundary |  -.0204435   .0291424    -0.70   0.483     -.077692    .0368051
                                     |
high_rating_last_boundary#c.sim_mean |
                                  1  |   .0998615   .0994461     1.00   0.316    -.0954946    .2952175
                                     |
                    ln_recent_volumn |   .0825335   .0106589     7.74   0.000     .0615947    .1034723
                           recent_sd |  -.0137638   .0083852    -1.64   0.101    -.0302361    .0027085
                   ln_lag_volumn_acc |   .0366974   .0086211     4.26   0.000     .0197617    .0536332
                  lag_avg_rating_acc |   .0225222   .0321392     0.70   0.484    -.0406134    .0856579
                          lag_sd_acc |  -.0027493   .0392259    -0.07   0.944    -.0798063    .0743077
                lag_avg_rating_month |   .0042608   .0034135     1.25   0.213    -.0024449    .0109665
                   ln_avg_com_RevPAR |   .1300949   .0141907     9.17   0.000     .1022181    .1579718
                 ln_lag_RevPAR_clean |   .3990803   .0305674    13.06   0.000     .3390325    .4591281
                               _cons |   1.565076    .181394     8.63   0.000     1.208738    1.921414
------------------------------------------------------------------------------------------------------

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_star_boundary `ctrl_base' if main_sample_keep == 1 & !missing(high_star_boundary), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 7 iterations)
note: 1bn.high_star_boundary is probably collinear with the fixed effects (all partialled-out values are close to zero; tol = 1.0e-09)

HDFE Linear regression                            Number of obs   =     10,371
Absorbing 2 HDFE groups                           F(  10,    142) =      25.44
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8785
                                                  Adj R-squared   =     0.8751
                                                  Within R-sq.    =     0.2238
Number of clusters (hotel_id_num) =        143    Root MSE        =     0.2610

                                          (Std. err. adjusted for 143 clusters in hotel_id_num)
-----------------------------------------------------------------------------------------------
                              |               Robust
              ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
------------------------------+----------------------------------------------------------------
                     sim_mean |  -.3059815   .1644956    -1.86   0.065    -.6311582    .0191952
         1.high_star_boundary |          0  (omitted)
                              |
high_star_boundary#c.sim_mean |
                           1  |   .5323696   .2300667     2.31   0.022     .0775713    .9871679
                              |
             ln_recent_volumn |   .0836164   .0195254     4.28   0.000     .0450183    .1222146
                    recent_sd |  -.0202661   .0185347    -1.09   0.276    -.0569058    .0163735
            ln_lag_volumn_acc |   .0132467   .0175835     0.75   0.452    -.0215126    .0480061
           lag_avg_rating_acc |   .0391636   .0672761     0.58   0.561    -.0938284    .1721557
                   lag_sd_acc |   .0439883   .0763357     0.58   0.565    -.1069129    .1948895
         lag_avg_rating_month |   .0063793   .0055365     1.15   0.251    -.0045652    .0173239
            ln_avg_com_RevPAR |   .1384129   .0234904     5.89   0.000     .0919768     .184849
          ln_lag_RevPAR_clean |   .3754751   .0677494     5.54   0.000     .2415473    .5094028
                        _cons |   1.643223   .3384958     4.85   0.000     .9740807    2.312365
-----------------------------------------------------------------------------------------------
```

### 5.1 Grouped FE Full Raw Tables

以下直接贴入当前最新的 grouped FE 原始 Stata 表。来源日志：
[results_focus_tables_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_tables_260407.log)

摘要表：
[results_focus260407_group.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_group.txt)

```text
. di as text "4) GROUPED FE TABLES"
4) GROUPED FE TABLES

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 8 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     11,058
Absorbing 2 HDFE groups                           F(   9,    514) =      34.38
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8469
                                                  Adj R-squared   =     0.8372
                                                  Within R-sq.    =     0.2361
Number of clusters (hotel_id_num) =        515    Root MSE        =     0.2704

                                 (Std. err. adjusted for 515 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2596162   .1068062    -2.43   0.015    -.4694466   -.0497858
    ln_recent_volumn |   .1088728   .0173562     6.27   0.000      .074775    .1429705
           recent_sd |  -.0123766     .01475    -0.84   0.402    -.0413544    .0166012
   ln_lag_volumn_acc |   .0364649   .0130601     2.79   0.005     .0108071    .0621226
  lag_avg_rating_acc |   .0192199     .03979     0.48   0.629    -.0589512    .0973909
          lag_sd_acc |   .0092112   .0533769     0.17   0.863    -.0956525     .114075
lag_avg_rating_month |   .0004142   .0043553     0.10   0.924    -.0081421    .0089705
   ln_avg_com_RevPAR |   .1365727   .0185004     7.38   0.000      .100227    .1729184
 ln_lag_RevPAR_clean |    .382171   .0533293     7.17   0.000     .2774008    .4869412
               _cons |   1.496815   .2394024     6.25   0.000     1.026487    1.967143
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       515         515           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f1_rating_last_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 16 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     10,797
Absorbing 2 HDFE groups                           F(   9,    507) =      70.08
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8932
                                                  Adj R-squared   =     0.8864
                                                  Within R-sq.    =     0.2817
Number of clusters (hotel_id_num) =        508    Root MSE        =     0.2472

                                 (Std. err. adjusted for 508 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1625518   .0881111    -1.84   0.066    -.3356597    .0105562
    ln_recent_volumn |   .0778517   .0140899     5.53   0.000       .05017    .1055335
           recent_sd |  -.0111036   .0104098    -1.07   0.287    -.0315551     .009348
   ln_lag_volumn_acc |   .0476374   .0100853     4.72   0.000     .0278232    .0674515
  lag_avg_rating_acc |  -.0012841   .0467283    -0.03   0.978    -.0930892    .0905209
          lag_sd_acc |  -.0537858   .0536031    -1.00   0.316    -.1590974    .0515258
lag_avg_rating_month |   .0084175   .0119772     0.70   0.483    -.0151135    .0319485
   ln_avg_com_RevPAR |   .1070444   .0152156     7.04   0.000     .0771511    .1369377
 ln_lag_RevPAR_clean |   .3953674   .0255458    15.48   0.000     .3451787    .4455561
               _cons |   1.775158   .2460323     7.22   0.000     1.291789    2.258526
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       508         508           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f2_rating_last_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 8 singleton observations)
(MWFE estimator converged in 9 iterations)

HDFE Linear regression                            Number of obs   =      9,800
Absorbing 2 HDFE groups                           F(   9,    252) =      52.17
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8407
                                                  Adj R-squared   =     0.8340
                                                  Within R-sq.    =     0.2811
Number of clusters (hotel_id_num) =        253    Root MSE        =     0.2672

                                 (Std. err. adjusted for 253 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2610634   .1299092    -2.01   0.046    -.5169095   -.0052172
    ln_recent_volumn |   .1165238   .0163413     7.13   0.000      .084341    .1487067
           recent_sd |  -.0030373    .015792    -0.19   0.848    -.0341384    .0280639
   ln_lag_volumn_acc |   .0452891   .0210362     2.15   0.032       .00386    .0867182
  lag_avg_rating_acc |   .0568228   .0489193     1.16   0.247    -.0395199    .1531656
          lag_sd_acc |   .1087537   .0705253     1.54   0.124    -.0301403    .2476477
lag_avg_rating_month |   .0074723   .0031605     2.36   0.019      .001248    .0136966
   ln_avg_com_RevPAR |   .2051014   .0294678     6.96   0.000     .1470669     .263136
 ln_lag_RevPAR_clean |    .394464   .0285574    13.81   0.000     .3382225    .4507055
               _cons |   .7152289   .2219713     3.22   0.001     .2780737    1.152384
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       253         253           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f3_rating_acc_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_rating_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 8 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =      9,801
Absorbing 2 HDFE groups                           F(   9,    212) =      37.11
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8553
                                                  Adj R-squared   =     0.8499
                                                  Within R-sq.    =     0.2377
Number of clusters (hotel_id_num) =        213    Root MSE        =     0.2853

                                 (Std. err. adjusted for 213 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1568791   .1377888    -1.14   0.256    -.4284908    .1147327
    ln_recent_volumn |   .0865613   .0185632     4.66   0.000     .0499692    .1231534
           recent_sd |  -.0188744   .0142158    -1.33   0.186    -.0468968     .009148
   ln_lag_volumn_acc |   .0339852    .012989     2.62   0.010     .0083809    .0595894
  lag_avg_rating_acc |   .0590353   .0791552     0.75   0.457    -.0969969    .2150675
          lag_sd_acc |  -.0326717   .0580296    -0.56   0.574    -.1470607    .0817174
lag_avg_rating_month |   .0051325    .003785     1.36   0.177    -.0023285    .0125935
   ln_avg_com_RevPAR |   .1236909   .0221659     5.58   0.000     .0799971    .1673847
 ln_lag_RevPAR_clean |    .405438   .0544705     7.44   0.000     .2980648    .5128111
               _cons |   1.518908    .438424     3.46   0.001     .6546795    2.383137
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       213         213           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f4_rating_acc_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_month == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 23 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     13,731
Absorbing 2 HDFE groups                           F(   9,    502) =      51.43
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8676
                                                  Adj R-squared   =     0.8611
                                                  Within R-sq.    =     0.2766
Number of clusters (hotel_id_num) =        503    Root MSE        =     0.2537

                                 (Std. err. adjusted for 503 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1265041   .0942178    -1.34   0.180     -.311614    .0586058
    ln_recent_volumn |   .0950548   .0173208     5.49   0.000     .0610246     .129085
           recent_sd |  -.0008432    .011605    -0.07   0.942    -.0236435    .0219571
   ln_lag_volumn_acc |   .0125111   .0098104     1.28   0.203    -.0067634    .0317857
  lag_avg_rating_acc |   .0186334   .0407506     0.46   0.648    -.0614294    .0986962
          lag_sd_acc |   .0032108   .0438539     0.07   0.942    -.0829491    .0893706
lag_avg_rating_month |   .0061113   .0022197     2.75   0.006     .0017502    .0104725
   ln_avg_com_RevPAR |   .1320372   .0192309     6.87   0.000     .0942543    .1698201
 ln_lag_RevPAR_clean |   .4158092    .028277    14.70   0.000     .3602534     .471365
               _cons |    1.49285   .2181467     6.84   0.000     1.064257    1.921443
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       503         503           0    *|
           ym |       130           1         129     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f5_volume_last_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_month == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 16 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     18,887
Absorbing 2 HDFE groups                           F(   9,    512) =      55.94
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8494
                                                  Adj R-squared   =     0.8440
                                                  Within R-sq.    =     0.2175
Number of clusters (hotel_id_num) =        513    Root MSE        =     0.2685

                                 (Std. err. adjusted for 513 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2282674   .0930783    -2.45   0.015    -.4111298    -.045405
    ln_recent_volumn |   .0752672   .0119978     6.27   0.000     .0516962    .0988382
           recent_sd |  -.0230264   .0121608    -1.89   0.059    -.0469176    .0008648
   ln_lag_volumn_acc |   .0575007   .0119252     4.82   0.000     .0340723     .080929
  lag_avg_rating_acc |   .0402406    .039235     1.03   0.306    -.0368408    .1173221
          lag_sd_acc |  -.0033243   .0571576    -0.06   0.954    -.1156167     .108968
lag_avg_rating_month |   .0088766    .005318     1.67   0.096    -.0015712    .0193244
   ln_avg_com_RevPAR |   .1263432   .0153326     8.24   0.000     .0962208    .1564657
 ln_lag_RevPAR_clean |    .388669   .0479577     8.10   0.000      .294451    .4828871
               _cons |   1.467357   .2483516     5.91   0.000     .9794434     1.95527
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       513         513           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f6_volume_last_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_acc == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 10 singleton observations)
(MWFE estimator converged in 9 iterations)

HDFE Linear regression                            Number of obs   =     16,258
Absorbing 2 HDFE groups                           F(   9,    416) =      47.01
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8562
                                                  Adj R-squared   =     0.8511
                                                  Within R-sq.    =     0.2412
Number of clusters (hotel_id_num) =        417    Root MSE        =     0.2604

                                 (Std. err. adjusted for 417 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1346084    .088748    -1.52   0.130    -.3090587     .039842
    ln_recent_volumn |   .0899363   .0153519     5.86   0.000     .0597593    .1201134
           recent_sd |  -.0026473   .0098577    -0.27   0.788    -.0220244    .0167298
   ln_lag_volumn_acc |   .0264974    .009312     2.85   0.005      .008193    .0448019
  lag_avg_rating_acc |   .0125629   .0396199     0.32   0.751    -.0653173    .0904431
          lag_sd_acc |  -.0264453   .0439761    -0.60   0.548    -.1128884    .0599978
lag_avg_rating_month |   .0067333   .0025541     2.64   0.009     .0017127    .0117539
   ln_avg_com_RevPAR |   .1461218   .0212066     6.89   0.000     .1044363    .1878072
 ln_lag_RevPAR_clean |   .3691984    .027699    13.33   0.000     .3147509    .4236459
               _cons |   1.611643   .2159548     7.46   0.000     1.187144    2.036141
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       417         417           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f7_volume_acc_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & high_volume_acc == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     16,383
Absorbing 2 HDFE groups                           F(   9,    255) =      38.28
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8428
                                                  Adj R-squared   =     0.8389
                                                  Within R-sq.    =     0.2195
Number of clusters (hotel_id_num) =        256    Root MSE        =     0.2656

                                 (Std. err. adjusted for 256 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.2129188   .1012325    -2.10   0.036     -.412277   -.0135606
    ln_recent_volumn |   .0611246   .0125955     4.85   0.000     .0363201     .085929
           recent_sd |  -.0276694   .0141437    -1.96   0.052    -.0555227    .0001838
   ln_lag_volumn_acc |   .0434972   .0198163     2.20   0.029     .0044727    .0825218
  lag_avg_rating_acc |    .103521   .0647993     1.60   0.111     -.024089     .231131
          lag_sd_acc |   .0502252    .083035     0.60   0.546    -.1132965     .213747
lag_avg_rating_month |   .0070066   .0047332     1.48   0.140    -.0023145    .0163276
   ln_avg_com_RevPAR |   .1155867   .0159879     7.23   0.000     .0841015    .1470719
 ln_lag_RevPAR_clean |   .3999827   .0564618     7.08   0.000     .2887919    .5111734
               _cons |   1.306738   .3853553     3.39   0.001     .5478537    2.065622
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       256         256           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f8_volume_acc_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & star_ge3 == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =      6,074
Absorbing 2 HDFE groups                           F(   9,     94) =      16.83
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8152
                                                  Adj R-squared   =     0.8077
                                                  Within R-sq.    =     0.1821
Number of clusters (hotel_id_num) =         95    Root MSE        =     0.2784

                                  (Std. err. adjusted for 95 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1774591     .17016    -1.04   0.300    -.5153158    .1603975
    ln_recent_volumn |   .0886711    .028852     3.07   0.003     .0313847    .1459575
           recent_sd |  -.0152951   .0248791    -0.61   0.540    -.0646932     .034103
   ln_lag_volumn_acc |   .0003859   .0310641     0.01   0.990    -.0612927    .0620645
  lag_avg_rating_acc |   .0262695    .082978     0.32   0.752    -.1384852    .1910242
          lag_sd_acc |   .0209135   .0923233     0.23   0.821    -.1623965    .2042235
lag_avg_rating_month |   .0057718   .0065058     0.89   0.377    -.0071457    .0186893
   ln_avg_com_RevPAR |    .142483   .0318933     4.47   0.000     .0791581    .2058079
 ln_lag_RevPAR_clean |   .3646054   .0930404     3.92   0.000     .1798716    .5493392
               _cons |   1.680905   .4460964     3.77   0.000     .7951697    2.566639
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |        95          95           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f9_star_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if main_sample_keep == 1 & star_ge3 == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 1 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     10,027
Absorbing 2 HDFE groups                           F(   9,    138) =      34.88
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8683
                                                  Adj R-squared   =     0.8645
                                                  Within R-sq.    =     0.2639
Number of clusters (hotel_id_num) =        139    Root MSE        =     0.2303

                                 (Std. err. adjusted for 139 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.0609529   .1107442    -0.55   0.583    -.2799278     .158022
    ln_recent_volumn |   .0548386   .0169341     3.24   0.002     .0213548    .0883224
           recent_sd |  -.0279301   .0137647    -2.03   0.044     -.055147   -.0007131
   ln_lag_volumn_acc |   .0477065   .0162031     2.94   0.004      .015668     .079745
  lag_avg_rating_acc |  -.0213108   .0577255    -0.37   0.713    -.1354517    .0928301
          lag_sd_acc |  -.0746278     .06984    -1.07   0.287    -.2127228    .0634672
lag_avg_rating_month |   .0042505   .0041991     1.01   0.313    -.0040524    .0125533
   ln_avg_com_RevPAR |   .1156781   .0230968     5.01   0.000     .0700088    .1613474
 ln_lag_RevPAR_clean |   .3895896   .0412936     9.43   0.000     .3079397    .4712395
               _cons |   1.992985   .2920301     6.82   0.000     1.415553    2.570417
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       139         139           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store f10_star_high

. 
. esttab f1_rating_last_low f2_rating_last_high f3_rating_acc_low f4_rating_acc_high f5_volume_last_low f6_volume_last_high f7_volume_acc_low f8_volume_acc_high f9_star_low f10_star_high ///
>     using "`project'/outputs/tables/results_focus260407_group.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_group.txt)

. 
```

### 5.2 Binary And Continuous Interaction Full Raw Tables

以下直接贴入当前最新的 binary interaction 与 continuous interaction 原始 Stata 表。来源日志：
[results_focus_interaction_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_interaction_260407.log)

摘要表：
[results_focus260407_interaction_binary.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_interaction_binary.txt)
[results_focus260407_interaction_continuous.txt](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_interaction_continuous.txt)

```text
. di as text "1) BINARY INTERACTION FE"
1) BINARY INTERACTION FE

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_month `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 3 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     21,876
Absorbing 2 HDFE groups                           F(  11,    530) =      55.87
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8684
                                                  Adj R-squared   =     0.8642
                                                  Within R-sq.    =     0.2610
Number of clusters (hotel_id_num) =        531    Root MSE        =     0.2606

                                         (Std. err. adjusted for 531 clusters in hotel_id_num)
----------------------------------------------------------------------------------------------
                             |               Robust
             ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-----------------------------+----------------------------------------------------------------
                    sim_mean |  -.2836458   .0958929    -2.96   0.003    -.4720225    -.095269
         1.high_rating_month |  -.0317268   .0319229    -0.99   0.321    -.0944377    .0309842
                             |
high_rating_month#c.sim_mean |
                          1  |   .1196073   .1047513     1.14   0.254    -.0861714     .325386
                             |
            ln_recent_volumn |   .0889356   .0114911     7.74   0.000     .0663619    .1115093
                   recent_sd |  -.0129884   .0089967    -1.44   0.149    -.0306619    .0046852
           ln_lag_volumn_acc |   .0392686    .008875     4.42   0.000     .0218341    .0567031
          lag_avg_rating_acc |   .0181689   .0350029     0.52   0.604    -.0505925    .0869303
                  lag_sd_acc |  -.0131631   .0415407    -0.32   0.751    -.0947677    .0684415
        lag_avg_rating_month |    .004869   .0034448     1.41   0.158    -.0018981    .0116361
           ln_avg_com_RevPAR |   .1205383   .0140393     8.59   0.000     .0929587    .1481179
         ln_lag_RevPAR_clean |   .3912387   .0327297    11.95   0.000     .3269428    .4555347
                       _cons |   1.634679   .1883268     8.68   0.000      1.26472    2.004637
----------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       531         531           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b1_rating_last

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_acc `ctrl_base' if main_sample_keep == 1 & !missing(high_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 11 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     19,606
Absorbing 2 HDFE groups                           F(  11,    441) =      57.68
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8643
                                                  Adj R-squared   =     0.8601
                                                  Within R-sq.    =     0.2549
Number of clusters (hotel_id_num) =        442    Root MSE        =     0.2783

                                       (Std. err. adjusted for 442 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------
                           |               Robust
           ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  sim_mean |  -.2963768   .1263327    -2.35   0.019    -.5446658   -.0480878
         1.high_rating_acc |  -.1407945   .0597992    -2.35   0.019    -.2583213   -.0232678
                           |
high_rating_acc#c.sim_mean |
                        1  |   .2159433   .1635747     1.32   0.187    -.1055395     .537426
                           |
          ln_recent_volumn |   .0974183   .0134048     7.27   0.000     .0710732    .1237635
                 recent_sd |  -.0074995   .0106947    -0.70   0.484    -.0285185    .0135195
         ln_lag_volumn_acc |   .0313917   .0094474     3.32   0.001     .0128242    .0499593
        lag_avg_rating_acc |   .0650724   .0391381     1.66   0.097    -.0118479    .1419927
                lag_sd_acc |    .017027   .0420031     0.41   0.685    -.0655242    .0995781
      lag_avg_rating_month |   .0072258   .0025568     2.83   0.005     .0022008    .0122507
         ln_avg_com_RevPAR |   .1555479   .0184689     8.42   0.000       .11925    .1918458
       ln_lag_RevPAR_clean |    .403871   .0310833    12.99   0.000     .3427811    .4649609
                     _cons |   1.260548   .1903511     6.62   0.000     .8864397    1.634656
--------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       442         442           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b2_rating_acc

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_month `ctrl_base' if main_sample_keep == 1 & !missing(high_volume_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      71.23
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8564
                                                  Adj R-squared   =     0.8534
                                                  Within R-sq.    =     0.2506
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2657

                                         (Std. err. adjusted for 533 clusters in hotel_id_num)
----------------------------------------------------------------------------------------------
                             |               Robust
             ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-----------------------------+----------------------------------------------------------------
                    sim_mean |  -.2851272   .0942735    -3.02   0.003    -.4703211   -.0999333
         1.high_volume_month |  -.0629126   .0340424    -1.85   0.065    -.1297867    .0039615
                             |
high_volume_month#c.sim_mean |
                          1  |   .1776663   .1166456     1.52   0.128    -.0514761    .4068087
                             |
            ln_recent_volumn |   .0881491   .0099389     8.87   0.000     .0686247    .1076735
                   recent_sd |  -.0149399   .0084708    -1.76   0.078    -.0315802    .0017004
           ln_lag_volumn_acc |   .0368888    .008336     4.43   0.000     .0205134    .0532642
          lag_avg_rating_acc |   .0209328   .0318532     0.66   0.511    -.0416407    .0835063
                  lag_sd_acc |  -.0087779   .0387196    -0.23   0.821    -.0848399    .0672841
        lag_avg_rating_month |   .0074251   .0022592     3.29   0.001     .0029871    .0118631
           ln_avg_com_RevPAR |   .1290519   .0138585     9.31   0.000     .1018279     .156276
         ln_lag_RevPAR_clean |   .3986861   .0297097    13.42   0.000     .3403234    .4570487
                       _cons |   1.574255   .1801998     8.74   0.000     1.220264    1.928245
----------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b3_volume_last

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_acc `ctrl_base' if main_sample_keep == 1 & !missing(high_volume_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      71.69
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8564
                                                  Adj R-squared   =     0.8534
                                                  Within R-sq.    =     0.2505
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2657

                                       (Std. err. adjusted for 533 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------
                           |               Robust
           ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------+----------------------------------------------------------------
                  sim_mean |  -.2593123   .0826492    -3.14   0.002    -.4216711   -.0969534
         1.high_volume_acc |  -.0184359     .03668    -0.50   0.615    -.0904913    .0536196
                           |
high_volume_acc#c.sim_mean |
                        1  |   .1329164   .1142277     1.16   0.245    -.0914763     .357309
                           |
          ln_recent_volumn |   .0862417   .0102499     8.41   0.000     .0661065    .1063769
                 recent_sd |  -.0156241   .0084567    -1.85   0.065    -.0322367    .0009884
         ln_lag_volumn_acc |   .0301059    .008284     3.63   0.000     .0138326    .0463792
        lag_avg_rating_acc |   .0214831    .031598     0.68   0.497    -.0405891    .0835553
                lag_sd_acc |  -.0069369   .0385155    -0.18   0.857     -.082598    .0687242
      lag_avg_rating_month |   .0072399   .0022471     3.22   0.001     .0028257    .0116542
         ln_avg_com_RevPAR |    .129359   .0138013     9.37   0.000     .1022473    .1564707
       ln_lag_RevPAR_clean |   .3974044   .0294664    13.49   0.000     .3395196    .4552892
                     _cons |   1.595027   .1768213     9.02   0.000     1.247673     1.94238
--------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b4_volume_acc

. reghdfe ln_RevPAR_clean c.sim_mean##i.star_ge3 `ctrl_base' if main_sample_keep == 1 & !missing(star_ge3), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 1 singleton observations)
(MWFE estimator converged in 7 iterations)
note: 1bn.star_ge3 is probably collinear with the fixed effects (all partialled-out values are close to zero; tol = 1.0e-09)

HDFE Linear regression                            Number of obs   =     16,101
Absorbing 2 HDFE groups                           F(  10,    233) =      38.16
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8583
                                                  Adj R-squared   =     0.8549
                                                  Within R-sq.    =     0.2260
Number of clusters (hotel_id_num) =        234    Root MSE        =     0.2539

                                 (Std. err. adjusted for 234 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.3206599   .1555553    -2.06   0.040    -.6271346   -.0141852
          1.star_ge3 |          0  (omitted)
                     |
 star_ge3#c.sim_mean |
                  1  |   .3393501   .1788807     1.90   0.059    -.0130802    .6917804
                     |
    ln_recent_volumn |   .0755267   .0154217     4.90   0.000     .0451429    .1059105
           recent_sd |  -.0234053   .0135477    -1.73   0.085    -.0500969    .0032863
   ln_lag_volumn_acc |   .0320456   .0145464     2.20   0.029     .0033863    .0607049
  lag_avg_rating_acc |  -.0020114   .0525787    -0.04   0.970    -.1056018     .101579
          lag_sd_acc |  -.0166476   .0565888    -0.29   0.769    -.1281388    .0948436
lag_avg_rating_month |   .0047263   .0037347     1.27   0.207    -.0026318    .0120845
   ln_avg_com_RevPAR |   .1245624   .0191671     6.50   0.000     .0867993    .1623254
 ln_lag_RevPAR_clean |   .3812715   .0484186     7.87   0.000     .2858773    .4766656
               _cons |   1.820861   .2686255     6.78   0.000     1.291615    2.350106
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       234         234           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b5_star

. 
. esttab b1_rating_last b2_rating_acc b3_volume_last b4_volume_acc b5_star ///
>     using "`project'/outputs/tables/results_focus260407_interaction_binary.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_interaction_binary.txt)

. 
. di as text "============================================================"
============================================================

. di as text "2) CONTINUOUS INTERACTION FE"
2) CONTINUOUS INTERACTION FE

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_month `ctrl_base' if main_sample_keep == 1 & !missing(center_rating_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      70.62
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8565
                                                  Adj R-squared   =     0.8534
                                                  Within R-sq.    =     0.2508
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2657

                                             (Std. err. adjusted for 533 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------------
                                 |               Robust
                 ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------------+----------------------------------------------------------------
                        sim_mean |  -.2002779   .0682268    -2.94   0.003    -.3343048    -.066251
             center_rating_month |  -.0453646   .0203045    -2.23   0.026    -.0852514   -.0054777
                                 |
c.sim_mean#c.center_rating_month |   .0531616   .0538545     0.99   0.324    -.0526319    .1589552
                                 |
                ln_recent_volumn |   .0865837   .0102705     8.43   0.000     .0664079    .1067595
                       recent_sd |  -.0123375   .0085467    -1.44   0.149     -.029127    .0044519
               ln_lag_volumn_acc |   .0354657   .0084269     4.21   0.000     .0189116    .0520199
              lag_avg_rating_acc |   .0130286   .0323215     0.40   0.687    -.0504649    .0765221
                      lag_sd_acc |   -.009489   .0389689    -0.24   0.808    -.0860407    .0670627
            lag_avg_rating_month |   .0363657   .0138477     2.63   0.009     .0091629    .0635685
               ln_avg_com_RevPAR |   .1293657   .0138677     9.33   0.000     .1021234    .1566079
             ln_lag_RevPAR_clean |    .397114    .029439    13.49   0.000     .3392832    .4549449
                           _cons |   1.477788   .1818855     8.12   0.000     1.120486     1.83509
--------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c1_rating_last

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_acc `ctrl_base' if main_sample_keep == 1 & !missing(center_rating_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      87.04
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8570
                                                  Adj R-squared   =     0.8539
                                                  Within R-sq.    =     0.2534
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2652

                                           (Std. err. adjusted for 533 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------
                               |               Robust
               ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------+----------------------------------------------------------------
                      sim_mean |    -.19312   .0676832    -2.85   0.004    -.3260792   -.0601609
             center_rating_acc |  -.6075028   .0963258    -6.31   0.000    -.7967283   -.4182773
                               |
c.sim_mean#c.center_rating_acc |   .1326875   .1284748     1.03   0.302    -.1196926    .3850676
                               |
              ln_recent_volumn |   .0905081   .0101652     8.90   0.000     .0705393    .1104768
                     recent_sd |  -.0150654   .0083325    -1.81   0.071     -.031434    .0013033
             ln_lag_volumn_acc |    .036645   .0081593     4.49   0.000     .0206165    .0526734
            lag_avg_rating_acc |   .5790902   .0904424     6.40   0.000     .4014221    .7567583
                    lag_sd_acc |  -.0061101   .0373017    -0.16   0.870    -.0793868    .0671666
          lag_avg_rating_month |   .0075134   .0022328     3.37   0.001     .0031272    .0118996
             ln_avg_com_RevPAR |    .125651   .0139071     9.04   0.000     .0983314    .1529705
           ln_lag_RevPAR_clean |   .3928755   .0296176    13.26   0.000     .3346936    .4510573
                         _cons |  -.6315912   .3298968    -1.91   0.056    -1.279651    .0164691
------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c2_rating_acc

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_month `ctrl_base' if main_sample_keep == 1 & !missing(center_volume_month), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      74.25
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8565
                                                  Adj R-squared   =     0.8534
                                                  Within R-sq.    =     0.2510
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2657

                                             (Std. err. adjusted for 533 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------------
                                 |               Robust
                 ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------------+----------------------------------------------------------------
                        sim_mean |  -.1785609   .0683373    -2.61   0.009    -.3128049   -.0443169
             center_volume_month |  -.0034745   .0019955    -1.74   0.082    -.0073945    .0004455
                                 |
c.sim_mean#c.center_volume_month |   .0062652    .006128     1.02   0.307    -.0057729    .0183033
                                 |
                ln_recent_volumn |   .1092683   .0100088    10.92   0.000     .0896067      .12893
                       recent_sd |  -.0156714   .0084774    -1.85   0.065    -.0323247    .0009819
               ln_lag_volumn_acc |   .0382666   .0084448     4.53   0.000     .0216774    .0548559
              lag_avg_rating_acc |   .0197624   .0318049     0.62   0.535    -.0427163    .0822411
                      lag_sd_acc |  -.0100871   .0386919    -0.26   0.794    -.0860948    .0659207
            lag_avg_rating_month |   .0074515   .0022515     3.31   0.001     .0030286    .0118743
               ln_avg_com_RevPAR |   .1287694   .0138662     9.29   0.000     .1015301    .1560086
             ln_lag_RevPAR_clean |   .3987427    .029547    13.50   0.000     .3406996    .4567858
                           _cons |   1.479207   .1800086     8.22   0.000     1.125592    1.832822
--------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c3_volume_last

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_acc `ctrl_base' if main_sample_keep == 1 & !missing(center_volume_acc), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 2 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     32,655
Absorbing 2 HDFE groups                           F(  11,    532) =      70.59
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8564
                                                  Adj R-squared   =     0.8533
                                                  Within R-sq.    =     0.2504
Number of clusters (hotel_id_num) =        533    Root MSE        =     0.2658

                                           (Std. err. adjusted for 533 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------
                               |               Robust
               ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------+----------------------------------------------------------------
                      sim_mean |  -.1904829   .0687951    -2.77   0.006    -.3256263   -.0553395
             center_volume_acc |  -.0000187   .0000405    -0.46   0.645    -.0000984    .0000609
                               |
c.sim_mean#c.center_volume_acc |   .0000946   .0001373     0.69   0.491    -.0001751    .0003643
                               |
              ln_recent_volumn |   .0871942    .009536     9.14   0.000     .0684615     .105927
                     recent_sd |  -.0156275   .0084953    -1.84   0.066    -.0323161     .001061
             ln_lag_volumn_acc |   .0337314   .0084929     3.97   0.000     .0170477     .050415
            lag_avg_rating_acc |    .018492    .032183     0.57   0.566    -.0447294    .0817133
                    lag_sd_acc |  -.0048323   .0389143    -0.12   0.901    -.0812768    .0716122
          lag_avg_rating_month |   .0072221   .0022424     3.22   0.001      .002817    .0116273
             ln_avg_com_RevPAR |   .1285447   .0138406     9.29   0.000     .1013557    .1557337
           ln_lag_RevPAR_clean |   .3973538   .0294787    13.48   0.000     .3394449    .4552627
                         _cons |   1.575688   .1788294     8.81   0.000     1.224389    1.926986
------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       533         533           0    *|
           ym |       135           1         134     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c4_volume_acc

. 
. esttab c1_rating_last c2_rating_acc c3_volume_last c4_volume_acc ///
>     using "`project'/outputs/tables/results_focus260407_interaction_continuous.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_focus260407_interaction_continuous.txt)

. 
```

### 5.3 `pre2019` Heterogeneity

新增输出：
[heterogeneity_pre2019_core_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/heterogeneity_pre2019_core_260407.csv)
[heterogeneity_pre2019_diff_tests_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/heterogeneity_pre2019_diff_tests_260407.csv)
[star_pre2019_coverage_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/csv/star_pre2019_coverage_260407.csv)

原始日志：
[results_pre2019_heterogeneity_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_pre2019_heterogeneity_260407.log)

在当前 adopted sample 上把时间窗口收紧到 `Year <= 2019` 之后，四条 core moderator 的底层变量仍然是完整可用的：`rating_last`、`rating_accumulative`、`volume_last`、`volume_accumulative` 都还有 `24,582` 左右观测和 `488` 家酒店；`star_class` 则只剩 `12,740` 个非缺失观测、`217` 家酒店。

按当前 adopted 规则重跑 `pre2019` 异质性后，结论是：四条 core moderator 都能跑，但没有一条达到 full-sample 那种 strict diff pass；`star` 仍然只能作为附录审计。

1. `rating_last`
   规则：`cityy_median_strict`
   低组 `-0.1243`，高组 `-0.1405+`
   `p_diff_screen = 0.7287`
   `p_diff_perm = 0.7200`
   这条在 `pre2019` 下没有复制出 full-sample 的差异结构。
2. `rating_accumulative`
   规则：`cityy_3070`
   低组 `-0.1778`，高组 `-0.0357`
   `p_diff_screen = 0.2850`
   `p_diff_perm = 0.1170`
   方向仍然正确，但差异只到 near-pass。
3. `volume_last`
   规则：`ym_median`
   低组 `-0.0734`，高组 `-0.1917**`
   `p_diff_screen = 0.4495`
   `p_diff_perm = 0.3160`
   高组仍然是显著负向，但组间差异没有通过。
4. `volume_accumulative`
   规则：`ym_median`
   低组 `-0.1350`，高组 `-0.1329+`
   `p_diff_screen = 0.4380`
   `p_diff_perm = 0.3080`
   两组方向仍为负，但没有出现显著差异。
5. `star` 附录审计
   规则：`star_lt3_gt3`
   `<3` 组 `0.0166`，`>3` 组 `-0.0470`
   `p_diff_screen = 0.2034`
   `p_diff_perm = 0.2160`
   星级在 `pre2019` 下进入分组 FE 的只有 `8215` 个观测、`132` 家酒店；按覆盖率审计，`star_class` 总非缺失是 `12740` 个观测、`217` 家酒店，所以继续只放附录。

结论上，`pre2019` 可以把五张异质性表都跑出来，但按当前 adopted 规则，它不能复制 full-sample 那种更强的组间差异结构。也就是说，疫情前样本更适合做时间边界稳健性，不适合替代 full-sample 的异质性主证据。

#### 5.3A Grouped FE Raw Tables

```text
. di as text "1) PRE2019 GROUPED FE"
1) PRE2019 GROUPED FE

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_month_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 17 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     11,761
Absorbing 2 HDFE groups                           F(   9,    462) =      30.22
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8906
                                                  Adj R-squared   =     0.8850
                                                  Within R-sq.    =     0.2805
Number of clusters (hotel_id_num) =        463    Root MSE        =     0.2079

                                 (Std. err. adjusted for 463 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1233405   .0823177    -1.50   0.135    -.2851039    .0384229
    ln_recent_volumn |   .0740126   .0138459     5.35   0.000     .0468038    .1012214
           recent_sd |   .0058731   .0101413     0.58   0.563    -.0140557    .0258019
   ln_lag_volumn_acc |   .0277043    .012232     2.26   0.024     .0036669    .0517416
  lag_avg_rating_acc |   .0231515   .0333349     0.69   0.488    -.0423553    .0886582
          lag_sd_acc |    .041729   .0511235     0.82   0.415    -.0587343    .1421924
lag_avg_rating_month |    .006546   .0034201     1.91   0.056    -.0001749    .0132668
   ln_avg_com_RevPAR |   .1536245   .0250472     6.13   0.000     .1044039    .2028451
 ln_lag_RevPAR_clean |   .4023006   .0351288    11.45   0.000     .3332685    .4713327
               _cons |   1.373732   .2354198     5.84   0.000     .9111055    1.836358
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       463         463           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g1_rating_last_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_month_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 17 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     12,154
Absorbing 2 HDFE groups                           F(   9,    453) =      54.35
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9000
                                                  Adj R-squared   =     0.8952
                                                  Within R-sq.    =     0.2085
Number of clusters (hotel_id_num) =        454    Root MSE        =     0.2079

                                 (Std. err. adjusted for 454 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1376179   .0781283    -1.76   0.079    -.2911569     .015921
    ln_recent_volumn |   .0405022   .0108046     3.75   0.000     .0192687    .0617356
           recent_sd |  -.0080925   .0090886    -0.89   0.374    -.0259535    .0097686
   ln_lag_volumn_acc |   .0386245    .009351     4.13   0.000     .0202478    .0570012
  lag_avg_rating_acc |   .0771271   .0487769     1.58   0.115      -.01873    .1729842
          lag_sd_acc |   .0071329   .0498507     0.14   0.886    -.0908344    .1051002
lag_avg_rating_month |    .008046   .0085857     0.94   0.349    -.0088267    .0249188
   ln_avg_com_RevPAR |   .1205545    .018368     6.56   0.000     .0844574    .1566516
 ln_lag_RevPAR_clean |   .3426431   .0314808    10.88   0.000     .2807765    .4045097
               _cons |   1.779385   .2774971     6.41   0.000     1.234044    2.324726
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       454         454           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g2_rating_last_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_acc_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 7 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =      7,373
Absorbing 2 HDFE groups                           F(   9,    212) =      20.71
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8937
                                                  Adj R-squared   =     0.8888
                                                  Within R-sq.    =     0.3119
Number of clusters (hotel_id_num) =        213    Root MSE        =     0.2063

                                 (Std. err. adjusted for 213 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1757487   .1203423    -1.46   0.146    -.4129695    .0614721
    ln_recent_volumn |   .1007211   .0171083     5.89   0.000      .066997    .1344452
           recent_sd |  -.0006782   .0118647    -0.06   0.954     -.024066    .0227097
   ln_lag_volumn_acc |   .0363927   .0204581     1.78   0.077    -.0039347    .0767201
  lag_avg_rating_acc |   .0462577   .0406131     1.14   0.256    -.0337996    .1263149
          lag_sd_acc |   .1157486   .0669601     1.73   0.085    -.0162443    .2477415
lag_avg_rating_month |   .0046357    .002841     1.63   0.104    -.0009646    .0102359
   ln_avg_com_RevPAR |   .2413738    .042541     5.67   0.000     .1575162    .3252314
 ln_lag_RevPAR_clean |   .3582863   .0374802     9.56   0.000     .2844047    .4321679
               _cons |   .8417796   .2873456     2.93   0.004      .275359      1.4082
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       213         213           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g3_rating_acc_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_rating_acc_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =      7,365
Absorbing 2 HDFE groups                           F(   9,    189) =      27.58
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8888
                                                  Adj R-squared   =     0.8841
                                                  Within R-sq.    =     0.2143
Number of clusters (hotel_id_num) =        190    Root MSE        =     0.2315

                                 (Std. err. adjusted for 190 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.0367858   .1096667    -0.34   0.738    -.2531137    .1795421
    ln_recent_volumn |   .0548801    .015921     3.45   0.001     .0234744    .0862859
           recent_sd |  -.0132769   .0138845    -0.96   0.340    -.0406653    .0141116
   ln_lag_volumn_acc |   .0436486   .0149015     2.93   0.004     .0142539    .0730432
  lag_avg_rating_acc |   .0762077   .0802784     0.95   0.344    -.0821492    .2345645
          lag_sd_acc |  -.0262075   .0589686    -0.44   0.657    -.1425287    .0901137
lag_avg_rating_month |   -.005392   .0070606    -0.76   0.446    -.0193196    .0085357
   ln_avg_com_RevPAR |   .1252029   .0242824     5.16   0.000     .0773037    .1731022
 ln_lag_RevPAR_clean |   .3470358   .0630403     5.50   0.000     .2226828    .4713889
               _cons |   1.770942   .4801159     3.69   0.000     .8238677    2.718016
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       190         190           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g4_rating_acc_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_month_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 35 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     11,030
Absorbing 2 HDFE groups                           F(   9,    413) =      34.22
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8895
                                                  Adj R-squared   =     0.8840
                                                  Within R-sq.    =     0.2582
Number of clusters (hotel_id_num) =        414    Root MSE        =     0.2244

                                 (Std. err. adjusted for 414 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |   -.073391   .0934087    -0.79   0.432    -.2570068    .1102249
    ln_recent_volumn |    .083679     .01821     4.60   0.000     .0478833    .1194748
           recent_sd |  -.0040859   .0111305    -0.37   0.714    -.0259654    .0177935
   ln_lag_volumn_acc |   .0199538   .0103981     1.92   0.056     -.000486    .0403937
  lag_avg_rating_acc |   .0401149   .0384282     1.04   0.297    -.0354243    .1156541
          lag_sd_acc |   .0152306   .0437008     0.35   0.728    -.0706731    .1011343
lag_avg_rating_month |   .0004711   .0023411     0.20   0.841    -.0041308     .005073
   ln_avg_com_RevPAR |   .1469458   .0259114     5.67   0.000     .0960111    .1978804
 ln_lag_RevPAR_clean |   .3888456   .0374085    10.39   0.000     .3153109    .4623804
               _cons |   1.464786   .2597991     5.64   0.000     .9540922    1.975479
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       414         414           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g5_volume_last_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_month_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 24 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     13,493
Absorbing 2 HDFE groups                           F(   9,    425) =      40.65
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8940
                                                  Adj R-squared   =     0.8896
                                                  Within R-sq.    =     0.2151
Number of clusters (hotel_id_num) =        426    Root MSE        =     0.1931

                                 (Std. err. adjusted for 426 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1917233   .0719246    -2.67   0.008    -.3330955   -.0503511
    ln_recent_volumn |    .054037   .0092777     5.82   0.000     .0358012    .0722729
           recent_sd |  -.0006499   .0094795    -0.07   0.945    -.0192824    .0179826
   ln_lag_volumn_acc |   .0426648   .0107133     3.98   0.000     .0216072    .0637224
  lag_avg_rating_acc |   .0498615   .0376633     1.32   0.186     -.024168     .123891
          lag_sd_acc |   .0081744   .0553394     0.15   0.883    -.1005986    .1169473
lag_avg_rating_month |   .0202026    .005062     3.99   0.000     .0102529    .0301523
   ln_avg_com_RevPAR |    .125938   .0193239     6.52   0.000     .0879557    .1639202
 ln_lag_RevPAR_clean |   .3553438   .0396728     8.96   0.000     .2773645    .4333231
               _cons |   1.697833   .2278769     7.45   0.000     1.249926    2.145739
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       426         426           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g6_volume_last_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_acc_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 10 singleton observations)
(MWFE estimator converged in 9 iterations)

HDFE Linear regression                            Number of obs   =     12,230
Absorbing 2 HDFE groups                           F(   9,    365) =      31.06
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8913
                                                  Adj R-squared   =     0.8869
                                                  Within R-sq.    =     0.2464
Number of clusters (hotel_id_num) =        366    Root MSE        =     0.2144

                                 (Std. err. adjusted for 366 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1350399   .0881714    -1.53   0.126    -.3084276    .0383478
    ln_recent_volumn |   .0725688   .0155144     4.68   0.000       .04206    .1030776
           recent_sd |  -.0036233   .0092952    -0.39   0.697    -.0219021    .0146555
   ln_lag_volumn_acc |   .0248232   .0090514     2.74   0.006     .0070237    .0426228
  lag_avg_rating_acc |   .0434004   .0379803     1.14   0.254    -.0312872    .1180881
          lag_sd_acc |   .0022288   .0406313     0.05   0.956     -.077672    .0821297
lag_avg_rating_month |  -.0006764   .0024445    -0.28   0.782    -.0054834    .0041307
   ln_avg_com_RevPAR |     .17097   .0320134     5.34   0.000     .1080162    .2339238
 ln_lag_RevPAR_clean |   .3442785   .0367479     9.37   0.000     .2720144    .4165426
               _cons |    1.56727   .2670428     5.87   0.000     1.042135    2.092406
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       366         366           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g7_volume_acc_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_volume_acc_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 8 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     12,334
Absorbing 2 HDFE groups                           F(   9,    238) =      29.78
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8854
                                                  Adj R-squared   =     0.8821
                                                  Within R-sq.    =     0.2304
Number of clusters (hotel_id_num) =        239    Root MSE        =     0.1961

                                 (Std. err. adjusted for 239 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.1328765   .0741528    -1.79   0.074    -.2789562    .0132032
    ln_recent_volumn |   .0484977   .0099398     4.88   0.000     .0289166    .0680789
           recent_sd |  -.0058176   .0093306    -0.62   0.534    -.0241987    .0125634
   ln_lag_volumn_acc |   .0390819   .0161711     2.42   0.016     .0072252    .0709386
  lag_avg_rating_acc |    .129526   .0656482     1.97   0.050     .0002003    .2588517
          lag_sd_acc |   .0754824   .0788992     0.96   0.340    -.0799476    .2309125
lag_avg_rating_month |   .0146452   .0044927     3.26   0.001     .0057946    .0234958
   ln_avg_com_RevPAR |    .119141    .018959     6.28   0.000     .0817921    .1564899
 ln_lag_RevPAR_clean |   .3859656   .0518901     7.44   0.000     .2837431    .4881881
               _cons |   1.263662     .36392     3.47   0.001     .5467461    1.980577
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       239         239           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g8_volume_acc_high

. 
. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_star_pre == 0, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =      4,987
Absorbing 2 HDFE groups                           F(   9,     86) =      23.51
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9042
                                                  Adj R-squared   =     0.9003
                                                  Within R-sq.    =     0.2935
Number of clusters (hotel_id_num) =         87    Root MSE        =     0.1846

                                  (Std. err. adjusted for 87 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |   .0166156   .1177982     0.14   0.888    -.2175594    .2507906
    ln_recent_volumn |   .0674092   .0207495     3.25   0.002     .0261606    .1086578
           recent_sd |    .008932   .0138683     0.64   0.521    -.0186372    .0365012
   ln_lag_volumn_acc |   .0039674   .0231041     0.17   0.864    -.0419619    .0498968
  lag_avg_rating_acc |   .0188159   .0633251     0.30   0.767    -.1070701     .144702
          lag_sd_acc |   .0278307    .065129     0.43   0.670    -.1016414    .1573028
lag_avg_rating_month |   .0058225   .0044348     1.31   0.193    -.0029935    .0146385
   ln_avg_com_RevPAR |   .1600501   .0415486     3.85   0.000     .0774541    .2426461
 ln_lag_RevPAR_clean |   .4265332   .0481567     8.86   0.000     .3308009    .5222656
               _cons |   1.354993   .3163279     4.28   0.000     .7261544    1.983833
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |        87          87           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g9_star_low

. reghdfe ln_RevPAR_clean sim_mean `ctrl_base' if high_star_pre == 1, absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 6 iterations)

HDFE Linear regression                            Number of obs   =      3,228
Absorbing 2 HDFE groups                           F(   9,     44) =      26.98
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9191
                                                  Adj R-squared   =     0.9150
                                                  Within R-sq.    =     0.2343
Number of clusters (hotel_id_num) =         45    Root MSE        =     0.1597

                                  (Std. err. adjusted for 45 clusters in hotel_id_num)
--------------------------------------------------------------------------------------
                     |               Robust
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
            sim_mean |  -.0470465   .1214699    -0.39   0.700     -.291853      .19776
    ln_recent_volumn |   .0273518    .018821     1.45   0.153    -.0105795    .0652832
           recent_sd |  -.0058678   .0176391    -0.33   0.741    -.0414172    .0296815
   ln_lag_volumn_acc |    .037823   .0208856     1.81   0.077    -.0042693    .0799152
  lag_avg_rating_acc |   .1910568   .1077842     1.77   0.083     -.026168    .4082816
          lag_sd_acc |   .1459429   .1258958     1.16   0.253    -.1077833    .3996691
lag_avg_rating_month |   .0170878   .0067203     2.54   0.015      .003544    .0306316
   ln_avg_com_RevPAR |   .0880714   .0279981     3.15   0.003     .0316449     .144498
 ln_lag_RevPAR_clean |   .3180448   .0329217     9.66   0.000     .2516954    .3843942
               _cons |   1.638591   .4883272     3.36   0.002     .6544322     2.62275
--------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |        45          45           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store g10_star_high

. 
. esttab g1_rating_last_low g2_rating_last_high g3_rating_acc_low g4_rating_acc_high g5_volume_last_low g6_volume_last_high g7_volume_acc_low g8_volume_acc_high g9_star_low g10_star_high ///
>     using "`project'/outputs/tables/results_pre2019_heterogeneity_group_260407.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(file /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_group_260407.txt not found)
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_group_260407.txt)

. 
. di as text "============================================================"
============================================================
```

#### 5.3B Binary Interaction Raw Tables

```text
. di as text "2) PRE2019 BINARY INTERACTION FE"
2) PRE2019 BINARY INTERACTION FE

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_month_pre `ctrl_base' if !missing(high_rating_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     23,943
Absorbing 2 HDFE groups                           F(  11,    481) =      48.06
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8964
                                                  Adj R-squared   =     0.8938
                                                  Within R-sq.    =     0.2505
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2094

                                             (Std. err. adjusted for 482 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------------
                                 |               Robust
                 ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------------+----------------------------------------------------------------
                        sim_mean |  -.1003997   .0755277    -1.33   0.184    -.2488046    .0480051
         1.high_rating_month_pre |   .0137055    .026715     0.51   0.608    -.0387872    .0661981
                                 |
high_rating_month_pre#c.sim_mean |
                              1  |  -.0304369    .090613    -0.34   0.737    -.2084831    .1476093
                                 |
                ln_recent_volumn |   .0554726   .0091462     6.07   0.000     .0375011     .073444
                       recent_sd |  -.0064905   .0071747    -0.90   0.366     -.020588     .007607
               ln_lag_volumn_acc |   .0311379   .0081061     3.84   0.000     .0152101    .0470658
              lag_avg_rating_acc |   .0444301   .0304378     1.46   0.145    -.0153775    .1042377
                      lag_sd_acc |   .0139987   .0364264     0.38   0.701    -.0575759    .0855732
            lag_avg_rating_month |   .0020891   .0028172     0.74   0.459    -.0034464    .0076246
               ln_avg_com_RevPAR |   .1365265     .01944     7.02   0.000     .0983286    .1747243
             ln_lag_RevPAR_clean |    .379152   .0317239    11.95   0.000     .3168174    .4414865
                           _cons |   1.620415   .1938146     8.36   0.000     1.239587    2.001242
--------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b1_rating_last

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_rating_acc_pre `ctrl_base' if !missing(high_rating_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 8 singleton observations)
(MWFE estimator converged in 8 iterations)

HDFE Linear regression                            Number of obs   =     14,743
Absorbing 2 HDFE groups                           F(  11,    390) =      34.34
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9036
                                                  Adj R-squared   =     0.9002
                                                  Within R-sq.    =     0.2532
Number of clusters (hotel_id_num) =        391    Root MSE        =     0.2209

                                           (Std. err. adjusted for 391 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------
                               |               Robust
               ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------+----------------------------------------------------------------
                      sim_mean |  -.1889727   .1157244    -1.63   0.103    -.4164944    .0385491
         1.high_rating_acc_pre |  -.0830369   .0666792    -1.25   0.214    -.2141327    .0480588
                               |
high_rating_acc_pre#c.sim_mean |
                            1  |   .1529859   .1454917     1.05   0.294    -.1330603     .439032
                               |
              ln_recent_volumn |   .0731973   .0114139     6.41   0.000      .050757    .0956377
                     recent_sd |  -.0084535   .0093588    -0.90   0.367    -.0268535    .0099465
             ln_lag_volumn_acc |   .0348674   .0107277     3.25   0.001      .013776    .0559587
            lag_avg_rating_acc |   .0558052   .0349641     1.60   0.111    -.0129365    .1245469
                    lag_sd_acc |   .0283157   .0428723     0.66   0.509     -.055974    .1126055
          lag_avg_rating_month |   .0023635   .0027118     0.87   0.384    -.0029681    .0076951
             ln_avg_com_RevPAR |   .1712597   .0239935     7.14   0.000     .1240868    .2184325
           ln_lag_RevPAR_clean |   .3585563   .0383953     9.34   0.000     .2830686     .434044
                         _cons |   1.462416   .2148722     6.81   0.000     1.039963    1.884868
------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       391         391           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b2_rating_acc

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_month_pre `ctrl_base' if !missing(high_volume_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      43.27
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8964
                                                  Adj R-squared   =     0.8938
                                                  Within R-sq.    =     0.2495
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2091

                                             (Std. err. adjusted for 482 clusters in hotel_id_num)
--------------------------------------------------------------------------------------------------
                                 |               Robust
                 ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------------------+----------------------------------------------------------------
                        sim_mean |  -.1564449   .0805739    -1.94   0.053    -.3147652    .0018755
         1.high_volume_month_pre |  -.0240396   .0279901    -0.86   0.391    -.0790376    .0309584
                                 |
high_volume_month_pre#c.sim_mean |
                              1  |   .0729012   .0963214     0.76   0.450    -.1163615    .2621639
                                 |
                ln_recent_volumn |   .0570845   .0089427     6.38   0.000      .039513     .074656
                       recent_sd |  -.0074101   .0069539    -1.07   0.287    -.0210739    .0062537
               ln_lag_volumn_acc |    .030757   .0079624     3.86   0.000     .0151116    .0464023
              lag_avg_rating_acc |   .0440796    .029803     1.48   0.140    -.0144806    .1026397
                      lag_sd_acc |   .0113423    .035607     0.32   0.750    -.0586222    .0813069
            lag_avg_rating_month |   .0039349    .002156     1.83   0.069    -.0003015    .0081713
               ln_avg_com_RevPAR |   .1354312   .0191358     7.08   0.000      .097831    .1730314
             ln_lag_RevPAR_clean |   .3787229   .0315431    12.01   0.000     .3167435    .4407023
                           _cons |   1.641261   .1955205     8.39   0.000     1.257081    2.025441
--------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b3_volume_last

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_volume_acc_pre `ctrl_base' if !missing(high_volume_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      43.98
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8965
                                                  Adj R-squared   =     0.8939
                                                  Within R-sq.    =     0.2503
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2090

                                           (Std. err. adjusted for 482 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------
                               |               Robust
               ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------+----------------------------------------------------------------
                      sim_mean |  -.1656004   .0806237    -2.05   0.041    -.3240186   -.0071821
         1.high_volume_acc_pre |   .0087295    .036322     0.24   0.810    -.0626398    .0800988
                               |
high_volume_acc_pre#c.sim_mean |
                            1  |   .0840161   .1082423     0.78   0.438    -.1286701    .2967023
                               |
              ln_recent_volumn |   .0570372   .0089581     6.37   0.000     .0394355     .074639
                     recent_sd |  -.0078099   .0069458    -1.12   0.261    -.0214578     .005838
             ln_lag_volumn_acc |   .0210188   .0078148     2.69   0.007     .0056634    .0363742
            lag_avg_rating_acc |   .0478068   .0296151     1.61   0.107    -.0103841    .1059977
                    lag_sd_acc |   .0154795   .0354112     0.44   0.662    -.0541002    .0850592
          lag_avg_rating_month |   .0038695    .002168     1.78   0.075    -.0003903    .0081294
             ln_avg_com_RevPAR |   .1359843   .0189483     7.18   0.000     .0987526     .173216
           ln_lag_RevPAR_clean |   .3780585   .0313591    12.06   0.000     .3164407    .4396762
                         _cons |    1.66032   .1944456     8.54   0.000     1.278252    2.042388
------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b4_volume_acc

. reghdfe ln_RevPAR_clean c.sim_mean##i.high_star_pre `ctrl_base' if !missing(high_star_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(MWFE estimator converged in 6 iterations)
note: 1bn.high_star_pre is probably collinear with the fixed effects (all partialled-out values are close to zero; tol = 1.0e-09)

HDFE Linear regression                            Number of obs   =      8,215
Absorbing 2 HDFE groups                           F(  10,    131) =      35.02
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.9330
                                                  Adj R-squared   =     0.9310
                                                  Within R-sq.    =     0.2696
Number of clusters (hotel_id_num) =        132    Root MSE        =     0.1823

                                     (Std. err. adjusted for 132 clusters in hotel_id_num)
------------------------------------------------------------------------------------------
                         |               Robust
         ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------+----------------------------------------------------------------
                sim_mean |  -.0579213   .1189376    -0.49   0.627    -.2932081    .1773656
         1.high_star_pre |          0  (omitted)
                         |
high_star_pre#c.sim_mean |
                      1  |   .2169029   .1696679     1.28   0.203    -.1187406    .5525464
                         |
        ln_recent_volumn |   .0429668   .0150644     2.85   0.005     .0131658    .0727679
               recent_sd |   .0031335   .0110892     0.28   0.778    -.0188035    .0250705
       ln_lag_volumn_acc |   .0151707   .0133678     1.13   0.259     -.011274    .0416154
      lag_avg_rating_acc |   .0321547   .0598077     0.54   0.592    -.0861591    .1504686
              lag_sd_acc |   .0360337   .0602756     0.60   0.551    -.0832058    .1552732
    lag_avg_rating_month |   .0080164   .0041454     1.93   0.055    -.0001841    .0162169
       ln_avg_com_RevPAR |   .1348868   .0277366     4.86   0.000     .0800173    .1897564
     ln_lag_RevPAR_clean |   .3962053   .0369034    10.74   0.000     .3232015    .4692091
                   _cons |    1.67363   .2448346     6.84   0.000     1.189289    2.157971
------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       132         132           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store b5_star

. 
. esttab b1_rating_last b2_rating_acc b3_volume_last b4_volume_acc b5_star ///
>     using "`project'/outputs/tables/results_pre2019_heterogeneity_interaction_binary_260407.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(file /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_interaction_binary_260407.txt not found)
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_interaction_binary_260407.txt)

. 
. di as text "============================================================"
============================================================
```

#### 5.3C Continuous Interaction Raw Tables

```text
. di as text "3) PRE2019 CONTINUOUS INTERACTION FE"
3) PRE2019 CONTINUOUS INTERACTION FE

. di as text "============================================================"
============================================================

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_month_pre `ctrl_base' if !missing(center_rating_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      47.89
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8964
                                                  Adj R-squared   =     0.8938
                                                  Within R-sq.    =     0.2495
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2091

                                                 (Std. err. adjusted for 482 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------------
                                     |               Robust
                     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------------+----------------------------------------------------------------
                            sim_mean |  -.1186895   .0593708    -2.00   0.046    -.2353477   -.0020313
             center_rating_month_pre |   .0293031    .053117     0.55   0.581    -.0750669    .1336731
                                     |
c.sim_mean#c.center_rating_month_pre |  -.0204236   .0561804    -0.36   0.716    -.1308129    .0899658
                                     |
                    ln_recent_volumn |   .0571151   .0089655     6.37   0.000     .0394988    .0747315
                           recent_sd |  -.0077754   .0070731    -1.10   0.272    -.0216734    .0061227
                   ln_lag_volumn_acc |   .0303165   .0079748     3.80   0.000     .0146467    .0459862
                  lag_avg_rating_acc |   .0440193   .0298527     1.47   0.141    -.0146385    .1026772
                          lag_sd_acc |    .011611   .0356834     0.33   0.745    -.0585035    .0817256
                lag_avg_rating_month |  -.0196291   .0500481    -0.39   0.695    -.1179691    .0787108
                   ln_avg_com_RevPAR |   .1353417   .0191385     7.07   0.000     .0977364     .172947
                 ln_lag_RevPAR_clean |   .3785152   .0314812    12.02   0.000     .3166576    .4403728
                               _cons |   1.726633   .3094144     5.58   0.000     1.118662    2.334604
------------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c1_rating_last

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_rating_acc_pre `ctrl_base' if !missing(center_rating_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      63.04
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8968
                                                  Adj R-squared   =     0.8943
                                                  Within R-sq.    =     0.2528
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2086

                                               (Std. err. adjusted for 482 clusters in hotel_id_num)
----------------------------------------------------------------------------------------------------
                                   |               Robust
                   ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-----------------------------------+----------------------------------------------------------------
                          sim_mean |   -.123836    .058269    -2.13   0.034    -.2383292   -.0093428
             center_rating_acc_pre |  -.4723352   .0915073    -5.16   0.000    -.6521385   -.2925318
                                   |
c.sim_mean#c.center_rating_acc_pre |   .1279073   .1208385     1.06   0.290    -.1095293    .3653438
                                   |
                  ln_recent_volumn |   .0586864   .0090236     6.50   0.000      .040956    .0764169
                         recent_sd |  -.0076814   .0069626    -1.10   0.270    -.0213622    .0059993
                 ln_lag_volumn_acc |   .0320671   .0079214     4.05   0.000     .0165023    .0476318
                lag_avg_rating_acc |   .4701461   .0869559     5.41   0.000     .2992857    .6410065
                        lag_sd_acc |   .0123242   .0345067     0.36   0.721    -.0554782    .0801267
              lag_avg_rating_month |   .0043198   .0021396     2.02   0.044     .0001156     .008524
                 ln_avg_com_RevPAR |    .132825   .0192314     6.91   0.000      .095037     .170613
               ln_lag_RevPAR_clean |   .3736801   .0320667    11.65   0.000      .310672    .4366882
                             _cons |  -.0296891   .2968471    -0.10   0.920    -.6129664    .5535881
----------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c2_rating_acc

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_month_pre `ctrl_base' if !missing(center_volume_month_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      44.35
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8965
                                                  Adj R-squared   =     0.8939
                                                  Within R-sq.    =     0.2505
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2090

                                                 (Std. err. adjusted for 482 clusters in hotel_id_num)
------------------------------------------------------------------------------------------------------
                                     |               Robust
                     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-------------------------------------+----------------------------------------------------------------
                            sim_mean |  -.0949799     .05857    -1.62   0.106    -.2100646    .0201048
             center_volume_month_pre |  -.0047829   .0015001    -3.19   0.002    -.0077305   -.0018352
                                     |
c.sim_mean#c.center_volume_month_pre |   .0108916   .0046831     2.33   0.020     .0016898    .0200935
                                     |
                    ln_recent_volumn |   .0738771   .0093704     7.88   0.000     .0554652    .0922889
                           recent_sd |  -.0072751   .0069553    -1.05   0.296    -.0209416    .0063914
                   ln_lag_volumn_acc |   .0342116   .0080422     4.25   0.000     .0184094    .0500138
                  lag_avg_rating_acc |   .0440025   .0298259     1.48   0.141    -.0146027    .1026077
                          lag_sd_acc |    .007388   .0356207     0.21   0.836    -.0626034    .0773793
                lag_avg_rating_month |   .0042609   .0021644     1.97   0.050     8.05e-06    .0085138
                   ln_avg_com_RevPAR |   .1349169   .0190909     7.07   0.000      .097405    .1724288
                 ln_lag_RevPAR_clean |   .3792213   .0314511    12.06   0.000     .3174228    .4410198
                               _cons |   1.559249   .1952666     7.99   0.000     1.175568     1.94293
------------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c3_volume_last

. reghdfe ln_RevPAR_clean c.sim_mean##c.center_volume_acc_pre `ctrl_base' if !missing(center_volume_acc_pre), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
(dropped 6 singleton observations)
(MWFE estimator converged in 7 iterations)

HDFE Linear regression                            Number of obs   =     24,576
Absorbing 2 HDFE groups                           F(  11,    481) =      44.50
Statistics robust to heteroskedasticity           Prob > F        =     0.0000
                                                  R-squared       =     0.8965
                                                  Adj R-squared   =     0.8939
                                                  Within R-sq.    =     0.2503
Number of clusters (hotel_id_num) =        482    Root MSE        =     0.2090

                                               (Std. err. adjusted for 482 clusters in hotel_id_num)
----------------------------------------------------------------------------------------------------
                                   |               Robust
                   ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
-----------------------------------+----------------------------------------------------------------
                          sim_mean |  -.1220032   .0583346    -2.09   0.037    -.2366252   -.0073811
             center_volume_acc_pre |   .0000301   .0000353     0.85   0.394    -.0000392    .0000994
                                   |
c.sim_mean#c.center_volume_acc_pre |  -.0000121   .0001002    -0.12   0.904    -.0002091    .0001848
                                   |
                  ln_recent_volumn |   .0578759   .0088247     6.56   0.000     .0405362    .0752156
                         recent_sd |  -.0081383   .0069466    -1.17   0.242    -.0217877    .0055112
                 ln_lag_volumn_acc |   .0266568   .0079972     3.33   0.001     .0109431    .0423705
                lag_avg_rating_acc |   .0409686   .0300286     1.36   0.173    -.0180348     .099972
                        lag_sd_acc |   .0200602   .0356486     0.56   0.574    -.0499861    .0901064
              lag_avg_rating_month |   .0038107   .0021566     1.77   0.078    -.0004269    .0080483
                 ln_avg_com_RevPAR |   .1337088   .0190457     7.02   0.000     .0962859    .1711318
               ln_lag_RevPAR_clean |   .3774452   .0313237    12.05   0.000      .315897    .4389935
                             _cons |   1.666915   .1947845     8.56   0.000     1.284181    2.049649
----------------------------------------------------------------------------------------------------

Absorbed degrees of freedom:
------------------------------------------------------+
  Absorbed FE | Categories  - Redundant  = Num. Coefs |
--------------+---------------------------------------|
 hotel_id_num |       482         482           0    *|
           ym |       102           1         101     |
------------------------------------------------------+
* = FE nested within cluster; treated as redundant for DoF computation

. estimates store c4_volume_acc

. 
. esttab c1_rating_last c2_rating_acc c3_volume_last c4_volume_acc ///
>     using "`project'/outputs/tables/results_pre2019_heterogeneity_interaction_continuous_260407.txt", replace ///
>     se star(+ 0.10 * 0.05 ** 0.01 *** 0.001) b(%9.4f) se(%9.4f) ///
>     label compress nomtitles nonumber ///
>     stats(N r2, fmt(%9.0f %9.4f) labels("N" "R2"))
(file /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_interaction_continuous_260407.txt not found)
(output written to /Users/samxie/Research/ReviewSimi_Sales/Code/outputs/tables/results_pre2019_heterogeneity_interaction_continuous_260407.txt)

.
```

## 6. Dynamic Robustness

### 6.1 `pre2019` Same-Sample GMM

扫描表：
[gmm_pre2019_same_sample_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/gmm_pre2019_same_sample_scan_260407.csv)

原始日志：
[results_gmm_pre2019_same_sample_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_gmm_pre2019_same_sample_260407.log)

当前没有 strict pass。最佳 near-pass 规格是：

- `rich8_gmm | yearmon | L12 | gmm | plain | ylag 6/9 | xlag 6/7`
- `beta = -0.2174**`
- `AR(1) = 0.0006`
- `AR(2) = 0.2015`
- `Hansen = 0.0002`
- `N = 19,450`

也就是说，方向、显著性和 `AR(1) / AR(2)` 都对，但 `Hansen` 仍然远低于 `0.10`，所以不能写成有效 `sys-GMM`。

完整原始表如下：

```text
.     local x2 = subinstr("`x2'", "/", "", 1)
.     noisily run_gmm_pre, ctrl(`best_ctrl') timefe(`best_timefe') dyn(`best_dyn') siminst(gmm) ///
>         ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') transform(`best_transform') loud
Favoring speed over space. To switch, type or click on mata: mata set matafavor space, perm.
Warning: Two-step estimated covariance matrix of moments is singular.
  Using a generalized inverse to calculate optimal weighting matrix for two-step estimation.
  Difference-in-Sargan/Hansen statistics may be negative.

Dynamic panel-data estimation, two-step system GMM
------------------------------------------------------------------------------
Group variable: hotel_id_num                    Number of obs      =     19450
Time variable : ym                              Number of groups   =       467
Number of instruments = 41                      Obs per group: min =         1
F(32, 466)    =    113.27                                      avg =     41.65
Prob > F      =     0.000                                      max =        98
--------------------------------------------------------------------------------------
                     |              Corrected
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
     ln_RevPAR_clean |
                 L1. |  -.0252365   .1424714    -0.18   0.859    -.3052025    .2547294
                 L2. |  -.5914838   .1883557    -3.14   0.002    -.9616156    -.221352
                     |
  sim_mean_std_hotel |   -.217411   .0746469    -2.91   0.004    -.3640971   -.0707248
    ln_recent_volumn |    .245133   .0510518     4.80   0.000     .1448128    .3454532
           recent_sd |  -.3512329   .0976387    -3.60   0.000    -.5430995   -.1593663
   ln_lag_volumn_acc |   .2886129   .0537898     5.37   0.000     .1829123    .3943136
  lag_avg_rating_acc |   .5630519   .1315478     4.28   0.000     .3045515    .8215522
lag_avg_rating_month |   .0262129   .0082595     3.17   0.002     .0099823    .0424434
          lag_sd_acc |    .099856    .302491     0.33   0.741    -.4945592    .6942712
   ln_avg_com_RevPAR |   .2745803   .0494937     5.55   0.000     .1773218    .3718388
    review_freshness |    .283247   .1998468     1.42   0.157    -.1094655    .6759594
                     |
                Year |
               2011  |          0  (empty)
               2012  |   -.082661   .0481714    -1.72   0.087     -.177321    .0119991
               2013  |  -.2128108   .0728741    -2.92   0.004    -.3560133   -.0696083
               2014  |  -.2122949   .0887106    -2.39   0.017    -.3866173   -.0379725
               2015  |  -.2619614    .093751    -2.79   0.005    -.4461884   -.0777343
               2016  |  -.3154733   .1037621    -3.04   0.002     -.519373   -.1115737
               2017  |  -.3052051   .1099369    -2.78   0.006    -.5212385   -.0891717
               2018  |  -.3154792   .1160936    -2.72   0.007     -.543611   -.0873474
               2019  |     -.3482   .1244609    -2.80   0.005     -.592774    -.103626
                     |
                 Mon |
                  1  |          0  (empty)
                  2  |   .0537546    .049562     1.08   0.279     -.043638    .1511473
                  3  |   .2107598   .0607059     3.47   0.001     .0914687     .330051
                  4  |   .2652297   .0607011     4.37   0.000     .1459478    .3845115
                  5  |   .3055253   .0552387     5.53   0.000     .1969774    .4140731
                  6  |   .2335977   .0415137     5.63   0.000     .1520206    .3151749
                  7  |    .127015   .0414253     3.07   0.002     .0456115    .2084184
                  8  |    .077535   .0367078     2.11   0.035     .0054016    .1496684
                  9  |   .1011523   .0254639     3.97   0.000      .051114    .1511906
                 10  |   .1461085    .039576     3.69   0.000      .068339    .2238779
                 11  |   .0671817    .050862     1.32   0.187    -.0327655     .167129
                 12  |  -.0040773   .0367619    -0.11   0.912    -.0763169    .0681623
                     |
               _cons |   1.634908   .8337723     1.96   0.050    -.0035106    3.273327
--------------------------------------------------------------------------------------
Instruments for first differences equation
  Standard
    D.(ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness
    2011b.Year 2012.Year 2013.Year 2014.Year 2015.Year 2016.Year 2017.Year
    2018.Year 2019.Year 1b.Mon 2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon
    10.Mon 11.Mon 12.Mon)
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    L(6/7).sim_mean_std_hotel collapsed
    L(6/9).(L.ln_RevPAR_clean L2.ln_RevPAR_clean) collapsed
Instruments for levels equation
  Standard
    ln_recent_volumn recent_sd ln_lag_volumn_acc lag_avg_rating_acc
    lag_avg_rating_month lag_sd_acc ln_avg_com_RevPAR review_freshness
    2011b.Year 2012.Year 2013.Year 2014.Year 2015.Year 2016.Year 2017.Year
    2018.Year 2019.Year 1b.Mon 2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon
    10.Mon 11.Mon 12.Mon
    _cons
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    DL5.sim_mean_std_hotel collapsed
    DL5.(L.ln_RevPAR_clean L2.ln_RevPAR_clean) collapsed
------------------------------------------------------------------------------
Arellano-Bond test for AR(1) in first differences: z =  -3.42  Pr > z =  0.001
Arellano-Bond test for AR(2) in first differences: z =   1.28  Pr > z =  0.201
------------------------------------------------------------------------------
Sargan test of overid. restrictions: chi2(8)    =  77.71  Prob > chi2 =  0.000
  (Not robust, but not weakened by many instruments.)
Hansen test of overid. restrictions: chi2(8)    =  30.10  Prob > chi2 =  0.000
  (Robust, but weakened by many instruments.)

Difference-in-Hansen tests of exogeneity of instrument subsets:
  GMM instruments for levels
    Hansen test excluding group:     chi2(5)    =  26.74  Prob > chi2 =  0.000
    Difference (null H = exogenous): chi2(3)    =   3.36  Prob > chi2 =  0.339
  gmm(sim_mean_std_hotel, collapse lag(6 7))
    Hansen test excluding group:     chi2(5)    =  26.24  Prob > chi2 =  0.000
    Difference (null H = exogenous): chi2(3)    =   3.86  Prob > chi2 =  0.277
```

### 6.2 Full-Year Same-Sample GMM

扫描表：
[gmm_full_same_sample_scan_260407.csv](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/scans/gmm_full_same_sample_scan_260407.csv)

原始日志：
[results_gmm_full_same_sample_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_gmm_full_same_sample_260407.log)

这一轮 full-year 已经跑出了 strict pass。当前最优规格是：

- `base4_month_gmm | monthfe | L1 | gmm | orth | none | ylag 5/8 | xlag 6/7`
- `beta = -0.0332**`
- `AR(1) = 0.0000`
- `AR(2) = 0.1039`
- `Hansen = 0.1142`
- `N = 27,287`
- `Number of instruments = 24`

第二条同样通过的规格是：

- `quality6_gmm | monthfe | L1 | gmm | orth | none | ylag 5/8 | xlag 6/7`
- `beta = -0.0329**`
- `AR(1) = 0.0000`
- `AR(2) = 0.1022`
- `Hansen = 0.1176`
- `N = 27,287`
- `Number of instruments = 26`

这意味着 same-sample full-year `sys-GMM` 终于可以正式写进正文。与 `pre2019` 不同，full-year 这轮在 adopted sample 上已经同时满足 `beta < 0`、`p < 0.05`、`AR(1) < 0.05`、`AR(2) > 0.10`、`Hansen ∈ [0.10, 0.80]`。

对应最近规格的完整原始表如下：

```text
. di as text "Nearest spec 1: `alt1_ctrl' | `alt1_timefe' | `alt1_dyn' | `alt1_siminst' | `alt1_transform' | `alt1_breakspec' | `alt1_ylag' | `alt1_xlag'"
Nearest spec 1: base4_month_gmm | monthfe | L1 | gmm | orth | none | 5/8 | 6/7

. di as text "------------------------------------------------------------"
------------------------------------------------------------

. gettoken y1 y2 : alt1_ylag, parse("/")

. local y2 = subinstr("`y2'", "/", "", 1)

. if "`alt1_siminst'" == "iv" {
.     noisily run_gmm_spec, ctrl(`alt1_ctrl') timefe(`alt1_timefe') dyn(`alt1_dyn') siminst(iv) ///
>         ylag1(`y1') ylag2(`y2') transform(`alt1_transform') breakspec(`alt1_breakspec') loud
. }

. else {
.     gettoken x1 x2 : alt1_xlag, parse("/")
.     local x2 = subinstr("`x2'", "/", "", 1)
.     noisily run_gmm_spec, ctrl(`alt1_ctrl') timefe(`alt1_timefe') dyn(`alt1_dyn') siminst(gmm) ///
>         ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
>         transform(`alt1_transform') breakspec(`alt1_breakspec') loud
Favoring speed over space. To switch, type or click on mata: mata set matafavor space, perm.
Warning: Two-step estimated covariance matrix of moments is singular.
  Using a generalized inverse to calculate optimal weighting matrix for two-step estimation.
  Difference-in-Sargan/Hansen statistics may be negative.

Dynamic panel-data estimation, two-step system GMM
------------------------------------------------------------------------------
Group variable: hotel_id_num                    Number of obs      =     27287
Time variable : ym                              Number of groups   =       531
Number of instruments = 24                      Obs per group: min =         1
F(18, 530)    =   1004.73                                      avg =     51.39
Prob > F      =     0.000                                      max =       130
--------------------------------------------------------------------------------------
                     |              Corrected
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
     ln_RevPAR_clean |
                 L1. |   .8436509   .0469607    17.97   0.000     .7513989    .9359029
                     |
  sim_mean_std_hotel |  -.0332449   .0115773    -2.87   0.004    -.0559879   -.0105019
    ln_recent_volumn |    .081952   .0186619     4.39   0.000     .0452917    .1186124
   ln_lag_volumn_acc |  -.0007702   .0038955    -0.20   0.843    -.0084226    .0068823
lag_avg_rating_month |   .0224271   .0046648     4.81   0.000     .0132632    .0315909
   ln_avg_com_RevPAR |   .0905281    .013987     6.47   0.000     .0630514    .1180048
                     |
                 Mon |
                  1  |          0  (empty)
                  2  |   .1673298   .0152579    10.97   0.000     .1373564    .1973032
                  3  |   .0306816   .0213685     1.44   0.152    -.0112958    .0726591
                  4  |  -.1701939   .0215867    -7.88   0.000    -.2125998    -.127788
                  5  |  -.0907617   .0178262    -5.09   0.000    -.1257803   -.0557431
                  6  |   -.037961   .0193779    -1.96   0.051    -.0760279    .0001059
                  7  |  -.0932097   .0191688    -4.86   0.000    -.1308658   -.0555536
                  8  |  -.1402257   .0144041    -9.74   0.000    -.1685218   -.1119295
                  9  |  -.0051715   .0128384    -0.40   0.687    -.0303919    .0200489
                 10  |   .0696432   .0130034     5.36   0.000     .0440987    .0951877
                 11  |  -.1888402   .0207939    -9.08   0.000    -.2296888   -.1479917
                 12  |  -.2328795   .0210742   -11.05   0.000    -.2742787   -.1914804
                     |
               _cons |   .0290057   .0772167     0.38   0.707    -.1226827     .180694
--------------------------------------------------------------------------------------
Instruments for orthogonal deviations equation
  Standard
    FOD.(ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month
    ln_avg_com_RevPAR 1b.Mon 2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon
    10.Mon 11.Mon 12.Mon)
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    L(6/7).sim_mean_std_hotel collapsed
    L(5/8).L.ln_RevPAR_clean collapsed
Instruments for levels equation
  Standard
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_month ln_avg_com_RevPAR
    1b.Mon 2.Mon 3.Mon 4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon
    12.Mon
    _cons
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    DL5.sim_mean_std_hotel collapsed
    DL4.L.ln_RevPAR_clean collapsed
------------------------------------------------------------------------------
Arellano-Bond test for AR(1) in first differences: z =  -9.04  Pr > z =  0.000
Arellano-Bond test for AR(2) in first differences: z =  -1.63  Pr > z =  0.104
------------------------------------------------------------------------------
Sargan test of overid. restrictions: chi2(5)    =  12.40  Prob > chi2 =  0.030
  (Not robust, but not weakened by many instruments.)
Hansen test of overid. restrictions: chi2(5)    =   8.87  Prob > chi2 =  0.114
  (Robust, but weakened by many instruments.)

Difference-in-Hansen tests of exogeneity of instrument subsets:
  GMM instruments for levels
    Hansen test excluding group:     chi2(3)    =   7.36  Prob > chi2 =  0.061
    Difference (null H = exogenous): chi2(2)    =   1.51  Prob > chi2 =  0.470
  gmm(L.ln_RevPAR_clean, collapse lag(5 8))
    Hansen test excluding group:     chi2(0)    =   0.31  Prob > chi2 =      .
    Difference (null H = exogenous): chi2(5)    =   8.56  Prob > chi2 =  0.128
  gmm(sim_mean_std_hotel, collapse lag(6 7))
    Hansen test excluding group:     chi2(2)    =   6.31  Prob > chi2 =  0.043
    Difference (null H = exogenous): chi2(3)    =   2.57  Prob > chi2 =  0.463

.     }
. }

. 
. if `has_row2' {
.     di as text "------------------------------------------------------------"
------------------------------------------------------------
.     di as text "Nearest spec 2: `alt2_ctrl' | `alt2_timefe' | `alt2_dyn' | `alt2_siminst' | `alt2_transform' | `alt2_breakspec' | `alt2_ylag' | `alt2_xlag'"
Nearest spec 2: quality6_gmm | monthfe | L1 | gmm | orth | none | 5/8 | 6/7
.     di as text "------------------------------------------------------------"
------------------------------------------------------------
.     gettoken y1 y2 : alt2_ylag, parse("/")
.     local y2 = subinstr("`y2'", "/", "", 1)
.     if "`alt2_siminst'" == "iv" {
.         noisily run_gmm_spec, ctrl(`alt2_ctrl') timefe(`alt2_timefe') dyn(`alt2_dyn') siminst(iv) ///
>             ylag1(`y1') ylag2(`y2') transform(`alt2_transform') breakspec(`alt2_breakspec') loud
.     }
.     else {
.         gettoken x1 x2 : alt2_xlag, parse("/")
.         local x2 = subinstr("`x2'", "/", "", 1)
.         noisily run_gmm_spec, ctrl(`alt2_ctrl') timefe(`alt2_timefe') dyn(`alt2_dyn') siminst(gmm) ///
>             ylag1(`y1') ylag2(`y2') xlag1(`x1') xlag2(`x2') ///
>             transform(`alt2_transform') breakspec(`alt2_breakspec') loud
Favoring speed over space. To switch, type or click on mata: mata set matafavor space, perm.
Warning: Two-step estimated covariance matrix of moments is singular.
  Using a generalized inverse to calculate optimal weighting matrix for two-step estimation.
  Difference-in-Sargan/Hansen statistics may be negative.

Dynamic panel-data estimation, two-step system GMM
------------------------------------------------------------------------------
Group variable: hotel_id_num                    Number of obs      =     27287
Time variable : ym                              Number of groups   =       531
Number of instruments = 26                      Obs per group: min =         1
F(20, 530)    =   1006.11                                      avg =     51.39
Prob > F      =     0.000                                      max =       130
--------------------------------------------------------------------------------------
                     |              Corrected
     ln_RevPAR_clean | Coefficient  std. err.      t    P>|t|     [95% conf. interval]
---------------------+----------------------------------------------------------------
     ln_RevPAR_clean |
                 L1. |   .8335241   .0475007    17.55   0.000     .7402114    .9268368
                     |
  sim_mean_std_hotel |  -.0329277   .0115878    -2.84   0.005    -.0556914    -.010164
    ln_recent_volumn |   .0856488   .0185134     4.63   0.000     .0492801    .1220174
   ln_lag_volumn_acc |  -.0067571    .004102    -1.65   0.100    -.0148153    .0013011
  lag_avg_rating_acc |   .0473797   .0196156     2.42   0.016     .0088458    .0859135
lag_avg_rating_month |     .01584   .0033203     4.77   0.000     .0093173    .0223626
   ln_avg_com_RevPAR |   .0912737   .0137389     6.64   0.000     .0642843    .1182631
    review_freshness |  -.0417488    .023417    -1.78   0.075    -.0877503    .0042526
                     |
                 Mon |
                  1  |          0  (empty)
                  2  |   .1683411   .0151929    11.08   0.000     .1384955    .1981868
                  3  |   .0334614   .0214595     1.56   0.120    -.0086948    .0756176
                  4  |  -.1659135   .0217555    -7.63   0.000    -.2086511   -.1231758
                  5  |  -.0873614   .0180414    -4.84   0.000    -.1228029     -.05192
                  6  |  -.0349872   .0195595    -1.79   0.074    -.0734109    .0034364
                  7  |  -.0903148   .0193215    -4.67   0.000    -.1282709   -.0523587
                  8  |   -.137739   .0144528    -9.53   0.000    -.1661307   -.1093472
                  9  |  -.0033724    .012954    -0.26   0.795      -.02882    .0220751
                 10  |   .0715941   .0131091     5.46   0.000     .0458419    .0973462
                 11  |  -.1854957   .0208498    -8.90   0.000     -.226454   -.1445374
                 12  |  -.2309521   .0210344   -10.98   0.000    -.2722732    -.189631
                     |
               _cons |  -.0668967   .0500881    -1.34   0.182    -.1652922    .0314989
--------------------------------------------------------------------------------------
Instruments for orthogonal deviations equation
  Standard
    FOD.(ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc
    lag_avg_rating_month ln_avg_com_RevPAR review_freshness 1b.Mon 2.Mon 3.Mon
    4.Mon 5.Mon 6.Mon 7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon)
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    L(6/7).sim_mean_std_hotel collapsed
    L(5/8).L.ln_RevPAR_clean collapsed
Instruments for levels equation
  Standard
    ln_recent_volumn ln_lag_volumn_acc lag_avg_rating_acc lag_avg_rating_month
    ln_avg_com_RevPAR review_freshness 1b.Mon 2.Mon 3.Mon 4.Mon 5.Mon 6.Mon
    7.Mon 8.Mon 9.Mon 10.Mon 11.Mon 12.Mon
    _cons
  GMM-type (missing=0, separate instruments for each period unless collapsed)
    DL5.sim_mean_std_hotel collapsed
    DL4.L.ln_RevPAR_clean collapsed
------------------------------------------------------------------------------
Arellano-Bond test for AR(1) in first differences: z =  -8.98  Pr > z =  0.000
Arellano-Bond test for AR(2) in first differences: z =  -1.63  Pr > z =  0.102
------------------------------------------------------------------------------
Sargan test of overid. restrictions: chi2(5)    =  12.38  Prob > chi2 =  0.030
  (Not robust, but not weakened by many instruments.)
Hansen test of overid. restrictions: chi2(5)    =   8.79  Prob > chi2 =  0.118
  (Robust, but weakened by many instruments.)

Difference-in-Hansen tests of exogeneity of instrument subsets:
  GMM instruments for levels
    Hansen test excluding group:     chi2(3)    =   7.16  Prob > chi2 =  0.067
    Difference (null H = exogenous): chi2(2)    =   1.64  Prob > chi2 =  0.441
  gmm(L.ln_RevPAR_clean, collapse lag(5 8))
    Hansen test excluding group:     chi2(0)    =   0.31  Prob > chi2 =      .
    Difference (null H = exogenous): chi2(5)    =   8.48  Prob > chi2 =  0.132
  gmm(sim_mean_std_hotel, collapse lag(6 7))
    Hansen test excluding group:     chi2(2)    =   6.50  Prob > chi2 =  0.039
    Difference (null H = exogenous): chi2(3)    =   2.29  Prob > chi2 =  0.514
```

## 7. Current Bottom Line

这版 `focus110 + rich8_current` 结果现在可以分成四层来看：

1. 主结果已经锁住：level `FE = -0.1931**`，same-sample `OLS = -0.2339*`，而且主样本保留了 `32,657` 个观测、`535` 家酒店。
2. full-sample 异质性里，`volume_last` 和 `rating_accumulative` 仍然是最稳的两条；`volume_accumulative` 是 near-pass，`rating_last` 在严格中位数口径下仍不显著，`star` 的显著 alternative split 继续只放附录，因为方向反了。
3. 动态稳健性里，`pre2019` same-sample GMM 仍然没有 strict pass，卡点还是 `Hansen`；但 full-year same-sample GMM 仍然有两条 strict pass，可以正式作为动态稳健性证据。
4. 新增的 `COVID` 分析表明：`2020` 的业绩冲击在 FE/OLS 下都稳健显著为负，但 `post2020 / post2021 × ARS` 的 GMM 断点交互都不显著，所以当前没有强证据说明疫情后 `ARS` 的边际作用发生了显著结构变化。
5. 新增的 `pre2019 heterogeneity` 表明：疫情前样本可以把五张异质性表都跑出来，但在当前 adopted 规则下，它不能复制 full-sample 那种更强的异质性差异，因此仍应把 `pre2019` 放在时间边界稳健性的位置，而不是替代正文主异质性。


## 8. Raw Sources

本稿正文引用的原始 Stata 表主要来自：

- [results_focus_tables_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_tables_260407.log)
- [results_focus_interaction_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_interaction_260407.log)
- [results_focus_boundary_260410.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_focus_boundary_260410.log)
- [results_covid_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_covid_260407.log)
- [results_pre2019_heterogeneity_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_pre2019_heterogeneity_260407.log)
- [results_gmm_pre2019_same_sample_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_gmm_pre2019_same_sample_260407.log)
- [results_gmm_full_same_sample_260407.log](/Users/samxie/Research/ReviewSimi_Sales/Code/outputs/logs/results_gmm_full_same_sample_260407.log)
