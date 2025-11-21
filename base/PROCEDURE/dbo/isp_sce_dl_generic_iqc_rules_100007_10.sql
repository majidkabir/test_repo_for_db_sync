SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_IQC_RULES_100007_10             */
/* Creation Date: 25-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform PackKey Checking                                   */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Perform NULL PackKey Checking               */
/*         @c_InParm2 = '1' Perform Exist PackKey Checking              */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 25-May-2022  GHChan    1.1   Initial                                 */
/* 27-Feb-2023  WLChooi   1.1   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_IQC_RULES_100007_10] (
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

   DECLARE @c_PackKey   NVARCHAR(10)
         , @c_StorerKey NVARCHAR(15)
         , @c_Sku       NVARCHAR(20)
         , @c_ttlMsg    NVARCHAR(250);

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

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
      WHERE STG_BatchNo   = @n_BatchNo
      AND   STG_Status      = '1'
      AND   (
             PackKey IS NULL
          OR TRIM(PackKey) = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_IQC_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(TRIM(ISNULL(STG_ErrMsg, ''))) + '/PackKey is Null'
         WHERE STG_BatchNo   = @n_BatchNo
         AND   STG_Status      = '1'
         AND   (
                PackKey IS NULL
             OR TRIM(PackKey) = ''
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_IQC_RULES_100007_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;
         COMMIT;
      END;
   END;

   IF @c_InParm2 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(TRIM(PackKey), '')
                    , ISNULL(TRIM(StorerKey), '')
                    , ISNULL(TRIM(Sku), '')
      FROM dbo.SCE_DL_IQC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_CHK;

      FETCH NEXT FROM C_CHK
      INTO @c_PackKey
         , @c_StorerKey
         , @c_Sku;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SET @c_ttlMsg = N'';

         IF ISNULL(@c_PackKey,'') <> ''
         BEGIN

            IF NOT EXISTS (
            SELECT 1
            FROM dbo.V_PACK WITH (NOLOCK)
            WHERE PackKey = @c_PackKey
            )
            BEGIN
               SET @c_ttlMsg += N'/Packkey(' + @c_PackKey + N') not exists in Pack';
            END;

            IF NOT EXISTS (
            SELECT 1
            FROM dbo.V_SKU WITH (NOLOCK)
            WHERE PACKKey = @c_PackKey
            AND   StorerKey = @c_StorerKey
            AND   Sku       = @c_Sku
            )
            BEGIN
               SET @c_ttlMsg += N'/Packkey(' + @c_PackKey + N') not exists in SKU ';
            END;
         END;
         ELSE
         BEGIN
            BEGIN TRANSACTION;

            UPDATE STG WITH (ROWLOCK)
            SET STG.PackKey = S.PACKKey
            FROM dbo.SCE_DL_IQC_STG STG
            INNER JOIN dbo.V_SKU    S WITH (NOLOCK)
            ON  S.StorerKey = STG.StorerKey
            AND S.Sku      = STG.Sku
            WHERE STG.STG_BatchNo                = @n_BatchNo
            AND   STG.STG_Status                   = '1'
            AND   ISNULL(TRIM(STG.PackKey), '')   = @c_PackKey
            AND   ISNULL(TRIM(STG.StorerKey), '') = @c_StorerKey
            AND   ISNULL(TRIM(STG.Sku), '')       = @c_Sku;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68002;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_IQC_RULES_100007_10)';
               ROLLBACK TRANSACTION;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT TRANSACTION;
         END;

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_IQC_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo                = @n_BatchNo
            AND   STG_Status                   = '1'
            AND   ISNULL(TRIM(PackKey), '')   = @c_PackKey
            AND   ISNULL(TRIM(StorerKey), '') = @c_StorerKey
            AND   ISNULL(TRIM(Sku), '')       = @c_Sku;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68002;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_IQC_RULES_100007_10)';
               ROLLBACK TRANSACTION;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT TRANSACTION;
         END;

         FETCH NEXT FROM C_CHK
         INTO @c_PackKey
            , @c_StorerKey
            , @c_Sku;

      END;
      CLOSE C_CHK;
      DEALLOCATE C_CHK;
   END;

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN ( 0, 1 )
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_IQC_RULES_100007_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '');
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