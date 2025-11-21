SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_WORKORD_RULES_200001_10         */
/* Creation Date: 10-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into WorkOrder target table       */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore WorkOrder        */
/*                           @c_InParm1 =  '1'  Update is allow         */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2022  GHChan    1.1   Initial                                 */
/* 27-Feb-2023  WLChooi   1.1   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_WORKORD_RULES_200001_10] (
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
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_Storerkey          NVARCHAR(15)
         , @c_ExternWorkOrderKey NVARCHAR(20)
         , @c_WorkOrderKey       NVARCHAR(10)
         , @n_ActionFlag         INT
         , @c_Facility           NVARCHAR(5)
         , @c_AdjustmentType     NVARCHAR(5)
         , @n_RowRefNo           INT
         , @c_AdjustmentKey      NVARCHAR(10)
         , @n_GetQty             INT
         , @c_UOM                NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_Sku                NVARCHAR(20)
         , @n_Qty                INT
         , @n_iNo                INT
         , @c_ttlMsg             NVARCHAR(250);

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
   WHERE SPName = OBJECT_NAME(@@PROCID);

   BEGIN TRANSACTION;

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TRIM(StorerKey)
                 , TRIM(ExternWorkOrderKey)
   FROM dbo.SCE_DL_WORKORD_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @c_Storerkey
      , @c_ExternWorkOrderKey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_WorkOrderKey = ''
      
      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_WORKORD_STG WITH (NOLOCK)
      WHERE STG_BatchNo             = @n_BatchNo
      AND   STG_Status                = '1'
      AND   TRIM(StorerKey)          = @c_Storerkey
      AND   TRIM(ExternWorkOrderKey) = @c_ExternWorkOrderKey
      ORDER BY STG_SeqNo ASC;

      SELECT @c_WorkOrderKey = ISNULL(TRIM(WorkOrderKey), '')
      FROM dbo.V_WorkOrder WITH (NOLOCK)
      WHERE StorerKey        = @c_Storerkey
      AND   ExternWorkOrderKey = @c_ExternWorkOrderKey;

      IF @c_InParm1 = '1'
      BEGIN
         IF @c_WorkOrderKey <> ''
         BEGIN
            SET @n_ActionFlag = 1; -- UPDATE
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;
      ELSE IF @c_InParm1 = '0'
      BEGIN
         IF @c_WorkOrderKey <> ''
         BEGIN
            UPDATE dbo.SCE_DL_WORKORD_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:WorkOrder already exists'
            WHERE STG_BatchNo      = @n_BatchNo
            AND   STG_Status         = '1'
            AND   Storerkey          = @c_Storerkey
            AND   ExternWorkOrderKey = @c_ExternWorkOrderKey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
            GOTO NEXTITEM;
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;


      IF @n_ActionFlag = 1
      BEGIN
         UPDATE WORD WITH (ROWLOCK)
         SET WORD.ExternStatus = ISNULL(TRIM(STG.ExternStatus), '')
           , WORD.Type = ISNULL(TRIM(STG.Type), '')
           , WORD.Reason = ISNULL(TRIM(STG.Reason), '')
           , WORD.TotalPrice = ISNULL(TRIM(STG.TotalPrice), 0)
           , WORD.GenerateCharges = ISNULL(TRIM(STG.GenerateCharges), '')
           , WORD.Remarks = ISNULL(TRIM(STG.WHRemarks), '')
           , WORD.Notes1 = ISNULL(TRIM(STG.Notes1), '')
           , WORD.Notes2 = ISNULL(TRIM(STG.Notes2), '')
           , WORD.WkOrdUdef1 = ISNULL(TRIM(STG.WkOrdUdef1), '')
           , WORD.WkOrdUdef2 = ISNULL(TRIM(STG.WkOrdUdef2), '')
           , WORD.WkOrdUdef3 = ISNULL(TRIM(STG.WkOrdUdef3), '')
           , WORD.WkOrdUdef4 = ISNULL(TRIM(STG.WkOrdUdef4), '')
           , WORD.WkOrdUdef5 = ISNULL(TRIM(STG.WkOrdUdef5), '')
           , WORD.WkOrdUdef6 = ISNULL(STG.WkOrdUdef6, '')
           , WORD.WkOrdUdef7 = ISNULL(STG.WkOrdUdef7, '')
           , WORD.WkOrdUdef8 = ISNULL(TRIM(STG.WkOrdUdef8), '')
           , WORD.WkOrdUdef9 = ISNULL(TRIM(STG.WkOrdUdef9), '')
           , WORD.WkOrdUdef10 = ISNULL(TRIM(STG.WkOrdUdef10), '')
           , WORD.EditWho = @c_Username
           , WORD.EditDate = GETDATE()
         FROM dbo.SCE_DL_WORKORD_STG STG WITH (NOLOCK)
         JOIN dbo.WorkOrder          WORD
         ON (
             STG.ExternWorkOrderKey = WORD.ExternWorkOrderKey
         AND STG.StorerKey      = WORD.StorerKey
         )
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         DELETE FROM dbo.WorkOrderDetail
         WHERE WorkOrderKey = @c_WorkOrderKey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;
      ELSE IF @n_ActionFlag = 0
      BEGIN
         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'WorkOrder'
                            , @fieldlength = 10
                            , @keystring = @c_WorkOrderKey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new WorkOrderKey from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         INSERT INTO dbo.WorkOrder
         (
            WorkOrderKey
          , ExternWorkOrderKey
          , StorerKey
          , Facility
          , Status
          , ExternStatus
          , Type
          , Reason
          , TotalPrice
          , GenerateCharges
          , Remarks
          , Notes1
          , Notes2
          , WkOrdUdef1
          , WkOrdUdef2
          , WkOrdUdef3
          , WkOrdUdef4
          , WkOrdUdef5
          , WkOrdUdef6
          , WkOrdUdef7
          , WkOrdUdef8
          , WkOrdUdef9
          , WkOrdUdef10
         )
         SELECT @c_WorkOrderKey
              , @c_ExternWorkOrderKey
              , @c_Storerkey
              , ISNULL(TRIM(Facility), '')
              , ISNULL(TRIM(WHStatus), '')
              , ISNULL(TRIM(ExternStatus), '')
              , ISNULL(TRIM(Type), '')
              , ISNULL(TRIM(Reason), '')
              , ISNULL(TRIM(TotalPrice), 0)
              , ISNULL(TRIM(GenerateCharges), '')
              , ISNULL(TRIM(WHRemarks), '')
              , ISNULL(TRIM(Notes1), '')
              , ISNULL(TRIM(Notes2), '')
              , ISNULL(TRIM(WkOrdUdef1), '')
              , ISNULL(TRIM(WkOrdUdef2), '')
              , ISNULL(TRIM(WkOrdUdef3), '')
              , ISNULL(TRIM(WkOrdUdef4), '')
              , ISNULL(TRIM(WkOrdUdef5), '')
              , ISNULL(WkOrdUdef6, '')
              , ISNULL(WkOrdUdef7, '')
              , ISNULL(TRIM(WkOrdUdef8), '')
              , ISNULL(TRIM(WkOrdUdef9), '')
              , ISNULL(TRIM(WkOrdUdef10), '')
         FROM dbo.SCE_DL_WORKORD_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      SET @n_iNo = 0;

      DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
      FROM dbo.SCE_DL_WORKORD_STG WITH (NOLOCK)
      WHERE STG_BatchNo             = @n_BatchNo
      AND   STG_Status                = '1'
      AND   TRIM(StorerKey)          = @c_Storerkey
      AND   TRIM(ExternWorkOrderKey) = @c_ExternWorkOrderKey;

      OPEN C_DET;

      FETCH NEXT FROM C_DET
      INTO @n_RowRefNo;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_iNo += 1;

         INSERT INTO dbo.WorkOrderDetail
         (
            WorkOrderKey
          , ExternWorkOrderKey
          , WorkOrderLineNumber
          , ExternLineNo
          , Type
          , Reason
          , Unit
          , Qty
          , Price
          , LineValue
          , Remarks
          , WkOrdUdef1
          , WkOrdUdef2
          , WkOrdUdef3
          , WkOrdUdef4
          , WkOrdUdef5
          , WkOrdUdef6
          , WkOrdUdef7
          , WkOrdUdef8
          , WkOrdUdef9
          , WkOrdUdef10
          , SKU
          , Status
         )
         SELECT @c_WorkOrderKey
              , @c_ExternWorkOrderKey
              , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(10))
              , ISNULL(TRIM(ExternLineNo), '')
              , ISNULL(TRIM(WDType), '')
              , ISNULL(TRIM(WDReason), '')
              , ISNULL(TRIM(Unit), '')
              , ISNULL(TRIM(Qty), 0)
              , ISNULL(TRIM(Price), 0)
              , ISNULL(TRIM(LineValue), 0)
              , ISNULL(TRIM(WDRemarks), '')
              , ISNULL(TRIM(WDWkOrdUdef1), '')
              , ISNULL(TRIM(WDWkOrdUdef2), '')
              , ISNULL(TRIM(WDWkOrdUdef3), '')
              , ISNULL(TRIM(WDWkOrdUdef4), '')
              , ISNULL(TRIM(WDWkOrdUdef5), '')
              , ISNULL(WDWkOrdUdef6, '')
              , ISNULL(WDWkOrdUdef7, '')
              , ISNULL(TRIM(WDWkOrdUdef8), '')
              , ISNULL(TRIM(WDWkOrdUdef9), '')
              , ISNULL(TRIM(WDWkOrdUdef10), '')
              , ISNULL(TRIM(SKU), '')
              , ISNULL(TRIM(WDStatus), '')
         FROM dbo.SCE_DL_WORKORD_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         UPDATE dbo.SCE_DL_WORKORD_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo;
      END;
      CLOSE C_DET;
      DEALLOCATE C_DET;

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @c_Storerkey
         , @c_ExternWorkOrderKey;
   END;

   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR
   END

   IF CURSOR_STATUS('LOCAL', 'C_DET') IN ( 0, 1 )
   BEGIN
      CLOSE C_DET
      DEALLOCATE C_DET
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_WORKORD_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1;
   END;
   ELSE
   BEGIN
      SET @b_Success = 0;
   END;
END;

GO