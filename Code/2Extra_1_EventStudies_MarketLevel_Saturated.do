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
local figname = "EventStudy_CZLevel_`1'Treatments_Saturated"

*** Identify treatment (first adoption of tavr) 
// gen t_adopt = yq if tavr == 1
// bysort CZID: ereplace t_adopt = min(t_adopt)

gen medrisk = inrange(predrisk_60, 0.03, 0.08)
gen highrisk = predrisk_60 >= 0.08 & !missing(predrisk_60)
drop if missing(predrisk_60)

if ("`treatment'" == "high") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	gen outcome1 = (num_procs == 1 & medrisk == 0 & highrisk == 0)
	gen outcome2 = (num_procs == 1 & medrisk == 1)
	gen outcome3 = (num_procs == 1 & highrisk == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
}
else if ("`treatment'" == "low") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (ptca2 == 1)
	gen outcome1 = (num_procs == 1 & medrisk == 0 & highrisk == 0)
	gen outcome2 = (num_procs == 1 & medrisk == 1)
	gen outcome3 = (num_procs == 1 & highrisk == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
}
else if ("`treatment'" == "all") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1 | ptca2 == 1)
	gen outcome1 = (num_procs == 1 & medrisk == 0 & highrisk == 0)
	gen outcome2 = (num_procs == 1 & medrisk == 1)
	gen outcome3 = (num_procs == 1 & highrisk == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt, by(CZID yq) fast
}

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
fillin CZID yq
rename _fillin todrop
replace allprocs = 0 if missing(allprocs)
if ("`margin'" == "intensive") { 
	replace todrop = 1 if allprocs == 0
}
else {
	replace todrop = 1 if allprocs < 10
}
bysort CZID: ereplace todrop = max(todrop) 
drop if todrop == 1 
drop todrop

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
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

// loop through three outcomes 
foreach v of var outcome* {
	qui reghdfe `v' dummy*, absorb(CZID yq) vce(cluster CZID) 
	local j = substr("`v'", length("`v'"), 1)
	regsave using "$datadir/tomerge_`j'.dta", replace
}

// Graph results
use "$datadir/tomerge_1.dta", clear
gen group = 1 
append using "$datadir/tomerge_2.dta"
replace group = 2 if missing(group) 
append using "$datadir/tomerge_3.dta"
replace group = 3 if missing(group) 

drop if strpos(var,"o.")
keep if strpos(var, "dummy")
gen y = substr(var, 11, .)
destring y, replace
replace y = y * -1
replace y = real(substr(var, 7, .)) if missing(y)

gen lb = coef - 1.96*stderr
gen ub = coef + 1.96*stderr

// keep only 4 yqs pre-/post-adoption
drop if abs(y) > 12

	// local for where to put the text label
	qui sum y 
	local mymin = r(min) 
	local mymax = r(max) 
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

replace y = y - .25 if group == 1
replace y = y + .25 if group == 3
sort y 

twoway (scatter coef y if group == 1, color(maroon)) /// (line coef y, lcolor(ebblue)) /// 
	(scatter coef y if group == 2, color(navy)) ///
	(scatter coef y if group == 3, color(green)) ///
	(rcap lb ub y, color(gs12)), ///
	graphregion(color(white)) ///
	legend(order(1 "Low Risk" 2 "Medium Risk" 3 "High Risk")) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) 
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
//
// // Save data for decomposition 
// if ("`treatment'" == "all") { // change back to "low" if desired later
// 	save "$datadir/Low-Intensity-Intervention_Decomposition.dta", replace
// }
********************************************************************************
