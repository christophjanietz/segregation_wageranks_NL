/*=============================================================================* 
* Pay Quintile Analysis - Glass Ceiling in Dutch Organizations
*==============================================================================*
 	Project: Beyond Boardroom 
	Author: Christoph Janietz (c.janietz@rug.nl)
	Last update: 22-02-2025
* ---------------------------------------------------------------------------- *

	INDEX: 
		0.  SETTINGS 
		1.  PREPARING INDIVIDUAL-LEVEL WAGE DATA
		2.  DECILE SHARES (NOT WEIGHTED)
		3.  DECILE SHARES (WEIGHTED BY FIRM SIZE)
		4.  COMBINE FILES
		
* Short description of output:
*
* - Create files holding information on within-organization pay quintile shares
*   of men and women.
*
* NIDIO files used:
* - spolis_month_2006_2023
* - gba_rin_2023
* - abr_ogbe_register_2006_2023
* - bdk_be_2007_2023

* --------------------------------------------------------------------------- */
* 0. SETTINGS 
* ---------------------------------------------------------------------------- * 

*** Settings - run config file
	global sdir 		"H:/Syntax"			// Syntax Working Directory
	do 					"${sdir}/config"
	
	global wdir			"H:/Projects/CJ/segregation/sex"
	global adir			"H:/Projects/CJ/segregation/sex/analysis/q_shares"
	
* --------------------------------------------------------------------------- */
* 1. PREPARING INDIVIDUAL-LEVEL WAGE DATA
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		//  Starting point: monthly SPOLIS for 2011/2023; excluding directors, interns, 
		//  and wsw-ers; restricted to mainjobs
		spolisselect, data(month) start(`year') end(`year') jobtype(2) mainjob(1)
	
		// Merge GBA data (administrative sex categories)
		sort rinpersoon
		merge 1:1 rinpersoon using "${dGBA}/gba_rin_2023", ///
			keep(match) keepusing(rin_sex) nogen 
		
		// Merge ABR data (industry) 
		sort year beid
		merge m:1 year beid using "${dABR}/abr_ogbe_register_2006_2023", ///
			keep(match) keepusing(be_industry) nogen
		
		* Reduce variable set 
		keep rinpersoon beid sbasisloon_month sreguliereuren_month rin_sex ///
			be_industry
		
		// Construct hourly wage measure
		gen hwage = sbasisloon_month/sreguliereuren_month 
		drop sbasisloon_month sreguliereuren_month
		* Bottom-code negative wages
		replace hwage = 1 if hwage<1
		* Remove missings
		drop if hwage==.
		
		// Drop extraterritorial organizations
		drop if be_industry==21
		
		// Restrict to large organizations (N>=50)
		orgsizeselect, id(beid) min(50) n_org(1) select(1)
	
		// Dummy man / woman
		gen woman = 0
		replace woman=1 if rin_sex==2
		gen man = 0
		replace man=1 if rin_sex==1
		
		// Generate within-firm wage quantiles
		gquantiles withinq = hwage, xtile nquantiles(5) by(beid)
		
		// Save dataset
		save "${wdir}/data/q/wages_`year'", replace
	}
	*
	
* --------------------------------------------------------------------------- */
* 2. QUINTILE SHARES (NOT WEIGHTED)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/q/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${dABR}/abr_ogbe_register_2006_2023", ///
			keepusing(og_sector_alt be_gksbs vep_legalform og_ownership be_lbe) ///
			nogen keep(match)
			
		merge m:1 beid year using "${dBDK}/bdk_be_2007_2023", ///
			keepusing(be_founding) nogen keep(master match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
			
		// Prepare LBE & Founding
		replace be_lbe = 2 if be_lbe>=2 & be_lbe<=4
		replace be_lbe = 3 if be_lbe>=5 & be_lbe!=.
		gen lbe = be_lbe
		
		gen foundy = year(be_founding)
		gen cohort = 0
		replace cohort=1 if foundy<1960
		replace cohort=2 if foundy>=1960 & foundy<1970
		replace cohort=3 if foundy>=1970 & foundy<1980
		replace cohort=4 if foundy>=1980 & foundy<1990
		replace cohort=5 if foundy>=1990 & foundy<2000
		replace cohort=6 if foundy>=2000 & foundy<2010
		replace cohort=7 if foundy>=2010 & foundy<2020
		replace cohort=8 if foundy>=2020 & foundy<=2023
		
		drop be_lbe foundy
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			gegen tot_woman = mean(woman)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=woman (median) tot_woman=tot_woman ///
				n_org=n_org (sum) n = woman, by(withinq)
			drop if withinq==.
			gen sex="Women"
			save "${adir}/withinq_women", replace
		restore
		preserve
			gegen tot_woman = mean(woman)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=man (median) tot_woman=tot_woman ///
				n_org=n_org (sum) n = man, by(withinq)
			drop if withinq==.
			gen sex="Men"
			append using "${adir}/withinq_women" 
			erase "${adir}/withinq_women.dta"
			sort withinq sex
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
	
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				gegen tot_woman = mean(woman) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if be_industry==`ind', by(withinq)
				gen sex="Women"
				gen subpop=`ind'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				gegen tot_woman = mean(woman) if be_industry==`ind'
				gunique beid if be_industry==`ind'
				gen n_org=r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if be_industry==`ind', by(withinq)
				gen sex="Men"
				gen subpop=`ind'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_19", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8" ///
			"${adir}/withinq_m_9" "${adir}/withinq_m_10" ///
			"${adir}/withinq_m_11" "${adir}/withinq_m_12" ///
			"${adir}/withinq_m_13" "${adir}/withinq_m_14" ///
			"${adir}/withinq_m_15" "${adir}/withinq_m_16" ///
			"${adir}/withinq_m_17" "${adir}/withinq_m_18" ///
			"${adir}/withinq_m_19"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing" ///
				2"Industry: Mining and quarrying" ///
				3"Industry: Manufacturing" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities" ///
				6"Industry: Construction" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles" ///
				8"Industry: Transportation and storage" ///
				9"Industry: Accomodation and food service activities" ///
				10"Industry: Information and communication" ///
				11"Industry: Financial institutions" ///
				12"Industry: Renting, buying, and selling of real estate" ///
				13"Industry: Consultancy, research and other specialised business services" ///
				14"Industry: Renting and leasing of tangible goods and other business support services" ///
				15"Industry: Public administration, public services, and compulsory social security" ///
				16"Industry: Education" ///
				17"Industry: Human health and social work activities" ///
				18"Industry: Culture, sports, and recreation" ///
				19"Industry: Other service activities", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_w_`ind'.dta"
				erase "${adir}/withinq_m_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_woman = mean(woman) if og_sector_alt==`sect'
				gunique beid if og_sector_alt==`sect'
				gen n_org=r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if og_sector_alt==`sect', by(withinq)
				gen sex="Women"
				gen subpop=`sect'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				gegen tot_woman = mean(woman) if og_sector_alt==`sect'
				gunique beid if og_sector_alt==`sect'
				gen n_org=r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if og_sector_alt==`sect', by(withinq)
				gen sex="Men"
				gen subpop=`sect'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_15", replace
			append using "${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_m_11" ///
			"${adir}/withinq_m_12" "${adir}/withinq_m_13" ///
			"${adir}/withinq_m_15"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def sect_lbl 11"Sector: Non-financial company" ///
				12"Sector: Financial organization" 13"Sector: Governmental organization" ///
				15"Sector: Non-governmental non-profit organization", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_w_`sect'.dta"
				erase "${adir}/withinq_m_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 60 71 72 81 82 91 92 93 {
			preserve
				gegen tot_woman = mean(woman) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if be_gksbs==`gksbs', by(withinq)
				gen sex="Women"
				gen subpop=`gksbs'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 60 71 72 81 82 91 92 93 {
			preserve
				gegen tot_woman = mean(woman) if be_gksbs==`gksbs'
				gunique beid if be_gksbs==`gksbs'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if be_gksbs==`gksbs', by(withinq)
				gen sex="Men"
				gen subpop=`gksbs'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_93", replace
			append using "${adir}/withinq_w_60" "${adir}/withinq_w_71" ///
			"${adir}/withinq_w_72" "${adir}/withinq_w_81" ///
			"${adir}/withinq_w_82" "${adir}/withinq_w_91" ///
			"${adir}/withinq_w_92" ///
			"${adir}/withinq_m_60" "${adir}/withinq_m_71" ///
			"${adir}/withinq_m_72" "${adir}/withinq_m_81" ///
			"${adir}/withinq_m_82" "${adir}/withinq_m_91" ///
			"${adir}/withinq_m_92" "${adir}/withinq_m_93"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def gksbs_lbl 60 "Size: 50-99 employees" 71 "Size: 100-149 employees" ///
				72 "Size: 150-199 employees" 81 "Size: 200-249 employees" 82 "Size: 250-499 employees" ///
				91 "Size: 500-999 employees" 92 "Size: 1000-1999 employees" 93 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 60 71 72 81 82 91 92 93 {
				erase "${adir}/withinq_w_`gksbs'.dta"
				erase "${adir}/withinq_m_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				gegen tot_woman = mean(woman) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if vep_legalform==`legal', by(withinq)
				gen sex="Women"
				gen subpop=`legal'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				gegen tot_woman = mean(woman) if vep_legalform==`legal'
				gunique beid if vep_legalform==`legal'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if vep_legalform==`legal', by(withinq)
				gen sex="Men"
				gen subpop=`legal'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_900", replace
			append using "${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" ///
			"${adir}/withinq_m_43" "${adir}/withinq_m_57" ///
			"${adir}/withinq_m_74" "${adir}/withinq_m_900"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Verschillende publiekrechtelijke instellingen", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_w_`legal'.dta"
				erase "${adir}/withinq_m_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				gegen tot_woman = mean(woman) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if og_ownership==`owner', by(withinq)
				gen sex="Women"
				gen subpop=`owner'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				gegen tot_woman = mean(woman) if og_ownership==`owner'
				gunique beid if og_ownership==`owner'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if og_ownership==`owner', by(withinq)
				gen sex="Men"
				gen subpop=`owner'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_2" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def owner_lbl 2 "Ownership: Domestic" 3 "Ownership: Foreign", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_w_`owner'.dta"
				erase "${adir}/withinq_m_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_woman = mean(woman) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if cao==`cao', by(withinq)
				gen sex="Women"
				gen subpop=`cao'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				gegen tot_woman = mean(woman) if cao==`cao'
				gunique beid if cao==`cao'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if cao==`cao', by(withinq)
				gen sex="Men"
				gen subpop=`cao'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_2", replace
			append using "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_m_0" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cao_lbl 0 "CAO: No collective agreement " 1 "CAO: Sectoral agreement" ///
				2 "CAO: Firm-level agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_w_`cao'.dta"
				erase "${adir}/withinq_m_`cao'.dta"	
			}
			*
		restore
		
		**************
		* By number of LBEs
		**************
		foreach lbe of num 1 2 3 {
			preserve
				gegen tot_woman = mean(woman) if lbe==`lbe'
				gunique beid if lbe==`lbe'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if lbe==`lbe', by(withinq)
				gen sex="Women"
				gen subpop=`lbe'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`lbe'", replace
			restore		
		}
		*
		foreach lbe of num 1 2 3 {
			preserve
				gegen tot_woman = mean(woman) if lbe==`lbe'
				gunique beid if lbe==`lbe'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if lbe==`lbe', by(withinq)
				gen sex="Men"
				gen subpop=`lbe'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`lbe'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_1" ///
			"${adir}/withinq_w_2" "${adir}/withinq_m_1" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def lbe_lbl 1 "Nr. of establishments: 1" 2 "Nr. of establishments: 2-4" ///
				3 "Nr. of establishments: 5+", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_lbe_`year'", replace
	
			foreach lbe of num 1 2 3 {
				erase "${adir}/withinq_w_`lbe'.dta"
				erase "${adir}/withinq_m_`lbe'.dta"	
			}
			*
		restore
		
		**************
		* By founding cohort
		**************
		if `year'<=2019 {
		foreach cohort of num 1/7 {
			preserve
				gegen tot_woman = mean(woman) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if cohort==`cohort', by(withinq)
				gen sex="Women"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/7 {
			preserve
				gegen tot_woman = mean(woman) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if cohort==`cohort', by(withinq)
				gen sex="Men"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_7", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/7 {
				erase "${adir}/withinq_w_`cohort'.dta"
				erase "${adir}/withinq_m_`cohort'.dta"	
			}
			*
		restore
		}
		else {
		foreach cohort of num 1/8 {
			preserve
				gegen tot_woman = mean(woman) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=woman (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = woman if cohort==`cohort', by(withinq)
				gen sex="Women"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/8 {
			preserve
				gegen tot_woman = mean(woman) if cohort==`cohort'
				gunique beid if cohort==`cohort'
				gen n_org = r(J)
				collapse (mean) share=man (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = man if cohort==`cohort', by(withinq)
				gen sex="Men"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_8", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop cohort_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/8 {
				erase "${adir}/withinq_w_`cohort'.dta"
				erase "${adir}/withinq_m_`cohort'.dta"	
			}
			*
		restore
		}
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withinq)
			save  "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withinq_`var'", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
* --------------------------------------------------------------------------- */
* 3. QUINTILE SHARES (WEIGHTED BY FIRM SIZE)
* ---------------------------------------------------------------------------- *

	foreach year of num 2011/2023 {
		use "${wdir}/data/q/wages_`year'", replace
		
		gen year = `year'
		sort beid year
		
		merge m:1 beid year using "${dABR}/abr_ogbe_register_2006_2023", ///
			keepusing(og_sector_alt be_gksbs vep_legalform og_ownership be_lbe) ///
			nogen keep(match)
			
		merge m:1 beid year using "${dBDK}/bdk_be_2007_2023", ///
			keepusing(be_founding) nogen keep(master match)
			
		merge m:1 beid year using "${wdir}/data/cao_status", ///
			keepusing(cao) nogen keep(master match)
			
		// Prepare LBE & Founding
		replace be_lbe = 2 if be_lbe>=2 & be_lbe<=4
		replace be_lbe = 3 if be_lbe>=5 & be_lbe!=.
		gen lbe = be_lbe
		
		gen foundy = year(be_founding)
		gen cohort = 0
		replace cohort=1 if foundy<1960
		replace cohort=2 if foundy>=1960 & foundy<1970
		replace cohort=3 if foundy>=1970 & foundy<1980
		replace cohort=4 if foundy>=1980 & foundy<1990
		replace cohort=5 if foundy>=1990 & foundy<2000
		replace cohort=6 if foundy>=2000 & foundy<2010
		replace cohort=7 if foundy>=2010 & foundy<2020
		replace cohort=8 if foundy>=2020 & foundy<=2023
		
		drop be_lbe foundy
	
		// Collapse into summary datasets
		
		**********************
		* Overall labor market
		**********************
		preserve
			collapse (mean) share_be=woman (sum) n = woman, by(beid withinq)
			gegen tot_woman = mean(share_be)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) tot_woman=tot_woman ///
				n_org=n_org (sum) n = n, by(withinq)
			gen sex="Women"
			save "${adir}/withinq_women", replace
		restore
		preserve
			collapse (mean) share_be=man (sum) n = man, by(beid withinq)
			gunique beid
			gen n_org=r(J)
			collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
			drop if withinq==.
			gen sex="Men"
			append using "${adir}/withinq_women"
			egen tw = max(tot_woman)
			drop tot_woman
			rename tw tot_woman
			erase "${adir}/withinq_women.dta"
			sort withinq sex
			gen pc = round((share*100),.01) 
			save "${adir}/withinq_all_`year'", replace
		restore
		
		*************
		* By industry
		*************
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if be_industry==`ind', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`ind'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`ind'", replace
			restore		
		}
		*
		foreach ind of num 1/19 {
			preserve
				collapse (mean) share_be=man (sum) n = man if be_industry==`ind', by(beid withinq)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`ind'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`ind'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_19", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" "${adir}/withinq_w_8" ///
			"${adir}/withinq_w_9" "${adir}/withinq_w_10" ///
			"${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_w_14" ///
			"${adir}/withinq_w_15" "${adir}/withinq_w_16" ///
			"${adir}/withinq_w_17" "${adir}/withinq_w_18" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8" ///
			"${adir}/withinq_m_9" "${adir}/withinq_m_10" ///
			"${adir}/withinq_m_11" "${adir}/withinq_m_12" ///
			"${adir}/withinq_m_13" "${adir}/withinq_m_14" ///
			"${adir}/withinq_m_15" "${adir}/withinq_m_16" ///
			"${adir}/withinq_m_17" "${adir}/withinq_m_18" ///
			"${adir}/withinq_m_19"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def ind_lbl 1"Industry: Agriculture, forestry, and fishing" ///
				2"Industry: Mining and quarrying" ///
				3"Industry: Manufacturing" ///
				4"Industry: Electricity, gas, steam, and air conditioning supply" ///
				5"Industry: Water supply; sewerage, waste management and remidiation activities" ///
				6"Industry: Construction" ///
				7"Industry: Wholesale and retail trade; repair of motorvehicles and motorcycles" ///
				8"Industry: Transportation and storage" ///
				9"Industry: Accomodation and food service activities" ///
				10"Industry: Information and communication" ///
				11"Industry: Financial institutions" ///
				12"Industry: Renting, buying, and selling of real estate" ///
				13"Industry: Consultancy, research and other specialised business services" ///
				14"Industry: Renting and leasing of tangible goods and other business support services" ///
				15"Industry: Public administration, public services, and compulsory social security" ///
				16"Industry: Education" ///
				17"Industry: Human health and social work activities" ///
				18"Industry: Culture, sports, and recreation" ///
				19"Industry: Other service activities", replace
			lab val subpop ind_lbl
	
			save "${adir}/withinq_industry_`year'", replace
	
			foreach ind of num 1/19 {
				erase "${adir}/withinq_w_`ind'.dta"
				erase "${adir}/withinq_m_`ind'.dta"	
			}
			*
		restore
		
		***********
		* By sector
		***********
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if og_sector_alt==`sect', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`sect'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`sect'", replace
			restore		
		}
		*
		foreach sect of num 11 12 13 15 {
			preserve
				collapse (mean) share_be=man (sum) n = man if og_sector_alt==`sect', by(beid withinq)
				gunique beid
				gen n_org=r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`sect'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`sect'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_15", replace
			append using "${adir}/withinq_w_11" "${adir}/withinq_w_12" ///
			"${adir}/withinq_w_13" "${adir}/withinq_m_11" ///
			"${adir}/withinq_m_12" "${adir}/withinq_m_13" ///
			"${adir}/withinq_m_15"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def sect_lbl 11"Sector: Non-financial company" ///
				12"Sector: Financial organization" 13"Sector: Governmental organization" ///
				15"Sector: Non-governmental non-profit organization", replace
			lab val subpop sect_lbl
	
			save "${adir}/withinq_sector_`year'", replace
	
			foreach sect of num 11 12 13 15 {
				erase "${adir}/withinq_w_`sect'.dta"
				erase "${adir}/withinq_m_`sect'.dta"	
			}
			*
		restore
		
		*********
		* By size
		*********
		foreach gksbs of num 60 71 72 81 82 91 92 93 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if be_gksbs==`gksbs', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`gksbs'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`gksbs'", replace
			restore		
		}
		*
		foreach gksbs of num 60 71 72 81 82 91 92 93 {
			preserve
				collapse (mean) share_be=man (sum) n = man if be_gksbs==`gksbs', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`gksbs'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`gksbs'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_93", replace
			append using "${adir}/withinq_w_60" "${adir}/withinq_w_71" ///
			"${adir}/withinq_w_72" "${adir}/withinq_w_81" ///
			"${adir}/withinq_w_82" "${adir}/withinq_w_91" ///
			"${adir}/withinq_w_92" ///
			"${adir}/withinq_m_60" "${adir}/withinq_m_71" ///
			"${adir}/withinq_m_72" "${adir}/withinq_m_81" ///
			"${adir}/withinq_m_82" "${adir}/withinq_m_91" ///
			"${adir}/withinq_m_92" "${adir}/withinq_m_93"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def gksbs_lbl 60 "Size: 50-99 employees" 71 "Size: 100-149 employees" ///
				72 "Size: 150-199 employees" 81 "Size: 200-249 employees" 82 "Size: 250-499 employees" ///
				91 "Size: 500-999 employees" 92 "Size: 1000-1999 employees" 93 "Size: 2000+ employees", replace
			lab val subpop gksbs_lbl 
	
			save "${adir}/withinq_gksbs_`year'", replace
	
			foreach gksbs of num 60 71 72 81 82 91 92 93 {
				erase "${adir}/withinq_w_`gksbs'.dta"
				erase "${adir}/withinq_m_`gksbs'.dta"	
			}
			*
		restore
		
		***************
		* By legal form
		***************
		foreach legal of num 43 57 74 900 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if vep_legalform==`legal', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`legal'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`legal'", replace
			restore		
		}
		*
		foreach legal of num 43 57 74 900  {
			preserve
				collapse (mean) share_be=man (sum) n = man if vep_legalform==`legal', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`legal'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`legal'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_900", replace
			append using "${adir}/withinq_w_43" "${adir}/withinq_w_57" ///
			"${adir}/withinq_w_74" ///
			"${adir}/withinq_m_43" "${adir}/withinq_m_57" ///
			"${adir}/withinq_m_74" "${adir}/withinq_m_900"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def legal_lbl 43 "Legal type: Besloten Vennootschap (bv)" ///
				57 "Legal type: Naamloze Vennootschap (nv)" 74 "Legal type: Stichting" ///
				900 "Legal type: Verschillende publiekrechtelijke instellingen", replace
			lab val subpop legal_lbl 
	
			save "${adir}/withinq_legal_`year'", replace
	
			foreach legal of num 43 57 74 900 {
				erase "${adir}/withinq_w_`legal'.dta"
				erase "${adir}/withinq_m_`legal'.dta"	
			}
			*
		restore
		
		**************
		* By Ownership
		**************
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if og_ownership==`owner', by(beid withinq)
				gegen tot_woman = mean(share_be) 
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`owner'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`owner'", replace
			restore		
		}
		*
		foreach owner of num 2 3 {
			preserve
				collapse (mean) share_be=man (sum) n = man if og_ownership==`owner', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`owner'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`owner'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_2" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3" 
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def owner_lbl 2 "Ownership: Domestic" 3 "Ownership: Foreign", replace
			lab val subpop owner_lbl 
	
			save "${adir}/withinq_owner_`year'", replace
	
			foreach owner of num 2 3 {
				erase "${adir}/withinq_w_`owner'.dta"
				erase "${adir}/withinq_m_`owner'.dta"	
			}
			*
		restore
		
		**************
		* By Cao status
		**************
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if cao==`cao', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`cao'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cao'", replace
			restore		
		}
		*
		foreach cao of num 0 1 2 {
			preserve
				collapse (mean) share_be=man (sum) n = man if cao==`cao', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`cao'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cao'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_2", replace
			append using "${adir}/withinq_w_0" ///
			"${adir}/withinq_w_1" "${adir}/withinq_m_0" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cao_lbl 0 "CAO: No collective agreement " 1 "CAO: Sectoral agreement" ///
				2 "CAO: Firm-level agreement", replace
			lab val subpop cao_lbl 
	
			save "${adir}/withinq_cao_`year'", replace
	
			foreach cao of num 0 1 2 {
				erase "${adir}/withinq_w_`cao'.dta"
				erase "${adir}/withinq_m_`cao'.dta"	
			}
			*
		restore
		
		**************
		* By number of LBEs
		**************
		foreach lbe of num 1 2 3 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if lbe==`lbe', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`lbe'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`lbe'", replace
			restore		
		}
		*
		foreach lbe of num 1 2 3 {
			preserve
				collapse (mean) share_be=man (sum) n = man if lbe==`lbe', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`lbe'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`lbe'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_3", replace
			append using "${adir}/withinq_w_1" ///
			"${adir}/withinq_w_2" "${adir}/withinq_m_1" ///
			"${adir}/withinq_m_2" "${adir}/withinq_m_3"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def lbe_lbl 1 "Nr. of establishments: 1" 2 "Nr. of establishments: 2-4" ///
				3 "Nr. of establishments: 5+", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_lbe_`year'", replace
	
			foreach lbe of num 1 2 3 {
				erase "${adir}/withinq_w_`lbe'.dta"
				erase "${adir}/withinq_m_`lbe'.dta"	
			}
			*
		restore
		
		**************
		* By founding cohort
		**************
		if `year'<=2019 {
		foreach cohort of num 1/7 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if cohort==`cohort', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/7 {
			preserve
				collapse (mean) share_be=man (sum) n = man if cohort==`cohort', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_7", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/7 {
				erase "${adir}/withinq_w_`cohort'.dta"
				erase "${adir}/withinq_m_`cohort'.dta"	
			}
			*
		restore
		}
		else {
		foreach cohort of num 1/8 {
			preserve
				collapse (mean) share_be=woman (sum) n = woman if cohort==`cohort', by(beid withinq)
				gegen tot_woman = mean(share_be)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) tot_woman=tot_woman ///
					n_org=n_org (sum) n = n, by(withinq)
				gen sex="Women"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_w_`cohort'", replace
			restore		
		}
		*
		foreach cohort of num 1/8 {
			preserve
				collapse (mean) share_be=man (sum) n = man if cohort==`cohort', by(beid withinq)
				gunique beid
				gen n_org = r(J)
				collapse (mean) share=share_be (median) n_org=n_org (sum) n = n, by(withinq)
				gen sex="Men"
				gen subpop=`cohort'
				order subpop, before(withinq)
				save "${adir}/withinq_m_`cohort'", replace
			restore		
		}
		*
	
		preserve
			use "${adir}/withinq_w_8", replace
			append using "${adir}/withinq_w_1" "${adir}/withinq_w_2" ///
			"${adir}/withinq_w_3" "${adir}/withinq_w_4" ///
			"${adir}/withinq_w_5" "${adir}/withinq_w_6" ///
			"${adir}/withinq_w_7" ///
			"${adir}/withinq_m_1" "${adir}/withinq_m_2" ///
			"${adir}/withinq_m_3" "${adir}/withinq_m_4" ///
			"${adir}/withinq_m_5" "${adir}/withinq_m_6" ///
			"${adir}/withinq_m_7" "${adir}/withinq_m_8"
	
			gen pc = round((share*100),.01)
			
			drop if withinq==.
			sort subpop withinq sex
	
			lab def cohort_lbl 1 "Founding cohort: -1960" 2 "Founding cohort: 1960s" ///
				3 "Founding cohort: 1970s" 4 "Founding cohort: 1980s" ///
				5 "Founding cohort: 1990s" 6 "Founding cohort: 2000s" ///
				7 "Founding cohort: 2010s" 8 "Founding cohort: 2020s", replace
			lab val subpop lbe_lbl 
	
			save "${adir}/withinq_cohort_`year'", replace
	
			foreach cohort of num 1/8 {
				erase "${adir}/withinq_w_`cohort'.dta"
				erase "${adir}/withinq_m_`cohort'.dta"	
			}
			*
		restore
		}
		
	}
	*
	
	* Generate year variable
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		foreach year of num 2011/2023 {
			use "${adir}/withinq_`var'_`year'", replace
			gen year = `year'
			order year, before(withinq)
			save  "${adir}/withinq_`var'_`year'", replace
		}
		*
	}
	*
	
	* Append yearly datasets
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withinq_`var'_2011", replace
		
		append using "${adir}/withinq_`var'_2012" ///
			"${adir}/withinq_`var'_2013" ///
			"${adir}/withinq_`var'_2014" ///
			"${adir}/withinq_`var'_2015" ///
			"${adir}/withinq_`var'_2016" ///
			"${adir}/withinq_`var'_2017" ///
			"${adir}/withinq_`var'_2018" ///
			"${adir}/withinq_`var'_2019" ///
			"${adir}/withinq_`var'_2020" ///
			"${adir}/withinq_`var'_2021" ///
			"${adir}/withinq_`var'_2022" ///
			"${adir}/withinq_`var'_2023"
			
		save "${adir}/withinq_`var'_weighted", replace
		
		foreach year of num 2011/2023 {
			erase "${adir}/withinq_`var'_`year'.dta"
		}
		*
	}
	*
	
	* Fill missing of total average share of woman across quintiles
	foreach var in industry sector gksbs legal owner cao lbe cohort {
		use "${adir}/withinq_`var'_weighted", replace
		
		egen tw = max(tot_woman), by(subpop year)
		replace tot_woman = tw if tot_woman==.
		drop tw 
		
		save "${adir}/withinq_`var'_weighted", replace
	}
	*
	
* --------------------------------------------------------------------------- */
* 4. COMBINE FILES
* ---------------------------------------------------------------------------- *

	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withinq_`var'", replace
		
		gen wgt = "No"
		order wgt, before(year)
		capture order wgt, before(subpop)
		
		append using "${adir}/withinq_`var'_weighted"
		
		replace wgt = "Yes" if wgt==""
		
		save "${adir}/withinq_`var'", replace
		
		erase "${adir}/withinq_`var'_weighted.dta"
	
	}
	*
	
	* Generate percentage variable for tot_woman
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withinq_`var'", replace
		gen pc_tw = round((tot_woman*100),.01)
		
		save "${adir}/withinq_`var'", replace
	}
	*
	
	* Save subpop variable as string
	foreach var in industry sector gksbs legal owner cao lbe cohort {
		
		use "${adir}/withinq_`var'", replace
		decode subpop, gen(_subpop)
		drop subpop
		rename _subpop subpop
		
		save "${adir}/withinq_`var'", replace
	}
	*
	
	*Combine in one file
	use "${adir}/withinq_all", replace
	generate subpop = "Total population of larger organizations"
	
	append using "${adir}/withinq_industry" ///
		"${adir}/withinq_sector" ///
		"${adir}/withinq_gksbs" ///
		"${adir}/withinq_legal" ///
		"${adir}/withinq_owner" ///
		"${adir}/withinq_cao" ///
		"${adir}/withinq_lbe" ///
		"${adir}/withinq_cohort"
		
	generate format = "Wage quintiles"	
		
	order subpop, after(year)
	order format, before(wgt)
	
	save "${adir}/withinq_sex", replace
		
	export excel using "${adir}/withinq_sex", firstrow(variables) replace
	
	foreach var in all industry sector gksbs legal owner cao lbe cohort {
		erase "${adir}/withinq_`var'.dta"
	}
	*
		