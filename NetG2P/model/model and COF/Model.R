library(h2o)

# settings
save_folder = "your path"
main.path_tc = "The path where TCGA data is stored"
CancerType = "Interest cancer type"
cut_features = 50 # can adjust this value

set.seed(13524)
localH2O = h2o.init(ip = "localhost", port = sample(x=00000:65536,size=1,replace=F), startH2O = TRUE,min_mem_size = "400G",
                    nthreads = 96,enable_assertions = FALSE)

h2o.removeAll()

# 1) preprocessing
# (1) for TCGA data upload

# Sys.sleep(runif(1,min=1,max=10))

data_tc_link = readRDS(file = paste0(main.path_tc,"/",CancerType,"_pathwaylink_all_log.rds"))
data_tc_each = readRDS(file = paste0(main.path_tc,"/",CancerType,"_pathwayeach_all_log.rds"))

data_tc_link_filt = data_tc_link[,which(colSums(data_tc_link[-ncol(data_tc_link)]) != 0)]
data_tc_each_filt = data_tc_each[,which(colSums(data_tc_each[-ncol(data_tc_each)]) != 0)]

data_tc_link_filt$vitalstatus = data_tc_link$vitalstatus
data_tc_each_filt$vitalstatus = data_tc_each$vitalstatus

data_tc_link_filt = data_tc_link_filt[intersect(rownames(data_tc_link_filt), rownames(data_tc_each_filt)),]
data_tc_each_filt = data_tc_each_filt[intersect(rownames(data_tc_link_filt), rownames(data_tc_each_filt)),]

if (all.equal(rownames(data_tc_link_filt), rownames(data_tc_each_filt))) {
  data_tc_link_filt$vitalstatus = NULL
  data_tc = cbind(data_tc_link_filt,data_tc_each_filt)
}


if ("Not Reported" %in% data_tc$vitalstatus ) {
  if (length(which(data_tc$vitalstatus == "Not Reported")) == 1) {
    data_tc = data_tc[-which(data_tc$vitalstatus == "Not Reported"),]
  } else {
    while ("Not Reported" %in% data_tc$vitalstatus) {
      data_tc = data_tc[-which(data_tc$vitalstatus == "Not Reported")[1],]
    }
    
  }
  
}
if (sum((colSums(data_tc[,-ncol(data_tc)]) == 0)) != 0 ) {
  data_tc_ori = data_tc[,-which(colSums(data_tc[,-ncol(data_tc)]) == 0)]
} else {
  data_tc_ori = data_tc
}

# 2) transfer data for model build
# A - data split

data_tc_ori_alive = data_tc_ori[data_tc_ori$vitalstatus == "Alive",]
data_tc_ori_dead = data_tc_ori[data_tc_ori$vitalstatus == "Dead",]

train_alive = sample(1:nrow(data_tc_ori_alive), nrow(data_tc_ori_alive)*0.6) 
train_dead = sample(1:nrow(data_tc_ori_dead), nrow(data_tc_ori_dead)*0.6) 
testtmp_val_alive = -train_alive
testtmp_val_dead = -train_dead

train_tc_alive = data_tc_ori_alive[train_alive,]
train_tc_dead = data_tc_ori_dead[train_dead,]

train_tc = rbind(train_tc_alive,train_tc_dead)

testtmp_tc_alive = data_tc_ori_alive[testtmp_val_alive,]
testtmp_tc_dead = data_tc_ori_dead[testtmp_val_dead,]

valid_val_alive = sample(1:nrow(testtmp_tc_alive), nrow(testtmp_tc_alive)*0.5) 
valid_val_dead = sample(1:nrow(testtmp_tc_dead), nrow(testtmp_tc_dead)*0.5) 

test_val_alive = -valid_val_alive
test_val_dead = -valid_val_dead

valid_tc_alive = testtmp_tc_alive[valid_val_alive,]
valid_tc_dead = testtmp_tc_dead[valid_val_dead,]
valid_tc = rbind(valid_tc_alive,valid_tc_dead)

test_tc_alive = testtmp_tc_alive[test_val_alive,]
test_tc_dead = testtmp_tc_dead[test_val_dead,]
test_tc = rbind(test_tc_alive,test_tc_dead)

# B - Define input (features) and output (response) variables"

features=setdiff(colnames(data_tc_ori),"vitalstatus")
response = colnames(data_tc_ori)[length(colnames(data_tc_ori))]

# C - Convert the outcome variable into factor

train_tc$vitalstatus <- as.factor(train_tc$vitalstatus)
valid_tc$vitalstatus <- as.factor(valid_tc$vitalstatus)
test_tc$vitalstatus <- as.factor(test_tc$vitalstatus)

# D - Convert the data into h2o form (TCGA)

train_tc.hex <- as.h2o(x = train_tc, destination_frame = "train_tc.hex")
Sys.sleep(runif(1,min=1,max=10))
test_tc.hex <- as.h2o(x = test_tc, destination_frame = "test_tc.hex")
Sys.sleep(runif(1,min=1,max=10))
valid_tc.hex <- as.h2o(x = valid_tc, destination_frame = "valid_tc.hex")
Sys.sleep(runif(1,min=1,max=10))

# 3) model building 
# A - Deep learning 
# a - set hyper-parameter

dl_params <- list(
  activation = c("Rectifier", "Maxout", "Tanh", "RectifierWithDropout", "MaxoutWithDropout", "TanhWithDropout"), 
  hidden = list(c(5, 5, 5), c(10, 10, 10), c(50, 50, 50)),
  epochs = c(500,1000,2000,4000, 5000),
  l1 = c(0, 0.00001, 0.0001), 
  l2 = c(0, 0.00001, 0.0001),
  rate = c(0, 01, 0.005, 0.001),
  rate_annealing = c(1e-8, 1e-7, 1e-6),
  rho = c(0.9, 0.95, 0.99, 0.999),
  epsilon = c(1e-10, 1e-8, 1e-6, 1e-4),
  momentum_start = c(0, 0.5),
  momentum_stable = c(0.99, 0.5, 0),
  input_dropout_ratio = c(0, 0.1, 0.2,0.3,0.4),
  max_w2 = c(10, 100, 1000, 3.4028235e+38)
)

search_criteria <- list(strategy = "RandomDiscrete", 
                        max_models = 300,
                        max_runtime_secs = 1200,
                        stopping_tolerance = 0.0001,
                        stopping_rounds = 40)

# b - train

top_acc = 0
filtered_features_list = list()
dl_round_acc = data.frame(matrix(ncol = 2))
colnames(dl_round_acc) = c("round", "acc")

for (num_round in 1:(ncol(train_tc) / cut_features)) {
  
  if (num_round == 1) {
    new_features = features
  }
  
  dl_grid_filtered <- h2o.grid(algorithm = "deeplearning", 
                               x = new_features,
                               y = response,
                               grid_id = "dl_grid_filtered",
                               training_frame = train_tc.hex,
                               validation_frame = valid_tc.hex,
                               nfolds = 5,
                               fold_assignment = "Modulo",
                               keep_cross_validation_predictions=TRUE,
                               hyper_params = dl_params,
                               search_criteria = search_criteria,
                               seed = 1
  )
  
  # Sys.sleep(runif(1,min=1,max=10))
  
  tmp.dl_test_filtered_df = as.data.frame(h2o.make_leaderboard(dl_grid_filtered, test_tc.hex))
  assign(paste0('best_filtered_dl',1:(ncol(train_tc) / cut_features))[num_round], 
         h2o.getModel(tmp.dl_test_filtered_df[which(tmp.dl_test_filtered_df$aucpr == max(tmp.dl_test_filtered_df$aucpr))[1],]$model_id)) 
  
  best_filtered_dl = get(paste0('best_filtered_dl',1:(ncol(train_tc) / cut_features))[num_round])
  
  if (num_round == 1) {
    tmp_features = rev(h2o.varimp(best_filtered_dl)$variable )
  }
  
  best_filtered_dl_perf = h2o.performance(best_filtered_dl, newdata = test_tc.hex)
  best_filtered_dl_conma = as.data.frame(h2o.confusionMatrix(best_filtered_dl_perf))
  af_acc = round(1-best_filtered_dl_conma$Error[3],3)
  
  dl_round_acc[num_round,]$round = num_round  
  dl_round_acc[num_round,]$acc = af_acc
  
  print(paste("accuracy :", af_acc ,"round :" ,num_round))
  filtered_features_list[as.character(num_round)] = af_acc
  
  if (top_acc < af_acc) {
    top_acc = af_acc
    print(top_acc)
  }
  
  if (top_acc < 0.8 ) {
    max_num = num_round * cut_features
    new_features = tmp_features[-(1:max_num)]
    print(length(new_features))
    
  } else {
    break
  }
  
  remove(dl_grid_filtered,tmp.dl_test_filtered_df,best_filtered_dl,best_filtered_dl_perf,best_filtered_dl_conma,af_acc)
}

top_num = names(filtered_features_list)[filtered_features_list == top_acc]
top_num = as.numeric(top_num)

if (length(top_num) != 1 ) {
  top_num = top_num[1]
}

best_cut_dl = get(paste0("best_filtered_dl",top_num))
print(paste("best_features :", best_cut_dl@parameters$x))

df_dl_merge_confusion = rbind(as.data.frame(h2o.confusionMatrix(best_cut_dl)),"\n",
                              as.data.frame(h2o.confusionMatrix(object = best_cut_dl,test_tc.hex)))
best_cut_dl_perf = h2o.performance(best_cut_dl, newdata = test_tc.hex)
best_cut_dl_conma = as.data.frame(h2o.confusionMatrix(best_cut_dl_perf))

# save results
write.csv(df_dl_merge_confusion,paste0(save_folder,"/", best_cut_dl@model_id,"_", round(1-best_cut_dl_conma$Error[3],3) ,"_confusionmatrix.csv"))
write.csv(dl_round_acc, paste0(save_folder,"/",CancerType, "_acc_dl_round.csv"))
h2o.saveModel(best_cut_dl, path = paste0(save_folder,"/", best_cut_dl@model_id,"_", round(1-best_cut_dl_conma$Error[3],3)))

# B - Gradient Boosting Machine 
# a - set hyper-parameter

gbm_params = list(learn_rate = seq(0.01, 0.001, 0.0001),
                  ntrees = seq(10, 5000, 10),
                  max_depth = seq(2, 30, 1),
                  sample_rate = seq(0, 2, 0.01),
                  col_sample_rate = seq(0.2, 2.0 ,0.01),
                  col_sample_rate_change_per_level = seq(0.9,1.1,0.01),  
                  nbins = round(2 ^ seq(2, 6, length = 15)),
                  min_split_improvement = c(0,1e-8,1e-6,1e-4),
                  histogram_type = c("UniformAdaptive","Random","QuantilesGlobal","RoundRobin")  
)

search_criteria <- list(strategy = "RandomDiscrete",
                        max_runtime_secs = 60* 60, 
                        max_models = 500,  
                        stopping_rounds = 5,                
                        stopping_metric = "logloss",
                        stopping_tolerance = 1e-3,seed = 1)

# b - train

top_acc = 0
filtered_features_list = list()
gbm_round_acc = data.frame(matrix(ncol = 2))
colnames(gbm_round_acc) = c("round", "acc")
for (num_round in 1:(ncol(train_tc) / cut_features)) {
  
  if (num_round == 1) {
    new_features = features
  }
  
  gbm_grid_filtered <- h2o.grid("gbm", x = new_features, y = response,
                                grid_id = "gbm_grid_filtered",
                                training_frame = train_tc.hex,
                                validation_frame = valid_tc.hex,
                                fold_assignment = "Modulo",
                                nfolds = 5,
                                seed = 1,
                                keep_cross_validation_predictions=TRUE,
                                hyper_params = gbm_params,
                                search_criteria = search_criteria)
  
  # Sys.sleep(runif(1,min=1,max=10))
  
  tmp.gbm_test_filtered_df = as.data.frame(h2o.make_leaderboard(gbm_grid_filtered, test_tc.hex))
  
  assign(paste0('best_filtered_gbm',1:(ncol(train_tc) / cut_features))[num_round], 
         h2o.getModel(tmp.gbm_test_filtered_df[which(tmp.gbm_test_filtered_df$aucpr == max(tmp.gbm_test_filtered_df$aucpr))[1],]$model_id)) 
  
  best_filtered_gbm = get(paste0('best_filtered_gbm',1:(ncol(train_tc) / cut_features))[num_round])
  
  best_filtered_gbm_perf = h2o.performance(best_filtered_gbm, newdata = test_tc.hex)
  best_filtered_gbm_conma = as.data.frame(h2o.confusionMatrix(best_filtered_gbm_perf))
  af_acc = round(1-best_filtered_gbm_conma$Error[3],3)
  
  gbm_round_acc[num_round,]$round = num_round  
  gbm_round_acc[num_round,]$acc = af_acc
  
  print(paste("accuracy :", af_acc ,"round :" ,num_round))
  filtered_features_list[as.character(num_round)] = af_acc
  print(af_acc)
  
  if (num_round == 1) {
    tmp_features = best_filtered_gbm@parameters$x
  }
  
  if (top_acc < af_acc) {
    top_acc = af_acc
    print(top_acc)
  }
  
  if (top_acc < 0.8 ) {
    
    max_num = num_round * cut_features
    new_features = tmp_features[-(1:max_num)]
    print(length(new_features))
    
  } else {
    break
  }
  
}

top_num = names(filtered_features_list)[filtered_features_list == top_acc]
top_num = as.numeric(top_num)

if (length(top_num) != 1 ) {
  top_num = top_num[1]
}

best_cut_gbm = get(paste0("best_filtered_gbm",top_num))

# print(paste("best_features :", best_cut_gbm@parameters$x))

df_gbm_merge_confusion = rbind(as.data.frame(h2o.confusionMatrix(best_cut_gbm)),"\n",
                               as.data.frame(h2o.confusionMatrix(object = best_cut_gbm,test_tc.hex)))

best_cut_gbm_perf = h2o.performance(best_cut_gbm, newdata = test_tc.hex)
best_cut_gbm_conma = as.data.frame(h2o.confusionMatrix(best_cut_gbm_perf))

# save results
write.csv(df_gbm_merge_confusion,paste0(save_folder,"/", best_cut_gbm@model_id,"_", round(1-best_cut_gbm_conma$Error[3],3) ,"_confusionmatrix.csv"))
write.csv(gbm_round_acc, paste0(save_folder,"/",CancerType, "_acc_gbm_round.csv"))

h2o.saveModel(best_cut_gbm, path = paste0(save_folder,"/", best_cut_gbm@model_id,"_", round(1-best_cut_gbm_conma$Error[3],3)))

h2o.shutdown(prompt = F)
# Sys.sleep(runif(1,min=1,max=10))



