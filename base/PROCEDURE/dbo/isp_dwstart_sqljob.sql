SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_DWStart_SQLJob                                 */
/* Creation Date: 09-Dec-2013                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#296625                                                  */   
/*                                                                      */
/* Called By: r_dw_start_sqljob                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 29-Jan-2014  NJOW01   1.0  Fix to get job owner from sysjobs_view    */ 
/************************************************************************/

CREATE PROC [dbo].[isp_DWStart_SQLJob]   
   @c_JobName   sysname,  
   @c_StartJob  NVARCHAR(10) = 'Y'
AS   
BEGIN  
	    
   --USE MASTER 
   --GRANT EXECUTE ON MASTER.dbo.xp_sqlagent_enum_jobs TO PUBLIC
   --GO

   --USE MSDB
   --GRANT EXECUTE ON msdb.dbo.sp_start_job TO PUBLIC
   --GO
   --GRANT SELECT ON msdb.dbo.sysjobs_view TO PUBLIC
   --GO
       
   --Login id must map to msdb with 'SQLAgentOperatorRole' role enabled

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @job_id UNIQUEIDENTIFIER,
           @is_sysadmin INT,
		       @job_owner   sysname,
           @c_Messages NVARCHAR(200)
   
   SELECT @c_Messages = 'Job ''' + RTRIM(ISNULL(@c_JobName,'')) + ''' Running Successfully.'        
   
   IF ISNULL(@c_JobName,'') = '' 
   BEGIN
   	  SELECT @c_messages = 'Empty Job Name -  No Job To Start.'      
   	  GOTO EXIT_SP
   END

   IF ISNULL(@c_StartJob,'') <> 'Y' 
   BEGIN
   	  SELECT @c_messages = 'Start Job = '''+ RTRIM(ISNULL(@c_StartJob,'')) +''' - Job Not Start.'
   	  GOTO EXIT_SP
   END
       
   IF (SELECT OBJECT_ID('tempdb.dbo.#jobstatus'))>0
       DROP TABLE dbo.#jobstatus

   CREATE TABLE #jobstatus
   (
	     JobID UNIQUEIDENTIFIER NULL
      ,LastRunDate INT NULL
      ,LastRunTime INT NULL
      ,NextRunDate INT NULL
      ,NextRunTime INT NULL
      ,NextRunScheduleID INT NULL
      ,RequestedToRun INT NULL
      ,RequestSource INT NULL
      ,RequestSourceID SYSNAME NULL
      ,Running INT NULL
      ,CurrentStep INT NULL
      ,CurrentRetryAttempt INT NULL
      ,STATE INT NULL
   ) 
	      
   SELECT @job_id = job_id, @job_owner = SUSER_SNAME(owner_sid)
   FROM msdb.dbo.sysjobs_view 
   WHERE NAME = @c_JobName
        
   IF @@ROWCOUNT = 0 
   BEGIN
   	  SELECT @c_Messages = 'ERROR: The Specified Job ''' + RTRIM(@c_JobName) + ''' Does Not Exist.'
   	  GOTO EXIT_SP
   END

	 --SELECT @job_owner = 'sa' --SUSER_SNAME()
   SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin',@job_owner), 0)  --1
	
   INSERT INTO #jobstatus
   EXEC MASTER.dbo.xp_sqlagent_enum_jobs 
        @is_sysadmin
       ,@job_owner
       ,@job_id

  
		--Is the execution status for the jobs. 
		--Value Description 
		--0 Returns only those jobs that are not idle or suspended.  
		--1 Executing. 
		--2 Waiting for thread. 
		--3 Between retries. 
		--4 Idle. 
		--5 Suspended. 
		--7 Performing completion actions 
	      
   IF (SELECT Running FROM dbo.#jobstatus)=1 -- running
   BEGIN
   	  SELECT @c_Messages = 'Job already Running.'
      GOTO EXIT_SP
   END

   BEGIN TRY
       EXEC msdb.dbo.sp_start_job @c_JobName
   END TRY
   BEGIN CATCH
      SELECT @c_Messages = 'ERROR: ' + RTRIM(CAST(ERROR_NUMBER() AS NVARCHAR(10))) + ' - ' + ERROR_MESSAGE()      
   END CATCH;
         
EXIT_SP:
   
   SELECT @c_Messages          
   
END  

GO