############################################################
# TP Régression Logistique sur R-Studio d'une base de données d'essai clinique
############################################################
# Installation des packages
install.packages(c("car", "tidyverse", "funModeling", "finalfit", "knitr"))

# Chargement des librairies
library(car)
library(tidyverse)
library(funModeling)
library(finalfit)
library(knitr)

# Gestion des conflits de fonctions
library(conflicted)
conflict_prefer("filter", "dplyr")
conflict_prefer("select", "dplyr")

# Chargement des données
data(heart_disease)

# Vérifier l'importation
head(heart_disease)

# Dimension du dataset
dim(heart_disease)

# Création du dataframe HD et recodage de la variable
HD <- heart_disease %>%
  mutate(has_heart_disease_num = ifelse(has_heart_disease == "no", 0, 1)) %>%
  mutate(has_heart_disease_num = as.numeric(has_heart_disease_num))

# Scatterplot fréquence cardiaque max vs maladie
g_scatter <- ggplot(HD, aes(x = max_heart_rate, y = has_heart_disease_num)) +
  geom_point()

# Barplot genre vs maladie
g_bar <- ggplot(HD, aes(gender, fill = has_heart_disease)) +
  geom_bar(position = "fill", col = "black") +
  scale_fill_manual(values = c("#43d8c9", "#95389e"))

# Régression logistique
mod1 <- glm(
  has_heart_disease ~ max_heart_rate + gender,
  family = binomial,
  data = HD
)

# Résumé du modèle
summary(mod1)

# Vérification du nombre de cas
table(HD$has_heart_disease)

# Odds ratios
exp(coef(mod1))

# Intervalles de confiance
exp(cbind(OR = coef(mod1), confint(mod1)))

# ANOVA
Anova(mod1)

# Variables pour finalfit
dependent <- "has_heart_disease"
explanatory <- c("gender", "max_heart_rate")

# Tableau de résultats
res_glm_multi <- HD %>%
  glmmulti(dependent, explanatory) %>%
  fit2df(estimate_suffix = "(multivarié)")

# Affichage tableau formaté
table_results <- kable(res_glm_multi, row.names = FALSE, align = c("l", "l", "r", "r", "r", "r"))

# Forest plot
g_forest <- HD %>%
  or_plot(
    dependent,
    explanatory,
    table_text_size = 4,
    title_text_size = 16
  )

# print g_scatter
# print g_bar
# print g_forest
# print res_glm_multi
# print table_results
# Pour afficher les visuels de l'analyse