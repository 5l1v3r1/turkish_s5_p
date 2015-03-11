#! /bin/bash

echo -e "\n================================\n" >> RESULTS
echo "BEGIN" >> RESULTS
date >> RESULTS
tests="1 2 3 4 5 7"
# 1 = data prep
# 2 = feat prep
# 3 = monophone 
# 4 = triphone (deltas and deltas+deltas) 
# 5 = LDA + MLLT 
# 6 = LDA+MLLT+SAT, decode
# 7 = LDA+MLLT+MPE
# 8 = Karel's nnet

#Train with the full training set
for i in $tests
do
	bash run_turkish_phones.sh $i "all"
done



tests="3 4 5 7"
subsets="200 500 1000"
# train with a subset of $n utts from training set
for n in $subsets
do
	for i in $tests
	do
		bash run_turkish_phones.sh $i $n
	done
done

for x in exp/*/decode*; do [ -d $x ] && echo $x|grep "/.*/" && grep WER ${x}/wer_* | utils/best_wer.sh; done|sed '/^exp/d' >> RESULTS
echo -e "END" >> RESULTS
echo -e "\n================================\n\n\n" >> RESULTS
