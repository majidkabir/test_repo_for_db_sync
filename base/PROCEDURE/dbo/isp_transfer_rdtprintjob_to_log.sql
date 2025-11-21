SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
 
/************************************************************************/  
/* Stored Procedure: isp_Transfer_RDTPrintJob_To_Log                    */  
/* Creation Date: 05-Nov-2018                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Transfer RDT Print Job record to Log for short term         */  
/*          until all rdtprint program have converted                   */  
/*                                                                      */  
/* Called By: Backend Schedule Job hourly                               */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   ver  Purposes                                  */  
/* 16-Jun-2019  Shong    1.1  Cater TCPSpooler Print Job                */
/* 08-Jul-2019  Shong    1.2  Make the retain interval as parameter     */
/************************************************************************/  
CREATE PROC [dbo].[isp_Transfer_RDTPrintJob_To_Log]   
( @n_RecordRetainMinute INT = -60 )
AS  
BEGIN  
 SET NOCOUNT ON  
   
   DECLARE @n_JobId     BIGINT, 
           @c_JobStatus NVARCHAR(1), 
           @c_JobType   NVARCHAR(10), 
           @c_Printer   NVARCHAR(50), 
           @c_SocketErrorMessage NVARCHAR(1000),
           @c_SocketStatus       NVARCHAR(1) 
  
   IF @n_RecordRetainMinute > 0 
      SET @n_RecordRetainMinute = @n_RecordRetainMinute * -1
      
   DECLARE CUR_RDT_QSPL_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RJ.JobId, RJ.JobStatus, RJ.JobType, rj.Printer   
   FROM rdt.RDTPrintJob RJ WITH (NOLOCK)  
   WHERE  ( RJ.AddDate < DATEADD(minute, @n_RecordRetainMinute, GETDATE()) 
            OR RJ.JobStatus='9'
            OR (RJ.Printer = 'PDF' AND RJ.JobStatus = '0') )             
   AND RJ.JobStatus NOT IN ('1')
  
   OPEN CUR_RDT_QSPL_JOB  
  
   FETCH FROM CUR_RDT_QSPL_JOB INTO @n_JobId, @c_JobStatus, @c_JobType, @c_Printer  
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
   	IF @c_JobStatus = '0' AND @c_JobType = 'QCOMMANDER' AND @c_Printer <> 'PDF'
   	BEGIN
         SELECT @c_SocketErrorMessage = '', 
   		       @c_SocketStatus = ''
   		          		
   		SELECT @c_SocketErrorMessage = tqt.ErrMsg, 
   		       @c_SocketStatus = tqt.[Status]
   		FROM TCPSocket_QueueTask_Log AS tqt WITH(NOLOCK)
         WHERE tqt.TransmitLogKey= CAST(@n_JobId AS VARCHAR(50)) 
         AND tqt.CmdType = 'CMD' 
         
         
         IF ISNULL(RTRIM(@c_SocketStatus),'') = ''
         BEGIN
   		   SELECT @c_SocketErrorMessage = tqt.ErrMsg, 
   		          @c_SocketStatus = tqt.[Status]
   		   FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
            WHERE tqt.TransmitLogKey= CAST(@n_JobId AS VARCHAR(50)) 
            AND tqt.CmdType = 'CMD'          	
         END

         PRINT 'Job ID: ' + CAST(@n_JobId AS VARCHAR(50)) 
         PRINT 'Socket Status: ' + @c_SocketStatus         
         PRINT 'Err Msg: ' + @c_SocketErrorMessage
         
         IF @c_SocketStatus = '5'
         BEGIN
            INSERT INTO rdt.RDTPrintJob_Log  
            (  
             JobId,           JobName,    ReportID,  
             JobStatus,       JobErrMsg,  NextRun,  
             LastRun,         Datawindow, NoOfParms,  
             Parm1,           Parm2,      Parm3,  
             Parm4,           Parm5,      Parm6,  
             Parm7,           Parm8,      Parm9,  
             Parm10,        Printer,    NoOfCopy,  
             Mobile,          TargetDB,   PrintCount,  
             PrintData,       JobType,    StorerKey,  
             ExportFileName,  Parm11,     Parm12,  
             Parm13,          Parm14,     Parm15,  
             Parm16,          Parm17,     Parm18,  
             Parm19,          Parm20,     Function_ID,  
             AddDate,         AddWho,     EditDate,  
             EditWho,         TrafficCop, ArchiveCop  
            )  
            SELECT   
             JobId,        JobName,                   ReportID,  
             JobStatus,    @c_SocketErrorMessage,     NextRun,  
             LastRun,      ISNULL(Datawindow,''),     NoOfParms,  
             Parm1,        Parm2,      Parm3,  
             Parm4,        Parm5,      Parm6,  
             Parm7,        Parm8,      Parm9,  
             Parm10,       Printer,    NoOfCopy,  
             Mobile,       TargetDB,   PrintCount,  
             PrintData,    JobType,    StorerKey,  
             ExportFileName, '',    '',  
             '',    '',    '',  
             '',    '',    '',  
             '',    '',    Function_ID,  
             AddDate,    AddWho,    ISNULL(EditDate, GETDATE()),  
             ISNULL(EditWho, AddWho),    NULL,    NULL  
            FROM RDT.RDTPrintJob AS rj WITH(NOLOCK)  
            WHERE rj.JobId = @n_JobId   
            IF @@ERROR = 0   
            BEGIN  
               IF EXISTS(SELECT 1 FROM RDT.RDTPrintJob_Log AS rjl WITH(NOLOCK)  
                         WHERE rjl.JobId = @n_JobId)  
               BEGIN  
                    DELETE RDT.RDTPrintJob   
                    WHERE JobId = @n_JobId         
               END  
            END     		
         END
   	END
   	ELSE IF @c_Printer = 'PDF' AND @c_JobStatus = '0'
	   BEGIN
         DELETE RDT.RDTPrintJob   
         WHERE JobId = @n_JobId  	   	
	   END
	   ELSE IF @c_JobStatus IN ('9','5','E') 
   	BEGIN
         INSERT INTO rdt.RDTPrintJob_Log  
         (  
          JobId,           JobName,    ReportID,  
          JobStatus,       JobErrMsg,  NextRun,  
          LastRun,         Datawindow, NoOfParms,  
          Parm1,           Parm2,      Parm3,  
          Parm4,           Parm5,      Parm6,  
          Parm7,           Parm8,      Parm9,  
          Parm10,          Printer,    NoOfCopy,  
          Mobile,          TargetDB,   PrintCount,  
          PrintData,       JobType,    StorerKey,  
          ExportFileName,  Parm11,     Parm12,  
          Parm13,          Parm14,     Parm15,  
          Parm16,          Parm17,     Parm18,  
          Parm19,          Parm20,     Function_ID,  
          AddDate,         AddWho,     EditDate,  
          EditWho,         TrafficCop, ArchiveCop  
         )  
         SELECT   
          JobId,        JobName,                   ReportID,  
          JobStatus,    'Force Move from Backend', NextRun,  
          LastRun,      ISNULL(Datawindow,''),     NoOfParms,  
          Parm1,        Parm2,      Parm3,  
          Parm4,        Parm5,      Parm6,  
          Parm7,        Parm8,      Parm9,  
          Parm10,       Printer,    NoOfCopy,  
          Mobile,       TargetDB,   PrintCount,  
          PrintData,    JobType,    StorerKey,  
          ExportFileName, '',    '',  
          '',    '',    '',  
          '',    '',    '',  
          '',    '',    Function_ID,  
          AddDate,    AddWho,    ISNULL(EditDate, GETDATE()),  
          ISNULL(EditWho, AddWho),    NULL,    NULL  
         FROM RDT.RDTPrintJob AS rj WITH(NOLOCK)  
         WHERE rj.JobId = @n_JobId   
         IF @@ERROR = 0   
         BEGIN  
            IF EXISTS(SELECT 1 FROM RDT.RDTPrintJob_Log AS rjl WITH(NOLOCK)  
                      WHERE rjl.JobId = @n_JobId)  
            BEGIN  
                 DELETE RDT.RDTPrintJob   
                 WHERE JobId = @n_JobId         
            END  
    END     		
   	END 
   	ELSE IF @c_JobStatus = 'X'
   	BEGIN
         DELETE RDT.RDTPrintJob   
         WHERE JobId = @n_JobId         		
   	END
  
      FETCH FROM CUR_RDT_QSPL_JOB INTO @n_JobId, @c_JobStatus, @c_JobType, @c_Printer   
   END  
   CLOSE CUR_RDT_QSPL_JOB  
   DEALLOCATE CUR_RDT_QSPL_JOB  
   
END -- End Procedure   

GO