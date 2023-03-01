/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess whether TAVR changed surgical outcomes

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local outcome = "`2'" // readmit = readmissions; mortality
local figname = "Mechanisms_`1'Treatments_`2'"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

qui sum predrisk_60 // normalize risk scores 
gen normrisk = predrisk_60 / `r(mean)'
replace normrisk = .01 if normrisk < .01
// keep if inrange(predrisk_60, .05, .08) // crowd-out region 

if ("`treatment'" == "high" & "`outcome'" == "readmit") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_readmit <= 30 & !missing(days_readmit))/normrisk
	gen outcome2 = (num_procs == 1 & days_readmit <= 60 & !missing(days_readmit))/normrisk
	gen outcome3 = (num_procs == 1 & days_readmit <= 90 & !missing(days_readmit))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs // convert to % of procs
	}
}
if ("`treatment'" == "low" & "`outcome'" == "readmit") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (ptca == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_readmit <= 30 & !missing(days_readmit))/normrisk
	gen outcome2 = (num_procs == 1 & days_readmit <= 60 & !missing(days_readmit))/normrisk
	gen outcome3 = (num_procs == 1 & days_readmit <= 90 & !missing(days_readmit))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs // * 1000 // convert to rate per 1000 surgeries
	}
}
if ("`treatment'" == "all" & "`outcome'" == "readmit") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1 | ptca == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_readmit <= 30 & !missing(days_readmit))/normrisk
	gen outcome2 = (num_procs == 1 & days_readmit <= 60 & !missing(days_readmit))/normrisk
	gen outcome3 = (num_procs == 1 & days_readmit <= 90 & !missing(days_readmit))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs  // convert to % of procs
	}
}
if ("`treatment'" == "high" & "`outcome'" == "mortality") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_mortality <= 30 & !missing(days_mortality))/normrisk
	gen outcome2 = (num_procs == 1 & days_mortality <= 60 & !missing(days_mortality))/normrisk
	gen outcome3 = (num_procs == 1 & days_mortality <= 90 & !missing(days_mortality))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs  // convert to % of procs
	}
}
if ("`treatment'" == "low" & "`outcome'" == "mortality") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (ptca == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_mortality <= 30 & !missing(days_mortality))/normrisk
	gen outcome2 = (num_procs == 1 & days_mortality <= 60 & !missing(days_mortality))/normrisk
	gen outcome3 = (num_procs == 1 & days_mortality <= 90 & !missing(days_mortality))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs  // convert to % of procs
	}
}
if ("`treatment'" == "all" & "`outcome'" == "mortality") { 
	// Construct outcome: surgical complications at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1 | ptca == 1)
	gen allprocs = 1
	gen outcome1 = (num_procs == 1 & days_mortality <= 30 & !missing(days_mortality))/normrisk
	gen outcome2 = (num_procs == 1 & days_mortality <= 60 & !missing(days_mortality))/normrisk
	gen outcome3 = (num_procs == 1 & days_mortality <= 90 & !missing(days_mortality))/normrisk
	gcollapse (sum) allprocs outcome*  num_procs (mean) t_adopt, by(CZID yq) fast
	foreach v of varlist outcome* { 
		replace `v' = `v' / num_procs  // convert to % of procs
	}
}

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
fillin CZID yq
rename _fillin todrop
replace allprocs = 0 if missing(allprocs)
replace todrop = 1 if allprocs < 10
bysort CZID: ereplace todrop = max(todrop) 
drop if todrop == 1 
drop todrop

// // generate time trend
// bysort CZID (yq): gen ys = _n 
// gen ys2 = ys^2

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq -  t_adopt if treated == 1

*** Gen dummy variables
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/16 { //`mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
}
forvalues i = 2/15 { // `mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
}
// rename dummy_neg_`mymin' dropdummy 

// generate weights as average # of procs of interest done at CZ level
bysort CZID: egen wt = mean(num_procs)

// loop through three outcomes 
foreach v of var outcome* {
	// replace `v' = asinh(`v') //  * 100  // transform to rate per 100 surgeries
	qui reghdfe `v' dummy* [aw=wt], absorb(CZID yq) // vce(cluster CZID) 
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
	legend(order(1 "30 Days" 2 "60 Days" 3 "90 Days") rows(1)) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) 
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
