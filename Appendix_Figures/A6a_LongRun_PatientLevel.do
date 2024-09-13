/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes :Patient Level
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 3/7/20`2'
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies -- keep CZs included in market-level analysis 
cap graph drop * 
local figname = "LongRun_PatientLevel_`1'"

// first, correctly identify dates across all observable procedures (and drop the same CZs from before)
use "$datadir/IVCEventStudy_Base.dta" if tavr == 1, clear
append using "$datadir/all_OutpatientCardiology.dta"
keep if tavr ==1 
gcollapse (min) yq, by(CZID) fast
rename yq t_adopt_patlevel

// merge that with all observed procedures in the 20p sample 
merge 1:m CZID using "$datadir/IVCEventStudy_Base.dta", keep(2 3) nogenerate
drop t_adopt // only using inpatient data 
rename t_adopt_patlevel t_adopt // using inpatient and outpatient data 
gen allprocs = 1
bysort CZID yq: ereplace allprocs = total(allprocs)
bysort CZID: ereplace allprocs = mean(allprocs) 
gen todrop = (allprocs < 5)
drop allprocs 

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

// merge 1:m CZID using "$datadir/ASpatients20`2'_20p_collapsed.dta", keep(2 3) nogenerate
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
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(`2') post_window(`2') post_pooled(15) pmd(max) 
	// estimate pooled effects for first year [0,3] 
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-`2'(4)`2')) xlab(-`2'(4)`2') ///
	text(0.25 -16 "Pre-treatment mean: `pretreat'", place(e)) ///
	text(`pooledfx' -8 "Pooled Effect (Year 1): `pooledfx'", place(s))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
