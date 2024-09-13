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


***** 1. Initial Regressions ****
use "$datadir/all_SurgicalCandidates.dta" if year < 2012, clear
// drop if year >= 2012 // only want pre-TAVR adoption  
global controls as_flag riskvar_* predrisk_* 
sample 5 // not sure how long this will take on full sample of 65M patients

// treatment variable
gen anysurgery = (tavr == 1 | savr == 1 | ptca2 == 1)

// initial propensity for treatment (mixed logit)
xtmelogit anysurgery $controls || CZID: 
predict phat if e(sample)
predict phat_re if e(sample), reffects // these are the CZID-level predictions 
save "$datadir/working_allocativeinefficiency.dta", replace
********************************************************************************
