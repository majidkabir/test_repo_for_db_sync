SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_WSM_SendTCPSpoolerCommand                       */    
/* Creation Date: 02 Jul 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: Alex Keoh                                                 */    
/*                                                                       */    
/* Purpose: Send Command to TCP Spooler                                  */    
/*                                                                       */    
/* Called By:                                                            */    
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 02-Jul-2019  Alex     1.0  Initial Development                        */  
/* 11-Jul-2019  Wan01    1.1  Check command against Codelkup             */
/*                            Add GetINI & SetINT command                */      
/* 03-10-2019   Shong    1.2  Check Parameter 3 for Set INI							 */   
/*************************************************************************/    
    
CREATE PROC [dbo].[isp_WSM_SendTCPSpoolerCommand]    
(    
   @c_IP          NVARCHAR(15)    
,  @c_Port        NVARCHAR(5)    
,  @c_Command     NVARCHAR(50)    
,  @c_Param1      NVARCHAR(100)  = ''    
,  @c_Param2      NVARCHAR(100)  = ''    
,  @c_Param3      NVARCHAR(100)  = ''    
,  @c_Param4      NVARCHAR(100)  = ''    
,  @c_Param5      NVARCHAR(100)  = ''    
,  @b_Success     INT            = 1   OUTPUT    
,  @n_Err         INT            = 0   OUTPUT    
,  @c_ErrMsg      NVARCHAR(256)  = ''  OUTPUT
,  @c_ACKMsg      NVARCHAR(1000) = ''  OUTPUT
)    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
             
   DECLARE @c_RemoteEndPoint     NVARCHAR(21)        
         , @c_SendMessage        NVARCHAR(1000)        
         , @c_LocalEndPoint      NVARCHAR(21)    
         --, @c_ReceiveMessage     NVARCHAR(1000)    
         , @c_vbErrMsg           NVARCHAR(1000)        
    
   SET @b_Success                = 1     
   SET @n_Err                    = 0     
   SET @c_ErrMsg                 = ''    
    
   SET @c_RemoteEndPoint         = ''    
   SET @c_SendMessage            = ''    
   SET @c_LocalEndPoint          = ''    
   --SET @c_ReceiveMessage         = ''    
   SET @c_vbErrMsg               = ''    
   SET @c_ACKMsg                 = ''
                                   
   SET @c_IP                     = ISNULL(RTRIM(@c_IP),'')    
   SET @c_Port                   = ISNULL(RTRIM(@c_Port),'')    
   SET @c_Command                = ISNULL(RTRIM(@c_Command),'')    
   SET @c_Param1                 = ISNULL(RTRIM(@c_Param1),'')    
   SET @c_Param2                 = ISNULL(RTRIM(@c_Param2),'')    
   SET @c_Param3                 = ISNULL(RTRIM(@c_Param3),'')    
   SET @c_Param4                 = ISNULL(RTRIM(@c_Param4),'')    
   SET @c_Param5                 = ISNULL(RTRIM(@c_Param5),'')    
    
   IF @c_IP = '' OR @c_Port = ''    
   BEGIN    
      SET @b_Success = 0;    
      SET @n_Err = 68001;    
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err)+ ': IP and Port cannot be blank! (isp_WSM_SendTCPSpoolerCommand)'    
      GOTO QUIT    
   END    
    
   IF NOT EXISTS (SELECT 1  
                  FROM CODELKUP CL WITH (NOLOCK)  
                  WHERE CL.ListName = 'TCPSplFunc'   
                  AND CL.Long Like @c_Command + '%'  
                  )     
   BEGIN    
      SET @b_Success = 0;    
      SET @n_Err = 68002;    
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err)+ ': Only these commands is allowed - StopListen, Restart, HeartBit, GetAllPrintTask, ClearAllTask, GetINIThread, SetINIThread, AutoVersionUpdate. (isp_WSM_SendTCPSpoolerCommand)'    
      GOTO QUIT    
   END    
    
   IF @c_Command = 'SetINIThread'
   BEGIN    
      IF @c_Param1 = '' OR ISNUMERIC(@c_Param1) <> 1
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68003;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param1 cannot be blank. Only numeric value is allowed. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      SET @c_SendMessage = @c_Command + '=' + @c_Param1
   END
   ELSE IF @c_Command = 'GetINI'
   BEGIN    
      IF @c_Param1 = ''  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68009;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param1 cannot be blank. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      IF @c_Param2 = ''  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68010;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param2 cannot be blank. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      SET @c_SendMessage = @c_Command + '[' + RTRIM(@c_Param1) + ']' + RTRIM(@c_Param2) + '=' + RTRIM(@c_Param3)
   END
   ELSE IF @c_Command = 'SetINI'
   BEGIN    
      IF @c_Param1 = ''  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68011;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param1 cannot be blank. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      IF @c_Param2 = ''  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68012;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param2 cannot be blank. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      IF @c_Param2 = 'MaxThreads'  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68013;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Use SetIniThread command to set. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END
      IF @c_Param3 = ''  
      BEGIN
         SET @b_Success = 0;    
         SET @n_Err = 68014;    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                       + ': Param3 cannot be blank. (isp_WSM_SendTCPSpoolerCommand)'   
         GOTO QUIT 
      END          
      SET @c_SendMessage = @c_Command + '[' + RTRIM(@c_Param1) + ']' + RTRIM(@c_Param2) + '=' + RTRIM(@c_Param3)
   END
   ELSE
   BEGIN
      SET @c_SendMessage = @c_Command
   END
    
    
   --Case "GetQueueStatus"         Call <STX>ACT|999|999|GetQueueStatus    <ETX>    
   --Case "GetThreadStatus"        Call <STX>ACT|999|999|GetThreadStatus   <ETX>    
   --Case "RestartListener"        Call <STX>ACT|999|999|RestartListener   <ETX>    
   --Case "GetPendingTask"         Call <STX>ACT|999|999|GetPendingTask    |Param1|Param2<ETX>  -- Param1 = "1" = Starting TaskID = "1"; Param2 = "0" = Filter by Status "0"    
   --Case "ClearTaskQueue"         Call <STX>ACT|999|999|ClearTaskQueue    |Param1<ETX>         -- Param1 = "1" = Trigger GetPendingTask(1 & R) ; "0" = Do not trigger GetPendingTask()    
   --Case "SetThreadManager"       Call <STX>ACT|999|999|SetThreadManager  |Param1<ETX>         -- Param1 = "1" = Hold AssignThread ; "0" = UnHold AssignThread     
   --Case "UpdThreadCount"         Call <STX>ACT|999|999|UpdThreadCount    |Param1<ETX>         -- Param1 = "X" = New desired thread count     
   --Case "RestartService"         Call <STX>ACT|999|999|RestartService    <ETX>    
    
   SET @c_RemoteEndPoint         = @c_IP + ':' + @c_Port    
   --SET @c_SendMessage            = '<STX>ACT|999|999|' + @c_Command + '|' + @c_Param1 + '|' + @c_Param2 + '|' + @c_Param3 + '|' + @c_Param4 + '|' + @c_Param5 + '<ETX>'    
   
   
   EXEC [master].[dbo].[isp_GenericTCPSocketClient]    
            @c_IniFilePath       = 'C:\COMObject\GenericTCPSocketClient\config.ini',    
            @c_RemoteEndPoint    = @c_RemoteEndPoint,    
            @c_SendMessage       = @c_SendMessage,    
            @c_LocalEndPoint     = @c_LocalEndPoint      OUTPUT,    
            @c_ReceiveMessage    = @c_ACKMsg             OUTPUT,    
            @c_vbErrMsg          = @c_vbErrMsg           OUTPUT    

   INSERT INTO TCPSocket_OUTLog
   (
      [Application],    LocalEndPoint,    RemoteEndPoint,
      MessageType,      [Data],           MessageNum,
      StorerKey,        BatchNo,          LabelNo,
      RefNo,            ErrMsg,           [Status],
      NoOfTry,          ACKData 
   )
   VALUES
   (
      'WSM-TCPSPOOLER',
      @c_LocalEndPoint,
      @c_RemoteEndPoint,
      'SEND',
      @c_SendMessage,
      'C000000000',
      '', -- StorerKey
      '', -- Batch No
      '', -- LabelNo
      '', -- RefNo
      @c_vbErrMsg, 
      CASE WHEN @c_vbErrMsg <> '' THEN '5' ELSE '9' END,
      0,
      @c_ACKMsg
   )    
          
   IF @@ERROR <> 0 OR  @c_vbErrMsg <> ''    
   BEGIN    
      SET @b_Success = 0;    
      SET @n_Err     = 68007;    
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(5) ,@n_err)+ ': Error sending TCPSocket message - ' + @c_vbErrMsg + ' (isp_WSM_SendTCPSpoolerCommand)'    
      GOTO QUIT    
   END    
    
   --Select  @c_LocalEndPoint   [@c_LocalEndPoint]     
   --      , @c_ACKMsg          [@c_ACKMsg]    
   --      , @c_vbErrMsg        [@c_vbErrMsg]    

   QUIT:                             
END -- End of Procedure

GO