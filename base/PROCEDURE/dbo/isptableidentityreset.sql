SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
    
/************************************************************************/    
/* Stored Proc : ispTableIdentityReset                                  */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Input Parameters: NONE                                               */    
/*                                                                      */    
/* Output Parameters: NONE                                              */    
/*                                                                      */    
/* Return Status: NONE                                                  */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: All Archive Script                                        */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 14-May-2015  TLTING        Revise to cater bigInt                    */  
/* 04-Aug-2022  TLTING        change bigInt reset limit                 */
/************************************************************************/    

CREATE PROC [dbo].[ispTableIdentityReset]  (    
  @recipientList nvarchar(4000),      
  @ccRecipientList nvarchar(4000)  )    
AS        
BEGIN        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
/*********************************************/        
/* Variables Declaration (Start)             */       
    
Declare @c_SCHEMA nvarchar(30)    
, @c_Table        nvarchar(200)    
, @c_column       nvarchar(200)    
, @c_ExecStatements NVARCHAR(4000)        
, @c_ExecArguments NVARCHAR(4000)     
, @n_flag         INT    
, @b_debug        INT    
    
SET @b_debug = 1    
    
   DECLARE @textHTML  NVARCHAR(MAX),      
        @emailSubject NVARCHAR(4000),    
        @cDate nvarchar(20)      
      
   SET @textHTML = ''       
   SET @cDate = Convert(Char(11), getdate(), 106)      
   SET @emailSubject = 'WMS Table IDENTITY VALUE Reset Alert for Server ' + @@serverName + ' - ' + @cDate      
      
Create Table #temp    
( Rowref INT IDENTITY(1,1) Primary Key,     
 TableName nVarchar(200),    
 IdentityColumn nvarchar(200)    
)    
    
-- MAX value for Identity column - INT - 2,147,483,647  
-- BIGINT - 9,223,372,036,854,775,807
    
DECLARE TBLCol_Cur CURSOR FAST_FORWARD READ_ONLY FOR    
SELECT  SCHEMA_NAME( OBJECTPROPERTY( IC.OBJECT_ID, 'SCHEMAID' )) AS SCHEMA_NAME,  
         OBJECT_NAME(IC.OBJECT_ID) AS TABLE_NAME,   
         IC.NAME AS COLUMN_NAME   
FROM     SYS.IDENTITY_COLUMNS  IC (NOLOCK) , systypes  T (NOLOCK)   
  WHERE     IC.user_type_id = T.xusertype  
  AND IC.LAST_VALUE > 2100000000  
  AND T.name = 'int'  
UNION ALL  
SELECT  SCHEMA_NAME( OBJECTPROPERTY( IC.OBJECT_ID, 'SCHEMAID' )) AS SCHEMA_NAME,  
         OBJECT_NAME(IC.OBJECT_ID) AS TABLE_NAME,   
         IC.NAME AS COLUMN_NAME   
FROM     SYS.IDENTITY_COLUMNS  IC (NOLOCK) , systypes  T (NOLOCK)   
  WHERE     IC.user_type_id = T.xusertype  
  AND IC.LAST_VALUE > 9223372036654775807  
  AND T.name = 'bigint'  
ORDER BY 1, 2    
    
OPEN TBLCol_Cur    
    
FETCH NEXT FROM TBLCol_Cur INTO @c_SCHEMA, @c_Table, @c_column    
    
WHILE @@FETCH_STATUS <> -1    
BEGIN     
  
   SET @c_Table = @c_SCHEMA+'.'+@c_Table    
   if (@b_debug =1 )    
   begin    
      PRINT 'RESEED ' +  @c_Table    
   end    
   DBCC CHECKIDENT(@c_Table, RESEED, 100)    
    
   INSERT INTO #temp ( TableName, IdentityColumn )    
   VALUES (@c_Table,@c_column )    
    
FETCH NEXT FROM TBLCol_Cur INTO @c_SCHEMA, @c_Table, @c_column    
END    
    
CLOSE TBLCol_Cur    
DEALLOCATE TBLCol_Cur    
    
Select DB_Name()    
   IF EXISTS (SELECT 1 FROM #temp)      
   BEGIN      
     
      SET @textHTML = @textHTML + '<h3>WMS Server - ' +DB_Name()+ ' Table IDENTITY VALUE Reset </h3>'       
      SET @textHTML = @textHTML + N'<table border="1" cellspacing="0" cellpadding="5">' +      
             N'<tr bgcolor=silver><th>Table Name</th><th>Column</th></tr>' +      
             CAST ( ( SELECT td = ISNULL(CAST(TableName AS nchar(50)),''), '',      
                             td = ISNULL(CAST(IdentityColumn AS nchar(30)),'' )      
                     FROM #temp         
                 FOR XML PATH('tr'), TYPE      
             ) AS NVARCHAR(MAX) ) + N'</table>' ;       
    
      EXEC msdb.dbo.sp_send_dbmail       
       @recipients      = @recipientList,      
       @copy_recipients = @ccRecipientList,      
       @subject         = @emailSubject,      
       @body            = @textHTML,      
       @body_format     = 'HTML' ;      
   END      
      
   DROP TABLE #temp      
      
END  

GO