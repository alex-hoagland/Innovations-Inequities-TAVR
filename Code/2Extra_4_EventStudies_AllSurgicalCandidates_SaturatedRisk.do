/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/10/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: - TODO: should this be weighted somehow? 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/all_SurgicalCandidates.dta" if runif < `2', clear // take % sample of observations
	// note: runif is a uniform draw that is consistent across individuals
by bene_id: ereplace predrisk_60 = mean(predrisk_60) // consistent across individuals

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
// local margin = "extensive" //  "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_PrSurgery_RiskSaturated_`1'"

*** Identify treatment (first adoption of tavr) 
// gen t_adopt = yq if tavr == 1
// bysort CZID: ereplace t_adopt = min(t_adopt) // note: most CZs have at least one adoption!

*** Identify outcome: likelihood of surgery based  on `1'
replace isivc = 1 if isivc2 == 1
if ("`treatment'" == "high") { 
	gen outcome = (tavr == 1 | savr == 1) 
	replace outcome = 0 if isivc == 0
	// gcollapse (mean) outcome t_adopt, by(CZID yq) fast
}
else if ("`treatment'" == "low") {
	gen outcome = (ptca2 == 1)
	replace outcome = 0 if isivc == 0
}
else if ("`treatment'" == "all") {
	gen outcome = (tavr == 1 | savr == 1 | ptca2 == 1)
	replace outcome = 0 if isivc == 0
}

// // Generate weights (# of patients in each CZ)
// // note: for this regression, not used as weights, just to trim some people
// bysort CZID yq: gen num_pats = _N
// gen todrop = (num_pats < 10) 
// bysort CZID: ereplace todrop = max(todrop) 
// drop if todrop == 1 
// drop todrop
//  // doesn't drop very many (7k observations of 60 million)

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq -  t_adopt if treated == 1

*** Gen interaction terms 
gen medrisk = inrange(predrisk_60, 0.03, 0.08)
gen highrisk = (predrisk_60 > 0.08)

*** Gen dummy variables
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/16 { // `mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
	qui gen dummy_med_`i' = dummy_`i' * medrisk
	qui gen dummy_high_`i' = dummy_`i' * highrisk
}
forvalues i = 2/16 { // `mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
	qui gen dummy_neg_med_`i' = dummy_neg_`i' * medrisk
	qui gen dummy_neg_high_`i' = dummy_neg_`i' * highrisk
}
// rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
replace outcome = outcome * 100
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = round(r(mean), .01)

// Run regression
bysort bene_id (yq): gen yrinsample = _n
gen y2 = yrinsample * yrinsample
// cap destring state_cd, replace 
keep outcome dummy* yrinsample y2 medrisk highrisk riskvar*  yq CZID
qui reghdfe outcome dummy* yrinsample y2 medrisk highrisk riskvar* , absorb(yq CZID) // absorb(CZID yq) // vce(cluster CZID) 
// qui logit outcome dummy* i.yq

// Graph results
regsave
drop if strpos(var,"o.")
keep if strpos(var, "dummy")
cap replace var = subinstr(var, "outcome:","",.)
gen y = substr(var, length(var)-1, 2)
replace y = subinstr(y, "_", "", .)
destring y, replace
replace y = y * -1 if strpos(var,"neg")
// local obs = _N+1
// set obs `obs'
// replace y = -1 in `obs'
// replace coef = 0 in `obs'
// replace stderr = 0 in `obs'
gen lb = coef - 1.96*stderr
gen ub = coef + 1.96*stderr

// groups
gen group = 1
replace group = 2 if strpos(var,"med")
replace group = 3 if strpos(var,"high")

// add in base terms for the interaction terms in med/high risk groups
gen base = coef if group == 1
bysort y: ereplace base = mean(base) 
foreach v of var coef lb ub { 
	replace `v' = `v' + base if group > 1
}
drop base

// keep only 4 yqs pre-/post-adoption
replace y = y-.25 if group == 1 
replace y = y+.25 if group == 3
drop if abs(y) > 12.5

	// local for where to put the text label
	qui sum y 
	local mymin = r(min)+0.25 
	local mymax = r(max)-0.25
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

sort y 
twoway  (scatter coef y if group == 1, color(maroon)) /// 
	(scatter coef y if group == 2, color(navy)) /// 
	(scatter coef y if group == 3, color(green)) ///  
	(rcap lb ub y, lcolor(gs12)), ///
	graphregion(color(white))  ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e)) ///
	legend(order(1 "Low Risk" 2 "Medium Risk" 3 "High Risk"))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
