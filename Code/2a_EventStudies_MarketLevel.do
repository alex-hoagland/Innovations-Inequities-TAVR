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


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // extensive = use of technique, intensive = average patient risk conditional on treatment 
local figname = "EventStudy_CZLevel_`1'Treatments_`2'Margin"

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

if ("`treatment'" == "high" & "`margin'" == "extensive") { 
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (tavr == 1 | savr == 1)
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt, by(nCZID yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 // drop if area performs few procs 
}
else if ("`treatment'" == "high" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 
	
	keep if (tavr == 1 | savr == 1) // intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adopt, by(nCZID yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
}
else if ("`treatment'" == "low" & "`margin'" == "extensive") {
	// Construct outcome: aggregate count of procedure at surgeon-yq level
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt, by(nCZID yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 // drop if area performs few procs 
}
else if ("`treatment'" == "low" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 
	
	keep if (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty// intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adopt, by(nCZID yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
}
else if ("`treatment'" == "all" & "`margin'" == "extensive") {
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	// gen num_procs = (inlist(icd9, "3721", "3722", "3723", "3726", "8855", "8856")) // Cardiac Catheterization
	// gen num_procs = (inlist(icd9, "3794", "3795", "3796", "3797", "3798", "0050", "0051") | ///
	// 		inlist(icd9, "0052", "0053", "0054", "8945", "8946", "8947", "8948", "8949") | ///
	// 		inlist(icd9, "3770", "3771", "3772", "3773", "3774", "3775","3776") | ///
	// 		inlist(icd9,"3777","3778","3779") | ///
	// 		inlist(icd9, "3780", "3778", "3782", "3783", "3784", "3785") | ///
	// 		inlist(icd9,"3786","3787","3788","3789")) // Defibrillators/pacemakers
	replace num_procs = 1 if savr == 1 | tavr == 1
	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (sum) num_procs allprocs (mean) t_adopt, by(nCZID yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 // drop if area only does few procedures
}
else if ("`treatment'" == "all" & "`margin'" == "intensive") { 
	// Construct outcome: average predicted patient risk for surgery conditional on valve replacement
	gen allprocs = 1
	bysort bene_id from_dt at_npi yq: replace allprocs = 0 if _n > 1
	bysort CZID: egen todrop = total(allprocs)
	drop if todrop <= 100 // drop MDs with fewer than 10 procedures over all 
	
	keep if tavr == 1 | savr == 1 | /// All surgeries
		(inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty // intensive margin only
	collapse (mean) predicted_risk t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	collapse (mean) predicted_risk t_adop, by(nCZID yq) fast
	rename predicted_risk outcome 
	replace outcome = outcome * 100
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
reghdfe outcome dummy*, absorb(nCZID yq) // vce(cluster CZID) 

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
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'%", place(e))
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
