/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Inequities in PCI Access (Binned)
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/26/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: -- looks across ventiles of distribution (at CZ-yq) level 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear
cap drop if missing(`2') 

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // which distribution are we looking at? 
	// options: riskvar_white, dual, adi, others? 
local figname = "InequitiesBinned_`1'Treatments_`2'"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

// use "`treatment'" to identify num_procs 
if ("`treatment'" == "high") { 
	gen num_procs = (tavr == 1 | savr == 1)
}
else if ("`treatment'" == "low") { 
	gen num_procs = (ptca == 1)
}
else if ("`treatment'" == "all") { 
	gen num_procs = (tavr == 1 | savr == 1 | ptca == 1)
}

// use "`margin'" to generate outcome 
gen allprocs = 1 
if ("`margin'" == "riskvar_dual_any" | "`margin'" == "riskvar_dual_full") { 
	gen group = `2'
	local lab1 "Dual" 
	local lab0 "Non-Dual"
}
if ("`margin'" == "riskvar_adi_5" | "`margin'" == "riskvar_adi_9") { 
	gen group = `2'*-1 // need to flip this since they are rankings
	local lab1 "More Disadvantaged" 
	local lab0 "Less Disadvantaged"
}
if ("`margin'" == "riskvar_white") { 
	gen group = (riskvar_black == 1 | riskvar_hisp == 1 | riskvar_other == 1)
	local lab1 = "Nonwhite" 
	local lab0 = "White"
}
gen outcome = num_procs
bysort CZID: ereplace group = mean(group) // want this to be consistent across CZ's to separate them
gcollapse (sum) outcome* allprocs (mean) t_adopt group, by(CZID yq year) fast

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
fillin CZID yq
rename _fillin todrop
replace allprocs = 0 if missing(allprocs)
replace todrop = 1 if allprocs < 10
bysort CZID: ereplace todrop = max(todrop) 
drop if todrop == 1 
drop todrop

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq -  t_adopt if treated == 1

*** Gen dummy variables
// qui sum period_yq
// local mymin = `r(min)'*-1
// local mymax = `r(max)'
//
// forvalues  i = 0/16 { // `mymax' { 
// 	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
// }
// forvalues i = 2/15 { // `mymin' { 
// 	local j = `i' * -1
// 	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
// }
// // rename dummy_neg_`mymin' dropdummy 

// Loop across venitles of distribution of "group", collect treatment effect for each 
xtile deciles = group, n(20)
gen post = (period_yq >= 0 & !missing(period_yq))

forvalues g = 1/20 { 
	di "***** REGRESSION FOR DECILE `g' *****"
	quietly {
	
	qui reghdfe outcome post if decile == `g', absorb(CZID) // todo: why not yq here as well? 
	// qui reghdfe outcome dummy* if deciles == `g', absorb(CZID yq) vce(cluster CZID) 
	preserve
	regsave
	drop if strpos(var,"o.")
	keep if strpos(var, "post")
	keep coef stderr
	gen lb = coef - 1.96*s
	gen ub = coef + 1.96*s
	gen group = `g'
// 	keep if strpos(var, "dummy") 
// 	gen y = substr(var, 11, .)
// 	destring y, replace
// 	replace y = y * -1
// 	replace y = real(substr(var, 7, .)) if missing(y)
// 	keep if inrange(y, 4, 12) // keep years 1-3 after adoption 
//
// 	gen lb = coef - 1.96*stderr
// 	gen ub = coef + 1.96*stderr
//
// 	gcollapse (mean) coef lb ub, fast
// 	gen group = `g'
	save "$datadir/inequities_binned_`1'_`2'_`g'.dta", replace
	restore
}
}

use "$datadir/inequities_binned_`1'_`2'_1.dta", clear
forvalues g = 2/20 { 
	append using "$datadir/inequities_binned_`1'_`2'_`g'"
}

twoway (scatter coef g, color(maroon)) (rcap lb ub g, color(gs12)) , ///
		graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
		legend(off) xtitle("Group Ventile (CZ Level)") ylab(,angle(horizontal))
graph save "$output/`figname'", replace
graph export "$output/`figname'.pdf", replace as(pdf) 

local b = .8
twoway (scatter coef g, color(maroon%60))  ///
	(lowess coef g, bwidth(`b') color(maroon)) ///
	(lowess ub g, bwidth(`b') color(gs12)) ///
	(lowess lb g, bwidth(`b') color(gs12)) , ///
	graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
	legend(off) xtitle("CZ Ventile") ylab(,angle(horizontal)) 
graph save "$output/`figname'_Smoothed", replace
graph export "$output/`figname'_Smoothed.pdf", replace as(pdf) 
********************************************************************************
