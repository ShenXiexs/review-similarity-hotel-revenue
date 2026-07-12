#!/usr/bin/env Rscript
# Final event-month panel: unified allTPreview + TP ledger and full, identical
# Doc2Vec space. Writes only final DTA and log.
suppressPackageStartupMessages({ library(data.table); library(haven); library(syuzhet) })
root <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
data_dir <- file.path(root, "outputs/core_simi_260501/data")
log_dir <- file.path(root, "outputs/core_simi_260501/logs")
out <- file.path(data_dir, "event_month_pool_allreviews_gt100_panel_260711.dta")
logfile <- file.path(log_dir, "build_event_month_pool_allreviews_gt100_260711.log")
base_path <- file.path(data_dir, "core_simi_panel_260501_with_mr_text_sentiment_260526.dta")
tp_path <- file.path(root, "full-data/tp_data_new.csv")
all_path <- file.path(root, "full-data/allTPreview.csv")
vec_path <- file.path(root, "../Data/matched_new/TP_texas_data/reviews_texas_en_doc2vec200_joined.csv")
stopifnot(file.exists(base_path), file.exists(tp_path), file.exists(all_path), file.exists(vec_path))
sink(logfile, split = TRUE); on.exit(sink(), add = TRUE)
cat("Unified all-review event-month build:", format(Sys.time()), "\n")
idate <- function(x) as.IDate(as.Date(x))
ym <- function(x) format(as.Date(x), "%Y-%m")
smean <- function(x) if (any(!is.na(x))) as.numeric(mean(x, na.rm = TRUE)) else NA_real_
smedian <- function(x) if (any(!is.na(x))) as.numeric(median(x, na.rm = TRUE)) else NA_real_
share <- function(x) if (any(!is.na(x))) as.numeric(mean(x, na.rm = TRUE)) else NA_real_
wc <- function(x) { x <- trimws(as.character(x)); as.integer(ifelse(is.na(x) | x == "", 0L, lengths(regmatches(x, gregexpr("\\S+", x, perl = TRUE))))) }
flag <- function(x,p) as.integer(grepl(p,x,ignore.case=TRUE,perl=TRUE))

base <- as.data.table(read_dta(base_path)); base[, HotelID := as.character(HotelID)]
base[, event_ym := sprintf("%04d-%02d", as.integer(Year), as.integer(Mon))]
analysis_hotels <- unique(base[revtot_final > 100, HotelID])
cat("Revenue hotels with final reviews >100:", length(analysis_hotels), "\n")

cat("Reading unified raw review ledger...\n")
all_cols <- c("location_id","review_id","review_published_date","review_rating","review_text","review_response_id","review_response_date","review_response_text","review_response_author","review_response_author_connection")
all <- fread(all_path, select = all_cols, colClasses = c(location_id="character",review_id="character",review_text="character",review_response_text="character"), showProgress = TRUE)
setnames(all,c("location_id","review_id"),c("HotelID","ReviewID")); all[, HotelID := as.character(HotelID)]
all <- all[HotelID %chin% analysis_hotels & !is.na(ReviewID) & ReviewID != ""]
all[, review_date := idate(review_published_date)]
all[, text_chars := nchar(review_text,type="chars",allowNA=TRUE)]; all[is.na(text_chars),text_chars:=0L]
all[, date_valid := as.integer(!is.na(review_date))]
setorder(all,ReviewID,-date_valid,-text_chars); all <- unique(all,by="ReviewID"); all[, date_valid := NULL]
tp <- fread(tp_path, select=c("HotelID","ReviewID","review_date","review_rating","review_text"), colClasses=c(HotelID="character",ReviewID="character",review_text="character"), showProgress=TRUE)
tp <- tp[HotelID %chin% analysis_hotels & !is.na(ReviewID) & ReviewID != ""]
tp[, review_date := idate(review_date)]; tp[, source := "tp"]
setnames(tp,c("review_rating","review_text"),c("tp_rating","tp_text"))
all[, source := "all"]
tp_only <- tp[!ReviewID %chin% all$ReviewID]
reviews <- rbindlist(list(all,tp_only),fill=TRUE,use.names=TRUE)
reviews[, review_rating_num := suppressWarnings(as.numeric(fifelse(!is.na(review_rating), review_rating, tp_rating)))]
reviews[, review_text_final := fifelse(!is.na(review_text) & review_text != "", review_text, tp_text)]
reviews <- reviews[!is.na(review_date)]
reviews[, `:=`(event_ym=ym(review_date),Year=as.integer(format(review_date,"%Y")),Mon=as.integer(format(review_date,"%m")),review_words=wc(review_text_final))]
reviews[, text_chars := nchar(review_text_final,type="chars",allowNA=TRUE)]; reviews[is.na(text_chars),text_chars:=0L]
txt <- tolower(reviews$review_text_final); txt[is.na(txt)] <- ""
reviews[, `:=`(tg_low=as.integer(!is.na(review_rating_num)&review_rating_num<=2),tg_complaint=flag(txt,"complaint|issue|problem|disappoint|bad|poor|terrible"),tg_service=flag(txt,"service|staff|front desk|check.?in"),tg_room=flag(txt,"room|bed|bathroom|suite"),tg_clean=flag(txt,"clean|dirty|housekeep"),tg_value=flag(txt,"value|price|cost|expensive|worth"))]
cat("Unified reviews:",nrow(reviews),"; allTPreview:",sum(reviews$source=="all"),"; TP-only:",sum(reviews$source=="tp"),"\n")

cat("Reading full identical Doc2Vec vectors...\n")
vd <- paste0("V",0:199)
vec <- fread(vec_path, select=c("HotelID","ReviewID",vd), colClasses=c(HotelID="character",ReviewID="character"), showProgress=TRUE)
vec[,HotelID:=as.character(HotelID)]; vec <- vec[HotelID %chin% analysis_hotels]
setorder(vec,ReviewID,HotelID); vec <- unique(vec,by="ReviewID")
reviews <- merge(reviews,vec,by=c("HotelID","ReviewID"),all.x=TRUE,sort=FALSE)
mat <- as.matrix(reviews[,..vd]); storage.mode(mat)<-"double"; nr <- sqrt(rowSums(mat*mat))
reviews[, valid_vec := is.finite(nr) & nr>0 & rowSums(!is.finite(mat))==0]
idx <- which(reviews$valid_vec); reviews[idx,(vd):=lapply(.SD,function(z)z/nr[idx]),.SDcols=vd]
cat("Valid-vector review coverage:",mean(reviews$valid_vec),"; pre-2011 reviews:",sum(reviews$review_date<as.IDate("2011-01-01")),"; pre-2011 valid vectors:",sum(reviews$review_date<as.IDate("2011-01-01")&reviews$valid_vec),"\n")

cat("Constructing event sequence, controls, and pooled ARS...\n")
ev <- reviews[,.(ev_review_count=.N,ev_ln_review_count=log(.N+1),ev_mean_rating=smean(review_rating_num),ev_sd_rating=if(.N>1)suppressWarnings(sd(review_rating_num,na.rm=TRUE))else NA_real_,ev_mean_text_chars=smean(text_chars),ev_ln_mean_text_chars=log(smean(text_chars)+1),ev_mean_text_words=smean(review_words)),by=.(HotelID,Year,Mon,event_ym)]
ev[,event_start:=as.IDate(paste0(event_ym,"-01"))]; setorder(ev,HotelID,event_start)
ev[,event_seq:=seq_len(.N),by=HotelID]; ev[,`:=`(prev_event_ym=shift(event_ym),prev_event_start=shift(event_start),next_event_ym=shift(event_ym,type="lead"),next_event_start=shift(event_start,type="lead")),by=HotelID]
ev[,event_gap_months:=as.integer((as.integer(event_start)-as.integer(prev_event_start))/30.4375)]
vc <- reviews[,.(ev_vector_rows=.N,ev_valid_vectors=sum(valid_vec)),by=.(HotelID,event_ym)]; ev<-merge(ev,vc,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
reviews[,gid:=paste(HotelID,event_ym,sep="\r")]; groups<-split(reviews[valid_vec==TRUE,..vd],reviews[valid_vec==TRUE,gid]); empty<-matrix(numeric(),ncol=length(vd)); ars<-vector("list",nrow(ev))
for(i in seq_len(nrow(ev))){r<-ev[i];a<-groups[[paste(r$HotelID,r$event_ym,sep="\r")]];b<-if(!is.na(r$prev_event_ym))groups[[paste(r$HotelID,r$prev_event_ym,sep="\r")]]else NULL;ma<-if(is.null(a))empty else as.matrix(a);mb<-if(is.null(b))empty else as.matrix(b);p<-rbind(ma,mb);n<-nrow(p);ars[[i]]<-data.table(HotelID=r$HotelID,event_ym=r$event_ym,ars_pool_ev=if(n>=2)(sum(tcrossprod(p))-n)/(n*(n-1))else NA_real_,ev_pool_pairs=n*(n-1))}
ev<-merge(ev,rbindlist(ars),by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
stopifnot(all(is.na(ev$ars_pool_ev)|(ev$ars_pool_ev>=-1.000001&ev$ars_pool_ev<=1.000001)))

cat("Computing Bing review sentiment and management responses...\n")
text_idx<-which(reviews$review_words>0); reviews[,sent_bing:=NA_real_]; if(length(text_idx)) reviews[text_idx,sent_bing:=get_sentiment(review_text_final[text_idx],method="bing")]
reviews[,`:=`(sent_positive=as.integer(sent_bing>0),sent_negative=as.integer(sent_bing<0))]
sent<-reviews[,.(sent_avg_bing=smean(sent_bing),sent_pos_share_bing=share(sent_positive),sent_neg_share_bing=share(sent_negative),sent_net_pos_bing=share(sent_positive)-share(sent_negative),sent_avg_text_words=smean(review_words)),by=.(HotelID,event_ym)]
ev<-merge(ev,sent,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
reviews[,`:=`(response_date=idate(review_response_date),response_chars=nchar(review_response_text,type="chars",allowNA=TRUE),response_words=wc(review_response_text))]; reviews[is.na(response_chars),response_chars:=0L]
reviews[,response_valid:=as.integer((!is.na(review_response_id)&review_response_id!="")|response_words>0|(!is.na(review_response_author)&review_response_author!=""))]; reviews[,response_dated:=as.integer(response_valid==1&!is.na(response_date))]; reviews[,response_days:=as.integer(response_date-review_date)]; reviews[response_days<0|response_days>3650,response_days:=NA_integer_]
rtxt<-tolower(as.character(reviews$review_response_text));rtxt[is.na(rtxt)]<-""
reviews[,`:=`(st_thanks=flag(rtxt,"\\bthank|appreciat|grateful"),st_invite=flag(rtxt,"come back|return|visit again|welcome back|stay again"),st_apology=flag(rtxt,"sorry|apolog|regret"),st_recovery=flag(rtxt,"refund|compensat|credit|discount|resolve|make it right"),st_contact=flag(rtxt,"contact|email|phone|call|reach out"),st_positive=flag(rtxt,"great|glad|pleased|wonderful|excellent|happy"),st_problem=flag(rtxt,"issue|problem|concern|disappoint|inconvenience"),st_personal=flag(rtxt,"\\b(dear|you|your|guest|sir|madam)\\b"),st_mgr=flag(as.character(review_response_author_connection),"manager|management|owner|director"))]
aggmr<-function(d){d<-d[response_dated==1L];d[,.(pmr_activity_n=.N,pmr_activity_chars=sum(response_chars),pmr_activity_words=sum(response_words),pmr_activity_avg_chars=smean(response_chars),pmr_activity_avg_words=smean(response_words),pmr_activity_avg_days=smean(response_days),pmr_activity_med_days=smedian(response_days),pmr_activity_thanks=share(st_thanks),pmr_activity_invite=share(st_invite),pmr_activity_apology=share(st_apology),pmr_activity_recovery=share(st_recovery),pmr_activity_contact=share(st_contact),pmr_activity_positive=share(st_positive),pmr_activity_problem=share(st_problem),pmr_activity_personal=share(st_personal),pmr_activity_mgr=share(st_mgr),pmr_activity_complaint=share(tg_complaint),pmr_activity_service=share(tg_service),pmr_activity_room=share(tg_room),pmr_activity_cleanliness=share(tg_clean),pmr_activity_value=share(tg_value)),by=.(HotelID,target_ym)]}
reviews[,response_ym:=ym(response_date)]; prevmap<-ev[!is.na(prev_event_ym),.(HotelID,response_ym=prev_event_ym,target_ym=event_ym,event_start)]
pmr<-aggmr(merge(reviews,prevmap[,.(HotelID,response_ym,target_ym)],by=c("HotelID","response_ym"),all=FALSE,sort=FALSE))
cohort<-merge(reviews,prevmap[,.(HotelID,review_event_ym=response_ym,target_ym,event_start)],by.x=c("HotelID","event_ym"),by.y=c("HotelID","review_event_ym"),all=FALSE,sort=FALSE)
cr<-cohort[,.(pmr_cohort_eligible7=sum(review_date+7<event_start),pmr_cohort_eligible30=sum(review_date+30<event_start),pmr_cohort_rate7={z<-response_days[review_date+7<event_start];if(length(z))mean(!is.na(z)&z<=7)else NA_real_},pmr_cohort_rate30={z<-response_days[review_date+30<event_start];if(length(z))mean(!is.na(z)&z<=30)else NA_real_}),by=.(HotelID,target_ym)]

cat("Merging Revenue outcomes and final sample...\n")
base_cur<-copy(base);base_cur[,c("Year","Mon"):=NULL]
# Event-aligned controls supersede same-named calendar-month controls inherited from base.
base_cur[,(intersect(setdiff(names(ev),c("HotelID","event_ym")),names(base_cur))):=NULL]
setnames(base_cur,c("RevPAR_clean","ln_RevPAR_clean","ln_lag_RevPAR_clean","cs_sample_focus100"),c("Revenue_current","lnRevenue_current","lnRevenue_lag_month","inherited_sample"))
nextbase<-base_cur[,.(HotelID,event_ym,Revenue_current,lnRevenue_current)];nextbase[,event_ym:=format(as.Date(paste0(event_ym,"-01"))+32,"%Y-%m")];setnames(nextbase,c("Revenue_current","lnRevenue_current"),c("Revenue_next_calendar","lnRevenue_next_calendar"))
panel<-merge(ev,base_cur,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE);panel<-merge(panel,nextbase,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE);panel<-merge(panel,pmr,by.x=c("HotelID","event_ym"),by.y=c("HotelID","target_ym"),all.x=TRUE,sort=FALSE);panel<-merge(panel,cr,by.x=c("HotelID","event_ym"),by.y=c("HotelID","target_ym"),all.x=TRUE,sort=FALSE)
setorder(panel,HotelID,event_seq);panel[,`:=`(next_event_ars_pool_ev=shift(ars_pool_ev,type="lead"),next_event_review_count=shift(ev_review_count,type="lead"),next_event_mean_text_chars=shift(ev_mean_text_chars,type="lead"),next_event_sent_bing=shift(sent_avg_bing,type="lead")),by=HotelID]
panel[,final_review_count:=as.numeric(revtot_final)];panel[,sample_final_reviews_gt100:=as.integer(final_review_count>100)];panel<-panel[sample_final_reviews_gt100==1L]
for(v in grep("^pmr_activity_(n|chars|words)$",names(panel),value=TRUE))set(panel,which(is.na(panel[[v]])),v,0)
for(v in grep("^pmr_activity_(thanks|invite|apology|recovery|contact|positive|problem|personal|mgr|complaint|service|room|cleanliness|value)$",names(panel),value=TRUE))panel[,(paste0(v,"_zf")):=fifelse(is.na(get(v)),0,get(v))]
panel[,pmr_activity_any:=as.integer(pmr_activity_n>0)]
* Preserve the established Route A/B variable interface directly in the DTA.
* sim_mean now carries the rebuilt pooled ARS; the original name is retained
* so the Route A/B replication files require no in-do variable mapping.
panel[, `:=`(sim_mean=ars_pool_ev, ln_RevPAR_clean=lnRevenue_current, ln_lag_RevPAR_clean=lnRevenue_lag_month, cs_sample_focus100=1L)]
drop<-unique(c(grep("(^|_)sim_mean|ars_cross_ev|ev_cross_pairs|next_event_ars_cross_ev",names(panel),value=TRUE),"ev_within_current","ev_within_previous"));panel[,(intersect(drop,names(panel))):=NULL]
panel[, sim_mean := ars_pool_ev]
stopifnot(!anyDuplicated(panel,by=c("HotelID","event_ym")),all(panel$final_review_count>100))
cat("Final rows:",nrow(panel),"; hotels:",uniqueN(panel$HotelID),"; pooled ARS:",sum(!is.na(panel$ars_pool_ev)),"; Revenue+pool:",sum(!is.na(panel$Revenue_current)&!is.na(panel$ars_pool_ev)),"; dates:",min(panel$event_ym),max(panel$event_ym),"\n")
write_dta(panel,out,version=14);cat("Wrote:",out,"\nCompleted:",format(Sys.time()),"\n")
