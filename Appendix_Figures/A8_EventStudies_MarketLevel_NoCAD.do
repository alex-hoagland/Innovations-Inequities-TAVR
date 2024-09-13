/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: This file removes all patients with stable cornary artery disease, per the COURAGE trial

* Key edits: 
*******************************************************************************/


***** 0. Identify which patients to drop 
clear
gen bene_id = ""
save "$datadir/StableAngina.dta", replace

// codes come from https://www.sciencedirect.com/science/article/pii/S0002914914014416?casa_token=OcmTaARJ_G4AAAAA:YS0s1gImegdJgX5mzMy3_IWfrazd0528jkYyI1bbrCFr5CvN1KL3lOjtLzxA1JS9zeYs0v2i
// notes about identifying scad/sihd: https://www.ahajournals.org/doi/full/10.1161/CIRCOUTCOMES.113.000282
forvalues yr = 2010/2017 {
	di "***** YEAR: `yr' *****"
	use bene_id from_dt icd_dgns_cd* using ///
		/disk/aging/medicare/data/harm/100pct/ip/`yr'/ipc`yr'.dta if  ///
		inlist(icd_dgns_cd1, "4139", "I208", "I209") | /// 
		inlist(icd_dgns_cd2, "4139", "I208", "I209") | /// 
		inlist(icd_dgns_cd3, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd4, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd5, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd6, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd7, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd8, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd9, "4139", "I208", "I209")  | /// 
		inlist(icd_dgns_cd10, "4139", "I208", "I209") // primary dx of stable angina 
	gen sang = 1
	rename from_dt surg_dt
	append using "$datadir/StableAngina.dta"
	save "$datadir/StableAngina.dta", replace
}

use "$datadir/StableAngina.dta", clear
duplicates drop
gen dx = 0
replace dx = 1 if inlist(icd_dgns_cd1, "4139", "I208", "I209")
forvalues i = 2/10 { 
	replace dx = `i' if inlist(icd_dgns_cd`i', "4139", "I208", "I209") & dx== 0
}
gcollapse (min) dx, by(bene_id surg_dt)
save "$datadir/StableAngina.dta", replace
********************************************************************************


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

merge m:1 bene_id surg_dt using "$datadir/StableAngina.dta", keep(1 3) // remove the stable angina claims in outcome, but keep full set in order to idetnify which CZs to drop

	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = ((tavr == 1 | savr == 1 | ptca2 == 1) & (_merge != 3)) 
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs

	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	cap replace num_procs = 0 if missing(num_procs)
	replace outcome = 0 if missing(outcome)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = mean(allprocs) 
	drop if todrop < 4
	drop todrop

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// DD regression -- done in lpdid as pooled effects

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
// local pretreat = round(r(mean), .1)
local pretreat: di %4.0fc `r(p50)'

// Run regression 
gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(3 1 "Pre-treatment median: `pretreat'", place(e)) ///
	text(`pooledfx' -9 "Pooled Effect: `pooledfx'", place(s))
	
// Save graphs
local figname = "LPDID-EventStudy_CZLevel_NoSTABLEANGINA"
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
