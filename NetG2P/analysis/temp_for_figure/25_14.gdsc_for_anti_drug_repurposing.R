TLDR.sample.finder = function(tissue = NULL, TCGACode = NULL, OncoTreeCode = NULL,
                              snv.gene = NULL) {
  #define database
  meta.cell = readRDS("/mnt/gluster_server/data/reference/TLDR/meta_cells_primary.rds")
  meta.gene = readRDS("/mnt/gluster_server/data/reference/TLDR/meta_genes.rds")
  meta.map = readRDS("/mnt/gluster_server/data/reference/TLDR/meta_TCGA_Oncotree.rds")
  #creating arrays for term validation
  tcga.codes = unique(meta.map$TCGACode)
  oncotree.codes = unique(unlist(strsplit(meta.map$OncotreeCode, ","))) #might have to go deeper and read from meta.cell
  tissue.type = unique(meta.map$tissue)
  #entry check
  tissue.arr = c(is.null(tissue), is.null(TCGACode), is.null(OncoTreeCode))
  if (sum(tissue.arr) == 3) {
    stop("You must provide a category between tissue, TCGA and OncoTreeCode")
  } else if (sum(tissue.arr) < 2) {
    stop("TLDR currently only supports one sample type query.")
  }
  #i can probably compress this, but later
  #validity check
  if (!is.null(tissue)) {
    valid.tissue = intersect(tissue.type, tissue)
    if (length(valid.tissue) == 0) {
      stop("There are no valid tissue types in your query. Valid tissue types are: ", paste(unique(tissue.type), collapse = ", "))
    }
    meta.map.f = meta.map[meta.map$tissue %in% valid.tissue,]
  }
  if (!is.null(TCGACode)) {
    valid.TCGA = intersect(tcga.codes, TCGACode)
    if (length(valid.TCGA) == 0) {
      stop("There are no valid TCGA codes in your query. Valid TCGA codes are: ", paste(tcga.codes, collapse = ", "))
    }
    meta.map.f = meta.map[meta.map$TCGACode %in% valid.TCGA,]
  }
  if (!is.null(OncoTreeCode)) {
    valid.onco = intersect(oncotree.codes %in% OncoTreeCode)
    if (length(valid.onco) == 0) {
      stop("There are no validOncoTreeCodes in your query. If you are unsure, try looking with tissue types or TCGA codes")
    }
    meta.map.f = meta.map[meta.map$OncotreeCode %in% valid.onco,]
  }
  message("Your query resulted in TCGA: ", paste0(meta.map.f$TCGACode, collapse = ", "))
  message("Your query resulted in OncoTreeCode: ", paste0(meta.map.f$OncotreeCode, collapse = ", "))
  message("Your query resulted in lineage: ", paste0(meta.map.f$OncotreeLineage, collapse = ", "))
  message("Searching for cells!")
  meta.cell.t = meta.cell[meta.cell$OncotreeLineage %in% meta.map.f$tissue,]
  if (is.null(tissue)) {
    message("Further filtering by OncoTreeCode...")
    split.onco = unlist(strsplit(meta.map.f$OncotreeCode, ","))
    meta.cell.t$target.cell = meta.cell.t$OncotreeCode %in% split.onco
    meta.cell.t$target.cell[meta.cell.t$OncotreePrimaryDisease == "Non-Cancerous"] = T
    meta.cell.f = meta.cell.t[meta.cell.t$target.cell,]
  } else {
    meta.cell.f = meta.cell.t
  }
  message(sum(meta.cell.f$DepMap), " cell lines in DepMap, ", sum(meta.cell.f$COSMIC), " cell lines in COSMIC, ",sum(meta.cell.f$LINCS), " cell lines in LINCS.")
  message("Returning the queried information as data.frame. Good luck!")
  return(meta.cell.f)
}

###

library(dplyr)
library(tidyr)
library(tibble)
library(ggplot2)
library(ggfortify)
library(pheatmap)
library(RColorBrewer)
library(Rtsne)
# library(tsne)
# library(umap)
library(reshape2)
library(readxl)
# library(ggridges)
library(ggdist)
library(ggpubr)
library(tidyverse)
library(tidygraph)
library(ggraph)
filepath = "/home/seokwon/nas/"
ref_path = paste0(filepath, "99.reference/")

link_genes = readRDS(paste0(ref_path, "/KEGG_pathway_shared_genes.rds"))
single_genes = readRDS(paste0(ref_path, "/Kegg_pathway_genes.rds"))
link_genes$n_genes = NULL
link_genes_filtered = link_genes[which(link_genes$shared_genes != ""),]

link_genes_filtered <- link_genes_filtered %>%
  mutate(shared_genes = strsplit(shared_genes, ",")) %>%
  unnest(cols = shared_genes)
link_genes_filtered_df = as.data.frame(link_genes_filtered)
colnames(link_genes_filtered_df) = colnames(single_genes)

## Read Dataset 
meta.tbl <- read.csv(file = paste0(ref_path,'DepMap/Model.csv'), 
                     sep=',', header=T, fill=T)

ge.tbl <- read.csv(file = paste0(ref_path, 'DepMap/CRISPRGeneEffect.csv'), 
                   sep=',', header=T, fill=T, row.names=1)

meta_for_TCGA = read.csv(paste0(ref_path, "/Depmap_meta_filt_to_TCGA.csv"))
gdsc = readRDS("/mnt/gluster_server/data/reference/GDSC/2024_01_11/GDSC_data_combined.rds")
meta_cell = readRDS("/mnt/gluster_server/data/reference/TLDR/meta_cells_primary.rds")
nih_drug = read_xlsx("~/nas/99.reference/Nih_drug_data.xlsx")

nih_drug_filted = nih_drug %>%
  separate_rows(Drug_Name, sep = "\\(") %>%
  mutate(Drug_Name = str_trim(gsub("\\)", "", Drug_Name))) %>%
  group_by(Tissue_name) %>%
  distinct(Drug_Name, .keep_all = TRUE)

anticancer_drug = read_xlsx("~/nas/99.reference/anticancer_fund_cancerdrugsdb.xlsx")

anticancer_drug_filted = anticancer_drug %>%
  separate_rows(Indications, sep = "\\;") %>%
  mutate(Indications = str_trim(Indications))

anticancer_drug_filted = anticancer_drug_filted[!is.na(anticancer_drug_filted$Indications),]
anticancer_drug_filted = anticancer_drug_filted %>% select(Product,Indications,Targets,CESC,BLCA,STAD,LUAD,LIHC,OV,LUSC,LGG,BRCA,UCEC,COADREAD,KIDNEY, everything())

Cancerlist = dir(paste0(filepath, "/00.data/filtered_TCGA/"))
setwd("~/nas/04.Results/drug/depmap/gdsc/")
####
Cancerlist = Cancerlist[c(-11,-12)]

# TLDR.sample.finder(TCGACode = "TCGA-CESC") %>% filter(DepMap == T & COSMIC == T & GDSC == T)

num_CancerType = "24.TCGA-OV"

for (num_CancerType in Cancerlist) {
  
  main.path_tc = paste0(filepath, "00.data/filtered_TCGA/", num_CancerType)
  CancerType = gsub('[.]','',gsub('\\d','', num_CancerType))
  Cancername = gsub('TCGA-' , '', CancerType)
  
  # call input
  gc_cellline = readRDS(paste0("~/nas/00.data/filtered_TCGA/", num_CancerType, "/",Cancername,"_cellline_dual_all_log.rds"))
  gc_TCGA = readRDS(paste0("~/nas/04.Results/short_long/", CancerType,"_critical_features_short_long.rds"))
  
  filt_cancer_cell = meta_cell %>% 
    filter(DepMap.ID %in% rownames(gc_cellline)) %>%
    filter(DepMap == T & GDSC == T)
  
  setwd("~/nas/04.Results/drug/depmap/gdsc/")
  gdsc_each = gdsc %>% filter(COSMIC.ID %in% filt_cancer_cell$COSMIC.ID)
  
  gc_cellline_filt_df = readRDS(paste0(CancerType, "_DM_sl_cluster.rds"))
  
  # gdsc_each
  # filt_cancer_cell
  
  gc_filtered_cellline_df = gc_cellline_filt_df %>% filter(rownames(.) %in% filt_cancer_cell$DepMap.ID)
  
  gdsc_each_filt = left_join(gdsc_each, filt_cancer_cell %>% select(COSMIC.ID, DepMap.ID), by = "COSMIC.ID")
  
  tmp_df = data.frame(DepMap.ID = rownames(gc_filtered_cellline_df), cluster = gc_filtered_cellline_df$cluster)
  gdsc_w_cluster = left_join(gdsc_each_filt, tmp_df, by = "DepMap.ID")
  
  gdsc_w_cluster = gdsc_w_cluster %>%
    select(DepMap.ID, cluster, DRUG_ID,DRUG_NAME, PUTATIVE_TARGET, PATHWAY_NAME, AUC, RMSE, LN_IC50,Z_SCORE) %>% 
    arrange(DepMap.ID)

  library(ggpubr)
  library(ggsignif)
  
  # for fic
  fig_path = paste0(filepath,"/04.Results/drug/depmap/gdsc/", Cancername)
  if(!dir.exists(fig_path)){
    dir.create(fig_path)
    print(paste0("Created folder: ", fig_path))
  } else {
    print(paste0("Folder already exists: ", fig_path))
  }
  setwd(fig_path)
  
  # gdsc_w_cluster$DepMap.ID

  tmp_anti = anticancer_drug_filted %>% select(Product,Targets, !any_of(Cancername))
  tmp_anti_filt = tmp_anti[which(rowSums(is.na(tmp_anti[,4:12])) != 9),]
  
  # tmp_anti = tmp_anti %>% filter(!is.na(Cancername))
  
  anti_drug_gdsc = gdsc_w_cluster %>% 
    filter(DRUG_NAME %in% unique(tmp_anti_filt$Product))
  # 
  # anti_drug_long = anti_drug_gdsc %>% filter(cluster == "long")
  # anti_drug_short = anti_drug_gdsc %>% filter(cluster == "short")
  # 
  # anno_slice = t.test(slice_long$Z_SCORE, slice_short$Z_SCORE)$p.value
  
  library(gridExtra)
  # drug_name = "Olaparib"
  
  sig_anti_target = data.frame()
  for (drug_name in unique(anti_drug_gdsc$DRUG_NAME)) {
    # n = n+1
    tmp_for_drug = anti_drug_gdsc %>% filter(DRUG_NAME == drug_name)
    
    tmp_anti_long = tmp_for_drug %>% filter(cluster == "long")
    tmp_anti_short = tmp_for_drug %>% filter(cluster == "short")
    
    if (nrow(tmp_anti_long) < 2 | nrow(tmp_anti_short) < 2) {
      next
    } else {
      anno_tmp = t.test(tmp_anti_long$Z_SCORE, tmp_anti_short$Z_SCORE)$p.value
      
      tmp_drug = ggplot(tmp_for_drug , aes( x = cluster , y = Z_SCORE, fill= cluster)) + 
        # geom_violin(color ="black") +
        # geom_boxplot(width=0.1, color = "black" , fill="white")+
        geom_boxplot()+
        # scale_color_manual(values="black","black") + 
        scale_fill_manual(values=c("#4DAF4A", "#E41A1C")) +
        
        geom_signif(
          annotation = paste0(formatC(anno_tmp, digits = 3)),
          map_signif_level = TRUE,
          comparisons = list(c("long", "short")),
          # y_position = 3.05, 
          # xmin = 1, 
          # xmax = 3,
          # tip_length = c(0.22, 0.02),
        ) +
        ggtitle(paste0(drug_name , " : from ",paste(tmp_anti_filt %>%
                    filter(Product == drug_name) %>%
                    select(4:12) %>% 
                    mutate(across(where(~ any(. == "Y" & !is.na(.))), ~.)) %>%
                    select(where(~ any(!is.na(.)))) %>% colnames() ,collapse = ",") )) +
        # stat_compare_means(label.y = 10) +
        theme_minimal()
      
      
      
      if (mean(tmp_anti_long$Z_SCORE) - mean(tmp_anti_short$Z_SCORE) < 0) {
        tolerance = "short"
      } else {
        tolerance = "long"
      }
      
      if (anno_tmp < 0.05) {
        
        ggsave(filename = paste0(CancerType,"_",drug_name,"_anti_repurposing_sig.svg"), tmp_drug)
        tmp_target = data.frame(drug_name = drug_name,
                                tolerance = tolerance,
                                target = unique(tmp_anti_filt[which(tmp_anti_filt$Product == drug_name ),]$Targets))
        tmp_genes = str_trim(str_split(tmp_target$target, ";")[[1]])
        
        total_pathway = data.frame()
        for (p in unique(single_genes$Pathway)) {
          tmp_p = single_genes %>% filter(Pathway == p)
          
          pval_p = phyper(q = length(intersect(tmp_p$Genes, tmp_genes)) , 
                 m = length(tmp_p$Genes),          
                 n = length(single_genes %>% filter(Pathway != p) %>% pull(Genes)) ,
                 k = length(tmp_genes))
          tmp_pval_p = data.frame(Pathway = p, pval = pval_p)
          total_pathway = rbind(total_pathway, tmp_pval_p)
          
        }
        
        print(sum(total_pathway < 0.05))
        
        total_pathwaylink = data.frame()
        for (pp in unique(link_genes_filtered_df$Pathway)) {
          tmp_pp = link_genes_filtered_df %>% filter(Pathway == pp)
          
          pval_pp = phyper(q = length(intersect(tmp_pp$Genes, tmp_genes)) , 
                        m = length(tmp_pp$Genes),          
                        n = length(link_genes_filtered_df %>% filter(Pathway != pp) %>% pull(Genes)) ,
                        k = length(tmp_genes))
          tmp_pval_pp = data.frame(Pathway = pp, pval = pval_pp)
          total_pathwaylink = rbind(total_pathwaylink, tmp_pval_pp)
          
        }
        
        print(sum(total_pathwaylink < 0.05))
        
        each_sig = total_pathway %>% 
          filter(pval < 0.05)
        link_sig = total_pathwaylink %>% 
          filter(pval < 0.05) 
        
        if (nrow(each_sig) == 0 | nrow(link_sig) == 0) {
          next
        } else {
          tmp_target$critical_features = paste(colnames(gc_TCGA)[colnames(gc_TCGA) %in% c(each_sig$Pathway,link_sig$Pathway)], collapse = ";")
          
          
        }
        
        sig_anti_target = rbind(sig_anti_target,tmp_target)
      } 
      
    }
    
  }
  
  if (nrow(sig_anti_target) != 0) {
    write.csv(sig_anti_target, paste0(CancerType,"_anti_repurposing_sig.csv"))
  } 
  
  # 
  # cf_sl = read.csv(paste0(filepath, "04.Results/short_long/ttest_common/",CancerType,"_critical_features_short_long_common.csv"))
  # 
  # nodes = c()
  # edges = data.frame(matrix(ncol = 4))
  # colnames(edges) = c("from","to","group","cf")
  # # critical_features = "P16"
  # 
  # for (critical_features in cf_sl %>% filter(classification != "common") %>% pull(variable)) {
  #   
  #   nodes = unique(c(nodes , paste0("P",strsplit(critical_features, "P")[[1]][2]) , paste0("P",strsplit(critical_features, "P")[[1]][3])))
  #   
  #   if (is.na(strsplit(critical_features, "P")[[1]][3] )) {
  #     edges[critical_features,"from"] = paste0("P",strsplit(critical_features, "P")[[1]][2])
  #     edges[critical_features,"to"] = paste0("P",strsplit(critical_features, "P")[[1]][2])
  #     edges[critical_features,"group"] = cf_sl %>% filter(variable == critical_features) %>% select(classification) %>% pull()
  #     edges[critical_features,"cf"] = critical_features
  #     
  #   } else {
  #     edges[critical_features,"from"] = paste0("P",strsplit(critical_features, "P")[[1]][2]) 
  #     edges[critical_features,"to"] = paste0("P",strsplit(critical_features, "P")[[1]][3])
  #     edges[critical_features,"group"] = cf_sl %>% filter(variable == critical_features) %>% select(classification) %>% pull()
  #     edges[critical_features,"cf"] = critical_features
  #     
  #   }
  #   
  # }
  # 
  # edges = edges[-1,]
  # # spe_features_drug
  # rownames(edges) = NULL
  # remove(sf_nih_drug,sf_anti_drug)
  # 
  # if (nrow(sig_nih_target) == 0 & nrow(sig_anti_target) == 0) {
  #   next
  # } else if (nrow(sig_nih_target) != 0 & nrow(sig_anti_target) == 0) {
  #   sf_nih_drug = unlist(str_split(sig_nih_target$critical_features, ";"))
  #   sf_nih_drug = sf_nih_drug[sf_nih_drug!= ""]
  #   total_drug_network = edges %>%
  #     as_tbl_graph()  %N>% 
  #     mutate(nih_cf = case_when(name %in% sf_nih_drug ~ 1,
  #                               .default = 0))  %E>%
  #     mutate(nih_cf = case_when(cf %in% sf_nih_drug ~ 1, 
  #                               .default =0 )) %N>%
  #     mutate(color = case_when(nih_cf == 1 ~ "nih",
  #                              .default = "unspe")) %E>%
  #     mutate(color = case_when(nih_cf == 1 ~ "nih",
  #                              .default = "unspe")) %E>%
  #     
  #     mutate(edge_weight = case_when(color == "unspe" ~ 0.3,
  #                                    .default = 1))%>% 
  #     ggraph(layout = "nicely") +
  #     geom_edge_link(aes(color = color,
  #                        edge_alpha = edge_weight,
  #                        edge_width = edge_weight),          # 엣지 색깔
  #                    alpha = 0.5) +             # 엣지 명암
  #     scale_edge_width(range = c(0.5, 2)) +   
  #     scale_edge_alpha(range = c(0.3,0.7)) +
  #     geom_node_point(aes(color = color),     # 노드 색깔
  #                     size = 5) +               # 노드 크기
  #     
  #     geom_node_text(aes(label = name),         # 텍스트 표시
  #                    repel = T,                 # 노드밖 표시
  #                    size = 5) +  
  #     scale_color_manual(values = c("unspe" = "grey50",
  #                                   # "anti" = "#925E9FFF",
  #                                   "nih"= "#E41A1C", 
  #                                   "dual" = "#AD002AFF")) +
  #     scale_edge_colour_manual(values = c("unspe" = "grey50",
  #                                         # "anti" = "#925E9FFF",
  #                                         "nih"= "#E41A1C",
  #                                         "dual" = "#AD002AFF")) +
  #     theme_graph()           
  #   
  #   ggsave(total_drug_network , filename = paste0(Cancername,"_nih_target_network_wo_common.svg"))
  #   write.csv(sig_nih_target, paste0(CancerType,"_cellline_nih_approved_sig.csv"))
  #   
  # } else if (nrow(sig_nih_target) == 0 & nrow(sig_anti_target) != 0) {
  #   sf_anti_drug = unlist(str_split(sig_anti_target$critical_features, ";"))
  #   sf_anti_drug = sf_anti_drug[sf_anti_drug!= ""]
  #   
  #   total_drug_network = edges %>%
  #     as_tbl_graph() %N>% 
  #     mutate(anti_cf = case_when(name %in% sf_anti_drug ~ 1,
  #                                .default = 0))  %E>%
  #     mutate(anti_cf = case_when(cf %in% sf_anti_drug ~ 1, 
  #                                .default =0 ))  %N>%
  #     mutate(color = case_when(anti_cf == 1  ~ "anti",
  #                              .default = "unspe")) %E>%
  #     mutate(color = case_when(anti_cf == 1 ~ "anti",
  #                              .default = "unspe")) %E>%
  #     mutate(edge_weight = case_when(color == "unspe" ~ 0.3,
  #                                    .default = 1)) %>% 
  #     ggraph(layout = "nicely") +
  #     geom_edge_link(aes(color = color,
  #                        edge_alpha = edge_weight,
  #                        edge_width = edge_weight),          # 엣지 색깔
  #                    alpha = 0.5) +             # 엣지 명암
  #     scale_edge_width(range = c(0.5, 2)) +   
  #     scale_edge_alpha(range = c(0.3,0.7)) +
  #     geom_node_point(aes(color = color),     # 노드 색깔
  #                     size = 5) +               # 노드 크기
  #     
  #     geom_node_text(aes(label = name),         # 텍스트 표시
  #                    repel = T,                 # 노드밖 표시
  #                    size = 5) +  
  #     
  #     scale_color_manual(values = c("unspe" = "grey50", 
  #                                   "anti" = "#925E9FFF",
  #                                   # "nih"= "#E41A1C", 
  #                                   "dual" = "#AD002AFF")) +
  #     scale_edge_colour_manual(values = c("unspe" = "grey50",
  #                                         "anti" = "#925E9FFF",
  #                                         # "nih"= "#E41A1C",
  #                                         "dual" = "#AD002AFF")) +
  #     theme_graph()           
  #   
  #   ggsave(total_drug_network , filename = paste0(Cancername,"_anti_target_network_wo_common.svg"))
  #   
  #   write.csv(sig_anti_target, paste0(CancerType,"_cellline_anti_licensed_sig.csv"))
  #   
  # } else if (nrow(sig_nih_target) != 0 & nrow(sig_anti_target) != 0) {
  #   sf_nih_drug = unlist(str_split(sig_nih_target$critical_features, ";"))
  #   sf_anti_drug = unlist(str_split(sig_anti_target$critical_features, ";"))
  #   
  #   total_drug_network = edges %>%
  #     as_tbl_graph() %N>% 
  #     mutate(anti_cf = case_when(name %in% sf_anti_drug ~ 1,
  #                                .default = 0)) %N>% 
  #     mutate(nih_cf = case_when(name %in% sf_nih_drug ~ 1,
  #                               .default = 0)) %E>%
  #     mutate(anti_cf = case_when(cf %in% sf_anti_drug ~ 1, 
  #                                .default =0 )) %E>%
  #     mutate(nih_cf = case_when(cf %in% sf_nih_drug ~ 1, 
  #                               .default =0 )) %N>%
  #     mutate(color = case_when(anti_cf == 1 & nih_cf == 1 ~ "dual",
  #                              anti_cf == 1 & nih_cf != 1 ~ "anti",
  #                              anti_cf != 1 & nih_cf == 1 ~ "nih",
  #                              anti_cf != 1 & nih_cf != 1 ~ "unspe",
  #                              .default = "unspe")) %E>%
  #     mutate(color = case_when(anti_cf == 1 & nih_cf == 1 ~ "dual",
  #                              anti_cf == 1 & nih_cf != 1 ~ "anti",
  #                              anti_cf != 1 & nih_cf == 1 ~ "nih",
  #                              anti_cf != 1 & nih_cf != 1 ~ "unspe",
  #                              .default = "unspe")) %E>%
  #     mutate(edge_weight = case_when(color == "unspe" ~ 0.3,
  #                                    .default = 1))%>% 
  #     ggraph(layout = "nicely") +
  #     geom_edge_link(aes(color = color,
  #                        edge_alpha = edge_weight,
  #                        edge_width = edge_weight),          # 엣지 색깔
  #                    alpha = 0.5) +             # 엣지 명암
  #     scale_edge_width(range = c(0.5, 2)) +   
  #     scale_edge_alpha(range = c(0.3,0.7)) +
  #     geom_node_point(aes(color = color),     # 노드 색깔
  #                     size = 5) +               # 노드 크기
  #     
  #     geom_node_text(aes(label = name),         # 텍스트 표시
  #                    repel = T,                 # 노드밖 표시
  #                    size = 5) +  
  #     # scale_color_manual(values = c("short" = "blue", "common" = "red", "long" = "green")) +
  #     scale_color_manual(values = c("unspe" = "grey50", "anti" = "#925E9FFF","nih"= "#E41A1C", "dual" = "#AD002AFF")) +
  #     # scale_color_manual(values = c("short" = "#E41A1C", "long" = "#4DAF4A")) +
  #     scale_edge_colour_manual(values = c("unspe" = "grey50", "anti" = "#925E9FFF","nih"= "#E41A1C","dual" = "#AD002AFF")) +
  #     # geom_segment(aes(x = -3, y = -1.5, xend = 0.1, yend = 0.1),
  #     #                           arrow = arrow(length = unit(0.1, "cm"))) +
  #     theme_graph()           
  #   
  #   ggsave(total_drug_network , filename = paste0(Cancername,"_dual_target_network_wo_common.svg"))
  #   
  #   write.csv(sig_nih_target, paste0(CancerType,"_cellline_nih_approved_sig.csv"))
  #   write.csv(sig_anti_target, paste0(CancerType,"_cellline_anti_licensed_sig.csv"))
  #   
  # }
  # 
}


