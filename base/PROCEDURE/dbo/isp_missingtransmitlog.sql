SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_MissingTransmitLog                             */        
/* Creation Date: 23-Apr-2010                                           */        
/* Copyright: IDS                                                       */        
/* Written by: KHLim                                             */        
/*                                                                      */        
/* Purpose: send auto email alert                                       */        
/*                                                                      */        
/*                                                                      */        
/* Called By: BEJ - Alert Missing Transmitlog3                          */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author     Purposes                                     */        
/* 03-May-2013  Shong      Exclude SOStatus=MASTER, split order for     */        
/*                         C4 Malaysia (SHONG01)                        */
/************************************************************************/        
        
CREATE PROC [dbo].[isp_MissingTransmitLog] 
(
    @cCountry NVARCHAR(100)
   ,@recipientList NVARCHAR(MAX)
   ,@ccRecipientList NVARCHAR(MAX)
)  
AS        
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @textHTML      NVARCHAR(MAX)
          ,@emailSubject  NVARCHAR(MAX)
          ,@issueCount    INT
          ,@cDate         NVARCHAR(20)  
   
   SET @cDate = CONVERT(CHAR(10) ,GETDATE() ,103)     
   SET @emailSubject = 'Alert: ' + @@serverName + ' - Missing Transmitlog3  ' + 
       @cDate + ' - '  
   
   CREATE TABLE #temp
   (
      TableName     NVARCHAR(60)
      ,Storerkey    NVARCHAR(20)
      ,DocumentKey  NVARCHAR(10)
   )  
   
   INSERT INTO #temp
     (
       TableName
      ,Storerkey
      ,DocumentKey
     )
   SELECT SC.ConfigKey AS TableName
         ,R.StorerKey AS Storerkey
         ,R.ReceiptKey AS DocumentKey
   FROM   Receipt R(NOLOCK)
          JOIN StorerConfig SC(NOLOCK)
               ON  (
                       SC.ConfigKey = 'RCPTLOG'
                   AND SC.Svalue = '1'
                   AND SC.Storerkey = R.StorerKey
                   )
          LEFT JOIN Transmitlog3 T(NOLOCK)
               ON  (
                       T.Key1 = R.ReceiptKey
                   AND T.tablename = 'RCPTLOG'
                   AND T.Key3 = R.StorerKey
                   )
   WHERE  DATEDIFF(mi ,R.editdate ,GETDATE()) > 5
   AND    DATEDIFF(hh ,R.editdate ,GETDATE()) < 24
   AND    R.ASNStatus = '9'
   AND    LEN(R.ExternReceiptKey) > 0
   AND    T.Key1 IS NULL 
   UNION ALL
   SELECT SC.ConfigKey AS TableName
         ,O.StorerKey AS Storerkey
         ,O.Orderkey AS DocumentKey
   FROM   ORDERS O(NOLOCK)
          JOIN StorerConfig SC(NOLOCK)
               ON  (
                       SC.ConfigKey = 'PICKCFMLOG'
                   AND SC.Svalue = '1'
                   AND SC.Storerkey = O.StorerKey
                   )
          LEFT JOIN Transmitlog3 T(NOLOCK)
               ON  (
                       T.Key1 = O.Orderkey
                   AND T.tablename = 'PICKCFMLOG'
                   AND T.Key3 = O.StorerKey
                   )
   WHERE  DATEDIFF(mi ,O.editdate ,GETDATE()) > 5
   AND    DATEDIFF(hh ,O.editdate ,GETDATE()) < 24
   AND    O.SOStatus BETWEEN '0' AND '9'
   AND    O.Status = '5'
   AND    T.Key1 IS NULL 
   UNION ALL
   SELECT SC.ConfigKey AS TableName
         ,O.StorerKey AS Storerkey
         ,O.Orderkey AS DocumentKey
   FROM   ORDERS O(NOLOCK)
          JOIN StorerConfig SC(NOLOCK)
               ON  (
                       SC.ConfigKey = 'SOCFMLOG'
                   AND SC.Svalue = '1'
                   AND SC.Storerkey = O.StorerKey
                   )
          LEFT JOIN Transmitlog3 T(NOLOCK)
               ON  (
                       T.Key1 = O.Orderkey
                   AND T.tablename = 'SOCFMLOG'
                   AND T.Key3 = O.StorerKey
                   )
   WHERE  DATEDIFF(mi ,O.editdate ,GETDATE()) > 5
   AND    DATEDIFF(hh ,O.editdate ,GETDATE()) < 24
   AND    O.Status = '9' 
   AND    O.SOStatus NOT IN ('MASTER') -- SHONG01
   AND    T.Key1 IS NULL  
   
   IF @@ERROR <> 0
   BEGIN
       ROLLBACK TRAN
   END
   ELSE
   BEGIN
       IF EXISTS (
              SELECT 1
              FROM   #temp
          )
       BEGIN
           SET @textHTML = 
               N'<table border="1" cellspacing="0" cellpadding="5">' +
               N'<tr bgcolor=silver><th>TableName</th><th>StorerKey</th><th>DocumentKey</th></tr>' 
               +
               CAST(
                   (
                       SELECT TOP 50 
                              td = ISNULL(CAST(TableName AS NVARCHAR(99)) ,'')
                             ,''
                             ,td = ISNULL(CAST(StorerKey AS NVARCHAR(99)) ,'')
                             ,''
                             ,td = ISNULL(CAST(DocumentKey AS NVARCHAR(99)) ,'')
                       FROM   #temp 
                              FOR XML PATH('tr')
                             ,TYPE
                   ) AS NVARCHAR(MAX)
               ) + N'</table> P.S.: Top 50 records only' ;    
           
           EXEC msdb.dbo.sp_send_dbmail 
                @recipients = @recipientList
               ,@copy_recipients = @ccRecipientList
               ,@subject = @emailSubject
               ,@body = @textHTML
               ,@body_format = 'HTML' ;
       END
   END 
   
   DROP TABLE #temp
END -- procedure

GO