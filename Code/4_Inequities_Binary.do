/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Inequities in PCI Access
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/26/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear
cap drop if missing(`2') 
if ("`2'" == "riskvar_white") { 
	gen group = (riskvar_black == 1 | riskvar_hisp == 1 | riskvar_other == 1)
	local lab1 = "Nonwhite" 
	local lab0 = "White"
}

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // which distribution are we looking at? 
	// options: riskvar_white, dual, adi, others? 
local figname = "Inequities_`1'Treatments_`2'Margin"

*** Identify treatment (first adoption of tavr) 
// gen t_adopt = yq if tavr == 1
// bysort CZID: ereplace t_adopt = min(t_adopt)

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
	gen group = (`2' >= 80) // top quintile
	local lab1 "Top Quintile ADI" 
	local lab0 "Lowest 80% ADI"
}
gen outcome = num_procs
gcollapse (sum) outcome* allprocs (mean) t_adopt group, by(CZID yq) fast
qui sum group, d
replace group = (group >= `r(p50)') // convert group to binary based on market-levels 

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
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/`mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	qui gen dummy_group_`i' = dummy_`i' * group
}
forvalues i = 2/`mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	qui gen dummy_neg_group_`i' = dummy_neg_`i' * group
}
rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = round(r(mean), .1)

qui reghdfe outcome group dummy*, absorb(CZID yq) vce(cluster CZID) 
regsave 
drop if strpos(var,"o.")
keep if strpos(var, "dummy")
gen inter = (strpos(var, "group"))
replace inter = 1 if inter > 0 
replace var = subinstr(var,"group_","",.)
gen y = substr(var, 11, .)
destring y, replace
replace y = y * -1
replace y = real(substr(var, 7, .)) if missing(y)

//  add base treatment effect to interactions
gen base = coef if inter == 0
bysort y : ereplace base = mean(base)
replace coef = coef + base if inter == 1

gen lb = coef - 1.96*stderr
gen ub = coef + 1.96*stderr

// keep only 4 yqs pre-/post-adoption
drop if abs(y) > 12

	// local for where to put the text label
	qui sum y 
	local mymin = `r(min)' 
	local mymax = `r(max)'
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = `r(max)' * 0.85

replace y = y + .25 if inter == 1
sort y 

twoway (scatter coef y if inter == 1, color(maroon)) /// (line coef y, lcolor(ebblue)) /// 
	(scatter coef y if inter == 0, color(navy)) ///
	(rcap lb ub y, color(gs12)), ///
	graphregion(color(white)) ///
	legend(order(1 "`lab1'" 2 "`lab0'") rows(1)) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') ///
	xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
