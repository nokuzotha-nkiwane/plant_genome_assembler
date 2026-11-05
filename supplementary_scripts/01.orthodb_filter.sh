#!/bin/bash
#PBS -N orthodb_v13_filter
#PBS -q bix
#PBS -o orthodb_v13_filter.out
#PBS -e orthodb_v13_filter.err
#PBS -l select=1:ncpus=16:mem=64gb
#PBS -l walltime=48:00:00
#PBS -m abe

set -euo pipefail

#load modules
module load app/snakemake/7.32.3

#resources
THREADS=14

#files and directories
ORTHODB_REPO="/new-home/25086138/my_environments/orthodb-clades"
VIRIDIPLANTAE_OUTPUT="clades/Viridiplantae.fa"
TOMATO_DATA="/new-home/25086138/masters/tomato/data/orthodb13"

#make tomato data directory
mkdir -p "${TOMATO_DATA}"

#run scirpt from repo directory
cd "${ORTHODB_REPO}"
snakemake --cores "${THREADS}" "${VIRIDIPLANTAE_OUTPUT}"

#move output to tomato data folder
mv "${VIRIDIPLANTAE_OUTPUT}" "${TOMATO_DATA}/"
