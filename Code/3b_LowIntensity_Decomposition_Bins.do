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


***** 2. Now, use bins of theta (deciles)
local all = `1' // 1 for all, 0 for only PCI
local nq = 10 // number of quantiles to use for bins

*** Create blank data set of deciles in order to save DD coefficients
clear
set obs `nq'
gen deciles = _n
gen dd_coef = .
gen dd_se = .  
gen dd_lb = . 
gen dd_ub = . 
sort deciles
save "$datadir/DDDecomposition.dta", replace

use "$datadir/IVCEventStudy_Base.dta", clear
xtile deciles = predicted_risk, nq(`nq')

// identify traditional cutoffs for risk (3, 8 percent)
sum decile if abs(predicted_risk-.03) < .0001
local lowmed = `r(mean)'
sum decile if abs(predicted_risk-.08) < .0001
local medhigh = `r(mean)'

*** Identify treatment (first adoption of tavr) 
gen t_adopt = yq if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

*** Construct outcome: aggregate count of procedure at surgeon-year level
gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
	inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
if (`all' == 1) { 
	replace num_procs = 1 if tavr == 1 | savr == 1 // if you want the outcome to be ALL interventions, not just low-intensity (this is really interesting)	
}

// Run DD Regressions
forvalues d = 1/`nq' { 
	preserve
	
	replace num_procs = 0 if deciles != `d' // Keep only those in cut-off region

	collapse (max) num_procs (mean) t_adopt CZID, by(bene_id from_dt at_npi yq) fast // collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1
	collapse (sum) num_procs allprocs (mean) t_adopt CZID, by(at_npi yq) fast
	gen outcome = num_procs / allprocs * 100
	bysort at_npi: egen todrop = total(allprocs)
	drop if todrop <= 10 // drop if MD only does 10 procedures

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yr = yq - t_adopt if treated == 1
	
	// Save DD coefficient in data set 
	gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
	reghdfe outcome post, absorb(at_npi yq) vce(cluster CZID) 
	local dd_coef = round(e(b)[1,1],.001)
	local dd_se = round(sqrt(e(V)[1,1]),.001)
	
	// Update DDDecomposition.dta
	use "$datadir/DDDecomposition.dta", clear
	sort deciles
	replace dd_coef = `dd_coef' if deciles == `d'
	replace dd_se = `dd_se' if deciles == `d'
	save "$datadir/DDDecomposition.dta", replace
	
	restore
}

// Generate figure across bins
use "$datadir/DDDecomposition.dta", clear
replace dd_lb = dd_coef-1.96*dd_se
replace dd_ub = dd_coef+1.96*dd_se
twoway (scatter dd_coef deciles, color(maroon)) (rcap dd_lb dd_ub deciles, lcolor(ebblue%80)), ///
	graphregion(color(white)) legend(off) ///
	yline(0, lpattern(dash) lcolor(red)) ///
	xsc(r(1(1)`nq')) xlab(1(1)`nq') xtitle("Deciles of Predicted Patient Risk") ///
	ylab(, angle(horizontal)) ///
	xline(`lowmed', lcolor(green)) xline(`medhigh', lcolor(green))
	
if (`all' == 1) { 
	// Save graphs
	graph save "$output/DDDecomposition_AllInterventions_`nq'Quantiles.gph", replace
	graph export "$output/DDDecomposition_AllInterventions_`nq'Quantiles.pdf", as(pdf) replace
}
else { 
	// Save graphs
	graph save "$output/DDDecomposition_Low-Intensity-Intervention_`nq'Quantiles.gph", replace
	graph export "$output/DDDecomposition_Low-Intensity-Intervention_`nq'Quantiles.pdf", as(pdf) replace
}	
********************************************************************************
