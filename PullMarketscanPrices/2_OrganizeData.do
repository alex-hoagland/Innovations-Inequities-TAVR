// note: these files do not run with TAVR_Master.do because they need to be run on a separate server


// This is for the admission-level data
// aggregate files from 1.TAVRPricesAdmissions_YYYY.sas
cd /project/sdoh-mod/IBNR/Alex_Code/1.IdentifyEvents/TAVR_PullMarketscanPrices
use TAVRPrices-Admissions_2006.dta, clear
forvalues i = 2007/2018 { 
	append using TAVRPrices-Admissions_`i'.dta
}
rename * , lower 

// filter relevant DRGs
keep if inrange(drg, 216,221) | /// cardiac cath
		inrange(drg, 231,236) | /// bypass
		inrange(drg, 246,249) | /// stent
		inrange(drg, 250,251) | /// PCI1
		inrange(drg, 273,274) | /// PCI2 
		inrange(drg, 266, 267) | /// SAVR and TAVR 
		inlist(drg, 268, 269, 319, 320) // other

		
compress
save TAVRPrices-Admissions.dta, replace

// forvalues i = 2006/2018 { 
// 	rm TAVRPrices_`i'.dta
// }

// // This is for the service-level data
// // aggregate files from 1.TAVRPricesServices_YYYY.sas
// cd /project/sdoh-mod/IBNR/Alex_Code/1.IdentifyEvents/TAVR_PullMarketscanPrices
// use TAVRPrices_2006.dta, clear
// forvalues i = 2007/2018 { 
// 	append using TAVRPrices_`i'.dta
// }
//
// // filter relevant DRGs
// keep if inrange(drg, 216,221) | /// cardiac cath
// 		inrange(drg, 231,236) | /// bypass
// 		inrange(drg, 246,249) | /// stent
// 		inrange(drg, 250,251) | /// PCI1
// 		inrange(drg, 273,274) | /// PCI2 
// 		inrange(drg, 266, 267) | /// SAVR and TAVR 
// 		inlist(drg, 268, 269, 319, 320) // other
//
//		
// compress
// rename * , lower 
// save TAVRPrices-Services.dta, replace
//
// // forvalues i = 2006/2018 { 
// // 	rm TAVRPrices_`i'.dta
// // }
