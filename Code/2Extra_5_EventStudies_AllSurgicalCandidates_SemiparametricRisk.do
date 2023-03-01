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

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
// local margin = "extensive" //  "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_PrSurgery_RiskSemiparametric_`1'"

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

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq -  t_adopt if treated == 1
gen post = (period_yq >= 0 & !missing(period_yq))
gen post_risk = post * predrisk_60

// Generate yq dummies
qui sum yq
local k = `r(min)' + 1
forvalues i = `k'/`r(max)' { 
	gen dumyq_`i' = (yq == `i')
}

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = round(r(mean), .1)

// Run regression
// semipar outcome treated post predrisk_60 dumyq*, nonpar(post_risk)
// quietly {
	fp <post_risk> , scale: qui reg outcome treated post predrisk_60 dumyq* <post_risk>
	keep outcome treated post predrisk_60 dumyq* post_risk*
	fp plot, residuals(none) graphregion(color(white)) ///
		saving("Semiparametric_`1'", replace)
// }
********************************************************************************
