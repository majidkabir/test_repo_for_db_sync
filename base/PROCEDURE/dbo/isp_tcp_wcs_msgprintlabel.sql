SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgPrintLabel                           */  
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
/* 02-Dec-2015  TKLIM     1.0   Redo flow for retry & rollback (TK01)   */  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK02)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgPrintLabel]  
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TSKUPD'  etc....  
   , @c_MessageType     NVARCHAR(15)   = ''  --'SEND', 'RECEIVE'  
   , @c_TaskDetailKey   NVARCHAR(10)   = ''    
   , @n_SerialNo        INT            = '0' --Serial No from TCPSocket_InLog for @c_MessageType = 'RECEIVE'  
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
   , @c_Param5          NVARCHAR(20)   = ''  --PAway_SKU5 / EPS_Pallet5   
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
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration                     */  
   /*********************************************/  
   DECLARE @n_continue        INT                  
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
         , @c_SKU                NVARCHAR(20)     
         , @c_MessageID          NVARCHAR(10)     
         , @c_PrinterID          NVARCHAR(10)     
         , @c_PrintLoc           NVARCHAR(10)     
         , @c_Weight             NVARCHAR(10)     
         , @c_Height             NVARCHAR(10)     
         , @n_SkuCount           INT    
         , @c_parm01             NVARCHAR(10)     
         , @c_parm02             NVARCHAR(10)     
         , @c_parm03             NVARCHAR(10)     
         , @c_parm04             NVARCHAR(10)     
  
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
   SET @c_PrintLoc               = 0  
   SET @c_PrinterID              = 0  
  
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
         SET @n_continue = 3  
         SET @n_Err = 68002    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgPrintLabel)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 68003    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgPrintLabel)'    
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
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      IF @n_SerialNo = '0'  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 68011  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
  
      SELECT @c_MessageID     = SUBSTRING(Data,  1,  10)  
           , @c_MessageName   = SUBSTRING(Data, 11,  15)  
           , @c_PalletID      = SUBSTRING(Data, 26,  18)  
           , @c_PrintLoc      = SUBSTRING(Data, 44,  10)  
           , @c_Weight        = SUBSTRING(Data, 54,  10)  
           , @c_Height        = SUBSTRING(Data, 64,  10)  
      FROM TCPSOCKET_INLOG WITH (NOLOCK)  
      WHERE SerialNo = @n_SerialNo  
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT @c_MessageID     [@c_MessageID]  
              , @c_MessageName   [@c_MessageName]  
              , @c_PalletID      [@c_PalletID]  
              , @c_PrintLoc      [@c_PrintLoc]  
              , @c_Weight        [@c_Weight]  
              , @c_Height        [@c_Height]  
      END  
  
  
      IF ISNULL(RTRIM(@c_MessageName),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @n_continue = 3  
         SET @n_Err = 68012  
         SET @c_ErrMsg = 'MessageName cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_PalletID),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @n_continue = 3  
         SET @n_Err = 68013  
         SET @c_ErrMsg = 'PalletID cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
     
      IF ISNULL(RTRIM(@c_PrintLoc),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @n_continue = 3  
         SET @n_Err = 68014  
         SET @c_ErrMsg = '@c_PrintLoc cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
     
      IF ISNULL(RTRIM(@c_Weight),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @n_continue = 3  
         SET @n_Err = 68015  
         SET @c_ErrMsg = 'Weight cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
     
      IF ISNULL(RTRIM(@c_Height),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @n_continue = 3  
         SET @n_Err = 68016  
         SET @c_ErrMsg = 'Height cannot be blank. (isp_TCP_WCS_MsgPrintLabel)'  
         GOTO QUIT  
      END  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      IF @c_MessageType = 'RECEIVE'  
      BEGIN  
           
         -- INSERT INTO WCSTran  
         INSERT INTO WCSTran (MessageName, MessageType, WCSMessageID, PalletID, UD1, UD2, UD3)  
         VALUES (@c_MessageName, @c_MessageType, @c_MessageID, @c_PalletID, @c_PrintLoc, @c_Weight, @c_Height)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=68031     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                          + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgPrintLabel)'  
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         --Query ReceiptKey and ReceiptLineNo  
         --SELECT TOP 1  
         --        @c_parm01 = ReceiptKey  
         --      , @c_parm02 = ReceiptLineNumber  
         --      , @c_parm03 = @c_Height     --Height  
         --      , @c_parm04 = @c_Weight     --Weight  
         --FROM ReceiptDetail WITH (NOLOCK)  
         --WHERE ToID = @c_PalletID  
         --ORDER BY ReceiptKey DESC  
  
   SELECT TOP 1  
     @c_parm01 = a.HDKey  
     , @c_parm02 = a.DTKey  
     , @c_parm03 = @c_Height     --Height  
     , @c_parm04 = @c_Weight     --Weight      
   FROM PalletLabel a WITH (NOLOCK)      
   WHERE a.ID = @c_PalletID and a.Status ='0'  
   ORDER BY HDKey DESC  
     
     
  
         --select * from rdt.rdtprinter  
         --select * from dbo.BartenderCmdConfig (nolock)  
         --select * from dbo.BartenderLabelCfg (nolock)  
         --PRINT 'PRINTING!!!!!'  
         --PRINT '@c_parm01:' + @c_parm01  
         --PRINT '@c_parm02:' + @c_parm02  
         --PRINT '@c_parm03:' + @c_parm03  
         --PRINT '@c_parm04:' + @c_parm04  
      
         --Execute command to Bartender to print at PRINTER1.  
         SET @c_PrinterID = RTRIM(@c_PrintLoc) + '_01'  
         EXEC isp_BT_GenBartenderCommand @c_PrinterID, 'PALLETLABEL', 'CSC', @c_parm01, @c_parm02, @c_parm03, @c_parm04,'','','','','','','','1','1','Y',@n_err,@c_errmsg   
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=68032     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': EXEC isp_BT_GenBartenderCommand fail. (isp_TCP_WCS_MsgPrintLabel)'  
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         --Execute command to Bartender to print at PRINTER2.  
         SET @c_PrinterID = RTRIM(@c_PrintLoc) + '_02'  
         EXEC isp_BT_GenBartenderCommand @c_PrinterID, 'PALLETLABEL', 'CSC', @c_parm01, @c_parm02, @c_parm03, @c_parm04,'','','','','','','','1','1','Y',@n_err,@c_errmsg   
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=68033     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': EXEC isp_BT_GenBartenderCommand fail. (isp_TCP_WCS_MsgPrintLabel)'  
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         UPDATE PalletLabel SET Status = '9' WHERE ID = @c_PalletID AND HDKey = @c_parm01 AND DTKey = @c_parm02 AND Status = '0'  
  
  
         --Prepare respond back to WCS  
         /*********************************************/  
         /* INSERT INTO WCSTran                       */  
         /*********************************************/  
         SET @c_OrigMessageID = @c_MessageID   
  
         --Prepare temp table to store MessageID  
         IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
            DROP TABLE #TmpTblMessageID  
         CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
         INSERT INTO WCSTran (MessageName, MessageType, OrigMessageID, PalletID, UD1)  
         OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
         VALUES (@c_MessageName, 'SEND', @c_OrigMessageID, @c_PalletID, @c_PrintLoc)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=68041     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgPrintLabel)'  
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         -- Get MessageID from Temp table #TmpTblMessageID  
         SELECT TOP 1 @c_MessageID = ISNULL(RTRIM(MessageID),'')  
         FROM #TmpTblMessageID  
  
         SET @c_MessageID = RIGHT(REPLICATE('0', 9) + RTRIM(LTRIM(@c_MessageID)), 10)  
       
         SET @c_SendMessage = '<STX>'                                                     --[STX]  
                           + LEFT(LTRIM(@c_MessageID)       + REPLICATE(' ', 10) , 10)    --[MessageID]  
                           + LEFT(LTRIM(@c_MessageName)     + REPLICATE(' ', 15) , 15)    --[MessageName]  
                           + LEFT(LTRIM(@c_OrigMessageID)   + REPLICATE(' ', 10) , 10)    --[OrigMessageID]  
                           + LEFT(LTRIM(@c_PalletID)        + REPLICATE(' ', 18) , 18)    --[PalletID]  
                           + LEFT(LTRIM(@c_RespStatus)      + REPLICATE(' ', 10) , 10)    --[Status]  
                           + LEFT(LTRIM(@c_RespReasonCode)  + REPLICATE(' ', 10) , 10)    --[ReasonCode]  
                           + LEFT(LTRIM(@c_RespErrMsg)      + REPLICATE(' ',100) ,100)    --[ErrMsg]  
                           + '<ETX>'                                                      --[ETX]  
  
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
                  , SUBSTRING(@c_SendMessage,   1,  5) [STX]  
                  , SUBSTRING(@c_SendMessage,   6, 10) [MessageID]  
                  , SUBSTRING(@c_SendMessage,  16, 15) [MessageName]  
                  , SUBSTRING(@c_SendMessage,  31, 10) [OrigMessageID]  
                  , SUBSTRING(@c_SendMessage,  41, 18) [PalletID]  
                  , SUBSTRING(@c_SendMessage,  59, 10) [Status]  
                  , SUBSTRING(@c_SendMessage,  69, 10) [ReasonCode]  
                  , SUBSTRING(@c_SendMessage,  79, 10) [ErrMsg]  
  
         END   --@b_Debug = 1                                            
  
         /*********************************************/  
         /* EXEC isp_GenericTCPSocketClient           */  
         /*********************************************/  
         EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
               @c_IniFilePath  
            , @c_RemoteEndPoint  
            , @c_SendMessage  
            , @c_LocalEndPoint        OUTPUT  
            , @c_ReceiveMessage       OUTPUT  
            , @c_vbErrMsg             OUTPUT  
  
         IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> ''    
         BEGIN    
  
            SET @c_Status = '5'    
            SET @n_continue = 3    
            SET @n_Err = 68043  
  
            -- SET @cErrmsg    
            IF ISNULL(@c_VBErrMsg,'') <> ''    
            BEGIN    
               SET @c_Errmsg = CAST(@c_VBErrMsg AS NVARCHAR(250))    
            END    
            ELSE    
            BEGIN    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                              + ': Error executing isp_GenericTCPSocketClient. (isp_TCP_WCS_MsgPrintLabel)'    
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            END    
  
                 
            --Previous message has been rollback. Re-Insert a new WCSTran record for retry to work      --TK01  
            INSERT INTO WCSTran (MessageName, MessageType, OrigMessageID, PalletID, UD1, Status)  
            VALUES (@c_MessageName, 'SEND', @c_OrigMessageID, @c_PalletID, @c_PrintLoc, '0')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 68044  
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsWCSTran'   
                              + ': Insert WCSTran Fail. (isp_TCP_WCS_MsgPrintLabel)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
         END  
         ELSE    
         BEGIN  
  
            SET @c_RespStatus       = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 37,  10)), '9')  
            SET @c_RespReasonCode   = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 47,  10)), '')  
            SET @c_RespErrMsg       = ISNULL(RTRIM(SUBSTRING(@c_ReceiveMessage, 57, 100)), '')  
  
            UPDATE WCSTran SET Status = @c_RespStatus, ReasonCode = @c_RespReasonCode, ErrMsg = @c_RespErrMsg  
            WHERE MessageID = CONVERT(INT, @c_MessageID)  
            AND Status = '0'  
                 
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 68045     
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdWCSTran'   
                              + ': Update WCSTran Fail. (isp_TCP_WCS_MsgPltSwap)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
         END  
        
         /*********************************************/  
         /* INSERT INTO TCPSocket_OUTLog              */  
         /*********************************************/  
         -- Insert TCP SEND message  
         INSERT INTO TCPSocket_OUTLog ([Application], LocalEndPoint, RemoteEndPoint, MessageNum, MessageType, Data, Status, StorerKey, ErrMsg, ACKData )  
         VALUES (@c_Application, @c_LocalEndPoint, @c_RemoteEndPoint, @c_MessageID, 'SEND', @c_SendMessage, @c_Status, @c_StorerKey, @c_ErrMsg, @c_ReceiveMessage)  
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_Err = 57912    
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTcpOutLg'   
                           + ': INSERT TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgPltSwap)'    
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT    
         END  
  
      END   --IF @c_MessageType = 'RECEIVE'  
   END      --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
  
   IF @n_continue <> 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 1  
   END  
END  
  
  

GO