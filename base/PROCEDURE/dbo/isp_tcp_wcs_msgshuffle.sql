SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgShuffle                              */  
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
/* Date         Author    Ver.  Purposes                                */  
/* 23-10-2015   Barnett   1.0   ASRS internal Shuffle not going to      */  
/*                              update to LLI. update ID.VirtualLoc     */  
/* 05-12-2015   TKLIM     1.1   MapWCS2WMS location (TK01)              */  
/* 05-12-2015   TKLIM     1.1   Handle ITRN Move for Reject Point (TK02)*/  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK02)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgShuffle]  
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
      
   DECLARE @c_MessageID          NVARCHAR(10)     
         , @c_StorerKey          NVARCHAR(15)     
         , @c_SKU                NVARCHAR(20)     
         , @c_Lot                NVARCHAR(10)     
         , @n_Qty                INT  
         , @c_FromLocCategory    NVARCHAR(10)   
         , @c_FromLocGroup       NVARCHAR(30)   
         , @c_FromLocLogical     NVARCHAR(18)  
         , @c_ToLocCategory      NVARCHAR(10)   
         , @c_ToLocGroup         NVARCHAR(30)   
         , @c_ToLocLogical       NVARCHAR(18)  
  
   --Constant Variables  
   DECLARE @c_LOCCAT_ASRS        NVARCHAR(30)  
         , @c_LOCCAT_GTM         NVARCHAR(10)  
         , @c_LOCGRP_REJECT      NVARCHAR(10)   --(TK02)  
         , @c_LOGLOC_A           NVARCHAR(18)  
         , @c_LOGLOC_B           NVARCHAR(18)  
         , @c_LOGLOC_C           NVARCHAR(18)  
         , @c_SourceKey          NVARCHAR(30)  
     
   DECLARE @c_MapWCSLoc          NVARCHAR(1)    --(TK01) translate WCS Location to WMS Location  
         , @c_WCSToLoc           NVARCHAR(10)   --(TK01)  
         , @c_WCSFromLoc         NVARCHAR(10)   --(TK01)  
         , @c_MoveRefKey         NVARCHAR(10)   --(TK02)  
  
   SET @n_continue               = 1   
   SET @c_ExecStatements         = ''   
   SET @c_ExecArguments          = ''  
   SET @b_Success                = '1'  
   SET @n_Err                    = 0  
   SET @c_ErrMsg                 = ''  
  
   --Constant Variables  
   SET @c_LOCCAT_ASRS            = 'ASRS'  
   SET @c_LOCCAT_GTM             = 'ASRSGTM'  
   SET @c_LOCGRP_REJECT          = 'REJECT'  
   SET @c_LOGLOC_A               = 'A'  
   SET @c_LOGLOC_B               = 'B'  
   SET @c_LOGLOC_C               = 'C'  
   SET @c_MapWCSLoc              = '1'    --(TK01)  
   SET @c_MoveRefKey             = ''     --(TK02)  
  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'INIT DATA'  
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
   IF @c_MessageType = 'RECEIVE'  
   BEGIN  
  
      IF @n_SerialNo = '0'  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68001  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                     + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgShuffle)'  
         GOTO QUIT  
      END  
  
       --NOTE: For WCS => WMS messages, Basic blank value validation are done in isp_TCP_WCS_MsgValidation  
  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      /*********************************************/  
      /* MessageType = 'RECEIVE'                   */  
      /*********************************************/  
      IF @c_MessageType = 'RECEIVE'  
      BEGIN  
         SELECT @c_MessageID     = SUBSTRING(Data,  1,  10),  
                @c_MessageName   = SUBSTRING(Data, 11,  15),  
                @c_PalletID      = SUBSTRING(Data, 26,  18),  
                @c_FromLoc       = SUBSTRING(Data, 44,  10),  
                @c_ToLoc         = SUBSTRING(Data, 54,  10)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
           
         --(TK01) - Start  
         IF @c_MapWCSLoc = '1'  
         BEGIN  
            SET @c_WCSToLoc = @c_ToLoc  
            SET @c_WCSFromLoc = @c_FromLoc  
  
            SELECT @c_ToLoc = CASE WHEN ISNULL(RTRIM(Short),'') <> '' THEN Short END  
            FROM CODELKUP WITH (NOLOCK)  
            WHERE ListName = 'MAPWCS2WMS' AND Code = @c_WCSToLoc  
  
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
  
         ---- INSERT INTO WCSTran  
         --INSERT INTO WCSTran (MessageName, MessageType, WCSMessageID, PalletID, FromLoc, ToLoc)  
         --VALUES (@c_MessageName, @c_MessageType, @c_MessageID, @c_PalletID, @c_FromLoc, @c_ToLoc)  
        
         --IF @@ERROR <> 0  
         --BEGIN  
         --   SET @b_Success = 0  
         --   SET @n_err=68010     
         --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
         --                 + ': INSERT WCSTran failed. (isp_TCP_WCS_MsgShuffle)'  
         --                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
         --   GOTO QUIT  
         --END  
  
         --Shuffling Empty Pallet to GTM C Location  
         --IF (@c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocLogical = @c_LOGLOC_C)             -- Destacker to GTM C Location  
         --   OR (@c_FromLocCategory = @c_LOCCAT_ASRS AND @c_ToLocCategory = @c_LOCCAT_ASRS)   -- ASRS to ASRS  
         --BEGIN  
  
         IF NOT EXISTS (SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_PalletID)  
         BEGIN  
            -- INSERT INTO ID  
            INSERT INTO ID (ID, VirtualLoc) VALUES (@c_PalletID, @c_ToLoc)  
                       
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_err=68011     
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                              + ': INSERT ID failed. (isp_TCP_WCS_MsgShuffle)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
         END  
         ELSE  
         BEGIN  
            -- UPDATE ID  
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID  
                       
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_err=68012     
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                              + ': UPDATE ID failed. (isp_TCP_WCS_MsgShuffle)'  
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
         END  
         --END  
  
         -- TKLIM 20151205 - When pallet Rejected at rejection point, Move it to Reject Lane.  
         -- TKLIM 20151025 - Do Not Track WCS Internal Reshuffle from ASRS to ASRS Location becasue it will cause many ITRN records which affect performance.  
         --ELSE IF (@c_FromLocCategory = @c_LOCCAT_ASRS AND @c_ToLocCategory = @c_LOCCAT_ASRS)    
         --BEGIN  
         IF NOT (ISNULL(RTRIM(@c_FromLocCategory),'') = @c_LOCCAT_ASRS AND ISNULL(RTRIM(@c_ToLocCategory),'') = @c_LOCCAT_ASRS)   
         BEGIN  
              
            IF @c_ToLocGroup = @c_LOCGRP_REJECT   
            BEGIN  
  
               SELECT @c_ToLoc = ISNULL(RTRIM(LANE.Loc),'')  
               FROM LOC LOC WITH (NOLOCK)   
               INNER JOIN LOC LANE WITH (NOLOCK)  
               ON LANE.PutawayZone = LOC.PutawayZone   
               AND LANE.LocationCategory = 'STAGING'  
               WHERE LOC.LOC = @c_Toloc  
  
               IF @c_ToLoc = ''  
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = 68013  
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                              + 'RejectLane not be blank. (isp_TCP_WCS_MsgShuffle)'  
                  GOTO QUIT  
               END  
            END  
  
            /*********************************************/  
            /* Update LLI.Loc - Start                    */  
            /*********************************************/  
  
            -- Query all related SKU and LOT on the pallet for LOC update  
            DECLARE C_UPDLLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
            SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty  
            FROM LOTxLOCxID LLI WITH (NOLOCK)  
            WHERE LLI.ID = @c_PalletID  
            AND LLI.Qty > 0  
            AND LLI.LOC <> @c_ToLoc  
  
            OPEN C_UPDLLI  
            FETCH NEXT FROM C_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty  
  
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
                  SET @n_Err = 68014     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                                 + ': Update PICKDETIAL failed. (isp_TCP_WCS_MsgShuffle)'  
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
                     , @c_MessageID                -- @c_SourceKey  
                     ,'isp_TCP_WCS_MsgShuffle'     -- @c_SourceType  
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
                  SET @n_Err = 68015     
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt'   
                                 + ': UPDATE PICKDETAIL failed. (isp_TCP_WCS_MsgShuffle)'  
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
                  GOTO QUIT  
               END  
  
               FETCH NEXT FROM C_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty  
  
            END  
            CLOSE C_UPDLLI  
            DEALLOCATE C_UPDLLI  
  
            /*********************************************/  
            /* Update LLI.Loc - End                      */  
            /*********************************************/  
  
         END  
      END   --IF @c_MessageType = 'RECEIVE'  
   END      --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
  
   IF CURSOR_STATUS('LOCAL' , 'C_CUR_UPDLLI') in (0 , 1)  
   BEGIN  
      CLOSE C_CUR_UPDLLI  
      DEALLOCATE C_CUR_UPDLLI  
   END  
END  

GO