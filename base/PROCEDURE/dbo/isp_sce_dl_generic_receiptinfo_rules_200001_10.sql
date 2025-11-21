SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_RECEIPTINFO_RULES_200001_10     */
/* Creation Date: 26-Oct-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21021 - Perform Insert/Update on ReceiptInfo            */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '0' - Reject Update                             */
/*         @c_InParm1 = '1' - Allow Update                              */
/*         @c_InParm1 = '2' - Ignore & Insert New                       */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 26-Oct-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_RECEIPTINFO_RULES_200001_10] (
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

   DECLARE @c_StorerKey             NVARCHAR(15)
         , @c_ttlMsg                NVARCHAR(250)
         , @c_Receiptkey            NVARCHAR(10)
         , @n_RowRefNo              BIGINT
         , @c_GetReceiptkey         NVARCHAR(10)

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

   --Validation--
   DECLARE C_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(STG.Receiptkey),'')
                 , RowRefNo
   FROM dbo.RECEIPTINFO_STG STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'
   
   OPEN C_UPD
   
   FETCH NEXT FROM C_UPD
   INTO @c_Receiptkey 
      , @n_RowRefNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      SET @c_Storerkey = N''
      SET @c_GetReceiptkey = N''

      SELECT @c_Storerkey        = R.Storerkey
           , @c_GetReceiptkey    = R.Receiptkey
      FROM RECEIPT R (NOLOCK)
      WHERE R.Receiptkey = @c_Receiptkey
      
      IF ISNULL(@c_GetReceiptkey, '') = ''
      BEGIN
         SET @c_ttlMsg += N'/Receiptkey is Null'
      END

      IF ISNULL(@c_Storerkey, '') = ''
      BEGIN
         SET @c_ttlMsg += N'/Storerkey is Null'
      END

      IF NOT EXISTS (SELECT 1
                     FROM dbo.STORER S (NOLOCK)
                     WHERE S.StorerKey = @c_StorerKey
                     AND S.[type] = '1')
      BEGIN
         SET @c_ttlMsg += N'/Storerkey not exists'
      END

      IF EXISTS (SELECT 1
                 FROM RECEIPTINFO RI (NOLOCK)
                 WHERE RI.Receiptkey = @c_Receiptkey) AND @c_InParm1 IN ('0','1')
      BEGIN
         IF @c_InParm1 = '0'
         BEGIN
            SET @c_ttlMsg += N'/Receiptkey is already exists!'
         END
         ELSE
         BEGIN
            BEGIN TRANSACTION

            UPDATE RECEIPTINFO WITH (ROWLOCK)
            SET EcomReceiveId = ISNULL(STG.EcomReceiveId, RI.EcomReceiveId)
              , EcomOrderId   = ISNULL(STG.EcomOrderId, RI.EcomOrderId)
              , ReceiptAmount = ISNULL(STG.ReceiptAmount, RI.ReceiptAmount)
              , Notes         = ISNULL(STG.Notes, RI.Notes)
              , Notes2        = ISNULL(STG.Notes2, RI.Notes2)
              , StoreName     = ISNULL(STG.StoreName, RI.StoreName)
              , EditWho       = SUSER_SNAME()
              , EditDate      = GETDATE()
            FROM RECEIPTINFO_STG STG WITH (NOLOCK)
            JOIN RECEIPTINFO RI ON RI.Receiptkey = STG.Receiptkey
            WHERE STG.Receiptkey = @c_Receiptkey
            AND   STG.STG_BatchNo = @n_BatchNo
            AND   STG.STG_Status  = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
   
            WHILE @@TRANCOUNT > 0
               COMMIT TRANSACTION
            END
      END   --No need include Insert statement here, generic SP will insert
      --ELSE
      --BEGIN
      --   BEGIN TRANSACTION

      --   INSERT INTO RECEIPTINFO (
      --      ReceiptKey
      --    , EcomReceiveId
      --    , EcomOrderId
      --    , ReceiptAmount
      --    , Notes
      --    , Notes2
      --    , StoreName
      --   )
      --   SELECT ReceiptKey
      --        , EcomReceiveId
      --        , EcomOrderId
      --        , ReceiptAmount
      --        , Notes
      --        , Notes2
      --        , StoreName
      --   FROM RECEIPTINFO_STG STG (NOLOCK)
      --   WHERE STG.Receiptkey = @c_Receiptkey
      --   AND   STG.STG_BatchNo = @n_BatchNo
      --   AND   STG.STG_Status  = '1'

      --   IF @@ERROR <> 0
      --   BEGIN
      --      SET @n_Continue = 3
      --      ROLLBACK TRAN
      --      GOTO QUIT
      --   END   
      --   WHILE @@TRANCOUNT > 0
      --      COMMIT TRANSACTION
      --END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION
   
         UPDATE dbo.RECEIPTINFO_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   RowRefNo    = @n_RowRefNo
   
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_RECEIPTINFO_RULES_200001_10)'
            ROLLBACK TRANSACTION
            GOTO STEP_999_EXIT_SP
         END
   
         WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION
      END

      IF @c_InParm1 IN ('1')
      BEGIN
         UPDATE dbo.RECEIPTINFO_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo
      
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END
      END

      FETCH NEXT FROM C_UPD
      INTO @c_Receiptkey       
         , @n_RowRefNo
   END
   CLOSE C_UPD
   DEALLOCATE C_UPD

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_UPD') IN (0 , 1)
   BEGIN
      CLOSE C_UPD
      DEALLOCATE C_UPD   
   END
   
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_RECEIPTINFO_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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