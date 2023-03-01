/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Inequities in PCI Access (Binned)
* Created by: Alex Hoagland
* Created on: 1/21/2022
* Last modified on: 2/26/2023 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: -- combines graphs from earlier chunk

* Key edits: 
*******************************************************************************/


***** 1. Load Data
// Income
use "$datadir/inequities_binned_`1'_riskvar_dual_any_1.dta", clear
forvalues g = 2/20 { 
	append using "$datadir/inequities_binned_`1'_riskvar_dual_any_`g'"
}
gen rv = 1

// Race
forvalues g = 1/20 { 
	append using "$datadir/inequities_binned_`1'_riskvar_white_`g'"
}
replace rv = 2 if missing(rv) 

// ADI
forvalues g = 1/20 { 
	append using "$datadir/inequities_binned_`1'_riskvar_adi_5_`g'"
}
replace rv = 3 if missing(rv) 

replace g = g - .1 if rv == 2
replace g = g + .1 if rv == 3

drop if rv == 1
twoway (scatter coe g if r == 2, color(navy)) ///
	(scatter c g if r == 3, color(green)) ///
	(rcap lb ub g, color(gs12)) , ///
	graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
	legend(rows(1) order(1 "Minority Race" 2 "Area Disadvantage Index")) ///
	xtitle("CZ Ventile (increasing to the right)") xsc(r(1(1)20)) xlab(1(1)20) ///
	ysc(r(-125(25)0)) ylab(-125(25)0,angle(horizontal))
graph save "$output/InequitiesCombined_`1'", replace
graph export "$output/InequitiesCombined_`1'.pdf", replace as(pdf) 
********************************************************************************
