SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgInvQuery                             */  
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
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK02)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgInvQuery]  
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TSKUPD'  etc....  
   , @c_MessageType     NVARCHAR(15)   = ''  --'SEND', 'RECEIVE'  
   , @c_TaskDetailKey   NVARCHAR(10)   = ''    
   , @n_SerialNo        INT            = '0'  --Serial No from TCPSocket_InLog for @c_MessageType = 'RECEIVE'  
   , @c_WCSMessageID    NVARCHAR(10)   = ''  
   , @c_OrigMessageID   NVARCHAR(10)   = ''  
   , @c_PalletID        NVARCHAR(18)   = ''  --PalletID  
   , @c_FromLoc         NVARCHAR(10)   = ''  --From Loc (Optional: Blank when calling out from ASRS)  
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
   , @b_debug           INT            = '0'  
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
   /* Variables Declaration                     */  
   /*********************************************/  
   DECLARE @n_continue           INT                  
         , @c_ExecStatements     NVARCHAR(4000)       
         , @c_ExecArguments      NVARCHAR(4000)   
      
  
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
        AND CODE2    = @c_CallerGroup      --TK02  
  
      IF ISNULL(@c_RemoteEndPoint,'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68002    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgInvQuery)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68003    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgInvQuery)'    
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
            ,@c_TaskDetailKey    [@c_TaskDetailKey]  
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
   /* Validation                                */  
   /*********************************************/  
   IF @c_MessageType = 'SEND'  
   BEGIN  
      IF ISNULL(RTRIM(@c_MessageName),'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68011  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': MessageName cannot be blank. (isp_TCP_WCS_MsgInvQuery)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_MessageType),'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68012  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': MessageType cannot be blank. (isp_TCP_WCS_MsgInvQuery)'  
         GOTO QUIT  
      END  
  
      IF (ISNULL(RTRIM(@c_PalletID),'') = '' AND ISNULL(RTRIM(@c_FromLoc),'') = '')  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68013  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': Both PalletID and Loc cannot be blank. (isp_TCP_WCS_MsgInvQuery)'  
         GOTO QUIT  
      END  
  
      IF (ISNULL(RTRIM(@c_PalletID),'') <> '' AND ISNULL(RTRIM(@c_FromLoc),'') <> '')  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': Either PalletID Or Loc must be empty. (isp_TCP_WCS_MsgInvQuery)'  
         GOTO QUIT  
      END  
   END  
   ELSE  --IF @c_MessageType = 'RECEIVE'  
   BEGIN  
      IF ISNULL(RTRIM(@c_OrigMessageID),'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68015  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': OrigMessageID cannot be blank. (isp_TCP_WCS_MsgMove)'  
         GOTO QUIT  
      END  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      /*********************************************/  
      /* MessageType = 'SEND'                      */  
      /*********************************************/  
      IF @c_MessageType = 'SEND'  
      BEGIN  
  
         /*********************************************/  
         /* INSERT INTO WCSTran                       */  
         /*********************************************/  
         --Prepare temp table to store MessageID  
         IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
            DROP TABLE #TmpTblMessageID  
         CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
         INSERT INTO WCSTran (MessageName, MessageType, PalletID, FromLoc)  
         OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
         VALUES (@c_MessageName, @c_MessageType, @c_PalletID, @c_FromLoc)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_err=68021     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgInvQuery)'   
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
                           + LEFT(LTRIM(@c_PalletID)     + REPLICATE(' ',18) ,18)    --[PalletID]  
                           + LEFT(LTRIM(@c_FromLoc)      + REPLICATE(' ',10) ,10)    --[Loc]  
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
                  , SUBSTRING(@c_SendMessage, 31, 18) [PalletID]  
                  , SUBSTRING(@c_SendMessage, 49, 10) [Loc]  
                  , SUBSTRING(@c_SendMessage, 59,  5) [ETX]  
         END  
  
  
         /*********************************************/  
         /* INSERT INTO TCPSocket_OUTLog              */  
         /*********************************************/  
         IF OBJECT_ID('tempdb..#TmpTblSerialNo') IS NOT NULL  
            DROP TABLE #TmpTblSerialNo  
         CREATE TABLE #TmpTblSerialNo(SerialNo INT)  
  
         -- Insert TCP SEND message  
         INSERT INTO TCPSocket_OUTLog ([Application], RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey)  
         OUTPUT INSERTED.SerialNo INTO #TmpTblSerialNo  
         VALUES (@c_Application, @c_RemoteEndPoint, @c_MessageID, 'SEND', @c_SendMessage, @c_Status, @c_StorerKey)  
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @b_Success = 0    
            SET @n_Err = 68022    
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                          + ': Error inserting into TCPSocket_OUTLog Table. (isp_TCP_WCS_MsgInvQuery)'    
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO Quit    
         END    
  
         -- Get SeqNo    
         SELECT @n_SerialNo = SerialNo    
         FROM #TmpTblSerialNo    
  
         EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
            @c_IniFilePath,  
            @c_RemoteEndPoint,  
            @c_SendMessage,  
            @c_LocalEndPoint        OUTPUT,  
            @c_ReceiveMessage       OUTPUT,  
            @c_vbErrMsg             OUTPUT  
  
         IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> ''    
         BEGIN    
            SET @c_Status = '5'    
            SET @b_Success = 0  
            SET @n_Err = 68023   
  
            -- SET @cErrmsg    
            IF ISNULL(@c_VBErrMsg,'') <> ''    
            BEGIN    
               SET @c_Errmsg = CAST(@c_VBErrMsg AS NVARCHAR(250))    
            END    
            ELSE    
            BEGIN    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                             + ': Error executing isp_GenericTCPSocketClient. (isp_TCP_WCS_MsgInvQuery)'    
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            END    
         END    
  
         -- SET NoOfTry to 3 to avoid schedule job from reprocessing the message  
         IF @c_Status = '5'  
         BEGIN  
            SET @n_NoOfTry = 3  
         END  
         ELSE  
         BEGIN  
            -- INSERT TCP RECEIVE message  
            INSERT INTO TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey)  
            VALUES (@c_Application, @c_LocalEndPoint, @c_RemoteEndPoint, @c_MessageID, 'RECEIVE', @c_ReceiveMessage, '9', @c_StorerKey)  
  
            IF @@ERROR <> 0    
            BEGIN    
               SET @b_Success = 0    
               SET @n_Err = 68024    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                             + ': Error inserting into TCPSocket_OUTLog. (isp_TCP_WCS_MsgInvQuery)'    
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO Quit    
            END    
  
         END  
        
         -- Update TCP SEND message  
         UPDATE TCPSocket_OUTLog WITH (ROWLOCK)  
         SET LocalEndPoint = @c_LocalEndPoint, Status = @c_Status, ErrMsg = @c_Errmsg, NoOfTry = @n_NoOfTry  
         WHERE SerialNo = @n_SerialNo   
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @b_Success = 0    
            SET @n_Err = 68025  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                          + ': Error updating into TCPSocket_OUTLog. (isp_TCP_WCS_MsgInvQuery)'    
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO Quit    
         END    
  
      END   --IF @c_MessageType = 'SEND'  
  
      /*********************************************/  
      /* MessageType = 'RECEIVE'                   */  
      /*********************************************/  
      IF @c_MessageType = 'RECEIVE'  
      BEGIN  
         SELECT @c_MessageID     = SUBSTRING(Data,  1,  10),  
                @c_MessageName   = SUBSTRING(Data, 11,  15),  
                @c_OrigMessageID = SUBSTRING(Data, 26,  10),  
                @c_PalletID      = SUBSTRING(Data, 36,  18),  
                @c_ToLoc         = SUBSTRING(Data, 54,  10),  
                @c_RespStatus    = SUBSTRING(Data, 64,  10),  
                @c_RespReasonCode= SUBSTRING(Data, 74,  10),  
                @c_RespErrMsg    = SUBSTRING(Data, 84, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
         -- INSERT INTO WCSTran  
         INSERT INTO WCSTran (MessageName, MessageType, WCSMessageID, OrigMessageID, PalletID, ToLoc, Status, ReasonCode, ErrMsg)  
         VALUES (@c_MessageName, @c_MessageType, @c_MessageID, @c_OrigMessageID, @c_PalletID, @c_ToLoc, @c_RespStatus, @c_RespReasonCode, @c_RespErrMsg)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_err=68031     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                          + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgPutaway)'  
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
      END   --IF @c_MessageType = 'RECEIVE'  
   END   --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
   IF CURSOR_STATUS('LOCAL' , 'C_CUR_QRYLLI') in (0 , 1)  
   BEGIN  
      CLOSE C_CUR_QRYLLI  
      DEALLOCATE C_CUR_QRYLLI  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'C_CUR_UPDLLI') in (0 , 1)  
   BEGIN  
      CLOSE C_CUR_UPDLLI  
      DEALLOCATE C_CUR_UPDLLI  
   END  
     
   SELECT  @c_ErrMsg = @c_MessageID  
END  

GO