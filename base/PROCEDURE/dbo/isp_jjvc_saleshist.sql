SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Stored Procedure: isp_JJVC_SalesHist            			            */
/* Creation Date: 01 Dec 2006                                           */
/* Copyright: IDS                                                       */
/* Written by: James                                                    */
/*                                                                      */
/* Purpose: IDSTW - JJVC Sales History File Export(SOS#63106)           */
/*                                                                      */
/* Called By: Report                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 01 Dec 2006  James         Created                                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_JJVC_SalesHist] (
   @c_Storerkey         NVARCHAR(15)
   ,@c_StartDate        DateTime
   ,@c_EndDate          DateTime  
)
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TempJJVCSalesHist') IS NOT NULL 
   BEGIN
      DROP TABLE #TempJJVCSalesHist
   END
   
   CREATE TABLE [#TempJJVCSalesHist] (
                [LineText] [varchar] (4096) NULL  
)

   --header record   
   INSERT INTO #TempJJVCSalesHist (LineText) 
   VALUES
   ('1TWNSH' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2) +  -- Month
   '/' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2) +  -- Day
   '/' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(YEAR, GETDATE()))), 2) +  -- Year
   '  ' +   
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2) +  -- Hour
   ':' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2) +  -- Minute
   ':' + 
--    RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(SECOND, GETDATE()))), 2)   -- Second
   '00'
   )
   
   --detail record
   INSERT INTO #TempJJVCSalesHist (LineText) 
   SELECT '2' +
   CONVERT(NCHAR(11), ISNULL(SKU.RetailSku, '')) + 
   SPACE(4) + 
   'ALL' + 
   'TWN' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(MONTH, @c_StartDate))), 2) +  -- Month
   '/' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(DAY, @c_StartDate))), 2) +  -- Day
   '/' + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEPART(YEAR, @c_StartDate))), 2) +  -- Year
   SPACE(2) + 
   RIGHT(dbo.fnc_RTrim('0' + CONVERT(CHAR, DATEDIFF(day, @c_StartDate, @c_EndDate) + 1)), 2) + 
   'D' + 
   SPACE(1) + 
   '1'  + 
--   RIGHT(dbo.fnc_RTrim(REPLICATE(0, 8) + CONVERT(CHAR, SUM(OD.SHIPPEDQTY) * PACK.ISWHQTY9 )), 8) OtherUnit1
  RIGHT(dbo.fnc_RTrim(REPLICATE(0, 8) + CONVERT(CHAR, SUM(OD.SHIPPEDQTY) * PACK.OtherUnit1 )), 8) 
   FROM ORDERS O (NOLOCK) JOIN 
   ORDERDETAIL OD (NOLOCK) 
   ON O.ORDERKEY = OD.ORDERKEY 
   JOIN SKU SKU (NOLOCK) 
   ON OD.SKU = SKU.SKU 
   JOIN PACK PACK (NOLOCK) 
   ON SKU.PACKKEY = PACK.PACKKEY 
   WHERE O.STORERKEY = @c_StorerKey 
   AND OD.EDITDATE BETWEEN @c_StartDate AND @c_EndDate
   GROUP BY SKU.RETAILSKU, PACK.OtherUnit1--PACK.ISWHQTY9

   --trailer record   
   INSERT INTO #TempJJVCSalesHist (LineText) 
   SELECT '3TWNSH' + 
   RIGHT(dbo.fnc_RTrim(REPLICATE(0, 5) + CONVERT(CHAR, COUNT(1) + 1)), 5) 
   FROM #TempJJVCSalesHist (NOLOCK) 


   SELECT * FROM #TempJJVCSalesHist 
END


GO