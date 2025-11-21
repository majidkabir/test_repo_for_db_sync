SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
CREATE PROC [dbo].[WMS_PERFTRACE_v1]              
AS              
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF         
SET CONCAT_NULL_YIELDS_NULL OFF        
              
DECLARE @myDate DATETIME    
        
IF EXISTS (SELECT 1    
       FROM   MASTER.dbo.sysProcesses    
       WHERE  OPEN_TRAN > 0    
       AND    DATEDIFF(mi ,last_batch ,GETDATE())>1    
       AND    ( PROGRAM_NAME IN ('EXceed' ,'EXceed WMS' ,'RDS' ,'jTDS' ,'RDT Print Server' ,'Zeus')    
                OR     
                PROGRAM_NAME LIKE 'SQLAgent - TSQL%' )    
   )    
BEGIN    
    SELECT @mydate = GETDATE()    
            
    INSERT INTO WMS_Process    
    SELECT @myDate          ,spid          ,kpid          ,blocked    
          ,waittype         ,waittime      ,lastwaittype  ,waitresource    
          ,dbid             ,uid           ,cpu           ,physical_io    
          ,memusage         ,login_time    ,last_batch    ,ecid    
          ,open_tran        ,STATUS        ,SID           ,hostname    
          ,program_name     ,hostprocess   ,cmd           ,nt_domain    
          ,nt_username      ,net_address   ,net_library   ,loginame    
          ,CONTEXT_INFO     ,sql_handle    ,stmt_start    ,stmt_end    
    FROM   MASTER.dbo.sysProcesses    
    WHERE  open_tran>0    
    AND    DATEDIFF(mi ,last_batch ,GETDATE())>1    
    AND   (PROGRAM_NAME IN ('EXceed' ,'EXceed WMS' ,'RDS' ,'jTDS' ,'RDT Print Server' ,'Zeus')    
           OR     
           PROGRAM_NAME LIKE 'SQLAgent - TSQL%')              
  
    INSERT INTO WMS_Process    
    SELECT @myDate          ,spid          ,kpid          ,blocked    
          ,waittype         ,waittime      ,lastwaittype  ,waitresource    
          ,dbid             ,uid           ,cpu           ,physical_io    
          ,memusage         ,login_time    ,last_batch    ,ecid    
          ,open_tran        ,STATUS        ,SID           ,hostname    
          ,program_name     ,hostprocess   ,cmd           ,nt_domain    
          ,nt_username      ,net_address   ,net_library   ,loginame    
          ,CONTEXT_INFO     ,sql_handle    ,stmt_start    ,stmt_end    
    FROM   MASTER.dbo.sysProcesses    
    WHERE  DATEDIFF(mi ,last_batch ,GETDATE())>1    
    AND    loginame like 'brio%'   
        
    DECLARE @spid          INT    
           ,@sql           VARCHAR(150)    
           ,@blocked       INT    
           ,@hostname      VARCHAR(128)    
           ,@program_name  VARCHAR(128)        
        
    DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD     
    FOR    
        -- DECLARE cursor              
        SELECT spid    
              ,blocked                            
        FROM   MASTER.dbo.sysProcesses    
        WHERE  open_tran>0    
        AND    DATEDIFF(mi ,last_batch ,GETDATE())>1    
        AND   (PROGRAM_NAME IN ('EXceed' ,'EXceed WMS' ,'RDS' ,'jTDS' ,'RDT Print Server' ,'Zeus')    
               OR     
               PROGRAM_NAME LIKE 'SQLAgent - TSQL%')     
        UNION ALL  
        SELECT spid    
              ,blocked      
        FROM   MASTER.dbo.sysProcesses    
        WHERE  DATEDIFF(mi ,last_batch ,GETDATE())>1    
        AND    loginame like 'brio%'   
  
    OPEN CUR -- OPEN cursor              
        
    FETCH NEXT FROM CUR INTO @spid, @blocked  --fetch first              
        
    WHILE @@fetch_status=0 --loop till the time we have something    
    BEGIN    
        SELECT @sql = 'dbcc inputbuffer ('+CAST(@spid AS NVARCHAR(3))+')' --create sql, we cannot put this sql in exec, some error              
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
            SELECT @sql = 'dbcc inputbuffer ('+CAST(@blocked AS NVARCHAR(3))+')' --create sql, we cannot put this sql in exec, some error              
            INSERT INTO WMS_Blocking    
              (    
                EventType    
               ,Parameters    
               ,EventInfo    
              )    
            EXEC (@sql) --EXEC sql to put the result of dbcc in wms table        
                
            SELECT @hostname = hostname    
                  ,@program_name = PROGRAM_NAME    
            FROM   MASTER.dbo.sysProcesses    
            WHERE  spid = @blocked         
                
            UPDATE WMS_Blocking    
            SET    currenttime = @mydate    
                  ,spid = @spid    
                  ,blocking_Id = @blocked    
                  ,hostname = @hostname    
                  ,program_name = @program_name    
            WHERE  blocking_Id IS NULL    
        END     
            
        FETCH NEXT FROM CUR INTO @spid, @blocked--fetch next    
    END     
    CLOSE CUR --close cursor              
    DEALLOCATE CUR --deallocate cursor    
END    
              
SET NOCOUNT OFF        
        

GO