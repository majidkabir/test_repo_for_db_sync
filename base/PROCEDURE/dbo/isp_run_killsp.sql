SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/************************************************************************/    
/* Stored Procedure: isp_long_run_kill                                  */    
/* Creation Date: 2012-May-08                                           */    
/* Copyright: IDS                                                       */    
/* Written by: KHLim                                                    */    
/*                                                                      */    
/* Purpose: Kill long-running process & send email                      */    
/*                                                                      */    
/* Called By: ALT - WMS Performance Trace Alert                         */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/************************************************************************/    
CREATE PROC [dbo].[isp_run_killsp] (    
   @cCountry   NVARCHAR(5),    
   @cListTo    NVARCHAR(max),    
   @cListCc    NVARCHAR(max) = ''  
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET ANSI_WARNINGS OFF    
    
   DECLARE  @cBody      NVARCHAR(max),    
            @cSubject   NVARCHAR(255),    
            @cImpt      NVARCHAR(6),    
            @cPattern   NVARCHAR(800),     
            @cEventInfo nvarchar(4000),
            @d_MyDate   datetime 

   DECLARE  @SPID       smallint,    
            @sql        NVARCHAR(150),    
            @cDBCCInfo  nvarchar(4000)        
   SET @cImpt     = 'Normal'    
   SET @cPattern  = 'Microsoft Office%'   -- SQL pattern of EventInfo    

  SELECT @d_MyDate = GETDATE()     

   Create TABLE #WMS_Trace        
      ( EventType   nvarchar(60) NULL,        
      parameters   int NULL,        
      Eventinfo   nvarchar(4000) NULL        
      )  
      
 

 
   IF EXISTS ( SELECT 1 FROM master..sysprocesses WITH (nolock)    
               WHERE DATEDIFF(mi, last_batch,@d_MyDate) >5   
               AND program_name LIKE 'Microsoft Office%'    )    
   BEGIN    
      SELECT TOP 1     
         @SPID = spid     
         FROM master..sysprocesses WITH (nolock)    
               WHERE DATEDIFF(mi, last_batch, @d_MyDate) > 5    
               AND program_name LIKE 'Microsoft Office%'    
    
                 
      SELECT @sql = 'DBCC INPUTBUFFER (' + CAST(@SPID as NVARCHAR(6)) + ')'    
      INSERT INTO  #WMS_Trace (EventType, Parameters, EventInfo)                  
      EXEC (@sql)    

      SELECT @sql = 'KILL ' + CAST(@SPID as NVARCHAR(6)) + ''    
      EXEC (@sql)        
     
    END


    IF exists ( Select 1
               from sys.dm_exec_sessions 
               where open_transaction_count > 0
               and ansi_nulls = 1
               and ansi_warnings = 1
               and is_user_process = 1
               and transaction_isolation_level <> 1
               and last_request_end_time  < dateadd( hour, -3, getdate() )
               and status = 'sleeping'
               and program_name in ( 'Microsoft SQL Server Management Studio - Query','HeidiSQL') 
               )

   BEGIN

      SELECT TOP 1     
         @SPID = session_id  
      from sys.dm_exec_sessions 
      where open_transaction_count > 0
      and ansi_nulls = 1
      and ansi_warnings = 1
      and is_user_process = 1
      and transaction_isolation_level <> 1
      and last_request_end_time  < dateadd( hour, -3, getdate() )
      and status = 'sleeping'
      and program_name in ( 'Microsoft SQL Server Management Studio - Query','HeidiSQL')
      Order by last_request_end_time desc


      SELECT @sql = 'DBCC INPUTBUFFER (' + CAST(@SPID as NVARCHAR(6)) + ')'    
      INSERT INTO  #WMS_Trace (EventType, Parameters, EventInfo)                  
      EXEC (@sql)    

      SELECT @sql = 'KILL ' + CAST(@SPID as NVARCHAR(6)) + ''    
      EXEC (@sql)

   END

   IF EXISTS ( Select 1  FROM #WMS_Trace )    
   BEGIN 
  
  	   DECLARE killitem_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select SPID, EventInfo
		   From #WMS_Trace

	   OPEN killitem_cur 
	   FETCH NEXT FROM killitem_cur INTO @SPID, @cDBCCInfo
	   WHILE @@FETCH_STATUS = 0 
	   BEGIN 
        
         SET @cImpt = 'High'    
    
         SET @cSubject = 'Performance Trace - WMS - ' + @cCountry + '- Process Killed'    
  
         SET @cBody = 'SPID - ' + @SPID + ' - ' + @cDBCCInfo  
            
      
         EXEC msdb.dbo.sp_send_dbmail    
          @recipients      = @cListTo,    
          @copy_recipients = @cListCc,    
          @subject         = @cSubject,    
          @importance      = @cImpt,    
          @body            = @cBody,    
          @body_format     = 'HTML' ;    

		   FETCH NEXT FROM killitem_cur INTO @SPID, @cDBCCInfo
	   END
	   CLOSE killitem_cur 
	   DEALLOCATE killitem_cur           
   END    
      DROP TABLE #WMS_Trace   
END 

GO