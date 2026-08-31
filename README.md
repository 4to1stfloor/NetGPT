# NetG2P
[![R](https://img.shields.io/badge/R-%3E%3D%204.3.1-blue)](https://www.r-project.org/)

**NetG2P**: **N**etwork-based **G**enotype-to(**2**)-**P**henotype transformation identifies key signaling crosstalks for prognosis in pan-cancer study

## Table of Contents

- [Graphical abstract](#graphical-abstract)
- [Usage](#usage)
- [Repository Structure](#repository-structure)
- [File Descriptions](#file-descriptions)
- [Example Workflow](#example-workflow)
- [Common Issues and Tips](#common-issues-and-tips)
- [License](#license)

---

## Graphical abstract
![Figure1](https://github.com/user-attachments/assets/414ad261-8451-4d07-a5c0-df63ccb23b9c)


<img width="1563" alt="abstract" src="https://github.com/user-attachments/assets/89f97e34-d41c-46af-9884-a162a365e7d8">

---

## Usage

For producing network propagation with GC clustering method, follow the code below.

cf. For expression and mutation data, samples (patients) should be organized as columns.

```bash
$ git clone this-repo-url
$ cd ./NetG2P/NetG2P/
$ Rscript Netg2p_GPTmodule.R --expression your expression file
                             --mutation your mutation file
                             --outdir your path

- List of parameters:

Rscript Netg2p_GPTmodule.R --help
usage: Netg2p_GPTmodule.R [-h] --expression EXP --mutation MUT --outdir OUTDIR

Merge expression data and mutation data by networkpropagation

optional arguments:
    --expression EXP  EXP file to be merged by networkpropagation, Path to the expression data CSV file or RDS file
    --mutation MUT    MUT file to be merged by networkpropagation, Path to the mutation data CSV file or RDS file
    --outdir OUTDIR   Out directory
    -h, --help        Show this help message and exit
```

## Repository Structure

This repository contains the following files and directories:

- `NetG2P/`: Directory containing source code
  - `model.R`: Script for data uploading, data preprocessing, training the model, hyperparameter tunning, and save the results
  - Will be added 
- `data/`: Directory containing input datasets
  - `TCGA-XXXX_pathwayeach.rds`: merged tcga transcriptome data and somatic mutation data as pathway levels
  - `TCGA-XXXX_pathwaylink.rds`: merged tcga transcriptome data and somatic mutation data as pathway-link levels
  - `TCGA-XXXX_dual_with_duration.rds`: merged `TCGA-XXXX_pathwayeach.rds`, `TCGA-XXXX_pathwaylink.rds` and duration data from TCGA clinical data
- `tests/`: Will be added 
- `tutorials/`: Will be added 

## File Descriptions

### `NetG2P/model.R`
This script train the model by preprocessed TCGA data. It performs the following steps:
1. Loads preprocessed TCGA data
2. Cleans and split the data.
3. Feature selection
4. Model training
5. Performance evaluation
6. Retraining 3-5 steps until are met the criteria while ablating the noise features
7. Outputs (best model and metrics) to the `your path` directory

### `NetG2P/analysis.R`
will be added. It includes:
- will be added.

## Example Workflow
will be added

---

## To-do-list
- [x] Upload the pretrained model
- [x] Upload the preprocessed input data
- [x] Upload the input data with clinical information
- [x] Provide the pretraining code for GPT module
- [x] Provide the pretraining code for COF module


## Developed at SDK Lab, National Cancer Center"
https://sites.google.com/view/sdklab/

## License

This project is licensed under the [MIT License](LICENSE).

---

**Note:** Always ensure that your data and scripts are backed up before running batch processing tasks to prevent accidental data loss.
