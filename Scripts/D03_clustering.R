# CLUSTERING: si cerca di individuare dei cluster di clienti con caratterische simili

#### INSIGHTS ####
# Le variabili prese in considerazione sono: numero acquisti, numero articoli, spesa
# Si sono considerati tutti i clienti che hanno effettuato un acquisto dopo l'1 gennaio 2019
# Il numero di cluster ottimale varia tra i seguenti valori: 3, 4 (i seguenti valori sono stati ottenuti tramite diversi metodi ad hoc)
# Per cercare di individuare i cluster in questione sono stati utilizzati diversi
# algoritmi tra cui:
# k-means: con k=3,4, l'algoritmo è sensibile agli outliers
# k-medoids: con k=4, l'algoritmo è più robusto agli outliers
# dbscan: l'algoritmo è più robusto agli outliers, tuttavia per come impostato le performance sono state deludenti
# In generale, prendendo come riferimento l'output dell'algoritmo K-medoids, 
# si è osservato ad esempio che: i clienti che fanno più acquisti sono quelli 
# che acquistano più articoli ma non sono i clienti che spendono di più. I clienti
# che spendono di più fanno un numero discreto di acquisti ai quali viene associato 
# un numero non troppo elevato di articoli


#### preparazione dataset ####

# variabili da considerare
# NUMERO ACQUISTI
# NUMERO ARTICOLI
# SPESA

# si considerano tutti gli acquisti effettuati l'1 gennaio 2019 o successivamente
clustering_dataset <- df_7_tic_clean_final %>%
  filter(DIREZIONE == 1) %>%
  filter(TIC_DATETIME >= as.Date("01/01/2019",
                                 format="%d/%m/%Y"))

# si selezionano le variabili di interesse
clustering_dataset <- clustering_dataset %>%
  group_by(ID_CLI) %>%
  summarize(
    NUM_OF_PURCHASES = n_distinct(ID_SCONTRINO),
    NUM_OF_ARTICLES = n_distinct(ID_ARTICOLO),
    TOT_PURCHASE = sum(IMPORTO_LORDO),
    TOT_SCONTO = sum(SCONTO),
    SPESA = TOT_PURCHASE - TOT_SCONTO  
  ) 
# si è considerata la variabile SPESA dopo aver attestato la presenza di una 
# elevata correlazione tra TOT_PURCHASE E TOT_SCONTO

# si considerano i clienti che hanno effettuato più di 1 acquisto
clustering_dataset <- clustering_dataset %>%
  filter(NUM_OF_PURCHASES > 3)

# complessivamente
str(clustering_dataset)

# controllo la presenza di eventuali na
sapply(clustering_dataset, function(x) sum(is.na(x)))  # non sono presenti valori mancanti


# attenzione agli outliers
# l'algorimto k-means è molto sensibile agli outliers
boxplot(clustering_dataset$NUM_OF_PURCHASES)
boxplot(clustering_dataset$NUM_OF_ARTICLES)
boxplot(clustering_dataset$SPESA)

# vengono mantenuti i record del dataframe "clustering_dataset" i cui z-score hanno
# un valore minore del valore assoluto 3
z_scores <- as.data.frame(sapply(clustering_dataset, function(clustering_dataset)
  (abs(clustering_dataset-mean(clustering_dataset))/sd(clustering_dataset))))
clustering_dataset <- clustering_dataset[!rowSums(z_scores > 3), ]

# controllo nuovamente gli outliers: la situazione è migliorata
boxplot(clustering_dataset$NUM_OF_PURCHASES)
boxplot(clustering_dataset$NUM_OF_ARTICLES)
boxplot(clustering_dataset$SPESA)


# eliminazione variabili non utili
clustering_dataset_original <- clustering_dataset
clustering_dataset <- clustering_dataset[,-c(1, 4, 5)]


# si verifica la correlazione tra esse
numeric.var <- sapply(clustering_dataset, is.numeric)
corr.matrix <- cor(clustering_dataset[,numeric.var])
corrplot(corr.matrix, main="\n\nCorrelation Plot for Numerical Variables", 
         method = "number")

# i dati vengono standardizzati in modo tale che essi abbiano la stessa scala
customer_data_stand <- scale(clustering_dataset) 


#### setting clustering ####

# numero di cluster
k_max <- 10
twcss <- sapply(1:k_max, function(k){kmeans(customer_data_stand, k)$tot.withinss})

g <- qplot(x = 1:k_max, y = twcss, geom = 'line')
g + scale_x_continuous(breaks = seq(0, 10, by = 1))
# questo grafico deve essere letto da destra verso sinistra
# si deve trovare il punto in cui la curva tende a salire in modo più consistente
# dal grafico sopra riportato si potrebbe pensare al valore 3 o 4, come numero 
# ottimale di cluster suggerito

# per individuare in maniera più precisa e analitica il numero ottimale di cluster da considerare
# si possono considerare i metodi sotto riportati (non eseguiti per limiti computazionali)


# Elbow method
# fviz_nbclust(customer_data_stand, kmeans, method = "wss") +
#   geom_vline(xintercept = 4, linetype = 2) + 
#   labs(subtitle = "Elbow method")


# Silhouette method
# fviz_nbclust(customer_data_stand, kmeans, method = "silhouette") +
#   labs(subtitle = "Silhouette method")


# Gap statistic
# fviz_nbclust(customer_data_stand, kmeans,  
#              nstart = 25,
#              method = "gap_stat",
#              nboot = 500 
# ) + labs(subtitle = "Gap statistic method")


# NbClust
# nbclust_out <- NbClust(
#   data = customer_data_stand,
#   distance = "euclidean",
#   min.nc = 2, # minimum number of clusters
#   max.nc = 5, # maximum number of clusters
#   method = "kmeans" # one of: "ward.D", "ward.D2", "single", "complete", "average", "mcquitty", "median", "centroid", "kmeans")


# un metodo alternativo per trovare il numero ottimale di cluster è il seguente
# duda <- NbClust(customer_data_stand, distance = "euclidean", method = "ward.D2",
#                 max.nc = 9, index = "duda")
# pseudot2 <- NbClust(customer_data_stand, distance = "euclidean", method = "ward.D2", 
#                     max.nc = 9, index = "pseudot2")

# il valore ottimale di numero di cluster dovrebbe coincidere con il valore più
# elevato di duda a cui corrisponde il valore pseudo-T2 minore

# duda$All.index

# pseudot2$All.index

# oppure più semplicemente
# duda$Best.nc  # numero ottimale cluster 



#### K-means ####

# vengono testati due scenari, K=3,4

##### K = 3 ##### 
# vengono selezionati n cluster = 3, viene applicato l'algoritmo kmeans
km_3 <-kmeans(customer_data_stand, centers = 3, nstart=20)

# general info
str(km_3)

# dimensioni dei cluster identificati
# km_3$size
table(km_3$cluster)
# 1       2     3 
# 17532  1362  4517 

km_3$withinss
# 12153.85  6762.29 11550.14

# valutazione qualità: la qualità di una partizione ottenuta applicando l'algoritmo
# k-means può essere valutata calcolando la percentuale di "TSS" speigata dalla
# partizione usando la seguente formula: BSS / TSS * 100 

# BSS: Between Sum of Square
# TSS:Total Sum of Squares

BSS_km_3 <- km_3$betweenss
TSS_km_3 <- km_3$totss
BSS_km_3 / TSS_km_3 * 100  #  56.61928 
# una maggiore qualità signfica una valore più alto spiegato

# maggiore è la percentuale ottenuta maggiore sarà lo score, dunque la qualità 
# perchè significa che BSS è elevato e/o WSS è piccolo


# si riconvertono i valori standardizzati per rendere chiaro l'output
data.orig_km_3 <- t(apply(km_3$centers, 1, function(r)r*attr(customer_data_stand,
                                                             'scaled:scale') + 
                            attr(customer_data_stand, 'scaled:center')))
data.orig_km_3[,c(1, 2)] <- round(data.orig_km_3[,c(1, 2)])
data.orig_km_3

# i valori finali dei centri dei cluster sono ottenuti come media di ciascuno dei
# valori presenti all'interno di ciascun cluster della configurazione finale. I valori 
# finali dei centri dei cluster rappresentano dunque le caratteristiche dell'oservazione
# tipica di ciascun cluster

# NUM_OF_PURCHASES    NUM_OF_ARTICLES     SPESA
#         5                 17            459.2832
#         9                 40            3902.5796
#         11                46            995.9989


# visualizzazione grafica
fviz_cluster(km_3, data = customer_data_stand, palette=c("#2E9FDF", "#00AFBB", 
                                                         "#E7B800"), 
             geom = "point",
             ellipse.type = "convex", 
             ggtheme = theme_bw()
)

# visualizzazione dei risultati di clustering attraverso PCA (Principal Component Analysis)
dimensione_pca_k3 <- prcomp(customer_data_stand,  scale = TRUE)

# si estraggono le coordinate
index_coordinate_k3 <- as.data.frame(get_pca_ind(dimensione_pca_k3)$coord)

# si aggiungono i cluster ottenuti con l'algoritmo k-means
index_coordinate_k3$cluster <- factor(km_3$cluster)

# si ottiene la percentuale di varianza spiegata dalla dimensioni
eigen_value_k3 <- round(get_eigenvalue(dimensione_pca_k3), 1)
variance_percent_k3 <- eigen_value_k3$variance_percent_k3
head(eigen_value_k3)

# visualizzazione grafica (si ottiene lo stesso grafico sopra riportato)
ggscatter(
  index_coordinate_k3, x = "Dim.1", y = "Dim.2", 
  color = "cluster", palette = "npg", ellipse = TRUE, ellipse.type = "convex",
  title = "K = 3",
  size = 1.5,  legend = "right", ggtheme = theme_bw(),
  xlab = paste0("Dim 1 (", variance_percent_k3[1], "% )" ),
  ylab = paste0("Dim 2 (", variance_percent_k3[2], "% )" )
) +
  stat_mean(aes(color = cluster), size = 4)



#####   K = 4 ##### 
# vengono selezionati n cluster = 4, viene applicato l'algoritmo kmeans
km_4 <-kmeans(customer_data_stand, centers = 4, nstart=20)

# general info
str(km_4)

# dimensioni dei cluster identificati
# km_4$size
table(km_4$cluster)
# 1     2     3     4 
# 1163 13820  6427  2001 

km_4$withinss
# 5411.670 5768.792 7578.557 5578.400

# valutazione qualità
BSS_km_4 <- km_4$betweenss
TSS_km_4 <- km_4$totss
BSS_km_4 / TSS_km_4 * 100   # 65.34612

# riconvertiamo i valori standardizzati per rendere chiaro l'output
data.orig_km_4 <- t(apply(km_4$centers, 1, function(r)r*attr(customer_data_stand,
                                                             'scaled:scale') + 
                            attr(customer_data_stand, 'scaled:center')))
data.orig_km_4[,c(1, 2)] <- round(data.orig_km_4[,c(1, 2)])
data.orig_km_4

# NUM_OF_PURCHASES NUM_OF_ARTICLES     SPESA
# 8                       39            4077.2940
# 5                       14            384.6349
# 14                      57            1279.8293
# 8                       33            816.5407

# visualizzazione grafica
fviz_cluster(km_4, data = customer_data_stand, palette=c("#2E9FDF", "#00AFBB", 
                                                         "#E7B800", "#FF0000"), 
             geom = "point",
             ellipse.type = "convex", 
             ggtheme = theme_bw()
)

# visualizzazione dei risultati di clustering attraverso PCA (Principal Component Analysis)
dimensione_pca_k4 <- prcomp(customer_data_stand,  scale = TRUE)

# si estraggono le coordinate
index_coordinate_k4 <- as.data.frame(get_pca_ind(dimensione_pca_k4)$coord)

# si aggiungono i cluster ottenuti con l'algoritmo k-means
index_coordinate_k4$cluster <- factor(km_4$cluster)

# si ottiene la percentuale di varianza spiegata dalla dimensioni
eigen_value_k4 <- round(get_eigenvalue(dimensione_pca_k4), 1)
variance_percent_k4 <- eigen_value_k4$variance_percent_k4
head(eigen_value_k4)

# visualizzazione grafica (si ottiene lo stesso grafico sopra riportato)
ggscatter(
  index_coordinate_k4, x = "Dim.1", y = "Dim.2", 
  color = "cluster", palette = "npg", ellipse = TRUE, ellipse.type = "convex",
  title = "K = 4",
  size = 1.5,  legend = "right", ggtheme = theme_bw(),
  xlab = paste0("Dim 1 (", variance_percent_k4[1], "% )" ),
  ylab = paste0("Dim 2 (", variance_percent_k4[2], "% )" )
) +
  stat_mean(aes(color = cluster), size = 4)



#### K-medoids ####

# Il metodo k-medoids di clustering più comune è l'algoritmo PAM, Partitioning Around Medoids

# in base ai risultati precedenti, si procede con k = 4
pam.res <- pam(customer_data_stand, 4)  # esecuzione che richiede molte risorse
# View(customer_data_stand)
# print(pam.res)

# Cluster medoids
pam.res$medoids  # medoids, ogetti che rappresentano il cluster di appertenenza

# numero di osservazioni per cluster
pam.res.list <- pam.res$clustering  # a vector containing the cluster number of each object
pam.res.df <- data.frame(matrix(unlist(pam.res.list), nrow=length(pam.res.list), byrow=TRUE))
names(pam.res.df)[1] <- "cluster"
pam.res.df %>% 
  group_by(pam.res.df$cluster) %>%
  summarise(Count = n())
# cluster 1  8489
# cluster 2  3734
# cluster 3  8947
# cluster 4  2241

# scale data -> original data
data.orig_pam_kmed_4 <- t(apply(pam.res$medoids, 1, function(r)r*attr(customer_data_stand,
                                                               'scaled:scale') + 
                           attr(customer_data_stand, 'scaled:center')))

# NUM_OF_PURCHASES NUM_OF_ARTICLES   SPESA
# 6                     24            446.91
# 11                    47            939.29
# 4                     11            232.03
# 7                     29            2575.03


#### DBSCAN ####

# in questo caso non è necessario stabilire a priori il numero di cluster da considerare

# scaled data
Dbscan_cl <- dbscan(customer_data_stand, eps = 0.45, MinPts = 5)

# The clustering contains 11 cluster(s) and 748 noise points.
# 
# 0     1       2     3     4     5     6     7     8     9    10    11    12    13    14 
# 285 23024     7    22    11     6    10    12     6     3     5     1    11     5     3 

# N.b.
# noise point: un punto che non è definito ne come un core point ne come un border
# point. Significa che si tratta di punti etichettati come outliers che non sono
# associati ad alcun cluster

# Checking cluster
Dbscan_cl$cluster

# DBSCAN visti i risultati poco soddisfacienti non viene considerato per analisi successive

# è stata testata anche un'altra versione di clustering con variabili diverse:
# "old_version_D03_clustering.R"
