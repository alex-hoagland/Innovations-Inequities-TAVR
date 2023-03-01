use "$datadir/EnrolleeEventStudy_Base.dta", clear
gen file_year = riskvar_year 
keep bene_id file_year
duplicates drop

// Income data based on qualifying subsidies/eligibility
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/2010/bsfd2010.dta, ///
		keep(1 3) nogenerate keepusing(cstshr* rdsind* dual*) 
	forvalues y = 2011/2016 { 
		merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/`y'/bsfd`y'.dta, ///
			keep(1 3 4 5) nogenerate keepusing(cstshr* rdsind* dual*) update replace
	}
	destring dual_mo, replace // need to update data types
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfd/2017/bsfd2017.dta, ///
		keep(1 3 4 5) nogenerate keepusing(cstshr* rdsind* dual*) update replace
		
	*** Generate low-income variables
	// Use based on LIS at time of surgery
	// for those without surgery, need to update this to be any time over year? 

	gen lis_eligible = 0 
	gen lis_enrol = 0 
	gen lis_premsub = 0 
	gen lis_copaysub = 0 

	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace lis_eligible = 1 if inlist(cstshr`mi', "01", "02", "03") 
		replace lis_enrol = 1 if inlist(cstshr`mi', "04", "05", "06", "07", "08") 
		replace lis_premsub = 100 if inlist(cstshr`mi', "01", "02", "03", "04", "05") 
		replace lis_premsub = 75 if cstshr`mi' == "06" & lis_premsub != 100
		replace lis_premsub = 50 if cstshr`mi' == "07" & lis_premsub != 100 & lis_premsub != 75
		replace lis_premsub = 25 if cstshr`mi' == "08" & !inlist(lis_premsub,50,75,100)
		replace lis_copaysub = 100 if cstshr`mi' == "01" 
		replace lis_copaysub = 85 if inlist(cstshr`mi', "02", "05", "06", "07", "08") & lis_copaysub != 100
		replace lis_copaysub = 15 if inlist(cstshr`mi', "04", "03") & lis_copaysub != 85 & lis_copaysub != 15 
		
	}

	gen dual_mdcd = 0 
	gen dual_lowinc_mdcr = 0
	gen dual_other = 0 

	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace dual_mdcd = 1 if inlist(dual_`mi', "02", "04") 
		replace dual_lowinc = 1 if inlist(dual_`mi', "01", "03") 
		replace dual_other = 1 if inlist(dual_`mi', "05", "06", "08") 
	}

	gen rds_ind = 0
	forvalues m = 1/12 { 
		local mi = string(`m', "%02.0f")
		
		replace rds_ind = 1 if rdsind`mi' == "Y" 
	}

	rename lis_* lowinc_lis_*
	rename dual_mdcd lowinc_dual_mdcd
	rename dual_lowinc lowinc_dual_mdcr
	rename dual_other lowinc_dual_other
	rename rds_ind lowinc_rds_ind

	drop cstshr* rdsind* dual* 
	
rename file_year riskvar_year
merge 1:1 bene_id riskvar_year using "$datadir/EnrolleeEventStudy_Base.dta", nogenerate

save "$datadir/EnrolleeEventStudy_Base.dta", replace
