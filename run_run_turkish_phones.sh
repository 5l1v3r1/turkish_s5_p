#! /bin/bash

tests="1 2 3 4 7"
# 1 = data prep
# 2 = feat prep
# 3 = monophone 
# 4 = triphone (deltas and deltas+deltas) 
# 5 = LDA + MLLT 
# 6 = LDA+MLLT+SAT, decode
# 7 = Karel's nnet
subsets="50 100 200 500"


# train with the full training set
#for i in $tests
#do
#	bash run_turkish_phones.sh $i 
#done

tests="3 4 7"
# train with a subset of $n utts from training set
for n in $subsets
do
	for i in $tests
	do
		bash run_turkish_phones.sh $i $n
	done
done

