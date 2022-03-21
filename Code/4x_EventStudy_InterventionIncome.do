/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Patient Income 
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 3/18/2022
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Study
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local figname = "EventStudy_PatientIncome_`1'Treatments"

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

gen allprocs = 1
bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
bysort at_npi: egen todrop = total(allprocs)
drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 

replace medinc = log(medinc) // main outcome: log of median income

else if ("`treatment'" == "high") { 
	keep if (tavr == 1 | savr == 1) // intensive margin only
	collapse (mean) medinc* predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (p50) medinc* (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename medinc outcome 
}
else if ("`treatment'" == "low") { 
	keep if (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty// intensive margin only
	collapse (mean) medinc* predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (p50) medinc* (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename medinc outcome 
}
else if ("`treatment'" == "all") {	
	keep if tavr == 1 | savr == 1 | /// All surgeries
		(inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty // intensive margin only
	collapse (mean) medinc* predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (p50) medinc* (mean) predicted_risk t_adopt nCZID, by(at_npi yq) fast
	rename medinc outcome 
}

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

// Store mean before treatment 
sum outcome if period_yq < 0 | missing(period_yq), d
local pretreat = round(r(mean), .01)

// Run regression 
reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster nCZID) 

// Graph results
regsave
drop if strpos(var,"o.")
keep if strpos(var, "dummy")
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
drop if abs(y) > 16

	// local for where to put the text label
	qui sum y 
	local mymin = r(min) 
	local mymax = r(max) 
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

sort y 
twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
