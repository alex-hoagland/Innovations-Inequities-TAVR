// note: these files do not run with TAVR_Master.do because they need to be run on a separate server

cd /project/sdoh-mod/IBNR/Alex_Code/1.IdentifyEvents/TAVR_PullMarketscanPrices
use TAVRPrices-Admissions.dta, clear 

// within DRGs for SAVR and TAVR, need to split
gen savr = 0
replace savr = 1 if inlist(pproc, "3521", "3522") // ICD-9
replace savr = 1 if substr(pproc,1,5) == "02RF0" // ICD-10

gen tavr = 0
replace tavr = 1 if inlist(pproc, "3505", "3506")
replace tavr = 1 if substr(pproc,1,5) == "02RF3" // ICD-10
replace tavr = 1 if pproc == "X2A5312" // extra ICD-10
	
// Inflation adjust prices  
do Inflation.do "tot*"
foreach v of var tot* {
	replace `v' = 250000 if `v' > 250000
}
duplicates drop

// calculate average payments by drg-year, except for TAVR and SAVR
drop if tavr == 1 & savr == 1
replace drg = . if tavr == 1 | savr == 1
replace drg = 216 if inrange(drg, 216,221) // cardiac cath
replace drg = 231 if inrange(drg, 231,236) // bypass
replace drg = 246 if inrange(drg, 246,249) // stent
replace drg = 266 if inrange(drg, 266,269) | drg == 319 | drg == 320 // aortic procs
replace drg = 250 if inlist(drg, 250,251,273,274) // pci
gcollapse (mean) totpay (sd) sd=totpay (count) n=totpay, by(drg tavr savr year) fast
gen lb = totpay-1.96*sd/sqrt(n)
gen ub = totpay + 1.96*sd/sqrt(n)

set scheme cblind1
drop if year == 2006 // weird year?
twoway (connect totpay year if savr == 1) (connect totpay year if tavr == 1) ///
	(connect totpay year if drg == 216) (connect totpay year if drg == 231) ///
	(connect totpay year if drg == 246) (connect totpay year if drg == 250) ///
	(rcap lb ub year if drg == 250, color(gs10)) ///
	(rcap lb ub year if drg == 216, color(gs10)) (rcap lb ub year if drg == 231, color(gs10)) ///
	(rcap lb ub year if drg == 246, color(gs10)) ///
	(rcap lb ub year if savr == 1, color(gs10)) (rcap lb ub year if tavr == 1, color(gs10)), ///
	xtitle("Year") ytitle("") ///
	legend(order(1 "SAVR" 2 "TAVR" 3 "Cardiac Cath" 4 "Bypass" 5 "Stent" 6 "PCI" )) ///
	xline(2011.9, lpattern(dash) lcolor(black)) ///
	xsc(r(2007(1)2018)) xlab(2007(1)2018) ylab(,format(%9.0fc))
graph save "CommercialPrices.gph", replace
graph export "CommercialPrices.pdf", as(pdf) replace

// now detrend 
replace drg = 0 if tavr == 1 
replace drg = -1 if savr == 1
xtset drg year
reg totpay year
predict detrend, resid

twoway (connect detrend year if savr == 1) (connect detrend year if tavr == 1) ///
	(connect detrend year if drg == 216) (connect detrend year if drg == 231) ///
	(connect detrend year if drg == 246) (connect detrend year if drg == 250), ///
	xtitle("Year") ytitle("") ///
	legend(order(1 "SAVR" 2 "TAVR" 3 "Cardiac Cath" 4 "Bypass" 5 "Stent" 6 "PCI" )) ///
	xline(2011.9, lpattern(dash) lcolor(black)) ///
	xsc(r(2007(1)2018)) xlab(2007(1)2018) ylab(,format(%9.0fc))
graph save "CommercialPrices_Detrended.gph", replace
graph export "CommercialPrices_Detrended.pdf", as(pdf) replace
********************************************************************************/
