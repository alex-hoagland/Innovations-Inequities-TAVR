quietly{
	/*******************************************************************************
	* Title: Estimate allocative inefficiencies pre/post TAVR at the CZ level 
	* Created by: Alex Hoagland
	* Created on: 8/2024
	* Last modified on: 
	* Last modified by: 
	* Purpose: Uses the Chandra and Staiger (2016) methodology to estimate the allocative inefficiency (over/underuse) of any treatment 
			across CZs
	* Notes: -uses covariates from STS-PROM model predicting risk of surgical mortality following TAVR/SAVR
		 -estimates these separately prior to vs. following adoption 
		 - uses code from https://www.aeaweb.org/articles?id=10.1257/aer.p20161079

	* Key edits: 
	*******************************************************************************/

	***** 1. CZ Level of Treatment Thresholds (risk adjusted) ***
	use phat_re CZID using "$datadir/working_allocativeinefficiency.dta", clear
	drop if missing(phat_re)
	duplicates drop // centered around 0, with fairly large variance -- seems appropriate

	// construct quintiles, keep the right version
	xtile q = phat_re, nq(4)
	keep if q == `1' // run from TAVR_Master.do to get this right 
	********************************************************************************


	***** 2. LPDID
	merge 1:m CZID using "$datadir/IVCEventStudy_Base.dta", keep(3) nogenerate

	*** Identify treatment (first adoption of tavr) 
	cap drop t_adopt
	gen t_adopt = yq if tavr == 1
	bysort CZID: ereplace t_adopt = min(t_adopt)

	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1 | ptca2 == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs

	// Require that a CZID have sufficient procs in each quarter (deals with 0s as well)
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	cap replace num_procs = 0 if missing(num_procs)
	replace outcome = 0 if missing(outcome)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = mean(allprocs) 
	drop if todrop < 4
	drop todrop

	bys CZID: ereplace t_adopt = min(t_adopt) // for CZ-yqs with 0s

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	sum treated
	qui gen period_yq = yq -  t_adopt if treated == 1

	// Run regression , pooled effects only 
	gen treatdummy = (treated == 1 & period_yq >= 0)
}
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12) only_pooled nograph 

// store outputs as globals for the table 
global b_q`1': di %6.2fc e(pooled_results)[2,1] 
global se_q`1': di %6.3fc e(pooled_results)[2,2] 
global p_q`1': di %6.3fc e(pooled_results)[2,4] 
local temp = e(pooled_results)[1,7] +  e(pooled_results)[2,7] // pre + post obs 
global N_q`1': di %8.0fc `temp' 
********************************************************************************
