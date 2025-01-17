############
### Info ###
############
#
## Authors:  Dan Turner (dturner @ northwestern.edu)
#            Timo Roettger (timo.b.roettger @ gmail.com)
#
## Project: Eye tracking during prenuclear pitch accent comprehension
#
##          Plotting
#
##          This file plots the fixation proportion.
#
## Version: 9/19/2020


#############
### Setup ###
#############

library(tidyverse)
library(ggbeeswarm)
library(rstudioapi)
library(see)

## Getting the path of your current open file
datapath = rstudioapi::getActiveDocumentContext()$path 
setwd(dirname(datapath))
setwd("../processed/")

## Load and merge the data with our acoustic landmarks
# Load processed data
data <- read_csv("ret_processed_stage_2.csv")

# Load acoustic landmarks
setwd("../data/")
landmarks <- read_csv("acoustic_landmarks.csv")

# Join the landmarks and data
data <- full_join(data, landmarks)

# rename levels 
data$window <- as.factor(data$window)
levels(data$window) <- c("adverb", "early", "2nd NP", "1st NP")

# exclusion
data <- data %>% 
  #filter(!is.na(window)) %>% 
  # exclusion
  filter(excludeTriggerError == 0,
         excludeRefError == 0, 
         excludeLargeError == 0,
         lgerror == 0,
         surveyExclude == 0) %>% 
  mutate(window = factor(window, levels = c("early", "1st NP", "2nd NP", "adverb"))) %>% 
  # generate binary preference score
  mutate(subj_preference = ifelse(((Target_prop + ObjComp_prop) / 2) > ((SubjComp_prop + Distr_prop) / 2), 1, 0),
         obj_preference = ifelse(((Target_prop + SubjComp_prop) / 2) > ((ObjComp_prop + Distr_prop) / 2), 1, 0),
         # centralize eyetrial
         eyetrial.c = scale(eyetrial, scale = T))

# Gather proportional values
data <- data %>% 
  gather(response, proportion, c(8:13, 25:26)) 

# Rename response levels
data <- data %>% 
  mutate(response = as.factor(response),
         response = fct_recode(response, Target = "Target_prop",
                               `Object Competitor` = "ObjComp_prop",
                               `Subject Competitor` =  "SubjComp_prop", 
                               Distractor = "Distr_prop",
                               `Given Subject` = "GivenSubj_prop",
                               `Given Object` = "GivenObj_prop",
                               `Target 1st NP` = "subj_preference",
                               `Target 2nd NP` = "obj_preference"),
         Condition = as.factor(Condition),
         Condition = fct_recode(Condition, `NP1 accented` = "CG",
                                `NP2 accented` = "GC",
                                `Both NPs accented` =  "GG")
         )
         
#################
### Aggregate ###
#################

# aggregate proportions (per subject)
xagg_subj <- data %>% 
  group_by(Condition, window, ID, response) %>% 
  summarise(prop = mean(proportion, na.rm = T),
            prenuc_onset = mean(prenuclear_onset, na.rm = T),
            ref_onset = mean(referent_onset, na.rm = T),
            adverb_onset = mean(adverb_onset, na.rm = T)) %>% 
  mutate(window_dummy1 = prenuc_onset / 2,
         window_dummy2 = ((ref_onset - prenuc_onset)/2) + prenuc_onset + 200,
         window_dummy3 = ((adverb_onset - ref_onset)/2) + ref_onset + 200,
         window_dummy4 = adverb_onset + 500 + 200,
         window_dummy = ifelse(window == "early", window_dummy1,
                               ifelse(window == "1st NP", window_dummy2,
                                      ifelse(window == "2nd NP", window_dummy3, window_dummy4)
))) %>% 
  select(-window_dummy1, -window_dummy2, -window_dummy3, -window_dummy4)


# aggregate proportions (overall)
xagg <- xagg_subj %>% 
  group_by(Condition, window, response) %>% 
  summarise(prop = mean(prop, na.rm = T),
            prenuc_onset = mean(prenuc_onset, na.rm = T),
            ref_onset = mean(ref_onset, na.rm = T),
            adverb_onset = mean(adverb_onset, na.rm = T),
            window_dummy = mean(window_dummy, na.rm = T))


############
### Plot ###
############

# specify colors
Col1 = "#008837"
Col2 = "#7b3294"


# load posteriors
setwd("../models/")
load("posteriors.RData")

## plot preferences for 1st NP Target or 2nd NP Target 

# store information for annotation
xagg_text <- data.frame(Condition = unique(xagg$Condition))
xagg_text$text_2 <- ifelse(xagg_text$Condition != "NP2 accented", "THINGY", "thingy")
xagg_text$text_3 <- ifelse(xagg_text$Condition != "NP1 accented", "BERRIES", "berries")
xagg_text$text_4 <- ifelse(xagg_text$Condition == "Both NPs accented", "again", "instead")

# store font face
xagg_text <- xagg_text %>%   
  gather(position, text, -Condition) %>% 
  mutate(font_face = c("bold", "plain", "bold", "plain", "bold", "bold", "plain", "plain", "plain"))

# rename columns for posteriors
colnames(posteriors_prob) <- c("name", "lci", "uci", "proportion", "probability", "Condition", "window", "type", "time", "response")

# merge dfs for plot
plot_df <- posteriors_prob %>% 
  mutate(Condition = fct_recode(Condition, `NP1 accented` = "1st NP accent",
                                         `NP2 accented` = "2nd NP accent",
                                         `Both NPs accented` =  "Both NPs have accents")) %>% 
  full_join(xagg[xagg$response %in% c("Target 1st NP", "Target 2nd NP"),]) %>% 
  full_join(xagg_text) 

plot_df$Condition <- as.factor(plot_df$Condition)
plot_df$Condition <- factor(plot_df$Condition, levels = c("NP1 accented", "NP2 accented", "Both NPs accented"))

# make df for geom_text
annotation_df <- expand_grid(Condition = c("NP1 accented", "NP2 accented", "Both NPs accented"),
                             response = c("Target 1st NP", "Target 2nd NP"))



## plot simple comparison between baseline and prenuclear window
Fix_agg_simple <- 
ggplot(data = xagg_subj[xagg_subj$response %in%  c("Target 2nd NP", "Target 1st NP") & 
                          xagg_subj$window %in% c("early", "1st NP", "2nd NP"),], 
       aes(x = window, y = prop, color = response, fill = response)) +
  geom_segment(x = -Inf, xend = Inf, y = 0.5, yend = 0.5, color = "grey", lty = "dashed") +
  facet_grid(response ~ Condition) +
  #geom_violin(color = "white", fill = "grey", alpha = 0.2, trim = FALSE) +
  geom_quasirandom(width = 0.2, alpha = 0.3, size = 3) +
  geom_line(data = plot_df[plot_df$time == "middle" & plot_df$window %in% c("early", "1st NP", "2nd NP"),],
            aes(x = window, y = proportion, color = response, group = 1),
            size = 2) +
  geom_errorbar(data = plot_df[plot_df$time == "middle" & plot_df$window %in% c("early", "1st NP", "2nd NP"),],
                aes(x = window, ymin = lci, ymax = uci),
                colour = "black", width = 0.1, inherit.aes = FALSE) +
  geom_point(data = plot_df[plot_df$time == "middle" & plot_df$window %in% c("early", "1st NP", "2nd NP"),],
             aes(x = window, y = proportion, fill = response),
             size = 3, pch = 21, stroke = 1, inherit.aes = FALSE,
             color = "black") +
  # draw circles
  geom_point(data = annotation_df[annotation_df$response %in%  c("Target 1st NP") & 
                                annotation_df$Condition %in% c("NP1 accented"),],
             pch = 21, size = 8, color = "black", fill = NA, 
             x = 1.5, y = 0.2) +
  geom_point(data = annotation_df[annotation_df$response %in%  c("Target 1st NP") & 
                                annotation_df$Condition %in% c("NP1 accented"),],
             pch = 21, size = 8, color = "black", fill = NA, 
             x = 2.5, y = 0.35) +
  geom_point(data = annotation_df[annotation_df$response %in%  c("Target 2nd NP") & 
                                    annotation_df$Condition %in% c("NP2 accented"),],
             pch = 21, size = 8, color = "black", fill = NA, 
             x = 1.5, y = 0.25) +
  geom_text(data = annotation_df[annotation_df$response %in%  c("Target 1st NP") & 
                                   annotation_df$Condition %in% c("NP1 accented"),],
            size = 6, color = "black",
            x = 1.5, y = 0.21, label = "a") +
  geom_text(data = annotation_df[annotation_df$response %in%  c("Target 1st NP") & 
                                   annotation_df$Condition %in% c("NP1 accented"),],
            size = 6, color = "black",
            x = 2.51, y = 0.352, label = "b") +
  geom_text(data = annotation_df[annotation_df$response %in%  c("Target 2nd NP") & 
                                   annotation_df$Condition %in% c("NP2 accented"),],
            size = 6, color = "black",
            x = 1.5, y = 0.26, label = "c") +
  scale_colour_manual(values = c(Col2, "grey")) +
  scale_fill_manual(values = c(Col2, "white")) +
  scale_y_continuous(expand = c(0, 0), breaks = (c(0, 0.25, 0.5, 0.75, 1)), limits = c(0,1)) +
  labs(title = "Average fixation preference across conditions and windows",
       subtitle = "semitransparent dots represent averages of individual participants\n",
       y = "Average fixation preference for target referents\n"
  ) +
  theme_classic() + 
  theme(legend.position = "none",
        legend.key.height = unit(2,"line"),
        legend.title = element_blank(),
        legend.text = element_text(size = 16),
        legend.background = element_rect(fill = "transparent"),
        strip.background = element_blank(),
        strip.text = element_text(size = 16),
        panel.spacing = unit(2, "lines"),
        plot.background = element_rect(fill = "transparent", colour = NA),
        panel.background = element_rect(fill = "transparent"),
        axis.line = element_blank(),
        axis.text.y = element_text(size = 16),
        axis.text.x = element_text(size = 16, angle = 45, hjust = 1),
        axis.title.y = element_text(size = 16, face = "bold"),
        axis.title.x = element_blank(),
        plot.title = element_text(size = 16, face = "bold"),
        panel.border = element_rect(colour = "black", fill = NA), 
        plot.margin = unit(c(1,1,1,1),"cm"))

# store plot 
setwd("../plots/")
ggsave(filename = "Fix_agg_simple.pdf",
       plot = Fix_agg_simple,
       device = "pdf",
       width = 250, 
       height = 200,
       units = "mm",
       #bg = "transparent",
       dpi = 300)