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


***** 3. Local polynomial approach for estimated treatment effect conditional on patient risk
// follows Xie et al. (2012) : "Estimating Heterogeneous Treatment Effects w/ Observational Data"
// Currently using method 3 in the paper ("Smoothing-Differencing Method")
local all = `1' // 1 for all interventions, 0 for PCI only
use "$datadir/IVCEventStudy_Base.dta", clear

// first step: separate nonparameteric regressions for treated/control groups
// outcome: use of low-intensity intervention (as % of procs)
// independent variable: patient predicted risk (local nonparameteric)

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)
gen newgroup = (!missing(t_adopt) & year >= t_adopt) // 1 = treated, 0 = control groups

gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
	inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
if (`all' == 1) { 
	replace num_procs = 1 if tavr == 1 | savr == 1 // if you want the outcome to be ALL interventions, not just low-intensity (this is really interesting)	
}

collapse (max) num_procs (mean) t_adopt CZID predicted_risk newgroup, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
gen allprocs = 1
collapse (sum) num_procs allprocs (mean) t_adopt CZID predicted_risk newgroup, by(at_npi yq) fast
gen outcome = num_procs / allprocs * 100
bysort at_npi: egen todrop = total(allprocs)
drop if todrop <= 10 // drop if MD only does 10 procedures

// take out year fixed effects (demean across years)
bysort yq: egen yearmean = mean(outcome)
replace outcome = outcome - yearmean

// take out MD fixed effects (demean across MDs)
bysort at_npi: egen npimean = mean(outcome)
replace outcome = outcome - npimean

drop if predicted_risk >= .2 // Ignore (small) tail of risk distribution
lpoly outcome predicted_risk if newgroup == 0, gen(points_control yhat_control) nograph se(se_control)
	// control group
lpoly outcome predicted_risk if newgroup == 1, at(points_control) gen(yhat_treated) nograph se(se_treated) 
	// treated group

// second step: take difference in predicted values over predicted_risk 
keep points_control yhat_* se_*
drop if missing(points_control)
gen diff = yhat_treated - yhat_control
gen diff_se = sqrt(se_control^2+se_treated^2)
gen diff_lb = diff-1.96*diff_se
gen diff_ub = diff+1.96*diff_se
qui sum diff_lb
local mymin = round(`r(min)')
qui sum diff_ub
local mymax = round(`r(max)')
twoway (connected diff points_control, msymbol(none) lcolor(ebblue) lwidth(medthick)) ///
	(rconnected diff_lb diff_ub points_control, msymbol(none) lcolor(gs1) lpattern(shortdash)), ///
	graphregion(color(white)) yline(0, lpattern(dash)) ///
	xtitle("Predicted Surgical Risk") ///
	ysc(r(`mymin'(2)`mymax')) ylab(`mymin'(2)`mymax',angle(horizontal)) ytitle("") ///
	xline(.03, lcolor(green)) xline(0.08, lcolor(green)) legend(off)

if (`all' == 1) { 
	// Save graphs
	graph save "$output/DDDecomposition_AllInterventions_NonParametric.gph", replace
	graph export "$output/DDDecomposition_AllInterventions_NonParametric.pdf", as(pdf) replace
}
else { 
	// Save graphs
	graph save "$output/DDDecomposition_Low-Intensity-Intervention_NonParametric.gph", replace
	graph export "$output/DDDecomposition_Low-Intensity-Intervention_NonParametric.pdf", as(pdf) replace
}	
********************************************************************************
