
--Submitted by : Sukhmanjit Kaur

use NHS_Tariff_Project
go

/*
***************************************************************************************************************
STEPS: 

1. Contains Input table: input table with HRG codes (per spell) created before the stored procedure is made.
2. STORED PROCEDURE containes: 
	2.1: creates a view where all the data is extracted from the Input table
	2.2: case statements are used to aplly conditions and determine correct tariff.
	2.3: The tariff per HES case is outputed as  HES_HRG_output table

***************************************************************************************************************
Explanation for my use of Spell duration rather than Episode duration.

The offical NHS National Tariff Payment System pdf states: 

	1. 'We use spellbased HRGs as the currency for admitted patient care and some outpatient
	procedures.' 

	2. 'Spell-based HRG4+ is the currency design for admitted patient care covering
	the period from admission to discharge.'

Taking into consideration the documents and the domain knowledge the tariff is worked out based on teh spell duration.
so spell duration in our data is split across numerous episode and over days,month and even years. 
The output of spell duration is quite high so when compared to trim day to charge extra bed cost then the tariff could look ordinary.

Stored Procedure is designed to work for the real HRG data (tested on sample grouper data and correct tariffs produced using spell duration)

**Tariffs are only calculated for spells which end in 2017/18 and 2018/19 because that is the only Tariff HRG data we have.

***************************************************************************************************************
*/

-----------------------------------------------------------------------------------------
--Creating the input table for the Stored procedure
-----------------------------------------------------------------------------------------
drop table input_hes_data
create table input_HES_data
(
	spellID int identity primary key 
	,spell int 
	,[HRG code] varchar(100)
	,hesid varchar(100)
	,admimeth varchar(100)
	,classpat int
	,spellstart date
	,spellend date
	,spelldur int
)
insert into input_HES_data(spell, [HRG code], hesid, admimeth,classpat,spellstart, spellend, spelldur)
(
select distinct
	spell
	,[HRG_code]
	,FIRST_VALUE(hesid) over(partition by hesid order  by cast(episode as int))
	,FIRST_VALUE([admimeth]) over(partition by hesid order  by cast(episode as int)) admimeth --admission method. elective or non-elective
	,cast(FIRST_VALUE(classpat) over(partition by hesid order  by cast(episode as int)) as int) classpat	
	,convert(date,FIRST_VALUE(epistart) over(partition by hesid order  by cast(episode as int)), 103) epistart	--spell start date
	,convert(date, LAST_VALUE(epiend) over(partition by hesid order by cast(episode as int) rows between unbounded preceding and unbounded following), 103)	epiend --spell end date
	
	,DATEDIFF(dd,convert(date, FIRST_VALUE(epistart) over(partition by hesid order  by cast(episode as int)), 103), convert(date, LAST_VALUE(epiend) over(partition by hesid order by cast(episode as int)
 rows between unbounded preceding and unbounded following), 103)) --spell duration

from  [stage].[HES_data]
)


--****************************************************************************************

--Droping the Stored procedure, view and output table 
if OBJECT_ID('sp_HRG_HES_Tariff') is not  null 
drop proc sp_HRG_HES_Tariff
go
if OBJECT_ID('HES_HRG_output_view') is not null
drop view [dbo].[HES_HRG_output_view]
go
if OBJECT_ID('HES_HRG_output') is not null 
drop table [dbo].[HES_HRG_output]
go

------------------------------------------------------------------------------------------------------------------------
--STORED PROCEDURE
------------------------------------------------------------------------------------------------------------------------

create proc  sp_HRG_HES_Tariff 
as 
set nocount on;

go
--view takes into the values from the HES input table, compares them to HRG National Tariff Database depending on the conditions.

;create view HES_HRG_output_view 
as 
select 
	 h.hesid
	,h.[HRG code]	
	--,t1718.[HRG code]
	,h.spellstart
	,h.spellend
	,h.spelldur
	,h.admimeth
	,h.classpat
	,case 
	 when h.spellend between cast('2017-04-01' as date) and cast('2018-03-31' as date) then --tariff only applied to patients whose spell ended on 2017/18 or 2018/19.
		(case
			when h.admimeth in ('11', '12' ,'13') then --elective
			(
				case 
					when h.spelldur = 0 then isnull(t1718.[Combined day case / ordinary elective spell tariff (£)], t1718.[Day case spell tariff (£)])
					when cast(h.spelldur as float) <= t1718. [Ordinary elective long stay trim point (days)] then isnull(t1718.[Combined day case / ordinary elective spell tariff (£)],t1718.[Ordinary elective spell tariff (£)])
					when cast(h.spelldur as float) > t1718. [Ordinary elective long stay trim point (days)] then t1718.[Combined day case / ordinary elective spell tariff (£)] + (h.spelldur- t1718.[Ordinary elective long stay trim point (days)])*t1718.[Per day long stay payment (for days exceeding trim point) (£)]
				end

			)
			when h.[admimeth] in ('99' , '21', '2A','2B','25','28') then -- when admimeth is non-elective
			(
				case
				 when cast(h.spelldur as int) < 2 and  t1718.[Reduced short stay emergency tariff _applicable?] in ('yes') then t1718.[Reduced short stay emergency tariff (£)] 
				 when cast(h.spelldur as float) <= t1718.[Non-elective long stay trim point (days)] then t1718.[Non-elective spell tariff (£)]
				 when cast(h.spelldur as float) > t1718.[Non-elective long stay trim point (days)] then t1718.[Non-elective spell tariff (£)] + (h.spelldur - t1718.[Non-elective long stay trim point (days)])*t1718.[Per day long stay payment (for days exceeding trim point) (£)]
				 end  
			)
	
		end) 
	when h.spellend between cast('2018-04-01' as date) and cast('2019-04-01' as date) then
			(case
			when h.admimeth in ('11', '12' ,'13') then --elective
			(
				case 
					when h.spelldur = 0 then isnull(t1819.[Combined day case / ordinary elective spell tariff (£)], t1819.[Day case spell tariff (£)])
					when cast(h.spelldur as float) <= t1819. [Ordinary elective long stay trim point (days)] then isnull(t1819.[Combined day case / ordinary elective spell tariff (£)],t1819.[Ordinary elective spell tariff (£)])
					when cast(h.spelldur as float) > t1819. [Ordinary elective long stay trim point (days)] then t1819.[Combined day case / ordinary elective spell tariff (£)] + (h.spelldur- t1819.[Ordinary elective long stay trim point (days)])*t1819.[Per day long stay payment (for days exceeding trim point) (£)]
				end

			)
			when h.[admimeth] in ('99' , '21', '2A','2B','25','28') then -- when admimeth is non-elective
			(
				case
				 when cast(h.spelldur as int) < 2 and  t1819.[Reduced short stay emergency tariff _applicable?] in ('yes') then t1819.[Reduced short stay emergency tariff (£)] 
				 when cast(h.spelldur as float) <= t1819.[Non-elective long stay trim point (days)] then t1819.[Non-elective spell tariff (£)]
				 when cast(h.spelldur as float) > t1819.[Non-elective long stay trim point (days)] then t1819.[Non-elective spell tariff (£)] + (h.spelldur - t1819.[Non-elective long stay trim point (days)])*t1819.[Per day long stay payment (for days exceeding trim point) (£)]
				 end  
			)
			end) 

	else null 
	end as [tariff(£)] 

from [stage].[Tariff_APC 17_18] t1718
inner join [dbo].[input_HES_data] h
on h.[HRG code] = t1718.[HRG code]
inner join [stage].[Tariff_APC 18_19] t1819
on h.[HRG code] = t1819.[HRG code]
go

--writting all  the tariff data to an output table 
create table HES_HRG_output
(
	hesid varchar(100)
	,[HRG code] varchar(100)
	,spellstart date
	,spellend date
	,spelldur int
	,admimeth varchar(100)
	,classpat int
	,[Tariff(£)] float 
)
insert into HES_HRG_output(hesid, [HRG code], spellstart, spellend, spelldur, admimeth, classpat,[Tariff(£)])
(select * from HES_HRG_output_view
)

go

--*********************************************************************************************************************
--END OF PROCEDURE
--*********************************************************************************************************************

--executing the procedure
exec sp_HRG_HES_Tariff 

--output table
--select * from HES_HRG_output

