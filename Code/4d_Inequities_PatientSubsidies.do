/*******************************************************************************
* Title: Effect of TAVR Adoption on SAVR/TAVR or PCI use by income 
* Created by: Alex Hoagland
* Created on: 3/1/2022
* Last modified on: 
* Last modified by: 
* Purpose: Show inequities in access to surgeries by income quintile

* Notes: 

* Key edits:
*******************************************************************************/


***** 1. Prep Data
use "$datadir/IVCEventStudy_Base.dta", clear
local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both

// Define crowd-out region
local thetabar_l = `2'
local thetabar_u = `3'

local figname = "EventStudy_IncomeInequities_`1'Treatments_Binary"
cap graph drop * 
********************************************************************************


***** 2. Event Studies for Use of Interventions
// run separate event studies across eligibility categories  
// for now, just bin into "low" and "high" income

gen lowinc = (lowinc_lis_elig == 1 | lowinc_lis_enrol == 1 | lowinc_lis_premsub > 0 | /// 
	lowinc_lis_copay > 0 | lowinc_dual_mdcd == 1 | lowinc_dual_other == 1) // covers about 1/4 of patients
forvalues q = 0/1 { 
	preserve
	// keep if incq == 1 & predicted_risk > .05 // keep those in lowest income quintile, in crowd-out region

	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	// Construct outcome: aggregate count of alternate procedure at surgeon-year level
	if ("`treatment'" == "high") { 
		gen num_procs = (tavr == 1 | savr == 1)
	}
	if ("`treatment'" == "low") { 
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
			inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	}
	else if ("`treatment'" == "all") { 
		gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
				inlist(icd9, "3510", "3511", "3512", "3513", "3514")) | /// Valvuloplasty
				tavr == 1 | savr == 1
	}
	
	replace num_procs = 0 if lowinc != `q' | !inrange(predicted_risk,`thetabar_l',`thetabar_u') 
		// only look at share for crowd-out region patients in desired income group.
		
	collapse (max) num_procs as_flag (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast 
		// collapse to the procedure level (avoid inflation in proc codes after ICD-10)

	gen allprocs = 1
	bysort at_npi: egen nCZID = mode(CZID), nummode(1)
	// replace num_procs = 0 if as_flag == 0
	collapse (sum) num_procs allprocs (mean) t_adopt nCZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop if MD only does few procedures

	do "$allcode/EventStudyFrag.do"
	save "$datadir/tomerge_`q'.dta", replace
	
	restore
}

// Merge in aggregated data for decomposition
use "$datadir/tomerge_0.dta", clear
rename coef coef_high
rename lb lb_high
rename ub ub_high
merge 1:1 y using "$datadir/tomerge_1.dta", nogenerate


// local for where to put the text label
qui sum y 
local mymin = r(min) 
local mymax = r(max) 
local myx = `mymax' * 0.05
qui sum ub
local myy = r(max) * 0.85

twoway (scatter coef_high y, color(navy)) (line coef_high y, lcolor(gold)) /// 
	(rarea lb_high ub_high y, lcolor(gold%30) fcolor(gold%30)) ///
	(scatter coef y, color(marroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) 

// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace

rm "$datadir/tomerge_0.dta"
rm "$datadir/tomerge_1.dta"
********************************************************************************
