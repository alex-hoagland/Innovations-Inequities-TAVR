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


***** Packages and directories
global mydir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666"
global datadir "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/CMS_Updated202105"
global geodata "/homes/nber/hoagland-dua55666/talgross-DUA55666/hoagland-dua55666/2_Data/Geography"
global output "$mydir/ToExport"
********************************************************************************


***** 1. Low-intensity treatment (extensive margin) for highest x% of conditional risk
local thetabar = .08
use "$datadir/IVCEventStudy_Base.dta", clear
drop if year == 2016 // why is 2016 a weird year? 
preserve
// Construct outcome: aggregate count of procedure at surgeon-year level
*** Identify treatment (first adoption of tavr) 
gen t_adopt = year if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)

gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
	inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
replace num_procs = 0 if predicted_risk < `thetabar' // only count highest-risk patient usage
gen allprocs = 1
collapse (sum) num_procs allprocs (mean) t_adopt, by(at_npi year) fast
gen outcome = num_procs / allprocs * 100
gen todrop = (allprocs < 10) // drop those with fewest procs
bysort at_npi year: ereplace todrop = max(todrop)
drop if todrop == 1

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
reghdfe outcome dummy*, absorb(at_npi year) 

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

// Save graphs
graph save "$output/EventStudyDecomposition_Low-Intensity-Intervention_Thetabar`thetabar'.gph", replace
graph export "$output/EventStudyDecomposition_Low-Intensity-Intervention_Thetabar`thetabar'.png", as(png) replace

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
	xsc(r(-4(1)4)) xlab(-4(1)4) xtitle("Years Around TAVR Adoption") /// 
	ylab(,angle(horizontal))
graph save "$output/LowIntensityIntervention_Decomposition_Thetabar`thetabar'.gph", replace
graph export "$output/LowIntensityIntervention_Decomposition_Thetabar`thetabar'.pdf", as(pdf) replace
restore
********************************************************************************


***** 2. Now, use bins of theta (deciles)
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
forvalues d = 1/`nq' { 
	preserve
	// Construct outcome: aggregate count of procedure at surgeon-year level
	*** Identify treatment (first adoption of tavr) 
	gen t_adopt = year if tavr == 1
	bysort at_npi: ereplace t_adopt = min(t_adopt)

	gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
		inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
	replace num_procs = 0 if deciles != `d' // only count usage in decile of risk
	gen allprocs = 1
	collapse (sum) num_procs allprocs (mean) t_adopt, by(at_npi year) fast
	gen outcome = num_procs / allprocs * 100
	gen todrop = (allprocs < 10) // drop those with fewest procs
	bysort at_npi year: ereplace todrop = max(todrop)
	drop if todrop == 1

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
	
	// Save DD coefficient in data set 
	gen post = (period_yr >= 0 & !missing(period_yr) & treated == 1) 
	reghdfe outcome post, absorb(at_npi year)
	local dd_coef = round(e(b)[1,1],.001)
	local dd_se = round(sqrt(e(V)[1,1]),.001)
	
	// Run regression 
	reghdfe outcome dummy*, absorb(at_npi year) 

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

	// Save graphs
	graph save "$output/EventStudyDecomposition_Low-Intensity-Intervention_Quantile`d'.gph", replace
	graph export "$output/EventStudyDecomposition_Low-Intensity-Intervention_Quantile`d'.png", as(png) replace
	
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
	
// Save graphs
graph save "$output/DDDecomposition_Low-Intensity-Intervention_`nq'Quantiles.gph", replace
graph export "$output/DDDecomposition_Low-Intensity-Intervention_`nq'Quantiles.png", as(png) replace
********************************************************************************


***** 3. Local polynomial approach for estimated treatment effect conditional on patient risk
// follows Xie et al. (2012) : "Estimating Heterogeneous Treatment Effects w/ Observational Data"
// Currently using method 3 in the paper ("Smoothing-Differencing Method")
use "$datadir/IVCEventStudy_Base.dta" if year < 2016, clear

// first step: separate nonparameteric regressions for treated/control groups
// outcome: use of low-intensity intervention (as % of procs)
// independent variable: patient predicted risk (local nonparameteric)

*** Identify treatment (first adoption of tavr) 
gen t_adopt = year if tavr == 1
bysort at_npi: ereplace t_adopt = min(t_adopt)
gen newgroup = (!missing(t_adopt) & year >= t_adopt) // 1 = treated, 0 = control groups

gen num_procs = (inlist(icd9, "0061", "0062", "0063", "0064", "0065", "0066") | /// Angioplasty
	inlist(icd9, "3510", "3511", "3512", "3513", "3514")) // Valvuloplasty
gen allprocs = 1
collapse (sum) num_procs allprocs (mean) predicted_risk t_adopt newgroup, by(at_npi year) fast
gen outcome = num_procs / allprocs * 100 // outcome variable 
gen todrop = (allprocs < 10) // drop those with fewest procs
bysort at_npi year: ereplace todrop = max(todrop)
drop if todrop == 1

// take out year fixed effects (demean across years)
bysort year: egen yearmean = mean(outcome)
replace outcome = outcome - yearmean

// take out MD fixed effects (demean across MDs)
bysort at_npi: egen npimean = mean(outcome)
replace outcome = outcome - npimean

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
	
// Save graphs
graph save "$output/DDDecomposition_Low-Intensity-Intervention_NonParametric.gph", replace
graph export "$output/DDDecomposition_Low-Intensity-Intervention_NonParametric.png", as(png) replace
********************************************************************************
