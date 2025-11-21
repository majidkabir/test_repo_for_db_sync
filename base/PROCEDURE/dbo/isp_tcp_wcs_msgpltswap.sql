SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgPltSwap                              */  
/* Creation Date: 30 Oct 2014                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Sub StorProc that Generate Outbound/Respond Message to WCS  */  
/*          OR Process Inbound/Respond Message from WCS                 */  
/*                                                                      */  
/* Called By: isp_TCP_WCS_MsgProcess                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK01)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgPltSwap]  
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TSKUPD'  etc....  
   , @c_MessageType     NVARCHAR(15)   = ''  --'SEND', 'RECEIVE'  
   , @c_TaskDetailKey   NVARCHAR(10)   = ''    
   , @n_SerialNo        INT            = '0'  --Serial No from TCPSocket_InLog for @c_MessageType = 'RECEIVE'  
   , @c_WCSMessageID    NVARCHAR(10)   = ''  
   , @c_OrigMessageID   NVARCHAR(10)   = ''  
   , @c_PalletID        NVARCHAR(18)   = ''  --PalletID  
   , @c_FromLoc         NVARCHAR(10)   = ''  --From Loc  
   , @c_ToLoc           NVARCHAR(10)   = ''  --To Loc (Blank for 'PUTAWAY')  
   , @c_Priority        NVARCHAR(1)    = ''  --for 'MOVE' and 'TSKUPD' message  
   , @c_RespStatus      NVARCHAR(10)   = ''  --for responce from WCS  
   , @c_RespReasonCode  NVARCHAR(10)   = ''  --for responce from WCS  
   , @c_RespErrMsg      NVARCHAR(100)  = ''  --for responce from WCS  
   , @c_UD1             NVARCHAR(20)   = ''  --PhotoReq / TaskUpdCode / MotherPltEmpty / PrintID / ToPallet  
   , @c_UD2             NVARCHAR(20)   = ''  --LabelReq / Weight  
   , @c_UD3             NVARCHAR(20)   = ''  --Storer / Height  
   , @c_UD4             NVARCHAR(20)   = ''  
   , @c_UD5             NVARCHAR(20)   = ''  
   , @c_Param1          NVARCHAR(20)   = ''  --PAway_SKU1  / EPS_Pallet1   
   , @c_Param2          NVARCHAR(20)   = ''  --PAway_SKU2  / EPS_Pallet2   
   , @c_Param3          NVARCHAR(20)   = ''  --PAway_SKU3  / EPS_Pallet3   
   , @c_Param4          NVARCHAR(20)   = ''  --PAway_SKU4  / EPS_Pallet4   
   , @c_Param5          NVARCHAR(20)   = ''  --PAway_SKU5  / EPS_Pallet5   
   , @c_Param6          NVARCHAR(20)   = ''  --PAway_SKU6  / EPS_Pallet6   
   , @c_Param7          NVARCHAR(20)   = ''  --PAway_SKU7  / EPS_Pallet7   
   , @c_Param8          NVARCHAR(20)   = ''  --PAway_SKU8  / EPS_Pallet8   
   , @c_Param9          NVARCHAR(20)   = ''  --PAway_SKU9  / EPS_Pallet9   
   , @c_Param10         NVARCHAR(20)   = ''  --PAway_SKU10 / EPS_Pallet10  
   , @c_CallerGroup     NVARCHAR(30)   = 'OTH'  --CallerGroup  
   , @b_debug           INT            = 0  
   , @b_Success         INT            OUTPUT  
   , @n_Err             INT            OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  OUTPUT  
  
  
AS   
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration         */  
   /*********************************************/  
   DECLARE @n_continue           INT                  
         , @c_ExecStatements     NVARCHAR(4000)       
         , @c_ExecArguments      NVARCHAR(4000)   
         , @n_StartTCnt          INT  
  
   DECLARE @c_Application        NVARCHAR(50)  
         , @c_Status             NVARCHAR(1)  
         , @n_NoOfTry            INT  
  
   DECLARE @c_IniFilePath        NVARCHAR(100)  
         , @c_SendMessage        NVARCHAR(MAX)  
         , @c_LocalEndPoint      NVARCHAR(50)   
         , @c_RemoteEndPoint     NVARCHAR(50)   
         , @c_ReceiveMessage     NVARCHAR(MAX)  
         , @c_vbErrMsg           NVARCHAR(MAX)  
  
   DECLARE @c_MessageGroup       NVARCHAR(20)     
         , @c_StorerKey          NVARCHAR(15)     
         , @c_MessageID          NVARCHAR(10)     
         , @n_TmpSerialNo        INT   
  
   SET @n_StartTCnt              = @@TRANCOUNT  
   SET @n_continue               = 1   
   SET @c_ExecStatements         = ''   
   SET @c_ExecArguments          = ''  
   SET @b_Success                = '1'  
   SET @n_Err                    = 0  
   SET @c_ErrMsg                 = ''  
  
   SET @c_MessageGroup           = 'WCS'  
   SET @c_StorerKey              = ''  
   SET @c_Application            = 'GenericTCPSocketClient_WCS'  
   SET @c_Status                 = '9'  
   SET @n_NoOfTry                = 0  
  
   /*********************************************/  
   /* Prep TCPSocketClient                      */  
   /*********************************************/     
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      SELECT @c_RemoteEndPoint = Long, @c_IniFilePath = UDF01  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = 'TCPClient'  
        AND CODE     = 'WCS'  
        AND SHORT    = 'IN'  
        AND CODE2    = @c_CallerGroup      --TK01  
  
      IF ISNULL(@c_RemoteEndPoint,'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57901    
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldWCSSvrIP'   
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgPltSwap)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57902    
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldCfgFPath'   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgPltSwap)'    
         GOTO QUIT   
      END  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'INIT DATA'  
            ,@c_IniFilePath      [@c_IniFilePath]  
            ,@c_RemoteEndPoint   [@c_RemoteEndPoint]   
            ,@c_MessageName      [@c_MessageName]  
            ,@c_MessageType      [@c_MessageType]  
            ,@c_WCSMessageID     [@c_WCSMessageID]  
            ,@c_OrigMessageID    [@c_OrigMessageID]  
            ,@c_PalletID         [@c_PalletID]  
            ,@c_FromLoc          [@c_FromLoc]  
            ,@c_ToLoc            [@c_ToLoc]  
            ,@c_Priority         [@c_Priority]  
            ,@c_RespStatus       [@c_RespStatus]  
            ,@c_RespReasonCode   [@c_RespReasonCode]  
            ,@c_RespErrMsg       [@c_RespErrMsg]  
            ,@c_UD1              [@c_UD1]  
            ,@c_UD2              [@c_UD2]  
            ,@c_UD3              [@c_UD3]  
            ,@c_UD4              [@c_UD4]  
            ,@c_UD5              [@c_UD5]  
            ,@c_Param1           [@c_Param1]  
            ,@c_Param2           [@c_Param2]  
            ,@c_Param3           [@c_Param3]  
            ,@c_Param4           [@c_Param4]  
            ,@c_Param5           [@c_Param5]  
            ,@c_Param6           [@c_Param6]  
            ,@c_Param7           [@c_Param7]  
            ,@c_Param8           [@c_Param8]  
            ,@c_Param9           [@c_Param9]  
            ,@c_Param10          [@c_Param10]  
   END  
  
   /*********************************************/  
   /* Validation      */  
   /*********************************************/  
   IF ISNULL(RTRIM(@c_MessageName),'') = ''  
   BEGIN  
      SET @n_continue = 3  
      SET @n_Err = 57903  
      SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgName'   
                    + ': MessageName cannot be blank. (isp_TCP_WCS_MsgPltSwap)'  
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_MessageType),'') = ''  
   BEGIN  
      SET @n_continue = 3  
      SET @n_Err = 57904  
      SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgType'   
                    + ': MessageType cannot be blank. (isp_TCP_WCS_MsgPltSwap)'  
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_PalletID),'') = ''  
   BEGIN  
      SET @n_continue = 3  
      SET @n_Err = 57905  
      SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldFromID'   
                    + ': PalletID cannot be blank. (isp_TCP_WCS_MsgPltSwap)'  
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_UD1),'') = ''  
   BEGIN  
      SET @n_continue = 3  
      SET @n_Err = 57906  
      SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldToID'   
                    + ': ToPallet cannot be blank. (isp_TCP_WCS_MsgPltSwap)'  
      GOTO QUIT  
   END  
  
   IF @c_MessageType = 'RECEIVE'  
   BEGIN  
      IF ISNULL(RTRIM(@c_OrigMessageID),'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57907  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldOriMsgID'   
                       + ': OrigMessageID cannot be blank. (isp_TCP_WCS_MsgMove)'  
         GOTO QUIT  
      END  
  
   END  
  
   /*********************************************/  
   /* INSERT INTO WCSTran                       */  
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
  
      --Prepare temp table to store MessageID  
      IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
         DROP TABLE #TmpTblMessageID  
      CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
      INSERT INTO WCSTran (MessageName, MessageType, PalletID, UD1)  
      OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
      VALUES (@c_MessageName, @c_MessageType, @c_PalletID, @c_UD1)  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=57908     
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsWCSTran'   
                       + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgPltSwap)'   
                       + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
         GOTO QUIT  
      END  
  
      -- Get MessageID from Temp table #TmpTblMessageID  
      SELECT TOP 1 @c_MessageID = ISNULL(RTRIM(MessageID),'')  
      FROM #TmpTblMessageID  
  
      SET @c_MessageID = RIGHT( REPLICATE('0', 9) + RTRIM(LTRIM(@c_MessageID)), 10)  
        
      SET @c_SendMessage = '<STX>'                                                --[STX]  
                        + LEFT(LTRIM(@c_MessageID)    + REPLICATE(' ',10) ,10)    --[MessageID]  
                        + LEFT(LTRIM(@c_MessageName)  + REPLICATE(' ',15) ,15)    --[MessageName]  
                        + LEFT(LTRIM(@c_PalletID)     + REPLICATE(' ',18) ,18)    --[FromPallet]  
                        + LEFT(LTRIM(@c_UD1)          + REPLICATE(' ',18) ,18)    --[ToPallet]  
                        + '<ETX>'                                                 --[ETX]  
  
      IF @b_Debug = 1    
      BEGIN    
         SELECT 'MESSAGE DATA'  
               , @c_MessageID      [@c_MessageID]  
               , @c_MessageName    [@c_MessageName]  
               , @c_MessageType    [@c_MessageType]  
               , @c_Application    [@c_Application]  
               , @c_IniFilePath    [@c_IniFilePath]  
               , @c_RemoteEndPoint [@c_RemoteEndPoint]  
               , @c_SendMessage    [@c_SendMessage]  
           
         SELECT 'MESSAGE VIEW'  
               , SUBSTRING(@c_SendMessage,  1,  5) [STX]  
               , SUBSTRING(@c_SendMessage,  6, 10) [MessageID]  
           , SUBSTRING(@c_SendMessage, 16, 15) [MessageName]  
               , SUBSTRING(@c_SendMessage, 31, 18) [FromPallet]  
               , SUBSTRING(@c_SendMessage, 49, 18) [ToPallet]  
               , SUBSTRING(@c_SendMessage, 67,  5) [ETX]  
      END    
  
      /*********************************************/  
      /* EXEC isp_GenericTCPSocketClient           */  
      /*********************************************/  
      --Prepare temp table to store MessageID  
      IF OBJECT_ID('tempdb..#TmpTblSerialNo') IS NOT NULL  
         DROP TABLE #TmpTblSerialNo  
      CREATE TABLE #TmpTblSerialNo(SerialNo INT)  
  
      SET @n_NoOfTry = 1  
  
      WHILE @n_NoOfTry <= 3  
      BEGIN  
         SET @c_vbErrMsg = ''  
         SET @c_ReceiveMessage = ''  
  
         /*********************************************/  
         /* INSERT INTO TCPSocket_OUTLog              */  
         /*********************************************/  
         TRUNCATE TABLE #TmpTblSerialNo  
         -- Insert TCP SEND message  
         INSERT INTO TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey, NoOfTry, ErrMsg, ACKData )  
         OUTPUT INSERTED.SerialNo INTO #TmpTblSerialNo  
         VALUES (@c_Application, @c_LocalEndPoint, @c_RemoteEndPoint, @c_MessageID, 'SEND', @c_SendMessage, @c_Status, @c_StorerKey, @n_NoOfTry, '', '')  
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_Err = 57912    
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTcpOutLg'   
                           + ': INSERT TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgPltSwap)'    
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT    
         END  
  
         EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
               @c_IniFilePath,  
               @c_RemoteEndPoint,  
               @c_SendMessage,  
               @c_LocalEndPoint        OUTPUT,  
               @c_ReceiveMessage       OUTPUT,  
               @c_vbErrMsg             OUTPUT  
        
         /*********************************************/  
         /* UPDATE TCPSocket_OUTLog                   */  
         /*********************************************/  
         -- Get MessageID from Temp table #TmpTblMessageID  
         SELECT TOP 1 @n_TmpSerialNo = ISNULL(RTRIM(SerialNo),'0')  
         FROM #TmpTblSerialNo  
  
         UPDATE TCPSocket_OUTLog WITH (ROWLOCK)  
         SET LocalEndPoint = @c_LocalEndPoint, ErrMsg = @c_vbErrMsg, ACKData = @c_ReceiveMessage, EditDate = GETDATE(), EditWho = SUSER_SNAME()  
         WHERE SerialNo = @n_TmpSerialNo  
                    
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_Err = 57909    
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTcpOutLg'   
                           + ': UPDATE TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgPutaway)'    
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT    
         END  
  
         IF NOT (ISNULL(RTRIM(@c_ReceiveMessage),'') = '' OR LEFT(ISNULL(@c_vbErrMsg,''),74) = 'No connection could be made because the target machine actively refused it')  
         BEGIN  
            SET @n_NoOfTry = 4  
         END  
  
         SET @n_NoOfTry = @n_NoOfTry + 1  
  
      END   --WHILE @n_NoOfTry <= 3  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'WCS_RETURN', @c_vbErrMsg [@c_vbErrMsg], @c_ReceiveMessage [@c_ReceiveMessage]  
      END  
  
      IF ISNULL(@c_vbErrMsg,'') <> '' OR ISNULL(RTRIM(@c_ReceiveMessage),'') = ''  
      BEGIN    
  
         SET @c_Status = '5'    
         SET @n_continue = 3    
         SET @n_Err = 57910  
  
         -- SET @cErrmsg    
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrExeTcpClnt'   
                           + ': EXEC isp_GenericTCPSocketClient Fail. (isp_TCP_WCS_MsgPutaway)'    
          + ' sqlsvr message=' + ISNULL(RTRIM(CAST(@c_VBErrMsg AS NVARCHAR(250))), '')  
                 
      END  
      ELSE     --TCP Socket success  
      BEGIN  
  
         SET @c_RespStatus       = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 37,  10)), '9')  
         SET @c_RespReasonCode   = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 47,  10)), '')  
         SET @c_RespErrMsg       = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 57, 100)), '')  
  
         UPDATE WCSTran WITH (ROWLOCK) SET Status = @c_RespStatus, ReasonCode = @c_RespReasonCode, ErrMsg = @c_RespErrMsg  
         WHERE MessageID = CONVERT(INT, @c_MessageID)  
                 
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 57911     
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdWCSTran1'   
                           + ': Update WCSTran Fail. (isp_TCP_WCS_MsgPutaway)'  
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         --Quit and return errors when respond status <> 9  
         IF @c_RespStatus <> '9' and @c_RespReasonCode <> ''  
         BEGIN  
            SET @c_Status = '5'   
            SET @n_continue = 3    
            SET @n_Err = 58600  
  
            -- SET @cErrmsg    
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^WCSRespndedErr'   
                           + ': WCS Responded error. ' + ISNULL(RTRIM(@c_RespReasonCode), '') + '-' + ISNULL(RTRIM(@c_RespErrMsg), '')   
  
            --(TK04) - Use a convertion sp to ease handle more WCS errors.  
            EXECUTE isp_ConvertErrWCSToRDT   
               'isp_TCP_WCS_MsgPutaway'  
               , @c_RespReasonCode  
               , @c_RespErrMsg  
               , 0  
               , @b_Success        OUTPUT  
               , @n_Err            OUTPUT  
               , @c_ErrMsg         OUTPUT  
  
         END  
         ELSE  
         BEGIN  
  
            UPDATE PalletLabel WITH (ROWLOCK) SET ID = @c_UD1 WHERE ID = @c_PalletID AND Status = '0'  
  
         END  
  
      END  
  
   END  
  
   QUIT:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
     
      IF @n_IsRDT = 1  
      BEGIN  
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here  
         -- Instead we commit and raise an error back to parent, let the parent decide  
     
         -- Commit until the level we begin with  
         --WHILE @@TRANCOUNT > @n_StartTCnt  
         --   COMMIT TRAN  
     
         -- Raise error with severity = 10, instead of the default severity 16.   
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger  
         RAISERROR (@n_err, 10, 1) WITH SETERROR   
     
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten  
      END  
      ELSE  
      BEGIN  
         --IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
         --BEGIN  
         --   ROLLBACK TRAN  
         --END  
         --ELSE  
         --BEGIN  
         --   WHILE @@TRANCOUNT > @n_StartTCnt  
         --   BEGIN  
         --      COMMIT TRAN  
         --   END  
         --END  
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TCP_WCS_MsgPltSwap'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      --WHILE @@TRANCOUNT > @n_StartTCnt  
      --BEGIN  
      --   COMMIT TRAN  
      --END  
      RETURN  
   END  
  
  
  
END  

GO