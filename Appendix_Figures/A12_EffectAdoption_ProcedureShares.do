/*******************************************************************************
* Title: Fragment to run event studies
* Created by: Alex Hoagland
* Created on: 3/1/2022
* Last modified on: 
* Last modified by: 
* Purpose: 

* Notes: 

* Key edits:
*******************************************************************************/

use "$datadir/all_IVcardiologists.dta", clear
	// Generate relative time variables
	qui gen treated = (!missing(fyear_tavr))
	qui gen period = year - fyear_tavr if treated == 1

	*** Gen dummy variables
	qui sum period
	local mymin = `r(min)'*-1
	local mymax = `r(max)'

	forvalues  i = 0/`mymax' { 
		qui gen dummy_`i' = (period == `i' & treated == 1)
	}
	forvalues i = 2/`mymin' { 
		local j = `i' * -1
		qui gen dummy_neg_`i' = (period == `j' & treated == 1)
	}
	rename dummy_neg_`mymin' dropdummy 

	// Run regression + graph results
	preserve
		// Store mean before treatment 
		sum share_tavr if period < 0 | missing(period), d
		global pretreat = round(r(mean), .1)
	reghdfe share_tavr dummy* [aw=num_pats], absorb(npi year)

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
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Years Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: $pretreat `p'", place(e))
			
	// Save graphs
	graph save "$output/Effect_Adoption_ShareTAVR.gph", replace
	graph export "$output/Effect_Adoption_ShareTAVR.pdf", as(pdf) replace
	
	restore
		// Store mean before treatment 
		sum share_ptca if period < 0 | missing(period), d
		global pretreat = round(r(mean), .1)
	reghdfe share_ptca dummy* [aw=num_pats], absorb(npi year)

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
		xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Years Around TAVR Adoption") /// 
		ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: $pretreat `p'", place(e))
			
	// Save graphs
	graph save "$output/Effect_Adoption_SharePTCA.gph", replace
	graph export "$output/Effect_Adoption_SharePTCA.pdf", as(pdf) replace
