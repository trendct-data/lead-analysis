library(stringr)
library(dplyr)
library(lubridate)
library(tidyr)
library(ggplot2)
#schools <- read.csv("school_lead_update.csv", stringsAsFactors=FALSE)

#schools_unique <- schools[!duplicated(schools$Name),]
#schools_unique$Name <- str_to_upper(schools_unique$Name)

#colnames(schools_unique)[colnames(schools_unique) == 'Name'] <- 'name'

#violations_schools <- left_join(actions, schools_unique)
#violations_schools <- violations_schools[!is.na(violations_schools$Town),]

#violations_schools <- subset(violations_schools, rule=="Lead and Copper Rule")

##

violations <- read.csv("data/violation_report.csv", stringsAsFactors=FALSE)
cities <- read.csv("data/cities.csv", stringsAsFactors=FALSE)
violations <- left_join(violations, all, by="PWS.ID")
violations <- left_join(violations, cities, by="city.s.served")

violations_list <- violations %>%
  select(PWS.Name, Contaminant.Name, Rule.Name, 
         Violation.Type, Is.Health.Based, 
         PWS.Type, Population.Served.Count,
          Compliance.Period.Begin.Date,
         Compliance.Period.End.Date, Compliance.Status,
         RTC.Date, Is.Major.Violation, address,
         link, towns.served)

write.csv(violations_list, "data/violations_joined.csv")


##
v_count <- violations_list %>%
  group_by(Contaminant.Name, Is.Major.Violation) %>%
  summarise(Count=n())

compliance_count <- violations_list %>%
  group_by(Compliance.Status) %>%
  summarise(Count=n())

violations_list$date <- dmy(violations_list$RTC.Date)
violations_list$year <- year(violations_list$date)

v_year <- violations_list %>%
  group_by(year) %>%
  summarise(Returned.to.compliance=n())
colnames(v_year) <- c("year", "Returned.to.compliance")


violations_list$begin.date <- dmy(violations_list$Compliance.Period.Begin.Date)
violations_list$begin.year <- year(violations_list$begin.date)

begin_year <- violations_list %>%
  group_by(begin.year) %>%
  summarise(Compliance.began=n())
colnames(begin_year) <- c("year", "Compliance.begin")

violations_list$end.date <- dmy(violations_list$Compliance.Period.End.Date)
violations_list$end.year <- year(violations_list$end.date)

end_year <- violations_list %>%
  group_by(end.year) %>%
  summarise(Compliance.end=n())

colnames(end_year) <- c("year", "Compliance.end")

violations_by_year <- left_join(begin_year, end_year)
violations_by_year <- left_join(violations_by_year, v_year)

violations_by_year <- gather(violations_by_year, "type", "violations", 2:4)
violations_by_year$type <- as.factor(violations_by_year$type)

ggplot(violations_by_year, aes(x=year, y=violations, group=type, colour=type)) +
  geom_line() +
  geom_point()

#ggplot(violations_by_year, aes(x=year, y=violations, fill=type)) +
#  geom_bar(stat="identity", position=position_dodge())


major_year <- violations_list %>%
  group_by(end.year, Is.Major.Violation) %>%
  summarise(major=n())

ggplot(major_year, aes(x=end.year, y=major, group=Is.Major.Violation, colour=Is.Major.Violation)) +
  geom_line() +
  geom_point()

## bar chart/mostest

most_system <- violations_list %>%
  group_by(PWS.Name) %>%
  summarise(violations=n()) %>%
  arrange(-violations)

# most_system <- most_system[1:10,]

most_system_y <- violations_list %>%
  filter(Is.Health.Based=="Y") %>%
  group_by(PWS.Name) %>%
  summarise(health.based.violations=n()) %>%
  arrange(-health.based.violations)


most_system_n <- violations_list %>%
  filter(Is.Health.Based=="N") %>%
  group_by(PWS.Name) %>%
  summarise(health.based.violations_n=n()) %>%
  arrange(-health.based.violations_n)

systems_most <- left_join(most_system, most_system_y)
systems_most <- left_join(systems_most, most_system_n)



compliance_system_r <- violations_list %>%
  filter(Compliance.Status=="Returned to Compliance") %>%
  group_by(PWS.Name) %>%
  summarise(complied=n()) %>%
  arrange(-complied)

compliance_system_k <- violations_list %>%
  filter(Compliance.Status=="Known") %>%
  group_by(PWS.Name) %>%
  summarise(known=n()) %>%
  arrange(-known)

systems_most <- left_join(systems_most, compliance_system_r)
systems_most <- left_join(systems_most, compliance_system_k)

systems_most$percent.health.based <- round(systems_most$health.based.violations/systems_most$violations*100,2)
systems_most$percent.complied <- round(systems_most$complied/systems_most$violations*100,2)

systems_most <- systems_most[c("PWS.Name", "violations", "percent.health.based", "percent.complied")]
colnames(systems_most) <- c("name", "violations", "percent.health.based", "percent.complied")

systems_most <- left_join(systems_most, all_links_only)
systems_most$system <- paste0("<a href='", systems_most$link, "' target='_blank'>", systems_most$name, "</a>")
systems_most <- systems_most[c("system", "violations", "percent.health.based", "percent.complied")]
systems_most <- data.frame(systems_most)
library(trendct)

fancytable(systems_most, headline = "Drinking water system violations in Connecticut", subhead = "Since 2000.", height = 400,
           paging = "false", sourceline = "U.S. EPA, Safe Drinking Water Information System", byline = "Andrew Ba Tran/TrendCT.org", col = 0,
           desc_asc = "desc")

violations_rule <- violations %>%
  group_by(Rule.Name) %>%
  summarise(Count=n()) %>%
  arrange(-Count)
violations_rule <- violations_rule[1:10,]

violations_type <- violations %>%
  group_by(Violation.Type) %>%
  summarise(Count=n()) %>%
  arrange(-Count)
violations_type <- violations_type[1:10,]

violations_rule <- data.frame(violations_rule)
trendchart(violations_rule, headline = "10 most-frequent drinking water violation by rule", subhead = "ANDREW BA TRAN/TRENDCT.ORG", src = "U.S. EPA, Safe Drinking Water Information System",
           byline = "Andrew Ba Tran/TrendCT.org", type = "bar", xTitle = "", yTitle = "",
           xSuffix = "", ySuffix = "", xPrefix = "", yPrefix = "", option = "")

violations_type <- data.frame(violations_type)
trendchart(violations_type, headline = "10 most-frequent drinking water violation by type", subhead = "ANDREW BA TRAN/TRENDCT.ORG", src = "U.S. EPA, Safe Drinking Water Information System",
           byline = "Andrew Ba Tran/TrendCT.org", type = "bar", xTitle = "", yTitle = "",
           xSuffix = "", ySuffix = "", xPrefix = "", yPrefix = "", option = "")
