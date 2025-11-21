SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TASKDETAIL_RULES_200001_10      */
/* Creation Date: 10-Dec-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24263 - Perform insert into TASKDETAIL target table     */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Populate Loc to Logical Loc                 */
/*         @c_InParm2 = '1' Populate Areakey from Areadetail            */
/*         @c_InParm3 = '1' Enable Qty Replen                           */
/*         @c_InParm4 = '1' Enable PendingMoveIn Qty                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Dec-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TASKDETAIL_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_Taskdetailkey  NVARCHAR(10)
         , @c_FromLoc        NVARCHAR(10)
         , @c_Areakey        NVARCHAR(50)

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo     INT
         , @c_ttlMsg       NVARCHAR(250)
         , @c_Storerkey    NVARCHAR(15)

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID)

   BEGIN TRANSACTION

   DECLARE C_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo, FromLoc
   FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'

   OPEN C_INS
   FETCH NEXT FROM C_INS
   INTO @n_RowRefNo
      , @c_FromLoc

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      SET @c_Areakey = N''

      IF @c_InParm2 = '1'
      BEGIN
         SELECT @c_Areakey = ISNULL(AD.AreaKey, '')
         FROM AREADETAIL AD (NOLOCK)
         JOIN LOC L (NOLOCK) ON L.PutawayZone = AD.PutawayZone
         WHERE L.Loc = @c_FromLoc

         UPDATE SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
         SET Areakey = @c_Areakey
         WHERE RowRefNo = @n_RowRefNo
      END

      SELECT @b_Success = 0
      EXECUTE nspg_GetKey 'TASKDETAILKEY'
                        , 10
                        , @c_Taskdetailkey OUTPUT
                        , @b_Success OUTPUT
                        , @n_ErrNo OUTPUT
                        , @c_ErrMsg OUTPUT
      
      IF @b_Success = 1
      BEGIN
         INSERT INTO dbo.TaskDetail (TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM, UOMQty, Qty, FromLoc, LogicalFromLoc
                                   , FromID, ToLoc, LogicalToLoc, ToID, Caseid, PickMethod, Status, StatusMsg, Priority
                                   , SourcePriority, Holdkey, UserKey, UserPosition, UserKeyOverRide, StartTime, EndTime
                                   , SourceType, SourceKey, PickDetailKey, OrderKey, OrderLineNumber, ListKey, WaveKey
                                   , ReasonKey, Message01, Message02, Message03, AddDate, AddWho
                                   , SystemQty, RefTaskKey, LoadKey, AreaKey, DropID, TransitCount, TransitLOC
                                   , FinalLOC, FinalID, Groupkey, PendingMoveIn, QtyReplen, DeviceID)
         SELECT @c_Taskdetailkey
              , TaskType
              , Storerkey
              , Sku
              , Lot
              , ISNULL(UOM, '')
              , UOMQty
              , Qty
              , FromLoc
              , IIF(@c_InParm1 = '1', FromLoc, LogicalFromLoc)
              , ISNULL(TRIM(FromID), '')
              , ToLoc
              , IIF(@c_InParm1 = '1', ToLoc, LogicalToLoc)
              , ISNULL(TRIM(ToID), '')
              , ISNULL(Caseid, '')
              , PickMethod
              , ISNULL([Status], '0')
              , ISNULL(StatusMsg, '')
              , ISNULL([Priority], '9')
              , ISNULL(SourcePriority, '9')
              , ISNULL(Holdkey, '')
              , ISNULL(UserKey, '')
              , ISNULL(UserPosition, '1')
              , ISNULL(UserKeyOverRide, '')
              , ISNULL(StartTime, GETDATE())
              , ISNULL(EndTime, GETDATE())
              , 'SCE_DL_TASKDETAIL'
              , ISNULL(SourceKey, '')
              , ISNULL(PickDetailKey, '')
              , ISNULL(OrderKey, '')
              , ISNULL(OrderLineNumber, '')
              , ISNULL(ListKey, '')
              , ISNULL(WaveKey, '')
              , ISNULL(ReasonKey, '')
              , ISNULL(Message01, '')
              , ISNULL(Message02, '')
              , ISNULL(Message03, '')
              , GETDATE()
              , SUSER_SNAME()
              , ISNULL(SystemQty, 0)
              , ISNULL(RefTaskKey, '')
              , ISNULL(LoadKey, '')
              , ISNULL(AreaKey, '')
              , ISNULL(DropID, '')
              , ISNULL(TransitCount, 0)
              , ISNULL(TransitLOC, '')
              , ISNULL(FinalLOC, '')
              , ISNULL(FinalID, '')
              , ISNULL(Groupkey, '')
              , IIF(@c_InParm4 = '1', Qty, 0)
              , IIF(@c_InParm3 = '1', Qty, 0)
              , ISNULL(DeviceID, '')
         FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   RowRefNo = @n_RowRefNo
      END
      ELSE 
      BEGIN
         UPDATE dbo.SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = 'Error: NSQL' + CONVERT(CHAR(5), @n_ErrNo)
                        + ':Failed to generate Taskdetailkey ( ' + TRIM(@c_ErrMsg) + ' ) '
         WHERE RowRefNo = @n_RowRefNo
         AND STG_BatchNo = @n_BatchNo
         AND STG_Status  = '1'
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
         
         GOTO NEXT_ITEM
      END

      UPDATE dbo.SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXT_ITEM:

      FETCH NEXT FROM C_INS
      INTO @n_RowRefNo
         , @c_FromLoc
   END
   CLOSE C_INS
   DEALLOCATE C_INS

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_INS') IN (0 , 1)
   BEGIN
      CLOSE C_INS
      DEALLOCATE C_INS   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TASKDETAIL_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END
GO