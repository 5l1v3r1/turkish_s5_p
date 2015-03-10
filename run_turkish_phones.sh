#!/bin/bash

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

. cmd.sh
set -e # exit on error

# Acoustic model parameters
numLeavesTri1=1500 #2500
numGaussTri1=7000 #15000
numLeavesMLLT=1500 #2500
numGaussMLLT=7000 #15000
numLeavesSAT=1500 #2500
numGaussSAT=7000 #15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=10
train_nj=30
decode_nj=5

# call the next line with the directory where the RM data is
# (the argument below is just an example).  This should contain
# subdirectories named as follows:
#    rm1_audio1  rm1_audio2	rm2_audio
#local/rm_data_prep.sh /mnt/matylda2/data/RM
#local/rm_data_prep.sh /home/dpovey/data/LDC93S3A/rm_comp

# Directory where wav files are present
TURKROOT=$corpus_dir
# Enter either "WRD" (to measure WER) or "PHN" (to measure PER)
extn="PHN"
stage=$1
# If you want to train on a subset of trn data, enter a number. Otherwise, leave it empty (which means train on full set)
num_trn_utt=$2
featdir=mfcc

# [[ $num_trn_utt =~ ^[0-9]+$ ]] returns true if $num_trn_utt is a number
[[ $num_trn_utt =~ ^[0-9]+$ ]] && echo "Stage $stage: Train acoustic models on $num_trn_utt utterances" \
	|| echo "Stage $stage: Train acoustic models on all utterances"

# Calculate num leaves and num Gauss from the number of utterances. 
# Each Turkish utt is about 4 secs long; skip rate at 100 frames/sec; 80 params per Gauss mix (mean = 39, diag cov = 39, wt = 1);
export num_trn_utt; 
numGaussTri1=`perl -e '$x=int($ENV{num_trn_utt}*4*100/80); print "$x";'`;
numLeavesTri1=`echo "$numGaussTri1/5" | bc`

echo -e "#Triphone States = $numLeavesTri1 \n#Triphone Mix = $numGaussTri1";

if [[ $stage -eq 1 ]]; then
# If $num_trn_utt is empty (train full set), then run the data prep and feat generation part.
local/turkish_data_prep.sh  $TURKROOT $extn

local/turkish_prepare_dict.sh $TURKROOT $extn

echo "Preparing lang models for type $extn ...";
if [ "$extn" = "PHN" ]; then  
utils/prepare_lang.sh --position-dependent-phones false --num-sil-states 3 \
 data/local/dict 'sil' data/local/lang data/lang
else 
utils/prepare_lang.sh data/local/dict 'SIL' data/local/lang data/lang
fi

local/turkish_format_data.sh
fi

if [[ $stage -eq 2 ]]; then
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.   You can make a soft link if you want.
# Generate features for the full train dev test set even if you chose to train on subsets

for x in train dev test; do
  [ -s  data/$x/spk2utt ] && \
  { steps/make_mfcc.sh --nj 8 --cmd "run.pl" data/$x exp/make_feat/$x $featdir
    #steps/make_plp.sh --nj 8 --cmd "run.pl" data/$x exp/make_feat/$x $featdir
    steps/compute_cmvn_stats.sh data/$x exp/make_feat/$x $featdir
  }
done

# Make a combined data dir where the data from all the test sets goes-- we do
# all our testing on this averaged set.  This is just less hassle.  We
# regenerate the CMVN stats as one of the speakers appears in two of the
# test sets; otherwise tools complain as the archive has 2 entries.

#utils/combine_data.sh data/test data/test_{mar87,oct87,feb89,oct89,feb91,sep92}
#steps/compute_cmvn_stats.sh data/test exp/make_feat/test $featdir
fi

# Amit: Everything below this is same as rm/run.sh for word models and 
# timit/run.sh for phn models
train=train${num_trn_utt}

mono=mono${num_trn_utt}
mono_ali=${mono}_ali

tri1=tri1${num_trn_utt}
tri1_ali=${tri1}_ali

#tri1fmllr=tri1fmllr${num_trn_utt}
#tri1fmllr_ali=${tri1fmllr}_ali

tri2a=tri2a${num_trn_utt}
tri2b=tri2b${num_trn_utt}
tri2b_ali=${tri2b}_ali

tri3b=tri3b${num_trn_utt}
tri3b_ali=${tri3b}_ali

[[ -d $featdir -a ! -d data/train${num_trn_utt} ]] && utils/subset_data_dir.sh data/train ${num_trn_utt:-1000} data/train${num_trn_utt:-.1k}

if [[ $stage -eq 3 ]]; then
echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================
steps/train_mono.sh --nj "$train_nj" --cmd "$train_cmd" data/train${num_trn_utt:-.1k} data/lang exp/$mono

#show-transitions data/lang/phones.txt exp/tri2a/final.mdl  exp/tri2a/final.occs | perl -e 'while(<>) { if (m/ sil /) { $l = <>; $l =~ m/pdf = (\d+)/|| die "bad line $l";  $tot += $1; }} print "Total silence count $tot\n";'

utils/mkgraph.sh --mono data/lang exp/$mono exp/$mono/graph

#steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
# exp/mono/graph data/dev exp/mono/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
  exp/$mono/graph data/test exp/$mono/decode_test
fi

if [[ $stage -eq 4 ]]; then
echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
 data/$train data/lang exp/$mono exp/${mono_ali}

# Train tri1, which is deltas + delta-deltas, on train data.
steps/train_deltas.sh --cmd "$train_cmd" \
 $numLeavesTri1 $numGaussTri1 data/$train data/lang exp/${mono_ali} exp/$tri1

utils/mkgraph.sh data/lang exp/$tri1 exp/$tri1/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/dev exp/tri1/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/$tri1/graph data/test exp/$tri1/decode_test

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
  data/$train data/lang exp/$tri1 exp/${tri1_ali}
  
#steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
# exp/$tri1/graph data/dev exp/$tri1/decode_dev
 
#steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
# exp/$tri1/graph data/test exp/$tri1/decode_test
 
#steps/align_fmllr.sh --nj "$train_nj" --cmd "$train_cmd" \
# data/$train data/lang exp/$tri1 exp/${tri1_ali}
fi

if [[ $stage -eq 5 ]]; then
echo ============================================================================
echo "                 tri2b : LDA + MLLT Training & Decoding                    "
echo ============================================================================

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
  data/$train data/lang exp/$tri1 exp/${tri1_ali}

steps/train_lda_mllt.sh --cmd "$train_cmd" \
 --splice-opts "--left-context=3 --right-context=3" \
 $numLeavesMLLT $numGaussMLLT data/$train data/lang exp/${tri1_ali} exp/$tri2b

utils/mkgraph.sh data/lang exp/$tri2b exp/$tri2b/graph

#steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
# exp/tri2b/graph data/dev exp/tri2b/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/$tri2b/graph data/test exp/$tri2b/decode_test
fi

if [[ $stage -eq 6 ]]; then
echo ============================================================================
echo "              tri3b : LDA + MLLT + SAT Training & Decoding                 "
echo ============================================================================

# Align tri2 system with train data.
steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
 --use-graphs true data/$train data/lang exp/$tri2b exp/${tri2b_ali}

# From tri2 system, train tri3 which is LDA + MLLT + SAT.
steps/train_sat.sh --cmd "$train_cmd" \
 $numLeavesSAT $numGaussSAT data/$train data/lang exp/${tri2b_ali} exp/$tri3b

utils/mkgraph.sh data/lang exp/$tri3b exp/$tri3b/graph

#steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
# exp/tri3b/graph data/dev exp/tri3b/decode_dev

steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/$tri3b/graph data/test exp/$tri3b/decode_test

steps/align_fmllr.sh --nj "$train_nj" --cmd "$train_cmd" \
 data/$train data/lang exp/$tri3b exp/${tri3b_ali}
fi

if [[ $stage -eq 7 ]]; then
# Karel's neural net recipe.                                                                                                                                        
local/nnet/run_dnn.sh exp/$tri1 ${num_trn_utt}                                                                                                                                                  

# Karel's CNN recipe.
# local/nnet/run_cnn.sh
fi
