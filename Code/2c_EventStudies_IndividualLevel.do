/*******************************************************************************
* Title: Effect of TAVR Adoption on SAVR/TAVR or PCI use by income 
* Created by: Alex Hoagland
* Created on: 3/1/2022
* Last modified on: 
* Last modified by: 
* Purpose: Show inequities in access to surgeries by income quintile

* Notes: 

* Key edits: - TODO: this needs to move beyond just those seeking IP care from an IVC? 
*******************************************************************************/


***** 1. Prep Data
// to look at: how does this differ across risk? Patient income? If/not they have AS? 
use "$datadir/IVCEventStudy_Base.dta", clear
gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
if ("`1'" == "all") { 
	replace num_procs = 1 if tavr == 1 | savr == 1
}

// keep if as_flag == 1 & inrange(predicted_risk, .05, .15) // now focus on desired population only 

*** Identify treatment (first adoption of tavr in local market) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)
		
collapse (max) outcome=num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast 
	// collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	// did the patient get treated at all? 

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
local pretreat = round(r(mean), .1)

// Run regression 
reghdfe outcome dummy*, absorb(at_npi yq) vce(cluster CZID) 

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

sort y 

// local for where to put the text label
qui sum y 
local mymin = r(min) 
local mymax = r(max) 
local myx = `mymax' * 0.05
qui sum ub
local myy = r(max) * 0.85

twoway (scatter coef y, color(maroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'%", place(e))

// Save graphs
* graph save "$output/`figname'.gph", replace
* graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
