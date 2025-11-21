SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Store Procedure: isp_jp_BSJ_caseID_generator	https://jiralfl.atlassian.net/browse/WMS-22736	*/
/* Creation Date: 11-11-2022												*/
/* Copyright:                                                               */
/* Written by: JohnChuah													*/
/*                                                                          */
/* Purpose:			*/
/*					*/
/*                                                                          */
/* Called By: Jreport                                                       */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 1.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date				Author    Ver.  Purposes                                */
/* 06-July-2023		YangSong  1.0	Deploy in JPWMS PROD					*/
/****************************************************************************/

-- Test: EXEC BI.isp_jp_PS_caseID_generator 1,100,'M','PS'

CREATE     PROC [BI].[isp_jp_BSJ_caseID_generator]  
		@prefix nvarchar(2)
		,@TYPE nvarchar (1)
		, @number int
		, @count int  
AS
BEGIN                  
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
@caseid nvarchar(14),
@cnt int

set @cnt = @number
set @caseid = ''

IF OBJECT_ID('tempdb..#CASEID','u') IS NOT NULL  DROP TABLE #CASEID;
create table #CASEID (
[TYPE] nvarchar(10)
, CASEID nvarchar(14) 
)

BEGIN

WHILE @cnt <= @count
BEGIN

  IF @cnt < 10  
   begin
     set @caseid = @prefix + @TYPE + FORMAT(ABS(datediff(DAY,getdate(),convert(date,'2021-1-1'))), '0000') + '000' + convert(nvarchar, @cnt)
   end

  ELSE IF @cnt < 100 
   begin
     set @caseid = @prefix + @TYPE + FORMAT(ABS(datediff(DAY,getdate(),convert(date,'2021-1-1'))), '0000') + '00' + convert(nvarchar, @cnt)
   end

  ELSE IF @cnt < 1000
   begin
     set @caseid = @prefix + @TYPE + FORMAT(ABS(datediff(DAY,getdate(),convert(date,'2021-1-1'))), '0000') + '0' + convert(nvarchar, @cnt)
   end

   ELSE
   begin
     set @caseid = @prefix + @TYPE + FORMAT(ABS(datediff(DAY,getdate(),convert(date,'2021-1-1'))), '0000') +  convert(nvarchar, @cnt)
   end
  
  insert into #CASEID ([TYPE], CASEID) values ('CASEID', @caseid)

  SET @cnt = @cnt + 1
END

select TYPE, CASEID 
from #CASEID
order by 2

END

END

GRANT EXEC ON BI.isp_jp_BSJ_caseID_generator TO [JReportRole]

GO