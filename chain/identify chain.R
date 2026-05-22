#Read chain hotel data
hotel_chain_list <- 
  read.csv('chain/chain_list.csv', header = TRUE, stringsAsFactors = FALSE)
hotel_texas1 <- fread("hotel_texas1.csv")

#Recognize chain hotel with chain name
#In the data of hotel_texas, there are 73212 rows are not reviews of chain hotel
#In the data of hotel_texas, there are 275460 rows are reviews of chain hotel
chain_name <- 
  str_c(hotel_chain_list$name, collapse = ' |')
hotel_texas1$chain <-
  grepl(chain_name, hotel_texas1$HotelName, ignore.case = TRUE)
hotel_texas1 %>% 
  filter(chain == TRUE) %>% count() #275459 chain
hotel_texas1 %>%
  filter(chain == FALSE) %>% count() #73212 non-chain

#Recognize chain hotel with chain parent name
#In the data of hotel_texas, there are 319232 rows are not recognized by parent chain name
#In the data of hotel_texas, there are 29440 rows are recognized by parent chain name
chain_parent_name <- 
  str_c(hotel_chain_list$parent_name, collapse = ' |')
hotel_texas1$chain_parent <-
  grepl(chain_parent_name, hotel_texas1$HotelName, ignore.case = TRUE)
hotel_texas1 %>% filter(chain_parent == TRUE) %>% count() #29440

#Try to find chain hotel in other ways
chain_name_1 <- 
  str_c(hotel_chain_list$name, collapse = '| ')
hotel_texas1$chain_1 <-
  grepl(chain_name_1, hotel_texas1$HotelName, ignore.case = TRUE)
hotel_texas1 %>% 
  filter(chain_1 == TRUE) %>% count() #82791

chain_parent_name_1 <- 
  str_c(hotel_chain_list$parent_name, collapse = '| ')
hotel_texas1$chain_parent_1 <-
  grepl(chain_parent_name_1, hotel_texas1$HotelName, ignore.case = TRUE)
hotel_texas1 %>% filter(chain_parent_1 == TRUE) %>% count() #5319

#add chain hotel recognized by other 3 methods
#there are 280870 rows are reviews of chain hotels 
hotel_texas1$chain[hotel_texas1$chain_1 == TRUE] <- TRUE
hotel_texas1$chain[hotel_texas1$chain_parent_1 == TRUE] <- TRUE
hotel_texas1$chain[hotel_texas1$chain_parent == TRUE] <- TRUE
hotel_texas1 %>% filter(chain == TRUE) %>% count() #280869

hotel_texas_formodel <- hotel_texas_formodel %>%
  dplyr::select(-chain)

hotel_texas_formodel <- hotel_texas_formodel %>%
  left_join(dplyr::select(hotel_texas1, ReviewID, chain), by = c("ReviewID"="ReviewID"))

write.csv(hotel_texas1, file = "hotel_texas1.csv")