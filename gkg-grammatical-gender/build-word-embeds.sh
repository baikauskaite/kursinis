#!/bin/bash
set -e

BASE_DIR=""
GKG_DIR="$BASE_DIR/gkg-grammatical-gender"
WORD2VECF_DIR="$BASE_DIR/word2vecf"
GKG_DATA_DIR="$GKG_DIR/data"
RESULTS_DIR="$GKG_DIR/results"

RESULTS_FILE="$RESULTS_DIR/results.txt"

echo -e "\n______________________________" >> "$RESULTS_FILE"
echo "Date: $(date +%Y%m%d%H%M)" >> "$RESULTS_FILE"

helpFunction() {
   echo -e "\nUsage: $0 -l language"
   echo -e "\t-l Language of the corpus"
   exit 1
}

run_and_time() {
    local start_time=$(date +%s.%N)
    $@
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "Duration: $duration seconds" >> "$RESULTS_FILE"
}

while getopts "l:" opt
do
   case "$opt" in
      l ) language="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$language" ]; then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

if [ "$language" == "it" ]; then
    OUTPUT_FILE=it_lemma_to_fem
    LEMMATIZE_OPTION=to_fem
elif [ "$language" == "de" ]; then
    OUTPUT_FILE=de_lemma_basic_all
    LEMMATIZE_OPTION=basic
else
    echo "Language not supported"
    helpFunction
    exit 1
fi

PAIRS_PATH="$GKG_DATA_DIR/word2vecf_pairs/$OUTPUT_FILE"
EMBEDDINGS_PATH="$GKG_DATA_DIR/word2vecf_embeddings/$OUTPUT_FILE"

# Create pairs
cd "$GKG_DIR/source"
echo -e "\nCreating pairs for $language" >> "$RESULTS_FILE"
run_and_time python ./create_pairs_word2vecf.py --lang $language --lemmatize $LEMMATIZE_OPTION --input ${GKG_DATA_DIR}/${language}_corpus_tokenized --output $PAIRS_PATH

# Create vocab
cd "$WORD2VECF_DIR"
make
echo -e "\nCreating vocab for $language" >> "$RESULTS_FILE"
run_and_time ./count_and_filter -train $PAIRS_PATH -cvocab ${PAIRS_PATH}_cv -wvocab ${PAIRS_PATH}_wv -min-count 100

# Create embeddings
cd "$WORD2VECF_DIR"
echo -e "\nCreating embeddings for $language" >> "$RESULTS_FILE"

TRAIN_FILE="$RESULTS_DIR/train_$(date +%Y%m%d%H%M).txt"
echo "Train file: $TRAIN_FILE" >> "$RESULTS_FILE"

run_and_time ./word2vecf -train $PAIRS_PATH -wvocab ${PAIRS_PATH}_wv -cvocab ${PAIRS_PATH}_cv -output $EMBEDDINGS_PATH -dumpcv ${EMBEDDINGS_PATH}_ctx -size 300 -negative 15 -threads 16 -iters 5 > "$TRAIN_FILE"

tail -n 1 "$TRAIN_FILE" >> "$RESULTS_FILE"