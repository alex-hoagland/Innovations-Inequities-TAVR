/*******************************************************************************
* Title: Make intensive margin graphs (that combine across all risk measures)
* Created by: Alex Hoagland
* Created on: 1/21/2023
* Last modified on: 2/14/2023 
* Last modified by: 
* Purpose: Assess whether TAVR changed risk thresholds for other procedures, 
	across multiple measures of risk

* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Event Study Graphs
local treatment = "`1'" // high = high-intensity (valve replacements), low = low-intensity (PCI/stents), all = both
local figname = "EventStudy_CZLevel_`1'Treatments_CombinedIntensiveMargin"

// combine data
use "$datadir/figuredata_intensivemargin_`treatment'_predrisk_30.dta", clear
drop var N r2 stderr
rename (coef lb ub ) (coef_30 lb_30 ub_30)
merge 1:1 y using "$datadir/figuredata_intensivemargin_`treatment'_predrisk_60.dta", nogenerate
drop var N r2 stderr
rename (coef lb ub ) (coef_60 lb_60 ub_60)
merge 1:1 y using "$datadir/figuredata_intensivemargin_`treatment'_predrisk_90.dta", nogenerate
drop var N r2 stderr
rename (coef lb ub ) (coef_90 lb_90 ub_90)

reshape long coef_ lb_ ub_, i(y) j(risk)
replace y = y-.25 if risk == 30 
replace y = y+.25 if risk == 90

	// local for where to put the text label
	qui sum y 
	local mymin = round(r(min),1) 
	local mymax = round(r(max) , 1)
	local myx = `mymax' * 0.05
	qui sum ub
	local myy = r(max) * 0.85

sort y 
twoway (scatter coef y if risk == 30, color(maroon)) /// 
	(scatter coef y if risk == 60, color(navy)) /// 
	(scatter coef y if risk == 90, color(green)) /// 
	(rcap lb ub y, color(gs10)), ///
	graphregion(color(white)) legend(off) ///
	xline(-.25, lpattern(dash)) yline(0, lcolor(red)) ///
	xsc(r(`mymin'(4)`mymax')) xlab(`mymin'(4)`mymax') xtitle("Quarters Around TAVR Adoption") /// 
	ylab(,angle(horizontal))  
		
// Save graphs
graph save "$output/`figname'.gph", replace
graph export "$output/`figname'.pdf", as(pdf) replace
********************************************************************************
