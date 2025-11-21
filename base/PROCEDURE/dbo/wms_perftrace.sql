SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- tlting 20170302  remove program name filter for log check    
 -- 24May 2017  tlting  add trace on contention    
 -- 24Jan2019  tlting  lentgh    
CREATE PROC [dbo].[WMS_PERFTRACE]            
AS            
SET NOCOUNT ON      
SET ANSI_NULLS OFF     
SET QUOTED_IDENTIFIER OFF       
SET CONCAT_NULL_YIELDS_NULL OFF      
            
DECLARE @myDate DATETIME      
SELECT @mydate = GETDATE()    
    
IF EXISTS (SELECT 1    
       FROM   MASTER.dbo.sysProcesses (NOLOCK)    
       WHERE  open_tran>0    
       AND DATEDIFF(mi ,last_batch ,GETDATE())>1) --KH01    
BEGIN    
    INSERT INTO WMS_Process    
    SELECT @myDate    
          ,spid    
          ,kpid    
          ,blocked    
          ,waittype    
          ,waittime    
          ,lastwaittype    
          ,waitresource    
          ,dbid    
          ,uid    
          ,cpu    
          ,physical_io    
          ,memusage    
          ,login_time    
          ,last_batch    
          ,ecid    
          ,open_tran    
          ,STATUS    
          ,SID    
          ,hostname    
          ,program_name    
          ,hostprocess    
          ,cmd    
          ,nt_domain    
          ,nt_username    
          ,net_address    
          ,net_library    
          ,loginame    
          ,CONTEXT_INFO    
          ,sql_handle    
          ,stmt_start    
          ,stmt_end    
    FROM  MASTER.dbo.sysProcesses (NOLOCK)     
    WHERE open_tran>0    
      AND DATEDIFF(mi ,last_batch ,GETDATE())>1    
        
    DECLARE @spid             INT    
           ,@sql              NVARCHAR(150)    
           ,@blocked          INT    
           ,@hostname         NVARCHAR(128)    
           ,@program_name     NVARCHAR(128)      
        
    DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR            
      SELECT DISTINCT spid ,blocked    
      FROM   MASTER.dbo.sysProcesses (NOLOCK)     
      WHERE  open_tran>0    
      AND DATEDIFF(mi ,last_batch ,GETDATE())>1    
        
    OPEN CUR -- OPEN cursor            
        
    FETCH NEXT FROM CUR INTO @spid, @blocked            
        
    WHILE @@fetch_status=0 --loop till the time we have something    
    BEGIN    
        SELECT @sql = 'dbcc inputbuffer ('+CAST(@spid AS NVARCHAR(5))+')'          
        INSERT INTO WMS_Trace    
          (    
            EventType    
           ,Parameters    
           ,EventInfo    
          )    
        EXEC (@sql) --EXEC sql to put the result of dbcc in wms table            
            
        UPDATE WMS_Trace    
        SET    currenttime = @mydate    
              ,spid = @spid    
        WHERE  spid IS NULL      
            
        IF @blocked>0 --IF this process is being blocked by some other process    
        BEGIN    
            SELECT @sql = 'dbcc inputbuffer ('+CAST(@blocked AS NVARCHAR(5))+    
                   ')' --create sql, we cannot put this sql in exec, some error            
            INSERT INTO WMS_Blocking    
              (    
                EventType    
               ,Parameters    
               ,EventInfo    
              )    
            EXEC (@sql) --EXEC sql to put the result of dbcc in wms table      
                
            SELECT @hostname = hostname    
                  ,@program_name     = program_name    
            FROM   MASTER.dbo.sysProcesses    
            WHERE  spid              = @blocked       
                
            UPDATE WMS_Blocking    
            SET    currenttime      = @mydate    
                  ,spid             = @spid    
                  ,blocking_Id      = @blocked    
                  ,hostname         = @hostname    
                  ,program_name     = @program_name    
            WHERE  blocking_Id IS NULL    
        END     
            
        FETCH NEXT FROM CUR INTO @spid, @blocked--fetch next    
    END     
    CLOSE CUR --close cursor            
    DEALLOCATE CUR --deallocate cursor    
END    
    
DECLARE @n_Batch BIGINT    
SET @n_Batch = CAST('1'+RIGHT('00'+RTRIM(CAST(DATEPART(HOUR ,@mydate) AS CHAR(2))) ,2)     
       +RIGHT('00'+RTRIM(CAST(DATEPART(MINUTE ,@mydate) AS CHAR(2))) ,2) AS INT )    
     
    
--INSERT INTO dbo.TraceInfo (    
--    TraceName   ,TimeIn    ,TIMEOUT ,TotalTime    
--   ,Step1      ,Step2      ,Step3   ,Step4    
--   ,Step5      ,Col1       ,Col2    ,Col3   ,Col4   ,Col5 )    
--SELECT 'Latch_Contention'           TraceName    
--      ,@mydate                      TimeIn    
--      ,@mydate                      TIMEOUT    
--      ,@n_Batch                     TotalTime    
--      ,session_id    
--      ,wait_type    
--      ,wait_duration_ms    
--      ,blocking_session_id    
--      ,resource_description    
--      ,ResourceType = CASE     
--                           WHEN PageID=1 OR PageID % 8088=0 THEN 'Is PFS Page'    
--                           WHEN PageID=2 OR PageID % 511232=0 THEN 'Is GAM Page'    
--                           WHEN PageID=3 OR (PageID- 1) % 511232=0 THEN 'Is SGAM Page'    
--                           ELSE     'Is Not PFS, GAM, or SGAM page'    
--                      END    
--      ,''                           Col2    
--      ,''                           Col3    
--      ,''                           Col4    
--      ,''                           Col5    
--FROM   (    
--   SELECT session_id    
--         ,wait_type    
--         ,wait_duration_ms    
--         ,blocking_session_id    
--         ,resource_description    
--         ,PageID = CAST(RIGHT(resource_description    
--                  ,LEN(resource_description) - CHARINDEX(':' ,resource_description ,3) ) AS INT )    
--   FROM   sys.dm_os_waiting_tasks    
--   WHERE  wait_type LIKE 'PAGE%LATCH_%'    
--     AND resource_description LIKE '2:%' ) Tasks;    
    
--INSERT INTO dbo.TraceInfo    
--  (    
--    TraceName  ,TimeIn  ,TIMEOUT ,TotalTime    
--   ,Step1      ,Step2   ,Step3   ,Step4  ,Step5    
--   ,Col1       ,Col2    ,Col3    ,Col4   ,Col5  )    
--SELECT 'WAIT_TASK'     TraceName    
--      ,@mydate         TimeIn    
--      ,@mydate         TIMEOUT    
--      ,@n_Batch        TotalTime    
--      ,session_id    
--      ,wait_type    
--      ,wait_duration_ms    
--      ,blocking_session_id    
--      ,resource_description    
--      ,''    
--      ,''    
--      ,''    
--      ,''    
--      ,''    
--FROM   sys.dm_os_waiting_tasks    
--WHERE  wait_type IN ('IO_COMPLETION' ,'SLEEP_TASK')    
    
    
SET @sql = ''    
DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD     
FOR    
    -- DECLARE cursor            
    SELECT DISTINCT step1    
    FROM   TraceInfo (NOLOCK)    
    WHERE  TraceName      = 'WAIT_TASK'    
           AND TimeIn     = @mydate    
           AND Step2      = 'IO_COMPLETION'   -- wait type    
     
 OPEN CUR -- OPEN cursor            
     
 FETCH NEXT FROM CUR INTO @spid         
     
WHILE @@fetch_status=0 --loop till the time we have something    
BEGIN    
    IF NOT EXISTS (    
           SELECT 1    
           FROM   WMS_Trace(NOLOCK)    
           WHERE  currenttime     = @mydate    
                  AND spid        = @spid    
       )    
    BEGIN    
        SELECT @sql = 'dbcc inputbuffer ('+CAST(@spid AS NVARCHAR(5))+')' --create sql, we cannot put this sql in exec, some error            
        INSERT INTO WMS_Trace    
          (    
            EventType    
           ,Parameters    
           ,EventInfo    
          )    
        EXEC (@sql) --EXEC sql to put the result of dbcc in wms table            
            
        UPDATE WMS_Trace    
        SET    currenttime     = @mydate    
              ,spid            = @spid    
        WHERE  spid IS NULL    
    END    
        
    FETCH NEXT FROM CUR INTO @spid    
END     
 CLOSE CUR --close cursor            
 DEALLOCATE CUR --deallocate cursor    
     
             
SET NOCOUNT OFF

GO