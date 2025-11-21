SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CPC_UpdateTaskStatus                           */
/* Creation Date: 20-May-2023                                           */
/* Copyright: Maersk FbM WMS                                            */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Update status into CloudPrintTask table                     */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'XML/JSON'                  */
/*                    @c_UserID           - 'UserName'                  */
/*                    @c_OperationType    - 'Operation'                 */
/*                    @c_RequestString    - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @c_ErrNo            - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: IntranetAPIServer - isp_Generic_WebAPI_Request            */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 20-May-2023  TKLim      Initial Development                          */
/* 25-Jul-2023  TKLIM      Add MoveToArchive for archive after print    */
/************************************************************************/
CREATE PROC [dbo].[isp_CPC_UpdateTaskStatus] (
     @b_Debug           INT            = 0  
   , @c_Format          NVARCHAR(10)   = ''  
   , @c_UserID          NVARCHAR(256)  = ''  
   , @c_OperationType   NVARCHAR(60)   = ''  
   , @c_RequestString   NVARCHAR(MAX)  = ''  
   , @b_Success         INT            = 0   OUTPUT  
   , @n_ErrNo           INT            = 0   OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT  
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @n_Continue                    INT  
         , @n_StartCnt                    INT  
         , @c_ExecStatements              NVARCHAR(MAX)  
         , @c_ExecArguments               NVARCHAR(2000)  
         , @c_ID                          NVARCHAR(20)        
         , @c_PrintClientID               NVARCHAR(100)       
         , @c_ThreadID                    NVARCHAR(20)    
         , @c_MsgRecvDate                 NVARCHAR(23)    
         , @c_ThreadStartTime             NVARCHAR(23)    
         , @c_ThreadEndTime               NVARCHAR(23)    
         , @c_TaskStatus                  NVARCHAR(1)     
         , @c_TaskErrMsg                  NVARCHAR(1000)  
         , @c_Try                         NVARCHAR(1)  
         --, @c_JSON                        NVARCHAR(MAX)  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 1  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
   SET @c_ID                              = ''
   SET @c_PrintClientID                   = ''  
   SET @c_ThreadID                        = ''
   SET @c_MsgRecvDate                     = ''
   SET @c_ThreadStartTime                 = ''
   SET @c_ThreadEndTime                   = ''
   SET @c_TaskStatus                      = ''
   SET @c_TaskErrMsg                      = ''
   SET @c_Try                             = ''
   --SET @c_JSON                            = ''  
  --Validations
   IF ISNULL(RTRIM(@c_RequestString), '') = ''  
   BEGIN  
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98991  
      SET @c_ErrMsg = 'Content Body cannot be blank.'  
      GOTO QUIT  
   END
   IF ISNULL(RTRIM(UPPER(@c_Format)), '') <> 'JSON' 
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98992  
      SET @c_ErrMsg = 'Content body type must be JSON ' + @c_Format
      GOTO QUIT  
   END
   IF ISJSON(@c_RequestString) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98993  
      SET @c_ErrMsg = 'Content body is not valid JSON'  
      GOTO QUIT  
   END
   --Get PrintClientID from Request String JSON
   SELECT @c_ID                = ISNULL(RTRIM(ID),'')
        , @c_PrintClientID     = ISNULL(RTRIM(PrintClientID),'')
        , @c_ThreadID          = ISNULL(RTRIM(ThreadID),'')
        , @c_MsgRecvDate       = ISNULL(RTRIM(MsgRecvDate),'')
        , @c_ThreadStartTime   = ISNULL(RTRIM(ThreadStartTime),'')
        , @c_ThreadEndTime     = ISNULL(RTRIM(ThreadEndTime),'')
        , @c_TaskStatus        = ISNULL(RTRIM(TaskStatus),'')
        , @c_TaskErrMsg        = ISNULL(RTRIM(TaskErrMsg),'')
   FROM OPENJSON (@c_RequestString)  
   WITH (    
         ID                NVARCHAR(20)   '$.Request.ID',
         PrintClientID     NVARCHAR(100)  '$.Request.PrintClientID',
         ThreadID          NVARCHAR(20)   '$.Request.ThreadID',
         MsgRecvDate       NVARCHAR(23)   '$.Request.MsgRecvDate',
         ThreadStartTime   NVARCHAR(23)   '$.Request.ThreadStartTime',
         ThreadEndTime     NVARCHAR(23)   '$.Request.ThreadEndTime',
         TaskStatus        NVARCHAR(1)    '$.Request.Status',
         TaskErrMsg        NVARCHAR(1000) '$.Request.ErrMsg'
   )
   IF ISNUMERIC(@c_ID) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid ID or non-numeric'  
      GOTO QUIT  
   END
   IF @c_PrintClientID = ''
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid PrintClientID'  
      GOTO QUIT  
   END
   IF ISDATE(@c_MsgRecvDate) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid MsgRecvDate or non-date format'  
      GOTO QUIT  
   END
   IF ISDATE(@c_ThreadStartTime) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid ThreadStartTime or non-date format'  
      GOTO QUIT  
   END
   IF ISDATE(@c_ThreadEndTime) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid ThreadEndTime or non-date format'  
      GOTO QUIT  
   END 
   --IF ISNUMERIC(@c_Try) = 0
   --BEGIN
   --   SET @n_Continue = 3   
   --   SET @b_Success = 0
   --   SET @n_ErrNo = 98994  
   --   SET @c_ErrMsg = 'Invalid Try count or non-numeric'  
   --   GOTO QUIT  
   --END
   /*******************************************
    *  Start update QueueTask table
    *******************************************/
   IF @c_TaskStatus = '1'
   BEGIN
      UPDATE dbo.CloudPrintTask WITH (ROWLOCK)
      SET  ThreadID = @c_ThreadID
         , MsgRecvDate = @c_MsgRecvDate 
         , ThreadStartTime = @c_ThreadStartTime, ThreadEndTime= NULL 
         , EditDate = GETDATE(), EditWho = SUSER_SNAME()
      WHERE ID = @c_ID  
      AND PrintClientID = @c_PrintClientID;  
      SET @n_StartCnt = @@ROWCOUNT 
   END
   ELSE 
   BEGIN
      BEGIN TRANSACTION
      INSERT INTO dbo.CloudPrintTask_Log  
      (ID, PrintClientID, CmdType, B64Command, B64FileSrc, IP, Port, Timeout ,PrinterName, RefDocType, RefDocID, RefJobID, RefDesc 
      , Priority, ThreadId, [Status], ErrMsg, [Try], MsgRecvDate, ThreadStartTime, ThreadEndTime
      , PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate, PrintCopy, MoveToArchive 
      , AddDate, AddWho, EditDate, EditWho) 
      SELECT ID, PrintClientID, CmdType, B64Command, B64FileSrc, IP, Port, Timeout, PrinterName, RefDocType, RefDocID, RefJobID, RefDesc 
      , Priority, ThreadId = @c_ThreadId, [Status] = @c_TaskStatus, ErrMsg = @c_TaskErrMsg, [Try] = [Try] + 1
      , MsgRecvDate = @c_MsgRecvDate, ThreadStartTime = @c_ThreadStartTime, ThreadEndTime = @c_ThreadEndTime 
      , PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate, PrintCopy, MoveToArchive 
      , AddDate, AddWho, EditDate = GETDATE(), EditWho = SUSER_SNAME() 
      FROM dbo.CloudPrintTask WITH (NOLOCK)  
      WHERE ID = @c_ID  
      AND PrintClientID = @c_PrintClientID  
      SET @n_StartCnt = @@ROWCOUNT;   
      IF @@ERROR = 0 AND @n_StartCnt = 1   
      BEGIN   
         DELETE FROM CloudPrintTask  
         WHERE ID = @c_ID;  
         COMMIT TRANSACTION;   
      END 
      ELSE  
      BEGIN  
         ROLLBACK TRANSACTION; 
      END 
   END 
   IF @@ERROR <> 0
   BEGIN
		SET @n_Continue = 3   
      SET @b_Success = 0
      SET @n_ErrNo = 98995  
      SET @c_ErrMsg  = 'Failed to Update CloudPrintConfig!'
      GOTO QUIT  
   END
   QUIT:
   SET @c_ResponseString = '{"Success":"' + CONVERT(NVARCHAR(1),@b_Success) + '", "ErrNo":"' + CONVERT(NVARCHAR(10),@n_ErrNo)  + '", "ErrMsg":"' + @c_ErrMsg + '"}'
END -- procedure

GO