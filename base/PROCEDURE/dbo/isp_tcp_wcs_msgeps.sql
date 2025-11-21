SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/ 
/* Store procedure: isp_TCP_WCS_MsgEPS                                  */  
/* Creation Date: 30 Oct 2014                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Sub StorProc that Generate Outbound/Respond Message to WCS  */  
/*          OR Process Inbound/Respond Message from WCS                 */  
/*                                                                      */  
/* Note: For WCS => WMS messages, Basic blank value validation are      */  
/*       done in isp_TCP_WCS_MsgValidation                              */  
/*                                                                      */  
/* Called By: isp_TCP_WCS_MsgProcess                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Date        Author   Ver.  Purposes                                  */  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK02)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgEPS]  
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
         , @c_CurrPalletID       NVARCHAR(18)  
         , @n_Counter            INT  
         , @c_PltEmpty           NVARCHAR(1)  
         , @c_PltEmpty0          NVARCHAR(1)  
         , @c_PltEmpty1          NVARCHAR(1)  
         , @c_PltEmpty2          NVARCHAR(1)  
         , @c_PltEmpty3          NVARCHAR(1)  
         , @c_PltEmpty4          NVARCHAR(1)  
         , @c_PltEmpty5          NVARCHAR(1)  
         , @c_PltEmpty6          NVARCHAR(1)  
         , @c_PltEmpty7          NVARCHAR(1)  
         , @c_PltEmpty8          NVARCHAR(1)  
         , @c_PltEmpty9          NVARCHAR(1)  
         , @c_PltEmpty10         NVARCHAR(1)  
         , @n_MaxEPCount         INT  
  
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
   SET @n_MaxEPCount             = 9   --HARDCODED max palletCount per stack (Excluding Mother pallet)  
  
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
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgEPS)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68003    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgEPS)'    
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
   IF @n_SerialNo = '0'  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 68011  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                     + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgEPS)'  
      GOTO QUIT  
   END  
  
   SELECT  @c_MessageID    = SUBSTRING(Data,   1,  10)  
         , @c_MessageName  = SUBSTRING(Data,  11,  15)  
         , @c_PalletID     = SUBSTRING(Data,  26,  18)  
         , @c_Param1       = SUBSTRING(Data,  44,  18)  
         , @c_Param2       = SUBSTRING(Data,  62,  18)  
         , @c_Param3       = SUBSTRING(Data,  80,  18)  
         , @c_Param4       = SUBSTRING(Data,  98,  18)  
         , @c_Param5       = SUBSTRING(Data, 116,  18)  
         , @c_Param6       = SUBSTRING(Data, 134,  18)  
         , @c_Param7       = SUBSTRING(Data, 152,  18)  
         , @c_Param8       = SUBSTRING(Data, 170,  18)  
         , @c_Param9       = SUBSTRING(Data, 188,  18)  
         , @c_Param10      = SUBSTRING(Data, 206,  18)  
   FROM TCPSOCKET_INLOG WITH (NOLOCK)  
   WHERE SerialNo = @n_SerialNo  
  
   IF @b_Debug = 1  
   BEGIN  
      SELECT  @c_MessageID       [@c_MessageID]  
            , @c_MessageName     [@c_MessageName]  
            , @c_PalletID        [@c_PalletID]  
            , @c_Param1          [@c_Param1]   
            , @c_Param2          [@c_Param2]   
            , @c_Param3          [@c_Param3]   
            , @c_Param4          [@c_Param4]   
            , @c_Param5          [@c_Param5]   
            , @c_Param6          [@c_Param6]   
            , @c_Param7          [@c_Param7]   
            , @c_Param8          [@c_Param8]   
            , @c_Param9          [@c_Param9]   
            , @c_Param10         [@c_Param10]  
   END  
  
   IF ISNULL(RTRIM(@c_MessageName),'') = ''  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 68011  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                    + ': MessageName cannot be blank. (isp_TCP_WCS_MsgEPS)'  
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_PalletID),'') = ''  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 68013  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                    + ': MotherPalletID cannot be blank. (isp_TCP_WCS_MsgEPS)'  
      GOTO QUIT  
   END  
  
  
   /*********************************************/  
   /* PROCESS AND CHECK ALL PALLET ON EPS       */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      IF @c_MessageType = "RECEIVE"  
      BEGIN  
           
         ---- INSERT INTO WCSTran  
         --INSERT INTO WCSTran (MessageName, MessageType, WCSMessageID, PalletID, Param1, Param2, Param3, Param4, Param5, Param6, Param7, Param8, Param9, Param10)  
         --VALUES (@c_MessageName, @c_MessageType, @c_WCSMessageID, @c_PalletID, @c_Param1, @c_Param2, @c_Param3, @c_Param4, @c_Param5, @c_Param6, @c_Param7, @c_Param8, @c_Param9, @c_Param10)  
        
         --IF @@ERROR <> 0  
         --BEGIN  
     --   SET @b_Success = 0  
         --   SET @n_err=68017     
         --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
         --                 + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgEPS)'  
         --                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
         --   GOTO QUIT  
         --END  
  
  
         /*********************************************/  
         /* Validate EPS PalletIDs                    */  
         /*********************************************/     
         SET @n_Counter = 0  
         SET @c_RespStatus = '1'  
         SET @c_RespReasonCode = ''  
         SET @c_RespErrMsg = ''  
  
         --Base validation moved from isp_TCP_WCS_MsgValidation so WMS can respond error via EPS Confirmation Message.                                             
         --Validate and respond error when Pallet ID contain Spaces or blank based on @n_MaxEPCount  
         IF @c_RespStatus = '1'  
         BEGIN  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 1  AND RTRIM(@c_Param1 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param1 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param1 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 2  AND RTRIM(@c_Param2 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param2 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param2 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 3  AND RTRIM(@c_Param3 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param3 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param3 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 4  AND RTRIM(@c_Param4 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param4 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param4 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 5  AND RTRIM(@c_Param5 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param5 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param5 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 6  AND RTRIM(@c_Param6 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param6 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param6 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 7  AND RTRIM(@c_Param7 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param7 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param7 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 8  AND RTRIM(@c_Param8 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param8 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param8 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 9  AND RTRIM(@c_Param9 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param9 )) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param9 ) + ').'  
            IF (@c_RespErrMsg = '' AND @n_MaxEPCount >= 10 AND RTRIM(@c_Param10) = '' OR CHARINDEX(' ', RTRIM(@c_Param10)) <> 0) SET @c_RespErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param10) + ').'  
  
            IF @c_RespErrMsg <> ''  
            BEGIN  
               SET @c_RespStatus = '5'  
               SET @c_RespReasonCode = 'F05'  
            END  
         END  
  
         --Validate and respond error when inventory found on the pallet.  
         IF @c_RespStatus = '1'  
         BEGIN  
            --Loop all 11 pallets (Include @n_Counter = 0 for mother pallet)  
            WHILE @n_Counter <= @n_MaxEPCount         
            BEGIN  
           
               SET @c_PltEmpty = 'Y'  
               SET @c_CurrPalletID = ''  
  
               --Get specific palletID based on @n_Counter  
               SET @c_CurrPalletID = CASE WHEN @n_Counter = 0  THEN ISNULL(RTRIM(@c_PalletID),'')   --Mother PalletID  
                                          WHEN @n_Counter = 1  THEN ISNULL(RTRIM(@c_Param1),'')  
                                          WHEN @n_Counter = 2  THEN ISNULL(RTRIM(@c_Param2),'')  
                                          WHEN @n_Counter = 3  THEN ISNULL(RTRIM(@c_Param3),'')  
                                          WHEN @n_Counter = 4  THEN ISNULL(RTRIM(@c_Param4),'')  
                                          WHEN @n_Counter = 5  THEN ISNULL(RTRIM(@c_Param5),'')  
                                          WHEN @n_Counter = 6  THEN ISNULL(RTRIM(@c_Param6),'')  
                                          WHEN @n_Counter = 7  THEN ISNULL(RTRIM(@c_Param7),'')  
                                          WHEN @n_Counter = 8  THEN ISNULL(RTRIM(@c_Param8),'')  
                                          WHEN @n_Counter = 9  THEN ISNULL(RTRIM(@c_Param9),'')  
                                          WHEN @n_Counter = 10 THEN ISNULL(RTRIM(@c_Param10),'')  
                                 END  
           
               --Query if the palletID contain SKU <> 'EPS' and Qty <> 0 in LOTxLOCxID. Mark 'N' when Exist  
               IF EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE ID = @c_CurrPalletID AND Qty <> 0 AND SKU <> 'EPS')  
               BEGIN  
                  SET @c_PltEmpty = 'N'  
                  SET @c_RespStatus = '5'  
                  SET @c_RespReasonCode = ''  
                  SET @c_RespErrMsg = 'One or more pallet is not empty'  
               END  
  
  
               --Set status to specific pallet based on @n_Counter  
               IF @n_Counter = 0    SET @c_PltEmpty0  = @c_PltEmpty     --Mother PalletID  
               IF @n_Counter = 1    SET @c_PltEmpty1  = @c_PltEmpty  
               IF @n_Counter = 2    SET @c_PltEmpty2  = @c_PltEmpty  
               IF @n_Counter = 3    SET @c_PltEmpty3  = @c_PltEmpty  
               IF @n_Counter = 4    SET @c_PltEmpty4  = @c_PltEmpty  
               IF @n_Counter = 5    SET @c_PltEmpty5  = @c_PltEmpty  
               IF @n_Counter = 6    SET @c_PltEmpty6  = @c_PltEmpty  
               IF @n_Counter = 7    SET @c_PltEmpty7  = @c_PltEmpty  
               IF @n_Counter = 8    SET @c_PltEmpty8  = @c_PltEmpty  
               IF @n_Counter = 9    SET @c_PltEmpty9  = @c_PltEmpty  
               IF @n_Counter = 10   SET @c_PltEmpty10 = @c_PltEmpty  
  
               SET @n_Counter = @n_Counter + 1  
                                  
            END   --WHILE @n_Counter <= 10   
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'PALLET STATUS'  
                     ,@b_Success                               [@b_Success]  
                     ,@c_PalletID + ' => ' + @c_PltEmpty0      [@c_PalletID]     --Mother PalletID  
                     ,@c_Param1   + ' => ' + @c_PltEmpty1      [@c_Param1]    
                     ,@c_Param2   + ' => ' + @c_PltEmpty2      [@c_Param2]    
                     ,@c_Param3   + ' => ' + @c_PltEmpty3      [@c_Param3]    
                     ,@c_Param4   + ' => ' + @c_PltEmpty4      [@c_Param4]    
                     ,@c_Param5   + ' => ' + @c_PltEmpty5      [@c_Param5]    
                     ,@c_Param6   + ' => ' + @c_PltEmpty6      [@c_Param6]    
                     ,@c_Param7   + ' => ' + @c_PltEmpty7      [@c_Param7]    
                     ,@c_Param8   + ' => ' + @c_PltEmpty8      [@c_Param8]    
                     ,@c_Param9   + ' => ' + @c_PltEmpty9      [@c_Param9]    
                     ,@c_Param10  + ' => ' + @c_PltEmpty10     [@c_Param10]    
            END  
  
         END  
  
  
         --Prepare respond back to WCS  
         /*********************************************/  
         /* INSERT INTO WCSTran                       */  
         /*********************************************/  
         SET @c_OrigMessageID = @c_MessageID   
  
         --Prepare temp table to store MessageID  
         IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
            DROP TABLE #TmpTblMessageID  
         CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
         INSERT INTO WCSTran (MessageName, MessageType, OrigMessageID, PalletID, UD1, Param1, Param2, Param3, Param4, Param5, Param6, Param7, Param8, Param9, Param10)  
         OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
         VALUES (@c_MessageName, 'SEND', @c_OrigMessageID, @c_PalletID, @c_PltEmpty0, @c_PltEmpty1, @c_PltEmpty2, @c_PltEmpty3, @c_PltEmpty4, @c_PltEmpty5, @c_PltEmpty6, @c_PltEmpty7, @c_PltEmpty8, @c_PltEmpty9, @c_PltEmpty10)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_err=68041     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                          + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgEPS)'  
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         -- Get MessageID from Temp table #TmpTblMessageID  
         SELECT TOP 1 @c_MessageID = ISNULL(RTRIM(MessageID),'')  
         FROM #TmpTblMessageID  
  
         SET @c_MessageID = RIGHT( REPLICATE('0', 9) + RTRIM(LTRIM(@c_MessageID)), 10)  
        
         SET @c_SendMessage = '<STX>'                                                  --[STX]  
                           + LEFT(LTRIM(@c_MessageID)     + REPLICATE(' ', 10), 10)    --[MessageID]  
                           + LEFT(LTRIM(@c_MessageName)   + REPLICATE(' ', 15), 15)    --[MessageName]  
                           + LEFT(LTRIM(@c_OrigMessageID) + REPLICATE(' ', 10), 10)    --[WCSMessageID]  
                           + LEFT(LTRIM(@c_PalletID)      + REPLICATE(' ', 18), 18)    --[MotherPltID]     
                           + LEFT(LTRIM(@c_PltEmpty0)     + REPLICATE(' ',  1),  1)    --[MotherPltEmpty]  
                           + LEFT(LTRIM(@c_PltEmpty1)     + REPLICATE(' ',  1),  1)    --[PalletEmpty1]  
                           + LEFT(LTRIM(@c_PltEmpty2)     + REPLICATE(' ',  1),  1)    --[PalletEmpty2]  
                           + LEFT(LTRIM(@c_PltEmpty3)     + REPLICATE(' ',  1),  1)    --[PalletEmpty3]  
                           + LEFT(LTRIM(@c_PltEmpty4)     + REPLICATE(' ',  1),  1)    --[PalletEmpty4]  
                           + LEFT(LTRIM(@c_PltEmpty5)     + REPLICATE(' ',  1),  1)    --[PalletEmpty5]  
                           + LEFT(LTRIM(@c_PltEmpty6)     + REPLICATE(' ',  1),  1)    --[PalletEmpty6]  
                           + LEFT(LTRIM(@c_PltEmpty7)     + REPLICATE(' ',  1),  1)    --[PalletEmpty7]  
                           + LEFT(LTRIM(@c_PltEmpty8)     + REPLICATE(' ',  1),  1)    --[PalletEmpty8]  
                           + LEFT(LTRIM(@c_PltEmpty9)     + REPLICATE(' ',  1),  1)    --[PalletEmpty9]  
                           + LEFT(LTRIM(@c_PltEmpty10)    + REPLICATE(' ',  1),  1)    --[PalletEmpty10]  
                           + LEFT(LTRIM(@c_RespStatus)    + REPLICATE(' ', 10),  10)   --[RespStatus]  
                           + LEFT(LTRIM(@c_RespReasonCode)+ REPLICATE(' ', 10),  10)   --[RespReasonCode]  
                           + LEFT(LTRIM(@c_RespErrMsg)    + REPLICATE(' ',100), 100)   --[RespErrMsg]  
                           + '<ETX>'                                                   --[ETX]  
  
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
                  , SUBSTRING(@c_SendMessage,   1,   5) [STX]  
                  , SUBSTRING(@c_SendMessage,   6,  10) [MessageID]  
                  , SUBSTRING(@c_SendMessage,  16,  15) [MessageName]  
                  , SUBSTRING(@c_SendMessage,  31,  10) [WCSMessageID]  
                  , SUBSTRING(@c_SendMessage,  41,  10) [MotherPltID]  
                  , SUBSTRING(@c_SendMessage,  51,   1) [MotherPltEmpty]  
                  , SUBSTRING(@c_SendMessage,  52,   1) [PalletEmpty1]  
                  , SUBSTRING(@c_SendMessage, 53,   1) [PalletEmpty2]  
                  , SUBSTRING(@c_SendMessage,  54,   1) [PalletEmpty3]  
                  , SUBSTRING(@c_SendMessage,  55,   1) [PalletEmpty4]  
                  , SUBSTRING(@c_SendMessage,  56,   1) [PalletEmpty5]  
                  , SUBSTRING(@c_SendMessage,  57,   1) [PalletEmpty6]  
                  , SUBSTRING(@c_SendMessage,  58,   1) [PalletEmpty7]  
                  , SUBSTRING(@c_SendMessage,  59,   1) [PalletEmpty8]  
                  , SUBSTRING(@c_SendMessage,  60,   1) [PalletEmpty9]  
                  , SUBSTRING(@c_SendMessage,  61,   1) [PalletEmpty10]  
                  , SUBSTRING(@c_SendMessage,  62,  10) [RespStatus]  
                  , SUBSTRING(@c_SendMessage,  72,  10) [RespReasonCode]  
                  , SUBSTRING(@c_SendMessage,  82, 100) [RespErrMsg]  
                  , SUBSTRING(@c_SendMessage, 182,   5) [ETX]  
  
         END   --IF @b_Debug = 1    
  
        
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
                          + ': Error inserting into TCPSocket_OUTLog Table. (isp_TCP_WCS_MsgEPS)'    
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT    
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
                             + ': Error executing isp_GenericTCPSocketClient. (isp_TCP_WCS_MsgEPS)'    
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
                             + ': Error inserting into TCPSocket_OUTLog. (isp_TCP_WCS_MsgEPS)'    
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT    
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
                          + ': Error updating into TCPSocket_OUTLog. (isp_TCP_WCS_MsgEPS)'    
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT    
         END    
  
         --/*********************************************/  
         --/* Call Putaway for EPS                      */  
         --/*********************************************/     
         --EXECUTE dbo.isp_TCP_WCS_MsgProcess  
         --      @c_MessageName    = 'PUTAWAY'  
         --   ,  @c_MessageType    = 'SEND'  
         --   ,  @c_PalletID       = @c_PalletID  
         --   ,  @c_FromLoc        = ''  
         --   ,  @c_ToLoc          = ''  
         --   ,  @c_Priority       = '05'  
         --   ,  @c_TaskDetailKey  = ''  
         --   ,  @b_Success        = @b_Success   OUTPUT  
         --   ,  @n_Err            = @n_Err       OUTPUT  
         --   ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT  
  
         --IF ISNULL(@c_ErrMsg,'') <> ''    
         --BEGIN    
         --   SET @b_Success = 0    
         --   SET @n_Err = 68030  
         --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
         --                    + ': Error executing isp_TCP_WCS_MsgProcess Putaway. (isp_TCP_WCS_MsgEPS)'    
         --                    + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
         --END    
  
      END   --IF @c_MessageType = 'RECEIVE'  
  
   END      --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
  
END  

GO