library(survival) 
library(tidygraph)
library(survminer)
library(pheatmap)
library(RColorBrewer)
library(readxl)
library(openxlsx)


filepath = "/home/seokwon/nas/"
ref_path = paste0(filepath, "99.reference/")

Cancerlist = dir(paste0(filepath, "/00.data/filtered_TCGA/"))
surv_total_results = read_xlsx("~/nas/04.Results/Total_results_survpval2.xlsx")

setwd("~/nas/04.Results/short_long/quantile")
# num_CancerType = "19.TCGA-LIHC"
# for all
for (num_CancerType in Cancerlist) {
  
  main.path_tc = paste0(filepath, "00.data/filtered_TCGA/", num_CancerType)
  CancerType = gsub('[.]','',gsub('\\d','', num_CancerType))
  
  # call input
  
  cancer_bf = read.csv(paste0("~/nas/04.Results/short_long/ttest_common/",CancerType,"_critical_features_short_long_common.csv"))
  short_long = readRDS(paste0(filepath,"04.Results/short_long/",CancerType,"_critical_features_short_long.rds"))
  short_long = short_long[which(!is.na(short_long$duration)),]
  
  short_long_filt = short_long %>% select(-vitalstatus,-duration, -status)
  
  # fig
  
  total_group_for_fig = short_long_filt
  
  total_group_meta =data.frame(cluster = total_group_for_fig[,c("cluster")])
  
  total_group_for_tmp = total_group_for_fig[,which(!colnames(total_group_for_fig) %in% c("cluster"))]
  
  # # Convert the matrix to a numeric matrix
  
  tmp_numeric <- matrix(as.numeric(unlist(total_group_for_tmp)), nrow = nrow(total_group_for_tmp))
  vec <- as.vector(tmp_numeric)
  # hist(vec)
  total_group_for_tmp[total_group_for_tmp > quantile(vec, probs = 0.75) + 1.5*IQR(vec)] <- round(quantile(vec, probs = 0.75) + 1.5*IQR(vec),1)
  
  total_group_for_fig_final = cbind(total_group_for_tmp,total_group_meta)
  dim(total_group_for_fig_final)
  # pic
  annotation_col <- data.frame(patients_group= total_group_for_fig_final$cluster)
  rownames(annotation_col) <- rownames(total_group_for_fig_final)
  nrow(annotation_col)
  short_long_colors <- c("short" = "red", "long" = "#009E73")
  
  annotation_row = data.frame(types = cancer_bf$classification)
  rownames(annotation_row) <- cancer_bf$variable
  nrow(annotation_row)
  num_features = c("short" = "#E41A1C", "long" = "#4DAF4A" , common = "#377EB8")
  
  ann_colors_sl = list(patients_group = short_long_colors, types = num_features )
  
  Colors = brewer.pal(9, "YlOrRd")
  
  png(filename = paste0(CancerType,"_short_long_complex_pval_quant_cluster_row_critical_features.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  
  total_out =  ComplexHeatmap::pheatmap(as.matrix(t(total_group_for_fig_final %>%
                                                      dplyr::select(-cluster) %>%
                                                      as.matrix())),
                                        column_split = factor(annotation_col$patients_group, levels = c("short","long")),
                                        annotation_col = annotation_col,
                                        annotation_row = annotation_row,
                                        annotation_colors = ann_colors_sl,
                                        cluster_rows = T,
                                        cluster_cols = T,
                                        legend = T,
                                        annotation_legend = T,
                                        show_colnames = F,
                                        cluster_column_slices = FALSE,
                                        color = Colors,
                                        show_rownames = F
  ) 
  
  print(total_out)
  
  dev.off()
  
  tmp_roworder = hclust(dist(as.matrix(t(total_group_for_fig_final %>%
                                           dplyr::select(-cluster) %>%
                                           as.matrix()))))
  
  write.csv(tmp_roworder$labels[ tmp_roworder$order ], paste0("~/nas/04.Results/short_long/quantile/",CancerType,"_clustering_ordered_rownames.csv"))
  
  annotation_col <- data.frame(patients_group= total_group_for_fig_final$cluster)
  rownames(annotation_col) <- rownames(total_group_for_fig_final)
  
  short_long_colors <- c("short" = "red", "long" = "#009E73")
  
  annotation_row = data.frame(types = cancer_bf$classification)
  rownames(annotation_row) <- cancer_bf$variable
  
  custom_order <- c("short", "common", "long")
  
  annotation_row = annotation_row %>% arrange(factor(types, levels = custom_order))
  
  num_features = c("short" = "#E41A1C", "long" = "#4DAF4A" , common = "#377EB8")
  
  ann_colors_sl = list(patients_group = short_long_colors, types = num_features )
  
  Colors = brewer.pal(9, "YlOrRd")
  total_group_for_fig_final = total_group_for_fig_final[,c(rownames(annotation_row),"cluster")]
  
  png(filename = paste0(CancerType,"_short_long_complex_pval_quant_critical_features.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  total_out =  ComplexHeatmap::pheatmap(as.matrix(t(total_group_for_fig_final %>%
                                                      dplyr::select(-cluster) %>%
                                                      as.matrix())),
                                        column_split = factor(annotation_col$patients_group, levels = c("short","long")),
                                        row_split = factor(annotation_row$types , levels = c(unique(annotation_row$types))),
                                        annotation_col = annotation_col,
                                        annotation_row = annotation_row,
                                        annotation_colors = ann_colors_sl,
                                        cluster_rows = T,
                                        cluster_cols = T,
                                        legend = T,
                                        annotation_legend = T,
                                        show_colnames = F,
                                        cluster_column_slices = FALSE,
                                        cluster_row_slices = FALSE,
                                        color = Colors,
                                        show_rownames = F
  ) 
  
  print(total_out)
  
  dev.off()
  write.csv(annotation_row, paste0("~/nas/04.Results/short_long/quantile/",CancerType,"_ordered_rownames.csv"))
  
}  
