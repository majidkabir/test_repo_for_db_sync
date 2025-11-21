SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: isp_Long_Running_WMS_SysProcess                          */
/* Copyright: IDS                                                             */
/* Purpose: capture the long running Brio information                         */
/*                                                                            */
/* Called By: 00-BEJ - WMS Performance Trace                                  */
/* Updates:                                                                   */
/* Date         Author        Purposes                                        */
/* 22-Aug-2011  TLTING        Shorten Timing & Bug fix on Update              */
/* 9-Aug-2012   TLTING        New col DB_name                                 */
/* 11-Nov-2015  KHLim01       increase SPID length from 3 to 9                */
/* 2017-05-11   KHLim         Add LastWaitType column to capture broker(KH03) */
/* 29-Sep-2018  TLTING        Bug fix CPU and IO sum                          */
/* 20-Mar-2019  TLTING        reduce CPU and IO sum capture                   */
/* 08-Apr-2019  TLTING        capture 'Microsoft Office' query                */
/* 08-Apr-2019  TLTING        capture waiting COMMAND query casue blocking    */
/* 30-May-2020  TLTING        Exclude system backend task                     */
/* 10-Nov-2020  TLTING        Duration bug - NULL                             */
/******************************************************************************/

CREATE PROC [dbo].[isp_Long_Running_WMS_SysProcess]
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF
   DECLARE @d_MyDate datetime

   CREATE TABLE #WMS_Trace (
      RowRef int NOT NULL IDENTITY (1, 1) PRIMARY KEY,
      Currenttime datetime NULL,
      spid smallint NULL,
      EventType nvarchar(60) NULL,
      parameters int NULL,
      Eventinfo nvarchar(4000) NULL
   )

   DECLARE @SPID smallint
   DECLARE @sql nvarchar(150)

   SELECT @d_MyDate = GETDATE()

   INSERT INTO WMS_SysProcess (currenttime, [spid], blocked, hostname, [program_name], [net_address], loginame,
            login_time, last_batch, Duration, EventInfo, [DB_Name], LastWaitType)--KH03        
      SELECT
         @d_MyDate,
         [spid],
         blocked,
         hostname,
         [program_name] =
            CASE WHEN program_name like 'SQLAgent%' 
                  THEN master.dbo.fnc_GetJobNameFromProgramName(program_name)  
                  ELSE program_name 
            END,
         net_address,
         loginame,
         login_time,
         last_batch,
         ISNULL(DATEDIFF(MINUTE, last_batch, ISNULL(@d_MyDate, GETDATE())), 999) AS Duration,
         '' as EventInfo,
         DB_NAME(a.dbid) as [DB_Name],
         lastwaittype --KH03        
      FROM master.dbo.Sysprocesses a WITH (NOLOCK)
      WHERE spid >= 50
      AND DATEDIFF(MINUTE, Login_Time, GETDATE()) > 5  -- @n_Minutes              
      AND DATEDIFF(MINUTE, last_batch, GETDATE()) > 5
      AND cmd <> 'AWAITING COMMAND'
      AND NOT (loginame = 'sa' AND LastWaitType IN ('CHECKPOINT_QUEUE', 'BROKER_EVENTHANDLER'))
      AND NOT (loginame = 'sa' AND [program_name] = '') 
      AND ([program_name] <> 'SQLAgent - TSQL JobStep (Job 0x697824825E07704BBFF2C9D3C42E266D : Step 2)') -- cdc.CNWMS_capture
      GROUP BY spid,
               blocked,
               hostname,
               CASE WHEN program_name like 'SQLAgent%' 
                     THEN master.dbo.fnc_GetJobNameFromProgramName(program_name)  
                     ELSE program_name 
               END ,
               net_address,
               loginame,
               login_time,
               last_batch,
               ISNULL(DATEDIFF(MINUTE, last_batch, ISNULL(@d_MyDate, GETDATE())), 999),
               DB_NAME(a.dbid),
               lastwaittype --KH03        
      HAVING SUM(CONVERT(bigint, CPU)) > 100
      AND SUM(CONVERT(bigint, physical_io)) > 100
         
   --UNION     
   --Select  @d_MyDate, [spid], blocked,hostname, [program_name], net_address, loginame,        
   --       login_time, last_batch, DATEDIFF(MINUTE, last_batch, GETDATE()),'', db_name(a.dbid), lastwaittype --KH03        
   --FROM master.dbo.Sysprocesses a with (NOLOCK)             
   --WHERE spid >= 50            
   --AND DATEDIFF(MINUTE, Login_Time, GETDATE()) > 8  -- @n_Minutes              
   --AND DATEDIFF(MINUTE, last_batch, GETDATE()) > 8             
   --AND cmd <> 'AWAITING COMMAND'          
   --AND NOT ( loginame= 'sa' and  LastWaitType  in ( 'CHECKPOINT_QUEUE', 'BROKER_EVENTHANDLER') )    
   --AND [program_name] like 'Microsoft Office%'    
   --AND blocked <> ''    
   --group by spid, blocked,hostname, [program_name], net_address, loginame,         
   --       login_time, last_batch, DATEDIFF(MINUTE, last_batch, GETDATE()),    db_name(a.dbid), lastwaittype --KH03        

   -- temp disable    
   --INSERT INTO WMS_SysProcess (currenttime,[spid],blocked,hostname,[program_name],[net_address],loginame,        
   --login_time, last_batch, Duration                               , EventInfo,[DB_Name],LastWaitType)--KH03        
   --Select  @d_MyDate, a.[spid], a.blocked,a.hostname, a.[program_name], a.net_address, a.loginame,        
   --       a.login_time, a.last_batch, DATEDIFF(MINUTE, a.last_batch, GETDATE()),'', db_name(a.dbid), a.lastwaittype --KH03        
   --FROM master.dbo.Sysprocesses a with (NOLOCK)         
   --     JOIN  WMS_SysProcess B (NOLOCK) ON  b.blocked = a.[spid]    
   --WHERE a.spid >= 50            
   --AND DATEDIFF(MINUTE, a.Login_Time, GETDATE()) > 20  -- @n_Minutes              
   --AND DATEDIFF(MINUTE, a.last_batch, GETDATE()) > 20        
   --AND b.currenttime =  @d_MyDate and b.blocked <> ''         
   --  AND NOT exists ( Select 1 from  WMS_SysProcess C (NOLOCK)      
   --  WHERE c.currenttime =  @d_MyDate   AND C.spid = b.blocked    
   --  )     
   --group by a.spid, a.blocked,a.hostname, a.[program_name], a.net_address, a.loginame,         
   --       a.login_time, a.last_batch, DATEDIFF(MINUTE, a.last_batch, GETDATE()),    db_name(a.dbid), a.lastwaittype --KH03        


   DECLARE Cur_Process CURSOR LOCAL READ_ONLY FAST_FORWARD FOR -- DECLARE cursor                      
   SELECT DISTINCT [spid]
   FROM WMS_SysProcess WITH (NOLOCK)
   WHERE currenttime = @d_MyDate
   --ORDER BY last_batch

   OPEN Cur_Process -- OPEN cursor                      

   FETCH NEXT FROM Cur_Process INTO @SPID

   WHILE @@FETCH_STATUS = 0 --loop till the time we have something                      
   BEGIN
      SELECT
         @sql = 'DBCC INPUTBUFFER (' + CAST(@SPID AS nvarchar(9)) + ')' --create sql, we cannot put this sql in exec, some error    --KHLim01                  
      INSERT INTO #WMS_Trace (EventType, Parameters, EventInfo)
      EXEC (@sql) --EXEC sql to put the result of dbcc in wms table                      

      UPDATE #WMS_Trace
      SET CurrentTime = @d_MyDate,
          SPID = @SPID
      WHERE SPID IS NULL

      IF exists ( SELECT 1 from  #WMS_Trace WHERE EventInfo  = 'sys.sp_MScdc_capture_job' )
      BEGIN
         -- ignore CDC Job
         Delete   WMS_SysProcess      
         FROM WMS_SysProcess WP
         JOIN #WMS_Trace WT ON WP.SPID = WT.SPID
         WHERE WP.currenttime = @d_MyDate
         AND WP.SPID = @SPID
         AND  WT.EventInfo  = 'sys.sp_MScdc_capture_job'
      END
      ELSE
      BEGIN

         UPDATE WMS_SysProcess WITH (ROWLOCK)
            SET Eventinfo = ISNULL(WT.EventInfo, '') 
         FROM WMS_SysProcess WP
         JOIN #WMS_Trace WT ON WP.SPID = WT.SPID
         WHERE WP.currenttime = @d_MyDate
         AND WP.SPID = @SPID
      END
  
      TRUNCATE TABLE #WMS_Trace

      FETCH NEXT FROM Cur_Process INTO @SPID
   END
   CLOSE Cur_Process --close cursor                      
   DEALLOCATE Cur_Process --deallocate cursor                       

GO