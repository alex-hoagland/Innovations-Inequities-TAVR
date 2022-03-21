/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Other Surgery Outcomes
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies on pmt_amt and OOP for TAVR/SAVR and PCI
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // oop or total 
local figname = "EventStudy_Spending_`1'Treatments_`2'Costs"

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

if ("`treatment'" == "high" & "`margin'" == "oop") { 
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (tavr == 1 | savr == 1)
	collapse (max) num_procs (sum) oop (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) oop t_adopt nCZID, by(at_npi yq) fast
	gen outcome = oop
}
else if ("`treatment'" == "high" & "`margin'" == "total") { 
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (tavr == 1 | savr == 1)
	collapse (max) num_procs (sum) pmt_amt (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) pmt_amt t_adopt nCZID, by(at_npi yq) fast
	gen outcome = pmt_amt
}
else if ("`treatment'" == "low" & "`margin'" == "oop") {
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	collapse (max) num_procs (sum) oop (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) oop t_adopt nCZID, by(at_npi yq) fast
	gen outcome = oop
}
else if ("`treatment'" == "low" & "`margin'" == "total") { 
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	collapse (max) num_procs (sum) pmt_amt (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) pmt_amt t_adopt nCZID, by(at_npi yq) fast
	gen outcome = pmt_amt
}
else if ("`treatment'" == "all" & "`margin'" == "oop") {
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) | /// Valvuloplasty
		tavr == 1 | savr == 1
	collapse (max) num_procs (sum) oop (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) oop t_adopt nCZID, by(at_npi yq) fast
	gen outcome = oop
}
else if ("`treatment'" == "all" & "`margin'" == "total") { 
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop MDs with fewer than 10 procedures over all 
	
	// Construct outcome: average spending on intervention (bundled at visit level)
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) | /// Valvuloplasty
		tavr == 1 | savr == 1
	collapse (max) num_procs (sum) pmt_amt (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	keep if num_procs == 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) pmt_amt t_adopt nCZID, by(at_npi yq) fast
	gen outcome = pmt_amt
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

// Transformm outcome variable 
replace outcome = asinh(outcome)

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
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: $`pretreat'", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
