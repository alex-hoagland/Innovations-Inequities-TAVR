***** 0. Import list of procedures
preserve
import excel "$datadir/ID_PTCA.xlsx", ///
	sheet("Sheet1") firstrow clear 
drop if Diagnostic == "Yes"
levelsof Code, local(allcodes)
restore

cap gen ptca2 = 0 
forvalues i = 1/10 { // first 10 procedures
	di "PROCEDURE `i' of 10" 
	foreach code of local allcodes { 
		replace ptca2 =1 if icd_prcdr_cd`i' == "`code'"
	}
} 








