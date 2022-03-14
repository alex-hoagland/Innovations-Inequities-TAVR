import delimited C:\Users\alexh\Downloads\productDownload_2022-03-14T142150\ACSST5Y2010.S1901_data_with_overlays_2022-03-14T142129.csv, clear varnames(1)

keep geo_id s1901_c02_012e
drop in 1
gen year = 2010
replace geo_id = substr(geo_id, length(geo_id)-4,.)
save "fips_income_ACS_5Year", replace

forvalues y = 2011/2017 { 
	import delimited C:\Users\alexh\Downloads\productDownload_2022-03-14T142150\ACSST5Y`y'.S1901_data_with_overlays_2022-03-14T142129.csv, ///
		clear varnames(1)

	keep geo_id s1901_c02_012e
	drop in 1
	gen year = `y'
	replace geo_id = substr(geo_id, length(geo_id)-4,.)
	append using "fips_income_ACS_5Year.dta"
	save "fips_income_ACS_5Year", replace
}

rename s1901 medinc_hh
rename geo_id fips_string
compress
save, replace
