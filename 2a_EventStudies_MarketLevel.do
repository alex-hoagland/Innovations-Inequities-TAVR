/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_CZLevel_`1'Treatments_`2'Margin"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

if ("`treatment'" == "high" & "`margin'" == "extensive") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "high" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	keep if (tavr == 1 | savr == 1) // intensive margin only
	gen allprocs = 1 
	gcollapse (sum) allprocs (mean) predrisk* riskvar* t_adopt, by(CZID yq) fast
	rename `3' outcome 
	if (strpos("`3'","predrisk")) {
		replace outcome = asinh(outcome * 100)
	}
}
else if ("`treatment'" == "low" & "`margin'" == "extensive") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (ptca2 == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "low" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	keep if (ptca2 == 1) // intensive margin only
	gen allprocs = 1 
	gcollapse (sum) allprocs (mean) predrisk* t_adopt, by(CZID yq) fast
	rename `3' outcome 
// 	if (strpos("`3'","predrisk")) {
// 		replace outcome = asinh(outcome * 100)
// 	}
}
else if ("`treatment'" == "all" & "`margin'" == "extensive") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1 | ptca2 == 1)
	gen allprocs = 1
	gcollapse (sum) num_procs allprocs (mean) t_adopt, by(CZID yq) fast
	gen outcome = num_procs
}
else if ("`treatment'" == "all" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	keep if (tavr == 1 | savr == 1 | ptca2 == 1) // intensive margin only
	gen allprocs = 1 
	gcollapse (sum) allprocs (mean) predrisk* t_adopt, by(CZID yq) fast
	rename `3' outcome 
	if (strpos("`3'","predrisk")) {
		replace outcome = asinh(outcome * 100)
	}
}

// Require that a CZID have sufficient procs in each quarter (deals with 0s as well)
if ("`treatment'" != "high" & "`margin'" != "intensive") { 
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	cap replace num_procs = 0 if missing(num_procs)
	replace outcome = 0 if missing(outcome)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = mean(allprocs) 
	drop if todrop < 4
	drop todrop
}

bys CZID: ereplace t_adopt = min(t_adopt) // for CZ-yqs with 0s

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
lpdid outcome, unit(CZID) time(yq) treat(treatdummy) pre_window(12) post_window(12) // pmd(max) // post_pooled(15)
// results are robust to including: rw nocomp (or nevertraet, but there aren't sufficient nevertreat for this to be done except noisily)
addplot: , yline(0, lcolor(black))
local pooledfx: di %4.2fc e(pooled_results)[2,1]
addplot: , yline(`pooledfx', lpattern(dash))
addplot: , xtitle("Quarters Around TAVR Adoption") ytitle("") xsc(r(-12(4)12)) xlab(-12(4)12) ///
	text(3 1 "Pre-treatment median: `pretreat'", place(e)) ///
	text(`pooledfx' -9 "Pooled Effect: `pooledfx'", place(s)) 
	
// Save graphs
local figname = "LPDID-EventStudy_CZLevel_`1'Treatments_`2'Margin"
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
