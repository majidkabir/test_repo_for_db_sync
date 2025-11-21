SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10      */
/* Creation Date: 10-Dec-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24263 - Perform Column Checking                         */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' SKU Exist Checking                          */
/*         @c_InParm2 = '1' Lot Exist Checking                          */
/*         @c_InParm3 = '1' Loc Exist Checking                          */
/*         @c_InParm3 = 'F' FromLoc Exist Checking                      */
/*         @c_InParm3 = 'T' ToLoc Exist Checking                        */
/*         @c_InParm4 = '1' ID Exist Checking                           */
/*         @c_InParm4 = 'F' FromID Exist Checking                       */
/*         @c_InParm4 = 'T' ToID Exist Checking                         */
/*         @c_InParm5 = '1' Qty Checking                                */
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

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10] (
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

   DECLARE @c_Storerkey       NVARCHAR(15)
         , @c_SKU             NVARCHAR(20)
         , @c_ttlMsg          NVARCHAR(250)
         , @c_Lot             NVARCHAR(10)
         , @c_FromLoc         NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_FromID          NVARCHAR(50)
         , @c_ToID            NVARCHAR(50)
         , @n_Qty             INT
         , @n_LLIQty          INT
         , @c_LoseID          NVARCHAR(10) = ''
         , @n_RowRefNo        BIGINT = 0
         , @c_Pickmethod      NVARCHAR(10) = ''
         , @n_QtyAvailable    INT = 0

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

   DECLARE C_CHK_Qty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(FromLoc)
        , ISNULL(TRIM(FromID),'')
        , SUM(Qty)
        , Storerkey
   FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   GROUP BY TRIM(FromLoc)
          , ISNULL(TRIM(FromID),'')
          , Storerkey

   OPEN C_CHK_Qty

   FETCH NEXT FROM C_CHK_Qty
   INTO @c_FromLoc
      , @c_FromID
      , @n_Qty
      , @c_Storerkey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      SET @n_LLIQty = 0
      SET @c_Pickmethod = 'PP'

      SELECT @n_LLIQty = SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen)
      FROM LOTXLOCXID LLI (NOLOCK)
      WHERE LLI.Loc = @c_FromLoc
      AND LLI.ID = @c_FromID
      AND LLI.StorerKey = @c_Storerkey

      SET @n_QtyAvailable = @n_LLIQty - @n_Qty

      IF @n_QtyAvailable <= 0
      BEGIN
         SET @c_Pickmethod = 'FP'
      END
      ELSE
      BEGIN
         SET @c_Pickmethod = 'PP'
      END

      ;WITH CTE AS ( SELECT DISTINCT RowRefNo
                     FROM SCE_DL_TASKDETAIL_STG (NOLOCK)
                     WHERE FromLoc = @c_FromLoc
                     AND ISNULL(TRIM(FromID),'') = @c_FromID
                     AND Storerkey = @c_Storerkey)
      UPDATE STG WITH (ROWLOCK)
      SET Pickmethod = @c_Pickmethod
      FROM CTE
      JOIN SCE_DL_TASKDETAIL_STG STG ON STG.RowRefNo = CTE.RowRefNo
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      
      IF @n_Qty > @n_LLIQty AND @c_InParm5 = '1'
      BEGIN
         SET @c_ttlMsg += N'/Invalid Qty for FromLoc: ' + @c_FromLoc + N' and FromID: ' + @c_FromID + N'.'
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         ;WITH CTE AS ( SELECT DISTINCT RowRefNo
                        FROM SCE_DL_TASKDETAIL_STG (NOLOCK)
                        WHERE FromLoc = @c_FromLoc
                        AND FromID = @c_FromID
                        AND Storerkey = @c_Storerkey )
         UPDATE STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         FROM CTE
         JOIN SCE_DL_TASKDETAIL_STG STG ON STG.RowRefNo = CTE.RowRefNo
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68003
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END

         COMMIT TRANSACTION
      END

      FETCH NEXT FROM C_CHK_Qty
      INTO @c_FromLoc
         , @c_FromID
         , @n_Qty
         , @c_Storerkey
   END
   CLOSE C_CHK_Qty
   DEALLOCATE C_CHK_Qty

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   (
             SKU IS NULL
          OR TRIM(SKU) = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = TRIM(ISNULL(STG_ErrMsg, '')) + '/SKU is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   (
                SKU IS NULL
             OR TRIM(SKU) = ''
         )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT TRANSACTION
      END

      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TRIM(StorerKey)
                    , ISNULL(TRIM(Sku), '')
                    , RowRefNo
      FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'

      OPEN C_CHK

      FETCH NEXT FROM C_CHK
      INTO @c_Storerkey
         , @c_SKU
         , @n_RowRefNo

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N''

         IF @c_InParm2 = '1'
         BEGIN
            IF NOT EXISTS (
               SELECT 1
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @c_Storerkey
               AND SKU = @c_SKU
            )
            BEGIN
               SET @c_ttlMsg += N'/SKU (' + @c_SKU + N')  not exists in SKU table.'
            END
         END

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION

            UPDATE SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status = '1'
            AND   RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68001
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         FETCH NEXT FROM C_CHK
         INTO @c_Storerkey
            , @c_SKU
            , @n_RowRefNo
      END
      CLOSE C_CHK
      DEALLOCATE C_CHK
   END

   DECLARE C_CHK_LLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TRIM(Lot)
                 , TRIM(FromLoc)
                 , TRIM(ToLoc)
                 , ISNULL(TRIM(FromID), '')
                 , ISNULL(TRIM(ToID), '')
                 , RowRefNo
                 , PickMethod
   FROM dbo.SCE_DL_TASKDETAIL_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'

   OPEN C_CHK_LLI

   FETCH NEXT FROM C_CHK_LLI
   INTO @c_Lot
      , @c_FromLoc
      , @c_ToLoc
      , @c_FromID
      , @c_ToID
      , @n_RowRefNo
      , @c_Pickmethod

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF @c_InParm3 IN ('1', 'F', 'T')
      BEGIN
         IF @c_InParm3 IN ('1', 'F')
         BEGIN
            IF NOT EXISTS (
               SELECT 1
               FROM dbo.LOC WITH (NOLOCK)
               WHERE Loc = @c_FromLoc
            )
            BEGIN
               SET @c_ttlMsg += N'/Invalid FromLoc: ' + @c_FromLoc + N'.'
            END
         END

         IF @c_InParm3 IN ('1', 'T')
         BEGIN
            IF NOT EXISTS (
               SELECT 1
               FROM dbo.LOC WITH (NOLOCK)
               WHERE Loc = @c_ToLoc
            )
            BEGIN
               SET @c_ttlMsg += N'/Invalid ToLoc: ' + @c_ToLoc + N'.'
            END
         END
      END

      IF @c_InParm4 IN ('1', 'F', 'T')
      BEGIN
         IF @c_InParm4 IN ('1', 'F')
         BEGIN
            SET @c_LoseID = ''
            SELECT @c_LoseID = LoseID
            FROM LOC (NOLOCK)
            WHERE LOC = @c_FromLoc

            IF NOT EXISTS (
               SELECT 1
               FROM dbo.ID WITH (NOLOCK)
               WHERE ID = @c_FromID
            ) AND @c_LoseID = '0' AND @c_Pickmethod = 'FP'
            BEGIN
               SET @c_ttlMsg += N'/Invalid FromID: ' + @c_FromID + N'.'
            END
         END

         IF @c_InParm4 IN ('1', 'T')
         BEGIN
            SET @c_LoseID = ''
            SELECT @c_LoseID = LoseID
            FROM LOC (NOLOCK)
            WHERE LOC = @c_ToLoc

            IF NOT EXISTS (
               SELECT 1
               FROM dbo.ID WITH (NOLOCK)
               WHERE ID = @c_ToID
            ) AND @c_LoseID = '0' AND @c_Pickmethod = 'FP'
            BEGIN
               SET @c_ttlMsg += N'/Invalid ToID: ' + @c_ToID + N'.'
            END
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE SCE_DL_TASKDETAIL_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status = '1'
         AND   RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END

         COMMIT TRANSACTION
      END

      FETCH NEXT FROM C_CHK_LLI
      INTO @c_Lot
         , @c_FromLoc
         , @c_ToLoc
         , @c_FromID
         , @c_ToID
         , @n_RowRefNo
         , @c_Pickmethod
   END
   CLOSE C_CHK_LLI
   DEALLOCATE C_CHK_LLI

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF CURSOR_STATUS('LOCAL', 'C_CHK_LLI') IN (0 , 1)
   BEGIN
      CLOSE C_CHK_LLI
      DEALLOCATE C_CHK_LLI   
   END

   IF CURSOR_STATUS('LOCAL', 'C_CHK_Qty') IN (0 , 1)
   BEGIN
      CLOSE C_CHK_Qty
      DEALLOCATE C_CHK_Qty   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TASKDETAIL_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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