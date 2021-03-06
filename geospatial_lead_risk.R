# Replicating Vox risk of lead by census block
# This is the raw script. For a thorough walkthrough, visit http://trendct.github.io/data/2016/03/lead-analysis/geospatial_lead_risk.html

library(dplyr)
library(scales)
require(rgdal)
require(ggmap)
require(Cairo)
require(maptools)
library(ggplot2)
#devtools::install_github("hrecht/censusapi")
library(censusapi)
source("keys.R")

housing <- getCensus(name="acs5", 
                      vintage=2014,
                      key=censuskey, 
                      vars=c("NAME", "B25034_001E", "B25034_002E", "B25034_003E", 
                             "B25034_004E","B25034_005E","B25034_006E","B25034_007E",
                             "B25034_008E","B25034_009E","B25034_010E", "B17004_001E"
                             ), 
                      region="tract:*", regionin="state:09")

# S1701 is not accessible via the Census API but I found the equivalent in B06012

poverty <- getCensus(name="acs5", 
                      vintage=2014,
                      key=censuskey, 
                      vars=c("NAME", "B06012_001E", "B06012_002E"
                      ), 
                      region="tract:*", regionin="state:09")

old <- housing

old$age_39 <- old$B25034_010E * .68
old$age40_59 <- (old$B25034_009E + old$B25034_008E) * .43
old$age60_79 <- (old$B25034_007E + old$B25034_006E) * .08
old$age80_99 <- (old$B25034_005E + old$B25034_004E) * .03
old$age00_10 <- (old$B25034_003E + old$B25034_002E) * 0
old$total <-  old$B25034_001E

old$risk_sum <- old$age_39 + old$age40_59 + old$age60_79 + old$age80_99 + old$age80_99 + old$age00_10
old$risk <- old$risk_sum/old$total*100
old <- subset(old, total>0)

# Poverty

poverty$percent_poverty <- poverty$B06012_002E/poverty$B06012_001E * 100
poverty <- subset(poverty, B06012_001E>0)

# Z score
# (x-mean(x))/sd(x)

poverty$z_poverty <- (poverty$percent_poverty - mean(poverty$percent_poverty))/sd(poverty$percent_poverty)
old$z_housing <-  (old$risk - mean(old$risk))/sd(old$risk)

# Calcuating weighted figures

poverty$weighted_poverty <- poverty$z_poverty * .42
old$weighted_housing <- old$z_housing * .58

# join dataframes

poverty$tract_id <- paste0(poverty$state, poverty$county, poverty$tract)
old$tract_id <- paste0(old$state, old$county, old$tract)

old <- old[c("tract_id", "risk", "z_housing", "weighted_housing")]
#colnames(old) <- c("tract_id", "risk", "z_housing", "weighted_housing")

df <- left_join(poverty, old)

df$riskscore_raw <- df$weighted_housing + df$weighted_poverty

# calculating deciles on risk score

df <- mutate(df, quantile = ntile(riskscore_raw, 10))
df$id <- df$tract

gpclibPermit()
gpclibPermitStatus()
censustracts <- readOGR(dsn="maps/census_tracts/wgs84", layer="tractct_37800_0000_2010_s100_census_1_shp_wgs84")
censustracts_only <- censustracts
censustracts <- fortify(censustracts, region="TRACTCE10")

risk_map <- left_join(censustracts, df)

dtm_df <- ggplot() +
  geom_polygon(data = risk_map, aes(x=long, y=lat, group=group, fill=quantile), color = "black", size=0.2) +
  coord_map() +
  scale_fill_distiller(type="seq", trans="reverse", palette = "Reds", breaks=pretty_breaks(n=10)) +
  theme_nothing(legend=TRUE) +
  labs(title="Estimated lead risk", fill="")
