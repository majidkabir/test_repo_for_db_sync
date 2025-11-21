SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: sp_APP_PerformanceTrace                               */
/* Creation Date: 06-Apr-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date           Ver    Author   Purposes                                 */
/***************************************************************************/

CREATE PROC [dbo].[sp_APP_PerformanceTrace]          
AS          
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF     
SET CONCAT_NULL_YIELDS_NULL OFF    
          
DECLARE @c_myDate DATETIME    
IF EXISTS (  
       SELECT 1  
       FROM   MASTER.dbo.SysProcesses  
       WHERE  OPEN_TRAN > 0  
       AND    DATEDIFF(mi ,Last_Batch ,GETDATE()) > 1  
       AND    (Program_Name = 'EXceed WMS' OR Program_Name = 'EXceed 6.0')  
   ) --KH01  
BEGIN  
    SELECT @c_myDate = GETDATE()    
    INSERT INTO APP_Process  
    SELECT @c_myDate  
          ,SPID  
          ,KPId  
          ,BLOCKED  
          ,WAITTYPE  
          ,WAITTIME  
          ,LASTWAITTYPE  
          ,WAITRESOURCE  
          ,DBID  
          ,UID  
          ,CPU  
          ,PHYSICAL_IO  
          ,MEMUSAGE  
          ,LOGIN_TIME  
          ,LAST_BATCH  
          ,ECID  
          ,OPEN_TRAN  
          ,status  
          ,sid  
          ,HOSTNAME  
          ,Program_Name  
          ,HOSTPROCESS  
          ,CMD  
          ,NT_DOMAIN  
          ,NT_USERNAME  
          ,NET_ADDRESS  
          ,NET_LIBRARY  
          ,LOGINAME  
          ,CONTEXT_INFO  
          ,SQL_HANDLE  
          ,STMT_START  
          ,STMT_END  
    FROM   MASTER.dbo.SysProcesses  
    WHERE  Open_Tran > 0  
    AND    DATEDIFF(mi ,Last_Batch ,GETDATE()) > 1  
    AND    (Program_Name = 'EXceed WMS' OR   
            Program_Name = 'EXceed 6.0') --KH01      
      
    DECLARE @n_SPID          INT  
           ,@c_SQL           NVARCHAR(150)  
           ,@n_Blocked       INT  
           ,@c_HostName      NVARCHAR(128)  
           ,@c_ProgramName   NVARCHAR(128)    
      
    DECLARE CUR CURSOR LOCAL READ_ONLY FAST_FORWARD   
    FOR  
        SELECT [SPID]  
              ,Blocked  
        FROM   MASTER.dbo.SysProcesses  
        WHERE  Open_Tran > 0  
        AND    DATEDIFF(mi ,Last_Batch ,GETDATE()) > 1  
        AND    (Program_Name = 'EXceed WMS' OR Program_Name = 'EXceed 6.0') --KH01      
      
    OPEN CUR -- OPEN cursor          
      
    FETCH NEXT FROM CUR INTO @n_SPID, @n_Blocked--fetch first          
      
    WHILE @@fetch_status = 0 --loop till the time we have something  
    BEGIN  
        SELECT @c_SQL = 'DBCC INPUTBUFFER (' + CAST(@n_SPID AS NVARCHAR(3)) + ')' --create sql, we cannot put this sql in exec, some error          
        INSERT INTO APP_Trace  
          (  
            EventType  
           ,Parameters  
           ,EventInfo  
          )  
        EXEC (@c_SQL) --EXEC sql to put the result of dbcc in wms table          
          
        UPDATE APP_Trace  
        SET    currenttime = @c_myDate  
              ,SPID = @n_SPID  
        WHERE  SPID IS NULL    
          
        IF @n_Blocked > 0 --IF this process is being blocked by some other process  
        BEGIN  
            SELECT @c_SQL = 'DBCC INPUTBUFFER (' + CAST(@n_Blocked AS NVARCHAR(3)) +   
                   ')' --create sql, we cannot put this sql in exec, some error          
            INSERT INTO APP_Blocking  
              (  
                EventType  
               ,Parameters  
               ,EventInfo  
              )  
            EXEC (@c_SQL) --EXEC sql to put the result of dbcc in wms table    
              
            SELECT @c_HostName = hostname  
                  ,@c_ProgramName = Program_Name  
            FROM   MASTER.dbo.SysProcesses  
            WHERE  SPID = @n_Blocked      
              
            UPDATE APP_Blocking  
            SET    currenttime   = @c_myDate  
                  ,SPID          = @n_SPID  
                  ,blocking_Id   = @n_Blocked  
                  ,hostname      = @c_HostName  
                  ,Program_Name  = @c_ProgramName  
            WHERE  blocking_Id IS NULL  
        END   
          
        FETCH NEXT FROM CUR INTO @n_SPID, @n_Blocked--fetch next  
    END   
    CLOSE CUR --close cursor          
    DEALLOCATE CUR --deallocate cursor  
END  

GO