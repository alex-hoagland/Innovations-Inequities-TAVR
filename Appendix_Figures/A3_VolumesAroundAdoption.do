/*******************************************************************************
* Title: Robustness check: do volumes change just before adoption, especially for late adopters? 
* Created by: Alex Hoagland
* Created on: 7/5/2024
* Last modified on: 2024 
* Last modified by: 
* Purpose: Assess whether TAVR crowded out volumes of other procs 

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Studies
use "$datadir/IVCEventStudy_Base.dta", clear
local figname = "Robustness_VolumeAroundAdoption"

*** Identify treatment (first adoption of tavr) 
cap drop t_adopt
gen t_adopt = yq if tavr == 1
bysort orgnpinm CZID: egen org_adopt = min(t_adopt)
bysort CZID: ereplace t_adopt = min(t_adopt)
gen first_adopter = (org_adopt==t_adopt) 
bys orgnpinm CZID: ereplace first_adopter = max(first_adopter) // roughly 17% adopted at the start
gen adopt_gap = org_adopt - t_adopt
gen never_adopt = missing(adopt_gap) // roughly 41% of organization NPIs don't adopt in a given CZ

gcollapse (sum) tavr savr ptca2 (mean) *_adopt* adopt_gap, by(CZID orgnpinm yq) fast 
gen all = tavr + savr + ptca2

// Generate relative time variables
qui gen treated = (!missing(t_adopt))
sum treated
qui gen period_yq = yq -  t_adopt if treated == 1

// descriptive means by adoption status 
gen group = (first_adopter == 1)
replace group = 2 if never_adopt == 0 & group == 0 
gen n = 1
gcollapse (sum) n (mean) tavr savr ptca2 all (sd) sd_t=tavr sd_s=savr sd_p=ptca2 sd_a=all, by(period_yq group) fast
gen lb_t = tavr-1.96*sd_t/sqrt(n)
gen ub_t = tavr+1.96*sd_t/sqrt(n)
gen lb_s = savr-1.96*sd_s/sqrt(n)
gen ub_s = savr+1.96*sd_s/sqrt(n)
gen lb_p = ptca2-1.96*sd_p/sqrt(n)
gen ub_p = ptca2+1.96*sd_p/sqrt(n)
gen lb_a = all-1.96*sd_a/sqrt(n)
gen ub_a = all+1.96*sd_a/sqrt(n)
keep if abs(period_yq) <= 15

twoway (connect tavr period_yq if group == 1) (rcap lb_t ub_t period_yq if group == 1, color(gs9)) ///
	(connect tavr period_yq if group == 2) (rcap lb_t ub_t period_yq if group == 2, color(gs9)), /// 	(connect tavr period_yq if group == 0) (rcap lb_t ub_t period_yq if group == 0, color(gs9)), ///
	xline(-0.25, lcolor(red) lpattern(dash)) xtitle("Quarters Around Organization TAVR Adoption") ytitle("") ///
	xsc(r(-12(4)12)) xlab(-12(4)12) legend(order(1 "First adopters" 3 "Late adopters")) //  5 "Never adopters"))
graph save "$output/`figname'_TAVR.gph", replace
graph export "$output/`figname'_TAVR.pdf", as(pdf) replace

twoway (connect savr period_yq if group == 1) (rcap lb_s ub_s period_yq if group == 1, color(gs9)) ///
	(connect savr period_yq if group == 2) (rcap lb_s ub_s period_yq if group == 2, color(gs9)), ///	(connect savr period_yq if group == 0) (rcap lb_s ub_s period_yq if group == 0, color(gs9)), ///
	xline(-0.25, lcolor(red) lpattern(dash)) xtitle("Quarters Around Organization TAVR Adoption") ytitle("") ///
	xsc(r(-12(4)12)) xlab(-12(4)12) legend(order(1 "First adopters" 3 "Late adopters")) // 5 "Never adopters"))
graph save "$output/`figname'_SAVR.gph", replace
graph export "$output/`figname'_SAVR.pdf", as(pdf) replace

twoway (connect ptca period_yq if group == 1) (rcap lb_p ub_p period_yq if group == 1, color(gs9)) ///
	(connect ptca period_yq if group == 2) (rcap lb_p ub_p period_yq if group == 2, color(gs9)),  ///	(connect ptca period_yq if group == 0) (rcap lb_p ub_p period_yq if group == 0, color(gs9)), ///
	xline(-0.25, lcolor(red) lpattern(dash)) xtitle("Quarters Around Organization TAVR Adoption") ytitle("") ///
	xsc(r(-12(4)12)) xlab(-12(4)12) legend(order(1 "First adopters" 3 "Late adopters")) // 5 "Never adopters"))
graph save "$output/`figname'_ptca.gph", replace
graph export "$output/`figname'_ptca.pdf", as(pdf) replace

twoway (connect all period_yq if group == 1) (rcap lb_a ub_a period_yq if group == 1, color(gs9)) ///
	(connect all period_yq if group == 2) (rcap lb_a ub_a period_yq if group == 2, color(gs9)), /// 	(connect all period_yq if group == 0) (rcap lb_a ub_a period_yq if group == 0, color(gs9)), ///
	xline(-0.25, lcolor(red) lpattern(dash)) xtitle("Quarters Around Organization TAVR Adoption") ytitle("") ///
	xsc(r(-12(4)12)) xlab(-12(4)12) legend(order(1 "First adopters" 3 "Late adopters")) // 5 "Never adopters"))
graph save "$output/`figname'_all.gph", replace
graph export "$output/`figname'_all.pdf", as(pdf) replace
********************************************************************************
