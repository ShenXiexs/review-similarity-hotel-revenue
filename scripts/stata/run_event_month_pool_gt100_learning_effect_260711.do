*******************************************************
* Route B learning effect, same variable interface as
* run_routeB_learning_effect_260606.do.
*******************************************************
version 17.0
clear all
set more off
set linesize 255
capture log close
local p "/Users/samxie/Research/ReviewSimi_Sales/Code"
use "`p'/outputs/core_simi_260501/data/event_month_pool_allreviews_gt100_panel_260711.dta", clear
log using "`p'/stata-log/run_event_month_pool_gt100_learning_effect_260711.log", text replace

capture drop sent_neu_share_bing lead1_sent_pos_share_bing lead1_sent_neu_share_bing lead1_sent_neg_share_bing lead1_sent_avg_text_words lead1_sent_any_text d_topic_similarity d_sent_avg_text_words med_sim_mean_zipym learn_hi_ars
gen double sent_neu_share_bing = 1 - sent_pos_share_bing - sent_neg_share_bing if sent_any_text == 1
gen double lead1_sent_pos_share_bing = F1.sent_pos_share_bing
gen double lead1_sent_neu_share_bing = F1.sent_neu_share_bing
gen double lead1_sent_neg_share_bing = F1.sent_neg_share_bing
gen double lead1_sent_avg_text_words = F1.sent_avg_text_words
gen double lead1_sent_any_text = F1.sent_any_text
gen double d_topic_similarity = F1.sim_mean - sim_mean if !missing(F1.sim_mean, sim_mean)
gen double d_sent_avg_text_words = lead1_sent_avg_text_words - sent_avg_text_words if !missing(lead1_sent_avg_text_words, sent_avg_text_words)
bysort Zip ym: egen double med_sim_mean_zipym = median(sim_mean)
gen byte learn_hi_ars = sim_mean > med_sim_mean_zipym if !missing(sim_mean, med_sim_mean_zipym)
replace learn_hi_ars = 0 if !missing(sim_mean, med_sim_mean_zipym) & learn_hi_ars == 0
estimates clear

reghdfe d_topic_similarity sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L1_topic
reghdfe d_topic_similarity c.sim_mean##i.learn_hi_ars ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L1_interaction
reghdfe d_topic_similarity sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if learn_hi_ars == 0 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L1_low
reghdfe d_topic_similarity sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if learn_hi_ars == 1 & !missing(d_topic_similarity), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L1_high
reghdfe d_sent_avg_text_words sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L2_length
reghdfe d_sent_avg_text_words c.sim_mean##i.learn_hi_ars ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L2_interaction
reghdfe d_sent_avg_text_words sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if learn_hi_ars == 0 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L2_low
reghdfe d_sent_avg_text_words sim_mean ln_recent_volumn recent_sd recent_rating ln_lag_volumn_acc lag_avg_rating_acc lag_sd_acc if learn_hi_ars == 1 & !missing(d_sent_avg_text_words), absorb(hotel_id_num ym) vce(cluster hotel_id_num)
estimates store L2_high
estimates table L1_topic L1_interaction L1_low L1_high L2_length L2_interaction L2_low L2_high, b(%9.4f) se stats(N r2_a)
log close
