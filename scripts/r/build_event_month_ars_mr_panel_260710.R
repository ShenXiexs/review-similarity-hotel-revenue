#!/usr/bin/env Rscript
# Event-month ARS/MR panel.  Reads allTPreview in chunks and writes only DTA + log.
suppressPackageStartupMessages({ library(data.table); library(haven); library(readr) })
root <- "/Users/samxie/Research/ReviewSimi_Sales/Code"
out <- file.path(root, "outputs/core_simi_260501/data/event_month_ars_mr_panel_260710.dta")
logfile <- file.path(root, "outputs/core_simi_260501/logs/build_event_month_ars_mr_panel_260710.log")
tp_path <- file.path(root, "full-data/tp_data_new.csv")
resp_path <- file.path(root, "full-data/allTPreview.csv")
vec_path <- file.path(root, "../Data/review_vector_filtered0118.csv")
base_path <- file.path(root, "outputs/core_simi_260501/data/core_simi_panel_260501_with_mr_text_sentiment_260526.dta")
stopifnot(file.exists(tp_path), file.exists(resp_path), file.exists(vec_path), file.exists(base_path))
sink(logfile, split=TRUE); on.exit(sink(), add=TRUE)
cat("Event-month ARS/MR build started:", format(Sys.time()), "\n")
cat("Response source:", resp_path, " size=", file.info(resp_path)$size, "\n", sep="")

idate <- function(x) as.IDate(as.Date(x))
ym <- function(x) format(as.Date(x), "%Y-%m")
ymnext <- function(x) format(as.Date(paste0(x,"-01")) + 32, "%Y-%m")
smean <- function(x) if (any(!is.na(x))) as.numeric(mean(x, na.rm=TRUE)) else NA_real_
smed <- function(x) if (any(!is.na(x))) as.numeric(median(x, na.rm=TRUE)) else NA_real_
sshare <- function(x) if (any(!is.na(x))) as.numeric(mean(x, na.rm=TRUE)) else NA_real_
word_count <- function(x) { x <- trimws(as.character(x)); as.integer(ifelse(is.na(x) | x=="", 0L, lengths(regmatches(x, gregexpr("\\S+",x,perl=TRUE))))) }
flag <- function(x, p) as.integer(grepl(p, x, ignore.case=TRUE, perl=TRUE))

cat("Streaming project reviews and deriving text attributes...\n")
review_chunks <- list(); review_chunk_i <- 0L
review_cb <- DataFrameCallback$new(function(x,pos) {
  x <- as.data.table(x); x <- x[!is.na(HotelID) & HotelID!="" & !is.na(ReviewID) & ReviewID!=""]
  text <- fcoalesce(as.character(x$review_text),"")
  x[, `:=`(text_len=as.integer(nchar(text,type="chars")), review_words=word_count(text),
    tg_complaint=flag(tolower(text),"complaint|issue|problem|disappoint|bad|poor|terrible"),
    tg_service=flag(tolower(text),"service|staff|front desk|check.?in"), tg_room=flag(tolower(text),"room|bed|bathroom|suite"),
    tg_cleanliness=flag(tolower(text),"clean|dirty|housekeep"), tg_value=flag(tolower(text),"value|price|cost|expensive|worth"))]
  x[,review_text:=NULL]; review_chunk_i <<- review_chunk_i+1L; review_chunks[[review_chunk_i]] <<- x
  invisible(NULL)
})
review_ct <- cols_only(HotelID=col_character(),ReviewID=col_character(),review_date=col_character(),review_rating=col_character(),review_text=col_character())
read_csv_chunked(tp_path,callback=review_cb,chunk_size=5000L,col_types=review_ct,progress=FALSE)
reviews <- rbindlist(review_chunks,fill=TRUE); rm(review_chunks); gc()
reviews <- reviews[!is.na(HotelID) & HotelID!="" & !is.na(ReviewID) & ReviewID!=""]
reviews[, review_date := idate(review_date)]
reviews[, `:=`(date_valid=as.integer(!is.na(review_date)), text_len_sort=fcoalesce(text_len,0L))]
setorder(reviews, ReviewID, -date_valid, -text_len_sort)
dup_review_ids <- sum(duplicated(reviews$ReviewID)); reviews <- unique(reviews, by="ReviewID")
reviews[, c("date_valid","text_len_sort"):=NULL]
reviews <- reviews[!is.na(review_date)]
reviews[, `:=`(event_ym=ym(review_date), Year=as.integer(format(review_date,"%Y")), Mon=as.integer(format(review_date,"%m")),
              text_len=fcoalesce(text_len,0L), review_rating_num=suppressWarnings(as.numeric(review_rating)), tg_low=as.integer(!is.na(suppressWarnings(as.numeric(review_rating))) & suppressWarnings(as.numeric(review_rating))<=2))]
cat("Project reviews after deterministic dedupe:", nrow(reviews), "; duplicate IDs removed:", dup_review_ids, "\n")

cat("Constructing review-event calendar...\n")
ev <- reviews[, .(ev_review_count=.N, ev_ln_review_count=log(.N+1), ev_mean_rating=smean(review_rating_num),
  ev_sd_rating=if (.N>1) suppressWarnings(sd(review_rating_num,na.rm=TRUE)) else NA_real_,
  ev_mean_text_chars=smean(text_len), ev_ln_mean_text_chars=log(smean(text_len)+1), ev_mean_text_words=smean(review_words)), by=.(HotelID,Year,Mon,event_ym)]
ev[, event_start:=as.IDate(paste0(event_ym,"-01"))]; setorder(ev,HotelID,event_start)
ev[, event_seq:=seq_len(.N), by=HotelID]
ev[, `:=`(prev_event_ym=shift(event_ym), prev_event_start=shift(event_start), next_event_ym=shift(event_ym,type="lead"), next_event_start=shift(event_start,type="lead")), by=HotelID]
ev[, event_gap_months:=as.integer((as.integer(event_start)-as.integer(prev_event_start))/30.4375)]
stopifnot(!anyDuplicated(ev,by=c("HotelID","event_ym")), all(ev[, all(event_seq==seq_len(.N)), by=HotelID]$V1))
cat("Events:",nrow(ev)," hotels:",uniqueN(ev$HotelID)," gaps >1 month:",sum(ev$event_gap_months>1,na.rm=TRUE),"\n")

cat("Reading and matching Doc2Vec vectors...\n")
vd <- paste0("V",0:199)
vec <- fread(vec_path, select=c("HotelID","ReviewID",vd), colClasses=c(HotelID="character",ReviewID="character"), showProgress=TRUE)
vec[, `:=`(HotelID=as.character(HotelID),ReviewID=as.character(ReviewID))]
setorder(vec,ReviewID,HotelID); vec <- unique(vec,by="ReviewID")
reviews <- merge(reviews, vec, by=c("HotelID","ReviewID"), all.x=TRUE, sort=FALSE)
rm(vec); gc()
mat <- as.matrix(reviews[,..vd]); storage.mode(mat) <- "double"; nr <- sqrt(rowSums(mat*mat))
reviews[, valid_vec := is.finite(nr) & nr>0 & rowSums(!is.finite(mat))==0]
valid_idx <- which(reviews$valid_vec); mat[valid_idx,] <- mat[valid_idx,,drop=FALSE]/nr[valid_idx]
reviews[,(vd):=NULL]
vc <- reviews[,.(ev_vector_rows=.N,ev_valid_vectors=sum(valid_vec)),by=.(HotelID,event_ym)]
ev <- merge(ev,vc,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
reviews[, gid:=paste(HotelID,event_ym,sep="\r")]
groups <- split(which(reviews$valid_vec), reviews$gid[reviews$valid_vec])
empty <- matrix(numeric(),ncol=length(vd))
ars <- vector("list",nrow(ev))
for (i in seq_len(nrow(ev))) {
  a <- groups[[paste(ev$HotelID[i],ev$event_ym[i],sep="\r")]]; b <- if (!is.na(ev$prev_event_ym[i])) groups[[paste(ev$HotelID[i],ev$prev_event_ym[i],sep="\r")]] else NULL
  ma <- if (is.null(a)) empty else mat[a,,drop=FALSE]; mb <- if (is.null(b)) empty else mat[b,,drop=FALSE]
  na <- nrow(ma); nb <- nrow(mb); pp <- rbind(ma,mb); np <- nrow(pp)
  ars[[i]] <- data.table(HotelID=ev$HotelID[i],event_ym=ev$event_ym[i],
    ars_cross_ev=if(na>0 && nb>0) sum(ma %*% t(mb))/(na*nb) else NA_real_,
    ars_pool_ev=if(np>=2) (sum(pp %*% t(pp))-np)/(np*(np-1)) else NA_real_,
    ev_cross_pairs=na*nb,ev_pool_pairs=np*(np-1),
    ev_within_current=if(na>=2) (sum(ma %*% t(ma))-na)/(na*(na-1)) else NA_real_,
    ev_within_previous=if(nb>=2) (sum(mb %*% t(mb))-nb)/(nb*(nb-1)) else NA_real_)
}
rm(mat,groups); gc(); ev <- merge(ev,rbindlist(ars),by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
stopifnot(all(is.na(ev$ars_cross_ev)|(ev$ars_cross_ev>=-1.000001 & ev$ars_cross_ev<=1.000001)), all(is.na(ev$ars_pool_ev)|(ev$ars_pool_ev>=-1.000001 & ev$ars_pool_ev<=1.000001)))
cat("Vector coverage:",mean(reviews$valid_vec)," cross ARS coverage:",mean(!is.na(ev$ars_cross_ev))," pool ARS coverage:",mean(!is.na(ev$ars_pool_ev)),"\n")

cat("Streaming response source in chunks; retaining only project ReviewIDs...\n")
project_ids <- unique(reviews$ReviewID); response_chunks <- list(); chunk_i <- 0L; source_rows <- 0L
cb <- DataFrameCallback$new(function(x,pos) {
  source_rows <<- source_rows + nrow(x); x <- as.data.table(x)
  x <- x[review_id %chin% project_ids]
  if (nrow(x)) { chunk_i <<- chunk_i + 1L; response_chunks[[chunk_i]] <<- x }
  invisible(NULL)
})
ct <- cols_only(review_id=col_character(),review_response_id=col_character(),review_response_date=col_character(),review_response_text=col_character(),review_response_author=col_character(),review_response_author_connection=col_character())
read_csv_chunked(resp_path, callback=cb, chunk_size=200000L, col_types=ct, progress=FALSE)
resp <- rbindlist(response_chunks,fill=TRUE); rm(response_chunks); gc()
setnames(resp,"review_id","ReviewID"); resp[, response_date:=idate(review_response_date)]
resp[, `:=`(response_chars=fcoalesce(nchar(review_response_text,type="chars",allowNA=TRUE),0L), response_words=word_count(review_response_text))]
resp[, response_valid:=as.integer((!is.na(review_response_id)&review_response_id!="")|response_words>0|(!is.na(review_response_author)&review_response_author!=""))]
resp[, response_dated:=as.integer(response_valid==1L & !is.na(response_date))]
setorder(resp,ReviewID,-response_dated,-response_valid,-response_chars); dup_response_ids <- sum(duplicated(resp$ReviewID)); resp <- unique(resp,by="ReviewID")
setnames(resp,"review_response_author", "response_author")
cat("Response source rows:",source_rows," matched rows:",nrow(resp)+dup_response_ids," matched unique IDs:",nrow(resp)," duplicate rows removed:",dup_response_ids," dated response rate:",mean(resp$response_dated),"\n")
reviews <- merge(reviews,resp[,.(ReviewID,response_date,response_valid,response_dated,response_chars,response_words,review_response_text,response_author,review_response_author_connection)],by="ReviewID",all.x=TRUE,sort=FALSE)
rm(resp); gc()
reviews[, response_days:=as.integer(response_date-review_date)]; invalid_negative_days <- sum(reviews$response_days<0,na.rm=TRUE); reviews[response_days<0|response_days>3650,response_days:=NA_integer_]
rtxt <- tolower(fcoalesce(reviews$review_response_text,""))
reviews[, `:=`(st_thanks=flag(rtxt,"\\bthank|appreciat|grateful"),st_invite=flag(rtxt,"come back|return|visit again|welcome back|stay again"),
 st_apology=flag(rtxt,"sorry|apolog|regret"),st_recovery=flag(rtxt,"refund|compensat|credit|discount|resolve|make it right"),st_contact=flag(rtxt,"contact|email|phone|call|reach out"),
 st_positive=flag(rtxt,"great|glad|pleased|wonderful|excellent|happy"),st_problem=flag(rtxt,"issue|problem|concern|disappoint|inconvenience"),
 st_personal=flag(rtxt,"\\b(dear|you|your|guest|sir|madam)\\b"),st_template=flag(rtxt,"dear guest|thank you for taking the time"),st_mgr=flag(fcoalesce(reviews$review_response_author_connection,""),"manager|management|owner|director"))]
reviews[, response_ym:=ym(response_date)]
mr_aggregate <- function(d,prefix) {
  d <- d[response_dated==1L]
  ans <- d[,.(activity_n=.N,activity_chars=sum(response_chars),activity_words=sum(response_words),activity_avg_chars=smean(response_chars),activity_avg_words=smean(response_words),activity_avg_days=smean(response_days),activity_med_days=smed(response_days),
    target_low=sshare(tg_low),target_complaint=sshare(tg_complaint),target_service=sshare(tg_service),target_room=sshare(tg_room),target_cleanliness=sshare(tg_cleanliness),target_value=sshare(tg_value),
    text_thanks=sshare(st_thanks),text_invite=sshare(st_invite),text_apology=sshare(st_apology),text_recovery=sshare(st_recovery),text_contact=sshare(st_contact),text_positive=sshare(st_positive),text_problem=sshare(st_problem),text_personalization=sshare(st_personal),text_template=sshare(st_template),text_manager=sshare(st_mgr)),by=.(HotelID,target_ym)]
  setnames(ans,setdiff(names(ans),c("HotelID","target_ym")),paste0(prefix,"_",setdiff(names(ans),c("HotelID","target_ym")))); ans
}
prevmap <- ev[!is.na(prev_event_ym),.(HotelID,response_ym=prev_event_ym,target_ym=event_ym,event_start)]
pmr <- mr_aggregate(merge(reviews,prevmap[,.(HotelID,response_ym,target_ym)],by=c("HotelID","response_ym"),all=FALSE,sort=FALSE),"pmr")
intervals <- ev[!is.na(prev_event_start),.(HotelID,prev_event_start,event_start,target_ym=event_ym)]
setkey(intervals,HotelID,prev_event_start,event_start); rdated <- reviews[response_dated==1L,.(HotelID,response_date,ReviewID)]
imap <- intervals[rdated,on=.(HotelID,prev_event_start<=response_date,event_start>response_date),nomatch=0L,allow.cartesian=FALSE]
imap <- imap[,.(HotelID,target_ym,ReviewID)]
imr <- mr_aggregate(merge(reviews,imap,by=c("HotelID","ReviewID"),all=FALSE,sort=FALSE),"imr")
cohort <- merge(reviews,prevmap[,.(HotelID,prev_event_ym=response_ym,target_ym,event_start)],by.x=c("HotelID","event_ym"),by.y=c("HotelID","prev_event_ym"),all=FALSE,sort=FALSE)
cr <- cohort[,.(pmr_cohort_eligible7=sum(review_date+7<event_start),pmr_cohort_eligible30=sum(review_date+30<event_start),
 pmr_cohort_rate7={z<-response_days[review_date+7<event_start];if(length(z))mean(!is.na(z)&z<=7)else NA_real_},
 pmr_cohort_rate30={z<-response_days[review_date+30<event_start];if(length(z))mean(!is.na(z)&z<=30)else NA_real_},
 pmr_cohort_eventual_rate7=mean(!is.na(response_days)&response_days<=7),pmr_cohort_eventual_rate30=mean(!is.na(response_days)&response_days<=30)),by=.(HotelID,target_ym)]

cat("Merging monthly outcomes/controls...\n")
base <- as.data.table(read_dta(base_path)); base[,HotelID:=as.character(HotelID)]; base[,event_ym:=sprintf("%04d-%02d",as.integer(Year),as.integer(Mon))]
nextbase <- base[,.(HotelID,event_ym=ymnext(event_ym),Revenue_next_calendar=RevPAR_clean,lnRevenue_next_calendar=ln_RevPAR_clean)]
base[,(intersect(c("Year","Mon"),names(base))):=NULL]
collide <- intersect(setdiff(names(ev),c("HotelID","event_ym")),names(base)); if(length(collide)) base[,(collide):=NULL]
panel <- merge(ev,base,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
panel <- merge(panel,nextbase,by=c("HotelID","event_ym"),all.x=TRUE,sort=FALSE)
panel <- merge(panel,pmr,by.x=c("HotelID","event_ym"),by.y=c("HotelID","target_ym"),all.x=TRUE,sort=FALSE)
panel <- merge(panel,imr,by.x=c("HotelID","event_ym"),by.y=c("HotelID","target_ym"),all.x=TRUE,sort=FALSE)
panel <- merge(panel,cr,by.x=c("HotelID","event_ym"),by.y=c("HotelID","target_ym"),all.x=TRUE,sort=FALSE)
setorder(panel,HotelID,event_seq)
panel[,`:=`(next_event_ars_cross_ev=shift(ars_cross_ev,type="lead"),next_event_ars_pool_ev=shift(ars_pool_ev,type="lead"),next_event_review_count=shift(ev_review_count,type="lead"),next_event_mean_text_chars=shift(ev_mean_text_chars,type="lead"),next_event_sent_bing=shift(sent_avg_bing,type="lead")),by=HotelID]
for (prefix in c("pmr","imr")) {
  raw <- grep(paste0("^",prefix,"_(activity_n|activity_chars|activity_words)$"),names(panel),value=TRUE); for(v in raw) set(panel,which(is.na(panel[[v]])),v,0)
  panel[,(paste0(prefix,"_any")):=as.integer(get(paste0(prefix,"_activity_n"))>0)]
  shares <- grep(paste0("^",prefix,"_(target_|text_)"),names(panel),value=TRUE); for(v in shares) panel[,(paste0(v,"_zf")):=fifelse(is.na(get(v)),0,get(v))]
}
panel[,`:=`(Revenue_current=RevPAR_clean,lnRevenue_current=ln_RevPAR_clean,lnRevenue_lag_month=ln_lag_RevPAR_clean)]
stopifnot(!anyDuplicated(panel,by=c("HotelID","event_ym")), all(panel$event_seq>=1), all(is.na(panel$ars_cross_ev)|abs(panel$ars_cross_ev)<=1.000001), all(is.na(panel$ars_pool_ev)|abs(panel$ars_pool_ev)<=1.000001))
cat("Validation: invalid negative response days:",invalid_negative_days,"; response-date missing:",mean(reviews$response_valid==1 & is.na(reviews$response_date),na.rm=TRUE),"; final rows:",nrow(panel),"; hotels:",uniqueN(panel$HotelID),"\n")
write_dta(panel,out,version=14)
cat("Wrote final DTA:",out,"\nCompleted:",format(Sys.time()),"\n")
