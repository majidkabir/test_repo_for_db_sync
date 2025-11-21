SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_OrderAgeing                                    */
/* Creation Date: 11-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: LIM KAH HWEE                                             */
/*                                                                      */
/* Purpose: for email alert of Order Ageing                             */
/*                                                                      */
/*                                                                      */
/* Called By: VOLUMETRIC..isp_OrderAgeingEmail                          */
/*                                                                      */
/* PVCS Version: 1.1       -- Change this PVCS next version release     */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 1July2010    KHLim      improve coding standard                      */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_OrderAgeing]  
   @cCountryCode  NVARCHAR(5),     
   @cDBName       NVARCHAR(20),
   @key           NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @cSQL   Nvarchar(MAX)

   SET @cSQL = 'SELECT N''' + @cCountryCode + ''' AS Country, Ord.Dy, 
      SUM(CASE WHEN status = 0 THEN Ord.Cnt ELSE 0 END) AS Unprocessed,
      SUM(CASE WHEN status = 1 THEN Ord.Cnt ELSE 0 END) AS PartiallyAllocated,
      SUM(CASE WHEN status = 2 THEN Ord.Cnt ELSE 0 END) AS Allocated,
      SUM(CASE WHEN status = 3 THEN Ord.Cnt ELSE 0 END) AS PickInProcess,
      SUM(CASE WHEN status = 5 THEN Ord.Cnt ELSE 0 END) AS Picked
      
   FROM (SELECT  0  AS Dy
         UNION ALL 
         SELECT  1  AS Dy
         UNION ALL 
         SELECT  2  AS Dy
         UNION ALL
         SELECT  3  AS Dy
         UNION ALL
         SELECT  4  AS Dy
         UNION ALL
         SELECT  5  AS Dy
         UNION ALL
         SELECT  6  AS Dy
         UNION ALL
         SELECT  7  AS Dy) AS T_Day 
   JOIN (
   SELECT COUNT(DISTINCT ' + @key + ') AS Cnt,    
   (CASE WHEN DATEDIFF(day, o.EditDate, getdate()) < 7
      THEN DATEDIFF(day, o.EditDate, getdate())
      ELSE 7 END) AS Dy, status
   FROM ORDERS o WITH (NOLOCK) 
      WHERE o.STATUS < ''9''
      GROUP BY 
   (CASE WHEN DATEDIFF(day, o.EditDate, getdate()) < 7
      THEN DATEDIFF(day, o.EditDate, getdate())
      ELSE 7 END), status
       ) AS Ord ON T_Day.Dy = Ord.Dy  
   GROUP BY Ord.Dy'

   PRINT @cSQL
   EXEC sp_ExecuteSql @cSQL OUTPUT


END /* main procedure */

GO