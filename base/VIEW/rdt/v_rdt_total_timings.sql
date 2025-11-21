SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [RDT].[V_RDT_TOTAL_TIMINGS] AS
select convert(char(10),starttime,120) TransDate, count(*) TotalTrans, sum(timetaken)/count(*) AVGTime
 from rdt.rdttrace (nolock)
group by convert(char(10),starttime,120)





GO