SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure: isp_WOL_Send2Printer                                */    
/* Creation Date: 01-Jul-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: YTKuek                                                   */    
/*                                                                      */    
/* Purpose:                                                             */   
/*                                                                      */     
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */     
/************************************************************************/    
    
CREATE PROC [dbo].[isp_WOL_Send2Printer](    
           @c_DataStream         NVARCHAR(10)    
         , @c_StorerKey          NVARCHAR(15)    
         , @c_ProgramPath        NVARCHAR(2000)  
         , @c_SourceFilePath     NVARCHAR(4000)  
         , @c_PrintSettingID     NVARCHAR(10)  
         , @c_PrintAction        NVARCHAR(2)  
         , @c_PrinterName        NVARCHAR(500)  
         , @c_RemoteIP           NVARCHAR(50)  
         , @c_RemotePort         NVARCHAR(10)  
         , @c_WSDTKey            NVARCHAR(10)  
         , @c_TargetDB           NVARCHAR(15)  
         , @c_IniFilePath        NVARCHAR(500)  
         , @b_Debug              INT     
         , @b_Success            INT             = 0   OUTPUT    
         , @n_Err                INT             = 0   OUTPUT    
         , @c_ErrMsg             NVARCHAR(250)   = ''  OUTPUT    
)    
AS      
BEGIN    
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF    
   SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   /********************************************/    
   /* Variables Declaration (Start)            */    
   /********************************************/    
   --General    
   DECLARE @c_Command         NVARCHAR(4000)  
         , @c_Data            NVARCHAR(4000)  
         , @n_QueueID         INT  
         , @c_DataReceived    NVARCHAR(MAX)  
         , @dt_StartTime      DATETIME  
         , @c_SourceDB        NVARCHAR(20)  
  
   -- Initialisation     
   SET @c_Command             = ''  
   SET @c_Data                = ''  
   SET @n_QueueID             = 0  
   SET @c_DataReceived        = ''  
   SET @c_SourceDB            = DB_NAME()  
   /********************************************/    
   /* Variables Declaration (End)              */    
   /********************************************/    
   /********************************************/    
   /* General Validation (Start)               */    
   /********************************************/    
   IF @b_Debug = 1    
   BEGIN    
      PRINT '[isp_WOL_PDFSend2Printer]: Start...'     
   END    
    
   IF @c_DataStream = ''     
   BEGIN      
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': Datastream is blank. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END    
  
   IF @c_ProgramPath = ''     
   BEGIN       
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': ProgramPath is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END    
  
   IF @c_PrintSettingID = ''     
   BEGIN        
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': PrintSettingID is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END   
  
   IF @c_PrintAction = ''     
   BEGIN      
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': PrintAction is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END   
  
   IF @c_PrinterName = ''     
   BEGIN      
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': PrinterName is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END   
  
   IF @c_TargetDB = ''     
   BEGIN      
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': TargetDB is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END   
  
   IF @c_IniFilePath = ''     
   BEGIN      
      SET @n_Err = 88501     
      SET @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5),@n_err)    
                    + ': IniFilePath is blank for Datastream = ' + @c_DataStream + '. (isp_WOL_PDFSend2Printer)'    
      GOTO QUIT    
   END   
   /********************************************/    
   /* General Validation (End)                 */    
   /********************************************/  
   /* Main Process (Start)                     */    
   /********************************************/    
  
   SET @c_Command = '"' + @c_ProgramPath + '" '  
                  + '"' + @c_SourceFilePath + '" '  
                  + '"' + @c_PrintSettingID + '" '  
                  + '"' + @c_PrintAction + '" '  
                  + '"' + @c_PrinterName + '"'  
  
  
   INSERT INTO TCPSocket_QueueTask  
   (  
     CmdType  
    ,Cmd  
    ,StorerKey  
    ,ThreadPerAcct  
    ,ThreadPerStream  
    ,MilisecondDelay  
    ,DataStream  
    ,TransmitlogKey  
    ,[Port]  
    ,TargetDB  
    ,[IP]  
   )  
   VALUES  
   (  
     'CMD'  
   , @c_Command  
   , @c_Storerkey  
   , 0  
   , 0  
   , 0  
   , @c_DataStream  
   , @c_WSDTKey  
   , @c_RemotePort  
   , @c_TargetDB  
   , @c_RemoteIP  
   )  
  
   SELECT @n_QueueID = @@IDENTITY, @n_Err = @@ERROR    
       
   IF @n_QueueID IS NULL OR @n_QueueID = 0     
   BEGIN    
      SET @c_ErrMsg = 'Insert into TCPSocket_QueueTask fail, Error# ' + CAST(@n_Err AS VARCHAR(10))    
      SET @b_Success = 0     
      GOTO QUIT     
   END     
  
   SET @c_Data = '<STX>'            
               + 'CMD' + '|'             
               + CAST(@n_QueueID AS VARCHAR(20)) + '|'             
               + RTRIM(@c_TargetDB) + '|'            
               + @c_Command          
               + '<ETX>'      
  
   SET @dt_StartTime = GETDATE()  
  
   EXEC isp_QCmd_SendTCPSocketMsg    
         @cApplication     = 'QCommander'    
       , @cStorerKey       = @c_StorerKey     
       , @cMessageNum      = ''    
       , @cData            = @c_Data    
       , @cIP              = @c_RemoteIP  
       , @cPORT            = @c_RemotePort  
       , @cIniFilePath     = @c_IniFilePath  
       , @cDataReceived    = @c_DataReceived  OUTPUT    
       , @bSuccess         = @b_Success       OUTPUT     
       , @nErr             = @n_Err           OUTPUT     
       , @cErrMsg          = @c_ErrMsg        OUTPUT    
    
   IF ISNULL(RTRIM(LTRIM(@c_ErrMsg)), '') <> ''    
   BEGIN    
      EXEC isp_QCmd_UpdateQueueTaskStatus  
            @cTargetDB         = @c_SourceDB  
           ,@nQTaskID          = @n_QueueID  
           ,@cQStatus          = '5'  
           ,@cThreadID         = ''  
           ,@cMsgRecvDate      = ''  
           ,@dThreadStartTime  = @dt_StartTime  
           ,@dThreadEndTime    = null  
           ,@cQErrMsg          = @c_ErrMsg  
           ,@bSuccess          = @b_Success OUTPUT  
           ,@nErr              = @n_Err     OUTPUT  
           ,@cErrMsg           = @c_ErrMsg  OUTPUT  
   END    
   ELSE  
   BEGIN    
      EXEC isp_QCmd_UpdateQueueTaskStatus  
            @cTargetDB         = @c_SourceDB  
           ,@nQTaskID          = @n_QueueID  
           ,@cQStatus          = '9'  
           ,@cThreadID         = ''  
           ,@cMsgRecvDate      = ''  
           ,@dThreadStartTime  = @dt_StartTime  
           ,@dThreadEndTime    = null  
           ,@cQErrMsg          = ''  
           ,@bSuccess          = @b_Success OUTPUT  
           ,@nErr              = @n_Err     OUTPUT  
           ,@cErrMsg           = @c_ErrMsg  OUTPUT  
   END    
  
   /********************************************/  
   /* Main Process (End)                       */    
   /********************************************/    
   /********************************************/  
   /* Std - Error Handling (Start)             */  
   /********************************************/   
   QUIT:  
     
   IF @b_Debug = 1  
   BEGIN  
      PRINT 'ErrMsg = ' + @c_ErrMsg  
   END  
   /********************************************/  
   /* Std - Error Handling (End)               */  
   /********************************************/  
END --End Procedure  

GO