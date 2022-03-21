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


***** 1. Heterogeneity in effect of TAVR adoption on use of PCI/any services across distributions
// NOTE: this file doesn't say *anything* about the crowd-out region, this is just the full income/race distribution

local all = `1' // 1 = all interventions, 0 = PCI only 
local figname "InequitiesIncome_DistributionDD_`1'Interventions_`2'Quantiles"

*** Create blank data set of deciles in order to save DD coefficients
clear
set obs `2' // Number of quantiles to use across income distribution
gen deciles = _n
gen dd_coef = .
gen dd_se = .  
gen dd_lb = . 
gen dd_ub = . 
sort deciles
save "$datadir/Income_DDDecomposition.dta", replace

use "$datadir/IVCEventStudy_Base.dta", clear
xtile deciles = medinc_, nq(`2')

forvalues d = 1/`2' { 
	preserve
	keep if deciles == `d' // only look at patients in income decile of interest
	
	// Construct outcome: aggregate count of procedure at surgeon-year level
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = yq if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)
	 
	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	if (`all' == 1) { 
		replace num_procs = 1 if tavr == 1 | savr == 1
	}
	
	collapse (max) num_procs (mean) t_adopt CZID deciles predicted_risk, by(bene_id from_dt at_npi yq) fast 
		// collapse to the procedure level (avoid inflation in proc codes after ICD-10)
	gen allprocs = 1 // if deciles == `d' 
	// replace num_procs = 0 if deciles != `d' 
	collapse (sum) num_procs allprocs (mean) deciles predicted_risk t_adopt CZID, by(at_npi yq) fast
	gen outcome = ((num_procs / allprocs * 100))

	// Generate relative time variables
	qui gen treated = (!missing(t_adopt))
	qui gen period_yr = yq - t_adopt if treated == 1
	
	// Save DD coefficient in data set 
	gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
	reghdfe outcome post, absorb(at_npi yq) vce(cluster CZID)
	local dd_coef = round(e(b)[1,1],.001)
	local dd_se = round(sqrt(e(V)[1,1]),.001)
	
	// Update DDDecomposition.dta
	use "$datadir/Income_DDDecomposition.dta", clear
	sort deciles
	replace dd_coef = `dd_coef' if deciles == `d'
	replace dd_se = `dd_se' if deciles == `d'
	save "$datadir/Income_DDDecomposition.dta", replace
	
	restore
}

// Generate figure across bins
use "$datadir/Income_DDDecomposition.dta", clear
replace dd_lb = dd_coef-1.96*dd_se
replace dd_ub = dd_coef+1.96*dd_se
twoway (scatter dd_coef deciles, color(maroon)) (rcap dd_lb dd_ub deciles, lcolor(ebblue%80)), ///
	graphregion(color(white)) legend(off) ///
	yline(0, lpattern(dash) lcolor(red)) ///
	xsc(r(1(1)`2')) xlab(1(1)`2') xtitle("Quantiles of Patient Income") ///
	ylab(, angle(horizontal))
	
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
