##----------------------------------------------------------------------------##
## Master Thesis by Tobias Reinertsen & Benjamin Håkedal @ NHH, Fall 2021     ##
##----------------------------------------------------------------------------##

## TABLE OF CONTENTS --------------------------------------------------------
# 01.0 - Setting up working environment
# 02.0 - ISIN traded from 1990 to 2020
# 02.1 - Replace old ISIN with new ISIN
# 03.0 - Monthly Stock Prices - Adjusted for dividends
# 04.0 - Risk-free interest rate
# 05.0 - Fama French Factors
# 06.0 - Indicies from Børsprosjektet (OSEBX & GICS)
# 06.1 - Index from 1990-2020
# 06.2 - GICS indicies
# 07.0 - MarketCaps 1990-2020
# 08.0 - EIKON Accounting data: NEW_ISIN
# 08.1 - Accounting: From Excel to ready for backtesting
# 09.0 - Accounting data from Borsprosjektet
# 09.1 - Supply revenue data from Bors to EIKON
# 09.2 - Supply ROE data from Borsprosjektet
# 10.0 - Revenue 1990-2020
# 10.1 - Revenue 1990-2020 (EIKON + Borsprosjektet)
# 10.2 - Calculate Price / Sales ratio
# 11.0 - GICS: Sector classification
# 11.1 - Plot GICS indicies
# 11.2 - GICS proportion over time
# 12.0 - Which metrics have enough values?
# 13.0 - Backtest 3 weightings with Gics
# 14.0 - Backtest multiple metrics & 3 weightings with Gics
# 15.0 - Identify ultimate combination of metrics by backtesting
# 16.0 - Format tables used in the paper




## 01.0 - Setting up working environment ----------------------------------------
rm(list=ls()) # clear environment
dev.off()     # clear plots
cat("\014")   # clear console

# Working directory
setwd("C:/Users/Benja/OneDrive - Norges Handelshøyskole/FIETHE/CODE")

# Package names
packages <- c("dplyr", "readxl", "zoo", "ggplot2", "plotly", "hrbrthemes", 
              "extrafont", "writexl","ggpmisc","grid","gridExtra", "gtable",
              "broom", "tidyquant","tidyverse", "timetk","glue", "reshape2", 
              "ggpubr", "data.table", "ggthemes", "viridis", "plyr", "xtable",
              "moments", "stargazer", "extrafont", "ggrepel")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}
invisible(lapply(packages, library, character.only = TRUE)) # Packages loading
rm(installed_packages, packages)

## END


## 02.0 - ISIN traded from 1990 to 2020 --------------------------------------------

# To gather accounting key figures from EIKON, we need to identify each stock. 
# Børsprosjektet has a self-made CompanyID, but this can not be used at EIKON.
# Børsprosjektet has recorded every ISIN for each stock, but there are some
# data problems. Many ISIN's are outdated or wrong. 
# We need to search these stocks at EIKON-terminal, and find the ISIN that
# EIKON uses. 


# Load all data from Børsprosjektet, and gather unique ISIN
# MEP = Monthly Equity Prices

# stocks1 <- read.csv("MEP-1980-2000.csv", header = TRUE, sep = ";", dec = ".")
# stocks2 <- read.csv("MEP-2000-2010.csv", header = TRUE, sep = ";", dec = ".")
# stocks3 <- read.csv("MEP-2010-2014.csv", header = TRUE, sep = ";", dec = ".")
# stocks4 <- read.csv("MEP-2014-2018.csv", header = TRUE, sep = ";", dec = ".")
# stocks5 <- read.csv("MEP-2018-2020.csv", header = TRUE, sep = ";", dec = ".")
# 
# # Bind together all rows
# stocks <- rbind(stocks1, stocks2, stocks3, stocks4, stocks5)
# 
# rm(stocks1, stocks2, stocks3, stocks4, stocks5)
# 
# save(stocks, file = "stocks.all.RData")

load("stocks.all.RData")

# Column names 
colnames(stocks)[1] <- "Date"
stocks$Date <- as.Date(stocks$Date, format = "%Y-%m-%d")

# Remove columns
stocks <- stocks[ , -c(11:ncol(stocks))]


# Filtering
unique(stocks$Market)
unique(stocks$SecurityType)
unique(stocks$IsStock)

# We want only ordinary shares and primary capital certificates of companies 
# listed on OSE between 1990-01-01 and 2020-12-31

stocks <- filter(stocks, IsStock == 1)
stocks <- filter(stocks, SecurityType %in% c("Ordinary Shares", 
                                             "Primary Capital Certificates"))
stocks <- filter(stocks, stocks$Date >= "1990-01-01")
stocks <- filter(stocks, Market == "OSE")

# Remove and reorder columns
stocks <- stocks[ , c(3,4,5)]
stocks <- stocks[ , c(2,1,3)]

# Find unique ISIN
isin.unique <- unique(stocks$ISIN)

stocks.unique <- unique.data.frame(stocks)

list <- stocks.unique[ , 1]

isin.unique <- sort(isin.unique)
list <- sort(list)

# Fix rownames
rownames(stocks.unique) <- seq(length = nrow(stocks.unique))

# Find duplicated ISIN
n <- data.frame(table(stocks.unique$ISIN))
n <- n[n$Freq > 1, ]

# Remove Northen Offshore gammel
# Remove Mindex (same isin as Element)
# Remove Simrad Optronics (SIT, leave OPT ticker)
stocks.unique <- stocks.unique[-c(381, 246, 463), ]

# Check if OK:
n <- data.frame(table(stocks.unique$ISIN))
n <- n[n$Freq > 1, ]

write_xlsx(stocks.unique, "C:/Users/Benja/OneDrive - Norges Handelshøyskole/FIETHE/CODE/EIKON_ISIN.xlsx")

rm(list = ls())

# We use Excel for the next task.
# For every ISIN EIKON can not find, we manually search the company/stock, and
# find the ISIN EIKON uses. 
# We also noticed that EIKON uses its own ID ("RIC"). 
# There are thus 3 ways to ID every stock and respecting company: 
# * OLD_ISIN = ISIN from Børsprosjektet
# * NEW_ISIN = ISIN from Børsprosjektet, or adjusted ISIN at EIKON.
# * RIC      = Reuter Identification Code

# As we need accounting data from EIKON, we will use either NEW_ISIN og RIC.


## 02.1 - Replace old ISIN with new ISIN ----------------------------------------

# After the filtering in Excel, we have to replace old ISIN, with fixed ISIN.

# Gather fixed ISIN from excel sheet:
isin_1990_2020 <- read_xlsx("EIKON.isin.90-20.xlsx",
                            sheet = "ID",
                            skip = 0,
                            col_names = TRUE)

save(isin_1990_2020, file = "isin_1990.RData")

load("isin_1990.RData")


# Load stocks as before we fixed ISIN -----------------------------------------#
load("stocks.all.RData")

colnames(stocks)[1] <- "Date"
stocks$Date <- as.Date(stocks$Date, format = "%Y-%m-%d")

stocks <- filter(stocks, IsStock == 1)
stocks <- filter(stocks, SecurityType %in% c("Ordinary Shares", "Primary Capital Certificates"))
stocks <- filter(stocks, stocks$Date >= "1990-01-01")
stocks <- filter(stocks, Market == "OSE")


# Merge NEW_ISIN to all stocks ------------------------------------------------#

isin_1990_2020 <- isin_1990_2020[ , c(1,2)]
colnames(isin_1990_2020)[1] <- "ISIN"               # Same colname as in stocks
isin_1990_2020 <- as.data.frame(isin_1990_2020)

stocks <- merge(stocks, isin_1990_2020)
stocks$ISIN <- NULL
stocks <- stocks[ , c(1,2,3,44,4:43)]
colnames(stocks)[4] <- "ISIN"

save(stocks, file = "stocks.all.fixed.isin.RData")

rm(list = ls())


## END


## 03.0 - Monthly Stock Prices - Adjusted for dividends -------------------------

load("stocks.all.fixed.isin.RData")

# We only need certain columns

#stocks$Date <- NULL
stocks$SecurityId <- NULL
stocks$Symbol <- NULL
#stocks$ISIN <- NULL
stocks$SecurityName <- NULL
stocks$SecurityTypeId <- NULL
stocks$SecurityType <- NULL
stocks$IsStock <- NULL
stocks$Market <- NULL
stocks$CompanyId <- NULL
stocks$Gics <- NULL
stocks$Bid <- NULL
stocks$Offer <- NULL
stocks$Open <- NULL
stocks$High <- NULL
stocks$Low <- NULL
stocks$Last <- NULL
#stocks$Generic <- NULL
stocks$AdjBid <- NULL
stocks$AdjOffer <- NULL
stocks$AdjOpen <- NULL
stocks$AdjHigh <- NULL
stocks$AdjLow <- NULL
stocks$AdjLast <- NULL
#stocks$AdjGeneric <- NULL
stocks$Vwap <- NULL
stocks$ReturnLast <- NULL
stocks$ReturnGeneric <- NULL
stocks$ReturnAdjLast <- NULL
stocks$ReturnAdjGeneric <- NULL
stocks$LogReturnLast <- NULL
stocks$LogReturnGeneric <- NULL
stocks$LogReturnAdjLast <- NULL
stocks$LogReturnAdjGeneric <- NULL
stocks$OffShareTurnover <- NULL
stocks$OffTurnover <- NULL
stocks$NonOffTurnover <- NULL
stocks$NonOffShareTurnover <- NULL
#stocks$SharesIssued <- NULL
stocks$DivFactor <- NULL      
#stocks$CumDivFactor <- NULL   
stocks$LastQAccount <- NULL   
stocks$LastYAccount <- NULL   
stocks$X <- NULL              


# Check number of NAs in each column:
na_count <-sapply(stocks, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)


# Calculate adjusted prices ---------------------------------------------------#

# We have one na for cumDivFactor -> its for the last price, so the factor should be 1
stocks[is.na(stocks$CumDivFactor), ]
stocks[4961, 6] <- 1

# Check number of NAs in each column:
na_count <-sapply(stocks, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

# Calculate adjusted for dividend

stocks$DivAdjPrice <- stocks$AdjGeneric * stocks$CumDivFactor


## More filtering -------------------------------------------------------------#

stocks <- stocks[!is.na(stocks$AdjGeneric), ]       # Remove NA's
stocks <- stocks[stocks$Generic > 5, ]              # Remove penny stocks?
stocks <- stocks[stocks$SharesIssued > 0, ]         # Shares must be issued

# Check number of NAs in each column:
na_count <-sapply(stocks, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)


## Save file, for index later on ----------------------------------------------#
save(stocks, file = "stocks_market.RData")


## Add november and december prices from EIKON --------------------------------#

# Børsprosjektet stopped receiving pricedata from OSE when Euronext took over. 
# The data stops at 27.11.2020. We need the last two months (31.11 & 31.12)

eikon <- read_xlsx("EIKON.isin.90-20.xlsx", 
                   sheet = "Price", 
                   skip = 1, 
                   col_names = TRUE)

eikon <- eikon[, c(1,2,5)]
colnames(eikon) <- c("Date","ISIN","Price")
eikon <- as.data.frame(eikon)
eikon$Date <- as.Date(eikon$Date, format = "%Y-%m-%d")

# Which rows has NAs?
# list <- which(is.na(as.numeric(as.character(eikon[[3]]))))

# Remove rows with NAs in any column
eikon <- eikon[complete.cases(eikon), ]
eikon <- as.data.frame(eikon)
eikon <- eikon[eikon$Price > 5, ]  # Remove penny stocks

# Only one stock observation per month (the most recent)
num <- aggregate(eikon$ISIN, list(eikon$Date, eikon$ISIN), length)
eikon <- eikon[order(eikon$ISIN, eikon$Date), ]
eikon$row <- 1:nrow(eikon)
rows <- aggregate(eikon$row, list(eikon$Date, eikon$ISIN), max)
eikon <- eikon[rows$x, ]
eikon$row <- NULL
rm(num,rows)


# Add EIKON prices to our dataset, to complete 1990-2020 ----------------------#

# ISIN at OSE 27.11
isin_nov <- stocks[stocks$Date >= "2020-11-01", ]
isin_nov <- unique(isin_nov$ISIN)

eikon2 <- eikon[eikon$ISIN %in% isin_nov, ]

# Monthly stock data to 30.10.2020
stocks <- stocks[stocks$Date < "2020-11-01", ]

stocks2 <- stocks[ , c(1,2,7)]
colnames(stocks2)[3] <- "Price"

stocks_90_20 <- rbind(stocks2,eikon2)
stocks <- stocks_90_20
stocks <- stocks[order(stocks$Date, stocks$ISIN), ]

head(stocks)
tail(stocks)


rm(eikon,eikon2,stocks_90_20, stocks2,isin_nov,na_count)

save(stocks, file = "stockdata-1990-december2020.RData")


## Rolling observations forward in time ---------------------------------------#

# We need to make sure we have only one obersvation per stock, per month. 
# We also wish to have end-of-month price observation for each stock. 
# example: 2005-04-06 --> 2005-04-30

load("stockdata-1990-december2020.RData")


months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

stocks$Date.aux <- cut(stocks$Date, months, right = TRUE)

# We see that we did not get the desired result
stocks$Date[1:5]       
stocks$Date.aux[1:5]

# Fixing that: 
i <- as.numeric(stocks$Date.aux)
stocks$Date.aux <- months[i + 1]

# Now its good
stocks$Date[1:5]
stocks$Date.aux[1:5]

## Only one stock price observation per month ---------------------------------#

num <- aggregate(stocks$ISIN, list(stocks$Date.aux, stocks$ISIN), length)
head(num[num$x > 1, ])    

# We have some cases with more than one observations, For instance:
stocks[stocks$Date.aux == "1996-07-31" & stocks$ISIN == "ANN7425Q1095", ]

# We take the most recent observation in a given month:
stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$row <- 1:nrow(stocks)
rows <- aggregate(stocks$row, list(stocks$Date.aux, stocks$ISIN), max)
stocks <- stocks[rows$x, ]
stocks$row <- NULL

# Problem fixed, lets see: 
stocks[stocks$Date.aux == "1996-07-31" & stocks$ISIN == "ANN7425Q1095", ]


# Trade date is actually end-of-month -----------------------------------------#

stocks$delta.t <- as.numeric(stocks$Date.aux - stocks$Date)
summary(stocks$delta.t)

## ****************************
# We define a trade as not being too old if it occurs at most FIVE days before
# the end-of-month. 

stocks <- stocks[stocks$delta.t <= 5, ]
stocks$delta.t <- NULL

# Remove actual trading-date, as we only need end-of-month date: 
stocks$Date <- stocks$Date.aux
stocks$Date.aux <- NULL


## Computing returns ----------------------------------------------------------#

# Simple returns: R = Pt / Pt-1 -1
# Log returns: r = logPt - logPt-1

# Simple returns are additive across assets, but not additive over time.
# Log returns are aggregate over time, but not aggregate over assets. 
# Since we are analyzing portfolios, it is easiest to use simple returns. 

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$R <- unlist(tapply(stocks$Price, stocks$ISIN,
                          function(v) c(v[-1]/v[-length(v)] - 1, NA)))

# There could be cases when a stock stops trading for a period, and start up again
# We need to fix that for return-computation: 

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$delta.t <- unlist(tapply(stocks$Date, list(stocks$ISIN),
                                function(v) c(as.numeric(diff(v)), NA)))

# We see many stocks have more than 31 days between trading.
summary(stocks$delta.t)
summary(stocks$R)

# We only consider returns bases on price observation within a month (31 days)
stocks <- stocks[!is.na(stocks$delta.t), ]
stocks <- stocks[stocks$delta.t <= 31, ]
stocks$delta.t <- NULL

## Stock returns - wide format ------------------------------------------------#

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
w.stocks <- reshape(stocks[, c("Date", "ISIN", "R")],
                    v.names = "R", 
                    idvar = "Date", 
                    timevar = "ISIN",
                    direction = "wide")

w.stocks <- w.stocks[order(w.stocks$Date), ]
w.stocks[1:4, 1:4]
w.stocks[365:371, 1:4]


save(stocks, w.stocks, file = "stocks-90-20.RData")

rm(list=ls()) 




## 04.0 - Risk-free interest rate -------------------------------------------------

# 1980-1985: 1-month Eurokrone money market interest rates
# 1986–2013: 1-month Nibor
# 2014–2018: 1-month Nibor
# 2018-2020: 1-month Nibor


# 1980–1985
df1 <- read.csv("MMR-1980-1985.csv", skip = 12)
df1 <- df1[, c(1, 2)]
names(df1) <- c("Date", "rf")
months <- seq(as.Date("1959-05-01"), as.Date("1986-12-01"), by = "1 month")
months <- months - 1
df1$Date <- months
df1$rf <- df1$rf/100
df1 <- df1[df1$Date >= "1980-01-01", ]


# 1986-2013:
df2 <- read.csv("Nibor-1986-2013.csv", skip = 16)
df2 <- df2[, c(1, 5)]
names(df2) <- c("Date", "rf")
months <- seq(as.Date("1986-01-01"), as.Date("2013-12-01"), by = "1 month")
months <- months - 1
df2$Date <- months
df2$rf <- df2$rf/100

# 2014-2018:
df3 <- read.csv("Nibor-2014-2018.csv", skip = 0)
df3 <- df3[, c(1, 2)]
names(df3) <- c("Date", "rf")
df3$Date <- as.Date(df3$Date, format = "%d.%m.%y")
df3 <- df3[order(df3$Date), ]
df3 <- df3[df3$Date >= "2013-03-01" & df3$Date <= "2018-01-31", ]
months <- seq(as.Date("2013-03-01"), as.Date("2018-02-01"), by = "1 month")
df3$Date2 <- cut(df3$Date, months)
df3 <- aggregate(df3$rf, list(df3$Date2), head, n = 1)
names(df3) <- c("Date", "rf")
df3$Date <- as.Date(df3$Date) - 1
df3$rf <- df3$rf/100

# 2018-2020 (2021):

df4 <- read_xlsx("Nibor-2018-2020.xlsx")
names(df4) <- c("Date", "rf")
df4$Date <- as.Date(df4$Date)
df4 <- df4[order(df4$Date), ]

# We have stock data until 2020-12-31
# Need rates from 2018-01-01 to 2020-12-31

months <- seq(as.Date("2018-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

df4 <- df4[1:36, ]   # Only to 2020-12-31

df4$Date <- months
df4$rf <- df4$rf/100

# df1 = 1980-01-31 to 1986-11-30
# df2 = 1985-12-31 to 2013-11-30
# df3 = 2013-02-28 to 2017-12-31
# df4 = 2018-01-31 to 2020-12-31

# Try to plot them: 
plot(df1$Date, 
     df1$rf, 
     xlab = "", 
     ylab = "", 
     xlim = range(df1$Date, df2$Date, df3$Date, df4$Date), 
     ylim = range(df1$rf, df2$rf, df3$rf, df4$rf),
     type = "l", col = "black")

lines(df2$Date, df2$rf, col = "blue")
lines(df3$Date, df3$rf, col = "red")
lines(df4$Date, df4$rf, col = "green")

# Combining all rates: 

range(df1$Date)
range(df2$Date)
range(df3$Date)
range(df4$Date)


rf <- rbind(df1[df1$Date < "1985-12-31", ], df2, df3[df3$Date > "2013-11-30", ], df4)

rf$rf <- rf$rf/12 # monthly rate

## Only from 2000:
rf <- rf[rf$Date > "1989-12-31", ]


save(rf, file = "Riskfree-Rate.RData")

rm(list=ls()) # clear environment


## 05.0 - Fama French Factors --------------------------------------------------

# Norwegian factors  ----------------------------------------------------------#


## Load Excel file with data from Bernt Arne Ødegaard (Norwegian factors)
ffweb <- read_xlsx("ffweb.xlsm")
ffweb <- as.data.frame(ffweb)

# Change name from "date" to "Date"
names(ffweb)[names(ffweb) == 'date'] <- 'Date'

# Change date format
ffweb$Date <- as.Date(as.character(ffweb$Date),format="%Y%m%d")

## Change value format
sapply(ffweb, class)

cols.num <- c("SMB", "HML", "PR1YR", "UMD", "LIQ")
ffweb[cols.num] <- sapply(ffweb[cols.num],as.numeric)

sapply(ffweb, class)

# Push all data one month back (to align with forward looking returns)
months <- seq(as.Date("1980-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

ffweb$Date.aux <- cut(ffweb$Date, months, right = TRUE)
ffweb$Date <- ffweb$Date.aux
ffweb$Date.aux <- NULL
ffweb$Date <- as.Date(ffweb$Date)
## Filter for relevant months
#ffweb <- filter(ffweb, ffweb$Date >= "1999-12-31")
#save(ffweb, file = "FamaFrench2.RData")

## European factors -----------------------------------------------------------#

#fama3 <- read.csv("Europe_3_Factors.csv", header = TRUE, sep = ",", dec = ".", skip = 6)
fama5 <- read.csv("Europe_5_Factors.csv", header = TRUE, sep = ",", dec = ".", skip = 6)
mom <- read.csv("Europe_MOM_Factor.csv", header = TRUE, sep = ",", dec = ".", skip = 6)
#liq <- read.csv("famaliq.csv", header = TRUE, sep = ",", dec = ".")
#liq2 <- fread("https://finance.wharton.upenn.edu/~stambaug/liq_data_1962_2020.txt", skip = 100)

fama5 <- fama5[115:376, ]
colnames(fama5)[1] <- "Date"
fama5$Date <- paste(fama5$Date,"01",sep="")
fama5$Date <- as.Date(fama5$Date, format = "%Y%m %d")

mom <- mom[111:372, ]
colnames(mom)[1] <- "Date"
mom$Date <- paste(mom$Date,"01",sep="")
mom$Date <- as.Date(mom$Date, format = "%Y%m %d")

fama5mom <- merge(fama5, mom)


months <- seq(as.Date("2000-01-01"), as.Date("2021-11-01"), by = "1 month")
months <- months - 1

fama5mom$Date.aux <- cut(fama5$Date, months, right = TRUE)

fama5mom$Date[1:5]       
fama5mom$Date.aux[1:5]

fama5mom$Date <- fama5mom$Date.aux
fama5mom$Date.aux <- NULL
fama5mom$Date <- as.Date(fama5mom$Date, format = "%Y-%m-%d")

fama5mom[2:8] <- sapply(fama5mom[2:8], as.numeric)
fama5mom[2:8] <- fama5mom[2:8] / 100
fama5mom <- fama5mom[ , c(1:6,8,7)]


## Combine the two ------------------------------------------------------------#

ffweb <- filter(ffweb, ffweb$Date >= as.Date("1999-12-31") & ffweb$Date <= as.Date("2020-10-31"))
fama5mom <- filter(fama5mom, fama5mom$Date >= as.Date("1999-12-31") & fama5mom$Date <= as.Date("2020-10-31"))

colnames(fama5mom) <- c("Date", "Index.EU", "SMB.EU", "HML.EU", "RMW.EU", "CMA.EU", "UMD.EU","rf.EU")
colnames(ffweb) <- c("Date", "SMB.NO", "HML.NO", "PR1YR.NO", "UMD.NO", "LIQ.NO")

famafrench <- merge(ffweb, fama5mom)


# Save the files
save(famafrench, file = "FamaFrench_NO_EU.RData")


rm(list=ls())
##




## 06.0 - Indicies from Børsprosjektet (OSEBX & GICS) --------------------------

# index1 <- read.csv("Index-1980-1999.csv", header = TRUE, sep = ";", dec = ".")
# index2 <- read.csv("Index-2000-2003.csv", header = TRUE, sep = ";", dec = ".")
# index3 <- read.csv("Index-2004-2007.csv", header = TRUE, sep = ";", dec = ".")
# index4 <- read.csv("Index-2008-2010.csv", header = TRUE, sep = ";", dec = ".")
# index5 <- read.csv("Index-2011-2013.csv", header = TRUE, sep = ";", dec = ".")
# index6 <- read.csv("Index-2014-2016.csv", header = TRUE, sep = ";", dec = ".")
# index7 <- read.csv("Index-2017-2018.csv", header = TRUE, sep = ";", dec = ".")
# index8 <- read.csv("Index-2019-2020.csv", header = TRUE, sep = ";", dec = ".")
# 
# # Bind together all rows
# index <- rbind(index1, index2, index3, index4, index5, index6, index7, index8)
# 
# # Remove independt datafiles
# rm(index1, index2, index3, index4, index5, index6, index7, index8)
# 
# 
# colnames(index)[1] <- "TradeDate"
# index$TradeDate <- as.Date(index$TradeDate, format = "%Y-%m-%d")
# 
# index$X <- NULL
# index$Open <- NULL
# index$High <- NULL
# index$Low <- NULL
# 
# 
# # Check number of NAs in each column:
# na_count <-sapply(index, function(y) sum(length(which(is.na(y)))))
# data.frame(na_count)
# 
# save(index, file = "Index.RData")
# rm(list=ls())


load("Index.RData")

## Select indicies ------------------------------------------------------------#

indicies <- c("OSEBX", "OSE10GI", "OSE15GI", "OSE20GI", "OSE25GI", "OSE30GI", 
              "OSE35GI", "OSE40GI", "OSE45GI", "OSE50GI", "OSE55GI", "OSE60GI")

ix <- filter(index, Symbol %in% indicies)

ix <- ix[, c(1,3,6)]
colnames(ix) <- c("Date", "Index", "Close")


## Rolling observations forward in time ---------------------------------------#

# We need to make sure we have only one obersvation per stock, per month. 
# We also wish to have end-of-month price observation for each stock. 
# example: 2005-04-06 --> 2005-04-30

months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

ix$Date.aux <- cut(ix$Date, months, right = TRUE)

# We see that we did not get the desired result
ix$Date[1:5]       
ix$Date.aux[1:5]

# Fixing that: 
i <- as.numeric(ix$Date.aux)
ix$Date.aux <- months[i + 1]

# Now its good
ix$Date[1:5]
ix$Date.aux[1:5]

## Only one stock price observation per month ---------------------------------#

num <- aggregate(ix$Index, list(ix$Date.aux, ix$Index), length)
head(num[num$x > 1, ])    

# We have some cases with more than one observations, For instance:
ix[ix$Date.aux == "1996-01-31" & ix$Index == "OSE10GI", ]

# We take the most recent observation in a given month:
ix <- ix[order(ix$Index, ix$Date), ]
ix$row <- 1:nrow(ix)
rows <- aggregate(ix$row, list(ix$Date.aux, ix$Index), max)
ix <- ix[rows$x, ]
ix$row <- NULL

# Problem fixed, lets see: 
ix[ix$Date.aux == "1996-01-31" & ix$Index == "OSE10GI", ]

ix$Date <- ix$Date.aux
ix$Date.aux <- NULL


## Adding december prices -----------------------------------------------------#

dates <- c(as.Date("2020-12-31", format = "%Y-%m-%d"))
dates <- rep(dates, each = 12)
indicies <- indicies
values <- c(973.9700, 687.35, 678.67, 580.26, 861.92, 3028.82, 915.67, 2155.11,
            423.65, 1777.52, 2997.55, 180.85)

# Retrived from live.euronext.com

bind <- data.frame(Date = dates, Index = indicies, Close = values)
ix <- rbind(ix, bind)


## Computing returns ----------------------------------------------------------#

# Simple returns: R = Pt / Pt-1 -1
# Log returns: r = logPt - logPt-1

# Simple returns are additive across assets, but not additive over time.
# Log returns are aggregate over time, but not aggregate over assets. 
# Since we are analyzing portfolios, it is easiest to use simple returns. 

ix <- ix[order(ix$Index, ix$Date), ]
ix$R <- unlist(tapply(ix$Close, ix$Index,
                      function(v) c(v[-1]/v[-length(v)] - 1, NA)))

# There could be cases when a stock stops trading for a period, and start up again
# We need to fix that for return-computation: 

ix <- ix[order(ix$Index, ix$Date), ]
ix$delta.t <- unlist(tapply(ix$Date, list(ix$Index),
                            function(v) c(as.numeric(diff(v)), NA)))

# We see many stocks have more than 31 days between trading.
summary(ix$delta.t)
summary(ix$R)

# We only consider returns bases on price observation within a month (31 days)
ix <- ix[!is.na(ix$delta.t), ]
ix <- ix[ix$delta.t <= 31, ]
ix$delta.t <- NULL

## Stock returns - wide format ------------------------------------------------#

ix <- ix[order(ix$Index, ix$Date), ]
w.ix <- reshape(ix[, c("Date", "Index", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "Index",
                direction = "wide")

w.ix <- w.ix[order(w.ix$Date), ]
rownames(w.ix) <- seq(length = nrow(w.ix))


save(ix, w.ix, file = "Indicies2.RData")




## 06.0 - Indicies from Børsprosjektet ------------------------------------------

index1 <- read.csv("Index-1980-1999.csv", header = TRUE, sep = ";", dec = ".")
index2 <- read.csv("Index-2000-2003.csv", header = TRUE, sep = ";", dec = ".")
index3 <- read.csv("Index-2004-2007.csv", header = TRUE, sep = ";", dec = ".")
index4 <- read.csv("Index-2008-2010.csv", header = TRUE, sep = ";", dec = ".")
index5 <- read.csv("Index-2011-2013.csv", header = TRUE, sep = ";", dec = ".")
index6 <- read.csv("Index-2014-2016.csv", header = TRUE, sep = ";", dec = ".")
index7 <- read.csv("Index-2017-2018.csv", header = TRUE, sep = ";", dec = ".")
index8 <- read.csv("Index-2019-2020.csv", header = TRUE, sep = ";", dec = ".")

# Bind together all rows
index <- rbind(index1, index2, index3, index4, index5, index6, index7, index8)

# Remove independt datafiles
rm(index1, index2, index3, index4, index5, index6, index7, index8)


colnames(index)[1] <- "TradeDate"
index$TradeDate <- as.Date(index$TradeDate, format = "%Y-%m-%d")

index$X <- NULL
index$Open <- NULL
index$High <- NULL
index$Low <- NULL


# Check number of NAs in each column:
na_count <-sapply(index, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

save(index, file = "Index.RData")
rm(list=ls())


load("Index.RData")


## Picking indicies & from daily to monthly -----------------------------------#

indicies <- unique(index[, 3:4])

## TOTX - TOTX-Indeks
totx <- filter(index, Symbol %in% c("TOTX"))
totx[, 2:5] <- NULL
totx <- totx[order(totx$TradeDate), ]
head(totx)
tail(totx)
months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
totx$Date2 <- cut(totx$TradeDate, months)
totx <- aggregate(totx$Close, list(totx$Date2), head, n = 1)
names(totx) <- c("Date", "Close")
totx$Date <- as.Date(totx$Date) - 1

# XOBX - OBX-indeks
xobx <- filter(index, Symbol %in% c("XOBX"))
xobx[, 2:5] <- NULL
xobx <- xobx[order(xobx$TradeDate), ]
head(xobx)
tail(xobx)
months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
xobx$Date2 <- cut(xobx$TradeDate, months)
xobx <- aggregate(xobx$Close, list(xobx$Date2), head, n = 1)
names(xobx) <- c("Date", "Close")
xobx$Date <- as.Date(xobx$Date) - 1


# OSEAX - Oslo Børs All-share Index_GI
oseax <- filter(index, Symbol %in% c("OSEAX"))
oseax[, 2:5] <- NULL
oseax <- oseax[order(oseax$TradeDate), ]
head(oseax)
tail(oseax)
months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
oseax$Date2 <- cut(oseax$TradeDate, months)
oseax <- aggregate(oseax$Close, list(oseax$Date2), head, n = 1)
names(oseax) <- c("Date", "Close")
oseax$Date <- as.Date(oseax$Date) - 1


# OSEBX - Oslo Børs Benchmark Index_GI
osebx <- filter(index, Symbol %in% c("OSEBX"))
osebx[, 2:5] <- NULL
osebx <- osebx[order(osebx$TradeDate), ]
head(osebx)
tail(osebx)
months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
osebx$Date2 <- cut(osebx$TradeDate, months)
osebx <- aggregate(osebx$Close, list(osebx$Date2), head, n = 1)
names(osebx) <- c("Date", "Close")
osebx$Date <- as.Date(osebx$Date) - 1
head(osebx)
tail(osebx)

# OBX - OBX-indeks
obx <- filter(index, Symbol %in% c("OBX"))
obx[, 2:5] <- NULL
obx <- obx[order(obx$TradeDate), ]
head(obx)
tail(obx)
months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
obx$Date2 <- cut(obx$TradeDate, months)
obx <- aggregate(obx$Close, list(obx$Date2), head, n = 1)
names(obx) <- c("Date", "Close")
obx$Date <- as.Date(obx$Date) - 1


# Try to plot them: 
plot(obx$Date, 
     obx$Close, 
     xlab = "", 
     ylab = "", 
     xlim = range(obx$Date, oseax$Date, osebx$Date, totx$Date, xobx$Date), 
     ylim = range(obx$Close, oseax$Close, osebx$Close, totx$Close, xobx$Close),
     type = "l", col = "black")

lines(oseax$Date, oseax$Close, col = "blue")
lines(osebx$Date, osebx$Close, col = "red")
lines(totx$Date, totx$Close, col = "green")
lines(xobx$Date, xobx$Close, col = "yellow")


save(obx, oseax, osebx, totx, xobx, file = "Indicies.RData")
rm(list=ls())



## 06.1 - Index from 1990-2020 --------------------------------------------------

# Index = Value weighted market index until OSEBX exist

# Stock data
load("stocks_market.RData")


## Rolling observations forward in time ---------------------------------------#

months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

stocks$Date.aux <- cut(stocks$Date, months, right = TRUE)
i <- as.numeric(stocks$Date.aux)
stocks$Date.aux <- months[i + 1]


## Only one stock price observation per month (pick most recent) --------------#

num <- aggregate(stocks$ISIN, list(stocks$Date.aux, stocks$ISIN), length)

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$row <- 1:nrow(stocks)
rows <- aggregate(stocks$row, list(stocks$Date.aux, stocks$ISIN), max)
stocks <- stocks[rows$x, ]
stocks$row <- NULL

# Trade date is actually end-of-month -----------------------------------------#

stocks$delta.t <- as.numeric(stocks$Date.aux - stocks$Date)
summary(stocks$delta.t)

## ****************************
# We define a trade as not being too old if it occurs at most FIVE days before
# the end-of-month. Is this okay amount? 

stocks <- stocks[stocks$delta.t <= 5, ]
stocks$delta.t <- NULL

# Remove actual trading-date, as we only need end-of-month date: 
stocks$Date <- stocks$Date.aux
stocks$Date.aux <- NULL

# Save data for market cap for backtesting
save(stocks, file = "stocksMktCap.RData")

## Computing returns ----------------------------------------------------------#

# Simple returns: R = Pt / Pt-1 -1
# Log returns: r = logPt - logPt-1

# Simple returns are additive across assets, but not additive over time.
# Log returns are aggregate over time, but not aggregate over assets. 
# Since we are analyzing portfolios, it is easiest to use simple returns. 

colnames(stocks)[7] <- "Price"

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$R <- unlist(tapply(stocks$Price, stocks$ISIN,
                          function(v) c(v[-1]/v[-length(v)] - 1, NA)))


# There could be cases when a stock stops trading for a period, and start up again
# We need to fix that for return-computation: 

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
stocks$delta.t <- unlist(tapply(stocks$Date, list(stocks$ISIN),
                                function(v) c(as.numeric(diff(v)), NA)))

# We see many stocks have more than 31 days between trading.
summary(stocks$delta.t)
summary(stocks$R)

# We only consider returns bases on price observation within a month (31 days)
stocks <- stocks[!is.na(stocks$delta.t), ]
stocks <- stocks[stocks$delta.t <= 31, ]
stocks$delta.t <- NULL


## Market cap and weights -----------------------------------------------------#

stocks$MarketCap <- stocks$Generic * stocks$SharesIssued/1e+06

res <- aggregate(stocks$MarketCap, list(stocks$Date), sum)
names(res) <- c("Date", "TotalMarketCap")
plot(res$Date, res$TotalMarketCap,
     type="l", xlab="", ylab="Total Market Capitalization [mln]")

stocks <- merge(stocks, res, by = "Date")

stocks$Weight <- stocks$MarketCap/stocks$TotalMarketCap


# Market returns --------------------------------------------------------------#

market.ew <- aggregate(stocks$R, list(stocks$Date), mean)
names(market.ew) <- c("Date", "RM.ew")

stocks$h <- stocks$R*stocks$Weight
market.vw <- aggregate(stocks$h, list(stocks$Date), sum)
names(market.vw) <- c("Date", "RM.vw")

RM.ew <- 100 * cumprod(1 + market.ew$RM.ew)
RM.vw <- 100 * cumprod(1 + market.vw$RM.vw)
plot(market.ew$Date, RM.ew, type = "l", xlab = "", ylab = "Market index",
     col = "red")
lines(market.vw$Date, RM.vw, type = "l", col = "blue")
legend("topleft", c("Equally-weighed", "Value-weighed"), lwd = 2,
       col = c("red", "blue"))

market.ew$index <- RM.ew
market.vw$index <- RM.vw

# Add 100 as index start
market.ew <- rbind(data.frame(Date = as.Date("1989-12-31", format = "%Y-%m-%d"), 
                              RM.ew = 0, index = 100), market.ew)
market.vw <- rbind(data.frame(Date = as.Date("1989-12-31", format = "%Y-%m-%d"), 
                              RM.vw = 0, index = 100), market.vw)

save(market.ew, market.vw, file = "market.vw.ew.RData")

rm(list = ls())

## Combining OSEBX and the market index ---------------------------------------#

load("market.vw.ew.RData")
load("Indicies.RData")

rm(obx, oseax, rows, totx, xobx)

# Try to plot them: 
plot(osebx$Date, 
     osebx$Close, 
     xlab = "", 
     ylab = "", 
     xlim = range(market.ew$Date, market.vw$Date, osebx$Date), 
     ylim = range(market.ew$index, market.vw$index, osebx$Close),
     type = "l", col = "black")

lines(market.vw$Date, market.vw$index, type = "l", col = "green")
lines(market.ew$Date, market.ew$index, type = "l", col = "red")

# We see that value weighted aligns best with OSEBX
# We create value weighted until osebx exist

head(market.vw)
head(osebx)
# vw has returns, osebx has index, we adjust osebx to be returns

# Add november and december index for OSEBX:
osebx <- rbind(osebx, data.frame(Date = as.Date("2020-11-30", format = "%Y-%m-%d"),
                                 Close = 930.3900))
osebx <- rbind(osebx, data.frame(Date = as.Date("2020-12-31", format = "%Y-%m-%d"),
                                 Close = 973.9700))



## Fixing OSEBX returns
osebx.prices <- osebx[, "Close", drop = FALSE]
n <- nrow(osebx.prices)

osebx.r <- ((osebx.prices[2:n, 1] - osebx.prices[1:(n-1), 1])/osebx.prices[1:(n-1), 1])
osebx.r <- append(osebx.r, 0, 0)

osebx$r <- osebx.r

colnames(market.vw) <- c("Date","R","Index")
osebx <- osebx[, c(1,3,2)]
colnames(osebx) <- c("Date","R","Index")

osebx[1,]

# Merge return of "index" from 1990 to when osebx start
index <- rbind(market.vw[market.vw$Date <= "1995-11-30", ], osebx[-1,])

index.index <- 100 * cumprod(1 + index$R)
index$x <- index.index

# Plot it ---
index <- index[, c(1,2,4)]
colnames(index) <- c("Date","R","Index")


# Try to plot them: 
plot(osebx$Date, 
     osebx$Index, 
     xlab = "", 
     ylab = "", 
     xlim = range(index$Date, market.vw$Date, osebx$Date), 
     ylim = range(index$Index, market.vw$Index, osebx$Index),
     type = "l", col = "black")

lines(market.vw$Date, market.vw$Index, type = "l", col = "green")
lines(index$Date, index$Index, type = "l", col = "red")

# Is OK. 

save(index, file = "index-90-20.RData")

rm(list=ls()) # clear environment


## END


## 06.2 - GICS indicies --------------------------------------------------------

rm(list = ls())

load("Index.RData")
indicies <- unique(index[, 3:4])

gicsIndicies <- c("OSE10GI", "OSE15GI", "OSE20GI", "OSE25GI", "OSE30GI", 
                  "OSE35GI", "OSE40GI", "OSE45GI", "OSE50GI", "OSE55GI",
                  "OSE60GI")
gicsDescription <- c("Energy", "Materials", "Industrials", "ConsumerDiscretionary",
                     "ConsumerStaples", "HealthCare", "Financials", 
                     "InformationTechnology", "TelecommunicationServices", 
                     "Utilities", "RealEstate")


i <- 1

for (i in 1:length(gicsIndicies)) {
  
  name <- gicsIndicies[i]
  
  df <- filter(index, Symbol %in% c(name))
  df[, 2:5] <- NULL
  df <- df[order(df$TradeDate), ]
  head(df)
  tail(df)
  months <- seq(as.Date("1983-01-01"), as.Date("2020-12-01"), by = "1 month")
  df$Date2 <- cut(df$TradeDate, months)
  df <- aggregate(df$Close, list(df$Date2), head, n = 1)
  names(df) <- c("Date", "Close")
  df$Date <- as.Date(df$Date) - 1
  
  assign(paste(name, sep = "") , df)
  
  
}

gicsX <- OSE10GI[ , 1, drop = FALSE]


for (i in 1:10) {
  df <- get(gicsIndicies[i])
  gicsX$df <- df[ , 2]
  colnames(gicsX)[ncol(gicsX)] <- gicsIndicies[i]
}

gicsX <- merge(gicsX, OSE60GI, all.x = TRUE)
colnames(gicsX)[12] <- gicsIndicies[11]

save(gicsX, file = "gicsIndicies.RData")



## 07.0 - MarketCaps 1990-2020 --------------------------------------------------

load("stocksMktCap.RData")


stocks$MarketCap <- stocks$Generic * stocks$SharesIssued/1e+06

stocks <- stocks[ , c(1,2,8)]

colnames(stocks) <- c("Date","ISIN","R") # must named R for backtest

stocks <- stocks[order(stocks$ISIN, stocks$Date), ]
w.stocks <- reshape(stocks[, c("Date", "ISIN", "R")],
                    v.names = "R", 
                    idvar = "Date", 
                    timevar = "ISIN",
                    direction = "wide")

w.mktcap <- w.stocks[order(w.stocks$Date), ]



##
save(w.mktcap, file = "mktcap-90-20.RData")

rm(list=ls()) 



## END


## 08.0 - EIKON Accounting data: NEW_ISIN ---------------------------------------

eikon.acc <- read_xlsx("EIKON.isin.90-20.xlsx", 
                       sheet = "KeyAccNEW_ISIN", 
                       skip = 1, 
                       col_names = TRUE)

# Fixing columns
eikon.acc <- as.data.frame(eikon.acc)
eikon.acc[ , 1] <- as.Date(eikon.acc[ , 1], format = "%Y-%m-%d")
eikon.acc[ , 2] <- as.character(eikon.acc[ , 2])

# All other columns as numeric values:
cols <- names(eikon.acc)[3:ncol(eikon.acc)]
eikon.acc[cols] <- lapply(eikon.acc[cols], as.numeric)

names(eikon.acc) <- c("Date",
                      "ISIN",
                      "EBITDAMarginPrc",
                      "EBITDAMarginPrcChg",
                      "GrossMarginPrc",
                      "GrossProfitMargin",
                      "CurrentRatio",
                      "QuickRatio",
                      "ROA",
                      "ROE",
                      "EPS",
                      "P_E",
                      "NetProfitMarginPrc",
                      "OperatingMarginPrc",
                      "EV_FCF",
                      "FCF",
                      "DPS",
                      "Revenue",
                      "RevenueChg",
                      "DPR",
                      "CFPerShare",
                      "InterestCoverageRatio",
                      "EBITMarginPrc",
                      "CFFO", 
                      "EV_Revenue",
                      "EV_EBITDA",
                      "D_EPrc",
                      "ROIC",
                      "FCFYieldPrc",
                      "P_B",
                      "P_S")


# Remove rows with all NA's (except date and isin)
delete.na <- function(DF, n=0) { DF[rowSums(is.na(DF)) <= n,] }
eikon.acc <- delete.na(eikon.acc, ncol(eikon.acc)-3)
eikon.acc <- as.data.frame(eikon.acc)


## Rolling observations forward in time ---------------------------------------#

months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

eikon.acc$Date.aux <- cut(eikon.acc$Date, months, right = TRUE)
eikon.acc <- eikon.acc[ , c(1,32,2:31)]

i <- as.numeric(eikon.acc$Date.aux)
eikon.acc$Date.aux <- months[i + 1]

eikon.acc <- eikon.acc[order(eikon.acc$Date.aux, eikon.acc$ISIN), ]

# Check number of NAs in each column:
na_count <-sapply(eikon.acc, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

# ISIN RIC problem ------------------------------------------------------------#
# When we collect data from EIKON, EIKON sometimes return RIC for some rows
# with accouting data, not ISIN. We need to replace these rows with ISIN again.
load("isin_1990.RData")
isin_1990_2020 <- isin_1990_2020[ , c(2,3)]
colnames(isin_1990_2020)[1] <- "ISIN"               # Same colname as in eikon
isin_1990_2020 <- as.data.frame(isin_1990_2020)

# Match RIC in accouting dataframe, with corresponding ISIN in ISIN dataframe
# The column "Temp" is either NA
eikon.acc$Temp <- isin_1990_2020$ISIN[match(unlist(eikon.acc$ISIN), isin_1990_2020$RIC)]
eikon.acc$Temp2 <- ifelse(is.na(eikon.acc$Temp), eikon.acc$ISIN, eikon.acc$Temp)
eikon.acc$ISIN <- eikon.acc$Temp2
eikon.acc <- eikon.acc[ , -c(33,34)]


save(eikon.acc, file = "eikonaccNEW_ISIN.RData")

rm(list=ls()) # clear environment


## END


## 08.1 - Accounting: From Excel to ready for backtesting ------------------------

# In this section we will extract data downloaded from EIKON, and make it 
# ready for backtesting. 

load("eikonaccNEW_ISIN.RData")       
#load("ADJ.eikonaccNEW_ISIN.RData")    

for (i in 4:ncol(eikon.acc))  {      
  
  df <- eikon.acc[ , c(1,2,3,i)]
  df <- df[order(df$Date, df$ISIN), ]
  
  name <- colnames(df)[4]
  
  # Only one metric value per month -------------------------------------------#
  df <- df[complete.cases(df), ]
  
  num <- aggregate(df$ISIN, list(df$Date.aux, df$ISIN), length)
  
  # We take the most recent observation in a given month:
  df <- df[order(df$ISIN, df$Date), ]
  df$row <- 1:nrow(df)
  rows <- aggregate(df$row, list(df$Date.aux, df$ISIN), max)
  df <- df[rows$x, ]
  df$row <- NULL
  
  # Remove actual trading-date, as we only need end-of-month date: 
  df$Date <- df$Date.aux
  df$Date.aux <- NULL
  
  ## Wide format --------------------------------------------------------------#
  
  df <- df[order(df$ISIN, df$Date), ]
  colnames(df) <- c("Date", "ISIN", "R")
  df <- as.data.frame(df)
  
  w.df <- reshape(df[, c("Date", "ISIN", "R")],
                  v.names = "R", 
                  idvar = "Date", 
                  timevar = "ISIN", 
                  direction = "wide")
  
  w.df <- w.df[order(w.df$Date), ]
  w.df[330:336, 1:4]
  
  # Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#
  
  months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
  months <- months - 1
  
  months <- as.data.frame(months)
  colnames(months) <- "Date"
  
  w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)
  
  ## Last Observation Carried Forward  (since quarterly data) -----------------#
  
  # We only have quarterly updates of accounting values, but we want to rebalance 
  # our portfolio monthly. Therefore, we carry forward the last accounting
  # observation maximum 12 months. If there is a new updated observation within
  # this timeframe, the value will update. 
  # Thus, making the accounting-number "relevant" for max one year.
  
  w.df.locf <- w.df
  relevant <- 12  # How many months a metric is relevant
  
  for (i in 2:ncol(w.df.locf)) {
    x <- w.df.locf[ , i]
    l <- cumsum(! is.na(x))
    y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
    w.df.locf[ , i] <- y
  }

  # Assing correct name to dataframe
  assign(paste(name, sep = "") , w.df.locf)
  
  rm(months,num,rows,df,w.df,w.df.locf)

}

rm(eikon.acc, i, name)

# Save dataframes to working directory:
dfs<-Filter(function(x) is.data.frame(get(x)) , ls())
for(d in dfs) {
  save(list=d, file=paste0(d, ".RData"))
}

# Save list of metrics in case for later:
KeyMetrics <- dfs
save(KeyMetrics, file = "KeyMetrics.RData")

rm(list = ls())


## END



## 09.0 - Accounting data from Borsprosjektet -----------------------------------

## Accounts.csv ---------------------------------------------------------------#

accounts <- read.csv("Accounts.csv", header = FALSE, sep = ",", dec = ".")
names(accounts) <- c("AccountId", "CompanyId", "FiscalYear", "AccountType", 
                     "FiscalYearStart", "FiscalYearEnd", "Period", "Preliminary",
                     "ukjent1", "ukjent2", "ukjent3", "ukjent4", "ukjent5",
                     "ukjent6", "ukjent7", "ukjent8", "ukjent9", "ukjent10")

accounts[1,1] <- "1"
accounts$AccountId <- as.numeric(accounts$AccountId)
unique(accounts$AccountType) # søk Table A 2 Account Type i pdf (type regnskapform/regler)

accounts$FiscalYearStart <- as.Date(accounts$FiscalYearStart, format = "%Y-%m-%d")
accounts$FiscalYearEnd <- as.Date(accounts$FiscalYearEnd, format = "%Y-%m-%d")

unique(accounts$Period) # 1= 1 kvartal, 2-3-4.. 5 = årsregnskap
unique(accounts$Preliminary) # 0 = preliminary, 1 = audited, 2 = "Mangler fra OBI"

# ukjent 1 = AccountType
accounts$ukjent1 <- NULL

# ukjent 2 har verdiene "1980, 1995, 2004" - ser ut til å være "Fiscal year start" i Table A 2 Account Type
accounts$ukjent2 <- NULL

# ukjent 3 har verdiene til "Fiscal year end" i Table A 2 Account Type
accounts$ukjent3 <- NULL

# ukjent 4 er "Norwegian" i tabellen:
accounts$ukjent4 <- NULL

# ukjent 5 er "English" i tabellen:
accounts$ukjent5 <- NULL

# ukjent 6-8 er Table 3 account period:
accounts$ukjent6 <- NULL
accounts$ukjent7 <- NULL
accounts$ukjent8 <- NULL

# ukjent 9 og 10 er 0-1-2 om det er "Audited" "Preliminary" eller "Mangler fra OBI"
accounts$ukjent9 <- NULL
accounts$ukjent10 <- NULL


## AccountingVariables.csv ----------------------------------------------------#

accVar <- read.csv("AccountingVariables.csv", header = FALSE, sep = ",", dec = ".")

names(accVar) <- c("AccountId", "CompanyId", "ItemType", "VariableId", 
                   "SortKey", "AccountItemCategory", "Description", 
                   "AccountItem", "ItemType2", "ItemTypeNor", "ItemTypeEng")



accVar[1,1] <- "1"
accVar$AccountId <- as.numeric(accVar$AccountId)

# Account ID = ID til ett årsregnskap/kvartalsregnskap

# ItemType = Table A 1 Item Type (Income statement, assets, liabilities & equity, other)
# 1 = Income statement, 10 = assets, 11 = Liabilities & Equity, 20 = Other numbers
# 12 = Cash Flow Statement, 21 = Interest expenses on bond loans

accVar$ItemType2 <- NULL
accVar$ItemTypeNor <- NULL
accVar$ItemTypeEng <- NULL

# Variable ID = search "Variable Id List" - liste over poster
# Sort key - noe sorteringsgreier: post 4.1.9 = 4001009000000
# AccountItemCategory - detaljert post
# Description - forklaring
# Verdi i 1000 NOK


## AccountingKeyVariables.csv -------------------------------------------------#

# 5 List of key figures i dokumentasjonen

accKeyVar <- read.csv("AccountingKeyVariables.csv", header = FALSE, sep = ",", dec = ".")

names(accKeyVar) <- c("AccountId", "CompanyId", "KeyId", "Description", "KeyFigure")


accKeyVar[1,1] <- "1"
accKeyVar$AccountId <- as.numeric(accKeyVar$AccountId)
accKeyVar$KeyFigure <- as.numeric(accKeyVar$KeyFigure)

unique(accKeyVar$KeyId)
unique(accKeyVar$Description)


## Combine tables: AccVar -----------------------------------------------------#

# Check number of NAs in each column:
na_count <-sapply(accounts, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

na_count <-sapply(accVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

na_count <-sapply(accKeyVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)


BorsAccVar <- merge(accVar, accounts, by.x = "AccountId", by.y = "AccountId")

BorsAccVar$ItemType <- NULL
BorsAccVar$SortKey <- NULL
BorsAccVar$AccountItemCategory <- NULL
BorsAccVar$AccountType <- NULL
BorsAccVar$FiscalYear <- NULL
BorsAccVar$FiscalYearStart <- NULL
BorsAccVar$CompanyId.y <- NULL
BorsAccVar$Preliminary <- NULL

BorsAccVar <- BorsAccVar[BorsAccVar$Period < 5, ]  # Only quarterly numbers
BorsAccVar$Period <- NULL

colnames(BorsAccVar)[2] <- "CompanyId"

na_count <-sapply(BorsAccVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

## Add 2 months to end date
BorsAccVar <- BorsAccVar[ ,c(6,1:5)]
colnames(BorsAccVar)[1] <- "Date"

months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

BorsAccVar$Date.aux <- cut(BorsAccVar$Date, months, right = TRUE)
i <- as.numeric(BorsAccVar$Date.aux)
BorsAccVar$Date.aux <- months[i + 3]

BorsAccVar$Date[1:5]       
BorsAccVar$Date.aux[1:5]

## Add ISIN 

load("stocks.all.RData")

# Column names 
colnames(stocks)[1] <- "Date"
stocks$Date <- as.Date(stocks$Date, format = "%Y-%m-%d")

# Remove columns
stocks <- stocks[ , -c(11:ncol(stocks))]


# We want only ordinary shares and primary capital certificates of companies 
# listed on OSE between 1990-01-01 and 2020-12-31

stocks <- filter(stocks, IsStock == 1)
stocks <- filter(stocks, SecurityType %in% c("Ordinary Shares", 
                                             "Primary Capital Certificates"))
stocks <- filter(stocks, stocks$Date >= "1990-01-01")
stocks <- filter(stocks, Market == "OSE")

test <- unique(stocks[ , c(4,10)])

## Add to Bors: 
test2 <- merge(BorsAccVar, test)
BorsAccVar <- test2

BorsAccVar$CompanyId <- NULL
BorsAccVar$AccountId <- NULL
BorsAccVar <- BorsAccVar[ , c(1,5,6,2,3,4)]

AccountingVariables <- unique(BorsAccVar[ , c(4,5)])
rownames(AccountingVariables) <- seq(length = nrow(AccountingVariables))

save(BorsAccVar, AccountingVariables, file = "BorsAccVar.RData")



## Combine tables: accKeyVar --------------------------------------------------#

# Check number of NAs in each column:
na_count <-sapply(accounts, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

na_count <-sapply(accVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

na_count <-sapply(accKeyVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)


BorsAccKeyVar <- merge(accKeyVar, accounts, by.x = "AccountId", by.y = "AccountId")

BorsAccKeyVar$AccountType <- NULL
BorsAccKeyVar$FiscalYear <- NULL
BorsAccKeyVar$FiscalYearStart <- NULL
BorsAccKeyVar$CompanyId.y <- NULL
BorsAccKeyVar$Preliminary <- NULL

BorsAccKeyVar <- BorsAccKeyVar[BorsAccKeyVar$Period < 5, ]  # Only quarterly numbers
BorsAccKeyVar$Period <- NULL

colnames(BorsAccKeyVar)[2] <- "CompanyId"

na_count <-sapply(BorsAccKeyVar, function(y) sum(length(which(is.na(y)))))
data.frame(na_count)

BorsAccKeyVar <- BorsAccKeyVar[!is.na(BorsAccKeyVar$KeyFigure), ]       # Remove NA's

## Add 2 months to end date
BorsAccKeyVar <- BorsAccKeyVar[ ,c(6,1:5)]
colnames(BorsAccKeyVar)[1] <- "Date"

months <- seq(as.Date("1990-01-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

BorsAccKeyVar$Date.aux <- cut(BorsAccKeyVar$Date, months, right = TRUE)
i <- as.numeric(BorsAccKeyVar$Date.aux)
BorsAccKeyVar$Date.aux <- months[i + 3]

BorsAccKeyVar$Date[1:5]       
BorsAccKeyVar$Date.aux[1:5]

## Add ISIN 
# Need ISIN and CompanyID

load("stocks.all.RData")

# Column names 
colnames(stocks)[1] <- "Date"
stocks$Date <- as.Date(stocks$Date, format = "%Y-%m-%d")

# Remove columns
stocks <- stocks[ , -c(11:ncol(stocks))]


# We want only ordinary shares and primary capital certificates of companies 
# listed on OSE between 1990-01-01 and 2020-12-31

stocks <- filter(stocks, IsStock == 1)
stocks <- filter(stocks, SecurityType %in% c("Ordinary Shares", 
                                             "Primary Capital Certificates"))
stocks <- filter(stocks, stocks$Date >= "1990-01-01")
stocks <- filter(stocks, Market == "OSE")

test <- unique(stocks[ , c(4,10)])

## Add to Bors: 
test2 <- merge(BorsAccKeyVar, test)
BorsAccKeyVar <- test2

BorsAccKeyVar$CompanyId <- NULL
BorsAccKeyVar$AccountId <- NULL
BorsAccKeyVar <- BorsAccKeyVar[ , c(1,5,6,2,3,4)]

AccountingKeyVariables <- unique(BorsAccKeyVar[ , c(4,5)])
rownames(AccountingKeyVariables) <- seq(length = nrow(AccountingKeyVariables))

save(BorsAccKeyVar, AccountingKeyVariables, file = "BorsAccKeyVar.RData")

rm(list = ls())


## 09.1 - Supply revenue data from Bors to EIKON --------------------------------

load("BorsAccVar.RData")

TotOpIncome <- filter(BorsAccVar, VariableId == 34)
TotOpIncome <- filter(TotOpIncome, AccountItem > 0)

load("isin_1990.RData")

TotOpIncome2 <- merge(TotOpIncome, isin_1990_2020, by.x = "ISIN", by.y = "OLD_ISIN")
TotOpIncome <- TotOpIncome2

TotOpIncome <- TotOpIncome[ , c(3,6,7)]
TotOpIncome <- TotOpIncome[ , c(1,3,2)]
colnames(TotOpIncome) <- c("Date", "ISIN", "R")


### REVENUE EIKON: 

load("eikonaccNEW_ISIN.RData") 

df <- eikon.acc[ , c(1,2,3,19)]
df <- df[order(df$Date, df$ISIN), ]

# Only one metric value per month -------------------------------------------#
df <- df[complete.cases(df), ]

num <- aggregate(df$ISIN, list(df$Date.aux, df$ISIN), length)

# We take the most recent observation in a given month:
df <- df[order(df$ISIN, df$Date), ]
df$row <- 1:nrow(df)
rows <- aggregate(df$row, list(df$Date.aux, df$ISIN), max)
df <- df[rows$x, ]
df$row <- NULL

# Remove actual trading-date, as we only need end-of-month date: 
df$Date <- df$Date.aux
df$Date.aux <- NULL



df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
df <- df[df$R >= 0, ]                   # Remove negative revenues

revenue <- df

## Merge EIKON data and Bors data

revenue2 <- merge(revenue, TotOpIncome, by = c("Date", "ISIN"), all = TRUE)
colnames(revenue2) <- c("Date", "ISIN", "EIKON", "Bors")
revenue2$Bors <- revenue2$Bors * 1000
revenue2$merged <- ifelse(is.na(revenue2$EIKON), revenue2$Bors, revenue2$EIKON)
revenue2 <- revenue2[ , c(1,2,5)]
colnames(revenue2) <- c("Date", "ISIN", "R")


save(revenue2, file = "revenue-merged.RData")

rm(list=ls())

## Wide format ----------------------------------------------------------------#

df <- TotOpIncome
df <- df[order(df$Date, df$ISIN), ]


## Wide format --------------------------------------------------------------#

df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
#df <- df[df$R >= 0, ]                   # Remove negative revenues

w.df <- reshape(df[, c("Date", "ISIN", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "ISIN", 
                direction = "wide")

w.df <- w.df[order(w.df$Date), ]


# Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#

months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

months <- as.data.frame(months)
colnames(months) <- "Date"

w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)

## Last Observation Carried Forward  (since quarterly data) -----------------#

# We only have quarterly updates of accounting values, but we want to rebalance 
# our portfolio monthly. Therefore, we carry forward the last accounting
# observation maximum 12 months. If there is a new updated observation within
# this timeframe, the value will update. 
# Thus, making the accounting-number "relevant" for max one year.

w.df.locf <- w.df
relevant <- 12  # How many months a metric is relevant

for (i in 2:ncol(w.df.locf)) {
  x <- w.df.locf[ , i]
  l <- cumsum(! is.na(x))
  y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
  w.df.locf[ , i] <- y
}


w.df[300:320,340:343]
w.df.locf[300:320,340:343]

w.revenue.bors <- w.df.locf


eikon <- rowSums(!is.na(w.revenue))
bors <- rowSums(!is.na(w.revenue.bors))

jazz <- data.frame(w.revenue$Date, bors, eikon)



## 09.2 - Supply ROE data from Borsprosjektet -----------------------------------------

load("BorsAccKeyVar.RData")


roe <- filter(BorsAccKeyVar, KeyId == 14)

load("isin_1990.RData")

roe2 <- merge(roe, isin_1990_2020, by.x = "ISIN", by.y = "OLD_ISIN")
roe <- roe2

roe <- roe[ , c(3,6,7)]
roe <- roe[ , c(1,3,2)]
colnames(roe) <- c("Date", "ISIN", "R")

roe.bors <- roe

### ROE EIKON -----------------------------------------------------------------#

load("eikonaccNEW_ISIN.RData") 

df <- eikon.acc[ , c(1,2,3,11)]
df <- df[order(df$Date, df$ISIN), ]

# Only one metric value per month -------------------------------------------#
df <- df[complete.cases(df), ]

num <- aggregate(df$ISIN, list(df$Date.aux, df$ISIN), length)

# We take the most recent observation in a given month:
df <- df[order(df$ISIN, df$Date), ]
df$row <- 1:nrow(df)
rows <- aggregate(df$row, list(df$Date.aux, df$ISIN), max)
df <- df[rows$x, ]
df$row <- NULL

# Remove actual trading-date, as we only need end-of-month date: 
df$Date <- df$Date.aux
df$Date.aux <- NULL



df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)

roe.eikon <- df

## Merge EIKON data and Bors data ---------------------------------------------#

roe2 <- merge(roe.eikon, roe.bors, by = c("Date", "ISIN"), all = TRUE)
colnames(roe2) <- c("Date", "ISIN", "EIKON", "Bors")

roe2$merged <- ifelse(is.na(roe2$EIKON), roe2$Bors, roe2$EIKON)
roe2 <- roe2[ , c(1,2,5)]
colnames(roe2) <- c("Date", "ISIN", "R")

save(roe2, file = "roe-merged.RData")

rm(list=ls())


## Wide format ----------------------------------------------------------------#
load("roe-merged.RData")


df <- roe2
df <- df[order(df$Date, df$ISIN), ]


## Wide format --------------------------------------------------------------#

df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
#df <- df[df$R >= 0, ]                   # Remove negative revenues

w.df <- reshape(df[, c("Date", "ISIN", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "ISIN", 
                direction = "wide")

w.df <- w.df[order(w.df$Date), ]


# Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#

months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

months <- as.data.frame(months)
colnames(months) <- "Date"

w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)

## Last Observation Carried Forward  (since quarterly data) -----------------#

# We only have quarterly updates of accounting values, but we want to rebalance 
# our portfolio monthly. Therefore, we carry forward the last accounting
# observation maximum 12 months. If there is a new updated observation within
# this timeframe, the value will update. 
# Thus, making the accounting-number "relevant" for max one year.

w.df.locf <- w.df
relevant <- 12  # How many months a metric is relevant

for (i in 2:ncol(w.df.locf)) {
  x <- w.df.locf[ , i]
  l <- cumsum(! is.na(x))
  y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
  w.df.locf[ , i] <- y
}


w.df[300:320,340:343]
w.df.locf[300:320,340:343]

ROE <- w.df.locf

# Replace old ROE-file in directory
save(ROE, file = "ROE.RData")





## 10.0 - Revenue 1990-2020 -----------------------------------------------------

load("eikonaccNEW_ISIN.RData") 

df <- eikon.acc[ , c(1,2,3,19)]
df <- df[order(df$Date, df$ISIN), ]


# Only one metric value per month -------------------------------------------#
df <- df[complete.cases(df), ]

num <- aggregate(df$ISIN, list(df$Date.aux, df$ISIN), length)

# We take the most recent observation in a given month:
df <- df[order(df$ISIN, df$Date), ]
df$row <- 1:nrow(df)
rows <- aggregate(df$row, list(df$Date.aux, df$ISIN), max)
df <- df[rows$x, ]
df$row <- NULL

# Remove actual trading-date, as we only need end-of-month date: 
df$Date <- df$Date.aux
df$Date.aux <- NULL

## Wide format --------------------------------------------------------------#

df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
df <- df[df$R >= 0, ]                   # Remove negative revenues

w.df <- reshape(df[, c("Date", "ISIN", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "ISIN", 
                direction = "wide")

w.df <- w.df[order(w.df$Date), ]


# Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#

months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

months <- as.data.frame(months)
colnames(months) <- "Date"

w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)

## Last Observation Carried Forward  (since quarterly data) -----------------#

# We only have quarterly updates of accounting values, but we want to rebalance 
# our portfolio monthly. Therefore, we carry forward the last accounting
# observation maximum 12 months. If there is a new updated observation within
# this timeframe, the value will update. 
# Thus, making the accounting-number "relevant" for max one year.

w.df.locf <- w.df
relevant <- 12  # How many months a metric is relevant

for (i in 2:ncol(w.df.locf)) {
  x <- w.df.locf[ , i]
  l <- cumsum(! is.na(x))
  y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
  w.df.locf[ , i] <- y
}


w.df[300:320,340:343]
w.df.locf[300:320,340:343]

w.revenue <- w.df.locf
save(w.revenue, file = "revenue-90-20.RData")



rm(list = ls())


## END

## 10.1 - Revenue 1990-2020 (EIKON + Borsprosjektet) ----------------------------

#load("eikonaccNEW_ISIN.RData") 
#df <- eikon.acc[ , c(1,2,3,19)]

load("revenue-merged.RData")
df <- revenue2
df <- df[order(df$Date, df$ISIN), ]


# Only one metric value per month -------------------------------------------#
df <- df[complete.cases(df), ]

num <- aggregate(df$ISIN, list(df$Date, df$ISIN), length)

# We take the most recent observation in a given month:
df <- df[order(df$ISIN, df$Date), ]
df$row <- 1:nrow(df)
rows <- aggregate(df$row, list(df$Date, df$ISIN), max)
df <- df[rows$x, ]
df$row <- NULL

## Wide format --------------------------------------------------------------#

df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
df <- df[df$R >= 0, ]                   # Remove negative revenues

w.df <- reshape(df[, c("Date", "ISIN", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "ISIN", 
                direction = "wide")

w.df <- w.df[order(w.df$Date), ]


# Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#

months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

months <- as.data.frame(months)
colnames(months) <- "Date"

w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)

## Last Observation Carried Forward  (since quarterly data) -----------------#

# We only have quarterly updates of accounting values, but we want to rebalance 
# our portfolio monthly. Therefore, we carry forward the last accounting
# observation maximum 12 months. If there is a new updated observation within
# this timeframe, the value will update. 
# Thus, making the accounting-number "relevant" for max one year.

w.df.locf <- w.df
relevant <- 12  # How many months a metric is relevant

for (i in 2:ncol(w.df.locf)) {
  x <- w.df.locf[ , i]
  l <- cumsum(! is.na(x))
  y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
  w.df.locf[ , i] <- y
}


w.df[300:320,340:343]
w.df.locf[300:320,340:343]

w.revenue <- w.df.locf
save(w.revenue, file = "revenue-90-20.RData")



rm(list = ls())


## END

## 10.2 - Calculate Price / Sales ratio ----------------------------------------


# Market cap
load("stocksMktCap.RData")


stocks$MarketCap <- stocks$Generic * stocks$SharesIssued/1e+06

stocks <- stocks[ , c(1,2,8)]


# Revenue 
load("revenue-merged.RData")
df <- revenue2
df <- df[order(df$Date, df$ISIN), ]


# Only one metric value per month 
df <- df[complete.cases(df), ]

num <- aggregate(df$ISIN, list(df$Date, df$ISIN), length)

# We take the most recent observation in a given month:
df <- df[order(df$ISIN, df$Date), ]
df$row <- 1:nrow(df)
rows <- aggregate(df$row, list(df$Date, df$ISIN), max)
df <- df[rows$x, ]
df$row <- NULL


df <- df[order(df$Date, df$ISIN), ]

## Merge
mktcap <- stocks[order(stocks$Date, stocks$ISIN), ]
revenue <- df[order(df$Date, df$ISIN), ]

merged <- merge(mktcap, revenue)
merged <- merged[order(merged$Date, merged$ISIN), ]

merged[merged == 0] <- NA
merged <- merged[complete.cases(merged),]

merged$R <- merged$R / 1e+06
merged$P_S <- merged$MarketCap / merged$R

merged <- merged[order(merged$Date, merged$ISIN), ]

#summary(merged$P_S)


## Wide format --------------------------------------------------------------#
df <- merged[ , c(1,2,5)]


df <- df[order(df$ISIN, df$Date), ]
colnames(df) <- c("Date", "ISIN", "R")
df <- as.data.frame(df)
df <- df[df$R >= 0, ]                   # Remove negative revenues

w.df <- reshape(df[, c("Date", "ISIN", "R")],
                v.names = "R", 
                idvar = "Date", 
                timevar = "ISIN", 
                direction = "wide")

w.df <- w.df[order(w.df$Date), ]


# Fill out date frequency - ensure rows are from 1990-01-31 to 2020-12-31 ---#

months <- seq(as.Date("1990-02-01"), as.Date("2021-01-01"), by = "1 month")
months <- months - 1

months <- as.data.frame(months)
colnames(months) <- "Date"

w.df <- merge(w.df, months, by.x = "Date", by.y = "Date", all.x = T, all.y = T)

## Last Observation Carried Forward  (since quarterly data) -----------------#

# We only have quarterly updates of accounting values, but we want to rebalance 
# our portfolio monthly. Therefore, we carry forward the last accounting
# observation maximum 12 months. If there is a new updated observation within
# this timeframe, the value will update. 
# Thus, making the accounting-number "relevant" for max one year.

w.df.locf <- w.df
relevant <- 12  # How many months a metric is relevant

for (i in 2:ncol(w.df.locf)) {
  x <- w.df.locf[ , i]
  l <- cumsum(! is.na(x))
  y <- c(NA, x[! is.na(x)])[replace(l, ave(l, l, FUN=seq_along) > relevant, 0) + 1]
  w.df.locf[ , i] <- y
}


w.df[300:320,340:343]
w.df.locf[300:320,340:343]

P_S <- w.df.locf


save(P_S, file = "P_S.RData")

rm(list = ls())



## END

## 11.0 - GICS: Sector classification ------------------------------------------

gics <- fread("https://ba-odegaard.no/wps/empirics_ose_basics/industries_company_list.txt")
gics <- as.data.frame(gics)
colnames(gics) <- c("OBI_code", "orgNr", "FirstYear", "LastYear", "gics", "FirstName", "LastName")

gics$gicsDescription <- gics$gics
gics$gicsDescription <- gics$gicsDescription %>% 
  replace(., . == 10, "Energy") %>% 
  replace(., . == 15, "Materials") %>% 
  replace(., . == 20, "Industrials") %>% 
  replace(., . == 25, "ConsumerDiscretionary") %>% 
  replace(., . == 30, "ConsumerStaples") %>% 
  replace(., . == 35, "HealthCare") %>% 
  replace(., . == 40, "Financials") %>% 
  replace(., . == 45, "InformationTechnology") %>% 
  replace(., . == 50, "TelecommunicationServices") %>% 
  replace(., . == 55, "Utilities") %>% 
  replace(., . == 60, "RealEstate") 

gics <- filter(gics, LastYear >= 2000)  # Only stocks listed 2000 or later

# Companies have multiple gics (different years, i.e., Norsk Hydro)
n_occur <- data.frame(table(gics$OBI_code))
n_occur[n_occur$Freq > 1,]
duplicated <- gics[gics$OBI_code %in% n_occur$Var1[n_occur$Freq > 1],]


# Add ISIN to list, and make wide ---------------------------------------------#
load("stocks.all.fixed.isin.RData")

stocks <- stocks[ , c(4, 10)]
stocks <- unique.data.frame(stocks)

colnames(gics)[1] <- "CompanyId"

gics2 <- merge(gics, stocks, all.y = TRUE)  # Keep all ISIN from Børs

gics <- gics2
gics$orgNr <- NULL
gics <- gics[ , c(8, 2, 3, 4, 7)]

# Fill NAs with values for "Unkown" sector
gics[c("FirstYear")][is.na(gics[c("FirstYear")])] <- 1980
gics[c("LastYear")][is.na(gics[c("LastYear")])] <- 2020
gics[c("gics")][is.na(gics[c("gics")])] <- 0
gics[c("gicsDescription")][is.na(gics[c("gicsDescription")])] <- "Unknown"


gics[c("FirstYear")][gics[c("FirstYear")] < 2000] <- 2000  # Do not need from 1980

# Fill out dates: 
gics$StartDate <- as.Date(ISOdate(gics$FirstYear, 1, 1))

gics$LastYear <- gics$LastYear + 1
gics$EndDate <- as.Date(ISOdate(gics$LastYear, 1, 1))

test <- gics %>% 
  rowwise() %>%
  do(data.frame(ISIN=.$ISIN, 
                FirstYear=.$FirstYear, 
                LastYear=.$LastYear,
                gics=.$gics,
                gicsDescription=.$gicsDescription,
                StartDate=.$StartDate,
                EndDate=.$EndDate,
                month=seq(.$StartDate,.$EndDate, by = "1 month")))


test$month2 <- test$month - 1
test$month2 <- as.Date(test$month2, format = "%Y-%m-%d")
test <- as.data.frame(test)

gics <- test[ , c(9, 1, 4, 5)]
colnames(gics) <- c("Date", "ISIN", "gics", "R")


gics <- gics[order(gics$ISIN, gics$Date), ]
w.gics <- reshape(gics[, c("Date", "ISIN", "R")],
                  v.names = "R", 
                  idvar = "Date", 
                  timevar = "ISIN",
                  direction = "wide")

w.gics <- w.gics[order(w.gics$Date), ]
w.gics[1:20, 1:4]
w.gics[240:253, 1:4]

w.gics <- w.gics[12:nrow(w.gics), ]

rownames(w.gics) <- seq(length = nrow(w.gics))

# Check to se if ISIN with GICS is in return data
load("stocks-90-20.RData")
w.stocks <- w.stocks[131:nrow(w.stocks), ]

stocks.gics <- colnames(w.gics)
stocks.stocks <- colnames(w.stocks)

setdiff(stocks.stocks, stocks.gics)  # No stocks left out! Great. 
remove <- setdiff(stocks.gics, stocks.stocks)

w.gics <- w.gics[ , !(names(w.gics) %in% remove)]

# Replace each NA with "Unknown"
w.gics[is.na(w.gics)] <- "Unknown"

save(w.gics, file = "gics.RData")



## END

## 11.1 - Plot GICS indicies ---------------------------------------------------

## Format data:

load("Indicies2.RData")
gicsDescription <- c("Energy", "Materials", "Industrials", "ConsumerDiscretionary",
                     "ConsumerStaples", "HealthCare", "Financials", 
                     "InformationTechnology", "TelecommunicationServices", 
                     "Utilities", "RealEstate", "OSEBX")

colnames(w.ix)[2:13] <- gicsDescription

w.ix <- w.ix[60:nrow(w.ix), ]
w.ix <- w.ix[ , c(1, 13, 2:12)]
w.ix[1, 2:12] <- 0
rownames(w.ix) <- seq(length = nrow(w.ix))
w.ix[190, 13] <- 0

realEstate <- w.ix[ , c(1,13)]
realEstate <- realEstate[complete.cases(realEstate), ]
realEstate$RealEstate <- 100 * cumprod(1 + realEstate$RealEstate)

w.ix <- w.ix[ , -c(13)]
w.ix[ , 2:12] <- 100 * cumprod(1 + w.ix[ , 2:12])

w.ix <- merge(w.ix, realEstate, all.x = TRUE)


## Plotting -------------------------------------------------------------------#

firstdate <- w.ix[1,1]
lastdate <- w.ix[nrow(w.ix),1]
r.axis <- as.numeric(as.vector(w.ix[nrow(w.ix), 2:13]))
r.axis <- round(r.axis, 2)


ColName <- colnames(w.ix)[2:13]
ColCol  <- c("#1a1a1a","#67001f","#b2182b","#d6604d","#f4a582","#fddbc7",
             "#d1e5f0","#92c5de","#4393c3","#2166ac","#053061", "#011c3b")


df_long = reshape2::melt(w.ix, id.vars="Date")
df_long <- df_long %>% mutate_if(is.numeric, ~round(., 2))

data_starts <- df_long %>% filter(Date == as.Date("2000-11-30", format = "%Y-%m-%d"))
data_ends <- df_long %>% filter(Date == as.Date("2020-11-30", format = "%Y-%m-%d"))


theme_set(theme_classic() +
            theme(text = element_text(family = "LM Roman 10", face = "plain"),
                  #plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,20,0), face = "bold"),
                  #plot.subtitle = element_text(size=8, hjust=0, margin=margin(1,0,0,0)),
                  #plot.caption  = element_text(size=20, hjust=0, margin=margin(3,0,0,0), face = "italic"),
                  panel.background = element_rect(fill = "white"),
                  plot.background = element_rect(fill = "white"),
                  plot.margin = margin(30, 100, 30, 30),  # top, right, bottom, left
                  axis.text = element_text(color = "black", size = 30),
                  axis.title = element_text(color = "black", size = 30, face = "bold"),
                  legend.justification = c(0.01, 1), 
                  legend.position = c(0.01, 1),
                  #legend.position = "right",
                  #legend.position = c(0.1, 0.85),
                  #legend.direction = "vertical",
                  #legend.justification = c(1, 1),
                  legend.title=element_blank(),
                  legend.text = element_text(colour="black", size = 30, margin=margin(0,0,0,0)),
                  legend.background = element_rect(fill="white", size=2, linetype="dotted")))



ggplot(df_long, aes(x = Date, y = value, group = variable)) +
  scale_colour_manual("", breaks = ColName, values = ColCol) +
  scale_y_continuous(breaks = seq(100, 3400, by = 300)) + 
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01,0)) +
  coord_cartesian(xlim = as.Date(c("2000-01-30", "2021-01-30")), clip = "off") +
  labs(title = "", x = "Time", y = "Value", color = "Legend") +
  geom_line(aes(color = variable), size = 2) +
  geom_point(data = data_starts, aes(x = Date, y = value), col = "black", 
             shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
  geom_point(data = data_ends, aes(x = Date, y = value), col = "black", 
             shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
  guides(color = guide_legend(override.aes = list(size = 7) ) ) +
  geom_text_repel(aes(label = value, family = "LM Roman 10"), 
                  data = data_ends,
                  size = 10,
                  direction = "y", 
                  hjust = 0, 
                  segment.size = 1,
                  na.rm = TRUE,
                  xlim = as.Date(c("2021-03-30", "2027-11-30"))) 
   
## Plotting without utilities -------------------------------------------------#

w.ix <- w.ix[ , -c(12)]

firstdate <- w.ix[1,1]
lastdate <- w.ix[nrow(w.ix),1]
r.axis <- as.numeric(as.vector(w.ix[nrow(w.ix), 2:12]))
r.axis <- round(r.axis, 2)


ColName <- colnames(w.ix)[2:12]
ColCol  <- c("#1a1a1a","#67001f","#b2182b","#d6604d","#f4a582","#fddbc7",
             "#d1e5f0","#92c5de","#4393c3","#2166ac","#053061")


df_long = reshape2::melt(w.ix, id.vars="Date")
df_long <- df_long %>% mutate_if(is.numeric, ~round(., 2))

data_starts <- df_long %>% filter(Date == as.Date("2000-11-30", format = "%Y-%m-%d"))
data_ends <- df_long %>% filter(Date == as.Date("2020-11-30", format = "%Y-%m-%d"))


theme_set(theme_classic() +
            theme(text = element_text(family = "LM Roman 10", face = "plain"),
                  #plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,20,0), face = "bold"),
                  #plot.subtitle = element_text(size=8, hjust=0, margin=margin(1,0,0,0)),
                  #plot.caption  = element_text(size=20, hjust=0, margin=margin(3,0,0,0), face = "italic"),
                  panel.background = element_rect(fill = "white"),
                  plot.background = element_rect(fill = "white"),
                  plot.margin = margin(30, 100, 30, 30),  # top, right, bottom, left
                  axis.text = element_text(color = "black", size = 30),
                  axis.title = element_text(color = "black", size = 30, face = "bold"),
                  legend.justification = c(0.01, 1), 
                  legend.position = c(0.01, 1),
                  #legend.position = "right",
                  #legend.position = c(0.1, 0.85),
                  #legend.direction = "vertical",
                  #legend.justification = c(1, 1),
                  legend.title=element_blank(),
                  legend.text = element_text(colour="black", size = 30, margin=margin(0,0,0,0)),
                  legend.background = element_rect(fill="white", size=2, linetype="dotted")))



ggplot(df_long, aes(x = Date, y = value, group = variable)) +
  scale_colour_manual("", breaks = ColName, values = ColCol) +
  scale_y_continuous(breaks = seq(100, 3400, by = 300)) + 
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01,0)) +
  coord_cartesian(xlim = as.Date(c("2000-01-30", "2021-01-30")), clip = "off") +
  labs(title = "", x = "Time", y = "Value", color = "Legend") +
  geom_line(aes(color = variable), size = 2) +
  geom_point(data = data_starts, aes(x = Date, y = value), col = "black", 
             shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
  geom_point(data = data_ends, aes(x = Date, y = value), col = "black", 
             shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
  guides(color = guide_legend(override.aes = list(size = 7) ) ) +
  geom_text_repel(aes(label = value, family = "LM Roman 10"), 
                  data = data_ends,
                  size = 10,
                  direction = "y", 
                  hjust = 0, 
                  segment.size = 1,
                  na.rm = TRUE,
                  xlim = as.Date(c("2021-03-30", "2027-11-30"))) 




##

## 11.2 - GICS proportion over time --------------------------------------------


gicsmkt <- read.csv("industry_market_values_monthly.csv", header = TRUE, sep = ";", dec = ".", skip = 1)
colnames(gicsmkt) <- c("Date", "Energy", "Materials", "Industrials", "ConsumerDiscretionary", 
                       "ConsumerStaples", "HealthCare", "Financials", "IT", "Telecom", "Utilities")
#Sys.setlocale("LC_TIME",'us')
gicsmkt$Date <- as.Date(gicsmkt$Date, format = " %d %b %Y ")

gicsmkt <- filter(gicsmkt, Date >= "2000-01-31")
gicsmkt[2:ncol(gicsmkt)] <- gicsmkt[2:ncol(gicsmkt)] / 1e6
gicsmkt[2:ncol(gicsmkt)] <- gicsmkt[2:ncol(gicsmkt)]/rowSums(gicsmkt[,2:ncol(gicsmkt)])


# Porportion over time ------------------------------------------------------#
ColCol  <- c("#67001f","#053061","#d6604d","#4393c3","#fddbc7",
             "#d1e5f0","#92c5de","#f4a582","#2166ac","#b2182b", "#011c3b")


df.long <- reshape2::melt(gicsmkt, id.vars = "Date")


ggplot(df.long, aes(x = Date, y = value, fill = variable)) +
  labs(title = "",
       x = "Time", y = "Proportion", color = "Legend") +
  geom_area(alpha = 0.6 , size = 1, colour = "black") + 
  scale_fill_manual(values = ColCol) + 
  scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
  theme_classic() +
  theme(
    text = element_text(family = "LM Roman 10", face="plain"),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(30, 30, 30, 30),  # top,right,bottmo,left
    axis.text = element_text(color = "black", size = 30),
    axis.title = element_text(color = "black", size = 30, face = "bold"),
    legend.title=element_blank(),
    legend.text = element_text(colour="black", size = 30, margin=margin(0,0,0,0)),
    legend.background = element_rect(fill="white", size=2, linetype="dotted"),
    legend.position = "top",
    strip.text.y = element_text(size = 30, color = "black", face = "bold"))


## END



## 12.0 - Which metrics have enough values? ------------------------------------


#  Inside function: 
x = 10
t.cost = 0.0144
accountingValue = 7
high_low = "highest"
l.axis = 100


load("KeyMetrics.RData")
load("weighting.RData")  # Dates
load("stocks-90-20.RData")
load("mktcap-90-20.RData")
load("revenue-90-20.RData")

# Dates from 2000-11-30 to 2020-12-31
w.stocks <- w.stocks[12:nrow(w.stocks), ]
w.mktcap <- w.mktcap[12:nrow(w.mktcap), ]
w.revenue <- w.revenue[12:nrow(w.revenue), ]
weighting <- weighting[13:nrow(weighting), , drop = FALSE]



for (j in 1:29) {
  
  load(paste0(KeyMetrics[j], ".RData"))
  name <- KeyMetrics[j]
  KeyMet <- get(name)
  KeyMet <- KeyMet[12:nrow(KeyMet), ]
  
  # Values to record for backtesting --------------------------------------------#
  
  m <- c()  
  
    
    for (i in 2:nrow(w.stocks)) {
      
      # Which stocks to invest in at month i ------------------------------------#
      
      # Ensure stock at month i is listed
      stock.i <- w.stocks[i, ]
      stock.i <- stock.i[ , colSums(is.na(stock.i)) == 0]
      listed <- colnames(stock.i[ ,-1])  # And remove date
      
      # Ensure stock has MarketCap-data, for weighting
      mktcap.i <- w.mktcap[i, ]
      mktcap.i <- mktcap.i[ , colSums(is.na(mktcap.i)) == 0, drop = FALSE]
      mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% listed, drop = FALSE]
      mktcap.ok <- colnames(mktcap.i)
      
      # Ensure stock has Revenue-data, for weighting
      revenue.i <- w.revenue[i, ]
      revenue.i <- revenue.i[ , colSums(is.na(revenue.i)) == 0, drop = FALSE]
      revenue.i <- revenue.i[ , colnames(revenue.i) %in% mktcap.ok, drop = FALSE]
      rev.ok <- colnames(revenue.i)
      
      # Extract non-NA values from metric at last month, filter with above
      metric.i <- KeyMet[i-1, ]
      metric.i <- metric.i[ , colSums(is.na(metric.i)) == 0, drop = FALSE]
      metric.i <- metric.i[ , colnames(metric.i) %in% rev.ok, drop = FALSE]
      
      l <- length(metric.i) # How many possible stocks at month i
      m <- c(m, l)
    
  }
  
  weighting$m <- m
  colnames(weighting)[ncol(weighting)] <- name
  
  print(j)
}


## Order columns by mean:
mns <- colMeans(weighting[ , 2:30], na.rm=TRUE)
mns <- order(mns, decreasing = TRUE) + 1
weighting <- weighting[ , c(1, mns)]

save(weighting, file = "metricsGO.RData")

load("metricsGO.RData")

ColName <- colnames(weighting)[2:30]
ColCol  <- c("#1a1a1a","#67001f","#b2182b","#d6604d","#fddbc7",
             "#f7f7f7","#d1e5f0","#92c5de","#2166ac","#053061",
             "#1a1a1a","#67001f","#b2182b","#d6604d","#fddbc7",
             "#f7f7f7","#d1e5f0","#92c5de","#2166ac","#053061",
             "#1a1a1a","#67001f","#b2182b","#d6604d","#fddbc7",
             "#f7f7f7","#d1e5f0","#2166ac","#053061")


#*#*#*#*#*#**#*#*#*#*#*#*##*#**#*#*#*##*#*#*#*#**##**##*#**#*#*##***#*#*
# 
# df1 <- reshape2::melt(weighting[ , c(1, 2:10)], id.vars = "Date")
# df1$sort <- "first"
# df2 <- reshape2::melt(weighting[ , c(1, 11:20)], id.vars = "Date")
# df2$sort <- "seond"
# df3 <- reshape2::melt(weighting[ , c(1, 21:30)], id.vars = "Date")
# df3$sort <- "third"
# 
# df <- rbind(df1, df2, df3)
# 
# 
# ggplot(df, aes(x = Date, y = value, fill = variable)) +
#   labs(title = "Metrics found each month",
#        x = "", y = "", color = "Legend") +
#   geom_line(aes(colour = variable, group = variable), size = 1.5) + 
#   scale_color_manual(values = ColCol) + 
#   scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
#   theme_classic() +
#   theme(
#     text = element_text(family = "Times New Roman", face="plain"),
#     plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,20,0), face = "bold"),
#     panel.background = element_rect(fill = "gray95"),
#     plot.background = element_rect(fill = "gray95"),
#     plot.margin = margin(30, 30, 30, 30),  # top,right,bottmo,left
#     axis.text = element_text(color = "black", size = 10),
#     axis.title = element_text(color = "black", size = 10, face = "bold"),
#     legend.title=element_blank(),
#     legend.text = element_text(colour="black", size = 10, margin=margin(0,0,0,0)),
#     legend.background = element_rect(fill="gray95", size=2, linetype="dotted"),
#     strip.text.y = element_text(size = 10, color = "black", face = "bold")) +
#   facet_grid(sort ~ .)
# 


#*#*#*#*#*#*#*#*#*##**#*#*#*##**##**#*#*#*#*#*#*#**#*#*#*#*#*#*##**##*#*

cbp2 <- c("#67001f","#b2182b","#d6604d","#1a1a1a","#fddbc7",
          "#053061","#4393c3","#542788","#b2abd2","#b35806")

melted1 = reshape2::melt(weighting[ , c(1, 2:10)], id.vars="Date")
melted2 = reshape2::melt(weighting[ , c(1, 11:20)], id.vars="Date")
melted3 = reshape2::melt(weighting[ , c(1, 21:30)], id.vars="Date")

g1 <- ggplot(melted1, aes(x = Date, y = value)) + 
  scale_x_date(date_breaks = "2 years", date_labels = "%y", expand = c(0.01,0)) + 
  scale_y_continuous(breaks = seq(0, 250, by = 50)) + 
  geom_hline(yintercept= c(50,100,150,200,250), color = "gray80", size=0.5)+
  coord_cartesian(ylim=c(0,250)) +
  geom_line(aes(colour = variable, group = variable), size = 1.5) +
  scale_color_manual(values = cbp2, name = "Accounting metric") +
  theme(legend.position = "bottom") +
  labs(title="", x ="", y = "") + 
  theme_classic() +
  theme(
    text = element_text(family = "LM Roman 10", face="plain"),
    #plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,20,0), face = "bold"),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 10, 10, 10),  # top,right,bottmo,left
    axis.text = element_text(color = "black", size = 30),
    axis.title = element_text(color = "black", size = 30, face = "bold"),
    legend.title=element_blank(),
    legend.text = element_text(colour="black", size = 30 ),
    legend.background = element_rect(fill="white", size=2, linetype="dotted"))
  
  
g2 <- ggplot(melted2, aes(x = Date, y = value)) + 
  
  scale_x_date(date_breaks = "2 years", date_labels = "%y", expand = c(0.01,0)) + 
  scale_y_continuous(breaks = seq(0, 250, by = 50)) + 
  geom_hline(yintercept= c(50,100,150,200,250), color = "gray80", size=0.5)+
  coord_cartesian(ylim=c(0,250)) +
  geom_line(aes(colour = variable, group = variable), size = 1.5) +
  scale_color_manual(values = cbp2, name = "Accounting metric") +
  theme(legend.position = "bottom") +
  labs(title="", x ="", y = "Number of metrics") + 
  theme_classic() +
  theme(
    text = element_text(family = "LM Roman 10", face="plain"),
    #plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,20,0), face = "bold"),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 10, 10, 10),  # top,right,bottmo,left
    axis.text = element_text(color = "black", size = 30),
    axis.title = element_text(color = "black", size = 30, face = "bold"),
    legend.title=element_blank(),
    legend.text = element_text(colour="black", size = 30),
    legend.background = element_rect(fill="white", size=2, linetype="dotted"))

g3 <- ggplot(melted3, aes(x = Date, y = value)) + 
  scale_x_date(date_breaks = "2 years", date_labels = "%y", expand = c(0.01,0)) + 
  scale_y_continuous(breaks = seq(0, 250, by = 50)) + 
  geom_hline(yintercept= c(50,100,150,200,250), color = "gray80", size=0.5)+
  coord_cartesian(ylim=c(0,250)) +
  geom_line(aes(colour = variable, group = variable), size = 1.5) +
  scale_color_manual(values = cbp2, name = "Accounting metric") +
  theme(legend.position = "bottom") +
  labs(title="", x ="Time", y = "") + 
  theme_classic() +
  theme(
    text = element_text(family = "LM Roman 10", face="plain"),
    #plot.title    = element_text(size=40, hjust=0, margin=margin(0,0,0,0), face = "bold"),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 10, 10, 10),  # top,right,bottmo,left
    axis.text = element_text(color = "black", size = 30),
    axis.title = element_text(color = "black", size = 30, face = "bold"),
    legend.title=element_blank(),
    legend.text = element_text(colour="black", size = 30),
    legend.background = element_rect(fill="white", size=2, linetype="dotted"))

g.equal <- ggarrange(g1, g2, g3, ncol = 1, nrow = 3)
g.equal





##

## 13.0 - Backtest 3 weightings with Gics------------------------------------------------

## Inside function: 
# x = 10
# t.cost = 0.02
# accountingValue = 7
# high_low = "highest"
# l.axis = 100
# DATE1 = "2000-11-30"
# DATE2 = "2020-11-30"


## Function
# x = number of stocks to pick each month
# t.cost = transaction cost
# accounting value = which accounting value
# high_low = invest in top or bottom based on accounting value
# DATE1 = start date of backtest
# DATE2 = end date of backtest

backtest <- function(x, t.cost, accountingValue, high_low, l.axis, DATE1, DATE2) {
  
  # Load accounting data
  load("KeyMetrics.RData")
  load(paste0(KeyMetrics[accountingValue], ".RData"))
  name <- KeyMetrics[accountingValue]
  KeyMet <- get(name)
  
  # Load other data
  load("stocks-90-20.RData")
  load("mktcap-90-20.RData")
  load("revenue-90-20.RData")
  load("gics.RData")
  
  
  # Align dates
  KeyMet <- filter(KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.stocks <- filter(w.stocks, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.mktcap <- filter(w.mktcap, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.revenue <- filter(w.revenue, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.gics <- filter(w.gics, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))

  
  # Values to record for backtesting --------------------------------------------#
  r.equal <- c(0)    # Return series: The return that month
  r.mktcap <- c(0)
  r.rev <- c(0)
  t <- c(0)          # Transaction series: Number of transactions that month
  p <- c(0)          # Portfolio series: Number of stocks held that month
  p.lm <- c()        # Which stocks in portfolio, last month
  m <- c(0)          # Number of listed stocks that have metrics each month 
  
  e.gic0  <- c(0)
  e.gic10 <- c(0)
  e.gic15 <- c(0)
  e.gic20 <- c(0)
  e.gic25 <- c(0)
  e.gic30 <- c(0)
  e.gic35 <- c(0)
  e.gic40 <- c(0)
  e.gic45 <- c(0)
  e.gic50 <- c(0)
  e.gic55 <- c(0)
  e.gic60 <- c(0)
  
  m.gic0  <- c(0)
  m.gic10 <- c(0)
  m.gic15 <- c(0)
  m.gic20 <- c(0)
  m.gic25 <- c(0)
  m.gic30 <- c(0)
  m.gic35 <- c(0)
  m.gic40 <- c(0)
  m.gic45 <- c(0)
  m.gic50 <- c(0)
  m.gic55 <- c(0)
  m.gic60 <- c(0)
  
  r.gic0  <- c(0)
  r.gic10 <- c(0)
  r.gic15 <- c(0)
  r.gic20 <- c(0)
  r.gic25 <- c(0)
  r.gic30 <- c(0)
  r.gic35 <- c(0)
  r.gic40 <- c(0)
  r.gic45 <- c(0)
  r.gic50 <- c(0)
  r.gic55 <- c(0)
  r.gic60 <- c(0)
  
  #i <- 2
  #for (i in 2:201) {
  
  for (i in 2:nrow(w.stocks)) {
    
    # Which stocks to invest in at month i ------------------------------------#
    
    # Ensure stock at month i is listed
    stock.i <- w.stocks[i, ]
    stock.i <- stock.i[ , colSums(is.na(stock.i)) == 0]
    listed <- colnames(stock.i[ ,-1])  # And remove date
    
    # Ensure stock has MarketCap-data, for weighting
    mktcap.i <- w.mktcap[i, ]
    mktcap.i <- mktcap.i[ , colSums(is.na(mktcap.i)) == 0, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% listed, drop = FALSE]
    mktcap.ok <- colnames(mktcap.i)
    
    # Ensure stock has Revenue-data, for weighting
    revenue.i <- w.revenue[i, ]
    revenue.i <- revenue.i[ , colSums(is.na(revenue.i)) == 0, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% mktcap.ok, drop = FALSE]
    rev.ok <- colnames(revenue.i)
    
    # Extract non-NA values from metric at last month, filter with above
    metric.i <- KeyMet[i-1, ]
    metric.i <- metric.i[ , colSums(is.na(metric.i)) == 0, drop = FALSE]
    metric.i <- metric.i[ , colnames(metric.i) %in% rev.ok, drop = FALSE]
    
    l <- length(metric.i) # How many possible stocks at month i
    m <- c(m, l)
    
    # Choose top or bottom x stocks?
    if (high_low == "highest") {
      metric.i <- (metric.i[,order(-metric.i[nrow(metric.i),]), drop = FALSE])
    } else if (high_low == "lowest") {
      metric.i <- (metric.i[,order(metric.i[nrow(metric.i),]), drop = FALSE])
    }
    
    # Pick stocks to invest in, at month i
    metric.i <- metric.i[1:x]
    invest.i <- colnames(metric.i)
    p <- c(p, length(invest.i))
    
    stock.i <- stock.i[ , colnames(stock.i) %in% invest.i, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% invest.i, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% invest.i, drop = FALSE]
    
    # GICS
    gics.i <- w.gics[i, ]
    gics.i <- gics.i[ , colnames(gics.i) %in% invest.i, drop = FALSE]
    
    
    # First month -> only buy -------------------------------------------------#
    if (l > 0 && length(p.lm) == 0) {
      
      # Returns, weightings and transaction costs -----------------------------#
      #sold <- setdiff(p.lm,invest.i)
      bought <- setdiff(invest.i,p.lm)
      #hold <- intersect(p.lm,invest.i)
      t <- c(t, length(bought))
      
      # Bought
      #r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      #stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      ww.equal.bh <- 1/(length(returns))              
      p.equal <- ww.equal.bh * ( sum(returns) )
      r.equal <- c(r.equal, p.equal)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap <- sum(ww.mktcap.r * returns)
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))           
      p.rev <- sum(ww.rev.r * returns)
      r.rev <- c(r.rev, p.rev)
      
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
    # Month 2+ -> Buy, sell & hold stocks -------------------------------------#
    } else if (l > 0 && length(p.lm) > 0) {
      
      
      # Returns, weightings and transaction costs -----------------------------#
      sold <- setdiff(p.lm, invest.i)
      bought <- setdiff(invest.i, p.lm)
      hold <- intersect(p.lm, invest.i)
      t <- c(t, length(sold) + length(bought))
      
      # Adjust returns for bought:
      r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      # Returns for sold (transaction cost)
      n.sold <- length(sold)
      n.t <- c()
      for (j in 1:n.sold) {
        n.t[j] <- -t.cost
      }
      
      # Equal weighting -------------------------------------------------------#
      ww.equal.sold <- ww.equal.lm
      p.equal.sold <- ww.equal.sold * ( sum(n.t) )
      
      ww.equal.bh <- 1 / (length(returns))
      p.equal.bh <- ww.equal.bh * ( sum(returns) )
      
      p.equal <- p.equal.sold + p.equal.bh
      r.equal <- c(r.equal, p.equal)
      
      # MarketCap weighting ---------------------------------------------------#
      ww.mktcap.sold <- ww.mktcap.lm[sold]
      ww.mktcap.sold <- as.numeric(as.vector(ww.mktcap.sold[1,]))
      p.mktcap.sold <- sum( ww.mktcap.sold * n.t)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap.bh <- sum(ww.mktcap.r * returns)
      
      p.mktcap <- p.mktcap.sold + p.mktcap.bh
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      # Revenue weighting -----------------------------------------------------#
      ww.rev.sold <- ww.rev.lm[sold]
      ww.rev.sold <- as.numeric(as.vector(ww.rev.sold[1,]))
      p.rev.sold <- sum( ww.rev.sold * n.t)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))
      p.rev.bh <- sum(ww.rev.r * returns)
      
      p.rev <- p.rev.sold + p.rev.bh
      r.rev <- c(r.rev, p.rev)
      
      # Store portfolio this month, for calculation next month
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
    }
    
    ## GICS -----------------------------------------------------------------#
    
    e.gic0  <- c(e.gic0,  length(which(gics.i == "Unknown")) / 10)
    e.gic10 <- c(e.gic10, length(which(gics.i == "Energy")) / 10)
    e.gic15 <- c(e.gic15, length(which(gics.i == "Materials")) / 10)
    e.gic20 <- c(e.gic20, length(which(gics.i == "Industrials")) / 10)
    e.gic25 <- c(e.gic25, length(which(gics.i == "ConsumerDiscretionary")) / 10)
    e.gic30 <- c(e.gic30, length(which(gics.i == "ConsumerStaples")) / 10)
    e.gic35 <- c(e.gic35, length(which(gics.i == "HealthCare")) / 10)
    e.gic40 <- c(e.gic40, length(which(gics.i == "Financials")) / 10)
    e.gic45 <- c(e.gic45, length(which(gics.i == "InformationTechnology")) / 10)
    e.gic50 <- c(e.gic50, length(which(gics.i == "TelecommunicationServices")) / 10)
    e.gic55 <- c(e.gic55, length(which(gics.i == "Utilities")) / 10)
    e.gic60 <- c(e.gic60, length(which(gics.i == "RealEstate")) / 10)
    
    df3 <- rbind(gics.i, ww.mktcap.bh)
    
    m.gic0  <- c(m.gic0,  sum(as.numeric(df3[2,which(df3[1,] == "Unknown")])))
    m.gic10 <- c(m.gic10, sum(as.numeric(df3[2,which(df3[1,] == "Energy")])))
    m.gic15 <- c(m.gic15, sum(as.numeric(df3[2,which(df3[1,] == "Materials")])))
    m.gic20 <- c(m.gic20, sum(as.numeric(df3[2,which(df3[1,] == "Industrials")])))
    m.gic25 <- c(m.gic25, sum(as.numeric(df3[2,which(df3[1,] == "ConsumerDiscretionary")])))
    m.gic30 <- c(m.gic30, sum(as.numeric(df3[2,which(df3[1,] == "ConsumerStaples")])))
    m.gic35 <- c(m.gic35, sum(as.numeric(df3[2,which(df3[1,] == "HealthCare")])))
    m.gic40 <- c(m.gic40, sum(as.numeric(df3[2,which(df3[1,] == "Financials")])))
    m.gic45 <- c(m.gic45, sum(as.numeric(df3[2,which(df3[1,] == "InformationTechnology")])))
    m.gic50 <- c(m.gic50, sum(as.numeric(df3[2,which(df3[1,] == "TelecommunicationServices")])))
    m.gic55 <- c(m.gic55, sum(as.numeric(df3[2,which(df3[1,] == "Utilities")])))
    m.gic60 <- c(m.gic60, sum(as.numeric(df3[2,which(df3[1,] == "RealEstate")])))
    
    df4 <- rbind(gics.i, ww.rev.bh)
    
    r.gic0  <- c(r.gic0,  sum(as.numeric(df4[2,which(df4[1,] == "Unknown")])))
    r.gic10 <- c(r.gic10, sum(as.numeric(df4[2,which(df4[1,] == "Energy")])))
    r.gic15 <- c(r.gic15, sum(as.numeric(df4[2,which(df4[1,] == "Materials")])))
    r.gic20 <- c(r.gic20, sum(as.numeric(df4[2,which(df4[1,] == "Industrials")])))
    r.gic25 <- c(r.gic25, sum(as.numeric(df4[2,which(df4[1,] == "ConsumerDiscretionary")])))
    r.gic30 <- c(r.gic30, sum(as.numeric(df4[2,which(df4[1,] == "ConsumerStaples")])))
    r.gic35 <- c(r.gic35, sum(as.numeric(df4[2,which(df4[1,] == "HealthCare")])))
    r.gic40 <- c(r.gic40, sum(as.numeric(df4[2,which(df4[1,] == "Financials")])))
    r.gic45 <- c(r.gic45, sum(as.numeric(df4[2,which(df4[1,] == "InformationTechnology")])))
    r.gic50 <- c(r.gic50, sum(as.numeric(df4[2,which(df4[1,] == "TelecommunicationServices")])))
    r.gic55 <- c(r.gic55, sum(as.numeric(df4[2,which(df4[1,] == "Utilities")])))
    r.gic60 <- c(r.gic60, sum(as.numeric(df4[2,which(df4[1,] == "RealEstate")])))
    
    #print(i)
    
  }
  
  # Format data for plotting --------------------------------------------------#
  df.plot <- w.stocks[ , 1 , drop = FALSE]
  rownames(df.plot) <- seq(length = nrow(df.plot))
  
  df.plot$r.equal <- r.equal   # Return series of strategy
  df.plot$r.mktcap <- r.mktcap # Return series of strategy
  df.plot$r.rev <- r.rev       # Return series of strategy
  df.plot$m <- m               # Number of metrics found for strategy
  df.plot$t <- t               # Number of transactions
  df.plot$p <- p               # Number of stocks in portfolio
  
  # Add index -----------------------------------------------------------------#
  load("Indicies2.RData")
  df.plot <- merge(df.plot, w.ix[ , c(1, 13)], all.x = TRUE)
  colnames(df.plot)[ncol(df.plot)] <- "r.index"
  
  df.plot$Equal <- 100 * cumprod(1 + df.plot$r.equal)
  df.plot$MktCap <- 100 * cumprod(1 + df.plot$r.mktcap)
  df.plot$Revenue <- 100 * cumprod(1 + df.plot$r.rev)
  
  df.plot[1,8] <- 0
  df.plot$OSEBX <- 100 * cumprod(1 + df.plot$r.index)
  
  # Add risk-free -------------------------------------------------------------#
  load("Riskfree-Rate.RData")
  df.plot <- merge(df.plot, rf, all.x = TRUE) 
  
  df.plot$r.equal.excess <- df.plot$r.equal - df.plot$rf
  df.plot$r.mktcap.excess <- df.plot$r.mktcap - df.plot$rf
  df.plot$r.rev.excess <- df.plot$r.rev - df.plot$rf
  df.plot$r.index.excess <- df.plot$r.index - df.plot$rf
  
  # Fama French regression ---------------------------------------------------#
  load("FamaFrench_NO_EU.RData")
  
  df.plot.ff <- merge(df.plot[c(1:4,14:17)], famafrench, all.x = TRUE)
  df.plot.ff <- df.plot.ff[complete.cases(df.plot.ff), ]  # Non-nas for regression
  df.plot.ff <- df.plot.ff[-c(1),]
  
  # Norwegian FF3
  ff.equal.no <- lm(formula = r.equal.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)
  ff.mktcap.no <- lm(formula = r.mktcap.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)
  ff.rev.no <- lm(formula = r.rev.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)

  # European FF5
  df.plot.ff$r.equal.excess.eu <- df.plot.ff$r.equal - df.plot.ff$rf.EU
  df.plot.ff$r.mktcap.excess.eu <- df.plot.ff$r.mktcap - df.plot.ff$rf.EU
  df.plot.ff$r.rev.excess.eu <- df.plot.ff$r.rev - df.plot.ff$rf.EU
  
  ff.equal.eu <- lm(formula = r.equal.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU, data = df.plot.ff)
  ff.mktcap.eu <- lm(formula = r.mktcap.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU, data = df.plot.ff)
  ff.rev.eu <- lm(formula = r.rev.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU,data = df.plot.ff)
  
  # Format GICS data ----------------------------------------------------------#
  df.gics.equal <- w.stocks[ , 1 , drop = FALSE]
  df.gics.mktcap <- df.gics.equal
  df.gics.rev <- df.gics.equal
  
  df.gics.equal$Unknown                   <- e.gic0
  df.gics.equal$Energy                    <- e.gic10
  df.gics.equal$Materials                 <- e.gic15
  df.gics.equal$Industrials               <- e.gic20
  df.gics.equal$ConsumerDiscretionary     <- e.gic25
  df.gics.equal$ConsumerStaples           <- e.gic30
  df.gics.equal$HealthCare                <- e.gic35
  df.gics.equal$Financials                <- e.gic40
  df.gics.equal$InformationTechnology     <- e.gic45
  df.gics.equal$TelecommunicationServices <- e.gic50
  df.gics.equal$Utilities                 <- e.gic55
  df.gics.equal$RealEstate                <- e.gic60
  
  df.gics.mktcap$Unknown                   <- m.gic0
  df.gics.mktcap$Energy                    <- m.gic10
  df.gics.mktcap$Materials                 <- m.gic15
  df.gics.mktcap$Industrials               <- m.gic20
  df.gics.mktcap$ConsumerDiscretionary     <- m.gic25
  df.gics.mktcap$ConsumerStaples           <- m.gic30
  df.gics.mktcap$HealthCare                <- m.gic35
  df.gics.mktcap$Financials                <- m.gic40
  df.gics.mktcap$InformationTechnology     <- m.gic45
  df.gics.mktcap$TelecommunicationServices <- m.gic50
  df.gics.mktcap$Utilities                 <- m.gic55
  df.gics.mktcap$RealEstate                <- m.gic60
  
  df.gics.rev$Unknown                   <- r.gic0
  df.gics.rev$Energy                    <- r.gic10
  df.gics.rev$Materials                 <- r.gic15
  df.gics.rev$Industrials               <- r.gic20
  df.gics.rev$ConsumerDiscretionary     <- r.gic25
  df.gics.rev$ConsumerStaples           <- r.gic30
  df.gics.rev$HealthCare                <- r.gic35
  df.gics.rev$Financials                <- r.gic40
  df.gics.rev$InformationTechnology     <- r.gic45
  df.gics.rev$TelecommunicationServices <- r.gic50
  df.gics.rev$Utilities                 <- r.gic55
  df.gics.rev$RealEstate                <- r.gic60
  
  
  # Gather statistics ---------------------------------------------------------#
  
  # Strategy Equal
  mu.equal <- mean(df.plot$r.equal[-1]) * 12
  mu.ex.equal <- mean(df.plot$r.equal.excess[-1]) * 12
  sd.equal <- sd(df.plot$r.equal[-1]) * sqrt(12)
  sr.equal <- mu.ex.equal / sd.equal
  beta.equal <- cov(df.plot$r.equal[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy MktCap
  mu.mktcap <- mean(df.plot$r.mktcap[-1]) * 12
  mu.ex.mktcap <- mean(df.plot$r.mktcap.excess[-1]) * 12
  sd.mktcap <- sd(df.plot$r.mktcap[-1]) * sqrt(12)
  sr.mktcap <- mu.ex.mktcap / sd.mktcap
  beta.mktcap <- cov(df.plot$r.mktcap[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy Revenue
  mu.rev <- mean(df.plot$r.rev[-1]) * 12
  mu.ex.rev <- mean(df.plot$r.rev.excess[-1]) * 12
  sd.rev <- sd(df.plot$r.rev[-1]) * sqrt(12)
  sr.rev <- mu.ex.rev / sd.rev
  beta.rev <- cov(df.plot$r.rev[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  #Index
  mu.i <- mean(df.plot$r.index[-1]) * 12
  mu.ex.i <- mean(df.plot$r.index.excess[-1]) * 12
  sd.i <- sd(df.plot$r.index[-1]) * sqrt(12)
  sr.i <- mu.ex.i / sd.i
  beta.i <- cov(df.plot$r.index[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Jensen
  rf.ann <- mean(df.plot$rf[-1]) * 12
  jens.equal <- mu.equal - (rf.ann + (mu.i - rf.ann) * beta.equal)
  jens.mktcap <- mu.mktcap - (rf.ann + (mu.i - rf.ann) * beta.mktcap)
  jens.rev <- mu.rev - (rf.ann + (mu.i - rf.ann) * beta.rev)
  jens.i <- mu.i - (rf.ann + (mu.i - rf.ann) * beta.i)
  
  # Treynor
  trey.equal <- mu.ex.equal / beta.equal
  trey.mktcap <- mu.ex.mktcap / beta.mktcap
  trey.rev <- mu.ex.rev / beta.rev
  trey.i <- mu.ex.i / beta.i

  
  # Stats table
  a <- c(mu.i, sd.i, sr.i, beta.i, jens.i, trey.i)
  b <- c(mu.equal, sd.equal, sr.equal, beta.equal, jens.equal, trey.equal)
  c <- c(mu.mktcap, sd.mktcap, sr.mktcap, beta.mktcap, jens.mktcap, trey.mktcap)
  d <- c(mu.rev, sd.rev, sr.rev, beta.rev, jens.rev, trey.rev)
  stats <- data.frame(a,b,c,d)
  stats <- t(stats)
  stats <- as.data.frame(stats)
  rownames(stats) <- c("Index", "Equal","MktCap","Revenue")
  colnames(stats) <- c("Average Annual Return", "Standard Deviation", "Sharpe Ratio", "Beta", 
                       "Jensen's Alpha", "Treynor's Measure")
  stats <- stats %>% mutate_if(is.numeric, ~round(., 4))
  
  
  # Metrics, portfolio, transactions
  sum.mpt <- df.plot[-1, 6, drop = FALSE]
  sum.mpt <- do.call(cbind, lapply(sum.mpt, summary))
  sum.mpt <- t(sum.mpt)
  sum.mpt <- as.data.frame(sum.mpt)
  rownames(sum.mpt) <- c("Transactions")
  sum.mpt[, 4] <- round(sum.mpt[, 4], 2)
  sum.mpt <- cbind(sum.mpt, data.frame(Sum = sum(df.plot[ , 6])))
  
  
  # Plotting strategies over time ---------------------------------------------#
  df.plot1 <- df.plot[ , c(1,9:12)]
  
  firstdate <- df.plot1[1,1]
  lastdate <- df.plot1[nrow(df.plot1),1]
  r.axis <- as.numeric(as.vector(df.plot1[nrow(df.plot1), 2:ncol(df.plot1)]))
  r.axis <- round(r.axis, 2)
  
  ColName <- colnames(df.plot1)[2:ncol(df.plot1)]
  ColCol  <- c("#92c5de","#4393c3","#2166ac","#67001f")
  
  
  df_long = reshape2::melt(df.plot1, id.vars="Date")
  df_long <- df_long %>% mutate_if(is.numeric, ~round(., 2))
  
  data_starts <- df_long %>% filter(Date == firstdate)
  data_ends <- df_long %>% filter(Date == lastdate)
  
  roundUp <- function(x,to=100) {to*(x%/%to + as.logical(x%%to))}
  max <- roundUp(max(data_ends[ , 3]))
  
  theme_set(theme_classic() +
              theme(text = element_text(family = "LM Roman 10", face = "plain"),
                    plot.caption  = element_text(size=30, hjust=0, margin=margin(3,0,0,0), face = "plain"),
                    panel.background = element_rect(fill = "white"),
                    plot.background = element_rect(fill = "white"),
                    plot.margin = margin(30, 100, 30, 30),  # top, right, bottom, left
                    axis.text = element_text(color = "black", size = 30),
                    axis.title = element_text(color = "black", size = 30, face = "bold"),
                    legend.justification = c(0.01, 1), 
                    legend.position = c(0.01, 1),
                    legend.direction = "horizontal",
                    legend.title=element_blank(),
                    legend.text = element_text(colour="black", size = 40, margin=margin(0,0,0,0)),
                    legend.background = element_rect(fill="white", size=2, linetype="dotted")))
  
  gg <- ggplot(df_long, aes(x = Date, y = value, group = variable)) +
    scale_colour_manual("", breaks = ColName, values = ColCol) +
    scale_y_continuous(breaks = seq(100, max, by = l.axis)) + 
    scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01,0)) +
    coord_cartesian(xlim = as.Date(c("2000-10-30", "2021-01-30")), clip = "off") +
    labs(title = "", x = "Time", y = "Value", color = "Legend",
         caption = paste("*Strategy: Every month, invest in the",x,"stocks listed on OSE with the",high_low,name,
                         "\n*Transaction cost: ",100*abs(t.cost),"%")) +
    geom_line(aes(color = variable), size = 2) +
    geom_point(data = data_starts, aes(x = Date, y = value), col = "black", 
               shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
    geom_point(data = data_ends, aes(x = Date, y = value), col = "black", 
               shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
    guides(color = guide_legend(override.aes = list(size = 10) ) ) +
    geom_text_repel(aes(label = value, family = "LM Roman 10"), 
                    data = data_ends,
                    size = 10,
                    direction = "y", 
                    hjust = 0, 
                    segment.size = 1,
                    na.rm = TRUE,
                    xlim = as.Date(c("2021-03-30", "2027-11-30"))) 
  
  
  # Sector GICS illustration --------------------------------------------------#
  df.gics.equal <- df.gics.equal[ -1, , drop = FALSE]
  df.gics.mktcap <- df.gics.mktcap[ -1, , drop = FALSE]
  df.gics.rev <- df.gics.rev[ -1, , drop = FALSE]

  # Mean gics proportions over period -----------------------------------------#
  gics.equal <- colMeans(df.gics.equal[, -1])
  gics.mktcap <- colMeans(df.gics.mktcap[, -1])
  gics.rev <- colMeans(df.gics.rev[, -1])
  
  gics.mean <- data.frame(t(gics.equal))
  gics.mean <- rbind(gics.mean, gics.mktcap, gics.rev)
  gics.mean.t <- transpose(gics.mean)
  rownames(gics.mean.t) <- colnames(gics.mean)
  colnames(gics.mean.t) <- c("Equal", "MktCap", "Revenue")
  gics.mean.t <- gics.mean.t %>% mutate_if(is.numeric, ~round(., 4))
  
  # Porportion over time ------------------------------------------------------#
  ColCol  <- c("#1a1a1a","#67001f","#053061","#d6604d","#4393c3","#fddbc7",
               "#d1e5f0","#92c5de","#f4a582","#2166ac","#b2182b", "#011c3b")
  
  
  melt.gics1 <- reshape2::melt(df.gics.equal, id.vars = "Date")
  melt.gics1$weighting <- "Equal"
  melt.gics2 <- reshape2::melt(df.gics.mktcap, id.vars = "Date")
  melt.gics2$weighting <- "MktCap"
  melt.gics3 <- reshape2::melt(df.gics.rev, id.vars = "Date")
  melt.gics3$weighting <- "Revenue"
  
  melt.gics <- rbind(melt.gics1, melt.gics2, melt.gics3)
  
  
  gics.time <- ggplot(melt.gics, aes(x = Date, y = value, fill = variable)) +
    labs(title = "",
         x = "Time", y = "Proportion", color = "Legend") +
    geom_area(alpha = 0.6 , size = 1, colour = "black") + 
    scale_fill_manual(values = ColCol) + 
    scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(30, 30, 30, 30),  # top,right,bottmo,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      legend.title=element_blank(),
      legend.text = element_text(colour="black", size = 30, margin=margin(0,0,0,0)),
      legend.background = element_rect(fill="white", size=2, linetype="dotted"),
      legend.position = "top",
      strip.text.y = element_text(size = 30, color = "black", face = "bold")) +
    facet_grid(weighting ~ .)
  
  # Transactions over time ----------------------------------------------------#
  
  t.plot <- df.plot[ -c(1), c(1, 6)]
  mean <- round(mean(t.plot$t),2)
  
  t.time <- ggplot(t.plot, aes(x = Date, y = t)) +
    labs(title = "", 
         x = "Time", y = "Number of transactions") +
    geom_hline(yintercept = seq(from=2, to=20, by = 2), color = "gray80") + 
    geom_bar(stat = "identity", fill = "#4393c3", color = "#4393c3") +
    geom_hline(yintercept = mean, color = "#053061", size = 1.5) + 
    scale_y_continuous(limits = c(0,20), breaks = c(0,4,8,12,16,20), minor_breaks = c(2,6,10,14,18),
                       sec.axis = sec_axis(~ ., breaks = mean)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottmo,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y.right = element_text(color = "black", size = 30, face = "bold"),
      axis.line.y.right = element_line(color = "white"),
      axis.ticks.y.right = element_line(color = "white"))

  # Return distribution -------------------------------------------------------#
  
  r.plot <- df.plot[ -c(1), c(1:4, 8)]
  colnames(r.plot) <- c("Date", "Equal", "MktCap", "Revenue", "OSEBX")
  
  r.plot <- reshape2::melt(r.plot, id.vars = "Date")
  
  dist.vars <- ddply(r.plot, "variable", summarise, 
                     #Mode = getmode(value), 
                     #Median = median(value),
                     Mean = mean(value), 
                     Skewness = skewness(value), 
                     Kurtosis = kurtosis(value))
  dist.vars <- dist.vars %>% mutate_if(is.numeric, ~round(., 4))
  
  y.labs <- list(paste("Equal\n\nMean",dist.vars[1,2],"\nSkewness",dist.vars[1,3],"\nKurtosis",dist.vars[1,4]),
                 paste("MktCap\n\nMean",dist.vars[2,2],"\nSkewness",dist.vars[2,3],"\nKurtosis",dist.vars[2,4]),
                 paste("Revenue\n\nMean",dist.vars[3,2],"\nSkewness",dist.vars[3,3],"\nKurtosis",dist.vars[3,4]),
                 paste("OSEBX\n\nMean",dist.vars[4,2],"\nSkewness",dist.vars[4,3],"\nKurtosis",dist.vars[4,4]))
  y_labeller <- function(variable,value){
    return(y.labs[value])
  }
  
  r.dist <- ggplot(r.plot, aes(x = value, fill = variable)) + 
    labs(title = "", x = "Monthly Returns", y = "") +
    geom_density(alpha = 0.6, size = 1) +
    geom_vline(data = dist.vars, aes(xintercept = Mean), linetype = "dashed") +
    #geom_vline(data = dist.vars, aes(xintercept = Mode), linetype = "dashed") +
    #geom_vline(data = dist.vars, aes(xintercept = Median), linetype = "dashed") +
    scale_fill_manual(values = c("steelblue2", "steelblue", "steelblue4", "darkred")) +
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottom,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y = element_text(color = "white", size = 0),
      axis.line.y = element_line(color = "white"),
      axis.ticks.y = element_line(color = "white"),
      legend.position = "none", 
      strip.text.y = element_text(size = 30, color = "black", face = "bold", angle = 0),
      strip.background = element_rect(color="white", fill = "white", size=1.5, linetype="solid")) +
    facet_grid(variable ~ ., labeller = y_labeller)
  
  # Return distribution excess ------------------------------------------------#
  
  r.plot.excess <- df.plot[ -c(1), c(1:4, 8)]
  r.plot.excess$r.equal <- r.plot.excess$r.equal - r.plot.excess$r.index
  r.plot.excess$r.mktcap <- r.plot.excess$r.mktcap - r.plot.excess$r.index
  r.plot.excess$r.rev <- r.plot.excess$r.rev - r.plot.excess$r.index
  r.plot.excess$r.index <- NULL
  colnames(r.plot.excess) <- c("Date", "Equal", "MktCap", "Revenue")
  
  r.plot.excess <- reshape2::melt(r.plot.excess, id.vars = "Date")
  dist.vars <- ddply(r.plot.excess, "variable", summarise, Mean = mean(value), 
              Skewness = skewness(value), Kurtosis = kurtosis(value) )
  dist.vars <- dist.vars %>% mutate_if(is.numeric, ~round(., 4))
  
  y.labs.x <- list(paste("Equal \n\nMean", dist.vars[1,2],"\nSkewness", dist.vars[1,3],"\nKurtosis",dist.vars[1,4]),
                 paste("MktCap \n\nMean", dist.vars[2,2],"\nSkewness", dist.vars[2,3],"\nKurtosis",dist.vars[2,4]), 
                 paste("Revenue \n\nMean", dist.vars[3,2],"\nSkewness", dist.vars[3,3],"\nKurtosis",dist.vars[3,4]))
  y_labeller <- function(variable,value){
    return(y.labs.x[value])
  }
  
  r.ex.dist <- ggplot(r.plot.excess, aes(x = value, fill = variable)) + 
    labs(title = "", x = "Monthly Returns", y = "") +
    geom_density(alpha = 0.6, size = 1) +
    geom_vline(data = dist.vars, aes(xintercept = Mean), linetype = "dashed") +
    scale_fill_manual(values = c("steelblue2", "steelblue", "steelblue4")) +
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottom,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y = element_text(color = "white", size = 0),
      axis.line.y = element_line(color = "white"),
      axis.ticks.y = element_line(color = "white"),
      legend.position = "none", 
      strip.text.y = element_text(size = 30, color = "black", face = "bold", angle = 0),
      strip.background = element_rect(color="white", fill = "white", size=1.5, linetype="solid")) +
    facet_grid(variable ~ ., labeller = y_labeller)
    

  # Return objects-------------------------------------------------------------#
  df.plot <<- df.plot
  ff.equal.no <<- ff.equal.no
  ff.mktcap.no <<- ff.mktcap.no
  ff.rev.no <<- ff.rev.no
  ff.equal.eu <<- ff.equal.eu
  ff.mktcap.eu <<- ff.mktcap.eu
  ff.rev.eu <<- ff.rev.eu
  stats <<- stats
  sum.mpt <<- sum.mpt
  gg <<- gg
  gics.equal <<- gics.equal
  gics.mktcap <<- gics.mktcap
  gics.rev <<- gics.rev
  gics.mean.t <<- gics.mean.t
  gics.time <<- gics.time
  t.time <<- t.time
  r.dist <<- r.dist
  r.ex.dist <<- r.ex.dist
  name <<- name
  t.cost <<- t.cost
}


## Load accounting values to choose -------------------------------------------#
load("KeyMetrics.RData")
KeyMetrics
# 7, 4, 19, 3, 18

## Run function ---------------------------------------------------------------#
backtest(x = 10, 
         t.cost = 0.02, 
         accountingValue = 18, 
         high_low = "highest", 
         l.axis = 100,
         DATE1 = "2000-11-30",
         DATE2 = "2020-11-30")

# PLOTS -----------------------------------------------------------------------#
gg            # 2560*1600
t.time        # 2560*640
gics.time     # 2560*1600
r.dist        # 2560*2560
r.ex.dist     # 2560*2560



# TABLES ----------------------------------------------------------------------#
# LATEX: import txt to: https://www.tablesgenerator.com/latex_tables

xtable(stats, digits = c(0,4,4,4,4,4,4))
xtable(sum.mpt)
xtable(gics.mean.t, digits = c(0,2,2,2))


## Have norwegian and european in same output:
names(ff.equal.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")
names(ff.mktcap.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")
names(ff.rev.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")

names(ff.equal.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")
names(ff.mktcap.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")
names(ff.rev.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")


stargazer(ff.equal.no, ff.mktcap.no, ff.rev.no, ff.equal.eu, ff.mktcap.eu, ff.rev.eu,
          title = paste("Regression Results -",name),
          #column.labels = c("Norwegian (FF3F + MOM + LIQ)", "European (FF5F + MOM)"),
          #column.separate = c(3, 3),
          dep.var.caption  = "Norwegian Model (FF3F + MOM + LIQ) | European Model (FF5F + MOM)",
          dep.var.labels = c("Equal-rf", "MktCap-rf", "Revenue-rf", "Equal-rf", "MktCap-rf", "Revenue-rf" ),
          report = ('vc*'),
          no.space = TRUE,
          align = TRUE,
          omit.stat = c("ser", "f", "rsq"),
          #font.size = "small",
          star.char = c("*"),
          star.cutoffs = c(0.05),
          notes.append = FALSE, 
          notes = paste("$^{*}$p$<$0.05;", "Transaction cost:", t.cost),
          notes.label = 'Notes'
          #notes.align = 'r' # c center, r right)
)







## 14.0 - Backtest multiple metrics & 3 weightings with Gics -------------------

# ## Inside function:
# y = 1
# x = 10
# t.cost = 0.02
# p.ratio = "EBITDAMarginPrc"
# p.hl = "highest"
# s.ratio = "D_EPrc"
# s.hl = "lowest"
# l.ratio = "CurrentRatio"
# l.hl = "highest"
# l.axis = 100
# DATE1 = "2000-11-30"
# DATE2 = "2020-11-30"


## Function
# y = Start to pick stocks at rank y
# x = Stop to pick stocks at rank x
# t.cost = transaction cost
# accounting value = which accounting value
# high_low = invest in top or bottom based on accounting value
# DATE1 = start date of backtest
# DATE2 = end date of backtest

backtest <- function(y, x, t.cost, p.ratio, p.hl, s.ratio, s.hl, l.ratio, l.hl, l.axis, DATE1, DATE2) {
  
  # Load accounting data
  load("KeyMetrics.RData")
  
  load(paste0(p.ratio, ".RData"))
  p.KeyMet <- get(p.ratio)
  
  load(paste0(s.ratio, ".RData"))
  s.KeyMet <- get(s.ratio)
  
  load(paste0(l.ratio, ".RData"))
  l.KeyMet <- get(l.ratio)
  
  # Load other data
  load("stocks-90-20.RData")
  load("mktcap-90-20.RData")
  load("revenue-90-20.RData")
  load("gics.RData")
  
  
  # Align dates
  p.KeyMet <- filter(p.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  s.KeyMet <- filter(s.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  l.KeyMet <- filter(l.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.stocks <- filter(w.stocks, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.mktcap <- filter(w.mktcap, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.revenue <- filter(w.revenue, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.gics <- filter(w.gics, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  
  
  # Values to record for backtesting --------------------------------------------#
  r.equal <- c(0)    # Return series: The return that month
  r.mktcap <- c(0)
  r.rev <- c(0)
  t <- c(0)          # Transaction series: Number of transactions that month
  p <- c(0)          # Portfolio series: Number of stocks held that month
  p.lm <- c()        # Which stocks in portfolio, last month
  m <- c(0)          # Number of listed stocks that have metrics each month 
  
  e.gic0  <- c(0)
  e.gic10 <- c(0)
  e.gic15 <- c(0)
  e.gic20 <- c(0)
  e.gic25 <- c(0)
  e.gic30 <- c(0)
  e.gic35 <- c(0)
  e.gic40 <- c(0)
  e.gic45 <- c(0)
  e.gic50 <- c(0)
  e.gic55 <- c(0)
  e.gic60 <- c(0)
  
  m.gic0  <- c(0)
  m.gic10 <- c(0)
  m.gic15 <- c(0)
  m.gic20 <- c(0)
  m.gic25 <- c(0)
  m.gic30 <- c(0)
  m.gic35 <- c(0)
  m.gic40 <- c(0)
  m.gic45 <- c(0)
  m.gic50 <- c(0)
  m.gic55 <- c(0)
  m.gic60 <- c(0)
  
  r.gic0  <- c(0)
  r.gic10 <- c(0)
  r.gic15 <- c(0)
  r.gic20 <- c(0)
  r.gic25 <- c(0)
  r.gic30 <- c(0)
  r.gic35 <- c(0)
  r.gic40 <- c(0)
  r.gic45 <- c(0)
  r.gic50 <- c(0)
  r.gic55 <- c(0)
  r.gic60 <- c(0)
  
  #i <- 2
  #for (i in 2:201) {
  
  for (i in 2:nrow(w.stocks)) {
    
    # Which stocks to invest in at month i ------------------------------------#
    
    # Ensure stock at month i is listed
    stock.i <- w.stocks[i, ]
    stock.i <- stock.i[ , colSums(is.na(stock.i)) == 0]
    listed <- colnames(stock.i[ ,-1])  # And remove date
    
    # Ensure stock has MarketCap-data, for weighting
    mktcap.i <- w.mktcap[i, ]
    mktcap.i <- mktcap.i[ , colSums(is.na(mktcap.i)) == 0, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% listed, drop = FALSE]
    mktcap.ok <- colnames(mktcap.i)
    
    # Ensure stock has Revenue-data, for weighting
    revenue.i <- w.revenue[i, ]
    revenue.i <- revenue.i[ , colSums(is.na(revenue.i)) == 0, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% mktcap.ok, drop = FALSE]
    rev.ok <- colnames(revenue.i)
    
    # Extract non-NA values from metric at last month, filter with above
    p.metric.i <- p.KeyMet[i-1, ]
    p.metric.i <- p.metric.i[ , colSums(is.na(p.metric.i)) == 0, drop = FALSE]
    p.metric.i <- p.metric.i[ , colnames(p.metric.i) %in% rev.ok, drop = FALSE]
    
    s.metric.i <- s.KeyMet[i-1, ]
    s.metric.i <- s.metric.i[ , colSums(is.na(s.metric.i)) == 0, drop = FALSE]
    s.metric.i <- s.metric.i[ , colnames(s.metric.i) %in% rev.ok, drop = FALSE]
    
    l.metric.i <- l.KeyMet[i-1, ]
    l.metric.i <- l.metric.i[ , colSums(is.na(l.metric.i)) == 0, drop = FALSE]
    l.metric.i <- l.metric.i[ , colnames(l.metric.i) %in% rev.ok, drop = FALSE]
    
    
    l <- length(p.metric.i) # How many possible stocks at month i
    m <- c(m, l)
    
    ### Scoring stocks and pick top 10 ----------------------------------------#
    
    pr <- p.metric.i %>% gather(isin, value)
    sr <- s.metric.i %>% gather(isin, value)
    lr <- l.metric.i %>% gather(isin, value)
    
    if (p.hl == "highest") {
      pr$p.decile <- ntile(pr$value, 10)
      pr$value <- NULL
    } else if (p.hl == "lowest") {
      pr$p.decile <- ntile(-pr$value, 10)
      pr$value <- NULL
    }
    if (s.hl == "highest") {
      sr$s.decile <- ntile(sr$value, 10)
      sr$value <- NULL
    } else if (s.hl == "lowest") {
      sr$s.decile <- ntile(-sr$value, 10)
      sr$value <- NULL
    }
    if (l.hl == "highest") {
      lr$l.decile <- ntile(lr$value, 10)
      lr$value <- NULL
    } else if (l.hl == "lowest") {
      lr$l.decile <- ntile(-lr$value, 10)
      lr$value <- NULL
    }
    
    score <- merge(pr, sr, all = TRUE)
    score <- merge(score, lr, all = TRUE)
    score <- transform(score, sum = rowSums(score[2:4], na.rm = TRUE))
    
    score <- score[order(-score$sum), ]
    invest.i <- score$isin[y:x]
    p <- c(p, length(invest.i))

    stock.i <- stock.i[ , colnames(stock.i) %in% invest.i, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% invest.i, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% invest.i, drop = FALSE]
    
    # GICS
    gics.i <- w.gics[i, ]
    gics.i <- gics.i[ , colnames(gics.i) %in% invest.i, drop = FALSE]
    
    
    # First month -> only buy -------------------------------------------------#
    if (l > 0 && length(p.lm) == 0) {
      
      # Returns, weightings and transaction costs -----------------------------#
      #sold <- setdiff(p.lm,invest.i)
      bought <- setdiff(invest.i,p.lm)
      #hold <- intersect(p.lm,invest.i)
      t <- c(t, length(bought))
      
      # Bought
      #r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      #stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      ww.equal.bh <- 1/(length(returns))              
      p.equal <- ww.equal.bh * ( sum(returns) )
      r.equal <- c(r.equal, p.equal)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap <- sum(ww.mktcap.r * returns)
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))           
      p.rev <- sum(ww.rev.r * returns)
      r.rev <- c(r.rev, p.rev)
      
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
      # Month 2+ -> Buy, sell & hold stocks -------------------------------------#
    } else if (l > 0 && length(p.lm) > 0) {
      
      
      # Returns, weightings and transaction costs -----------------------------#
      sold <- setdiff(p.lm, invest.i)
      bought <- setdiff(invest.i, p.lm)
      hold <- intersect(p.lm, invest.i)
      t <- c(t, length(sold) + length(bought))
      
      # Adjust returns for bought:
      r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      # Returns for sold (transaction cost)
      n.sold <- length(sold)
      n.t <- c()
      for (j in 1:n.sold) {
        n.t[j] <- -t.cost
      }
      
      # Equal weighting -------------------------------------------------------#
      ww.equal.sold <- ww.equal.lm
      p.equal.sold <- ww.equal.sold * ( sum(n.t) )
      
      ww.equal.bh <- 1 / (length(returns))
      p.equal.bh <- ww.equal.bh * ( sum(returns) )
      
      p.equal <- p.equal.sold + p.equal.bh
      r.equal <- c(r.equal, p.equal)
      
      # MarketCap weighting ---------------------------------------------------#
      ww.mktcap.sold <- ww.mktcap.lm[sold]
      ww.mktcap.sold <- as.numeric(as.vector(ww.mktcap.sold[1,]))
      p.mktcap.sold <- sum( ww.mktcap.sold * n.t)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap.bh <- sum(ww.mktcap.r * returns)
      
      p.mktcap <- p.mktcap.sold + p.mktcap.bh
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      # Revenue weighting -----------------------------------------------------#
      ww.rev.sold <- ww.rev.lm[sold]
      ww.rev.sold <- as.numeric(as.vector(ww.rev.sold[1,]))
      p.rev.sold <- sum( ww.rev.sold * n.t)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))
      p.rev.bh <- sum(ww.rev.r * returns)
      
      p.rev <- p.rev.sold + p.rev.bh
      r.rev <- c(r.rev, p.rev)
      
      # Store portfolio this month, for calculation next month
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
    }
    
    ## GICS -----------------------------------------------------------------#
    
    e.gic0  <- c(e.gic0,  length(which(gics.i == "Unknown")) / 10)
    e.gic10 <- c(e.gic10, length(which(gics.i == "Energy")) / 10)
    e.gic15 <- c(e.gic15, length(which(gics.i == "Materials")) / 10)
    e.gic20 <- c(e.gic20, length(which(gics.i == "Industrials")) / 10)
    e.gic25 <- c(e.gic25, length(which(gics.i == "ConsumerDiscretionary")) / 10)
    e.gic30 <- c(e.gic30, length(which(gics.i == "ConsumerStaples")) / 10)
    e.gic35 <- c(e.gic35, length(which(gics.i == "HealthCare")) / 10)
    e.gic40 <- c(e.gic40, length(which(gics.i == "Financials")) / 10)
    e.gic45 <- c(e.gic45, length(which(gics.i == "InformationTechnology")) / 10)
    e.gic50 <- c(e.gic50, length(which(gics.i == "TelecommunicationServices")) / 10)
    e.gic55 <- c(e.gic55, length(which(gics.i == "Utilities")) / 10)
    e.gic60 <- c(e.gic60, length(which(gics.i == "RealEstate")) / 10)
    
    df3 <- rbind(gics.i, ww.mktcap.bh)
    
    m.gic0  <- c(m.gic0,  sum(as.numeric(df3[2,which(df3[1,] == "Unknown")])))
    m.gic10 <- c(m.gic10, sum(as.numeric(df3[2,which(df3[1,] == "Energy")])))
    m.gic15 <- c(m.gic15, sum(as.numeric(df3[2,which(df3[1,] == "Materials")])))
    m.gic20 <- c(m.gic20, sum(as.numeric(df3[2,which(df3[1,] == "Industrials")])))
    m.gic25 <- c(m.gic25, sum(as.numeric(df3[2,which(df3[1,] == "ConsumerDiscretionary")])))
    m.gic30 <- c(m.gic30, sum(as.numeric(df3[2,which(df3[1,] == "ConsumerStaples")])))
    m.gic35 <- c(m.gic35, sum(as.numeric(df3[2,which(df3[1,] == "HealthCare")])))
    m.gic40 <- c(m.gic40, sum(as.numeric(df3[2,which(df3[1,] == "Financials")])))
    m.gic45 <- c(m.gic45, sum(as.numeric(df3[2,which(df3[1,] == "InformationTechnology")])))
    m.gic50 <- c(m.gic50, sum(as.numeric(df3[2,which(df3[1,] == "TelecommunicationServices")])))
    m.gic55 <- c(m.gic55, sum(as.numeric(df3[2,which(df3[1,] == "Utilities")])))
    m.gic60 <- c(m.gic60, sum(as.numeric(df3[2,which(df3[1,] == "RealEstate")])))
    
    df4 <- rbind(gics.i, ww.rev.bh)
    
    r.gic0  <- c(r.gic0,  sum(as.numeric(df4[2,which(df4[1,] == "Unknown")])))
    r.gic10 <- c(r.gic10, sum(as.numeric(df4[2,which(df4[1,] == "Energy")])))
    r.gic15 <- c(r.gic15, sum(as.numeric(df4[2,which(df4[1,] == "Materials")])))
    r.gic20 <- c(r.gic20, sum(as.numeric(df4[2,which(df4[1,] == "Industrials")])))
    r.gic25 <- c(r.gic25, sum(as.numeric(df4[2,which(df4[1,] == "ConsumerDiscretionary")])))
    r.gic30 <- c(r.gic30, sum(as.numeric(df4[2,which(df4[1,] == "ConsumerStaples")])))
    r.gic35 <- c(r.gic35, sum(as.numeric(df4[2,which(df4[1,] == "HealthCare")])))
    r.gic40 <- c(r.gic40, sum(as.numeric(df4[2,which(df4[1,] == "Financials")])))
    r.gic45 <- c(r.gic45, sum(as.numeric(df4[2,which(df4[1,] == "InformationTechnology")])))
    r.gic50 <- c(r.gic50, sum(as.numeric(df4[2,which(df4[1,] == "TelecommunicationServices")])))
    r.gic55 <- c(r.gic55, sum(as.numeric(df4[2,which(df4[1,] == "Utilities")])))
    r.gic60 <- c(r.gic60, sum(as.numeric(df4[2,which(df4[1,] == "RealEstate")])))
    
    #print(i)
    
  }
  
  # Format data for plotting --------------------------------------------------#
  df.plot <- w.stocks[ , 1 , drop = FALSE]
  rownames(df.plot) <- seq(length = nrow(df.plot))
  
  df.plot$r.equal <- r.equal   # Return series of strategy
  df.plot$r.mktcap <- r.mktcap # Return series of strategy
  df.plot$r.rev <- r.rev       # Return series of strategy
  df.plot$m <- m               # Number of metrics found for strategy
  df.plot$t <- t               # Number of transactions
  df.plot$p <- p               # Number of stocks in portfolio
  
  # Add index -----------------------------------------------------------------#
  load("Indicies2.RData")
  df.plot <- merge(df.plot, w.ix[ , c(1, 13)], all.x = TRUE)
  colnames(df.plot)[ncol(df.plot)] <- "r.index"
  
  df.plot$Equal <- 100 * cumprod(1 + df.plot$r.equal)
  df.plot$MktCap <- 100 * cumprod(1 + df.plot$r.mktcap)
  df.plot$Revenue <- 100 * cumprod(1 + df.plot$r.rev)
  
  df.plot[1,8] <- 0
  df.plot$OSEBX <- 100 * cumprod(1 + df.plot$r.index)
  
  # Add risk-free -------------------------------------------------------------#
  load("Riskfree-Rate.RData")
  df.plot <- merge(df.plot, rf, all.x = TRUE) 
  
  df.plot$r.equal.excess <- df.plot$r.equal - df.plot$rf
  df.plot$r.mktcap.excess <- df.plot$r.mktcap - df.plot$rf
  df.plot$r.rev.excess <- df.plot$r.rev - df.plot$rf
  df.plot$r.index.excess <- df.plot$r.index - df.plot$rf
  
  # Fama French regression ---------------------------------------------------#
  load("FamaFrench_NO_EU.RData")
  
  df.plot.ff <- merge(df.plot[c(1:4,14:17)], famafrench, all.x = TRUE)
  df.plot.ff <- df.plot.ff[complete.cases(df.plot.ff), ]  # Non-nas for regression
  df.plot.ff <- df.plot.ff[-c(1),]
  
  # Norwegian FF3
  ff.equal.no <- lm(formula = r.equal.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)
  ff.mktcap.no <- lm(formula = r.mktcap.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)
  ff.rev.no <- lm(formula = r.rev.excess ~ r.index.excess + SMB.NO + HML.NO + UMD.NO + LIQ.NO, data = df.plot.ff)
  
  # European FF5
  df.plot.ff$r.equal.excess.eu <- df.plot.ff$r.equal - df.plot.ff$rf.EU
  df.plot.ff$r.mktcap.excess.eu <- df.plot.ff$r.mktcap - df.plot.ff$rf.EU
  df.plot.ff$r.rev.excess.eu <- df.plot.ff$r.rev - df.plot.ff$rf.EU
  
  ff.equal.eu <- lm(formula = r.equal.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU, data = df.plot.ff)
  ff.mktcap.eu <- lm(formula = r.mktcap.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU, data = df.plot.ff)
  ff.rev.eu <- lm(formula = r.rev.excess.eu ~ Index.EU + SMB.EU + HML.EU + RMW.EU + CMA.EU + UMD.EU,data = df.plot.ff)
  
  # Format GICS data ----------------------------------------------------------#
  df.gics.equal <- w.stocks[ , 1 , drop = FALSE]
  df.gics.mktcap <- df.gics.equal
  df.gics.rev <- df.gics.equal
  
  df.gics.equal$Unknown                   <- e.gic0
  df.gics.equal$Energy                    <- e.gic10
  df.gics.equal$Materials                 <- e.gic15
  df.gics.equal$Industrials               <- e.gic20
  df.gics.equal$ConsumerDiscretionary     <- e.gic25
  df.gics.equal$ConsumerStaples           <- e.gic30
  df.gics.equal$HealthCare                <- e.gic35
  df.gics.equal$Financials                <- e.gic40
  df.gics.equal$InformationTechnology     <- e.gic45
  df.gics.equal$TelecommunicationServices <- e.gic50
  df.gics.equal$Utilities                 <- e.gic55
  df.gics.equal$RealEstate                <- e.gic60
  
  df.gics.mktcap$Unknown                   <- m.gic0
  df.gics.mktcap$Energy                    <- m.gic10
  df.gics.mktcap$Materials                 <- m.gic15
  df.gics.mktcap$Industrials               <- m.gic20
  df.gics.mktcap$ConsumerDiscretionary     <- m.gic25
  df.gics.mktcap$ConsumerStaples           <- m.gic30
  df.gics.mktcap$HealthCare                <- m.gic35
  df.gics.mktcap$Financials                <- m.gic40
  df.gics.mktcap$InformationTechnology     <- m.gic45
  df.gics.mktcap$TelecommunicationServices <- m.gic50
  df.gics.mktcap$Utilities                 <- m.gic55
  df.gics.mktcap$RealEstate                <- m.gic60
  
  df.gics.rev$Unknown                   <- r.gic0
  df.gics.rev$Energy                    <- r.gic10
  df.gics.rev$Materials                 <- r.gic15
  df.gics.rev$Industrials               <- r.gic20
  df.gics.rev$ConsumerDiscretionary     <- r.gic25
  df.gics.rev$ConsumerStaples           <- r.gic30
  df.gics.rev$HealthCare                <- r.gic35
  df.gics.rev$Financials                <- r.gic40
  df.gics.rev$InformationTechnology     <- r.gic45
  df.gics.rev$TelecommunicationServices <- r.gic50
  df.gics.rev$Utilities                 <- r.gic55
  df.gics.rev$RealEstate                <- r.gic60
  
  
  # Gather statistics ---------------------------------------------------------#
  
  # Strategy Equal
  mu.equal <- mean(df.plot$r.equal[-1]) * 12
  mu.ex.equal <- mean(df.plot$r.equal.excess[-1]) * 12
  sd.equal <- sd(df.plot$r.equal[-1]) * sqrt(12)
  sr.equal <- mu.ex.equal / sd.equal
  beta.equal <- cov(df.plot$r.equal[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy MktCap
  mu.mktcap <- mean(df.plot$r.mktcap[-1]) * 12
  mu.ex.mktcap <- mean(df.plot$r.mktcap.excess[-1]) * 12
  sd.mktcap <- sd(df.plot$r.mktcap[-1]) * sqrt(12)
  sr.mktcap <- mu.ex.mktcap / sd.mktcap
  beta.mktcap <- cov(df.plot$r.mktcap[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy Revenue
  mu.rev <- mean(df.plot$r.rev[-1]) * 12
  mu.ex.rev <- mean(df.plot$r.rev.excess[-1]) * 12
  sd.rev <- sd(df.plot$r.rev[-1]) * sqrt(12)
  sr.rev <- mu.ex.rev / sd.rev
  beta.rev <- cov(df.plot$r.rev[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  #Index
  mu.i <- mean(df.plot$r.index[-1]) * 12
  mu.ex.i <- mean(df.plot$r.index.excess[-1]) * 12
  sd.i <- sd(df.plot$r.index[-1]) * sqrt(12)
  sr.i <- mu.ex.i / sd.i
  beta.i <- cov(df.plot$r.index[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Jensen
  rf.ann <- mean(df.plot$rf[-1]) * 12
  jens.equal <- mu.equal - (rf.ann + (mu.i - rf.ann) * beta.equal)
  jens.mktcap <- mu.mktcap - (rf.ann + (mu.i - rf.ann) * beta.mktcap)
  jens.rev <- mu.rev - (rf.ann + (mu.i - rf.ann) * beta.rev)
  jens.i <- mu.i - (rf.ann + (mu.i - rf.ann) * beta.i)
  
  # Treynor
  trey.equal <- mu.ex.equal / beta.equal
  trey.mktcap <- mu.ex.mktcap / beta.mktcap
  trey.rev <- mu.ex.rev / beta.rev
  trey.i <- mu.ex.i / beta.i
  
  
  # Stats table
  a <- c(mu.i, sd.i, sr.i, beta.i, jens.i, trey.i)
  b <- c(mu.equal, sd.equal, sr.equal, beta.equal, jens.equal, trey.equal)
  c <- c(mu.mktcap, sd.mktcap, sr.mktcap, beta.mktcap, jens.mktcap, trey.mktcap)
  d <- c(mu.rev, sd.rev, sr.rev, beta.rev, jens.rev, trey.rev)
  stats <- data.frame(a,b,c,d)
  stats <- t(stats)
  stats <- as.data.frame(stats)
  rownames(stats) <- c("Index", "Equal","MktCap","Revenue")
  colnames(stats) <- c("Average Annual Return", "Standard Deviation", "Sharpe Ratio", "Beta", 
                       "Jensen's Alpha", "Treynor's Measure")
  stats <- stats %>% mutate_if(is.numeric, ~round(., 4))
  
  
  # Metrics, portfolio, transactions
  sum.mpt <- df.plot[-1, 6, drop = FALSE]
  sum.mpt <- do.call(cbind, lapply(sum.mpt, summary))
  sum.mpt <- t(sum.mpt)
  sum.mpt <- as.data.frame(sum.mpt)
  rownames(sum.mpt) <- c("Transactions")
  sum.mpt[, 4] <- round(sum.mpt[, 4], 2)
  sum.mpt <- cbind(sum.mpt, data.frame(Sum = sum(df.plot[ , 6])))
  
  
  # Plotting strategies over time ---------------------------------------------#
  df.plot1 <- df.plot[ , c(1,9:12)]
  
  firstdate <- df.plot1[1,1]
  lastdate <- df.plot1[nrow(df.plot1),1]
  r.axis <- as.numeric(as.vector(df.plot1[nrow(df.plot1), 2:ncol(df.plot1)]))
  r.axis <- round(r.axis, 2)
  
  ColName <- colnames(df.plot1)[2:ncol(df.plot1)]
  ColCol  <- c("#92c5de","#4393c3","#2166ac","#67001f")
  
  
  df_long = reshape2::melt(df.plot1, id.vars="Date")
  df_long <- df_long %>% mutate_if(is.numeric, ~round(., 2))
  
  data_starts <- df_long %>% filter(Date == firstdate)
  data_ends <- df_long %>% filter(Date == lastdate)
  
  roundUp <- function(x,to=100) {to*(x%/%to + as.logical(x%%to))}
  max <- roundUp(max(data_ends[ , 3]))
  
  theme_set(theme_classic() +
              theme(text = element_text(family = "LM Roman 10", face = "plain"),
                    plot.caption  = element_text(size=30, hjust=0, margin=margin(3,0,0,0), face = "plain"),
                    panel.background = element_rect(fill = "white"),
                    plot.background = element_rect(fill = "white"),
                    plot.margin = margin(30, 100, 30, 30),  # top, right, bottom, left
                    axis.text = element_text(color = "black", size = 30),
                    axis.title = element_text(color = "black", size = 30, face = "bold"),
                    legend.justification = c(0.01, 1), 
                    legend.position = c(0.01, 1),
                    legend.direction = "horizontal",
                    legend.title=element_blank(),
                    legend.text = element_text(colour="black", size = 40, margin=margin(0,0,0,0)),
                    legend.background = element_rect(fill="white", size=2, linetype="dotted")))
  
  gg <- ggplot(df_long, aes(x = Date, y = value, group = variable)) +
    scale_colour_manual("", breaks = ColName, values = ColCol) +
    scale_y_continuous(breaks = seq(100, max, by = l.axis)) + 
    scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01,0)) +
    coord_cartesian(xlim = as.Date(c("2000-10-30", "2021-01-30")), clip = "off") +
    labs(title = "", x = "Time", y = "Value", color = "Legend",
         caption = paste("*Strategy: Every month, invest the 10 highest ranked stocks, by", p.ratio, "&", s.ratio, "&", l.ratio,
                         "\n*Transaction cost: ",100*abs(t.cost),"%")) +
    geom_line(aes(color = variable), size = 2) +
    geom_point(data = data_starts, aes(x = Date, y = value), col = "black", 
               shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
    geom_point(data = data_ends, aes(x = Date, y = value), col = "black", 
               shape = 21, fill = "black", size = 2.5, stroke = 1.7) +
    guides(color = guide_legend(override.aes = list(size = 10) ) ) +
    geom_text_repel(aes(label = value, family = "LM Roman 10"), 
                    data = data_ends,
                    size = 10,
                    direction = "y", 
                    hjust = 0, 
                    segment.size = 1,
                    na.rm = TRUE,
                    xlim = as.Date(c("2021-03-30", "2027-11-30"))) 
  
  
  # Sector GICS illustration --------------------------------------------------#
  df.gics.equal <- df.gics.equal[ -1, , drop = FALSE]
  df.gics.mktcap <- df.gics.mktcap[ -1, , drop = FALSE]
  df.gics.rev <- df.gics.rev[ -1, , drop = FALSE]
  
  # Mean gics proportions over period -----------------------------------------#
  gics.equal <- colMeans(df.gics.equal[, -1])
  gics.mktcap <- colMeans(df.gics.mktcap[, -1])
  gics.rev <- colMeans(df.gics.rev[, -1])
  
  gics.mean <- data.frame(t(gics.equal))
  gics.mean <- rbind(gics.mean, gics.mktcap, gics.rev)
  gics.mean.t <- transpose(gics.mean)
  rownames(gics.mean.t) <- colnames(gics.mean)
  colnames(gics.mean.t) <- c("Equal", "MktCap", "Revenue")
  gics.mean.t <- gics.mean.t %>% mutate_if(is.numeric, ~round(., 4))
  
  # Porportion over time ------------------------------------------------------#
  ColCol  <- c("#1a1a1a","#67001f","#053061","#d6604d","#4393c3","#fddbc7",
               "#d1e5f0","#92c5de","#f4a582","#2166ac","#b2182b", "#011c3b")
  
  
  melt.gics1 <- reshape2::melt(df.gics.equal, id.vars = "Date")
  melt.gics1$weighting <- "Equal"
  melt.gics2 <- reshape2::melt(df.gics.mktcap, id.vars = "Date")
  melt.gics2$weighting <- "MktCap"
  melt.gics3 <- reshape2::melt(df.gics.rev, id.vars = "Date")
  melt.gics3$weighting <- "Revenue"
  
  melt.gics <- rbind(melt.gics1, melt.gics2, melt.gics3)
  
  
  gics.time <- ggplot(melt.gics, aes(x = Date, y = value, fill = variable)) +
    labs(title = "",
         x = "Time", y = "Proportion", color = "Legend") +
    geom_area(alpha = 0.6 , size = 1, colour = "black") + 
    scale_fill_manual(values = ColCol) + 
    scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(30, 30, 30, 30),  # top,right,bottmo,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      legend.title=element_blank(),
      legend.text = element_text(colour="black", size = 30, margin=margin(0,0,0,0)),
      legend.background = element_rect(fill="white", size=2, linetype="dotted"),
      legend.position = "top",
      strip.text.y = element_text(size = 40, color = "black", face = "bold")) +
    facet_grid(weighting ~ .)
  
  # Transactions over time ----------------------------------------------------#
  
  t.plot <- df.plot[ -c(1), c(1, 6)]
  mean <- round(mean(t.plot$t),2)
  
  t.time <- ggplot(t.plot, aes(x = Date, y = t)) +
    labs(title = "", 
         x = "Time", y = "Number of transactions") +
    geom_hline(yintercept = seq(from=2, to=20, by = 2), color = "gray80") + 
    geom_bar(stat = "identity", fill = "#4393c3", color = "#4393c3") +
    geom_hline(yintercept = mean, color = "#053061", size = 1.5) + 
    scale_y_continuous(limits = c(0,20), breaks = c(0,4,8,12,16,20), minor_breaks = c(2,6,10,14,18),
                       sec.axis = sec_axis(~ ., breaks = mean)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%y", expand = c(0.01,0)) + 
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottmo,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y.right = element_text(color = "black", size = 30, face = "bold"),
      axis.line.y.right = element_line(color = "white"),
      axis.ticks.y.right = element_line(color = "white"))
  
  # Return distribution -------------------------------------------------------#
  
  r.plot <- df.plot[ -c(1), c(1:4, 8)]
  colnames(r.plot) <- c("Date", "Equal", "MktCap", "Revenue", "OSEBX")
  
  r.plot <- reshape2::melt(r.plot, id.vars = "Date")
  
  dist.vars <- ddply(r.plot, "variable", summarise, 
                     #Mode = getmode(value), 
                     #Median = median(value),
                     Mean = mean(value), 
                     Skewness = skewness(value), 
                     Kurtosis = kurtosis(value))
  dist.vars <- dist.vars %>% mutate_if(is.numeric, ~round(., 4))
  
  y.labs <- list(paste("Equal\n\nMean",dist.vars[1,2],"\nSkewness",dist.vars[1,3],"\nKurtosis",dist.vars[1,4]),
                 paste("MktCap\n\nMean",dist.vars[2,2],"\nSkewness",dist.vars[2,3],"\nKurtosis",dist.vars[2,4]),
                 paste("Revenue\n\nMean",dist.vars[3,2],"\nSkewness",dist.vars[3,3],"\nKurtosis",dist.vars[3,4]),
                 paste("OSEBX\n\nMean",dist.vars[4,2],"\nSkewness",dist.vars[4,3],"\nKurtosis",dist.vars[4,4]))
  y_labeller <- function(variable,value){
    return(y.labs[value])
  }
  
  r.dist <- ggplot(r.plot, aes(x = value, fill = variable)) + 
    labs(title = "", x = "Monthly Returns", y = "") +
    geom_density(alpha = 0.6, size = 1) +
    geom_vline(data = dist.vars, aes(xintercept = Mean), linetype = "dashed") +
    #geom_vline(data = dist.vars, aes(xintercept = Mode), linetype = "dashed") +
    #geom_vline(data = dist.vars, aes(xintercept = Median), linetype = "dashed") +
    scale_fill_manual(values = c("steelblue2", "steelblue", "steelblue4", "darkred")) +
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottom,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y = element_text(color = "white", size = 0),
      axis.line.y = element_line(color = "white"),
      axis.ticks.y = element_line(color = "white"),
      legend.position = "none", 
      strip.text.y = element_text(size = 30, color = "black", face = "bold", angle = 0),
      strip.background = element_rect(color="white", fill = "white", size=1.5, linetype="solid")) +
    facet_grid(variable ~ ., labeller = y_labeller)
  
  # Return distribution excess ------------------------------------------------#
  
  r.plot.excess <- df.plot[ -c(1), c(1:4, 8)]
  r.plot.excess$r.equal <- r.plot.excess$r.equal - r.plot.excess$r.index
  r.plot.excess$r.mktcap <- r.plot.excess$r.mktcap - r.plot.excess$r.index
  r.plot.excess$r.rev <- r.plot.excess$r.rev - r.plot.excess$r.index
  r.plot.excess$r.index <- NULL
  colnames(r.plot.excess) <- c("Date", "Equal", "MktCap", "Revenue")
  
  r.plot.excess <- reshape2::melt(r.plot.excess, id.vars = "Date")
  dist.vars <- ddply(r.plot.excess, "variable", summarise, Mean = mean(value), 
                     Skewness = skewness(value), Kurtosis = kurtosis(value) )
  dist.vars <- dist.vars %>% mutate_if(is.numeric, ~round(., 4))
  
  y.labs.x <- list(paste("Equal \n\nMean", dist.vars[1,2],"\nSkewness", dist.vars[1,3],"\nKurtosis",dist.vars[1,4]),
                   paste("MktCap \n\nMean", dist.vars[2,2],"\nSkewness", dist.vars[2,3],"\nKurtosis",dist.vars[2,4]), 
                   paste("Revenue \n\nMean", dist.vars[3,2],"\nSkewness", dist.vars[3,3],"\nKurtosis",dist.vars[3,4]))
  y_labeller <- function(variable,value){
    return(y.labs.x[value])
  }
  
  r.ex.dist <- ggplot(r.plot.excess, aes(x = value, fill = variable)) + 
    labs(title = "", x = "Monthly Returns", y = "") +
    geom_density(alpha = 0.6, size = 1) +
    geom_vline(data = dist.vars, aes(xintercept = Mean), linetype = "dashed") +
    scale_fill_manual(values = c("steelblue2", "steelblue", "steelblue4")) +
    theme_classic() +
    theme(
      text = element_text(family = "LM Roman 10", face="plain"),
      #plot.title    = element_text(size = 30, hjust=0, margin=margin(0,0,20,0), face = "bold"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      plot.margin = margin(10, 10, 10, 10),  # top,right,bottom,left
      axis.text = element_text(color = "black", size = 30),
      axis.title = element_text(color = "black", size = 30, face = "bold"),
      axis.text.y = element_text(color = "white", size = 0),
      axis.line.y = element_line(color = "white"),
      axis.ticks.y = element_line(color = "white"),
      legend.position = "none", 
      strip.text.y = element_text(size = 30, color = "black", face = "bold", angle = 0),
      strip.background = element_rect(color="white", fill = "white", size=1.5, linetype="solid")) +
    facet_grid(variable ~ ., labeller = y_labeller)
  
  
  # Return objects-------------------------------------------------------------#
  df.plot <<- df.plot
  ff.equal.no <<- ff.equal.no
  ff.mktcap.no <<- ff.mktcap.no
  ff.rev.no <<- ff.rev.no
  ff.equal.eu <<- ff.equal.eu
  ff.mktcap.eu <<- ff.mktcap.eu
  ff.rev.eu <<- ff.rev.eu
  stats <<- stats
  sum.mpt <<- sum.mpt
  gg <<- gg
  gics.equal <<- gics.equal
  gics.mktcap <<- gics.mktcap
  gics.rev <<- gics.rev
  gics.mean.t <<- gics.mean.t
  gics.time <<- gics.time
  t.time <<- t.time
  r.dist <<- r.dist
  r.ex.dist <<- r.ex.dist
  #name <<- name
  t.cost <<- t.cost
  p.ratio <<- p.ratio
  s.ratio <<- s.ratio
  l.ratio <<- l.ratio
}


## Load accounting values to choose -------------------------------------------#
load("KeyMetrics.RData")
KeyMetrics

## Run function ---------------------------------------------------------------#
backtest(y = 1,
         x = 10,
         t.cost = 0.02,
         p.ratio = "EBITDAMarginPrc",
         p.hl = "highest",
         s.ratio = "NetProfitMarginPrc",
         s.hl = "highest",
         l.ratio = "CurrentRatio",
         l.hl = "highest",
         l.axis = 100,
         DATE1 = "2000-11-30",
         DATE2 = "2020-11-30")


# PLOTS -----------------------------------------------------------------------#
gg            # 2560*1600
t.time        # 2560*640
gics.time     # 2560*1600
r.dist        # 2560*2560
r.ex.dist     # 2560*2560


# TABLES ----------------------------------------------------------------------#
# LATEX: import txt to: https://www.tablesgenerator.com/latex_tables

xtable(stats, digits = c(0,4,4,4,4,4,4))
xtable(sum.mpt)
xtable(gics.mean.t, digits = c(0,2,2,2))


## Have norwegian and european in same output:
names(ff.equal.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")
names(ff.mktcap.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")
names(ff.rev.no$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "UMD", "LIQ")

names(ff.equal.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")
names(ff.mktcap.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")
names(ff.rev.eu$coefficients) <- c("Alpha", "Index-rf", "SMB", "HML", "RMW", "CMA", "UMD")


stargazer(ff.equal.no, ff.mktcap.no, ff.rev.no, ff.equal.eu, ff.mktcap.eu, ff.rev.eu,
          title = "Regression Results - EBITDA Margin, Net Profit Margin, and Current Ratio",
          #column.labels = c("Norwegian (FF3F + MOM + LIQ)", "European (FF5F + MOM)"),
          #column.separate = c(3, 3),
          dep.var.caption  = "Norwegian Model (FF3F + MOM + LIQ) | European Model (FF5F + MOM)",
          dep.var.labels = c("Equal-rf", "MktCap-rf", "Revenue-rf", "Equal-rf", "MktCap-rf", "Revenue-rf" ),
          report = ('vc*'),
          no.space = TRUE,
          align = TRUE,
          omit.stat = c("ser", "f", "rsq"),
          #font.size = "small",
          star.char = c("*"),
          star.cutoffs = c(0.05),
          notes.append = FALSE, 
          notes = paste("$^{*}$p$<$0.05;", "Transaction cost:", t.cost),
          notes.label = 'Notes'
          #notes.align = 'r' # c center, r right)
)





## END












## 15.0 - Identify ultimate combination of metrics by backtesting --------------

## Inside function:
# y = 1
# x = 10
# t.cost = 0.02
# p.ratio = "EBITDAMarginPrc"
# p.hl = "highest"
# s.ratio = "D_EPrc"
# s.hl = "lowest"
# l.ratio = "CurrentRatio"
# l.hl = "highest"
# l.axis = 100
# DATE1 = "2000-11-30"
# DATE2 = "2020-11-30"


## Function
# y = Start to pick stocks at rank y
# x = Stop to pick stocks at rank x
# t.cost = transaction cost
# accounting value = which accounting value
# high_low = invest in top or bottom based on accounting value
# DATE1 = start date of backtest
# DATE2 = end date of backtest

backtest <- function(y, x, t.cost, p.ratio, p.hl, s.ratio, s.hl, l.ratio, l.hl, l.axis, DATE1, DATE2) {
  
  # Load accounting data
  load("KeyMetrics.RData")
  
  load(paste0(p.ratio, ".RData"))
  p.KeyMet <- get(p.ratio)
  
  load(paste0(s.ratio, ".RData"))
  s.KeyMet <- get(s.ratio)
  
  load(paste0(l.ratio, ".RData"))
  l.KeyMet <- get(l.ratio)
  
  # Load other data
  load("stocks-90-20.RData")
  load("mktcap-90-20.RData")
  load("revenue-90-20.RData")

  
  
  # Align dates
  p.KeyMet <- filter(p.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  s.KeyMet <- filter(s.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  l.KeyMet <- filter(l.KeyMet, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.stocks <- filter(w.stocks, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.mktcap <- filter(w.mktcap, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  w.revenue <- filter(w.revenue, Date >= as.Date(DATE1) & Date <= as.Date(DATE2))
  
  
  # Values to record for backtesting --------------------------------------------#
  r.equal <- c(0)    # Return series: The return that month
  r.mktcap <- c(0)
  r.rev <- c(0)
  t <- c(0)          # Transaction series: Number of transactions that month
  p <- c(0)          # Portfolio series: Number of stocks held that month
  p.lm <- c()        # Which stocks in portfolio, last month
  m <- c(0)          # Number of listed stocks that have metrics each month 
  #i <- 2
  #for (i in 2:201) {
  
  for (i in 2:nrow(w.stocks)) {
    
    # Which stocks to invest in at month i ------------------------------------#
    
    # Ensure stock at month i is listed
    stock.i <- w.stocks[i, ]
    stock.i <- stock.i[ , colSums(is.na(stock.i)) == 0]
    listed <- colnames(stock.i[ ,-1])  # And remove date
    
    # Ensure stock has MarketCap-data, for weighting
    mktcap.i <- w.mktcap[i, ]
    mktcap.i <- mktcap.i[ , colSums(is.na(mktcap.i)) == 0, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% listed, drop = FALSE]
    mktcap.ok <- colnames(mktcap.i)
    
    # Ensure stock has Revenue-data, for weighting
    revenue.i <- w.revenue[i, ]
    revenue.i <- revenue.i[ , colSums(is.na(revenue.i)) == 0, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% mktcap.ok, drop = FALSE]
    rev.ok <- colnames(revenue.i)
    
    # Extract non-NA values from metric at last month, filter with above
    p.metric.i <- p.KeyMet[i-1, ]
    p.metric.i <- p.metric.i[ , colSums(is.na(p.metric.i)) == 0, drop = FALSE]
    p.metric.i <- p.metric.i[ , colnames(p.metric.i) %in% rev.ok, drop = FALSE]
    
    s.metric.i <- s.KeyMet[i-1, ]
    s.metric.i <- s.metric.i[ , colSums(is.na(s.metric.i)) == 0, drop = FALSE]
    s.metric.i <- s.metric.i[ , colnames(s.metric.i) %in% rev.ok, drop = FALSE]
    
    l.metric.i <- l.KeyMet[i-1, ]
    l.metric.i <- l.metric.i[ , colSums(is.na(l.metric.i)) == 0, drop = FALSE]
    l.metric.i <- l.metric.i[ , colnames(l.metric.i) %in% rev.ok, drop = FALSE]
    
    
    l <- length(p.metric.i) # How many possible stocks at month i
    m <- c(m, l)
    
    ### Scoring stocks and pick top 10 ----------------------------------------#
    
    pr <- p.metric.i %>% gather(isin, value)
    sr <- s.metric.i %>% gather(isin, value)
    lr <- l.metric.i %>% gather(isin, value)
    
    if (p.hl == "highest") {
      pr$p.decile <- ntile(pr$value, 10)
      pr$value <- NULL
    } else if (p.hl == "lowest") {
      pr$p.decile <- ntile(-pr$value, 10)
      pr$value <- NULL
    }
    if (s.hl == "highest") {
      sr$s.decile <- ntile(sr$value, 10)
      sr$value <- NULL
    } else if (s.hl == "lowest") {
      sr$s.decile <- ntile(-sr$value, 10)
      sr$value <- NULL
    }
    if (l.hl == "highest") {
      lr$l.decile <- ntile(lr$value, 10)
      lr$value <- NULL
    } else if (l.hl == "lowest") {
      lr$l.decile <- ntile(-lr$value, 10)
      lr$value <- NULL
    }
    
    score <- merge(pr, sr, all = TRUE)
    score <- merge(score, lr, all = TRUE)
    score <- transform(score, sum = rowSums(score[2:4], na.rm = TRUE))
    
    score <- score[order(-score$sum), ]
    invest.i <- score$isin[y:x]
    p <- c(p, length(invest.i))
    
    stock.i <- stock.i[ , colnames(stock.i) %in% invest.i, drop = FALSE]
    mktcap.i <- mktcap.i[ , colnames(mktcap.i) %in% invest.i, drop = FALSE]
    revenue.i <- revenue.i[ , colnames(revenue.i) %in% invest.i, drop = FALSE]
    

    
    # First month -> only buy -------------------------------------------------#
    if (l > 0 && length(p.lm) == 0) {
      
      # Returns, weightings and transaction costs -----------------------------#
      #sold <- setdiff(p.lm,invest.i)
      bought <- setdiff(invest.i,p.lm)
      #hold <- intersect(p.lm,invest.i)
      t <- c(t, length(bought))
      
      # Bought
      #r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      #stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      ww.equal.bh <- 1/(length(returns))              
      p.equal <- ww.equal.bh * ( sum(returns) )
      r.equal <- c(r.equal, p.equal)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap <- sum(ww.mktcap.r * returns)
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))           
      p.rev <- sum(ww.rev.r * returns)
      r.rev <- c(r.rev, p.rev)
      
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
      # Month 2+ -> Buy, sell & hold stocks -------------------------------------#
    } else if (l > 0 && length(p.lm) > 0) {
      
      
      # Returns, weightings and transaction costs -----------------------------#
      sold <- setdiff(p.lm, invest.i)
      bought <- setdiff(invest.i, p.lm)
      hold <- intersect(p.lm, invest.i)
      t <- c(t, length(sold) + length(bought))
      
      # Adjust returns for bought:
      r.buy <- function(x){ return ( (1+x)*(1-t.cost)-1 )  }
      stock.i[bought] <- data.frame(lapply(stock.i[bought], r.buy))
      
      returns <- as.numeric(as.vector(stock.i[1,]))
      
      # Returns for sold (transaction cost)
      n.sold <- length(sold)
      n.t <- c()
      for (j in 1:n.sold) {
        n.t[j] <- -t.cost
      }
      
      # Equal weighting -------------------------------------------------------#
      ww.equal.sold <- ww.equal.lm
      p.equal.sold <- ww.equal.sold * ( sum(n.t) )
      
      ww.equal.bh <- 1 / (length(returns))
      p.equal.bh <- ww.equal.bh * ( sum(returns) )
      
      p.equal <- p.equal.sold + p.equal.bh
      r.equal <- c(r.equal, p.equal)
      
      # MarketCap weighting ---------------------------------------------------#
      ww.mktcap.sold <- ww.mktcap.lm[sold]
      ww.mktcap.sold <- as.numeric(as.vector(ww.mktcap.sold[1,]))
      p.mktcap.sold <- sum( ww.mktcap.sold * n.t)
      
      ww.mktcap.bh <- as.data.frame(mktcap.i[1, ] / sum(mktcap.i[1, ]))
      ww.mktcap.r <- as.numeric(as.vector(ww.mktcap.bh[1,]))
      p.mktcap.bh <- sum(ww.mktcap.r * returns)
      
      p.mktcap <- p.mktcap.sold + p.mktcap.bh
      r.mktcap <- c(r.mktcap, p.mktcap)
      
      # Revenue weighting -----------------------------------------------------#
      ww.rev.sold <- ww.rev.lm[sold]
      ww.rev.sold <- as.numeric(as.vector(ww.rev.sold[1,]))
      p.rev.sold <- sum( ww.rev.sold * n.t)
      
      ww.rev.bh <- as.data.frame(revenue.i[1, ] / sum(revenue.i[1, ]))
      ww.rev.r <- as.numeric(as.vector(ww.rev.bh[1,]))
      p.rev.bh <- sum(ww.rev.r * returns)
      
      p.rev <- p.rev.sold + p.rev.bh
      r.rev <- c(r.rev, p.rev)
      
      # Store portfolio this month, for calculation next month
      p.lm <- invest.i
      ww.equal.lm <- ww.equal.bh
      ww.mktcap.lm <- ww.mktcap.bh
      ww.rev.lm <- ww.rev.bh
      
    }

    
  }
  
  # Format data for plotting --------------------------------------------------#
  df.plot <- w.stocks[ , 1 , drop = FALSE]
  rownames(df.plot) <- seq(length = nrow(df.plot))
  
  df.plot$r.equal <- r.equal   # Return series of strategy
  df.plot$r.mktcap <- r.mktcap # Return series of strategy
  df.plot$r.rev <- r.rev       # Return series of strategy
  df.plot$m <- m               # Number of metrics found for strategy
  df.plot$t <- t               # Number of transactions
  df.plot$p <- p               # Number of stocks in portfolio
  
  # Add index -----------------------------------------------------------------#
  load("Indicies2.RData")
  df.plot <- merge(df.plot, w.ix[ , c(1, 13)], all.x = TRUE)
  colnames(df.plot)[ncol(df.plot)] <- "r.index"
  
  df.plot$Equal <- 100 * cumprod(1 + df.plot$r.equal)
  df.plot$MktCap <- 100 * cumprod(1 + df.plot$r.mktcap)
  df.plot$Revenue <- 100 * cumprod(1 + df.plot$r.rev)
  
  df.plot[1,8] <- 0
  df.plot$OSEBX <- 100 * cumprod(1 + df.plot$r.index)
  
  # Add risk-free -------------------------------------------------------------#
  load("Riskfree-Rate.RData")
  df.plot <- merge(df.plot, rf, all.x = TRUE) 
  
  df.plot$r.equal.excess <- df.plot$r.equal - df.plot$rf
  df.plot$r.mktcap.excess <- df.plot$r.mktcap - df.plot$rf
  df.plot$r.rev.excess <- df.plot$r.rev - df.plot$rf
  df.plot$r.index.excess <- df.plot$r.index - df.plot$rf
  
  
  # Gather statistics ---------------------------------------------------------#
  
  # Strategy Equal
  mu.equal <- mean(df.plot$r.equal[-1]) * 12
  mu.ex.equal <- mean(df.plot$r.equal.excess[-1]) * 12
  sd.equal <- sd(df.plot$r.equal[-1]) * sqrt(12)
  sr.equal <- mu.ex.equal / sd.equal
  beta.equal <- cov(df.plot$r.equal[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy MktCap
  mu.mktcap <- mean(df.plot$r.mktcap[-1]) * 12
  mu.ex.mktcap <- mean(df.plot$r.mktcap.excess[-1]) * 12
  sd.mktcap <- sd(df.plot$r.mktcap[-1]) * sqrt(12)
  sr.mktcap <- mu.ex.mktcap / sd.mktcap
  beta.mktcap <- cov(df.plot$r.mktcap[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Strategy Revenue
  mu.rev <- mean(df.plot$r.rev[-1]) * 12
  mu.ex.rev <- mean(df.plot$r.rev.excess[-1]) * 12
  sd.rev <- sd(df.plot$r.rev[-1]) * sqrt(12)
  sr.rev <- mu.ex.rev / sd.rev
  beta.rev <- cov(df.plot$r.rev[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  #Index
  mu.i <- mean(df.plot$r.index[-1]) * 12
  mu.ex.i <- mean(df.plot$r.index.excess[-1]) * 12
  sd.i <- sd(df.plot$r.index[-1]) * sqrt(12)
  sr.i <- mu.ex.i / sd.i
  beta.i <- cov(df.plot$r.index[-1], df.plot$r.index[-1]) / var(df.plot$r.index[-1])
  
  # Jensen
  rf.ann <- mean(df.plot$rf[-1]) * 12
  jens.equal <- mu.equal - (rf.ann + (mu.i - rf.ann) * beta.equal)
  jens.mktcap <- mu.mktcap - (rf.ann + (mu.i - rf.ann) * beta.mktcap)
  jens.rev <- mu.rev - (rf.ann + (mu.i - rf.ann) * beta.rev)
  jens.i <- mu.i - (rf.ann + (mu.i - rf.ann) * beta.i)
  
  # Treynor
  trey.equal <- mu.ex.equal / beta.equal
  trey.mktcap <- mu.ex.mktcap / beta.mktcap
  trey.rev <- mu.ex.rev / beta.rev
  trey.i <- mu.ex.i / beta.i
  
  
  # Stats table
  a <- c(mu.i, sd.i, sr.i, beta.i, jens.i, trey.i)
  b <- c(mu.equal, sd.equal, sr.equal, beta.equal, jens.equal, trey.equal)
  c <- c(mu.mktcap, sd.mktcap, sr.mktcap, beta.mktcap, jens.mktcap, trey.mktcap)
  d <- c(mu.rev, sd.rev, sr.rev, beta.rev, jens.rev, trey.rev)
  stats <- data.frame(a,b,c,d)
  stats <- t(stats)
  stats <- as.data.frame(stats)
  rownames(stats) <- c("Index", "Equal","MktCap","Revenue")
  colnames(stats) <- c("Average Annual Return", "Standard Deviation", "Sharpe Ratio", "Beta", 
                       "Jensen's Alpha", "Treynor's Measure")
  stats <- stats %>% mutate_if(is.numeric, ~round(., 4))
  
  
  # Return objects-------------------------------------------------------------#
  stats <<- stats
  
}


## Load accounting values to choose -------------------------------------------#
load("KeyMetrics.RData")
KeyMetrics

list.p <- KeyMetrics[c(3,4,7,18,19)]
list.s <- KeyMetrics[c(3,4,7,18,19)]
list.l <- KeyMetrics[c(3,4,7,18,19)]
combos <- as.data.frame(expand.grid(list.p, list.s, list.l))
combos <- sapply(combos, as.character)
colnames(combos) <- c("Profitbability", "Liquidity", "Solvency")
rownames(combos) <- 1:nrow(combos)
combos <- as.data.frame(combos)

combos2 <- combos
combos2[combos2 == "D_EPrc"] <- "lowest"
combos2[combos2 != "lowest"] <- "highest"



## Run function ---------------------------------------------------------------#

#combos <- combos[1:5,]
#combos2 <- combos2[1:5,]

DF_TOTAL <- data.frame(AAR = 0, STD = 0, SR = 0, BETA = 0, JENSEN = 0,TREYNOR = 0)
colnames(DF_TOTAL) <- c("Average Annual Return", "Standard Deviation", "Sharpe Ratio", "Beta",
                     "Jensen's Alpha", "Treynor's Measure")

for (i in 1:125) {

  backtest(y = 1,
           x = 10,
           t.cost = 0.02,
           p.ratio = combos[i, 1],
           p.hl = combos2[i, 1],
           s.ratio = combos[i,2],
           s.hl = combos2[i, 2],
           l.ratio = combos[i, 3],
           l.hl = combos2[i, 3],
           l.axis = 100,
           DATE1 = "2000-11-30",
           DATE2 = "2020-11-30")

  DF_TOTAL <- rbind(DF_TOTAL, stats)

  print(i)
}


#save(DF_TOTAL, combos, combos2, file = "ALLCombos.RData")
save(DF_TOTAL, combos, combos2, file = "ALLCombos2.RData")



#load("ALLCombos.RData")
load("ALLCombos2.RData")

df <- DF_TOTAL
df <- df[-1, ]

combos <- combos[rep(seq_len(nrow(combos)), each = 4), ]
combos2 <- combos2[rep(seq_len(nrow(combos2)), each = 4), ]


fr <- cbind(df, combos, combos2)

fr$Weight <- rownames(fr)
#fr[fr == "Index"] <- "OSEBX"
fr <- fr[!grepl("Index", fr$Weight),]
#fr$name <- NULL


fr[fr == "D_EPrc"] <- "D.E"
fr[fr == "CurrentRatio"] <- "C.R"
fr[fr == "InterestCoverageRatio"] <- "I.C.R"
fr[fr == "EBITDAMarginPrc"] <- "E.M"
fr[fr == "NetProfitMarginPrc"] <- "N.P.M"
fr[fr == "OperatingMarginPrc"] <- "O.M"
fr[fr == "QuickRatio"] <- "Q.R"
fr[fr == "highest"] <- "h"
fr[fr == "lowest"] <- "l"

fr$Weight[startsWith(fr$Weight, "Equal")] <- "E"
fr$Weight[startsWith(fr$Weight, "MktCap")] <- "M"
fr$Weight[startsWith(fr$Weight, "Revenue")] <- "R"


rownames(fr) <- seq(length = nrow(fr))
colnames(fr) <- c("AAR", "SD", "Sharpe", "Beta", "Alpha", "Treynor", "FR1", "FR2", "FR3", "HL1", "HL2", "HL3", "W")


fr <- fr[order(-fr$AAR), ]
fr = fr[!duplicated(fr$AAR),]


fr <- fr[order(-fr$Sharpe), ]
rownames(fr) <- seq(length = nrow(fr))

##

fr <- fr[ , -c(10,11,12)]
fr <- fr[ , c(7,8,9,10,1,2,3,4,5,6)]


fr <- fr[!(fr$FR1 == "C.R" & fr$FR2 == "C.R" & fr$FR3 == "C.R"), ]
fr <- fr[!(fr$FR1 == "N.P.M" & fr$FR2 == "N.P.M" & fr$FR3 == "N.P.M"), ]
fr <- fr[!(fr$FR1 == "E.M" & fr$FR2 == "E.M" & fr$FR3 == "E.M"), ]
fr <- fr[!(fr$FR1 == "D.E" & fr$FR2 == "D.E" & fr$FR3 == "D.E"), ]
fr <- fr[!(fr$FR1 == "I.C.R" & fr$FR2 == "I.C.R" & fr$FR3 == "I.C.R"), ]

rownames(fr) <- seq(length = nrow(fr))



xtable(fr, digits = c(0,0,0,0,0,3,3,3,3,3,3), include.rownames = FALSE)

save(fr, file = "FinancialRatios2.RData")



## END








## 16.0 - Format tables used in the paper ----------------------

load("latex.tables.RData")
load("latex.tables.combo.RData")

stats.big <- rbind(stats.ebitda, stats.de, stats.npm, stats.cr, stats.icr, stats.combo)
t.big <- rbind(sum.mpt.ebitda, sum.mpt.de, sum.mpt.npm, sum.mpt.cr, sum.mpt.icr, sum.mpt.combo)

df1 <- as.data.frame(t(gics.mean.t.ebitda))
df2 <- as.data.frame(t(gics.mean.t.de))
df3 <- as.data.frame(t(gics.mean.t.npm))
df4 <- as.data.frame(t(gics.mean.t.cr))
df5 <- as.data.frame(t(gics.mean.t.icr))
df6 <- as.data.frame(t(gics.mean.t.combo))

gics.big <- rbind(df1, df2, df3, df4, df5, df6)



xtable(stats.big, digits = c(0,4,4,4,4,4,4))
xtable(t.big)
xtable(gics.big, digits = c(0,2,2,2,2,2,2,2,2,2,2,2,2))











