library(readxl)
library(tidyverse)
library(tidygraph)
library(igraph)

filepath = "/home/seokwon/nas/"
ref_path = paste0(filepath, "99.reference/")

Cancerlist = dir(paste0(filepath, "/00.data/filtered_TCGA/"))
surv_total_results = read_xlsx("~/nas/04.Results/Total_results_survpval2.xlsx")

jaccard_similarity <- function(A, B) { 
  intersection = length(intersect(A, B)) 
  union = length(A) + length(B) - intersection 
  return (intersection/union) 
} 

# setwd("~/nas/04.Results/short_long/ttest")
Cancerlist = Cancerlist[c(-11,-12)]
total_features = list()

# for all
for (num_CancerType in Cancerlist) {
  
  main.path_tc = paste0(filepath, "00.data/filtered_TCGA/", num_CancerType)
  CancerType = gsub('[.]','',gsub('\\d','', num_CancerType))
  Cancernum = gsub('[.-]','',gsub('[a-zA-Z]','', num_CancerType))
  # call input
  
  cancer_bf = read.csv(paste0(filepath,"04.Results/bestfeatures/",CancerType, "_critical_features.csv"))
  cancer_bf_sl = read.csv(paste0(filepath,"04.Results/short_long/ttest_common/",CancerType, "_critical_features_short_long_common.csv"))
  
  # cancer_bf_cut = cancer_bf[1:surv_total_results[which(surv_total_results$CancerType == CancerType),]$num_of_features,]
  Cancername = gsub('TCGA-','', CancerType)
  total_features[[Cancername]] = cancer_bf$variable
  
}

node_size_df = data.frame( CancerType = gsub('TCGA-','',surv_total_results$CancerType), 
                           num_features = surv_total_results$num_of_features)
node_size_df = node_size_df[1:10,]

total_comb = gsub('.TCGA-','',gsub('\\d','', t(combn(Cancerlist, 2))))
network_df = data.frame()

for (i in 1:nrow(total_comb)) {
  first_cancer = total_comb[i,1]
  second_cancer = total_comb[i,2]
  
  if (length(intersect(total_features[[first_cancer]], total_features[[second_cancer]])) != 0 ) {
    tmp_df = data.frame(from = first_cancer, 
                        to = second_cancer, 
                        weight = jaccard_similarity(total_features[[first_cancer]] ,total_features[[second_cancer]] ))
  }else {
    next
  }
  network_df = rbind(network_df, tmp_df)
}

total_shared_features = data.frame()

for (i in 1:nrow(total_comb)) {
  first_cancer = total_comb[i,1]
  second_cancer = total_comb[i,2]
  
  if (length(intersect(total_features[[first_cancer]], total_features[[second_cancer]])) != 0 ) {
    tmp_df = data.frame(from = first_cancer, 
                        to = second_cancer, 
                        shared_features = intersect(total_features[[first_cancer]], total_features[[second_cancer]]))
  } else {
    next
  }
  total_shared_features = rbind(total_shared_features, tmp_df)
}

total_shared_features_filt = total_shared_features %>%
  mutate(original = shared_features) %>%
  separate_rows(shared_features, sep = "P", convert = TRUE) %>%
  filter(shared_features != "") %>%  # 공백이 아닌 행만 남기기
  mutate(shared_features = paste0("P", shared_features))

count_table = total_shared_features_filt %>%
  count(shared_features) %>%
  arrange(desc(n))

# total_shared_features_filt %>% filter(shared_features == "P54")

write.csv(count_table, "count_table_divide_pathwaylink.csv")
write.csv(total_shared_features_filt, "original_shared_features.csv")

# shared_network = graph_from_data_frame(network_df, directed = F)
shared_network = network_df %>%
  as_tbl_graph(directed=FALSE) %N>%
  mutate(num_features = ((node_size_df$num_features) / max(node_size_df$num_features)) * 15 + 10)  %N>%
  mutate(color = c("#DC0000FF","#7E6148FF","#91D1C2FF","#F39B7FFF","#8491B4FF","#3C5488FF","#B09C85FF","#00A087FF","#4DBBD5FF","#E64B35FF"))

# node color -> enriched 
# 
# shared_network = network_df %>%  
#   as_tbl_graph(directed=FALSE) %N>%
#   mutate(num_features = ((node_size_df$num_features) / max(node_size_df$num_features)) * 15 + 10) %N>%
#   mutate(color = c("#72BC6C","#72BC6C","#D3DFE5","#C0392B","#C0392B","#72BC6C","#C0392B","#D3DFE5","#C0392B","#72BC6C"))

library(ggraph)
library(ggforce)

# lo = layout_nicely(shared_network)
lo = readRDS("~/nas/04.Results/short_long/ttest_common/layout_network.rds")

# saveRDS(lo, "~/nas/04.Results/short_long/ttest_common/layout_network.rds")

# shared_network = network_df %>%  
#   as_tbl_graph(directed=FALSE) %N>%
#   mutate(num_features = ((node_size_df$num_features) / max(node_size_df$num_features)) * 15 + 10) %N>%
#   mutate(color = c("#DC0000FF","#7E6148FF","#91D1C2FF","#F39B7FFF","#8491B4FF","#3C5488FF","#B09C85FF","#00A087FF","#4DBBD5FF","#E64B35FF"))
# 
network_PP = ggraph(shared_network, layout = lo) +
  geom_edge_parallel2(aes(colour = node.color, edge_width = rep(E(shared_network)$weight , each = 2)), alpha = 0.25) +
  geom_node_point(
    aes(fill = names(V(shared_network)),
        color = names(V(shared_network))
    ),
    size = V(shared_network)$num_features
  ) +
  scale_edge_color_manual(values=c(
    "#00A087FF", # LGG
    "#3C5488FF", # OV
    "#4DBBD5FF", # BRCA
    "#7E6148FF", # BLCA
    "#8491B4FF", # LIHC
    "#91D1C2FF", # STAD
    "#B09C85FF", # LUSC
    "#DC0000FF", # CESC
    "#E64B35FF", # UCEC
    "#F39B7FFF"  # LUAD
  )) +
  scale_color_manual(values=c(
    "#7E6148FF", # BLCA
    "#4DBBD5FF", # BRCA
    "#DC0000FF", # CESC
    "#00A087FF", # LGG
    "#8491B4FF", # LIHC
    "#F39B7FFF", # LUAD
    "#B09C85FF", # LUSC
    "#3C5488FF", # OV
    "#91D1C2FF", # STAD
    "#E64B35FF"  # UCEC
  )) +

  scale_fill_manual(values=c(
    "#7E6148FF", # BLCA
    "#4DBBD5FF", # BRCA
    "#DC0000FF", # CESC
    "#00A087FF", # LGG
    "#8491B4FF", # LIHC
    "#F39B7FFF", # LUAD
    "#B09C85FF", # LUSC
    "#3C5488FF", # OV
    "#91D1C2FF", # STAD
    "#E64B35FF"  # UCEC
  )) +
  geom_node_text(aes(label = names(V(shared_network)), vjust = 0.5)) +
  theme_graph()+ 
  theme(legend.position="none")

ggsave(file="figure3D.svg", plot=network_PP, width=10, height=10)

##
# network_PP = ggraph(shared_network, layout = lo) +
#   geom_edge_parallel2(aes(colour = node.color, edge_width = rep(E(shared_network)$weight , each = 2)), alpha = 0.25) +
#   geom_node_point(
#     aes(fill = names(V(shared_network)),
#         color = names(V(shared_network))
#     ),
#     size = V(shared_network)$num_features
#   ) +
#   scale_edge_color_manual(values=c(
#     "#72BC6C", # BLCA
#     "#C0392B", # BRCA
#     "#72BC6C", # CESC
#     "#D3DFE5", # LGG
#     "#C0392B", # LIHC
#     "#C0392B", # LUAD
#     "#C0392B", # LUSC
#     "#72BC6C", # OV
#     "#D3DFE5", # STAD
#     "#72BC6C"  # UCEC
#   )) +
#   scale_color_manual(values=c(
#     "#72BC6C", # BLCA
#     "#C0392B", # BRCA
#     "#72BC6C", # CESC
#     "#D3DFE5", # LGG
#     "#C0392B", # LIHC
#     "#C0392B", # LUAD
#     "#C0392B", # LUSC
#     "#72BC6C", # OV
#     "#D3DFE5", # STAD
#     "#72BC6C"  # UCEC
#   )) +
#   
#   scale_fill_manual(values=c(
#     "#72BC6C", # BLCA
#     "#C0392B", # BRCA
#     "#72BC6C", # CESC
#     "#D3DFE5", # LGG
#     "#C0392B", # LIHC
#     "#C0392B", # LUAD
#     "#C0392B", # LUSC
#     "#72BC6C", # OV
#     "#D3DFE5", # STAD
#     "#72BC6C"  # UCEC
#   )) +
#   geom_node_text(aes(label = names(V(shared_network)), vjust = 0.5)) +
#   theme_graph()

# 
# ggsave(file="figure3C.svg", plot=network_PP, width=10, height=10)

#### long short on the plot 

total_features = list()

# for all
for (num_CancerType in Cancerlist) {
  
  main.path_tc = paste0(filepath, "00.data/filtered_TCGA/", num_CancerType)
  CancerType = gsub('[.]','',gsub('\\d','', num_CancerType))
  # Cancernum = gsub('[.-]','',gsub('[a-zA-Z]','', num_CancerType))
  # call input
  
  # cancer_bf = read.csv(paste0(filepath,"04.Results/bestfeatures/",CancerType, "_critical_features.csv"))
  cancer_bf_sl = read.csv(paste0(filepath,"04.Results/short_long/ttest_common/",CancerType, "_critical_features_short_long_common.csv"))
  
  # cancer_bf_cut = cancer_bf[1:surv_total_results[which(surv_total_results$CancerType == CancerType),]$num_of_features,]
  Cancername = gsub('TCGA-','', CancerType)
  total_features[[Cancername]] = cancer_bf_sl$variable
  
}

total_comb = gsub('.TCGA-','',gsub('\\d','', t(combn(Cancerlist, 2))))
network_sl_df = data.frame()

for (i in 1:nrow(total_comb)) {
  first_cancer = total_comb[i,1]
  second_cancer = total_comb[i,2]
  # first_cancer = "BLCA"
  # second_cancer = "UCEC"
  if (length(intersect(total_features[[first_cancer]], total_features[[second_cancer]])) != 0 ) {
    
    shared_features = intersect(total_features[[first_cancer]], total_features[[second_cancer]])
    
    first_cancer_sl = read.csv(paste0(filepath,"04.Results/short_long/ttest_common/",gsub('[.]','',gsub('\\d','',Cancerlist[grep(first_cancer, Cancerlist)])), "_critical_features_short_long_common.csv"))
    second_cancer_sl = read.csv(paste0(filepath,"04.Results/short_long/ttest_common/",gsub('[.]','',gsub('\\d','',Cancerlist[grep(second_cancer, Cancerlist)])), "_critical_features_short_long_common.csv"))
    
    first_cl = first_cancer_sl %>% 
      subset(., variable %in% shared_features) 
    
    second_cl = second_cancer_sl %>% 
      subset(., variable %in% shared_features)
    
    tmp_equal_enriched = merge(first_cl , second_cl , by = "variable", all = FALSE )
    
    equal_enriched = tmp_equal_enriched %>% 
      select(-X.1.x, -X.x, -X.1.y,-X.y) %>% 
      mutate(total_minmax = minmax.x * minmax.y) %>% 
      filter(classification.x == classification.y) %>%
      arrange(desc(total_minmax)) 
    
    equal_enriched = equal_enriched %>%
      mutate( classification = classification.x) %>%
      select(-classification.x ,- classification.y)
    
    # if (has_element(equal_enriched$classification , "common")) {
    #   equal_enriched = equal_enriched %>% filter( classification != 'common')
    # }
    
    if (nrow(equal_enriched) != 0) {
      tmp_prop = prop.table(table(equal_enriched$classification))
      
      if (sum(tmp_prop > 0.5) == 1) {
        equal_enriched = equal_enriched %>% filter( classification == names(tmp_prop[tmp_prop > 0.5]))
      } else if (sum(names(tmp_prop) %in% "common") >=1) {
        equal_enriched = equal_enriched %>% filter( classification == names(tmp_prop[!names(tmp_prop) %in% "common"]))
      } else {
        equal_enriched$ratio = tmp_prop
        equal_enriched$classification_backup = equal_enriched$classification
        equal_enriched$classification = "mixed"
      } 
    } 
    
    # print(unique(equal_enriched$classification))
    if (nrow(equal_enriched) != 0) {
      edge_character = unique(equal_enriched$classification)
    } else {
      edge_character = 'none'
    }
    
    if (length(unique(equal_enriched$classification)) ==1 && unique(equal_enriched$classification) == "common") {
      edge_character = 'none'
    }
    
    if (edge_character == "common") {
      edge_character = 'mixed'
    }
    tmp_df = data.frame(from = first_cancer, 
                        to = second_cancer, 
                        weight = length(equal_enriched$variable) / (length(total_features[[first_cancer]]) + 
                                                                      length(total_features[[second_cancer]]) - 
                                                                      length(intersect(total_features[[first_cancer]], total_features[[second_cancer]]))),
                        character = edge_character)
    } else {
      next
    }
    network_sl_df = rbind(network_sl_df, tmp_df)
  
}


network_sl_df <- network_sl_df %>% 
  mutate(edge_color = case_when(
    character == "short" ~ "#E41A1C",
    character == "long" ~ "#4DAF4A",
    character == "mixed" ~ "#D3DFE5",
    character == "none" ~ "white",
    TRUE ~ NA_character_
  ))

library(tidygraph)
shared_features_network = network_sl_df %>%  
  as_tbl_graph(directed=FALSE) %N>%
  mutate(num_features = ((node_size_df$num_features) / max(node_size_df$num_features)) * 15 + 10) %N>%
  mutate(color = c("#DC0000FF","#7E6148FF","#91D1C2FF","#F39B7FFF","#8491B4FF","#3C5488FF","#B09C85FF","#00A087FF","#4DBBD5FF","#E64B35FF"))

shared_features_network = delete_edges(shared_features_network, which(network_sl_df$edge_color == "white"))

network_p = ggraph(shared_features_network, layout = lo) +
  geom_edge_link(aes( color = c(E(shared_features_network)$edge_color), edge_width = E(shared_features_network)$weight ),
                 colour = rep(E(shared_features_network)$edge_color, each = 100), alpha = 0.25) +
  geom_node_point(
    aes(fill = names(V(shared_features_network)),
        color = names(V(shared_features_network))
    ),
    size = V(shared_features_network)$num_features
  ) +
  # scale_edge_color_manual(values=c(
  #  
  #   "#4DAF4A",
  #   "#E41A1C",
  #   "brown",
  #   "white"
  # 
  # )) +
  scale_color_manual(values=c(
    "#72BC6C", # BLCA
    "#C0392B", # BRCA
    "#72BC6C", # CESC
    "#D3DFE5", # LGG
    "#C0392B", # LIHC
    "#C0392B", # LUAD
    "#C0392B", # LUSC
    "#72BC6C", # OV
    "#D3DFE5", # STAD
    "#72BC6C"  # UCEC
  )) +
  
  scale_fill_manual(values=c(
    "#72BC6C", # BLCA
    "#C0392B", # BRCA
    "#72BC6C", # CESC
    "#D3DFE5", # LGG
    "#C0392B", # LIHC
    "#C0392B", # LUAD
    "#C0392B", # LUSC
    "#72BC6C", # OV
    "#D3DFE5", # STAD
    "#72BC6C"  # UCEC
  )) +
  geom_node_text(aes(label = names(V(shared_features_network)), vjust = 0.5)) +
  theme_graph()+ 
  theme(legend.position="none")

ggsave(file="figure3F_long_short_common.svg", plot=network_p, width=10, height=10)
########

