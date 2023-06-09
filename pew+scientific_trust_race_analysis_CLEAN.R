library(readstata13)
library(ggplot2)
library(reshape2)
library(plyr)
library(margins)
library(descr)
library(sandwich)
library(pscl)
library(psych)
library(effects)
library(multiwayvcov)
library(mirt)
library(moments)

#setwd("/Users/caalgara/OneDrive - University of Texas at El Paso/Research/COVID19 & Trust/Analysis")

###### Data Wrangling ####

# Load Pew Data

setwd("E:/Dropbox/Race_Scientific_Knowledge_Revision/")

pew <- read.dta13("E:/Dropbox/Race_Scientific_Knowledge_Revision/ATP_W64.dta")
pew <- subset(pew,select=c(QKEY,COVID_COMFORT_a_W64,COVID_COMFORT_b_W64,COVID_COMFORT_c_W64,COVID_COMFORT_d_W64,COVID_COMFORT_e_W64,COVID_RESTRICTION_a_W64,COVID_RESTRICTION_b_W64,COVID_RESTRICTION_c_W64,COVID_RESTRICTION_d_W64,COVID_RESTRICTION_e_W64,COVID_RESTRICTION_f_W64,COVID_RESTRICTION_g_W64,F_IDEO,F_PARTY_FINAL,F_SEX,F_AGECAT,F_EDUCCAT2,F_MARITAL,F_INCOME,F_CREGION,F_RACETHN,WEIGHT_W64))

# Code & Scale Ideological DV of interest (policy support)

covid_ideo_scales <- subset(pew,select=c(QKEY,COVID_RESTRICTION_a_W64,COVID_RESTRICTION_b_W64,COVID_RESTRICTION_c_W64,COVID_RESTRICTION_d_W64,COVID_RESTRICTION_e_W64,COVID_RESTRICTION_f_W64,COVID_RESTRICTION_g_W64,F_IDEO))
colnames(covid_ideo_scales) <- c("QKEY","restriction_intl_travel","restriction_most_business","restriction_large_gatherings","restriction_sporting_events","restriction_closing_k12","restriction_carry_out_only","restriction_postponing_primary","libcon")

for(i in 2:ncol(covid_ideo_scales)){
  covid_ideo_scales[,i] <- as.character(covid_ideo_scales[,i])
}
covid_ideo_scales[covid_ideo_scales == "Necessary"] <- 1
covid_ideo_scales[covid_ideo_scales == "Unnecessary"] <- 0

covid_ideo_scales$libcon <- ifelse(covid_ideo_scales$libcon %in% "Very conservative",1,ifelse(covid_ideo_scales$libcon %in% "Conservative",2,ifelse(covid_ideo_scales$libcon %in% "Moderate",3,ifelse(covid_ideo_scales$libcon %in% "Liberal",4,ifelse(covid_ideo_scales$libcon %in% "Liberal",4,ifelse(covid_ideo_scales$libcon %in% "Very liberal",5,NA))))))

for(i in 2:ncol(covid_ideo_scales)){
  covid_ideo_scales[,i] <- as.numeric(covid_ideo_scales[,i])
}
covid_ideo_scales <- na.omit(covid_ideo_scales)


# Factor Analysis (policy support)

library("FactoMineR")
library("factoextra")

x <- covid_ideo_scales[,c(2:9)]
for(i in 1:8){
  x[,i] <- factor(x[,i])
}

factanal <- FAMD(x, graph = F,ncp=7,sup.var = NULL)
fviz_screeplot(factanal)
fviz_contrib(factanal, "var", axes = 1)
fviz_contrib(factanal, "var", axes = 2)
fviz_contrib(factanal, "var", axes = 3)
fviz_famd_var(factanal, "var", repel = TRUE, col.var = "black")

factanal <- fa(covid_ideo_scales[,c(2:9)], nfactors=2, rotate="promax", fm="pa")
scores <- data.frame(factanal$scores)
loadings(factanal)
loadings <- factanal$loadings
loadings <- data.frame(f1 = loadings[,1],f2=loadings[,2])

plot(factanal$loadings,type="n") # set up plot 
text(factanal$loadings,labels=names(covid_ideo_scales)[2:9],cex=.7) # add variable names

library(ggrepel)

alpha(covid_ideo_scales[,c(2:9)])

library(grid)
library(gridExtra)
loadings$vars <- ifelse(rownames(loadings) %in% "restriction_intl_travel","International Travel",ifelse(rownames(loadings) %in% "restriction_most_business","Most Businesses",ifelse(rownames(loadings) %in% "restriction_large_gatherings","Large Gatherings",ifelse(rownames(loadings) %in% "restriction_sporting_events","Sporting Events",ifelse(rownames(loadings) %in% "restriction_closing_k12","K-12 Schools",ifelse(rownames(loadings) %in% "restriction_carry_out_only","Carry-out Only",ifelse(rownames(loadings) %in% "restriction_postponing_primary","Postponing Primary",ifelse(rownames(loadings) %in% "libcon","Left-Right Ideology",NA))))))))

plot <- ggplot(loadings,aes(x = f1, y=f2,label=vars)) + theme_minimal() + geom_label_repel() + scale_x_continuous("First Dimension Factor (Proportion of Variance: 36%)") + scale_y_continuous("Second Dimension Factor (Propoportion of Variance 4%)") + geom_segment(aes(x = 0,y = 0,xend = f1,yend = f2),arrow=arrow()) 
grid.newpage()
footnote <- expression("Cronbach's Standardized"~alpha~"="~0.78)
g <- arrangeGrob(plot, bottom = textGrob(footnote, x = 0.025, hjust = 0, vjust= 0, y=0.75, gp = gpar(fontface = "italic", fontsize = 9, col = "black")))
grid.draw(g)
ggsave(file="factor_analysis_covid19_policies.png", g, width = 8, height = 5.43, units = "in")

covid_ideo_scales <- cbind(covid_ideo_scales,scores)
colnames(covid_ideo_scales)[10:11] <- c("covid_restriction_fa_dim1","covid_restriction_fa_dim2")
covid_ideo_scales$summated_restriction_scale <- rowSums(covid_ideo_scales[2:8],na.rm=T)

# IRT

irt <- mirt(covid_ideo_scales[2:8], model = 1, itemtype = "graded", SE = T, verbose = T,removeEmptyRows = TRUE)
plt <- plot(irt, type = 'trace', facet_items=F) #store the object
print(plt) #plot the object
str(plt) #find the data
pltdata <- data.frame(lapply(plt$panel.args, function(x) do.call(cbind, x))[[1]])

groups <- plot(irt, type = 'trace', facet_items=T)
groups$packet.sizes
pltdata$item <- rep(colnames(covid_ideo_scales)[2:8], each = 200)
pltdata$response <- groups$panel.args.common$groups

plt$panel.args.common$groups

pltdata$item2 <- factor(pltdata$item,levels=c("restriction_carry_out_only","restriction_closing_k12","restriction_intl_travel","restriction_large_gatherings","restriction_most_business","restriction_postponing_primary","restriction_sporting_events"),labels=c("Carry Out Only","Close K-12 Schools","Restrict Intl. Travel","Restrict Large Gatherings","Restrict Most Businesses","Postpone Primary Elections","Restrict Sporting Events"))

pltdata$item2 <- factor(pltdata$item2,levels=c("Restrict Intl. Travel","Restrict Sporting Events","Close K-12 Schools","Restrict Large Gatherings","Carry Out Only","Restrict Most Businesses","Postpone Primary Elections"))

plot <- ggplot(pltdata, aes(x, y,linetype=item2,color=item2)) + geom_line() + scale_x_continuous(expression(theta)) + scale_y_continuous("Pr (Support)") + geom_hline(aes(yintercept = 0.5))  + theme_minimal() + labs(color="Policy",linetype="Policy") + theme(legend.position="bottom") #+ scale_colour_grey(start = 0, end = .5) + ggtitle("Ordinal IRT Model Characteric Curves for Emphatic Racism Scale")
#ggsave(file="covid19_restrictions_irt_curves_probs.png", plot, width = 8, height = 5.43, units = "in")

# Scores

covid_ideo_scales$covid_restriction_fa_dim2 <- fscores(irt, full.scores = TRUE, full.scores.SE = F)
colnames(covid_ideo_scales)[11] <- "covid_restriction_irt"

pew <- merge(pew,covid_ideo_scales,by=c("QKEY"),all=T)
pew$covid_restriction_fa_dim1 <- pew$covid_restriction_fa_dim1-mean(pew$covid_restriction_fa_dim1,na.rm=T)

# Covariates

pew$female <- as.character(pew$F_SEX)
pew$female <- factor(pew$female,levels=c("Male","Female"))

ggplot(na.omit(pew),aes(x=female,y=covid_restriction_fa_dim1)) + geom_boxplot()

pew$pid3 <- as.character(pew$F_PARTY_FINAL)
pew$pid3 <- factor(pew$pid3,levels=c("Republican","Independent","Democrat"))

pew$weight <- as.numeric(pew$WEIGHT_W64)

pew$age_linear <- as.numeric(factor(pew$F_AGECAT))
pew$age_linear[pew$age_linear %in% 5] <- NA # Get rid of refused

pew$educ_linear <- as.numeric(factor(pew$F_EDUCCAT2))
pew$educ_linear[pew$educ_linear %in% 7] <- NA # Get rid of refused

pew$marital_status <- ifelse(pew$F_MARITAL %in% "Married",1,0)
pew$marital_status[pew$F_MARITAL %in% "Refused"] <- NA # Get rid of refused

pew$income_linear <- as.numeric(factor(pew$F_INCOME))
pew$income_linear[pew$income_linear %in% 10] <- NA # Get rid of refused

pew$region_factor <- pew$F_CREGION
pew$white_respondent <- ifelse(pew$F_RACETHN %in% "White non-Hispanic",1,0)
pew$white_respondent[pew$F_RACETHN %in% "Refused"] <- NA # Get rid of refused

hold <- read.dta13("E:/Dropbox/Race_Scientific_Knowledge_Revision/ATP_W42.dta")
hold <- hold[,c("QKEY", "F_RACECMB")]

pew <- merge(pew,hold,by=c("QKEY"),all=T)

pew$race3 <- ifelse(pew$F_RACETHN %in% "White non-Hispanic","white",ifelse(pew$F_RACETHN %in% "Black non-Hispanic","black",ifelse(pew$F_RACETHN %in% "Hispanic","hispanic",NA)))
pew$race3 <- ifelse(is.na(pew$race3) & pew$F_RACECMB %in% "Asian or Asian-American","asian",pew$race3)

pew$race3 <- factor(pew$race3,levels=c("white","black","hispanic","asian"))

# Trust

trust <- read.dta13("E:/Dropbox/Race_Scientific_Knowledge_Revision/ATP_W42.dta")
trust <- subset(trust,select=c("QKEY","CONFa_W42","CONFb_W42","CONFd_F1_W42","CONFd_F2_W42", "POLICY1_W42","POLICY2_W42","POLICY3_W42","SCM2_W42","SCM3_W42","SCM4a_W42","SCM4b_W42"))

colnames(trust) <- c("QKEY","trust_elected_officials","trust_media","trust_medial_scientists","trust_scientists","scientists_active_role_policy","scientists_pivotal_policy","scientists_better_policy","scientific_method","scientists_judgement_facts","research_essential_immediate_applications","research_essential_advance_knowledge")

trust[trust == "Refused"] <- NA

for(i in 2:ncol(trust)){
  print(table(trust[,i]))
  print(levels(trust[,i]))
}
for(i in 2:ncol(trust)){
  trust[,i] <- as.character(trust[,i])
  print(table(trust[,i]))
}  
trust[trust == "Essential"] <- 4
trust[trust == "Important, but not essential"] <- 3
trust[trust == "Not too important"] <- 2
trust[trust == "Not important at all"] <- 1

trust[trust == "A great deal of confidence"] <- 4
trust[trust == "A fair amount of confidence"] <- 3
trust[trust == "Not too much confidence"] <- 2
trust[trust == "No confidence at all"] <- 1

trust[trust == "Scientists should take an active role in public policy debates about scientific issues"] <- 2
trust[trust == "Scientists should focus on establishing sound scientific facts and stay out of public policy debates"] <- 1

trust[trust == "Public opinion should NOT play an important role to guide policy decisions about scientific issues because these issues"] <- 2
trust[trust == "Public opinion should play an important role to guide policy decisions about scientific issues"] <- 1

trust[trust == "Usually BETTER at making good policy decisions about scientific issues than other people"] <- 3
trust[trust == "NEITHER BETTER NOR WORSE at making good policy decisions about scientific issues than other people"] <- 2
trust[trust == "Usually WORSE at making good policy decisions about scientific issues than other people"] <- 1

trust[trust == "The scientific method generally produces accurate conclusions"] <- 2
trust[trust == "The scientific method can be used to produce any conclusion the researcher wants"] <- 1

trust[trust == "Scientists make judgments based solely on the facts"] <- 2
trust[trust == "Scientists' judgments are just as likely to be biased as other people's"] <- 1

trust$trust_scientists <- ifelse(is.na(trust$trust_medial_scientists),trust$trust_scientists,ifelse(is.na(trust$trust_scientists),trust$trust_medial_scientists,NA))

trust$trust_medial_scientists <- NULL
trust$scientists_pivotal_policy <- NULL

for(i in 2:ncol(trust)){
  trust[,i] <- as.numeric(trust[,i])
  print(table(trust[,i]))
}  

factanal <- fa(trust[,c(4:10)], nfactors=2, rotate="promax", fm="pa")
scores <- data.frame(factanal$scores)
loadings(factanal)
loadings <- factanal$loadings
loadings <- data.frame(f1 = loadings[,1],f2=loadings[,2])

plot(factanal$loadings,type="n") # set up plot 
text(factanal$loadings,labels=names(trust)[4:10],cex=.7) # add variable names

library(ggrepel)

alpha(trust[,c(4:8)])
skewness(loadings$f1, na.rm=T)
kurtosis(loadings$f1, na.rm=T)

alpha(trust[,c(9:10)])
skewness(loadings$f2, na.rm=T)
kurtosis(loadings$f2, na.rm=T)

loadings$vars <- ifelse(rownames(loadings) %in% "trust_scientists","Trust Scientists",ifelse(rownames(loadings) %in% "scientists_active_role_policy","Scientists Active Role Policy",ifelse(rownames(loadings) %in% "scientists_pivotal_policy","PO Guiding Policy Science",ifelse(rownames(loadings) %in% "scientists_better_policy","Scientists Better Policymakers",ifelse(rownames(loadings) %in% "scientific_method","Scientific Method Validity",ifelse(rownames(loadings) %in% "scientists_judgement_facts","Unbiased Scientists",ifelse(rownames(loadings) %in% "research_essential_immediate_applications","Research Essential Applications",ifelse(rownames(loadings) %in% "research_essential_advance_knowledge","Research Essential Knowledge",NA))))))))

plot <- ggplot(loadings,aes(x = f1, y=f2,label=vars)) + theme_minimal() + geom_label_repel() + scale_x_continuous("First Dimension Factor") + scale_y_continuous("Second Dimension Factor") + geom_segment(aes(x = 0,y = 0,xend = f1,yend = f2),arrow=arrow())  # (Proportion of Variance F1: 18%) (Propoportion of F2 Variance 16%)"
grid.newpage()
footnote <- expression("Cronbach's Standardized"~alpha~"="~0.66)
g <- arrangeGrob(plot, bottom = textGrob(footnote, x = 0.025, hjust = 0, vjust= 0, y=0.75, gp = gpar(fontface = "italic", fontsize = 9, col = "black")))
grid.draw(g)
#ggsave(file="factor_analysis_scientific_trust.png", g, width = 8, height = 5.43, units = "in")

trust <- cbind(trust,scores)
colnames(trust)[11:12] <- c("trust_scientists_fa_dim1","trust_scientists_fa_dim2")

pew <- merge(pew,trust,by=c("QKEY"),all=T)

x <- subset(pew,select=c(pid3,trust_scientists_fa_dim1,trust_scientists_fa_dim2))
x <- na.omit(x)
x$pid <- ifelse(x$pid3 %in% "Democrat","D",ifelse(x$pid3 %in% "Republican","R",ifelse(x$pid3 %in% "Independent","I",NA)))

plot <- ggplot(x,aes(x=trust_scientists_fa_dim1,y=trust_scientists_fa_dim2,label=pid,color=pid)) + geom_text(alpha=0.2) + scale_color_manual("",values=c("blue","purple","red"))

x1 <- x
x1$pid3 <- "Full Sample"
x <- rbind(x,x1)
x$pid3 <- factor(x$pid3,levels=c("Republican","Independent","Democrat","Full Sample"),labels=c("Republican Partisans","Independent Partisans","Democratic Partisans","Full Sample"))

print(summary(aov(trust_scientists_fa_dim1 ~ pid3, data = x)))

plot <- ggplot(x, aes(x=pid3,y=trust_scientists_fa_dim1, group=pid3,fill=pid3)) + geom_boxplot(alpha=0.2) + theme_minimal() + scale_y_continuous("Latent Scientific Trust") + scale_x_discrete("") + scale_fill_manual("",values=c("red","purple","blue","black")) + theme(legend.position = "none") 
#ggsave(file="scientific_trust_boxplots_by_party.png", plot, width = 8, height = 5.43, units = "in")

###### Data Analysis: COVID Policy ~ Scientific Trust: Baseline Effects ####

# Baseline Trust Effects

baseline_trust_effects <- list()
for(i in which(colnames(pew) == "restriction_intl_travel"):which(colnames(pew) == "restriction_postponing_primary")){
  summary(model <- glm(pew[,i] ~ trust_scientists_fa_dim1 + trust_media + trust_elected_officials + female + pid3 + libcon + age_linear + educ_linear + income_linear + race3 + region_factor, data=pew, weights=weight, family = binomial(link = "logit")))
  mes <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"), type="response", change="minmax"))
  mes$model <- colnames(pew)[i]
  mes$category <- "Full Sample Baseline"
  baseline_trust_effects[[i]] <- mes
}
baseline_trust_effects <- ldply(baseline_trust_effects,data.frame)

baseline_trust_effects$pid3 <- "Full Baseline Sample"
baseline_trust_effects$category <- NULL

effects <- baseline_trust_effects
effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))
effects$model2 <- ifelse(effects$model %in% "restriction_carry_out_only","Dependent Variable: Restaurants Carry Out Only",ifelse(effects$model %in% "restriction_closing_k12","Dependent Variable: Close K-12 Schools",ifelse(effects$model %in% "restriction_intl_travel","Dependent Variable: Restrict International Travel",ifelse(effects$model %in% "restriction_large_gatherings","Dependent Variable: Restrict Large Gatherings",ifelse(effects$model %in% "restriction_most_business","Dependent Variable: Restrict Most Businesses",ifelse(effects$model %in% "restriction_postponing_primary","Dependent Variable: Postpone Primary Elections",ifelse(effects$model %in% "restriction_sporting_events","Dependent Variable: Restrict Sporting Events",NA)))))))
effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))

effects$label <- ifelse(effects$p < 0.01,paste(round(effects$AME,2),"***",sep=""),ifelse(effects$p < 0.05,paste(round(effects$AME,2),"**",sep=""),ifelse(effects$p < 0.10,paste(round(effects$AME,2),"*",sep=""),NA)))

for(i in unique(effects$model)){
  x <- subset(effects,effects$model %in% i)
  plot <- ggplot(x,aes(x=factor,y=AME,factor=factor,group=factor,color=factor,shape=factor,label=label,fill=factor)) + facet_wrap(~model2) + coord_flip() + geom_linerange(aes(x= factor, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= factor, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Pr(Necessary Government Policy)") + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "none") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + geom_label(vjust=-0.5,hjust=0.25,fill="white") + labs(caption="* p < 0.1; ** p < 0.05; *** p < 0.01") + scale_shape_manual("",values=c(23,22,21))
  print(plot)
  #ggsave(file=paste(i,"_model",".png",sep=""), plot, width = 8, height = 5.43, units = "in")
}




###### Data Analysis Figures: OLS Composite Models ####

summary(model <- glm(covid_restriction_irt ~ trust_scientists_fa_dim1 + trust_media + trust_elected_officials + female + libcon + age_linear + educ_linear + income_linear + race3 + region_factor, data=pew, weights=weight, family = gaussian(identity)))
baseline_trust_effects.2 <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"), type="response", change="minmax"))
baseline_trust_effects.2$model <- "DV: Latent Policy Scale"
baseline_trust_effects.2$pid3 <- "Full Sample"

effects <- baseline_trust_effects.2
effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))
effects$ame_label <- round(effects$AME,2)
effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))
effects$label <- ifelse(effects$p < 0.01,paste(round(effects$AME,2),"***",sep=""),ifelse(effects$p < 0.05,paste(round(effects$AME,2),"**",sep=""),ifelse(effects$p < 0.10,paste(round(effects$AME,2),"*",sep=""),NA)))

plot <- ggplot(effects,aes(x=factor,y=AME,factor=factor,group=factor,color=factor,shape=factor,label=label,fill=factor)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= factor, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= factor, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Latent Necessary Government Policies")  + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "none") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + geom_label(vjust=-0.5,hjust=0.25,fill="white") + labs(caption="* p < 0.1; ** p < 0.05; *** p < 0.01") + scale_shape_manual("",values=c(23,22,21))
#ggsave(file="latent_policy_scale_model.png", plot, width = 8, height = 5.43, units = "in")

summary(model <- glm(summated_restriction_scale ~ trust_scientists_fa_dim1 + trust_media + trust_elected_officials + female + libcon + age_linear + educ_linear + income_linear + race3 + region_factor, data=pew, weights=weight, family = "poisson"))
baseline_trust_effects.3 <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"), type="response", change="minmax"))
baseline_trust_effects.3$model <- "DV: Summated Policy Scale"
baseline_trust_effects.3$pid3 <- "Full Sample"

effects <- baseline_trust_effects.3
effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))
effects$ame_label <- round(effects$AME,2)
effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))
effects$label <- ifelse(effects$p < 0.01,paste(round(effects$AME,2),"***",sep=""),ifelse(effects$p < 0.05,paste(round(effects$AME,2),"**",sep=""),ifelse(effects$p < 0.10,paste(round(effects$AME,2),"*",sep=""),NA)))

plot <- ggplot(effects,aes(x=factor,y=AME,factor=factor,group=factor,color=factor,shape=factor,label=label)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= factor, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= factor, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Number of Necessary Government Policies")  + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "none") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + geom_label(vjust=-0.5,hjust=0.25,fill="white") + labs(caption="* p < 0.1; ** p < 0.05; *** p < 0.01") + scale_shape_manual("",values=c(23,22,21))
print(plot)
#ggsave(file="summated_policy_scale_model.png", plot, width = 8, height = 5.43, units = "in")

# Distribution of Summated Rating Scales

x <- subset(pew,select=c(summated_restriction_scale,trust_scientists_fa_dim1,pid3,trust_media,trust_elected_officials,female,libcon,age_linear,educ_linear,income_linear,white_respondent,region_factor,race3))
x1 <- na.omit(x)
x <- na.omit(x)
x1$race3 <- "Full Sample"

x <- subset(x,select=c(summated_restriction_scale,race3))
x$n <- 1
xs <- ddply(x,.(summated_restriction_scale,race3),summarise,total=sum(n,na.rm=T))
x <- ddply(x,.(race3),summarise,total_race3=sum(n,na.rm=T))
xs <- merge(xs,x,by=c("race3"))
xs$prop <- xs$total/xs$total_race3

x1 <- subset(x1,select=c(summated_restriction_scale,race3))
x1$n <- 1
xs1 <- ddply(x1,.(summated_restriction_scale),summarise,total=sum(n,na.rm=T))
xs1$total_race3 <- sum(x1$n,na.rm=T)
xs1$prop <- xs1$total/xs1$total_race3
xs1$race3 <- "Full Sample"

x <- rbind(xs,xs1)
x$race3 <- factor(x$race3,levels=c("asian","black","hispanic","white","Full Sample"),labels=c("Asian Respondents","Black Respondents","Hispanic Respondents","White Respondents","Full Sample"))

plot <- ggplot(x, aes(x=factor(summated_restriction_scale), y=prop, label=round(prop,2))) + geom_point(stat='identity', size=6*1.25) + geom_segment(aes(y=0,x=factor(summated_restriction_scale),yend=prop,xend=factor(summated_restriction_scale)))+ geom_text(color="white", size=2*1.25) + coord_flip() + facet_wrap(~race3) + theme_minimal() + theme(legend.position = "none") + scale_x_discrete("Number of Restrictive COVID-19 Policies Necessary") + scale_y_continuous("Proportion of Respondents")
#ggsave(file="number_policies_dotplot.png", plot, width = 8, height = 5.43, units = "in")


##### Conditioned by Race ######

###### Data Analysis: COVID Policy ~ Scientific Trust: Baseline Effects ####

# Baseline Trust Effects

baseline_trust_effects.race <- list()
for(i in which(colnames(pew) == "restriction_intl_travel"):which(colnames(pew) == "restriction_postponing_primary")){
  summary(model <- glm(pew[,i] ~ trust_scientists_fa_dim1*race3 + trust_media + trust_elected_officials + female + pid3 + libcon + age_linear + educ_linear + income_linear + region_factor, data=pew, weights=weight, family = binomial(link = "logit")))
  mes <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"),at=list(race3=c("asian","black","white","hispanic")), type="response", change="minmax",))
  mes$model <- colnames(pew)[i]
  mes$category <- "Full Sample Baseline"
  baseline_trust_effects.race[[i]] <- mes
}
baseline_trust_effects.race <- ldply(baseline_trust_effects.race,data.frame)


effects <- baseline_trust_effects.race
effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))
effects$model2 <- ifelse(effects$model %in% "restriction_carry_out_only","Dependent Variable: Restaurants Carry Out Only",ifelse(effects$model %in% "restriction_closing_k12","Dependent Variable: Close K-12 Schools",ifelse(effects$model %in% "restriction_intl_travel","Dependent Variable: Restrict International Travel",ifelse(effects$model %in% "restriction_large_gatherings","Dependent Variable: Restrict Large Gatherings",ifelse(effects$model %in% "restriction_most_business","Dependent Variable: Restrict Most Businesses",ifelse(effects$model %in% "restriction_postponing_primary","Dependent Variable: Postpone Primary Elections",ifelse(effects$model %in% "restriction_sporting_events","Dependent Variable: Restrict Sporting Events",NA)))))))
effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))
effects$race3 <- factor(effects$race3,levels=c("asian","black","white","hispanic"), labels=c("Asian Respondents","Black Respondents","White Respondents","Hispanic Respondents"))

for(i in unique(effects$model)){
  x <- subset(effects,effects$model %in% i)
  plot <- ggplot(x,aes(x=race3,y=AME,factor=factor,group=factor,color=factor,shape=factor)) + facet_wrap(~model2) + coord_flip() + geom_linerange(aes(x= race3, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= race3, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Pr(Necessary Government Policy)") + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "bottom") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + scale_shape_manual("Trust Effects",values=c(23,22,21))
  print(plot)
  #ggsave(file=paste(i,"_race3_model",".png",sep=""), plot, width = 8, height = 5.43, units = "in")
}

###### Data Analysis Figures: OLS Composite Models ####

summary(model <- glm(covid_restriction_irt ~ trust_scientists_fa_dim1*race3 + trust_media*race3 + trust_elected_officials*race3 + female + libcon + age_linear + educ_linear + income_linear + region_factor, data=pew, weights=weight, family = gaussian(identity)))
baseline_trust_effects.4 <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"),at=list(race3=c("asian","white","black","hispanic")), type="response", change="minmax"))
baseline_trust_effects.4$model <- "DV: Latent Policy Scale"
baseline_trust_effects.4$pid3 <- "Full Sample"

effects <- baseline_trust_effects.4
effects$race3 <- factor(effects$race3,levels=c("asian","black","white","hispanic"), labels=c("Asian Respondents","Black Respondents","White Respondents","Hispanic Respondents"))

effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))

effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))

plot <- ggplot(effects,aes(x=race3,y=AME,factor=factor,group=factor,color=factor,shape=factor)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= race3, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= race3, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Latent Policy Restriction Scale") + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "bottom") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + scale_shape_manual("Trust Effects",values=c(23,22,21))
print(plot)
#ggsave(file="latent_policy_scale_race3_model.png", plot, width = 8, height = 5.43, units = "in")

summary(model <- glm(summated_restriction_scale ~ trust_scientists_fa_dim1*race3 + trust_media*race3 + trust_elected_officials*race3 + female + libcon + age_linear + educ_linear + income_linear + region_factor, data=pew, weights=weight, family = gaussian(identity)))
baseline_trust_effects.5 <- summary(margins(model, variables=c("trust_scientists_fa_dim1","trust_media","trust_elected_officials"),at=list(race3=c("asian","white","black","hispanic")), type="response", change="minmax"))
baseline_trust_effects.5$model <- "DV: Summated Policy Scale"
baseline_trust_effects.5$pid3 <- "Full Sample"

effects <- baseline_trust_effects.5
effects$race3 <- factor(effects$race3,levels=c("asian","black","white","hispanic"), labels=c("Asian Respondents","Black Respondents","White Respondents","Hispanic Respondents"))

effects$ylo90 <- (effects$AME - (qt(.95, 100) * effects$SE))
effects$yhi90 <- (effects$AME + (qt(.95, 100) * effects$SE))

effects$factor <- ifelse(effects$factor %in% "trust_elected_officials","Elected Officials Trust",ifelse(effects$factor %in% "trust_media","Media Trust",ifelse(effects$factor %in% "trust_scientists_fa_dim1","Scientific Trust",NA)))

plot <- ggplot(effects,aes(x=race3,y=AME,factor=factor,group=factor,color=factor,shape=factor)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= race3, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= race3, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Min/Max First Difference Marginal Effects on Number of Necessary Government Policies") + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "bottom") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + scale_shape_manual("Trust Effects",values=c(23,22,21))
print(plot)
#ggsave(file="summated_policy_scale_race3_model.png", plot, width = 8, height = 5.43, units = "in")

# Boxplot by Race

x <- subset(pew,select=c(race3,trust_scientists_fa_dim1))
x <- na.omit(x)
print(summary(aov(trust_scientists_fa_dim1 ~ race3, data = x)))
y <- subset(pew,select=c(race3,trust_scientists_fa_dim1))
y$race3 <- "Full Sample"
x <- rbind(x,y)

plot <- ggplot(x, aes(x=race3,y=trust_scientists_fa_dim1, group=race3,fill=race3)) + geom_boxplot(alpha=0.2) + theme_minimal() + scale_y_continuous("Latent Scientific Trust") + scale_x_discrete("",labels=c("White Respondents","Black Respondents","Hispanic Respondents","Asian Respondents","Full Sample")) + theme(legend.position = "none") + labs(caption="ANOVA suggests significant differences in mean latent scientific trust across racial groups, p < 0.01.") + geom_jitter(aes(colour=race3),alpha=0.075) + scale_color_manual("",values=c("#F8766D","#7CAE00","#00BFC4","#529EFF","gray")) + scale_fill_manual("",values=c("#F8766D","#7CAE00","#00BFC4","#529EFF","gray"))
#ggsave(file="scientific_trust_boxplots_by_race3.png", plot, width = 8, height = 5.43, units = "in")

###### Data Analysis Figures: OLS Composite Models ####

summary(model <- lm(trust_scientists_fa_dim1 ~ female + pid3 + libcon + age_linear + educ_linear + income_linear + race3 + region_factor, data=pew, weights=weight))

mes <- summary(margins(model, type="response", change="minmax"))
mes$race3 <- factor(mes$factor,levels=c("race3asian","race3black","race3hispanic"),labels=c("Asian Respondents","Black Respondents","Hispanic Respondents"))

mes$label <- ifelse(mes$p < 0.01,paste(round(mes$AME,2),"***",sep=""),ifelse(mes$p < 0.05,paste(round(mes$AME,2),"**",sep=""),ifelse(mes$p < 0.10,paste(round(mes$AME,2),"*",sep=""),NA)))

mes$ylo90 <- (mes$AME - (qt(.95, 100) * mes$SE))
mes$yhi90 <- (mes$AME + (qt(.95, 100) * mes$SE))
mes$model <- "DV: Latent Scientific Trust "

plot <- ggplot(subset(mes,!is.na(mes$race3)),aes(x=race3,y=AME,factor=race3,group=race3,color=race3,shape=race3,label=label,fill=race3)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= race3, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= race3, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white") + theme_minimal() + scale_x_discrete("") + scale_y_continuous("Marginal Effect of Race on Latent Scientific Trust")  + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "none") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + geom_label(vjust=-0.5,hjust=0.25,fill="white") + labs(caption="Note marginal effects relative to white respondents. \n* p < 0.1; ** p < 0.05; *** p < 0.01") + facet_wrap(~model) + scale_shape_manual("Trust Effects",values=c(23,22,21))
ggsave(file="latent_scientific_trust_model.png", plot, width = 8, height = 5.43, units = "in")

mes <- subset(mes,!(mes$factor %in% c("region_factorWest","region_factorSouth","region_factorMidwest")))

plot <- ggplot(mes,aes(x=factor,y=AME,factor=factor,group=factor,label=label)) + facet_wrap(~model) + coord_flip() + geom_linerange(aes(x= factor, ymin = ylo90, ymax = yhi90), position = position_dodge(width=0.75), lwd  = 1) + geom_pointrange(aes(x= factor, ymin = lower, ymax = upper), lwd = 1/2, position = position_dodge(width=0.75),fill="white",shape=21) + theme_minimal() + scale_x_discrete("",labels=c("Age","Education","Female","Income","Liberal Ideology","Democrat","Independent","Asian Respondent","Black Respondent","Hispanic Respondent")) + scale_y_continuous("Marginal Effect of Covariates on Latent Scientific Trust")  + geom_hline(yintercept = 0, colour = gray(1/2), lty = 2) +  labs(color="Trust Effects",shape="Trust Effects") + theme(legend.position = "none") + theme(axis.text.x = element_text(hjust = 0.5),axis.text.y = element_text(hjust = 0.5)) + geom_label(vjust=-0.5,hjust=0.25,fill="white") + labs(caption="Note marginal effects for respondent race & partisanship relative to baseline factor categories. Contextual regions omitted. \nFactor Baselines: white respondents, Republican identifiers. * p < 0.1; ** p < 0.05; *** p < 0.01") + facet_wrap(~model) 
ggsave(file="latent_scientific_trust_model_full.png", plot, width = 8, height = 5.43, units = "in")