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
local figname = "EventStudy_CZLevel_`1'Treatments_Semiparametric"

*** Identify treatment (first adoption of tavr) 
// gen t_adopt = yq if tavr == 1
// bysort CZID: ereplace t_adopt = min(t_adopt)

gen medrisk = inrange(predrisk_60, 0.03, 0.08)
gen highrisk = predrisk_60 >= 0.08 & !missing(predrisk_60)
drop if missing(predrisk_60)

if ("`treatment'" == "high") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen outcome = (tavr == 1 | savr == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt predrisk*, by(CZID yq) fast
}
else if ("`treatment'" == "low") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen outcome = (ptca2 == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt predrisk*, by(CZID yq) fast
}
else if ("`treatment'" == "all") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen outcome = (tavr == 1 | savr == 1 | ptca2 == 1)
	gen allprocs = 1
	gcollapse (sum) outcome* allprocs (mean) t_adopt predrisk*, by(CZID yq) fast
}

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
gen post = (period_yq >= 0 & !missing(period_yq))
gen post_risk = post * predrisk_60
//
// *** Gen dummy variables
// qui sum period_yq
// local mymin = `r(min)'*-1
// local mymax = `r(max)'
//
// forvalues  i = 0/`mymax' { 
// 	qui gen dummy_`i' = (period_yq == `i' & treated == 1)
// }
// forvalues i = 2/`mymin' { 
// 	local j = `i' * -1
// 	qui gen dummy_neg_`i' = (period_yq == `j' & treated == 1)
// }
// rename dummy_neg_`mymin' dropdummy 

// Run regression
// semipar outcome treated post predrisk_60 dumyq*, nonpar(post_risk)
// quietly {
	fp <post_risk> , scale: qui reghdfe outcome post predrisk_60 <post_risk>, absorb(CZID) resid
	cap keep outcome post predrisk_60 post_risk* CZID yq t_adopt _reghdfe_resid
	fp plot if post_risk > .001, residuals(none) graphregion(color(white)) ///
		saving("Semiparametric_`1'", replace)
// }
********************************************************************************
