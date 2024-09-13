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

* Key edits: ***ONE THING TO CHANGE BEFORE FINAL REPLICATION***
*******************************************************************************/

***** 1. CZ Level of Treatment Thresholds (risk adjusted) ****
use phat_re CZID using "$datadir/working_allocativeinefficiency.dta", clear
drop if missing(phat_re)
duplicates drop // centered around 0, with fairly large variance -- seems appropriate

gsort phat_re
gen rank_theta = _n // rank them 

// histogram for appendix figure 
hist phat_re, xtitle("Estimated Values of `=ustrunescape("\u03b8")'") ytitle("" ) //
graph save "$output_a/Histogram_Theta.gph", replace
graph export "$output_a/Histogram_Theta.pdf", replace as(pdf)

tempfile theta
save `theta', replace
********************************************************************************


****** 2. Correlation between theta and % of patients in crowd-out region 
// pick which data you want to use: full patients or just PCI/TAVR patients 
use CZID year predrisk* using "$datadir/all_SurgicalCandidates.dta" if year < 2012, clear
//use "$datadir/IVCEventStudy_Base.dta"  if year < 2012, clear
gen crowdout_30 = inrange(predrisk_30, .045, .09)
gen crowdout_60 = inrange(predrisk_60, .045, .09)
gen crowdout_90 = inrange(predrisk_90, .045, .09)
gcollapse (mean) crowd*, by(CZID) fast

merge 1:1 CZID using `theta', nogenerate
replace crowdout_30 = crowdout_30 * 100 // convert to %
replace crowdout_60 = crowdout_60 * 100 // convert to %
replace crowdout_90 = crowdout_90 * 100 // convert to %

// binscatters -- these make the most sense, other robustness below
cap graph drop * 
foreach v of var crowdout_90 { 
	binscatter phat_re `v', nq(30) ///
		ytitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
		xtitle("% of Patients with PROM in Crowd-out Region") name(`v')
	graph save "$output/Correlation_CZTreatmentThreshold_CrowdoutRegion.gph", replace
	graph export "$output/Correlation_CZTreatmentThreshold_CrowdoutRegion.pdf", as(pdf) replace
}

// // full scatter plots 
// cap graph drop * 
// foreach v of var crowd* { 
// 	twoway (scatter `v' phat_re) (lfit `v' phat_re), ///
// 		xtitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
// 		ytitle("% of Patients with PROM in Crowd-out Region") name(`v')
// } 
//
// // do it in rank version
// cap graph drop * 
// foreach v of var crowdout* { 
// 	gsort `v' 
// 	gen rank_risk = _n
// 	binscatter rank_risk rank_theta, ///
// 		xtitle("Ranked CZ Specific Treatment Threshold (Risk Adjusted)") ///
// 		ytitle("Ranked % of Patients with PROM in Crowd-out Region") name(`v')
// 	drop rank_risk 
// }
//
// cap graph drop * 
// foreach v of var crowd* { 
// 	gsort `v' 
// 	gen rank_risk = _n
// 	twoway (scatter rank_risk rank_theta) (lfit rank_risk rank_theta), ///
// 		xtitle("Ranked CZ Specific Treatment Threshold (Risk Adjusted)") ///
// 		ytitle("Ranked % of Patients with PROM in Crowd-out Region") name(`v')
// 	drop rank_risk 
// } 
********************************************************************************

***** 3. Correlation between theta and ADI/race/etc. of patients 
// pick which data you want to use: full patients or just PCI/TAVR patients 
use CZID year riskvar_adi* riskvar_black riskvar_hisp riskvar_othernonwhite riskvar_fem riskvar_dual* using ///
	"$datadir/all_SurgicalCandidates.dta" if year < 2012, clear
// use CZID year riskvar_adi* riskvar_black riskvar_hisp riskvar_othernonwhite riskvar_fem riskvar_dual* using ///
// 	"$datadir/IVCEventStudy_Base.dta"  if year < 2012, clear

egen riskvar_allnonwhite = rowmax(riskvar_black riskvar_hisp riskvar_othernonwhite)
gcollapse (mean) riskvar*, by(CZID) fast

// convert ADI so that increasing numbers means more disadvantage 
// NOTE: in final run through, make sure that riskvar_adi_9 and updated adi_9 match 
replace riskvar_adi_5 = 100-riskvar_adi_5 // need to flip this since they are rankings
replace riskvar_adi_9 = 100-riskvar_adi_9 // need to flip this since they are rankings
replace riskvar_allnonwhite = riskvar_allnonwhite * 100 // change to %
replace riskvar_dual_full = riskvar_dual_full * 100 // change to %

merge 1:1 CZID using `theta', nogenerate

// binscatters -- these make the most sense, other robustness below
cap graph drop * 
binscatter phat_re riskvar_adi_9, nq(100) linetype(qfit) ///
	ytitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
	xtitle("Area Disadvantage Ranking (increasing in disadvantage)") // name(adi)
graph save "$output/Correlation_CZTreatmentThreshold_adi.gph", replace
graph export "$output/Correlation_CZTreatmentThreshold_adi.pdf", as(pdf) replace

cap graph drop * 
binscatter phat_re riskvar_allnonwhite, nq(100) linetype(qfit) ///
	ytitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
	xtitle("% Non-white Enrollees") 
graph save "$output/Correlation_CZTreatmentThreshold_nonwhite.gph", replace
graph export "$output/Correlation_CZTreatmentThreshold_nonwhite.pdf", as(pdf) replace

cap graph drop *  
binscatter phat_re riskvar_dual_full, nq(100) linetype(qfit) ///
	ytitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
	xtitle("% of Enrollees Dual Eligible") 
graph save "$output/Correlation_CZTreatmentThreshold_dual.gph", replace
graph export "$output/Correlation_CZTreatmentThreshold_dual.pdf", as(pdf) replace

// full scatter plots 
cap graph drop * 
foreach v of var riskvar* { 
	twoway (scatter phat_re `v') (lfit phat_re `v'), ///
		ytitle("CZ Specific Treatment Threshold (Risk Adjusted)") ///
		xtitle("`v'") name(`v')
} 
********************************************************************************
