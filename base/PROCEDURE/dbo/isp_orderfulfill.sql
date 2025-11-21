SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_OrderFulfill                                   */
/* Creation Date: 8-Apr-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: LIM KAH HWEE                                             */
/*                                                                      */
/* Purpose: for email alert of Order Fulfillment                        */
/*                                                                      */
/*                                                                      */
/* Called By: VOLUMETRIC..isp_OrderFulfillment                          */
/*                                                                      */
/* PVCS Version: 1.3       -- Change this PVCS next version release     */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 1July2010    KHLim      improve coding standard                      */
/* 30Aug2010    KHLim      correct mistake of FullFill Range  (KHLim01) */
/*                                                                      */
/************************************************************************/
      
CREATE PROC [dbo].[isp_OrderFulfill]  
   @cCountryCode   NVARCHAR(5),     
   @cDBName NVARCHAR(20),
   @key NVARCHAR(20)
AS    
BEGIN    
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    
   DECLARE @cSQL   Nvarchar(MAX)

   IF @key = 'OrderKey'
   BEGIN       -- (KHLim01)
      SET @cSQL = 'SELECT N''' + @cCountryCode + ''' AS Country, MthDesc, 
          SUM(CASE WHEN FullFill <0.96 THEN 1 ELSE 0 END) AS [Below_96], 
          SUM(CASE WHEN FullFill Between 0.96 AND 0.969999 THEN 1 ELSE 0 END) AS [Between_96n97],
          SUM(CASE WHEN FullFill Between 0.97 AND 0.979999 THEN 1 ELSE 0 END) AS [Between_97n98],
          SUM(CASE WHEN FullFill Between 0.98 AND 0.989999 THEN 1 ELSE 0 END) AS [Between_98n99],
          SUM(CASE WHEN FullFill Between 0.99 AND 0.999999 THEN 1 ELSE 0 END) AS [Between_99],
          SUM(CASE WHEN FullFill = 1 THEN 1 ELSE 0 END) AS [Full_100],
          getdate() AS AddDate
      FROM (SELECT  1  AS Mth,  ''01-JAN'' AS MthDesc
            UNION ALL 
            SELECT  2  AS Mth,  ''02-FEB''
            UNION ALL
            SELECT  3  AS Mth,  ''03-MAR''
            UNION ALL
            SELECT  4  AS Mth,  ''04-APR''
            UNION ALL
            SELECT  5  AS Mth,  ''05-MAY''
            UNION ALL
            SELECT  6  AS Mth,  ''06-JUN''
            UNION ALL
            SELECT  7  AS Mth,  ''07-JUL''
            UNION ALL
            SELECT  8  AS Mth,  ''08-AUG''
            UNION ALL
            SELECT  9  AS Mth,  ''09-SEP''
            UNION ALL
            SELECT  10 AS Mth,  ''10-OCT''
            UNION ALL
            SELECT  11 AS Mth,  ''11-NOV''
            UNION ALL
            SELECT  12 AS Mth,  ''12-DEC'') AS T_Month 
      JOIN (
         SELECT o.OrderKey, Datepart(MONTH, m.EditDate) AS [Mth], 
            (SUM(CAST(o.ShippedQty AS bigint)) / ( SUM(CAST(o.OriginalQty AS bigint)) * 1.000)) AS FullFill 
         FROM DataMart.ODS.ORDERDETAIL o WITH (NOLOCK) 
            JOIN DATAMART.ODS.MBOLDEtail MD WITH (NOLOCK) on (o.ODS_Orders_Key = md.ODS_Orders_Key)
            JOIN DATAMART.ODS.MBOL M WITH (NOLOCK) on (m.ODS_MBOL_Key = md.ODS_MBOL_Key)
         WHERE o.STATUS = ''9'' AND o.OriginalQty > 0 
         AND DATEDIFF(month, m.EditDate, getdate()) < 3
         GROUP BY o.OrderKey, Datepart(MONTH, m.EditDate)
          ) AS Ord ON T_Month.Mth = Ord.Mth  
      GROUP BY MthDesc'
   END
   ELSE
   BEGIN    -- (KHLim01)
      SET @cSQL = 'SELECT N''' + @cCountryCode + ''' AS Country, MthDesc, 
          COUNT(DISTINCT (CASE WHEN FullFill <0.96 THEN storerkey END)) AS [Below_96], 
          COUNT(DISTINCT (CASE WHEN FullFill Between 0.96 AND 0.969999 THEN storerkey END)) AS [Between_96n97],
          COUNT(DISTINCT (CASE WHEN FullFill Between 0.97 AND 0.979999 THEN storerkey  END)) AS [Between_97n98],
          COUNT(DISTINCT (CASE WHEN FullFill Between 0.98 AND 0.989999 THEN storerkey  END)) AS [Between_98n99],
          COUNT(DISTINCT (CASE WHEN FullFill Between 0.99 AND 0.999999 THEN storerkey  END)) AS [Between_99],
          COUNT(DISTINCT (CASE WHEN FullFill = 1 THEN storerkey  END)) AS [Full_100],
          getdate() AS AddDate
      FROM (SELECT  1  AS Mth,  ''01-JAN'' AS MthDesc
            UNION ALL 
            SELECT  2  AS Mth,  ''02-FEB''
            UNION ALL
            SELECT  3  AS Mth,  ''03-MAR''
            UNION ALL
            SELECT  4  AS Mth,  ''04-APR''
            UNION ALL
            SELECT  5  AS Mth,  ''05-MAY''
            UNION ALL
            SELECT  6  AS Mth,  ''06-JUN''
            UNION ALL
            SELECT  7  AS Mth,  ''07-JUL''
            UNION ALL
            SELECT  8  AS Mth,  ''08-AUG''
            UNION ALL
            SELECT  9  AS Mth,  ''09-SEP''
            UNION ALL
            SELECT  10 AS Mth,  ''10-OCT''
            UNION ALL
            SELECT  11 AS Mth,  ''11-NOV''
            UNION ALL
            SELECT  12 AS Mth,  ''12-DEC'') AS T_Month 
      JOIN (
         SELECT o.OrderKey, StorerKey, Datepart(MONTH, m.EditDate) AS [Mth], 
            (SUM(CAST(o.ShippedQty AS bigint)) / ( SUM(CAST(o.OriginalQty AS bigint)) * 1.000)) AS FullFill 
         FROM DataMart.ODS.ORDERDETAIL o WITH (NOLOCK) 
            JOIN DATAMART.ODS.MBOLDEtail MD WITH (NOLOCK) on (o.ODS_Orders_Key = md.ODS_Orders_Key)
            JOIN DATAMART.ODS.MBOL M WITH (NOLOCK) on (m.ODS_MBOL_Key = md.ODS_MBOL_Key)
         WHERE o.STATUS = ''9'' AND o.OriginalQty > 0 
         AND DATEDIFF(month, m.EditDate, getdate()) < 3
         GROUP BY o.OrderKey, StorerKey, Datepart(MONTH, m.EditDate)
          ) AS Ord ON T_Month.Mth = Ord.Mth  
      GROUP BY MthDesc'
   END

   --PRINT @cSQL
   EXEC sp_ExecuteSql @cSQL OUTPUT

END /* main procedure */

GO