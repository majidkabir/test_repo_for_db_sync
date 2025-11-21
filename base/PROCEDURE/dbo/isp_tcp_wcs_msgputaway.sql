SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgPutaway                                    */  
/* Creation Date: 30 Oct 2014                                                 */  
/* Copyright: LFL                                                             */  
/* Written by: TKLIM                                                          */  
/*                                                                            */  
/* Purpose: Sub StorProc that Generate Outbound/Respond Message to WCS        */  
/*          OR Process Inbound/Respond Message from WCS                       */  
/*                                                                            */  
/* Called By: isp_TCP_WCS_MsgProcess                                          */  
/*                                                                            */  
/* PVCS Version: 1.0                                                          */  
/*                                                                            */  
/* Version: 1.0                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 08-Mar-2015  TKLIM     1.0   Both SEND & RECEIVE will update LLI.Loc       */  
/* 09-Mar-2015  TKLIM     1.0   Temporary Map WCS-WMS Loc (TK01)              */  
/* 15-Oct-2015  TKLIM     1.0   Add Putaway to Extended Fac Loc (TK02)        */  
/* 01-Nov-2015  TKLIM     1.0   Use RDT compatible Error Message              */  
/* 02-Nov-2015  TKLIM     1.0   Update LabelReq and PhotoReq validation       */  
/* 02-Nov-2015  TKLIM     1.0   Allow force LabelReq='N' for UAT (TK03)       */  
/* 06-Nov-2015  TKLIM     1.0   Use isp_ConvertErrWCSToRDT (TK04)             */  
/* 11-Nov-2015  TKLIM     1.0   Run ITRNAddMove before send WCSMsg(TK05)      */  
/* 26-Nov-2015  TKLIM     1.0   Set LabelReq=N for ASN from Witron(TK06)      */  
/* 02-Dec-2015  TKLIM     1.0   Redo flow for retry & rollback (TK07)         */  
/* 07-Dec-2015  TKLIM     1.0   Move to Lane for rejected pallet (TK08)       */  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK09)         */  
/* 28-Dec-2015  TKLIM     1.0   Improve performance on SEND proc              */  
/* 25-Jan-2015  TKLIM     1.0   Use PalletLabel for Label Printing(TK11)      */  
/* 18-May-2017  Barnett   1.0   FBR-WMS-1927: Add Msg field-PutAwayLOC (BL12) */  
/* 27-Sep-2017  Barnett   1.0   Added P6308 profiler for auto putaway (BL13) */  
/******************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgPutaway]  
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TASKUPDATE'  etc....  
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
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration                     */  
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
         --, @c_RDTMsg             NVARCHAR(20)  
  
   DECLARE @c_MessageGroup       NVARCHAR(20)     
         , @c_StorerKey          NVARCHAR(15)     
         , @c_SKU                NVARCHAR(20)     
         , @c_AllSKU             NVARCHAR(MAX)     
         , @n_SkuCount           INT  
         , @c_SkuCount           NVARCHAR(3)  
         , @c_Lot                NVARCHAR(10)     
         , @c_PhotoReq           NVARCHAR(1)     
         , @c_LabelReq           NVARCHAR(1)     
         , @c_MessageID          NVARCHAR(10)     
         , @n_Qty                INT  
         , @c_MoveRefKey         NVARCHAR(10)  
         , @c_FromLocCategory    NVARCHAR(10)   
         , @c_FromLocGroup       NVARCHAR(30)   
         , @c_FromLocLogical     NVARCHAR(18)  
         , @c_ToLocCategory      NVARCHAR(10)   
         , @c_ToLocGroup         NVARCHAR(30)   
         , @c_ToLocLogical       NVARCHAR(18)  
         , @c_LogicalFromLoc     NVARCHAR(10)   
         , @c_LogicalToLoc       NVARCHAR(10)   
         , @n_TmpSerialNo        INT   
         , @c_SourceType         NVARCHAR(30)  
  
   --Constant Variables  
   DECLARE @c_LOCGRP_LOOP        NVARCHAR(30)  
         , @c_LOCGRP_REJECT      NVARCHAR(30)  
         , @c_LOCCAT_GTM         NVARCHAR(10)  
         , @c_LOCCAT_OUTST       NVARCHAR(10)  
         , @c_LOGLOC_A           NVARCHAR(18)  
         , @c_LOGLOC_B           NVARCHAR(18)  
         , @c_LOGLOC_C           NVARCHAR(18)  
  
   DECLARE @c_MapWCSLoc          NVARCHAR(1)    --(TK01) translate WCS Location to WMS Location  
         , @c_WCSToLoc           NVARCHAR(10)   --(TK01)  
         , @c_WCSFromLoc         NVARCHAR(10)   --(TK01)  
  
   DECLARE @c_Lottable09         NVARCHAR(30)   --(TK02)  
         , @c_SValue             NVARCHAR(10)   --(TK02)  
         , @c_Facility           NVARCHAR(5)    --(TK02)  
         , @c_ErrMsg2            NVARCHAR(250)  --(TK03)  
  
   DECLARE @c_ItrnKey            NVARCHAR(10)   --(TK04)  
   DECLARE @c_SourceKey          NVARCHAR(20)   --(TK04)  
         , @c_OrigLoc            NVARCHAR(10)   --(TK10)  
         , @c_Loc                NVARCHAR(10)   --(TK10)  
         , @c_Tablename          NVARCHAR(18)   --(TK11)  
         , @c_HDKey              NVARCHAR(10)   --(TK11)  
         , @c_PutAwayLoc         NVARCHAR(10)   --(BL12)  
         , @c_MsgPutAwayLoc      NVARCHAR(10)   --(BL12)  
         , @c_Req4PutawayFlag    NVARCHAR(1)    --(BL12)  
         , @c_ProfilerLoc        NVARCHAR(10)   --(BL12)  
  
   SET @n_StartTCnt              = @@TRANCOUNT  
   SET @n_continue               = 1   
   SET @c_ExecStatements         = ''   
   SET @c_ExecArguments          = ''  
   SET @b_Success                = 0  
   SET @n_Err                    = 0  
   SET @c_ErrMsg                 = ''  
   --SET @c_RDTMsg                 = ''  
  
   --Constant Variables  
   SET @c_LOCGRP_LOOP            = 'GTMLOOP'  
   SET @c_LOCGRP_REJECT          = 'REJECT'  
   SET @c_LOCCAT_GTM             = 'ASRSGTM'  
   SET @c_LOCCAT_OUTST           = 'ASRSOUTST'  
   SET @c_LOGLOC_A               = 'A'  
   SET @c_LOGLOC_B               = 'B'  
   SET @c_LOGLOC_C               = 'C'  
  
   SET @c_MessageGroup           = 'WCS'  
   SET @c_StorerKey              = ''  
   SET @c_Application            = 'GenericTCPSocketClient_WCS'  
   SET @c_PhotoReq               = 'Y'  
   SET @c_LabelReq               = 'Y'  
   SET @c_Status                 = '9'  
   SET @n_SkuCount               = 0  
   SET @n_NoOfTry                = 0  
   SET @c_MapWCSLoc              = '1'    --(TK01)  
   SET @c_SourceType             = 'isp_TCP_WCS_MsgPutaway'  
  
   SET @c_Lottable09             = ''  
   SET @c_SValue                 = ''  
   SET @c_Facility               = ''  
   SET @c_ErrMsg2                = ''     --(TK03)  
  
   SET @c_ItrnKey                = ''  
   SET @c_SourceKey              = ''  
   SET @c_PutAwayLoc             = ''  
   SET @c_MsgPutAwayLoc          = ''  
   SET @c_Req4PutawayFlag        = ''  
   SET @c_ProfilerLoc            = ''  
  
  
  
  
   SELECT @c_MessageName   = LTRIM(RTRIM(SUBSTRING(Data, 11,  15))),  
          @c_ProfilerLoc   = LTRIM(RTRIM(SUBSTRING(Data, 44,  10)))  
   FROM TCPSOCKET_INLOG WITH (NOLOCK)  
   WHERE SerialNo = @n_SerialNo  
    
   If @c_MessageName = 'REQ4PUTAWAY'  
   BEGIN  
  
      SELECT @c_PalletID     = SUBSTRING(Data, 26,  18)  
      FROM TCPSOCKET_INLOG WITH (NOLOCK)  
      WHERE SerialNo = @n_SerialNo  
  
      SET @c_Req4PutawayFlag = 'Y'  
      SET @c_MessageName = 'PUTAWAY'  
      SET @c_MessageType = 'SEND'  
       
      SELECT @c_FromLoc = CASE WHEN @c_ProfilerLoc = 'P5003' THEN 'P5002'  
                               WHEN @c_ProfilerLoc = 'P5001' THEN 'P5000'  
                               WHEN @c_ProfilerLoc = 'P5101' THEN 'P5100'  
                               WHEN @c_ProfilerLoc = 'P5103' THEN 'P5102'  
                         WHEN @c_ProfilerLoc = 'P6308' THEN 'P6305'  --(BL13)  
                           END        
  
      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE ID = @c_PalletID AND Qty > 0)  
      BEGIN  
            SET @n_SkuCount = 1  
            SET @c_AllSKU = LEFT('NO INVENTORY' + REPLICATE(' ',20), 20)  
            SET @c_StorerKey = REPLICATE(' ',15)  
            SET @c_MsgPutAwayLoc = 'REJECT'              
      END  
      --SELECT * FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'MAPWCS2WMS'   
      --AND (Code = 'P5001' OR Short = @c_FromLoc) AND UDF01 IN ('IN','GTM'))  
   END  
  
  
  
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
        AND CODE2    = @c_CallerGroup      --TK09  
  
      IF ISNULL(@c_RemoteEndPoint,'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57751    
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldWCSSvrIP'  
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgPutaway)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57752    
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldCfgFPath'   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgPutaway)'    
         GOTO QUIT   
      END     
   END  
  
   IF @c_MsgPutAwayLoc = 'REJECT'  Goto REJECT  
  
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
         SET @n_continue = 3  
         SET @n_Err = 57753  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgName'   
                       + ': MessageName cannot be blank. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_MessageType),'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57754  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgType'   
                       + ': MessageType cannot be blank. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_PalletID),'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57755  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldPalletID'   
                       + ': PalletID cannot be blank. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_FromLoc),'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57756  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldFromLoc'   
                       + ': FromLoc cannot be blank. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
      IF NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'MAPWCS2WMS' AND (Code = @c_FromLoc OR Short = @c_FromLoc) AND UDF01 IN ('IN','GTM'))  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57757  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^FromLocNotMap'   
                       + ': FromLoc (' + @c_FromLoc + ') not found in Mapping table. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
      --TKLIM 20150422 - Putaway message incomplete without SKU. It will crash WCS system.  
      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE ID = @c_PalletID AND Qty > 0)  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57758  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^PalletNoInv'   
                       + ': Pallet must contain inventory. (isp_TCP_WCS_MsgPutaway)'  
         GOTO QUIT  
      END  
  
   END  
   ELSE  --IF @c_MessageType = 'RECEIVE'  
   BEGIN  
      SET @c_MessageType = 'RECEIVE'  
  
      IF @n_SerialNo = '0'  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 57759  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgNum'   
                       + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgPutaway)'  
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
  
         --BEGIN TRAN  
  
         --Store OrigLoc for rollback process  
         SELECT TOP 1 @c_OrigLoc = LLI.LOC  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         WHERE LLI.ID = @c_PalletID  
         ORDER BY EditDate DESC  
  
         --Incase pallet not exist in WMS  
         IF ISNULL(RTRIM(@c_OrigLoc),'') = ''  
            SET @c_OrigLoc = 'WCS01'   
              
         IF @b_debug = 1  
         BEGIN  
            SELECT 'ORIGLOC', @c_OrigLoc [@c_OrigLoc]  
         END  
  
         --Set ToLoc for LLI.Loc updates  
         SET @c_ToLoc = 'WCS01'  
  
         /*********************************************/  
         /* Update LLI.Loc - Start                    */  
         /*********************************************/  
         -- Query all related SKU and LOT on the pallet for LOC update  
         DECLARE C_CUR_UPDLLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty, ISNULL(CFG.SValue,'0') [SValue]  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         LEFT OUTER JOIN StorerConfig CFG WITH (NOLOCK)  
         ON CFG.Storerkey = LLI.Storerkey AND CFG.ConfigKey = 'UseExtendedFacLoc'  
         WHERE LLI.ID = @c_PalletID  
         AND LLI.Qty > 0  
         AND LLI.LOC <> @c_ToLoc  
  
         OPEN C_CUR_UPDLLI  
         FETCH NEXT FROM C_CUR_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty, @c_SValue  
  
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
  
            --TK02 - UseExtendedFacLoc - Start  
            IF @c_SValue = '1'  
            BEGIN  
              
               SELECT @c_Facility = ISNULL(RTRIM(Facility),'')   
               FROM Loc WITH (NOLOCK)  
               WHERE Loc = @c_Loc  
  
               --Customized extended warehouse WCS01 location   
               SELECT @c_Lottable09 = ISNULL(RTRIM(Lottable09),'')  
               FROM LotAttribute WITH (NOLOCK)  
               WHERE LOT = @c_Lot  
  
               IF @c_Lottable09 <> ''  
               BEGIN  
                  SET @c_ToLoc = @c_Lottable09 + '_W'  
               END  
               ELSE  
               BEGIN  
                  SET @c_ToLoc = @c_Facility + '_W'  
               END  
  
            END  
  
            --Select @c_Loc [@c_Loc], @c_ToLoc [@c_ToLoc], @c_PalletID [@c_PalletID], @c_Facility [@c_Facility], @c_Lottable09 [@c_Lottable09]  
            --TK02 - UseExtendedFacLoc - End  
  
            SET @c_MoveRefKey = ''  
            SET @b_success = 1       
            EXECUTE   nspg_getkey      
                     'MoveRefKey'      
                     , 10      
                     , @c_MoveRefKey       OUTPUT      
                     , @b_success          OUTPUT      
                     , @n_err              OUTPUT      
                     , @c_errmsg           OUTPUT   
  
            IF @b_success <> 1      
            BEGIN      
               SET @n_continue = 3  
               GOTO QUIT  
            END   
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET MoveRefKey = @c_MoveRefKey  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE Lot = @c_Lot  
            AND Loc = @c_Loc  
            AND ID = @c_PalletID  
            AND Status < '9'  
            AND ShipFlag <> 'Y'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 57760     
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                              + ': Update PICKDETIAL failed. (isp_TCP_WCS_MsgPutaway)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
  
            --Select @c_Loc, @c_ToLoc, @c_PalletID  
  
            --Update all SKU on pallet to new ASRS LOC  
            EXEC nspItrnAddMove  
                     NULL                                         
                  , @c_StorerKey                -- @c_StorerKey     
                  , @c_Sku                      -- @c_Sku           
                  , @c_Lot                      -- @c_Lot           
                  , @c_Loc                      -- @c_Loc       
                  , @c_PalletID                 -- @c_FromID        
                  , @c_ToLoc                    -- @c_ToLoc         
                  , @c_PalletID                 -- @c_ToID          
                  , '0'                         -- @c_Status        
                  , ''                          -- @c_lottable01    
                  , ''                          -- @c_lottable02    
                  , ''                          -- @c_lottable03    
                  , NULL                        -- @d_lottable04    
                  , NULL                        -- @d_lottable05    
    , ''                          -- @c_lottable06    
                  , ''                          -- @c_lottable07    
                  , ''                          -- @c_lottable08    
                  , ''                          -- @c_lottable09    
                  , ''                          -- @c_lottable10    
                  , ''                          -- @c_lottable11    
                  , ''                          -- @c_lottable12    
                  , NULL                        -- @d_lottable13    
                  , NULL                        -- @d_lottable14    
                  , NULL                        -- @d_lottable15    
                  , 0                           -- @n_casecnt       
                  , 0                           -- @n_innerpack     
                  , @n_Qty                      -- @n_qty           
                  , 0                           -- @n_pallet        
                  , 0                           -- @f_cube          
                  , 0                           -- @f_grosswgt      
                  , 0                           -- @f_netwgt        
                  , 0                           -- @f_otherunit1    
                  , 0                           -- @f_otherunit2    
                  , @c_TaskDetailKey            -- @c_SourceKey  
                  ,'isp_TCP_WCS_MsgPutaway'     -- @c_SourceType  
                  , ''                          -- @c_PackKey       
                  , ''                          -- @c_UOM           
                  , 0                           -- @b_UOMCalc       
                  , NULL                        -- @d_EffectiveD    
                  , ''                          -- @c_itrnkey       
                  , @b_success  OUTPUT          -- @b_Success     
                  , @n_err      OUTPUT          -- @n_err         
                  , @c_errmsg   OUTPUT          -- @c_errmsg      
                  , @c_MoveRefKey    -- @c_MoveRefKey    
  
            IF @@ERROR <> 0 OR RTRIM(@c_errmsg) <> '' or @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               GOTO QUIT  
            END  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET MoveRefKey = ''  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE Lot = @c_Lot  
            AND Loc = @c_Loc  
            AND ID = @c_PalletID  
            AND Status < '9'  
            AND ShipFlag <> 'Y'  
            AND MoveRefKey = @c_MoveRefKey  
  
            IF @@ERROR <> 0   
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 57761     
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                              + ': UPDATE PICKDETAIL failed. (isp_TCP_WCS_MsgPutaway)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
            FETCH NEXT FROM C_CUR_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty, @c_SValue  
  
         END  
         CLOSE C_CUR_UPDLLI  
         DEALLOCATE C_CUR_UPDLLI  
  
         /*********************************************/  
         /* Update LLI.Loc - End                      */  
         /*********************************************/  
  
         --Query Location Category and Logical  
         IF @c_FromLoc <> ''  
         BEGIN  
            SELECT @c_FromLocCategory  = ISNULL(RTRIM(LocationCategory),'')  
                  ,@c_FromLocGroup    = ISNULL(RTRIM(LocationGroup),'')  
                  ,@c_FromLocLogical  = ISNULL(RTRIM(LogicalLocation),'')  
            FROM LOC WITH (NOLOCK)   
            WHERE LOC = @c_FromLoc  
         END  
  
         SELECT @c_ToLocCategory       = ISNULL(RTRIM(LocationCategory),'')   
               ,@c_ToLocGroup         = ISNULL(RTRIM(LocationGroup),'')  
               ,@c_ToLocLogical       = ISNULL(RTRIM(LogicalLocation),'')  
         FROM LOC WITH (NOLOCK)  
         WHERE LOC = @c_ToLoc  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'TOLOC & FROMLOC'  
                  ,@c_FromLoc          [@c_FromLoc]  
                  ,@c_FromLocCategory  [@c_FromLocCategory]  
                  ,@c_FromLocGroup     [@c_FromLocGroup]   
                  ,@c_FromLocLogical   [@c_FromLocLogical]  
                  ,@c_ToLoc            [@c_ToLoc]  
                  ,@c_ToLocCategory    [@c_ToLocCategory]  
                  ,@c_ToLocGroup       [@c_ToLocGroup]  
                  ,@c_ToLocLogical     [@c_ToLocLogical]  
         END  
  
         --Get All SKU on the pallet required  
         DECLARE C_CUR_QRYLLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
           
         SELECT DISTINCT UPPER(LLI.SKU), UPPER(LLI.StorerKey), Putaway.ZoneCategory -- BL01  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         JOIN SKU SKU WITH (NOLOCK)  
            ON  SKU.SKU = LLI.SKU   
            AND SKU.StorerKey = LLI.StorerKey  
         JOIN LotAttribute LA WITH (NOLOCK)  
            ON  LA.Lot = LLI.Lot  
            AND LA.SKU = LLI.SKU   
            AND LA.StorerKey = LLI.StorerKey  
  LEFT OUTER JOIN dbo.PUTAWAYZONE PUTAWAY WITH (NOLOCK) ON (PUTAWAY.PutawayZone = SKU.PutawayZone)  
         WHERE LLI.ID = @c_PalletID  
            AND LLI.QTY > 0  
  
         OPEN C_CUR_QRYLLI  
         FETCH NEXT FROM C_CUR_QRYLLI INTO @c_SKU, @c_StorerKey, @c_PutAwayLoc  
  
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
           
            SET @n_SkuCount = @n_SkuCount + 1  
            SET @c_AllSKU = @c_AllSKU + LEFT(LTRIM(@c_SKU) + REPLICATE(' ',20) ,20)  
  
              
            --Check PutAwayLoc base on SKU              
            --If PutawayLoc is empty return REJECT, Multiple SKU - one of the SKU.Putawayzone is AIRCOND then all AIRCOND   
            -- AIRCON / AMBIENT / REJECT  
            IF @c_PutAwayLoc <> ''   
            BEGIN                    
  
                  IF @c_PutAwayLoc = 'AIRCOND'  
                  BEGIN  
                        SET @c_MsgPutAwayLoc = 'AIRCON'  
                  END  
                  ELSE IF @c_PutAwayLoc = 'AMBIENT'  
                  BEGIN  
                        SET @c_MsgPutAwayLoc = 'AMBIENT'  
                  END  
                  Else  
                  BEGIN  
                        SET @c_MsgPutAwayLoc = 'REJECT'  
                  END   
  
            END                   
            ELSE  
            BEGIN  
                    
                  SET @c_MsgPutAwayLoc = 'REJECT'  
            END  
  
            FETCH NEXT FROM C_CUR_QRYLLI INTO @c_SKU, @c_StorerKey, @c_PutAwayLoc  
  
         END  
         CLOSE C_CUR_QRYLLI  
         DEALLOCATE C_CUR_QRYLLI  
  
         /*********************************************/  
         /* SET @c_LabelReq - Start                   */  
         /*********************************************/  
         SET @c_LabelReq   = 'Y'  
         SET @c_Tablename  = ''  
         SET @c_HDKey      = ''  
  
         SELECT  @c_Tablename  = Tablename  
               , @c_HDKey      = HDKey  
         FROM PalletLabel (NOLOCK)   
         WHERE ID = @c_PalletID   
         AND Status = '0'  
  
         IF @c_Tablename = ''  
         BEGIN  
  
  
            SET @c_LabelReq = 'N'  
            SET @c_PhotoReq = 'N'  
         END  
           
         IF @c_LabelReq = 'Y'  
         BEGIN  
            --Validate and only print label when pallet contain only 1 lot.  
            SELECT  @c_LabelReq   = CASE WHEN COUNT(DISTINCT LOT) = 1 THEN 'Y' ELSE 'N' END  
                  , @c_PhotoReq   = CASE WHEN COUNT(DISTINCT LOT) = 1 THEN 'Y' ELSE 'N' END  
                  , @c_Lot        = LLI.Lot  
                  , @c_SKU        = LLI.SKU  
                  , @c_Storerkey  = LLI.Storerkey  
                  , @n_Qty        = LLI.Qty  
            FROM LOTxLOCxID LLI WITH (NOLOCK)  
            WHERE LLI.ID = @c_PalletID AND LLI.QTY > 0  
            GROUP BY LLI.Lot, LLI.SKU, LLI.Storerkey, LLI.Qty  
         END  
  
         --Validate and only print label when stock is BONDED  
         IF @c_LabelReq = 'Y'  
         BEGIN  
            IF EXISTS ( SELECT 1  
                        FROM LOTxLOCxID LLI   WITH (NOLOCK)  
                        JOIN LOTAttribute LA  WITH (NOLOCK)  ON LLI.LOT = LA.LOT  
                        LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON CLK.Code = LA.Lottable06 AND CLK.Listname = 'BONDFAC' AND CLK.Short = 'BONDED'  
                        WHERE LLI.ID = @c_PalletID   
                        AND LLI.Qty > 0  
                        AND CLK.Short IS NULL  
            )  
            BEGIN  
               SET @c_LabelReq = 'N'  
            END  
         END  
  
  
   -- If Pallet Putaway from GTM, skip Label Printing  
   IF @c_FromLocCategory = @c_LOCCAT_GTM SET @c_LabelReq = 'N'  
  
  
         IF @c_Tablename = 'RECEIPT'  
         BEGIN  
  
            IF EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK)   
                        WHERE ReceiptKey = LEFT(LTRIM(@c_HDKey),10)  
                        AND ISNULL(RTRIM(ExternReceiptKey),'') = 'WITRON2WMS')  
            BEGIN  
               SET @c_LabelReq = 'N'  
            END  
         END  
  
         ----Validate and only print label when there is a ReceiptKey tie to it in ITRN records.  
         ----HouseKept ITRN records will require SOP to manually generate Custom Label.  
         --IF @c_LabelReq = 'Y'  
         --BEGIN  
         --   SELECT TOP 1 @c_ItrnKey = ISNULL(ItrnKey,'0'), @c_SourceKey = ISNULL(SourceKey,'')  
         --   FROM ITRN ITRN WITH (NOLOCK)  
         --   WHERE ITRN.TranType     = 'DP'  
         --     AND ITRN.SourceType   = 'ntrReceiptDetailUpdate'  
         --     AND ITRN.LOT          = @c_Lot  
         --     AND ITRN.ToID         = @c_PalletID  
         --     AND ITRN.SKU          = @c_SKU  
         --     AND ITRN.Storerkey    = @c_Storerkey  
         --     AND ITRN.Qty          = @n_Qty  
         --   ORDER BY ItrnKey DESC  
  
         --   IF @c_ItrnKey = '0' OR LEN(@c_SourceKey) < 11   
         --   BEGIN  
         --      SET @c_LabelReq = 'N'  
         --   END  
         --END  
  
         ----Validate and only print label when first time putaway.  
         --IF @c_LabelReq = 'Y'  
         --BEGIN  
         --   IF EXISTS ( SELECT 1 FROM ITRN ITRN WITH (NOLOCK)   
         --               WHERE ITRN.TranType     = 'MV'  
         --                 AND ITRN.SourceType   = 'isp_TCP_WCS_MsgPutaway'  
         --                 AND ITRN.LOT          = @c_Lot  
         --                 AND ITRN.ToID         = @c_PalletID  
         --                 AND ITRN.SKU          = @c_SKU  
         --                 AND ITRN.Storerkey    = @c_Storerkey  
         --                 AND ITRN.Qty          = @n_Qty  
         --               HAVING COUNT(Itrnkey) > 1  
         --   )  
         --   BEGIN  
         --      SET @c_LabelReq = 'N'  
         --   END  
         --END  
  
  
         /*********************************************/  
         /* SET @c_LabelReq - End                     */  
         /*********************************************/  
         /*********************************************/  
         /* SET @c_PhotoReq - Start                   */  
         /*********************************************/  
         --SET @c_PhotoReq = 'Y'  
  
         ----Validate and only capture photo when pallet contain only 1 lot.  
         --SELECT @c_Lot        = LLI.Lot  
         --     , @c_SKU        = LLI.SKU  
         --     , @c_Storerkey  = LLI.Storerkey  
         --     , @n_Qty        = LLI.Qty  
         --FROM LOTxLOCxID LLI WITH (NOLOCK)  
         --WHERE LLI.ID = @c_PalletID AND LLI.QTY > 0  
  
         ----Validate and only capture photo when there is a ReceiptKey tie to it in ITRN records.  
         --IF @c_PhotoReq = 'Y'  
         --BEGIN  
         --   SELECT TOP 1 @c_ItrnKey = ISNULL(ItrnKey,'0'), @c_SourceKey = ISNULL(SourceKey,'')  
         --   FROM ITRN ITRN WITH (NOLOCK)  
         --   WHERE ITRN.TranType     = 'DP'  
         --     AND ITRN.SourceType   = 'ntrReceiptDetailUpdate'  
         --     AND ITRN.LOT          = @c_Lot  
         --     AND ITRN.ToID         = @c_PalletID  
         --     AND ITRN.SKU          = @c_SKU  
         --     AND ITRN.Storerkey    = @c_Storerkey  
         --     AND ITRN.Qty          = @n_Qty  
         --   ORDER BY ItrnKey DESC  
  
         --   IF @c_ItrnKey = '0' OR LEN(@c_SourceKey) < 11   
         --   BEGIN  
         --      SET @c_PhotoReq = 'N'  
         --   END  
         --END  
           
         ----Validate and only print label when first time putaway.  
         --IF @c_PhotoReq = 'Y'  
         --BEGIN  
         --   IF EXISTS ( SELECT 1 FROM ITRN ITRN WITH (NOLOCK)   
         --               WHERE ITRN.TranType     = 'MV'  
         --                 AND ITRN.SourceType   = 'isp_TCP_WCS_MsgPutaway'  
         --                 AND ITRN.LOT          = @c_Lot  
         --                 AND ITRN.ToID         = @c_PalletID  
         --                 AND ITRN.SKU          = @c_SKU  
         --                 AND ITRN.Storerkey    = @c_Storerkey  
         --                 AND ITRN.Qty          = @n_Qty  
         --               HAVING COUNT(Itrnkey) > 1  
         --   )  
         --   BEGIN  
         --      SET @c_PhotoReq = 'N'  
         --   END  
         --END  
  
         /*********************************************/  
         /* SET @c_PhotoReq - End                     */  
         /*********************************************/  
  
         UPDATE PalletLabel WITH (ROWLOCK)   
         SET   PrintFlag   = @c_LabelReq  
              ,PhotoFlag   = @c_PhotoReq  
              ,Status      = CASE WHEN @c_LabelReq = 'N' THEN '9' ELSE '0' END   --Set to 9 so it can be housekept  
         WHERE ID = @c_PalletID   
         AND Status = '0'  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'SKU DATA'  
                  ,@c_PhotoReq      [@c_PhotoReq]   
                  ,@c_LabelReq      [@c_LabelReq]   
                  ,@n_SkuCount      [@n_SkuCount]  
                  ,@c_AllSKU        [@c_AllSKU]   
         END  
  
         --(TK01) - Start  
         IF @c_MapWCSLoc = '1'  
         BEGIN  
            SELECT @c_WCSToLoc = CASE WHEN ISNULL(RTRIM(Code),'') <> '' THEN Code END  
            FROM CODELKUP WITH (NOLOCK)  
            WHERE ListName = 'MAPWCS2WMS' AND Short = @c_ToLoc  
  
            SELECT @c_WCSFromLoc = CASE WHEN ISNULL(RTRIM(Code),'') <> '' THEN Code END  
            FROM CODELKUP WITH (NOLOCK)  
            WHERE ListName = 'MAPWCS2WMS' AND Short = @c_FromLoc  
         END  
         --(TK01) - END  
  
  
         /*********************************************/  
         /* INSERT INTO WCSTran                       */  
         /*********************************************/  
REJECT:  
         --Prepare temp table to store MessageID  
         IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
            DROP TABLE #TmpTblMessageID  
         CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
         INSERT INTO WCSTran (MessageName, MessageType, TaskDetailKey, PalletID, FromLoc, UD1, UD2, UD3, UD4)  
         OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
         VALUES (@c_MessageName, @c_MessageType, @c_TaskDetailKey, @c_PalletID, @c_WCSFromLoc, @c_PhotoReq, @c_LabelReq, @c_StorerKey, @c_SkuCount)      --(TK01)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=57765     
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsWCSTran'   
                          + ': Insert WCSTran fail. (isp_TCP_WCS_MsgPutaway)'  
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         -- Get MessageID from Temp table #TmpTblMessageID  
         SELECT TOP 1 @c_MessageID = ISNULL(RTRIM(MessageID),'')  
         FROM #TmpTblMessageID  
  
         SET @c_MessageID = RIGHT(REPLICATE('0', 9) + RTRIM(LTRIM(@c_MessageID)), 10)  
        
  
         --for Auto Request Putaway  
         --Remark the FromLoc to Profiler Location. -- (BL12)  
         IF @c_Req4PutawayFlag = 'Y'  
         BEGIN  
               SET @c_WCSFromLoc = @c_ProfilerLoc  
         END  
           
         SET @c_SendMessage = '<STX>'                                                 --[STX]  
                           + LEFT(LTRIM(@c_MessageID)    + REPLICATE(' ', 10) ,10)    --[MessageID]  
                           + LEFT(LTRIM(@c_MessageName)  + REPLICATE(' ', 15) ,15)    --[MessageName]  
                           + LEFT(LTRIM(@c_PalletID)     + REPLICATE(' ', 18) ,18)    --[PalletID]  
                           + LEFT(LTRIM(@c_WCSFromLoc)   + REPLICATE(' ', 10) ,10)    --[WCSFromLoc]     --(TK01)  
                           + LEFT(LTRIM(@c_PhotoReq)     + REPLICATE(' ',  1) ,1)     --[PhotoReq]  
                           + LEFT(LTRIM(@c_LabelReq)     + REPLICATE(' ',  1) ,1)     --[LabelReq]  
                           + LEFT(LTRIM(@c_StorerKey)    + REPLICATE(' ', 15) ,15)    --[StorerKey]  
                           + RIGHT(RTRIM(REPLICATE('0', 3) + LTRIM(CONVERT(CHAR(3),ISNULL(@n_SkuCount,0)))),3)     --[SkuCount]  
                           + @c_AllSKU                                                  
                           + LEFT(LTRIM(@c_MsgPutAwayLoc)+ REPLICATE(' ', 10) ,10)    --[PutAwayLoc]     --(BL12)  
                           + '<ETX>'                                                  --[ETX]  
  
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
                  , SUBSTRING(@c_SendMessage,  31, 18) [PalletID]  
                  , SUBSTRING(@c_SendMessage,  49, 10) [WCSFromLoc]     --(TK01)  
                  , SUBSTRING(@c_SendMessage,  59,  1) [PhotoReq]  
                  , SUBSTRING(@c_SendMessage,  60,  1) [LabelReq]  
                  , SUBSTRING(@c_SendMessage,  61, 15) [StorerKey]  
                  , SUBSTRING(@c_SendMessage,  76,  3) [SkuCount]  
                  , SUBSTRING(@c_SendMessage,  79, 20) [Sku_1]  
                  , SUBSTRING(@c_SendMessage,  99, 20) [Sku_2]  
                  , SUBSTRING(@c_SendMessage, 119, 20) [Sku_3]  
                  , SUBSTRING(@c_SendMessage, 139, 20) [Sku_4]  
                  , SUBSTRING(@c_SendMessage, 159, 20) [Sku_5]  
                  , SUBSTRING(@c_SendMessage, 179, 20) [Sku_6]  
                  , SUBSTRING(@c_SendMessage, 199, 20) [Sku_7]  
                  , SUBSTRING(@c_SendMessage, 219, 20) [Sku_8]  
                  , SUBSTRING(@c_SendMessage, 239, 20) [Sku_9]  
                  , SUBSTRING(@c_SendMessage, 259, 20) [Sku_10]  
                  , SUBSTRING(@c_SendMessage, 279, 20) [Sku_11]  
                  , SUBSTRING(@c_SendMessage, 299, 20) [Sku_12]  
                  , SUBSTRING(@c_SendMessage, 319, 20) [Sku_13]  
                  , SUBSTRING(@c_SendMessage, 339, 20) [Sku_14]  
                  , SUBSTRING(@c_SendMessage, 359, 20) [Sku_15]  
                  , SUBSTRING(@c_SendMessage, 379, 20) [Sku_16]  
                  , SUBSTRING(@c_SendMessage, 399, 20) [Sku_17]  
                  , SUBSTRING(@c_SendMessage, 419, 20) [Sku_18]  
                  , SUBSTRING(@c_SendMessage, 439, 20) [Sku_19]  
                  , SUBSTRING(@c_SendMessage, 459, 20) [Sku_20]  
                  , SUBSTRING(@c_SendMessage, 479, 20) [Sku_21]  
                  , SUBSTRING(@c_SendMessage, 499, 20) [Sku_22]  
                  , SUBSTRING(@c_SendMessage, 519, 20) [Sku_23]  
                  , SUBSTRING(@c_SendMessage, 539, 20) [Sku_24]  
                  , SUBSTRING(@c_SendMessage, 559, 20) [Sku_25]  
                  , SUBSTRING(@c_SendMessage, 579, 20) [Sku_26]  
                  , SUBSTRING(@c_SendMessage, 599, 20) [Sku_27]  
                  , SUBSTRING(@c_SendMessage, 619, 20) [Sku_28]  
                  , SUBSTRING(@c_SendMessage, 639, 20) [Sku_29]  
                  , SUBSTRING(@c_SendMessage, 659, 20) [Sku_30]  
         END   --@b_Debug = 1                                            
  
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
               SET @n_Err = 57769    
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTcpOutLg'   
                              + ': INSERT TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgPutaway)'    
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT    
            END    
  
            EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
                  @c_IniFilePath  
               , @c_RemoteEndPoint  
               , @c_SendMessage  
               , @c_LocalEndPoint     OUTPUT  
               , @c_ReceiveMessage    OUTPUT  
               , @c_vbErrMsg          OUTPUT  
  
            --IF @@ERROR <> 0    
            --BEGIN    
            --   SET @n_continue = 3    
            --   SET @n_Err = 57766    
            --   SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrExeTcpClnt'   
            --                  + ': EXEC isp_GenericTCPSocketClient Fail. (isp_TCP_WCS_MsgPutaway)'    
            --                  + ' sqlsvr message=' + ISNULL(RTRIM(CAST(@c_VBErrMsg AS NVARCHAR(250))), '')  
            --   GOTO QUIT    
            --END    
                 
            --DEBUG connection failure  
            --SET @c_vbErrMsg = 'No connection could be made because the target machine actively refused it'  
  
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
               SET @n_Err = 57767    
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
            SET @n_Err = 57766  
  
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
               SET @n_Err = 57768     
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
  
         END  
              
         --When Fail to execute TCPSocket OR TCPSocketClient return VBError OR WCS return Error, Move inventory back to Original Location.  
         --Else continue update the rest of the tables.  
         IF @n_continue = 3  
         BEGIN  
  
            --Declare new variable to store the origianl errors  
            DECLARE @n_FailErr      INT            
                  , @c_FailErrMsg   NVARCHAR(250)  
  
            SET @n_FailErr          = @n_Err  
            SET @c_FailErrMsg       = @c_ErrMsg  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'MOVEINVBACK-S', @c_OrigLoc [@c_OrigLoc],@n_continue [@n_continue], @c_Status [@c_Status], @n_Err [@n_Err], @c_ErrMsg [@c_ErrMsg]  
            END  
  
            /*********************************************/  
            /* UPDATE PICKDETAIL AND ITRN                */  
            /*********************************************/  
  
            -- Since the WCS failed, move back to orrignal location @c_OrigLoc  
            -- Query all related SKU and LOT on the pallet for LOC update  
            DECLARE C_CUR_UPDLLI2 CURSOR FAST_FORWARD READ_ONLY FOR   
            SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty  
            FROM LOTxLOCxID LLI WITH (NOLOCK)  
            WHERE LLI.ID = @c_PalletID  
            AND LLI.Qty > 0  
            AND LLI.Loc <> @c_OrigLoc  
  
            OPEN C_CUR_UPDLLI2  
            FETCH NEXT FROM C_CUR_UPDLLI2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty  
  
            WHILE @@FETCH_STATUS <> -1   
            BEGIN  
              
               SET @c_MoveRefKey = ''  
               SET @b_success = 1      
               EXECUTE   nspg_getkey      
                        'MoveRefKey'      
                        , 10      
                        , @c_MoveRefKey       OUTPUT      
                        , @b_success          OUTPUT      
                        , @n_err              OUTPUT      
                        , @c_errmsg           OUTPUT   
  
               IF @b_success <> 1      
               BEGIN      
                  SET @n_continue = 3  
                  GOTO QUIT  
               END   
  
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET MoveRefKey = @c_MoveRefKey  
                  ,EditWho    = SUSER_NAME()  
                  ,EditDate   = GETDATE()  
                  ,Trafficcop = NULL  
               WHERE Lot = @c_Lot  
               AND Loc = @c_FromLoc  
               AND ID = @c_PalletID  
               AND Status < '9'  
               AND ShipFlag <> 'Y'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 57776     
     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                                 + ': Update PICKDETIAL Failed. (isp_TCP_WCS_MsgPutaway)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
               --Update all SKU on pallet to new ASRS LOC  
               EXEC nspItrnAddMove  
                     NULL   
                  , @c_StorerKey             -- @c_StorerKey   
                  , @c_Sku                   -- @c_Sku         
                  , @c_Lot                   -- @c_Lot         
                  , @c_FromLoc               -- @c_FromLoc     
                  , @c_PalletID              -- @c_FromID      
                  , @c_OrigLoc               -- @c_ToLoc       
                  , @c_PalletID              -- @c_ToID        
                  , '0'                      -- @c_Status      
                  , ''                       -- @c_lottable01  
                  , ''                       -- @c_lottable02  
                  , ''                       -- @c_lottable03  
                  , NULL                     -- @d_lottable04  
                  , NULL                     -- @d_lottable05  
                  , ''                       -- @c_lottable06  
                  , ''                       -- @c_lottable07  
                  , ''                       -- @c_lottable08  
                  , ''                       -- @c_lottable09  
                  , ''                       -- @c_lottable10  
                  , ''                       -- @c_lottable11  
                  , ''                       -- @c_lottable12  
                  , NULL                     -- @d_lottable13  
                  , NULL                     -- @d_lottable14  
                  , NULL                     -- @d_lottable15  
                  , 0                        -- @n_casecnt     
                  , 0                        -- @n_innerpack   
                  , @n_Qty                   -- @n_qty         
                  , 0                        -- @n_pallet      
                  , 0                        -- @f_cube        
                  , 0                        -- @f_grosswgt    
                  , 0                        -- @f_netwgt      
                  , 0                        -- @f_otherunit1  
                  , 0                        -- @f_otherunit2  
                  , @c_TaskDetailKey         -- @c_SourceKey   
                  , @c_SourceType            -- @c_SourceType  
                  , ''                       -- @c_PackKey     
                  , ''                       -- @c_UOM         
                  , 0                        -- @b_UOMCalc     
                  , NULL                     -- @d_EffectiveD  
                  , ''                       -- @c_itrnkey     
                  , @b_success  OUTPUT       -- @b_Success     
                  , @n_err      OUTPUT       -- @n_err         
                  , @c_errmsg   OUTPUT       -- @c_errmsg      
                  , @c_MoveRefKey            -- @c_MoveRefKey       
  
               IF @@ERROR <> 0 OR RTRIM(@c_errmsg) <> ''  
               BEGIN  
                  SET @n_continue = 3  
                  GOTO QUIT  
               END  
  
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET MoveRefKey = ''  
                  ,EditWho    = SUSER_NAME()  
                  ,EditDate   = GETDATE()  
                  ,Trafficcop = NULL  
               WHERE Lot = @c_Lot  
               AND Loc = @c_FromLoc  
               AND ID = @c_PalletID  
               AND Status < '9'  
               AND ShipFlag <> 'Y'  
               AND MoveRefKey = @c_MoveRefKey  
  
               IF @@ERROR <> 0   
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 57777     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
         + ': UPDATE PICKDETAIL Failed. (isp_TCP_WCS_MsgPutaway)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
               FETCH NEXT FROM C_CUR_UPDLLI2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty  
  
            END  
            CLOSE C_CUR_UPDLLI2  
            DEALLOCATE C_CUR_UPDLLI2  
  
            ----Reset Status to Q to allow Auto recall out      --TK02  
            --UPDATE TaskDetail WITH (ROWLOCK) SET Status = 'Q' WHERE TaskDetailkey = @c_TaskDetailKey  
                 
            --IF @@ERROR <> 0  
            --BEGIN  
            --   SET @n_continue = 3  
            --   SET @n_Err = 57888     
            --   SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTaskDt'   
            --                  + ': Update TaskDetail Fail. (isp_TCP_WCS_MsgPutaway)'  
            --                  + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            --   GOTO QUIT  
            --END  
  
            IF @n_Err = 0  
            BEGIN  
               SET @c_Status  = '5'  
               SET @n_Err     = @n_FailErr  
               SET @c_ErrMsg  = @c_FailErrMsg  
            END  
            ELSE  
            BEGIN  
               SET @c_Status  = '5'  
               SET @c_ErrMsg  = @c_ErrMsg + '/' + @c_FailErrMsg  
            END  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'MOVEINVBACK-E', @c_OrigLoc [@c_OrigLoc],@n_continue [@n_continue], @c_Status [@c_Status], @n_Err [@n_Err], @c_ErrMsg [@c_ErrMsg]  
            END  
  
         END  
         ELSE     --IF @n_continue <> 3  
         BEGIN  
  
            BEGIN TRAN  
  
            /***************************************************************************************/  
            /* If Putaway from A, B, C or Loop, Clear ID.VirtualLoc                                */  
            /***************************************************************************************/  
            IF @c_FromLocCategory = @c_LOCCAT_GTM   
               AND ( @c_FromLocLogical = @c_LOGLOC_A     --GTM A Location  
                  OR @c_FromLocLogical = @c_LOGLOC_B     --GTM B Location  
                  OR @c_FromLocLogical = @c_LOGLOC_C     --GTM C Location  
                  OR @c_ToLocGroup = @c_LOCGRP_LOOP      --GTMLoop  
               )     
            BEGIN  
               UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID  
            END  
  
            /***************************************************************************************/  
            /* - FROM GTM_Area => ASRS                                                             */  
            /***************************************************************************************/  
            IF @c_FromLocCategory = @c_LOCCAT_GTM  
            BEGIN  
                 
               UPDATE GTMTASK WITH (ROWLOCK) SET Status = '9' WHERE TaskDetailKey = @c_TaskDetailKey AND Status <> '9'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 57762     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdGTMTask'   
                                 + ': UPDATE GTMTASK fail. (isp_TCP_WCS_MsgPutaway)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
               --GTM Strategy will create a record into GTMLoop after send callout the pallet.  
               --DELETE from GTMLoop Table when PUTAWAY from GTM area  
               DELETE FROM GTMLoop WHERE PalletID = @c_PalletID AND Status = '1'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 57763     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrDelGTMLoop'   
                    + ': DELETE GTMLoop fail. (isp_TCP_WCS_MsgPutaway)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
            END  
  
            /***************************************************************************************/  
            /* If @c_PalletID is Order Pallet, Set ID.PalletFlag = 'PACKNHOLD'                     */  
            /***************************************************************************************/  
            IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE ID = @c_PalletID AND Status = '5')  
            BEGIN  
              
               UPDATE ID WITH (ROWLOCK) SET PalletFlag = 'PACKNHOLD', EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 57764     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID'   
                                 + ': UPDATE ID fail. (isp_TCP_WCS_MsgPutaway)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
            END  
         END  
      END   --IF @c_MessageType = 'SEND'  
  
      /*********************************************/  
      /* MessageType = 'RECEIVE'                   */  
      /*********************************************/  
      IF @c_MessageType = 'RECEIVE'  
      BEGIN  
  
         BEGIN TRAN  
  
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
  
         -- GET TaskDetailKey From WCSTRAN (MessageType = 'SEND')  
         SELECT @c_TaskDetailKey = TaskDetailKey   
         FROM WCSTRAN (NOLOCK)  
         WHERE MessageType = 'SEND'   
         AND MessageID = @c_OrigMessageID  
         AND PalletID = @c_PalletID   
  
         ---- INSERT INTO WCSTran  
         --INSERT INTO WCSTran (MessageName, MessageType, TaskDetailKey, WCSMessageID, OrigMessageID, PalletID, ToLoc, Status, ReasonCode, ErrMsg)  
         --VALUES (@c_MessageName, @c_MessageType, @c_TaskDetailKey, @c_MessageID, @c_OrigMessageID, @c_PalletID, @c_ToLoc, @c_RespStatus, @c_RespReasonCode, @c_RespErrMsg)  
  
         -- UPDATE INTO WCSTran  
         UPDATE WCSTran WITH (ROWLOCK)   
         SET   TaskDetailkey  = @c_TaskDetailkey  
             , ToLoc          = @c_ToLoc  
             , Status         = @c_RespStatus  
             , ReasonCode     = @c_RespReasonCode  
             , ErrMsg         = @c_RespErrMsg  
         WHERE MessageName    = @c_MessageName  
         AND   MessageType    = @c_MessageType  
         AND   WCSMessageID   = @c_MessageID  
         AND   OrigMessageID  = @c_OrigMessageID  
         AND   PalletID       = @c_PalletID  
  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=57770  
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdWCSTran'   
                          + ': Update WCSTran fail. (isp_TCP_WCS_MsgPutaway)'  
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         --(TK01) - Start  
         IF @c_MapWCSLoc = '1'  
         BEGIN  
            SET @c_WCSToLoc = @c_ToLoc  
            SET @c_WCSFromLoc = @c_FromLoc  
  
            SELECT @c_ToLoc = CASE WHEN ISNULL(RTRIM(Short),'') <> '' THEN Short END  
            FROM CODELKUP WITH (NOLOCK)              WHERE ListName = 'MAPWCS2WMS' AND Code = @c_WCSToLoc  
  
            SELECT @c_FromLoc = CASE WHEN ISNULL(RTRIM(Short),'') <> '' THEN Short END  
            FROM CODELKUP WITH (NOLOCK)  
            WHERE ListName = 'MAPWCS2WMS' AND Code = @c_WCSFromLoc  
         END  
         --(TK01) - END  
  
         --Query Location Category and Logical  
         IF @c_FromLoc <> ''  
         BEGIN  
            SELECT @c_FromLocCategory  = ISNULL(RTRIM(LocationCategory),'')  
                  , @c_FromLocGroup    = ISNULL(RTRIM(LocationGroup),'')  
                  , @c_FromLocLogical  = ISNULL(RTRIM(LogicalLocation),'')  
            FROM LOC WITH (NOLOCK)   
            WHERE LOC = @c_FromLoc  
         END  
  
         SELECT @c_ToLocCategory       = ISNULL(RTRIM(LocationCategory),'')   
               , @c_ToLocGroup         = ISNULL(RTRIM(LocationGroup),'')  
               , @c_ToLocLogical       = ISNULL(RTRIM(LogicalLocation),'')  
         FROM LOC WITH (NOLOCK)  
         WHERE LOC = @c_ToLoc  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'TOLOC & FROMLOC Shuffle'  
                  ,@c_FromLoc          [@c_FromLoc]  
                  ,@c_FromLocCategory  [@c_FromLocCategory]  
                  ,@c_FromLocGroup     [@c_FromLocGroup]   
                  ,@c_FromLocLogical   [@c_FromLocLogical]  
                  ,@c_ToLoc            [@c_ToLoc]  
                  ,@c_ToLocCategory    [@c_ToLocCategory]  
                  ,@c_ToLocGroup       [@c_ToLocGroup]  
                  ,@c_ToLocLogical     [@c_ToLocLogical]  
         END  
  
         --When WCS return Error for Putaway Pallet, the ToLoc is Reject Point. Query and move pallet to Reject Lane (TK08)  
         IF @c_ToLocGroup = @c_LOCGRP_REJECT  
         BEGIN  
  
            SELECT Top 1 @c_Toloc = ISNULL(RTRIM(LANE.Loc),'')  
            FROM LOC LOC WITH (NOLOCK)   
            INNER JOIN LOC LANE WITH (NOLOCK)  
            ON LANE.PutawayZone = LOC.PutawayZone   
            AND LANE.LocationCategory = 'STAGING'  
            WHERE LOC.LOC = @c_Toloc  
  
            IF @c_Toloc = ''  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 57775  
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^RejLaneNotSet'   
                           + 'Reject Lane not setup. (isp_TCP_WCS_MsgShuffle)'  
               GOTO QUIT  
            END  
         END  
  
         IF @c_TaskDetailKey <> ''  
         BEGIN  
            UPDATE TaskDetail WITH (ROWLOCK) SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL   
            WHERE TaskDetailkey = @c_TaskDetailKey AND FromID = @c_PalletID  AND Status <> '9'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 57771  
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTskDt'   
                              + ': UPDATE TaskDetail fail. (isp_TCP_WCS_MsgPutaway)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
         END  
  
         UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc,  EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 57772  
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID'   
                           + ': UPDATE ID Fail. (isp_TCP_WCS_MsgPutaway)'  
                           + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
            GOTO QUIT  
         END  
  
         /*********************************************/  
         /* Update LLI.Loc - Start                    */  
         /*********************************************/  
         -- Query all related SKU and LOT on the pallet for LOC update  
         DECLARE C_CUR_UPDLLI3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty, ISNULL(CFG.SValue,'0') [SValue]  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         LEFT OUTER JOIN StorerConfig CFG WITH (NOLOCK)  
         ON CFG.Storerkey = LLI.Storerkey AND CFG.ConfigKey = 'UseExtendedFacLoc'  
         WHERE LLI.ID = @c_PalletID  
         AND LLI.Qty > 0  
         AND LLI.LOC <> @c_ToLoc  
  
         OPEN C_CUR_UPDLLI3  
         FETCH NEXT FROM C_CUR_UPDLLI3 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty, @c_SValue  
  
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
  
            --TK02 - UseExtendedFacLoc - Start  
            IF @c_SValue = '1'  
            BEGIN  
              
               SELECT @c_Facility = ISNULL(RTRIM(Facility),'')   
               FROM Loc WITH (NOLOCK)  
               WHERE Loc = @c_FromLoc  
  
               --Customized extended warehouse ASRS location   
               SET @c_ToLoc = @c_Facility + '_A'  
  
            END  
  
            --Select @c_FromLoc [@c_FromLoc], @c_ToLoc [@c_ToLoc], @c_PalletID [@c_PalletID], @c_Facility [@c_Facility], @c_Lottable09 [@c_Lottable09]  
            --TK02 - UseExtendedFacLoc - End  
  
            SET @c_MoveRefKey = ''  
            SET @b_success = 1      
            EXECUTE   nspg_getkey      
                     'MoveRefKey'      
                     , 10      
                     , @c_MoveRefKey       OUTPUT      
                     , @b_success          OUTPUT      
                     , @n_err              OUTPUT      
                     , @c_errmsg           OUTPUT   
  
            IF @b_success <> 1      
            BEGIN      
               SET @n_continue = 3  
               GOTO QUIT  
            END   
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET MoveRefKey = @c_MoveRefKey  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE Lot = @c_Lot  
            AND Loc = @c_FromLoc  
            AND ID = @c_PalletID  
            AND Status < '9'  
            AND ShipFlag <> 'Y'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 57773     
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                              + ': Update PICKDETIAL failed. (isp_TCP_WCS_MsgPutaway)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
            --Update all SKU on pallet to new ASRS LOC  
            EXEC nspItrnAddMove  
                     NULL                                         
                  , @c_StorerKey                -- @c_StorerKey     
                  , @c_Sku                      -- @c_Sku           
                  , @c_Lot                      -- @c_Lot           
                  , @c_FromLoc                  -- @c_FromLoc       
                  , @c_PalletID                 -- @c_FromID        
                  , @c_ToLoc                    -- @c_ToLoc         
                  , @c_PalletID                 -- @c_ToID          
                  , '0'                         -- @c_Status        
                  , ''                          -- @c_lottable01    
                  , ''                          -- @c_lottable02    
                  , ''                          -- @c_lottable03    
                  , NULL                        -- @d_lottable04    
                  , NULL                        -- @d_lottable05    
                  , ''                          -- @c_lottable06    
                  , ''                      -- @c_lottable07    
                  , ''                          -- @c_lottable08    
                  , ''                          -- @c_lottable09    
                  , ''                          -- @c_lottable10    
                  , ''                          -- @c_lottable11    
                  , ''                          -- @c_lottable12    
                  , NULL         -- @d_lottable13    
                  , NULL                        -- @d_lottable14    
                  , NULL                        -- @d_lottable15    
                  , 0                           -- @n_casecnt       
                  , 0                           -- @n_innerpack     
                  , @n_Qty                      -- @n_qty           
                  , 0                           -- @n_pallet        
                  , 0                           -- @f_cube          
                  , 0                           -- @f_grosswgt      
                  , 0                           -- @f_netwgt        
                  , 0                           -- @f_otherunit1    
                  , 0                           -- @f_otherunit2    
                  , @c_TaskDetailKey            -- @c_SourceKey  
                  ,'isp_TCP_WCS_MsgPutaway'     -- @c_SourceType  
                  , ''                          -- @c_PackKey       
                  , ''                          -- @c_UOM           
                  , 0                           -- @b_UOMCalc       
                  , NULL                        -- @d_EffectiveD    
                  , ''                          -- @c_itrnkey       
                  , @b_success  OUTPUT          -- @b_Success     
                  , @n_err      OUTPUT          -- @n_err         
                  , @c_errmsg   OUTPUT          -- @c_errmsg      
                  , @c_MoveRefKey               -- @c_MoveRefKey    
  
            IF @@ERROR <> 0 OR RTRIM(@c_errmsg) <> '' or @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               GOTO QUIT  
            END  
  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET MoveRefKey = ''  
               ,EditWho    = SUSER_NAME()  
               ,EditDate   = GETDATE()  
               ,Trafficcop = NULL  
            WHERE Lot = @c_Lot  
            AND Loc = @c_FromLoc  
            AND ID = @c_PalletID  
            AND Status < '9'  
            AND ShipFlag <> 'Y'  
            AND MoveRefKey = @c_MoveRefKey  
  
            IF @@ERROR <> 0   
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 57774     
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                              + ': UPDATE PICKDETAIL failed. (isp_TCP_WCS_MsgPutaway)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
            FETCH NEXT FROM C_CUR_UPDLLI3 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty, @c_SValue  
  
         END  
         CLOSE C_CUR_UPDLLI3  
         DEALLOCATE C_CUR_UPDLLI3  
  
         /*********************************************/  
         /* Update LLI.Loc - End                      */  
         /*********************************************/  
  
      END   --IF @c_MessageType = 'RECEIVE'  
   END      --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'QUIT',@n_continue [@n_continue], @c_Status [@c_Status], @n_Err [@n_Err], @c_ErrMsg [@c_ErrMsg]  
   END  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
     
      WHILE @@TRANCOUNT > @n_StartTCnt  
         ROLLBACK TRAN  
  
  
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
  
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TCP_WCS_MsgPutaway'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
  
      WHILE @@TRANCOUNT > @n_StartTCnt  
         COMMIT TRAN  
  
      RETURN  
   END  
  
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
  
   IF CURSOR_STATUS('LOCAL' , 'C_CUR_UPDLLI2') in (0 , 1)  
   BEGIN  
      CLOSE C_CUR_UPDLLI2  
      DEALLOCATE C_CUR_UPDLLI2  
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'C_CUR_UPDLLI3') in (0 , 1)  
   BEGIN  
      CLOSE C_CUR_UPDLLI3  
      DEALLOCATE C_CUR_UPDLLI3  
   END  
  
END  

GO