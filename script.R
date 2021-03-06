#author: TAYLOR TURNER
#date: December 23, 2017

options(warn = -1)
library(tidyverse)
library(lubridate)
library(data.table)
library(plotly)
library(ggExtra)
library(chron)
library(RMySQL)

knitr::opts_chunk$set(echo = TRUE)

#function for triming fields of white space
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

#kill all mysql database connections
killallDBConns <- function(){
  all_cons <- dbListConnections(MySQL())
  
  for(con in all_cons){
    dbDisconnect(con)
  }
  
  print("All connecitons killed!")
}


#mysql connection
con <- dbConnect(RMySQL::MySQL(), host = "localhost",user = "root", password = "password", dbname = "fitz_cap")

#list tables in fitz_cap for this markdown report
tbls <- setnames(data.frame(dbListTables(con)),c("tbl"))
tbls <- factor(tbls[substr(tbls$tbl,0,2) == "R_",])

#for loop to query the tables in tbls varaible
for (tbl in tbls){
  if(tbl == "R_MARGIN_VIEW"){
    sql <- paste0("SELECT PERIOD, INCOME, EXPENSES, MARGIN, OP_MARGIN FROM ", tbl)
    print (sql)
    sumar <- dbGetQuery(con, sql)
    sumar <- sumar %>% mutate(
      flg = as.factor(ifelse(sumar$MARGIN < 0, 'X<$0', ifelse(sumar$MARGIN > 0 & sumar$MARGIN < 1000, '$0<X<$1000', ifelse(sumar$MARGIN > 1000 & sumar$MARGIN < 1500,'$1000<X$1500', ifelse(sumar$MARGIN > 1500 & sumar$MARGIN < 1750, '$1500<X$1750', ifelse(sumar$MARGIN > 1750 & sumar$MARGIN < 2000, '$1750<X<$2000', ifelse(sumar$MARGIN > 2000 & sumar$MARGIN < 2500, '$2000<X<$2500','$2500<X'))))))), 
      dollarDif = c(0,diff(MARGIN, lag = 1))) %>% 
      arrange(as.factor(PERIOD)) %>% filter(!is.na(MARGIN))
    sql <- NULL
  }
  
  if(tbl == "R_CAT_MARGIN"){
    sql <- paste0("SELECT PERIOD, TRID, DEBIT, CREDIT, MARGIN FROM ", tbl)
    catmarg <- dbGetQuery(con, sql)
    catmarg$TRID <- trim(catmarg$TRID)
    sql <- NULL
  }
  
  if(tbl == "R_BUDGET_VIEW"){
    sql <- paste0("SELECT PERIOD, TRID, CREDIT FROM ", tbl)
    budget <- dbGetQuery(con, sql)
    sql <- NULL
  }
  
  if(tbl == "R_MARGIN_DECAY"){
    sql <- paste0("SELECT YEAR, PERIOD, PERIODKEY, DAY, DEBIT, INCOME FROM ", tbl)
    decay <- dbGetQuery(con, sql)
    
    decay <- decay %>%
      mutate(PERIOD = as.factor(PERIOD)) %>% 
      group_by(PERIOD) %>% arrange(PERIOD, DAY) %>% 
      mutate(
        runbal = cumsum(DEBIT) * -1,
        YEAR = as.factor(YEAR),
        mnthtot = (INCOME + runbal)) %>% 
      ungroup() %>%
      mutate(
        prd_flg = as.numeric(c(0,as.numeric(diff(as.numeric(decay$PERIOD))))),
        DIFF = c(NA, ifelse(diff(prd_flg) == 0, diff(mnthtot, lag = 1), 0)),
        marg_flg  = as.factor(
          ifelse(mnthtot < 0, "X<0", 
                 ifelse((mnthtot < 1000 & mnthtot > 0),"0<X<1000",
                        ifelse((mnthtot > 1000 & mnthtot < 1500), "1000<X<1500",
                               ifelse((mnthtot > 1500 & mnthtot < 1750), "1500<X<1750",
                                      ifelse((mnthtot < 2000 & mnthtot > 1750), "1750<X<2000",
                                             ifelse((mnthtot > 2000 & mnthtot < 2500), '2000<X<2500',
                                                    "2500<X"))))))),
        month = as.factor(substring(PERIOD,5,7)),
        row_num = as.numeric(rownames(decay)),
        opmarg = as.numeric((mnthtot/INCOME) * 100),
        opmargDIFF = abs(c(NA, ifelse(diff(prd_flg) == 0, diff(opmarg, lag = 1), 0)))) %>%
      group_by(DAY) %>%
      mutate(
        avg_diff = mean(DIFF), 
        med_diff = median(DIFF)
      ) %>%
      ungroup() %>%
      group_by(PERIOD) %>%
      mutate(
        avg_prd_diff = mean(DIFF), 
        avg_prd_op = mean(opmarg), 
        min_prd_op = min(opmarg), 
        median_prd_diff = median(DIFF), 
        min_prd_diff = min(DIFF)
      ) %>% 
      ungroup()%>%
      mutate(
        dif_avg_dif = c(NA, ifelse(
          diff(prd_flg) == 1, diff(avg_prd_diff, lag = 1), 0)),
        med_avg_prd_diff = (avg_prd_diff + median_prd_diff)/2,
        date = paste0(as.character(YEAR), '-', as.character(substr(PERIOD,5,6)), '-',  as.character(DAY)),
        weekday = weekdays(as.Date(date)),
        day_flg = chron::is.weekend(date)
      )
    
    sql <- NULL
  }
  
  if(tbl == "R_CUR_BALANCE"){
    sql <- paste0("SELECT PERIOD, TRID, BALANCE, MONTH_DEBIT FROM ", tbl)
    
    curBalance <- dbGetQuery(con, sql)
  }
  
  if(tbl == "R_MARGIN_TRIDDECAY"){
    sql <- paste0("SELECT YEAR, PERIOD, PERIODKEY, DAY, TRID, DEBIT, INCOME FROM ", tbl)
    
    tridDecay <- dbGetQuery(con, sql)
    
    tridDecay <- tridDecay %>%
      mutate(PERIOD = as.factor(PERIOD)) %>%
      group_by(PERIOD, TRID) %>%
      arrange(PERIOD, TRID, DAY) %>%
      mutate(
        runbal = cumsum(DEBIT) * -1,
        YEAR = as.factor(YEAR),
        mnthtot = (INCOME + runbal)) %>%
      ungroup() %>%
      arrange(PERIOD, TRID) %>% 
      mutate(
        marg_flg  = as.factor(ifelse(mnthtot < 0, "Negative", "Positive")),
        prdTrid = as.factor(paste0(PERIOD,TRID))
      )
    
    sql <- NULL
  }
  
  if(tbl == "R_CUR_MONTH_VAR"){
    sql <- paste0("SELECT TRID, DEBIT, CREDIT, VAR, FLAG, BUDGET_PERCENTAGE, ACTUAL_PERCENTAGE FROM ", tbl)
    
    cur_prd_var <- dbGetQuery(con, sql)
    
    sql <- NULL
  }
  
  if(tbl == "R_SUMMARY_VIEW"){
    sql <- paste0("SELECT * FROM ", tbl)
    
    summary_view <- dbGetQuery(con, sql)
    
    cat_bal <- setnames(data.frame(summary_view$PERIOD, summary_view$TRID, summary_view$VAR), c("PERIOD", "TRID", "VAR")) %>% 
      group_by(TRID) %>% 
      mutate(bal_sum = sum(VAR)) %>% 
      unique()
    
    rm(summary_view)
    
    
    sql <- NULL
  }
  
  if(tbl == "R_HIST"){
    sql <- paste0("SELECT MONTH, PERIOD, dynm, description, TRID, memo, debit, credit, transaction_number FROM ", tbl)
    
    hist <- dbGetQuery(con, sql)
    
    hist <- hist %>% 
      mutate(
        debitnum  = as.numeric(as.character(debit)),
        dynm = as.numeric(dynm),
        MONTH = as.numeric(MONTH)
      )
    
    cdfhist <- subset(hist, debitnum > -100)
    
    sql <- NULL
  }
  
  if(tbl == "R_TRANS"){
    sql <- paste0("SELECT PERIOD, COUNT, SUM FROM ", tbl)
    trans <- dbGetQuery(con, sql)
    
    trans <- trans %>% 
      mutate(
        period = as.factor(PERIOD)
      )
    
    sql <- NULL
  }
  
  if(tbl == "R_SAVINGS"){
    sql <- paste0("SELECT PERIOD, TRID_CODE, CREDIT FROM ", tbl)
    savingproforma <- dbGetQuery(con, sql)
    
    savingproforma <- savingproforma %>% 
      group_by(TRID_CODE) %>% 
      mutate(
        runbal = cumsum(CREDIT)
      ) %>% 
      ungroup() %>% 
      mutate(
        ROW_NUM = as.numeric(rownames(savingproforma))
      )
    
    sql <- NULL
  }
  
}

rm(tbl, tbls, sql)

dbDisconnect(con)

# count and sum margin by transaction id where margin is negative
neg <- setnames(data.frame(catmarg$TRID, catmarg$MARGIN), c("TRID", "MARGIN")) %>% 
  filter(MARGIN < 0) %>% 
  group_by(TRID) %>%
  mutate(
    num = 1, 
    count = sum(num),
    sum = sum(MARGIN),
    MARGIN = NULL, 
    num = NULL
  ) %>% 
  unique()

# count and sum margin by transaction id where margin is positive
pos <- setnames(data.frame(catmarg$TRID, catmarg$MARGIN), c("TRID", "MARGIN")) %>% 
  filter(MARGIN >= 0) %>% 
  group_by(TRID) %>% 
  mutate(
    num = 1, 
    count = sum(num), 
    sum = sum(MARGIN),
    MARGIN = NULL,
    num = NULL
  ) %>% 
  unique()


net <- setnames(merge(pos, neg, by = "TRID", all = T), c("TRID", "posCount", "posMargin", "negCount", "negMargin")) %>% 
  group_by(TRID) %>% 
  mutate(
    netCount = posCount - negCount, 
    posPcnt = posCount / (posCount + negCount),
    negPcnt = negCount / (posCount + negCount),
    netMargin = posMargin + negMargin
  )


stdevcatmarg <- catmarg %>% 
  group_by(TRID) %>% 
  mutate(stdev = sd(MARGIN),
         MARGIN = NULL
  ) %>%
  unique()

rm(catmarg)


# Margin Analysis
plot <- ggplot(sumar) + geom_bar(aes(x = as.factor(PERIOD), y = OP_MARGIN, fill = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Operating Margin") + xlab("Period") + ggtitle("Time Series of Operating Margin") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

plot

plot <- ggplot(sumar) + geom_bar(aes(x = as.factor(PERIOD), y = MARGIN, fill = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Dollar Margin") + xlab("Period") + ggtitle("Time Series of Dollar Margin") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

plot


plot <- ggplot(sumar) + geom_bar(aes(x = as.factor(PERIOD), y = EXPENSES, fill = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Dollar Expenses") + xlab("Period") + ggtitle("Time Series of Dollar Expenses") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

plot

plot <- ggplot(sumar) + geom_bar(aes(x = as.factor(PERIOD), y = dollarDif, fill = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Dollar Margin Diff") + xlab("Period") + ggtitle("Time Series of Dollar Margin Month over Month") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

plot

plot <- ggplot(sumar) + geom_point(aes(x = OP_MARGIN, y = MARGIN, color = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Dollar Margin") + xlab("Operating Margin") + ggtitle("Dollar Margin vs. Percent Operating Margin") + theme(axis.text.x = element_text(angle = 90, hjust = 1))

plot

sumar[1:6]

cur_prd_var
curBalance

mean(sumar$OP_MARGIN) #mean

median(sumar$OP_MARGIN) #median

ggplotly(ggplot() + geom_histogram(data =  sumar, aes(x = OP_MARGIN), binwidth = 5) + scale_x_continuous(breaks = scales::pretty_breaks(n = 10)))


pcntDriver <- hist %>% 
  filter(!is.na(debitnum)) %>% 
  group_by(PERIOD) %>% 
  mutate(
    maxTrans = (min(debitnum) * -1)
  ) %>% 
  select(PERIOD, maxTrans) %>% 
  filter(maxTrans > 0.00) %>% 
  unique()

pcntDriver <- left_join(pcntDriver, sumar, by = "PERIOD") 

pcntDriver <- pcntDriver %>% 
  select(PERIOD, maxTrans, INCOME, OP_MARGIN, flg) %>% 
  mutate(
    maxPercentageofTot = (maxTrans/INCOME)
  )

ggplot(pcntDriver) + geom_bar(aes(x = as.factor(PERIOD), y = maxPercentageofTot, color = flg), stat = "identity") + scale_y_continuous(breaks = scales::pretty_breaks(n = 15)) + ylab("Max Transaction as Percent of Income") + xlab("Period") + ggtitle("Time Series of Max Transaction as Percent of Income") + theme(axis.text.x = element_text(angle = 90, hjust = 1))


tridCount <- hist %>% 
  mutate(
    tranNum = as.factor(substr(transaction_number,0,1))
  ) %>% 
  select(PERIOD, tranNum, debit) %>% 
  group_by(PERIOD, tranNum) %>% 
  mutate(
    one = 1,
    tranNumSum = sum(one),
    transAmount = sum(as.numeric(debit))
  ) %>% 
  select(PERIOD, tranNumSum, transAmount) %>% unique() %>% 
  ungroup() %>%
  mutate(
    tranNum = ifelse(tranNum == '3', 'Food', 
                     ifelse(tranNum == '1', 'Housing',
                            ifelse(tranNum == '2', 'Digital',
                                   ifelse(tranNum == '4', 'Clothing', 
                                          ifelse(tranNum == '5', 'Transportation', 
                                                 ifelse(tranNum == '6', 'Hygene',
                                                        ifelse(tranNum == '7', 'Personal', 
                                                               ifelse(tranNum == '8', 'Savings','Other')))))))),
    dolPerTrans = (transAmount / tranNumSum),
    transPerDollar = (tranNumSum / transAmount),
    transPerdolPerTrans = (tranNumSum / dolPerTrans),
    transPerDollarMult = (tranNumSum / dolPerTrans) * 10
  )

ggplot(tridCount, aes(x = PERIOD, y = (dolPerTrans * -1), fill = tranNum)) + geom_bar(stat = 'identity') + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + ggtitle("Trend Of Dollar Per Purchase By Category By Day") + xlab("Period") + ylab("Dollar Per Transaction by Category")

ggplot(tridCount, aes(x = PERIOD, y = (transPerdolPerTrans * -1), fill = tranNum)) + geom_bar(stat = 'identity') + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + ggtitle("Trend Of Purchase Per Dollar By Category By Day") + xlab("Period") + ylab("Transaction Per Dollar by Category")

ggplot(tridCount) + geom_point(aes(x = (dolPerTrans * -1), y = (transPerdolPerTrans * -1), color = PERIOD)) + xlab("Dollar Per Transaction") + ylab("Transaction Per Dollar by Category") + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + ggtitle("Dollar Per Transaction v. Transation Per Dollar")


ggplotly(ggplot() + geom_boxplot(data = decay, aes(x = PERIOD, y = DEBIT)) + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + ggtitle("BoxPlot of Debit per Day By Period") + scale_y_continuous(breaks = scales::pretty_breaks(n = 10)))


ggplot() + geom_point(data = neg, aes(x = TRID, y = sum, colour = TRID)) + geom_point(data = pos, aes(x = TRID, y = sum, colour = TRID)) + xlab("Transaction ID") + ylab("Dollar Margin") + ggtitle("BoxPlot of Margin By Transaction ID")


ggplot(net) + geom_bar(aes(x = TRID, y = netCount, fill = TRID), stat = "identity") + xlab("Transaction ID") + ylab("Count of Net Dollar Margin") + ggtitle("Count of Net Dollar Margin")
net
rm(net)


ggplot() + geom_bar(data = stdevcatmarg, aes(x = TRID, y = stdev, fill = TRID), stat = "identity") + xlab("Transaction ID") + ylab("Sigma of Dollar Margin") + ggtitle("Standard Deviation of Net Dollar Margin")


tmp <- hist %>% 
  mutate(debit = as.numeric(debit)) %>% 
  filter(TRID == 'SVTRID') %>% 
  select(PERIOD, debit) %>% 
  group_by(PERIOD) %>% 
  mutate(
    debit = sum(debit)
  ) %>% 
  ungroup() %>%
  filter(!is.na(debit))

savingsRate <- budget %>%
  left_join(tmp, by = "PERIOD") %>% 
  group_by(PERIOD) %>% 
  mutate(
    INCOME = sum(CREDIT), 
    CREDIT = ifelse(!is.na(debit), (CREDIT + debit), CREDIT),
    savingrate = (CREDIT / INCOME)
  ) %>%
  filter(TRID == 'SVTRID') %>% 
  ungroup() %>% 
  mutate(
    runbal = cumsum(CREDIT)
  ) %>% 
  select(-debit)

tmp <- merge(savingsRate, sumar, by = "PERIOD")
tmp <- tmp %>% 
  mutate(
    moneyForMonthRemaining = (MARGIN - CREDIT)
  ) %>% 
  select(PERIOD, moneyForMonthRemaining)

ggplotly(ggplot(tmp) + geom_point(aes(x = as.factor(PERIOD), y = moneyForMonthRemaining)) + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + xlab("PERIOD") + ylab("netIncomePostSavings") + ggtitle("Net Income By Period"))

rm(tmp)


#Savings Analysis
ggplotly(ggplot(savingsRate) + geom_point(aes(x = PERIOD, y = savingrate), stat = "identity") + xlab("Period") + ylab("Savings Rate") + ggtitle("Actual Savings Rate by Period") + scale_y_continuous(breaks = seq(-.50,.90, by = .05)) + theme(legend.position="none") + theme(axis.text.x = element_text(angle = 90, hjust = 1)))

savingsRate[20:38,]

ggplotly(ggplot(savingsRate, aes(x = PERIOD, y = runbal)) + geom_bar(stat = "identity") + ggtitle("Actual Cumulative Savings") + theme(axis.text.x = element_text(angle = 90, hjust = 1)))

ggplotly(ggplot(savingproforma, aes(x = ROW_NUM, y = runbal)) + geom_bar(stat = "identity") + ggtitle("Budgeted Cumulative Savings"))


#First Difference
ggplot() + geom_boxplot(data = decay, aes(x = weekday, y = abs(avg_diff))) + ggtitle("Average Daily Difference by Weekday") + xlab("Weekday") + ylab("Average Difference")

ggplot() + geom_boxplot(data = decay, aes(x = month, y = abs(avg_diff))) + ggtitle("Average Daily Difference by Month") + xlab("Month") + ylab("Average Difference")


# Margin Decay
ggplot(decay, aes(x = DAY, y = mnthtot, colour = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period") + facet_wrap(~PERIOD)

tmptridDecay <- tridDecay[tridDecay$TRID == "FTRID",]
ggplot(tmptridDecay, aes(x = DAY, y = mnthtot, color = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period for Food") + facet_wrap(~PERIOD)

tmptridDecay <- tridDecay[tridDecay$TRID == "HTRID",]
ggplot(tmptridDecay, aes(x = DAY, y = mnthtot, color = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period for Housing") + facet_wrap(~PERIOD)

tmptridDecay <- tridDecay[tridDecay$TRID == "TTRID",]
ggplot(tmptridDecay, aes(x = DAY, y = mnthtot, color = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period for Transportation") + facet_wrap(~PERIOD)

tmptridDecay <- tridDecay[tridDecay$TRID == "PHTRID",]
ggplot(tmptridDecay, aes(x = DAY, y = mnthtot, color = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period for Personal Hygene") + facet_wrap(~PERIOD)

tmptridDecay <- tridDecay[tridDecay$TRID == "PRTRID",]
ggplot(tmptridDecay, aes(x = DAY, y = mnthtot, color = marg_flg)) + xlab("Day") + ylab("Margin Decay") + geom_area() + ggtitle("Margin Decay Wrap by Period for Personal") + facet_wrap(~PERIOD)


#order operating margin
order <- setnames(data.frame(decay$PERIOD, decay$min_prd_op), c("period", "opmarg")) %>% 
  mutate(
    cur_prd = ifelse(length(month(now())) == 1, paste0(year(now()), "0", month(now())), paste0(year(now()), month(now()))),
    flg = as.factor(ifelse(cur_prd == period, "CUR_PRD", "NOT_CUR"))
  ) %>% 
  unique()

plot <- ggplot(order) + geom_density(aes(x = opmarg)) + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + xlab("Operating Margin") + ylab("P(Operating Margin)") + ggtitle("Density Plot of Period Operating Margins")
ggplotly(plot)
rm(order)


plot <- ggplot(decay, aes(x = PERIOD, y = opmarg, colour = month)) + xlab("Period") + ylab("Operating Margin Decay") + ggtitle("Daily Margin Decay Time Series") + geom_boxplot() + scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplotly(plot)

plot <- ggplot(decay, aes(x = PERIOD, y = opmarg, colour = YEAR)) + xlab("Year") + ylab("Operating Margin Decay") + ggtitle("Daily Margin Decay Time Series") + geom_boxplot() + scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) + theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplotly(plot)


decay <- decay %>% na.omit()

for (prdRec in unique(decay$PERIOD)){
  # if the merged dataset doesn't exist, create it
  if (!exists("slopeCoef")){
    sub_df <- decay[decay$PERIOD == prdRec,]
    slopeCoef <- setnames(data.frame(prdRec, as.numeric(coef(lm(sub_df$opmarg ~ sub_df$DAY))["sub_df$DAY"]), as.numeric(coef(lm(sub_df$runbal ~ sub_df$DAY))["sub_df$DAY"])), c("prd", "slope", "dollar_slope"))
    rm(sub_df)
  }
  
  # if the merged dataset does exist, append to it
  if (exists("slopeCoef")){
    sub_df <- decay[decay$PERIOD == prdRec,]
    if(length(sub_df$PERIOD) >= 1){
      temp_datset <- setnames(data.frame(prdRec, as.numeric(coef(lm(sub_df$opmarg ~ sub_df$DAY))["sub_df$DAY"]), as.numeric(coef(lm(sub_df$runbal ~ sub_df$DAY))["sub_df$DAY"])), c("prd", "slope", "dollar_slope"))
      slopeCoef<-rbind(slopeCoef, temp_datset)
      rm(sub_df, temp_datset)
    }
  }
}


slopeCoef <- slopeCoef %>% 
  mutate(
    year = substr(prd,0,4)
  ) %>% 
  filter(!is.na(slope))

plot <- ggplot(slopeCoef) + geom_point(aes(x = prd, y = slope, color = year)) + xlab("Period") + ylab("Slope Coefficient") + ggtitle("Slope Coefficient Time Series") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplotly(plot)

plot <- ggplot(slopeCoef) + geom_point(aes(x = prd, y = dollar_slope, color = year)) + xlab("Period") + ylab("Dollar Slope") + ggtitle("Dollar Slope Coefficient by Period") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplotly(plot)

plot <- ggplot(slopeCoef) + geom_boxplot(aes(x = year, y = slope, color = year)) + xlab("Year") + ylab("Slope Coefficient") + ggtitle("Slope Coefficient by Year")
ggplotly(plot)

plot <- ggplot(slopeCoef) + geom_boxplot(aes(x = year, y = dollar_slope, color = year)) + xlab("Year") + ylab("Dollar Slope") + ggtitle("Dollar Slope Coefficient by Year")
ggplotly(plot)



plot <- ggplot(decay) + geom_point(aes(x = opmarg, y = DAY, color = as.factor(DAY))) + ggtitle("Month Day versus Day's Operating Margin")
ggplotly(plot)



plot <- ggplot(decay, aes(x = YEAR, y = opmarg, colour = YEAR)) + xlab("Year") + ylab("Operating Margin") + ggtitle("Margin Decay by Year") + geom_boxplot() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7))
ggplotly(plot)
rm(plot)

plot <- ggplot(decay, aes(x = YEAR, y = mnthtot, colour = YEAR)) + xlab("Year") + ylab("Dollar Margin") + ggtitle("Margin Decay by Year") + geom_boxplot() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7))
ggplotly(plot)
rm(plot)



ggplot(decay, aes(x = DAY, y = opmarg, colour = month)) + xlab("Day") + ylab("Operating Margin") + ggtitle("Daily Margin Decay by Month") + geom_point() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7)) + facet_grid(~YEAR)

ggplotly(ggplot(decay, aes(x = DAY, y = opmargDIFF, colour = month)) + xlab("Day") + ylab("Operating Margin First Difference") + ggtitle("First Difference of Daily Margin Decay by Month") + geom_point() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7)) + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + facet_grid(~YEAR))

ggplot(decay, aes(x = DAY, y = mnthtot, colour = month)) + xlab("Day") + ylab("Dollar Margin") + ggtitle("Daily Margin Decay by Month") + geom_point() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7)) + facet_grid(~YEAR)

ggplot(decay, aes(x = DAY, y = opmarg, colour = YEAR)) + xlab("Day") + ylab("Operating Margin") + ggtitle("Daily Margin Decay by Year") + geom_point() + scale_y_continuous(breaks = scales::pretty_breaks(n = 7))

rm(plot)


#How does operating margin relate to the day of the month? 
summary(lmResult <- lm(decay$opmarg ~ decay$DAY))


#For any given day of the month, what is the realtionship between the day number and the running balance for the month? 
summary(lm(decay$runbal ~ decay$DAY))



plot <- ggplot(decay, aes(x = DAY, y = opmarg, colour = marg_flg)) + xlab("Day") + ylab("Operating Margin") + ggtitle("Daily Margin Decay") + geom_boxplot(position = "dodge") + scale_y_continuous(breaks = scales::pretty_breaks(n = 7)) + scale_x_continuous(breaks = scales::pretty_breaks(n =15)) + theme(axis.text.x = element_text(angle = 50, hjust = 1))

ggplotly(plot)

rm(plot)


plot <- ggplot(decay, aes(x = PERIOD, y = avg_prd_diff, colour = PERIOD)) + xlab("Period") + ylab("Average Daily Difference") + ggtitle("Average Daily Difference v. PERIOD") + geom_point()+ scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) + theme(axis.text.x = element_text(angle = 90, hjust = 1))

ggplotly(plot)

plot <- ggplot(decay, aes(x = avg_prd_diff, y = min_prd_op, colour = PERIOD)) + ylab("Operating Margin") + xlab("Average Daily Difference") + ggtitle("Average Daily Difference v. Period Operating Margin") + geom_point()+ scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) + theme(axis.text.x = element_text(angle = 90, hjust = 1)) + geom_smooth(method = "lm", se=FALSE, color="black")

ggplotly(plot)

summary(lm(decay$min_prd_op ~ decay$avg_prd_diff))

rm(plot)


#Cumulative Distribution
c <- ggplot(cdfhist, aes(cdfhist$debitnum * -1)) + stat_ecdf() + coord_flip() + ylab("P(x)") + xlab("Transaction Amount")
c + facet_wrap(~TRID)
rm(cdfhist)


#Transaction Analysis
t <- ggplot(trans, aes(x = COUNT, y = SUM , colour = period)) + geom_point() + geom_smooth(method = "lm", se=FALSE, color="black") + ylab("Gross Period Expenses") + xlab("Count Transaction by Period") + ggtitle("Monthly Transaction Sum v. Transaction Count")
ggplotly(t)


summary(lm(trans$SUM ~ trans$COUNT))