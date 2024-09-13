/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes :Patient Level
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 3/7/2016
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies -- keep CZs included in market-level analysis 
cap graph drop * 
local figname = "LongRun_PatientLevel_`1'" // "LPDID-EventStudy_PatientLevel_`1'"

// first, correctly identify dates across all observable procedures (and drop the same CZs from before)
use "$datadir/IVCEventStudy_Base.dta", clear
gen allprocs = 1
gcollapse (max) tavr (sum) allprocs, by(CZID yq)
bysort CZID: ereplace allprocs = mean(allprocs) 
gen todrop = (allprocs < 5)
drop allprocs
rename tavr tavr1
merge 1:1 CZID yq using "$datadir/ASpatients2024_20p_collapsed_withoutpatient.dta" // I know this looks like it says without patient, but it says with outpatient
keep if tavr ==1 | tavr1 == 1
gcollapse (min) yq (max) todrop, by(CZID) fast
rename yq t_adopt_patlevel

// merge that with all observed procedures in the 20p sample 
merge 1:m CZID using "$datadir/IVCEventStudy_Base.dta", keep(2 3) nogenerate
drop t_adopt
rename t_adopt t_adopt

// keep only inpatient procedures for those in 20p
merge m:1 bene_id using "$datadir/20p_flag", keep(3) nogenerate 

// add in outpatient procedures
append using "$datadir/all_OutpatientCardiology.dta" // shouldn't be any duplicates here 
bys CZID: ereplace todrop = max(todrop) 
drop if todrop == 1

gen allprocs = 1
gcollapse (sum) allprocs tavr savr (mean) t_adopt, by(CZID yq) fast

// need to convert allprocs to rate per 1,000; this is the problem with large multipliers in older versions of Fig. A.5.
merge 1:1 CZID yq using "$datadir/czpop_20", keep(3) nogenerate
ereplace pop20 = mean(pop20)
foreach v of var all tavr savr {
	replace `v' = `v' / pop20 * 1000
}

// merge 1:m CZID using "$datadir/ASpatients2016_20p_collapsed.dta", keep(2 3) nogenerate
********************************************************************************


**** Now run regressions 
cap gen tavrsavr = tavr + savr
cap gen cabgcath = cabg + cath
cap gen cabgcathptca = cabg + cath + ptcaonly 
cap gen valvesupport = any - tavr - savr
gen outcome = `1'

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

*** Gen dummy variables
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/`mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
}
forvalues i = 2/`mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
}
rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
// local pretreat = round(r(mean), .1)
local pretreat: di %4.2fc `r(mean)'

// DD regression for Poisson robustness
gen post = (period_yq >= 0 & treated == 1)
ppmlhdfe outcome post, absorb(CZID) vce(cluster CZID) 

// Run regression 
gen treatdummy = (treated == 1 & period_yq >= 0)
set scheme cblind1
cap graph drop * 
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(16) post_window(16) post_pooled(15)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-16(4)16)) xlab(-16(4)16) ///
	text(0.17 -13 "Pre-treatment mean: `pretreat'", place(e)) ///
	text(`pooledfx' -9 "Pooled Effect: `pooledfx'", place(s))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
