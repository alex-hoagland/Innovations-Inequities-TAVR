/*******************************************************************************
* Title: Make a summary stat table for TAVR/SAVR use by providers over time
* Created by: Alex Hoagland
* Created on: 2/28/2022
* Last modified on: 3/15/2022
* Last modified by: 
* Purpose: 
* Notes: 

* Key edits: 
*******************************************************************************/


***** 1. Identify providers of valve replacement surgeries
use "$datadir/all_InpatientCardiology.dta", clear
gen tokeep = (tavr == 1 | savr == 1)
bysort bene_id surg_dt: ereplace tokeep = max(tokeep)
keep if tokeep == 1 // keep all surgical procedures for valve replacement
gen ivc = (group == 1)
gen cts = (group == 2) 
gcollapse (max) ivc cts tavr savr, by(bene_id file_year surg_dt) fast // collapse to surgery level 

gen allsurgeries = 1
gen fracivc_all = (ivc == 1)*100
gen fracivc_savr = (ivc == 1)*100 if savr == 1
gen fracivc_tavr = (ivc == 1)*100 if tavr == 1
gen fraccts_all = (cts == 1)*100
gen fraccts_savr = (cts == 1)*100 if savr == 1
gen fraccts_tavr = (cts == 1)*100 if tavr == 1

foreach v of var frac* { 
	replace `v' = 0 if missing(`v')
}
********************************************************************************


***** 2. Create table fragment (to paste in)
sort file_year
by file_year: egen sum_all = total(allsurgeries)
by file_year: egen sum_t = total(tavr)
by file_year: egen sum_s = total(savr)

estimates clear
clear matrix
by file_year: eststo: qui estpost sum sum_all sum_s  sum_t fraccts_all fraccts_savr fraccts_tavr fracivc_all fracivc_savr fracivc_tavr , listwise

esttab using "$output/ProviderSummary_TABFRAG.tex", cells("mean(fmt(%9.0fc %9.0fc %9.0fc 2))") label nodepvar nonumber noobs replace frag
matrix list r(coefs)
mat rename r(coefs) foo
esttab matrix(foo, transpose) using "$output/ProviderSummary_TABFRAG.tex", frag replace cells("mean(fmt(%9.0fc %9.0fc %9.0fc 2))") label nodepvar nonumber noobs 
********************************************************************************


***** 3. Create figure
gen allcats = 1 if savr == 1 & cts == 1
replace allcats = 2 if savr == 1 & ivc == 1
replace allcats = 3 if savr == 1 & missing(allcats)
replace allcats = 4 if tavr == 1 & cts == 1
replace allcats = 5 if tavr == 1 & ivc == 1 
replace allcats = 6 if tavr == 1 & missing(allcats)
label var allcats ""
label define mycatslab4 1 "SAVR CT" 2 "SAVR IVC" 3 "SAVR Other" 4 "TAVR CT" 5 "TAVR IVC" 6 "TAVR Other"
label values allcats mycatslab4

label define mytavrlab 0 "S" 1 "T"
label values tavr mytavrlab

catplot allcats, over(tavr, gap(5)) over(file_year, gap(30)) asyvars stack recast(bar) bargap(25) /// blabel(name, position(center) gap(3) color(white)) ///
	bar(1, fcolor(navy) lcolor(navy)) bar(2, fcolor(ebblue) lcolor(navy)) bar(3, fcolor(ebblue%20) lcolor(navy)) /// 
	bar(4, fcolor(dkgreen) lcolor(dkgreen)) bar(5, fcolor(midgreen) lcolor(dkgreen)) bar(6, fcolor(midgreen%20) lcolor(dkgreen)) /// 
	graphregion(color(white)) ytitle("") ylab(,angle(horizontal)) legend(rows(2)) b1title("")
graph save "$output/ProviderSummary_Figure", replace
graph export "$output/ProviderSummary_Figure.pdf", replace as(pdf)
********************************************************************************
