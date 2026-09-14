#!/bin/bash
#PBS -l select=1:ncpus=64:mem=80GB
#PBS -q bix
#PBS -l walltime=72:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/EDTA2/2.2.2

#resource parameters
THREADS=64

WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
OUTPUT_DIR="__RESULTS_DIR__"
logfile="${OUTPUT_DIR}/edta_soft_masking.log"
RAGATAG_SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
TE_LIB="${ALL_RESULTS_DIR}/09.edta_repeat_masking/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta.mod.EDTA.anno/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta.mod.EDTA.TEanno.out"
MASKING_SCRIPT="/new-home/apps2/mambaforge/envs/EDTA2/share/EDTA/bin/make_masked.pl"

#TODO check minlen parameter is it basedon the the sumfile outputs? Is it a default hte creator recommended? Whats its basis?
perl "${MASKING_SCRIPT}" -genome "${RAGATAG_SCAFFOLD_FASTA}" -minlen 80 -hardmask 0 -t "${THREADS}" -rmout "${TE_LIB}" > >(tee -a "${logfile}") 2>&1 &
edta_pid=$!

#write a log for edta monitoring
while kill -0 "${edta_pid}" 2>/dev/null; do
    if grep -qE "^ERROR|FATAL|die at" "${logfile}"; then
        kill -TERM "${edta_pid}"
        wait "${edta_pid}" 2>/dev/null
        exit 1
    fi
    sleep 10
done

#check that the final command exited with a 0 exit code and flag if it didn't
#done because PBS will return 0 exit code for successfully reaching end of the script
#but not necessarily a successful completion of underlying command/script
wait "${edta_pid}"
exit_code=$?
if [[ ${exit_code} -ne 0 ]]; then
    echo "make_masked.pl exited with status ${exit_code}" >> "${logfile}"
    exit "${exit_code}"
fi