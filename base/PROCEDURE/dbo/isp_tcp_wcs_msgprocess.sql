SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_TCP_WCS_MsgProcess                              */
/* Creation Date: 23 Sep 2014                                           */
/* Copyright: LFL                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose: Generic stor proc that Query TCPSocket_Process table based  */
/*          on ProjectName and MessageName                              */
/*                                                                      */
/* Called By: Exceed / RDT                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 31-Mar-2015  TKLIM     1.0   Force upper case bcos WCS case sensitive*/
/* 06-Nov-2015  TKLIM     1.0   Enhance ErrNo and ErrMsg to support RDT */
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK01)   */
/* 18-May-2017  BARNETT   1.0   Add New MessageName 'REQ4PUTAWAY'       */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgProcess]
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TSKUPD', 'INVQRY', 'PLTSWAP'  etc....
   , @c_MessageType     NVARCHAR(15)   = ''  --'SEND', 'RECEIVE'
   , @c_OrigMessageID   NVARCHAR(10)   = ''  
   , @c_PalletID        NVARCHAR(18)   = ''  --PalletID
   , @c_FromLoc         NVARCHAR(10)   = ''  --From Loc (Optional: Blank when calling out from ASRS)
   , @c_ToLoc           NVARCHAR(10)   = ''  --To Loc (Blank for 'PUTAWAY')
   , @c_Priority        NVARCHAR(1)    = ''  --for 'MOVE' and 'TSKUPD' message
   , @c_UD1             NVARCHAR(20)   = ''  --TaskUpdCode / ToPallet
   , @c_UD2             NVARCHAR(20)   = ''  --LabelReq / Weight
   , @c_UD3             NVARCHAR(20)   = ''  --Storer / Height
   , @c_TaskDetailKey   NVARCHAR(10)   = ''  --TaskDetailKey
   , @n_SerialNo        INT            = '0'  --Serial No from TCPSocket_InLog for @c_MessageType = 'RECEIVE'
   , @b_debug           INT            = '0'
   , @b_Success         INT            = '1' OUTPUT
   , @n_Err             INT            = '0' OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT

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
    
   DECLARE @c_MessageGroup       NVARCHAR(20)   
         , @c_StorerKey          NVARCHAR(15)   
         , @c_SProcName          NVARCHAR(100)

   DECLARE @c_WCSMessageID       NVARCHAR(10)   
         , @c_RespStatus         NVARCHAR(10)   --for responce from WCS
         , @c_RespReasonCode     NVARCHAR(10)   --for responce from WCS
         , @c_RespErrMsg         NVARCHAR(100)  --for responce from WCS
         --, @c_UD2                NVARCHAR(20)   --LabelReq / Weight
         --, @c_UD3                NVARCHAR(20)   --Storer / Height
         , @c_UD4                NVARCHAR(20)   
         , @c_UD5                NVARCHAR(20)   
         , @c_Param1             NVARCHAR(20)   --PAway_SKU1  / EPS_Pallet1 
         , @c_Param2             NVARCHAR(20)   --PAway_SKU2  / EPS_Pallet2 
         , @c_Param3             NVARCHAR(20)   --PAway_SKU3  / EPS_Pallet3 
         , @c_Param4             NVARCHAR(20)   --PAway_SKU4  / EPS_Pallet4 
         , @c_Param5             NVARCHAR(20)   --PAway_SKU5  / EPS_Pallet5 
         , @c_Param6             NVARCHAR(20)   --PAway_SKU6  / EPS_Pallet6 
         , @c_Param7             NVARCHAR(20)   --PAway_SKU7  / EPS_Pallet7 
         , @c_Param8             NVARCHAR(20)   --PAway_SKU8  / EPS_Pallet8 
         , @c_Param9             NVARCHAR(20)   --PAway_SKU9  / EPS_Pallet9 
         , @c_Param10            NVARCHAR(20)   --PAway_SKU10 / EPS_Pallet10
         , @c_CallerGroup        NVARCHAR(30)   --CallerGroup  

   SET @n_continue               = 1 
   SET @c_ExecStatements         = '' 
   SET @c_ExecArguments          = ''

   SET @c_MessageGroup           = 'WCS'
   SET @c_StorerKey              = ''
   SET @c_SProcName              = ''

   SET @c_MessageType            = 'SEND'    --'SEND', 'RECEIVE'
   SET @c_WCSMessageID           = ''
   SET @c_RespStatus             = ''
   SET @c_RespReasonCode         = ''
   SET @c_RespErrMsg             = ''
   --SET @c_UD2                    = ''
   --SET @c_UD3                    = ''
   SET @c_UD4                    = ''
   SET @c_UD5                    = ''
   SET @c_Param1                 = ''
   SET @c_Param2                 = ''
   SET @c_Param3                 = ''
   SET @c_Param4                 = ''
   SET @c_Param5                 = ''
   SET @c_Param6                 = ''
   SET @c_Param7                 = ''
   SET @c_Param8                 = ''
   SET @c_Param9                 = ''
   SET @c_Param10                = ''

   SET @c_MessageName            = UPPER(@c_MessageName)
   SET @c_MessageType            = UPPER(@c_MessageType)
   SET @c_OrigMessageID          = UPPER(@c_OrigMessageID)
   SET @c_PalletID               = UPPER(@c_PalletID)
   SET @c_FromLoc                = UPPER(@c_FromLoc)
   SET @c_ToLoc                  = UPPER(@c_ToLoc)
   SET @c_Priority               = UPPER(@c_Priority)
   SET @c_UD1                    = UPPER(@c_UD1)
   SET @c_UD2                    = UPPER(@c_UD2)
   SET @c_UD3                    = UPPER(@c_UD3)
   SET @c_TaskDetailKey          = UPPER(@c_TaskDetailKey)

   /*********************************************/
   /* Validation                                */
   /*********************************************/

   IF ISNULL(RTRIM(@c_MessageType),'') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_Err = 57801
      SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgType' 
                     + ': MessageType cannot be blank. (isp_TCP_WCS_MsgProcess)'
      GOTO QUIT
   END  
   ELSE IF @c_MessageType = 'SEND'
   BEGIN
      IF ISNULL(RTRIM(@c_MessageName),'') = ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57802
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgName' 
                       + ': MessageName cannot be blank. (isp_TCP_WCS_MsgProcess)'
         GOTO QUIT
      END

      IF ISNULL(RTRIM(@c_MessageName),'') = 'INVQUERY' 
      BEGIN
         IF ISNULL(RTRIM(@c_PalletID),'') = '' AND ISNULL(RTRIM(@c_FromLoc),'') = '' 
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 57803
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldID/FmLoc' 
                          + ': PalletID and FromLoc cannot be blank for InvQuery. (isp_TCP_WCS_MsgProcess)'
            GOTO QUIT
         END
      END
      ELSE 
      BEGIN
         IF ISNULL(RTRIM(@c_PalletID),'') = ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 57804
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldPalletID' 
                           + ': PalletID cannot be blank. (isp_TCP_WCS_MsgProcess)'
            GOTO QUIT
         END
      END

      IF ISNULL(RTRIM(@c_MessageName),'') = 'PUTAWAY' 
      BEGIN
         IF ISNULL(RTRIM(@c_FromLoc),'') = '' 
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 57806
            SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldFromLoc' 
                          + ': FromLoc cannot be blank for PUTAWAY. (isp_TCP_WCS_MsgProcess)'
            GOTO QUIT
         END
      END

   END
   ELSE  --IF @c_MessageType = 'RECEIVE'
   BEGIN
      SET @c_MessageType = 'RECEIVE'

      IF @n_SerialNo = '0'
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 57805
         SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^InvaldMsgNum' 
                       + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgProcess)'
         GOTO QUIT
      END
   END

   /*********************************************/
   /* Start Process                             */
   /*********************************************/   
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN

      --(TK01) Start
      IF ISNULL(RTRIM(@c_MessageName),'') = 'PUTAWAY'
      BEGIN

         SET @c_CallerGroup = 'OTH'

         IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)
                     WHERE ListName = 'MAPWCS2WMS' 
                     AND UDF01 = 'IN'                    --Induction
                     AND (Code = @c_FromLoc OR Short = @c_FromLoc)
         )
         BEGIN
            SET @c_CallerGroup = 'RDT'
         END
         ELSE IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)
                     WHERE ListName = 'MAPWCS2WMS' 
                     AND UDF01 = 'GTM'                    --GTM
                     AND (Code = @c_FromLoc OR Short = @c_FromLoc)
         )
         BEGIN
            SET @c_CallerGroup = 'PA_GTM'
         END


      END
      ELSE IF ISNULL(RTRIM(@c_MessageName),'') = 'MOVE'
      BEGIN

         SET @c_CallerGroup = 'OTH'

         --IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)
         --            WHERE ListName = 'MAPWCS2WMS' 
         --            AND UDF01 = 'GTM'                   --GTM
         --            AND (Code  IN (@c_FromLoc , @c_ToLoc) OR Short IN (@c_FromLoc , @c_ToLoc) )
         --)
         --BEGIN
         --   SET @c_CallerGroup = 'GTM'
         --END

         IF @c_ToLoc = 'GTMLOOP'
            AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
                        WHERE ListName = 'MAPWCS2WMS' 
                        AND UDF01 = 'GTM'                   --GTM
                        AND Short = @c_ToLoc)
         BEGIN
            SET @c_CallerGroup = 'MV_2LOOP'            
         END
         ELSE IF @c_ToLoc IN ('GTM1A','GTM2A','GTM3A','GTM4A')
            AND EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)
                     WHERE ListName = 'MAPWCS2WMS' 
                     AND UDF01 = 'GTM'                   --GTM
                     AND Short = @c_ToLoc
                  ) 
         BEGIN
            SET @c_CallerGroup = 'MV_2GTMA'
         END
         ELSE IF (@c_ToLoc IN ('GTM1B','GTM2B','GTM3B','GTM4B')
            OR @c_FromLoc IN ('GTM1A','GTM2A','GTM3A','GTM4A'))
            AND EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)
                     WHERE ListName = 'MAPWCS2WMS' 
                     AND UDF01 = 'GTM'                   --GTM
                     AND (Short = @c_ToLoc OR  Short = @c_FromLoc)
                  ) 
         BEGIN
            SET @c_CallerGroup = 'MV_2GTMB'
         END

      END
      ELSE IF ISNULL(RTRIM(@c_MessageName),'') = 'REQ4PUTAWAY'
      BEGIN
         SET @c_CallerGroup = 'RDT'  -- Use RDT is because after this module enable, RDT will not send PUTAWAY message anymore.
         
         --Log Received REQ4PUTAWAY in WCSTran
         INSERT INTO WCSTran (MessageName, MessageType, TaskDetailKey, PalletID, FromLoc)
         VALUES (@c_MessageName, @c_MessageType, '', @c_PalletID, @c_FromLoc)

         SELECT @c_FromLoc = isnull(Short, '')
         FROM CODELKUP (NOLOCK)
         WHERE ListName = 'MAPWCS2WMS' 
               AND UDF01 = 'IN' --Induction
               AND (Code = @c_FromLoc OR Short = @c_FromLoc)

         
         SET @c_MessageType ='SEND'
         SET @c_MessageName ='PUTAWAY'        


         IF @c_FromLoc = ''
         BEGIN               
               SET @c_ToLoc='REJECT'
         END

      END
      ELSE IF ISNULL(RTRIM(@c_MessageName),'') IN ('SHUFFLE','PLTSWAP','PRINTLABEL','PHOTO','EPS','TASKUPDATE','INVQUERY')
      BEGIN
         SET @c_CallerGroup = 'OTH'
      END
      --(TK01) End

      --Query SubStorProc from TCPSocket_Process
      SELECT @c_SProcName = SProcName 
      FROM dbo.TCPSocket_Process WITH (NOLOCK)
      WHERE StorerKey   = @c_StorerKey
      AND MessageGroup  = @c_MessageGroup
      AND MessageName   = @c_MessageName
      
      SET @c_ExecArguments  = '' 
      SET @c_ExecStatements = N'EXEC ' + @c_SProcName
                           + '  @c_MessageName'
                           + ', @c_MessageType'
                           + ', @c_TaskDetailKey'
                           + ', @n_SerialNo'
                           + ', @c_WCSMessageID'
                           + ', @c_OrigMessageID'
                           + ', @c_PalletID'
                           + ', @c_FromLoc'
                           + ', @c_ToLoc'
                           + ', @c_Priority'
                           + ', @c_RespStatus'
                           + ', @c_RespReasonCode'
                           + ', @c_RespErrMsg'
                           + ', @c_UD1'
                           + ', @c_UD2'
                           + ', @c_UD3'
                           + ', @c_UD4'
                           + ', @c_UD5'
                           + ', @c_Param1'
                           + ', @c_Param2'
                           + ', @c_Param3'
                           + ', @c_Param4'
                           + ', @c_Param5'
                           + ', @c_Param6'
                           + ', @c_Param7'
                           + ', @c_Param8'
                           + ', @c_Param9'
                           + ', @c_Param10'
                           + ', @c_CallerGroup'
                           + ', @b_debug '
                           + ', @b_Success         OUTPUT'
                           + ', @n_Err             OUTPUT'
                           + ', @c_ErrMsg          OUTPUT'

      SET @c_ExecArguments =  N'@c_MessageName     NVARCHAR(15)'
                           + ', @c_MessageType     NVARCHAR(10)'
                           + ', @c_TaskDetailKey   NVARCHAR(10)'
                           + ', @n_SerialNo        INT'
                           + ', @c_WCSMessageID    NVARCHAR(10)'
                           + ', @c_OrigMessageID   NVARCHAR(10)'
                           + ', @c_PalletID        NVARCHAR(18)'
                           + ', @c_FromLoc         NVARCHAR(10)'
                           + ', @c_ToLoc           NVARCHAR(10)'
                           + ', @c_Priority        NVARCHAR(1) '
                           + ', @c_RespStatus      NVARCHAR(10)'
                           + ', @c_RespReasonCode  NVARCHAR(10)'
                           + ', @c_RespErrMsg      NVARCHAR(100)'
                           + ', @c_UD1             NVARCHAR(20)'
                           + ', @c_UD2             NVARCHAR(20)'
                           + ', @c_UD3   NVARCHAR(20)'
                           + ', @c_UD4             NVARCHAR(20)'
                           + ', @c_UD5             NVARCHAR(20)'
                           + ', @c_Param1          NVARCHAR(20)'
                           + ', @c_Param2          NVARCHAR(20)'
                           + ', @c_Param3          NVARCHAR(20)'
                           + ', @c_Param4          NVARCHAR(20)'
                           + ', @c_Param5          NVARCHAR(20)'
                           + ', @c_Param6          NVARCHAR(20)'
                           + ', @c_Param7          NVARCHAR(20)'
                           + ', @c_Param8          NVARCHAR(20)'
                           + ', @c_Param9          NVARCHAR(20)'
                           + ', @c_Param10         NVARCHAR(20)'
                           + ', @c_CallerGroup     NVARCHAR(30)'
                           + ', @b_debug           INT         '
                           + ', @b_Success         INT            OUTPUT'
                           + ', @n_Err             INT            OUTPUT'
                           + ', @c_ErrMsg          NVARCHAR(250)  OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                        , @c_ExecArguments
                        , @c_MessageName
                        , @c_MessageType
                        , @c_TaskDetailKey
                        , @n_SerialNo
                        , @c_WCSMessageID
                        , @c_OrigMessageID
                        , @c_PalletID
                        , @c_FromLoc
                        , @c_ToLoc
                        , @c_Priority
                        , @c_RespStatus
                        , @c_RespReasonCode
                        , @c_RespErrMsg
                        , @c_UD1
                        , @c_UD2
                        , @c_UD3
                        , @c_UD4
                        , @c_UD5
                        , @c_Param1
                        , @c_Param2
                        , @c_Param3
                        , @c_Param4
                        , @c_Param5
                        , @c_Param6
                        , @c_Param7
                        , @c_Param8
                        , @c_Param9
                        , @c_Param10
                        , @c_CallerGroup
                        , @b_debug 
                        , @b_Success    OUTPUT
                        , @n_Err        OUTPUT
                        , @c_ErrMsg     OUTPUT

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         --SET @n_Err = 68006
         --SET @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_err,0))  + '^ErrExeTcpClnt' 
         --              + ': Fail while executing ' + @c_SProcName + ' (isp_TCP_WCS_MsgProcess) ( ' 
         --              + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         GOTO QUIT        
      END 
   END

   QUIT:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      --SET @n_IsRDT = 0 --(TK03) - Force 0 while waiting for sys.master registration

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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_TCP_WCS_MsgProcess'
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