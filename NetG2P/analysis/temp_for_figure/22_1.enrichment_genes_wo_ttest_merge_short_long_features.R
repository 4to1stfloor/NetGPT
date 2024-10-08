library(stringr)
library(data.table)
# library(ComplexHeatmap)
# library(TCGAbiolinks)
# library(SingleCellExperiment)
# library(SummarizedExperiment)
library(pheatmap)
library(readxl)
library(org.Hs.eg.db)
library(clusterProfiler)
# library(DESeq2)
# library(survival) 
# library(survminer) 
# library(DOSE)
# library(UpSetR)
library(enrichplot)
library(dplyr)
library(readxl)
library(tidyverse)
library(rrvgo)

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

Cancerlist = dir(paste0(filepath, "/00.data/filtered_TCGA/"))
sce_path = "/mnt/gluster_server/data/raw/TCGA_data/00.data/"

surv_total_results = read_xlsx("~/nas/04.Results/Total_results_survpval2.xlsx")

scatterPlot_edit <- function (simMatrix, reducedTerms, algorithm = c("pca", "umap"), 
                              onlyParents = FALSE, size = "score", addLabel = TRUE, labelSize = 3) 
{
  if (!all(sapply(c("ggplot2", "ggrepel", "umap"), requireNamespace, 
                  quietly = TRUE))) {
    stop("Packages ggplot2, ggrepel, umap and/or its dependencies not available. ", 
         "Consider installing them before using this function.", 
         call. = FALSE)
  }
  if (onlyParents) {
    x <- as.data.frame(table(reducedTerms$parentTerm))
    reducedTerms <- reducedTerms[reducedTerms$term == reducedTerms$parentTerm, 
    ]
    simMatrix <- simMatrix[reducedTerms$go, reducedTerms$go]
    reducedTerms[, size] <- x$Freq[match(reducedTerms$term, 
                                         x$Var1)]
  }
  x <- switch(match.arg(algorithm), pca = cmdscale(as.matrix(as.dist(1 - 
                                                                       simMatrix)), eig = TRUE, k = 2)$points, umap = umap::umap(as.matrix(as.dist(1 - 
                                                                                                                                                     simMatrix)))$layout)
  df <- cbind(as.data.frame(x), reducedTerms[match(rownames(x), 
                                                   reducedTerms$go), c("term", "parent", "parentTerm", 
                                                                       size)])
  p <- ggplot2::ggplot(df, ggplot2::aes(x = V1, y = V2, color = parentTerm)) + 
    ggplot2::geom_point(ggplot2::aes_string(size = size), 
                        alpha = 0.5) + ggplot2::scale_color_discrete(guide = "none") + 
    ggplot2::scale_size_continuous(guide = "none", range = c(0, 
                                                             25)) + ggplot2::scale_x_continuous(name = "") + 
    ggplot2::scale_y_continuous(name = "") + ggplot2::theme_minimal() + 
    ggplot2::theme(axis.text.x = ggplot2::element_blank(), 
                   axis.text.y = ggplot2::element_blank())
  if (addLabel) {
    p + ggrepel::geom_label_repel(ggplot2::aes(label = parentTerm), 
                                  data = subset(df, parent == rownames(df)), 
                                  box.padding = grid::unit(1,"lines"), 
                                  size = labelSize,
                                  xlim = c(NA,NA),
                                  ylim = c(NA,NA),
                                  max.overlaps = 50)
  }
  else {
    p
  }
}

# for fic
fig_path = paste0(filepath,"04.Results/GOenrichment_test/BP")
if(!dir.exists(fig_path)){
  dir.create(fig_path)
  print(paste0("Created folder: ", fig_path))
} else {
  print(paste0("Folder already exists: ", fig_path))
}
setwd(fig_path)

# for all
for (num_CancerType in Cancerlist) {
  
  main.path_tc = paste0(filepath, "00.data/filtered_TCGA/", num_CancerType)
  CancerType = gsub('[.]','',gsub('\\d','', num_CancerType))
  
  # call input
  
  short_long_features = read_xlsx(paste0(filepath, "04.Results/short_long/",CancerType, "_best_features_short_long.xlsx"))
  # bf_short_long = readRDS(paste0(filepath, "04.Results/short_long/",CancerType,"_best_features_short_long.rds"))
  # duration_log_df = readRDS(paste0(main.path_tc, "/", CancerType,"_dual_add_duration_log.rds"))
  
  # 일단 unique gene으로 해봄 
  # total_link_genes = link_genes_filtered_df[which(link_genes_filtered_df$Pathway %in% short_long_features$variable),]$Genes
  # total_single_genes = single_genes[which(single_genes$Pathway %in% short_long_features$variable),]$Genes
  # total_bf_genes = c(total_link_genes,total_single_genes)
  
  short_features = short_long_features[which(short_long_features$classification == "short"),]$variable 
  long_features = short_long_features[which(short_long_features$classification == "long"),]$variable 
  
  short_gene = c()
  long_gene = c()
  
  # short
  for (sf in short_features) {
    count <- str_count(sf, "P")
    if (count == 1) {
      tmp_short_gene = single_genes[which(single_genes$Pathway == sf),]$Genes
    } else {
      tmp_short_gene = link_genes_filtered_df[which(link_genes_filtered_df$Pathway == sf),]$Genes
    }
    short_gene = c(short_gene, tmp_short_gene)
    
  }
  
  # long
  for (lf in long_features) {
    count <- str_count(lf, "P")
    if (count == 1) {
      tmp_long_gene = single_genes[which(single_genes$Pathway == lf),]$Genes
    } else {
      tmp_long_gene = link_genes_filtered_df[which(link_genes_filtered_df$Pathway == lf),]$Genes
    }
    long_gene = c(long_gene, tmp_long_gene)
    
  }
  
  if (length(long_gene) != 0 && length(short_gene) != 0 ) {
    short_gene_en = AnnotationDbi::select(org.Hs.eg.db, short_gene, 'ENTREZID', 'SYMBOL')[
      which(!is.na(AnnotationDbi::select(org.Hs.eg.db, short_gene, 'ENTREZID', 'SYMBOL')$ENTREZID)),]
    short_gene_en <- data.frame(short_gene_en, row.names = NULL)
    
    long_gene_en = AnnotationDbi::select(org.Hs.eg.db, long_gene, 'ENTREZID', 'SYMBOL')[
      which(!is.na(AnnotationDbi::select(org.Hs.eg.db, long_gene, 'ENTREZID', 'SYMBOL')$ENTREZID)),]
    long_gene_en <- data.frame(long_gene_en, row.names = NULL)
    # top_genes_group = list(short_cluster = short_gene_en$ENTREZID,long_cluster = long_gene_en$ENTREZID)
    
  } else if (length(long_gene) == 0 ) {
    short_gene_en = AnnotationDbi::select(org.Hs.eg.db, short_gene, 'ENTREZID', 'SYMBOL')[
      which(!is.na(AnnotationDbi::select(org.Hs.eg.db, short_gene, 'ENTREZID', 'SYMBOL')$ENTREZID)),]
    short_gene_en <- data.frame(short_gene_en, row.names = NULL)
    # top_genes_group = list(short_cluster = short_gene_en$ENTREZID)
    
  } else if (length(short_gene) == 0 ) {
    long_gene_en = AnnotationDbi::select(org.Hs.eg.db, long_gene, 'ENTREZID', 'SYMBOL')[
      which(!is.na(AnnotationDbi::select(org.Hs.eg.db, long_gene, 'ENTREZID', 'SYMBOL')$ENTREZID)),]
    long_gene_en <- data.frame(long_gene_en, row.names = NULL)
    # top_genes_group = list(long_cluster = long_gene_en$ENTREZID)
    
  } else {
    print("I don't know")
  }
  
  # total_enrichGO = compareCluster(geneCluster = top_genes_group, fun = "enrichGO", OrgDb = org.Hs.eg.db)
  short_enrichGO = enrichGO(short_gene_en$ENTREZID ,OrgDb = org.Hs.eg.db , keyType = "ENTREZID" , ont = "BP" )
  long_enrichGO = enrichGO(long_gene_en$ENTREZID ,OrgDb = org.Hs.eg.db , keyType = "ENTREZID" , ont = "BP" )
  
  short_enrichGO_df = as.data.frame(short_enrichGO)
  long_enrichGO_df = as.data.frame(long_enrichGO)
  
  simMatrix_short <- calculateSimMatrix(short_enrichGO_df$ID,
                                        orgdb=org.Hs.eg.db,
                                        ont="BP",
                                        method="Rel")
  
  simMatrix_long <- calculateSimMatrix(long_enrichGO_df$ID,
                                       orgdb=org.Hs.eg.db,
                                       ont="BP",
                                       method="Rel")
  
  # total_enrichGO = compareCluster(geneCluster = top_genes_group, fun = "enrichGO", OrgDb = org.Hs.eg.db)
  # total_enrichGO_df = as.data.frame(total_enrichGO)
  # 
  # simMatrix_all <- calculateSimMatrix(total_enrichGO_df$ID,
  #                                     orgdb=org.Hs.eg.db,
  #                                     ont="MF",
  #                                     method="Rel")
  
  scores_short <- setNames(-log10(short_enrichGO_df$qvalue), short_enrichGO_df$ID)
  scores_long <- setNames(-log10(long_enrichGO_df$qvalue), long_enrichGO_df$ID)
  
  
  if (sum(is.na(scores_short)) != 0) {
    scores_short[which(is.na(scores_short))] = 0
  }
  
  if (sum(is.na(scores_long)) != 0) {
    scores_long[which(is.na(scores_long))] = 0
  }
  
  reducedTerms_short <- reduceSimMatrix(simMatrix_short,
                                        scores_short,
                                        threshold=0.7,
                                        orgdb="org.Hs.eg.db")
  
  reducedTerms_long <- reduceSimMatrix(simMatrix_long,
                                       scores_long,
                                       threshold=0.7,
                                       orgdb="org.Hs.eg.db")
  
  # fiq
  png(filename = paste0(CancerType,"_simmat_heatmap_short_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  heatmap_sim_short = heatmapPlot(simMatrix_short,
                                  reducedTerms_short,
                                  annotateParent=TRUE,
                                  annotationLabel="parentTerm",
                                  fontsize=6)
  
  print(heatmap_sim_short)
  dev.off()
  
  png(filename = paste0(CancerType,"_simmat_heatmap_long_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  heatmap_sim_long = heatmapPlot(simMatrix_long,
                                 reducedTerms_long,
                                 annotateParent=TRUE,
                                 annotationLabel="parentTerm",
                                 fontsize=6)
  
  print(heatmap_sim_long)
  dev.off()
  
  
  png(filename = paste0(CancerType,"_scatter_short_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  scatter_mat_short = scatterPlot_edit(simMatrix_short, reducedTerms_short)
  
  print(scatter_mat_short)
  dev.off()
  
  png(filename = paste0(CancerType,"_scatter_long_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  scatter_mat_long = scatterPlot_edit(simMatrix_long, reducedTerms_long)
  
  print(scatter_mat_long)
  dev.off()
  
  png(filename = paste0(CancerType,"_tree_short_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  tree_mat_short = treemapPlot(reducedTerms_short)
  
  print(tree_mat_short)
  dev.off()
  
  png(filename = paste0(CancerType,"_tree_long_wo_ttest_BP.png"),
      width = 35, height = 35,  units = "cm" ,pointsize = 12,
      bg = "white", res = 1200, family = "")
  
  tree_mat_long = treemapPlot(reducedTerms_long)
  
  print(tree_mat_long)
  dev.off()
  
  remove(top_genes_group,long_gene,short_gene,simMatrix_long,simMatrix_short,reducedTerms_short,reducedTerms_long,scores_long,scores_short,
         short_enrichGO,long_enrichGO,
         short_enrichGO_df,
         long_enrichGO_df)
}  


