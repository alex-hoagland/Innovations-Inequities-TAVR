/*******************************************************************************
* Title: Decompose effect of TAVR adoption on low-intensity use by patient risk
* Created by: Alex Hoagland
* Created on: 2/23/2022
* Last modified on: 
* Last modified by: 
* Purpose: 

* Notes: Binned approach --- shows effect for theta in medium-high risk (.05 and above), 
	- then estimates treatment effects across deciles
	- then uses local polynomial to estimate treatment effect across theta

* Key edits:
*******************************************************************************/


***** 1. Low-intensity treatment (extensive margin) for highest x% of conditional risk
local thetabar = `1'
use "$datadir/IVCEventStudy_Base.dta", clear

preserve
// Construct outcome: aggregate count of procedure at surgeon-year level
*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

// Construct outcome: aggregate count of procedure at surgeon-yq level
gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
	inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
replace num_procs = 0 if predicted_risk < `thetabar' // Keep only those in cut-off region

collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
gen allprocs = 1
collapse (sum) num_procs allprocs (mean) t_adopt CZID, by(at_npi yq) fast
gen outcome = num_procs / allprocs * 100
bysort at_npi: egen todrop = total(allprocs)
drop if todrop <= 10 // drop if MD only does 10 procedures

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
graph save "$output/EventStudyDecomposition_Low-Intensity-Intervention_Thetabar`thetabar'.gph", replace
graph export "$output/EventStudyDecomposition_Low-Intensity-Intervention_Thetabar`thetabar'.pdf", as(pdf) replace

// Merge in aggregated data for decomposition
rename coef coef_high 
rename lb lb_high
rename ub ub_high
merge 1:1 y using "$datadir/Low-Intensity-Intervention_Decomposition.dta", nogenerate
twoway (scatter coef_high y, color(navy)) (line coef_high y, lcolor(gold)) /// 
	(rarea lb_high ub_high y, lcolor(gold%30) fcolor(gold%30)) ///
	(scatter coef y, color(marroon)) (line coef y, lcolor(ebblue)) /// 
	(rarea lb ub y, lcolor(ebblue%30) fcolor(ebblue%30)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal))
graph save "$output/LowIntensityIntervention_Decomposition_Thetabar`thetabar'.gph", replace
graph export "$output/LowIntensityIntervention_Decomposition_Thetabar`thetabar'.pdf", as(pdf) replace
restore
********************************************************************************
