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


***** 0. If needed, add an indicator for all surgeries performed by IVCs
use in 1 using "$datadir/all_SurgicalCandidates.dta", clear
capture confirm variable isivc
if (_rc == 111) { // if variable doesn't exist, create it
	use "$datadir/all_SurgicalCandidates.dta" if tavr == 1 | savr == 1 | ptca2 == 1, clear
	gcollapse (max) tavr savr ptca2, by(bene_id) fast
	rename (tavr savr ptca2) (tavr_t savr_t ptca2_t) // for target/match comparison
	merge 1:m bene_id using "$datadir/all_InpatientCardiology", keep(3) nogenerate
	keep if group == 1 // just keep IVCs
	gen tokeep = 0 
	replace tokeep = 1 if tavr_t == tavr 
	replace tokeep = 1 if savr_t == savr
	replace tokeep = 1 if ptca2_t == ptca2
	keep if tokeep == 1
	drop tokeep
	gcollapse (max) tavr savr ptca2, by(bene_id) fast
	
	// Merge back in one at a time
	preserve
	keep if tavr == 1
	keep bene_id tavr
	gen tomerge = 1 
	merge 1:m bene_id tavr using "$datadir/all_SurgicalCandidates.dta", keep(2 3) nogenerate
	cap gen isivc = tomerge
	drop tomerge 
	save "$datadir/all_SurgicalCandidates.dta", replace
	restore
	
	preserve
	keep if savr == 1
	keep bene_id savr
	gen tomerge = 1 
	merge 1:m bene_id savr using "$datadir/all_SurgicalCandidates.dta", keep(2 3) nogenerate
	replace isivc = 1 if tomerge == 1 
	drop tomerge 
	save "$datadir/all_SurgicalCandidates.dta", replace
	restore
	
	keep if ptca2 == 1
	keep bene_id ptca2
	gen tomerge = 1 
	merge 1:m bene_id ptca2 using "$datadir/all_SurgicalCandidates.dta", keep(2 3) nogenerate
	replace isivc = 1 if tomerge == 1 
	drop tomerge 
	replace isivc = 0 if isivc != 1
	save "$datadir/all_SurgicalCandidates.dta", replace
}


***** 1. Event Studies
use "$datadir/all_SurgicalCandidates.dta" if runif < `2', clear // take % sample of observations
	// note: runif is a uniform draw that is consistent across individuals

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
// local margin = "extensive" //  "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_PrSurgery_`1'"

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

*** Gen dummy variables
qui sum period_yq
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/16 { // `mymax' { 
	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
}
forvalues i = 2/16 { // `mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
}
// rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = round(r(mean), .1)

// Run regression
bysort bene_id (yq): gen yrinsample = _n
gen y2 = yrinsample * yrinsample
// cap destring state_cd, replace 
keep  yq CZID outcome dummy* yrinsample y2 riskvar*
qui reghdfe outcome dummy* yrinsample y2 riskvar*, absorb(yq CZID)  // vce(cluster CZID) 
// qui logit outcome dummy* i.yq

// Graph results
regsave
drop if strpos(var,"o.")
keep if strpos(var, "dummy")
cap replace var = subinstr(var, "outcome:","",.)
gen y = substr(var, 11, .)
destring y, replace
replace y = y * -1
replace y = real(substr(var, 7, .)) if missing(y)
local obs = _N+1
set obs `obs'
replace y = -1 in `obs'
replace coef = 0 in `obs'
replace stderr = 0 in `obs'
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

sort y 
twoway (scatter coef y, color(maroon)) /// (line coef y, lcolor(ebblue)) /// 
	(rcap lb ub y, lcolor(ebblue%60)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
