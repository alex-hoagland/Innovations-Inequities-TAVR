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
local figname = "EventStudyPPML_CZLevel_`1'Treatments_`2'Margin"

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
	if (strpos("`3'","predrisk")) {
		replace outcome = asinh(outcome * 100)
	}
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

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
if ("`treatment'" != "high" | "`margin'" != "intensive") { 
	fillin CZID yq
	rename _fillin todrop
	replace allprocs = 0 if missing(allprocs)
	replace num_procs = 0 if missing(num_procs)
	replace todrop = 1 if allprocs < 10
	bysort CZID: ereplace todrop = max(todrop) 
	drop if todrop == 1 
	drop todrop
}

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// DD regression
gen post = (period_yq >= 0 & treated == 1)
ppmlhdfe outcome post, absorb(CZID) vce(cluster CZID) 
local regcoef = _b[post]

// // Store mean before treatment 
// sum outcome if period_yq < 0 | missing(period_yq), d
// local pretreat = round(r(mean), .1)
//
// // Run regression 
// qui ppmlhdfe outcome dummy*, absorb(CZID yq) vce(cluster CZID) 
//
// // Graph results
// regsave
// drop if strpos(var,"o.")
// keep if strpos(var, "dummy")
// gen y = substr(var, 11, .)
// destring y, replace
// replace y = y * -1
// replace y = real(substr(var, 7, .)) if missing(y)
// local obs = _N+1
// set obs `obs'
// replace y = -1 in `obs'
// replace coef = 0 in `obs'
// replace stderr = 0 in `obs'
// gen lb = coef - 1.96*stderr
// gen ub = coef + 1.96*stderr
//
// // keep only 4 yqs pre-/post-adoption
// drop if abs(y) > 12
//
// // combine the risk figures (intensive margin) 
// if ("`margin'" == "intensive") { 
// 	save "$datadir/figuredata_intensivemargin_`treatment'_`3'.dta", replace
// }
//
// 	// local for where to put the text label
// 	qui sum y 
// 	local mymin = r(min) 
// 	local mymax = r(max) 
// 	local myx = `mymax' * 0.05
// 	qui sum ub
// 	local myy = r(max) * 0.85
//
// sort y 
// twoway (scatter coef y, color(maroon)) /// (line coef y, lcolor(ebblue)) /// 
// 	(rcap lb ub y, color(ebblue%60)), ///
// 	graphregion(color(white)) legend(off) ///
// 	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
// 	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
// 	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
//		
// // Save graphs
// graph save "$output/`figname'.gph", replace
// graph export "$output/`figname'.pdf", as(pdf) replace
// //
// // // Save data for decomposition 
// // if ("`treatment'" == "all" & "`margin'" == "extensive") { // change back to "low" if desired later
// // 	save "$datadir/Low-Intensity-Intervention_Decomposition.dta", replace
// // }
********************************************************************************
