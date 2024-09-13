/*******************************************************************************
* Title: ID Effect of TAVR Adoption on Inequities in PCI Access (Binned)
* Created by: Alex Hoagland
* Created on: 1/21/`3'22
* Last modified on: 2/26/`3'23 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: -- looks across ventiles of distribution (at CZ-yq) level 

* Key edits: 
*******************************************************************************/


***** 0. Clear old graphs
local allfiles: dir "$datadir/" files "inequities_binned_*"
foreach f of local allfiles { 
	rm "$datadir/`f'"
}

***** 1. Event Studies
cap graph drop * 

use "$datadir/IVCEventStudy_Base.dta", clear
// update adi if needed
capture confirm variable adi_9
if !_rc {
       drop riskvar_adi_9 // old version (with some minor descrepancies, so using new version just to be safe)
	rename adi_9 riskvar_adi_9
}
else {
	// pull in most recent ADI data so we know it's working properly 
	replace zip9 = zip5 if missing(zip9) // we have 5- or 9-digit zip codes for 99.82% of sample
	drop if missing(zip9)
	destring zip9, gen(zip_cd)
	merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_9digits.dta", keep(1 3) nogenerate keepusing(zip_cd adi_9)
		// a fair chunk of data missing here b/c we only have 5-digit zip codes for some 
	replace adi_9 = "" if strpos(adi_9, "PH") | strpos(adi_9, "Q") | strpos(adi_9, "N")
	destring adi_9, replace 
	merge m:1 zip_cd using "$mydir/2_Data/ADI/ADI_5digits.dta", keep(1 3) nogenerate keepusing(zip_cd adi_5)
	replace adi_9 = adi_5 if missing(adi_9) & !missing(adi_5)
	drop adi_5 zip_cd // now have ADI for 97.49% of data 
	save "$datadir/IVCEventStudy_Base.dta", replace
	drop riskvar_adi_9 // old version (with some minor descrepancies, so using new version just to be safe)
	rename adi_9 riskvar_adi_9
}

cap drop if missing(`2') 

local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local margin = "`2'" // which distribution are we looking at? 
	// options: riskvar_white, dual, adi, others? 
local figname = "LPDID-InequitiesBinned_`1'Treatments_`2'"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort CZID: ereplace t_adopt = min(t_adopt)

// use "`treatment'" to identify num_procs 
if ("`treatment'" == "high") { 
	gen outcome = (tavr == 1 | savr == 1)
	gen allprocs = 1 
}
else if ("`treatment'" == "low") { 
	gen outcome = (ptca == 1)
	gen allprocs = 1 
}
else if ("`treatment'" == "all") { 
	gen outcome = (tavr == 1 | savr == 1 | ptca == 1)
	gen allprocs = 1 
}

// use "`margin'" to generate outcome 
if ("`margin'" == "riskvar_dual_any" | "`margin'" == "riskvar_dual_full") { 
	gen group = `2'
	local lab1 "Dual" 
	local lab0 "Non-Dual"
}
if ("`margin'" == "riskvar_adi_5" | "`margin'" == "riskvar_adi_9") { 
	gen group = `2'*-1 // need to flip this since they are rankings
	local lab1 "More Disadvantaged" 
	local lab0 "Less Disadvantaged"
}
if ("`margin'" == "riskvar_white") { 
	gen group = (riskvar_black == 1 | riskvar_hisp == 1 | riskvar_other == 1)
	local lab1 = "Nonwhite" 
	local lab0 = "White"
}
bysort CZID: ereplace group = mean(group) // want this to be consistent across CZ's to separate them
gcollapse (sum) outcome allprocs (mean) t_adopt group, by(CZID yq) fast

// Require that a CZID have >10 procs in each quarter (deals with 0s as well)
fillin CZID yq
rename _fillin todrop
replace allprocs = 0 if missing(allprocs)
replace outcome = 0 if missing(outcome)
bysort CZID: ereplace todrop = mean(allprocs) 
drop if todrop < 5

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
qui gen period_yq = yq - t_adopt if treated == 1

// Loop across venitles of distribution of "group", collect treatment effect for each 
xtile deciles = group, n(`3')
gen post = (period_yq >= 0 & !missing(period_yq))
gen treatdummy = (treated == 1 & period_yq >= 0)
bys CZID: egen testt =  max(treated)
gen nevertreated = 1 - testt // include as controls in each regression
drop testt

forvalues g = 1/`3' { 
	di "***** REGRESSION FOR DECILE `g' *****"
	quietly {
		
	preserve
	keep if decile == `g' | nevertreated == 1
	qui sum outcome if period_yq < 0 | missing(period_yq)
	replace outcome = outcome / `r(mean)'
	
	lpdid outcome, unit(CZID) time(yq) treat(treatdummy) ///
		post_window(18) pre_window(12) only_pooled // pmd(max)
	
	matrix A = e(pooled_results)
	clear
	svmat A
	drop in 1
	rename A1 coef
	rename A2 stderr
	rename A3 t
	rename A4 pval
	rename A5 lb
	rename A6 ub 
	rename A7 n
	gen group = `g'
	save "$datadir/inequities_binned_`1'_`2'_`g'.dta", replace
	restore
}
}

use "$datadir/inequities_binned_`1'_`2'_1.dta", clear
forvalues g = 2/`3' { 
	append using "$datadir/inequities_binned_`1'_`2'_`g'"
}

label define edi 1 "Least Disadvantaged" `3' "Most Disadvantaged"
label val g edi

twoway (bar coef g, barw(0.8)) (rcap lb ub g, color(gs2)), legend(off) ///
	xtitle("CZ Quintile") ytitle("") xlabel(, valuelabel) ///
	yline(0, lcolor(red)) ytitle("Volume Effect, Relative to Pre-TAVR Mean") ///
	ysc(r(-0.5(0.25)0.25)) ylab(-0.5(0.25)0.25)
graph save "$output/`figname'", replace
graph export "$output/`figname'.pdf", replace as(pdf) 

// local b = .8
// twoway (scatter coef g, color(maroon%60))  ///
// 	(lowess coef g, bwidth(`b') color(maroon)) ///
// 	(lowess ub g, bwidth(`b') color(gs12)) ///
// 	(lowess lb g, bwidth(`b') color(gs12)) , ///
// 	graphregion(color(white)) yline(0, lcolor(red) lpattern(dash)) ///
// 	legend(off) xtitle("CZ Ventile") ylab(,angle(horizontal)) 
// graph save "$output/`figname'_Smoothed", replace
// graph export "$output/`figname'_Smoothed.pdf", replace as(pdf) 
********************************************************************************
