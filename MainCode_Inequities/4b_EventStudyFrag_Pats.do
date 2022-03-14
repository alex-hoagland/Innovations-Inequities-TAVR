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


// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yr = year - t_adopt if treated == 1

*** Gen dummy variables
qui sum period_yr
local mymin = `r(min)'*-1
local mymax = `r(max)'

forvalues  i = 0/`mymax' { 
	qui gen dummy_`i' = (period_yr == `i' & treated == 1)
}
forvalues i = 2/`mymin' { 
	local j = `i' * -1
	qui gen dummy_neg_`i' = (period_yr == `j' & treated == 1)
}
rename dummy_neg_`mymin' dropdummy 

// Store mean before treatment 
sum outcome if period_yr < 0 | missing(period_yr), d
local pretreat = r(mean)

// Run regression 
reghdfe outcome dummy*, absorb(bene_id year) 

// Graph results
regsave
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
	xsc(r(`mymin'(1)`mymax')) xlab(`mymin'(1)`mymax') xtitle("Years Around TAVR Adoption") /// 
	ylab(,angle(horizontal)) text(`myy' `myx' "Pre-treatment mean: `pretreat'", place(e))
