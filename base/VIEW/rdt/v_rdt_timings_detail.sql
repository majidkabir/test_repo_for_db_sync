SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [RDT].[V_RDT_TIMINGS_DETAIL] AS
select convert(char(10),starttime,120) TransDate ,InFunc , InStep , OutStep , 
sum(timetaken)/count(*) AVGTime, count(*) TotalTrans, Min(Timetaken) MinTime , Max(TimeTaken) MaxTime,
--sum(CASE WHEN TimeTaken <= 1000 THEN 1 ELSE 0 END) ms0_1000,
--sum(CASE WHEN TimeTaken > 1000 AND TimeTaken <= 2000 THEN 1 ELSE 0 END) ms1000_2000,
--sum(CASE WHEN TimeTaken > 2000 THEN 1 ELSE 0 END) ms2000_up
-- SOS#132168 - Add column MS2000_5000, MS5000_UP - Start
IsNULL( SUM( CASE WHEN TimeTaken <= 1000 THEN 1 ELSE 0 END), 0) MS0_1000,  
IsNULL( SUM( CASE WHEN TimeTaken > 1000 AND TimeTaken <= 2000 THEN 1 ELSE 0 END), 0) MS1000_2000,  
IsNULL( SUM( CASE WHEN TimeTaken > 2000 AND TimeTaken < 5000 THEN 1 ELSE 0 END), 0) MS2000_5000,  
IsNULL( SUM( CASE WHEN TimeTaken >= 5000 THEN 1 ELSE 0 END), 0) MS5000_UP   
-- SOS#132168 - Add column MS2000_5000, MS5000_UP - End
from rdt.rdttrace (nolock) --where convert(char(10),starttime,120) > '2005-07-31' 
group by convert(char(10),starttime,120), InFunc , instep , outstep




GO