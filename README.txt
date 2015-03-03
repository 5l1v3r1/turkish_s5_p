Construction of scripts under turkish/s5_p/ 	("s5_p" means s5 for phones)
============================================================================
path.sh						cp timit/path.sh
cmd.sh						cp timit/cmd.sh

run_turkish_phones.sh				everything after mfcc generation is based on timit/run.sh except the following:
						a) change utils/mkgraph.sh data/lang_test_bg  *  * --> utils/mkgraph.sh data/lang  *  *
						b) change tri2 ti tri2b
						c) change tri3 to tri3b



conf/
------
conf/dev_spk.list				<based on turkish corpus>			
conf/test_spk.list				<based on turkish corpus>	
metu2worldmap.txt				<linked to s5_w_v2>
		
conf/fbank.conf					cp timit/conf/fbank.conf			
conf/mfcc.conf					cp timit/conf/mfcc.conf				
conf/phones.60-48-39.map			cp timit/conf/phones.60-48-39.map (this is never used by turkish)




local/
------
local/turkish_data_prep.sh			<linked to s5_w_v2>
local/turkish_format_data.sh			<linked to s5_w_v2>
local/turkish_prepare_dict.sh			<linked to s5_w_v2>

local/run_dnn.sh				cp timit/local/run_dnn.sh			
local/score.sh					cp rm/local/score.sh				






