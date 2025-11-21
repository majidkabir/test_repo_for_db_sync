SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_TCP_WCS_MsgMove                                 */
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
/* 08-Mar-2015  TKLIM     1.0   IF ToLoc=GTM, FromLoc.Cat must be 'ASRS'*/
/* 08-Mar-2015  TKLIM     1.0   Skip CallOut when TaskDetail.Status = 0 */
/* 09-Mar-2015  TKLIM     1.0   Temporary Map WCS-WMS Loc (TK01)        */
/* 02-Dec-2015  TKLIM     1.0   Redo flow for retry & rollback (TK02)   */
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK03)   */
/* 28-Dec-2015  TKLIM     1.0   Improve performance on SEND proc (TK03) */
/* 12-APR-2017  BRLIM     1.0   FRB-WMS-1520(BL01)                      */
/* 20-Aug-2019  James     1.1   WMS-10081 Add stage loc lookup(james01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgMove]
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TASKUPDATE'  etc....
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
   , @b_debug           INT          = 0
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
         , @c_SKU                NVARCHAR(20)   
         , @c_Lot                NVARCHAR(10)   
         , @c_PhotoReq           NVARCHAR(1)   
         , @c_LabelReq           NVARCHAR(1)   
         , @c_MessageID          NVARCHAR(10)   
         , @n_Qty                INT
         , @c_FromLocCategory    NVARCHAR(10) 
         , @c_FromLocGroup       NVARCHAR(30) 
         , @c_FromLocLogical     NVARCHAR(18)
         , @c_ToLocCategory      NVARCHAR(10) 
         , @c_ToLocGroup         NVARCHAR(30) 
         , @c_ToLocLogical       NVARCHAR(18)
         , @c_LogicalFromLoc     NVARCHAR(10) 
         , @c_LogicalToLoc       NVARCHAR(10) 
         , @c_FinalLoc           NVARCHAR(10) 
         , @n_TmpSerialNo        INT 

   --Constant Variables
   DECLARE @c_LOCGRP_LOOP        NVARCHAR(30)
         , @c_LOCGRP_EPS         NVARCHAR(30)
         , @c_LOCGRP_REJECT      NVARCHAR(30)
         , @c_LOCGRP_GTMWS       NVARCHAR(30)
         , @c_LOCGRP_GTMWS1      NVARCHAR(30)
         , @c_LOCGRP_GTMWS2      NVARCHAR(30)
         , @c_LOCGRP_GTMWS3      NVARCHAR(30)
         , @c_LOCGRP_GTMWS4      NVARCHAR(30)
         , @c_LOCCAT_ASRS        NVARCHAR(10)
         , @c_LOCCAT_GTM         NVARCHAR(10)
         , @c_LOCCAT_OUTST       NVARCHAR(10)
         , @c_LOGLOC_A           NVARCHAR(18)
         , @c_LOGLOC_B           NVARCHAR(18)
         , @c_LOGLOC_C           NVARCHAR(18)
         , @c_SourceKey          NVARCHAR(30)
         , @c_SourceType         NVARCHAR(30)
         , @c_RDTOutMove         NVARCHAR(10)
         , @c_GTMKioskJob        NVARCHAR(10)
         , @c_SkipCallOut        NVARCHAR(1)
         , @c_NewTaskDetailKey   NVARCHAR(10)
         , @c_MoveRefKey         NVARCHAR(10)
         , @c_Orderkey           NVARCHAR(10)
         , @c_PickMethod         NVARCHAR(10)

   DECLARE @c_MapWCSLoc          NVARCHAR(1)    --(TK01) translate WCS Location to WMS Location
         , @c_WCSToLoc           NVARCHAR(10)   --(TK01)
         , @c_WCSFromLoc         NVARCHAR(10)   --(TK01)
         , @c_OrigLoc            NVARCHAR(10)   --(TK04)
         , @c_Loc                NVARCHAR(10)   --(TK04)

   DECLARE @nErrNo               INT         
         , @cErrMsg              NVARCHAR(250) 

   SET @n_StartTCnt              = @@TRANCOUNT
   SET @n_continue               = 1 
   SET @c_ExecStatements         = '' 
   SET @c_ExecArguments          = ''
   SET @b_Success                = 1
   SET @n_Err                    = 0
   SET @c_ErrMsg                 = ''

   SET @c_MessageGroup           = 'WCS'
   SET @c_StorerKey              = ''
   SET @c_Application            = 'GenericTCPSocketClient_WCS'
   SET @c_Status                 = '9'
 SET @n_NoOfTry                = 0
   SET @c_LogicalFromLoc         = ''
   SET @c_LogicalToLoc           = ''
   SET @c_FinalLoc               = ''

   --Constant Variables
   SET @c_LOCGRP_LOOP            = 'GTMLOOP'
   SET @c_LOCGRP_EPS             = 'EPS'
   SET @c_LOCGRP_REJECT          = 'REJECT'
   SET @c_LOCGRP_GTMWS           = 'GTMWS'
   SET @c_LOCGRP_GTMWS1          = 'GTMWS1'
   SET @c_LOCGRP_GTMWS2          = 'GTMWS2'
   SET @c_LOCGRP_GTMWS3          = 'GTMWS3'
   SET @c_LOCGRP_GTMWS4          = 'GTMWS4'
   SET @c_LOCCAT_ASRS            = 'ASRS'
   SET @c_LOCCAT_GTM             = 'ASRSGTM'
   SET @c_LOCCAT_OUTST           = 'ASRSOUTST'
   SET @c_LOGLOC_A               = 'A'
   SET @c_LOGLOC_B               = 'B'
   SET @c_LOGLOC_C               = 'C'
   SET @c_SourceType             = 'isp_TCP_WCS_MsgMove'
   SET @c_RDTOutMove             = 'ASTMV'
   SET @c_GTMKioskJob            = 'GTMJOB'
   SET @c_SkipCallOut            = '0'
   SET @c_MapWCSLoc              = '1'    --(TK01)
   SET @c_NewTaskDetailKey       = ''
   SET @c_Orderkey               = ''
   SET @nErrNo                   = 0

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
        AND CODE2    = @c_CallerGroup      --TK03

      IF ISNULL(@c_RemoteEndPoint,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57851
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldWCSSvrIP' 
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgMove)'  
         GOTO QUIT 
      END

      IF ISNULL(@c_IniFilePath,'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57852  
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldCfgFPath' 
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgMove)'  
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
         SET @n_continue = 3
         SET @n_Err = 57853
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgName' 
                       + ': MessageName cannot be blank. (isp_TCP_WCS_MsgMove)'
         GOTO QUIT
      END

      IF ISNULL(RTRIM(@c_MessageType),'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57854
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgType' 
                       + ': MessageType cannot be blank. (isp_TCP_WCS_MsgMove)'
         GOTO QUIT
      END

      IF ISNULL(RTRIM(@c_PalletID),'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57855
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldPalletID' 
                       + ': PalletID cannot be blank. (isp_TCP_WCS_MsgMove)'
         GOTO QUIT
      END
      
      IF ISNULL(RTRIM(@c_ToLoc),'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57856
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldToLoc' 
                       + ': ToLoc cannot be blank for pallet (' + @c_PalletID + '). (isp_TCP_WCS_MsgMove)'
         GOTO QUIT
      END

   END
   ELSE
   BEGIN
      SET @c_MessageType = 'RECEIVE'

      IF @n_SerialNo = '0'
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57857
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgNum' 
                       + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgMove)'
         GOTO QUIT
      END

   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      IF ISNULL(RTRIM(@c_Priority),'') = ''
      BEGIN
         SET @c_Priority = '5'
      END

      IF @b_debug = 1
      BEGIN
         SELECT 'MSG DATA'
               ,@c_PalletID         [@c_PalletID] 
               ,@c_FromLoc          [@c_FromLoc] 
               ,@c_ToLoc            [@c_ToLoc]
               ,@c_Priority         [@c_Priority] 

      END


      /*********************************************/
      /* MessageType = 'SEND'                      */
      /*********************************************/
      IF @c_MessageType = 'SEND'
      BEGIN
         
         --BEGIN TRAN --TK02

         SELECT TOP 1 @c_Storerkey = StorerKey
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_PalletID
         AND QTY > 0

         --(TK01) - Start
         IF @c_MapWCSLoc = '1'
         BEGIN
            SELECT @c_WCSToLoc = CASE WHEN ISNULL(RTRIM(Code),'') <> '' THEN Code END
            FROM CODELKUP WITH (NOLOCK)
            WHERE ListName = 'MAPWCS2WMS' AND Short = @c_ToLoc

            IF ISNULL(RTRIM(@c_WCSToLoc),'') = ''
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57858
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrMapWCSLoc' 
                             + ': Unable to Map WCS Location (' + @c_ToLoc + '). (isp_TCP_WCS_MsgMove)'
               GOTO QUIT
            END

            SELECT @c_WCSFromLoc = CASE WHEN ISNULL(RTRIM(Code),'') <> '' THEN Code END
            FROM CODELKUP WITH (NOLOCK)
            WHERE ListName = 'MAPWCS2WMS' AND Short = @c_FromLoc

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

         --If ToLoc = GTMLOOP, FromLoc.LocationCategory must be 'ASRS' / GTM Area (include Loc='WCS01')
         --WCS01 LocationCategory is 'ASRS'
         IF @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocGroup = @c_LOCGRP_LOOP AND @c_FromLocCategory <> @c_LOCCAT_GTM
         BEGIN

            IF EXISTS ( SELECT 1 FROM LOTxLOCxID LLI WITH (NOLOCK)
                        JOIN LOC LOC WITH (NOLOCK)
                        ON LLI.LOC = LOC.LOC
                        JOIN PutawayZone PZ WITH (NOLOCK)
                        ON LOC.PutawayZone = PZ.PutawayZone
                        WHERE LLI.ID = @c_PalletID
                        AND LLI.Qty > 0
                        AND LOC.LocationCategory <> 'ASRS'                 -- WCS01 LocationCategory = 'ASRS'
                        AND PZ.PutawayZone NOT IN ('AMBIENT','AIRCOND'))   --TK01
            BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 57859   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^IDNotInASRS' 
                                + ': Pallet (' + @c_PalletID + ') must be in ASRS. (isp_TCP_WCS_MsgMove)'
                                + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
            END
         END

         --When Exceed Execute the SP, where ToLoc = GTM area, Should NOT update the LLI.Loc to 'WCS01'. Strategy will call out pallet to GTM
         --When Exceed Execute the SP, where ToLoc <> GTM area, Should update the LLI.Loc to 'WCS01' and call out pallet to Destination
         --Only GTMStrategy allow to call out to GTMLoop.
         --Exceed will create TaskDetail.Status = 0. 
         --SP will skip callout when TaskDetail.Status = 0
         --GTMStrategy must update the Status = '1' before call out pallet.
         --If FromLoc is GTM area, allow to proceed send move message.
         IF EXISTS ( SELECT 1 FROM TaskDetail WITH (NOLOCK)
                     WHERE TaskDetailKey = @c_TaskDetailKey
                     AND   FromID = @c_PalletID
                     AND   Status = '0')
            AND   @c_FromLocCategory <> @c_LOCCAT_GTM
            AND   @c_ToLocCategory = @c_LOCCAT_GTM 
            AND   @c_ToLocGroup = @c_LOCGRP_LOOP 
         BEGIN
            SET @c_SkipCallOut = '1'
         END

         --Skip Move message when FromLoc = ToLoc
         IF @c_SkipCallOut <> '1' AND @c_FromLoc = @c_ToLoc
         BEGIN
            SET @c_SkipCallOut = '1'
         END

         IF @c_SkipCallOut <> '1'
         BEGIN

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

            IF NOT EXISTS (SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_PalletID)
            BEGIN
               
               INSERT INTO ID (ID, VirtualLoc) VALUES (@c_PalletID, @c_OrigLoc)

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 57860   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsID' 
+ ': INSERT ID Fail. (isp_TCP_WCS_MsgMove)'
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
               END
            END
            ELSE
            BEGIN
               UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_OrigLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID AND VirtualLoc <> @c_OrigLoc

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 57861   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                                 + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
               END

            END

            /*********************************************/
            /* UPDATE PICKDETAIL AND ITRN                */
            /*********************************************/

            -- Check if current pallet location not in WCS01, Update loc to WCS01
            -- Query all related SKU and LOT on the pallet for LOC update
            DECLARE C_CUR_UPDLLI CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LLI.ID = @c_PalletID
            AND LLI.Qty > 0
            AND LLI.Loc <> 'WCS01'

            OPEN C_CUR_UPDLLI
            FETCH NEXT FROM C_CUR_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty

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
               AND Loc = @c_Loc
               AND ID = @c_PalletID
               AND Status < '9'
               AND ShipFlag <> 'Y'

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 57866   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt1' 
                                + ': Update PICKDETIAL Failed. (isp_TCP_WCS_MsgMove)'
                                + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
               END

               --Update all SKU on pallet to new ASRS LOC
               EXEC nspItrnAddMove
                    NULL 
                  , @c_StorerKey             -- @c_StorerKey 
                  , @c_Sku                   -- @c_Sku       
                  , @c_Lot                   -- @c_Lot       
                  , @c_Loc               -- @c_Loc   
                  , @c_PalletID              -- @c_FromID    
                  , 'WCS01'                  -- @c_ToLoc     
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
               AND Loc = @c_Loc
               AND ID = @c_PalletID
               AND Status < '9'
               AND ShipFlag <> 'Y'
               AND MoveRefKey = @c_MoveRefKey

               IF @@ERROR <> 0 
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 57867   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt2' 
                                + ': UPDATE PICKDETAIL Failed. (isp_TCP_WCS_MsgMove)'
                                + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
               END

               FETCH NEXT FROM C_CUR_UPDLLI INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty

            END
            CLOSE C_CUR_UPDLLI
            DEALLOCATE C_CUR_UPDLLI


            /*********************************************/
            /* INSERT INTO WCSTran                       */
            /*********************************************/

            --Prepare temp table to store MessageID
            IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL
               DROP TABLE #TmpTblMessageID
            CREATE TABLE #TmpTblMessageID(MessageID INT)

            INSERT INTO WCSTran (MessageName, MessageType, TaskDetailKey, PalletID, FromLoc, ToLoc, Priority, Status)
            OUTPUT INSERTED.MessageID INTO #TmpTblMessageID 
            VALUES (@c_MessageName, @c_MessageType, @c_TaskDetailKey, @c_PalletID, @c_WCSFromLoc, @c_WCSToLoc, @c_Priority, '0')      --(TK01)

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
            SET @n_Err = 57868   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsWCSTran1' 
                             + ': Insert WCSTran Fail. (isp_TCP_WCS_MsgMove)'
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            -- Get MessageID from Temp table #TmpTblMessageID
            SELECT TOP 1 @c_MessageID = ISNULL(RTRIM(MessageID),'')
            FROM #TmpTblMessageID

            SET @c_MessageID = RIGHT(REPLICATE('0', 9) + RTRIM(LTRIM(@c_MessageID)), 10)
         
            SET @c_SendMessage = '<STX>'                                                 --[STX]
                              + LEFT(LTRIM(@c_MessageID)    + REPLICATE(' ', 10) ,10)    --[MessageID]
                              + LEFT(LTRIM(@c_MessageName)  + REPLICATE(' ', 15) ,15)    --[MessageName]
                              + LEFT(LTRIM(@c_PalletID)     + REPLICATE(' ', 18) ,18)    --[PalletID]
                              + LEFT(LTRIM(@c_WCSFromLoc)   + REPLICATE(' ', 10) ,10)    --[WCSFromLoc]        --(TK01)
                              + LEFT(LTRIM(@c_WCSToLoc)     + REPLICATE(' ', 10) ,10)    --[ToLoc]
                              + LEFT(LTRIM(@c_Priority)     + REPLICATE(' ',  2) , 2)    --[Priority]
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
                     , SUBSTRING(@c_SendMessage,  1,  5) [STX]
                     , SUBSTRING(@c_SendMessage,  6, 10) [MessageID]
                     , SUBSTRING(@c_SendMessage, 16, 15) [MessageName]
                     , SUBSTRING(@c_SendMessage, 31, 18) [PalletID]
                     , SUBSTRING(@c_SendMessage, 49, 10) [WCSFromLoc]         --(TK01)
                     , SUBSTRING(@c_SendMessage, 59, 10) [WCSToLoc]
                     , SUBSTRING(@c_SendMessage, 69,  2) [Priority]
                     , SUBSTRING(@c_SendMessage, 71,  5) [ETX]

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
                  SET @n_Err = 57872  
SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTcpOutLg' 
                                 + ': INSERT TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgMove)'  
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
               --   SET @n_Err = 57869
               --   SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrExeTcpClnt' 
               --                  + ': EXEC isp_GenericTCPSocketClient Fail. (isp_TCP_WCS_MsgMove)'  
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
                  SET @n_Err = 57873  
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTcpOutLg' 
                                 + ': UPDATE TCPSocket_OUTLog Fail. (isp_TCP_WCS_MsgMove)'  
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
               SET @n_Err = 57869

               -- SET @cErrmsg  
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrExeTcpClnt' 
                                + ': EXEC isp_GenericTCPSocketClient Fail. (isp_TCP_WCS_MsgMove)'  
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
                  SET @n_Err = 57871   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdWCSTran1' 
                                + ': Update WCSTran Fail. (isp_TCP_WCS_MsgMove)'
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
                     'isp_TCP_WCS_MsgMove'
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
               FETCH NEXT FROM C_CUR_UPDLLI2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty

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
                  AND Loc = @c_Loc
                  AND ID = @c_PalletID
                  AND Status < '9'
                  AND ShipFlag <> 'Y'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 57889   
                     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt' 
                                   + ': Update PICKDETIAL Failed. (isp_TCP_WCS_MsgMove)'
                                   + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                     GOTO QUIT
                  END

                  --Update all SKU on pallet to new ASRS LOC
                  EXEC nspItrnAddMove
                       NULL 
                     , @c_StorerKey             -- @c_StorerKey 
                     , @c_Sku                   -- @c_Sku       
                     , @c_Lot                   -- @c_Lot       
                     , @c_Loc                   -- @c_Loc   
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
   AND Loc = @c_Loc
                  AND ID = @c_PalletID
                  AND Status < '9'
                  AND ShipFlag <> 'Y'
                  AND MoveRefKey = @c_MoveRefKey

                  IF @@ERROR <> 0 
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 57890   
                     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt' 
                                   + ': UPDATE PICKDETAIL Failed. (isp_TCP_WCS_MsgMove)'
                                   + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                     GOTO QUIT
                  END

                  FETCH NEXT FROM C_CUR_UPDLLI2 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @n_Qty

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
               --                 + ': Update TaskDetail Fail. (isp_TCP_WCS_MsgMove)'
               --                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
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
               /* - FROM GTM_Area => OUTBOUND                     EXCEPT A => B                       */
               /* - FROM GTM_Area => OUTBOUND (VAS)               EXCEPT C => B                       */
               /* - FROM GTM_Area => GTMLOOP                                                          */
               /* - FROM GTM_Area => REJECT                                                           */
               /* - FROM GTM_Area => EPS                                                              */
               /***************************************************************************************/
               IF @c_FromLocCategory = @c_LOCCAT_GTM AND @c_ToLocLogical <> @c_LOGLOC_B     --GTM B Location
               BEGIN

                  -- Clear VirtualLoc to avoid 2 ID have same VirtualLoc at the same Time.
                  -- Do not clear VirtualLoc for A > B and C > B because it may cause GTM Kiosk to update GTMJob Status incorrectly.
                  IF NOT EXISTS (SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_PalletID)
                  BEGIN
               
                     INSERT INTO ID (ID, VirtualLoc) VALUES (@c_PalletID, 'WCS01')

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 57860   
                        SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsID' 
 + ': INSERT ID Fail. (isp_TCP_WCS_MsgMove)'
                                      + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
         GOTO QUIT
                     END
                  END
                  ELSE
                  BEGIN
                     UPDATE ID WITH (ROWLOCK) SET VirtualLoc = 'WCS01', EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID AND VirtualLoc <> 'WCS01'

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 57861   
                        SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                                      + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                                      + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                        GOTO QUIT
                     END

                  END
               END
            
               /***************************************************************************************/
               /* - FROM GTM_B => GTMLOOP                                                             */
               /***************************************************************************************/
               IF @c_FromLocCategory = @c_LOCCAT_GTM 
                  AND ( @c_FromLocLogical = @c_LOGLOC_A     --GTM A Location
                     OR @c_FromLocLogical = @c_LOGLOC_B     --GTM B Location
                     OR @c_FromLocLogical = @c_LOGLOC_C     --GTM C Location
                  )   
                  AND @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocGroup = @c_LOCGRP_LOOP    --GTMLoop
               BEGIN

                  IF EXISTS ( SELECT 1 FROM TaskDetail WITH (NOLOCK)
                              WHERE TaskDetailKey = @c_TaskDetailKey
                              AND FroMID = @c_PalletID
                              AND Status = '7'
                  )
                  BEGIN

                     UPDATE TaskDetail WITH (ROWLOCK) SET Status = '1', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL 
                     FROM TaskDetail TD
                     JOIN GTMLoop GL WITH (NOLOCK) 
                     ON GL.TaskDetailKey = TD.TaskDetailKey 
                     AND GL.PalletID = TD.FromID
                     WHERE TD.TaskDetailKey = @c_TaskDetailKey
                     AND TD.Status = '7' 
                     AND TD.FromID = @c_PalletID

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 57862   
                        SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTaskDt' 
                                      + ': Update TaskDetail Fail. (isp_TCP_WCS_MsgMove)'
                                      + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                        GOTO QUIT
                     END

                     UPDATE GTMTask WITH (ROWLOCK) SET Status = '1'
                     FROM GTMTask GT
                     JOIN GTMLoop GL WITH (NOLOCK) 
                     ON GL.TaskDetailKey = GT.TaskDetailKey 
                     AND GL.PalletID = GT.PalletID
                     WHERE GT.TaskDetailKey = @c_TaskDetailKey
                     AND GT.Status = '7' 
                     AND GT.PalletID = @c_PalletID

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 57863   
                        SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdGTMTask' 
                                      + ': Update GTMTask Fail. (isp_TCP_WCS_MsgMove)'
                                      + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                        GOTO QUIT
                     END
                  END

                  --GTM Strategy will create a record into GTMLoop after send callout the pallet.
                  --When pallet reach GTMLoop, Update Status = 1
                  UPDATE GTMLoop WITH (ROWLOCK) SET TaskDetailKey = '', WorkStation = '', OrderKey = '', Priority = '', Status = '0'
                  WHERE PalletID = @c_PalletID
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 57864   
                     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdGTMLoop' 
                                   + ': Update GTMLoop Fail. (isp_TCP_WCS_MsgMove)'
                                   + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                     GOTO QUIT
                  END
               END

               /***************************************************************************************/
               /* - FROM GTM_Area => OUTBOUND                                                         */
               /* - FROM GTM_Area => OUTBOUND (VAS)                                                   */
               /* - FROM GTM_Area => REJECT                                                           */
               /* - FROM GTM_Area => EPS                                                              */
               /***************************************************************************************/
               IF @c_FromLocCategory = @c_LOCCAT_GTM
                  AND @c_ToLocGroup NOT IN (@c_LOCGRP_LOOP, @c_LOCGRP_GTMWS, @c_LOCGRP_GTMWS1, @c_LOCGRP_GTMWS2, @c_LOCGRP_GTMWS3, @c_LOCGRP_GTMWS4)
               BEGIN
               
                  --GTM Strategy will create a record into GTMLoop after send callout the pallet.
                  --DELETE from GTMLoop Table when move out of GTM area (To Outbound, Reject, EPS, ASRS)
                  DELETE FROM GTMLoop WHERE PalletID = @c_PalletID AND Status = '1'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 57865   
                     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrDelGTMLoop' 
                                    + ': DELETE GTMLoop Fail. (isp_TCP_WCS_MsgMove)'
                                    + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                     GOTO QUIT
                  END

               END

               /***************************************************************************************/
               /* - FROM ASRS => OUTBOUND                                                             */
               /* - FROM ASRS => OUTBOUND (VAS)                                                       */
               /***************************************************************************************/
               IF @c_FromLocCategory = @c_LOCCAT_ASRS AND @c_ToLocCategory = @c_LOCCAT_OUTST 
               BEGIN

                  IF EXISTS ( SELECT 1 FROM TaskDetail WITH (NOLOCK)
                              WHERE TaskDetailKey = @c_TaskDetailKey
                              AND FromID = @c_PalletID
                              AND Status = '0'
                  )
                  BEGIN

                     UPDATE TaskDetail WITH (ROWLOCK) SET Status = '1', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL 
                     FROM TaskDetail TD
                     WHERE TD.TaskDetailKey = @c_TaskDetailKey
                     AND TD.FromID = @c_PalletID
                     AND TD.Status = '0' 

                  END
               END

            END   --IF @n_continue <> 3

         END   --IF @c_SkipCallOut <> '1'

      END      --IF @c_MessageType = 'SEND'

      IF @b_debug = 1
      BEGIN
         SELECT 'MIDDLE', @b_success, @n_err, @c_ErrMsg  
      END

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
                @c_FromLoc       = SUBSTRING(Data, 54,  10),
                @c_ToLoc         = SUBSTRING(Data, 64,  10),
                @c_RespStatus    = SUBSTRING(Data, 74,  10),
                @c_RespReasonCode= SUBSTRING(Data, 84,  10),
                @c_RespErrMsg    = SUBSTRING(Data, 94, 100)
         FROM TCPSOCKET_INLOG WITH (NOLOCK)
         WHERE SerialNo = @n_SerialNo

         SELECT TOP 1 @c_Storerkey = StorerKey
         FROM LOTxLOCxID (NOLOCK)
         WHERE ID = @c_PalletID
         AND QTY > 0

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

         -- GET TaskDetailKey From WCSTRAN (MessageType = 'SEND')
         SELECT @c_TaskDetailKey = TaskDetailKey 
         FROM WCSTRAN (NOLOCK)
         WHERE MessageType = 'SEND' 
         AND MessageID = @c_OrigMessageID
         AND PalletID = @c_PalletID 

         ---- INSERT INTO WCSTran
         --INSERT INTO WCSTran (MessageName, MessageType, TaskDetailkey, WCSMessageID, OrigMessageID, PalletID, FromLoc, ToLoc, Status, ReasonCode, ErrMsg)
         --VALUES (@c_MessageName, @c_MessageType, @c_TaskDetailkey, @c_MessageID, @c_OrigMessageID, @c_PalletID, @c_FromLoc, @c_ToLoc, @c_RespStatus, @c_RespReasonCode, @c_RespErrMsg)

         -- UPDATE INTO WCSTran
         UPDATE WCSTran WITH (ROWLOCK) 
         SET   TaskDetailkey  = @c_TaskDetailkey
             , FromLoc        = @c_FromLoc
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
            SET @n_Err = 57874   
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdWCSTran2' 
                          + ': UPDATE WCSTran Fail. (isp_TCP_WCS_MsgMove)'
                          + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
            GOTO QUIT
         END

         /***************************************************************************************/
         /* - FROM ASRS => GTMLOOP                                                              */
         /* - FROM GTM_B => GTMLOOP                                                             */
         /***************************************************************************************/
         IF @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocGroup = @c_LOCGRP_LOOP    --GTMLoop
         BEGIN
            --GTM Strategy will create a record into GTMLoop after send callout the pallet.
            --When pallet reach GTMLoop, Update Status = 1
            UPDATE GTMLoop WITH (ROWLOCK) SET Status = 1 WHERE PalletID = @c_PalletID AND Status = '0'

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57875   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdGTMLoop' 
                             + ': UPDATE GTMLoop Fail. (isp_TCP_WCS_MsgMove)'
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --Update LOC into ID Table
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57876   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                              + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

         END

         /***************************************************************************************/
         /* - FROM GTMLOOP => GTM_A                                                             */
         /***************************************************************************************/
         --IF @c_FromLocCategory = @c_LOCCAT_GTM AND @c_FromLocGroup = @c_LOCGRP_LOOP          --GTMLoop
         --   AND @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocLogical = @c_LOGLOC_A           --GTM A Location
         IF @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocLogical = @c_LOGLOC_A           --GTM A Location
         BEGIN

            --Get LogicalFromLoc and LogicalToLog from GTMTask Table
            SELECT @c_LogicalFromLoc   = ISNULL(RTRIM(LogicalFromLoc),'')
                  ,@c_LogicalToLoc     = ISNULL(RTRIM(LogicalToLoc),'')
            FROM GTMTask WITH (NOLOCK)
            WHERE TaskDetailKey = @c_TaskDetailKey
            AND   PalletID = @c_PalletID

            --GTM Strategy will update TaskDetail.Status to '6' after sending Move msg from GTMLoop to A location.
            --When pallet reached A location, Update Status to '7'
            UPDATE TaskDetail WITH (ROWLOCK) SET Status = '7', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL 
            WHERE TaskDetailKey = @c_TaskDetailKey
            AND   FromID = @c_PalletID AND Status = '6'

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57877   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTaskDt' 
                             + ': UPDATE TaskDetail Fail. (isp_TCP_WCS_MsgMove)'
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

   --Update Status into GTMTask Table
       UPDATE GTMTask WITH (ROWLOCK) SET Status = '7' 
            WHERE TaskDetailKey = @c_TaskDetailKey
            AND   PalletID = @c_PalletID AND Status = '6'

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57878   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdGTMTask' 
                             + ': UPDATE GTMTask Fail. (isp_TCP_WCS_MsgMove)'
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --Update LOC into ID Table
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57879   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                              + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --Get new taskDetailKey for GTMJOB
            EXECUTE nspg_getkey  
                    'TaskDetailKey'  
                  , 10 
                  , @c_NewTaskDetailKey OUTPUT  
                  , @b_success       OUTPUT  
                  , @n_err           OUTPUT  
                  , @c_ErrMsg        OUTPUT  
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               GOTO QUIT
            END

            --Insert new TaskDetail (GTMJOB) for GTM Kiosk (FBR#315474)
            INSERT INTO TASKDETAIL (TaskDetailKey, TaskType, FromID, Status, LogicalFromLoc, LogicalToLoc, UserPosition, RefTaskkey, StorerKey)
            VALUES (@c_NewTaskDetailKey, @c_GTMKioskJob, @c_PalletID, '0', @c_LogicalFromLoc, @c_LogicalToLoc, @c_ToLocGroup, @c_TaskDetailKey,  @c_StorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57880   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^' 
                              + ': INSERT TASKDETAIL (GTMJOB) Fail. (ErrInsTskDtGTM)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

         END

         /***************************************************************************************/
         /* - FROM GTM_A => GTM_B                                                               */
         /* - FROM GTM_C => GTM_B                                                               */
         /***************************************************************************************/
         IF  @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocLogical = @c_LOGLOC_B        --GTM B Location
         BEGIN
            --Update LOC into ID Table
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID AND VirtualLoc <> @c_ToLoc

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57881   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                              + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

         END

         /***************************************************************************************/
         /* - FROM GTM_A => GTM_EPS                                                             */
         /* - FROM GTM_B => GTM_EPS                 */
         /* - FROM GTM_C => GTM_EPS                                                             */
         /***************************************************************************************/
         IF  @c_ToLocCategory = @c_LOCCAT_GTM AND @c_ToLocGroup = @c_LOCGRP_EPS        --EPS Stacker
         BEGIN
            --Update LOC into ID Table
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID AND VirtualLoc <> @c_ToLoc

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57882   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                              + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

         END

         /***************************************************************************************/
         /* - FROM ASRS => OUTBOUND                                                             */
         /* - FROM ASRS => OUTBOUND (VAS)                                                       */
         /* - FROM GTM_B  => OUTBOUND                                                           */
         /***************************************************************************************/
         IF @c_ToLocCategory = @c_LOCCAT_OUTST
         BEGIN

            -- Query all related SKU and LOT on the pallet for LOC update
            DECLARE C_CUR_UPDLLI3 CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.StorerKey, LLI.SKU, LLI.LOT, LLI.LOC, LLI.Qty
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            WHERE LLI.ID = @c_PalletID
            AND LLI.LOC <> @c_ToLoc
            AND LLI.Qty > 0

            OPEN C_CUR_UPDLLI3
            FETCH NEXT FROM C_CUR_UPDLLI3 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty

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

               IF NOT @b_success = 1    
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
                  SET @n_Err = 57883   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt' 
                                + ': Update PICKDETIAL Failed. (isp_TCP_WCS_MsgMove)'
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
                  , @c_ToLoc                 -- @c_ToLoc       
                  , @c_PalletID            -- @c_ToID        
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
                  SET @n_Err = 57884   
                  SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdPickDt' 
                                + ': UPDATE PICKDETAIL Failed. (isp_TCP_WCS_MsgMove)'
                                + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
                  GOTO QUIT
               END

               FETCH NEXT FROM C_CUR_UPDLLI3 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_FromLoc, @n_Qty

            END
            CLOSE C_CUR_UPDLLI3
            DEALLOCATE C_CUR_UPDLLI3

            --Update LOC into ID Table
            --TKLIM 20150526 - When 'PackNHold' pallet are called out to OUTBOUND, remove the 'PackNHold' Flag. It will be reflagged 'PackNHold' again during Putaway.
            UPDATE ID WITH (ROWLOCK) SET VirtualLoc = @c_ToLoc, PalletFlag = '', EditDate = GETDATE(), EditWho = SUSER_SNAME() WHERE ID = @c_PalletID  AND VirtualLoc <> @c_ToLoc

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57885   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdID' 
                              + ': UPDATE ID Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --When pallet reached Outbound location, Update Status to '9'
            UPDATE TaskDetail WITH (ROWLOCK) SET Status = '9', EditDate = GETDATE(), EditWho = SUSER_SNAME(), TrafficCop=NULL 
            WHERE TaskDetailKey = @c_TaskDetailKey AND Status <> '9' 

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57886   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrUpdTaskDt' 
                             + ': UPDATE TaskDetail Fail. (isp_TCP_WCS_MsgMove)'
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --Get LogicalFromLoc and LogicalToLog from GTMTask Table
            SELECT @c_FinalLoc   = ISNULL(RTRIM(FinalLoc),'')
                 , @c_SourceKey  = ISNULL(RTRIM(SourceKey),'')   
                 , @c_Orderkey   = ISNULL(RTRIM(Orderkey),'')
                 , @c_PickMethod = ISNULL(RTRIM(PickMethod),'')
            FROM TASKDETAIL WITH (NOLOCK)
            WHERE TaskDetailKey = @c_TaskDetailKey
            AND   FromID = @c_PalletID

            --Default value to avoid hitting cannot be constrain "Cannot insert the value NULL".
            IF ISNULL(RTRIM(@c_SourceKey),'') = ''    SET @c_SourceKey = ' '
            IF ISNULL(RTRIM(@c_PickMethod),'') = ''   SET @c_PickMethod = ' '             

            IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE ID = @c_PalletID AND QTY > 0)
            BEGIN
               SET @c_PickMethod = 'NMV'
               SET @c_Storerkey = 'DMYSTR'
            END

            IF @c_FinalLoc = '' --AND @c_SourceKey = '' AND @c_Orderkey = '' AND @c_PickMethod = ''
            BEGIN
               ----Select 1 of the staging area link to that outbound point as Final Loc (RDT ToLoc)
               --SELECT TOP 1 @c_FinalLoc = ISNULL(FL.LOC,'')
               --FROM LOC FL WITH (NOLOCK)
               --JOIN LOC TL WITH (NOLOCK)
               --ON TL.PutawayZone = FL.PutawayZone
               --AND TL.LocationCategory = 'ASRSOUTST'
               --AND TL.Loc = @c_ToLoc
               --WHERE FL.LocationCategory = 'STAGING'

               --Default 
               SELECT @c_FinalLoc = ISNULL(FL.LOC,'')
               FROM LOC TL WITH (NOLOCK)
               JOIN LOC FL WITH (NOLOCK)
               ON TL.Floor = FL.Floor
               AND FL.LocationCategory = 'FMSTAGE'
               AND FL.PutawayZone = 'FMSTAGE'
               WHERE TL.Loc = @c_ToLoc
               AND TL.LocationCategory = 'ASRSOUTST'

            END

            ----------------------------------
            -- FBR#WMS-1520 A (BL01)
            ----------------------------------
            Declare @cFacility nvarchar(5)

            SELECT @c_PickMethod = ISNULL(PickMethod,'')
                  ,@cFacility = Facility
            FROM Loc (NOLOCK) WHERE Loc = @c_ToLoc

            declare @c_FinalLoc1   nvarchar( 10)
            set @c_FinalLoc1 = @c_FinalLoc

            -- (james01)
            DECLARE @cInterFloorMvLoc  NVARCHAR( 10)
            SET @cInterFloorMvLoc = ''

            IF @c_PickMethod = 'A'
            BEGIN
               SELECT TOP 1 @cInterFloorMvLoc = code2 
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'INTERFLOOR'
               AND   Code = @c_ToLoc
               ORDER BY 1

               IF @@ROWCOUNT > 0
                  SET @c_FinalLoc = @cInterFloorMvLoc
            END

            --Get new taskDetailKey for RDT ASTMV Task
            EXECUTE nspg_getkey  
                    'TaskDetailKey'  
                  , 10 
                  , @c_NewTaskDetailKey OUTPUT  
                  , @b_success       OUTPUT  
                  , @n_err           OUTPUT  
                  , @c_ErrMsg        OUTPUT  
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               GOTO QUIT
            END

            --Insert new TaskDetail (RDT) for RDT (FBR#332780)
            INSERT INTO TASKDETAIL (TaskDetailKey, TaskType, FromID, FromLoc, ToLoc, Priority, SourcePriority, Status, SourceType, SourceKey, RefTaskkey, Storerkey, Orderkey, PickMethod)
            VALUES (@c_NewTaskDetailKey, @c_RDTOutMove, @c_PalletID, @c_ToLoc, @c_FinalLoc, @c_Priority, @c_Priority, '0', @c_SourceType, @c_SourceKey, @c_TaskDetailKey, @c_Storerkey, @c_Orderkey, @c_PickMethod)

            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 57887   
               SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTskDtRDT' 
                              + ': INSERT TASKDETAIL (RDT Move to Lane) Fail. (isp_TCP_WCS_MsgMove)'
                              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')
               GOTO QUIT
            END

            --If PickMethod = A only
            IF @c_PickMethod = 'A'
            BEGIN
                  --select @cFacility, @c_Storerkey, @c_NewTaskDetailKey, @c_FinalLoc, @nErrNo, @cErrMsg
               Execute [RDT].[rdt_TM_Assist_Move_Confirm]
                           @nMobile         = 0
                        ,@nFunc           = 1816
                        ,@cLangCode       = 'ENG'
                        ,@nStep           = 0 
                        ,@nInputKey       = 0
                        ,@cFacility       = @cFacility
                        ,@cStorerKey      = @c_Storerkey
                        ,@cTaskdetailKey  = @c_NewTaskDetailKey
                        ,@cFinalLOC       = @c_FinalLoc
                        ,@nErrNo          = @nErrNo  OUTPUT 
                        ,@cErrMsg         = @cErrMsg OUTPUT

                  --select @cFacility, @c_Storerkey, @c_NewTaskDetailKey, @c_FinalLoc, @nErrNo, @cErrMsg

                  IF @nErrNo <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = @nErrNo   
                     SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrInsTskDtRDT' 
                                    + ': Auto Move To Lane (RDT Move to Lane) Fail. (isp_TCP_WCS_MsgMove)'
                                    + ' sqlsvr message=' + ISNULL(RTRIM(@cErrMsg), '')
                     GOTO QUIT
                  END

            END

         END

      END   --IF @c_MessageType = 'RECEIVE'
   END   --IF @n_Continue = 1 OR @n_Continue = 2

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

         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TCP_WCS_MsgMove'
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