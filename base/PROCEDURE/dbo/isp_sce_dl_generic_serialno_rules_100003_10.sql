SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SERIALNO_RULES_100003_10        */
/* Creation Date: 03-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23260 - Perform SKU Checking                            */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' SKU Null Checking                           */
/* Usage:  @c_InParm2 = '1' SKU Exist Checking                          */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 03-Aug-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SERIALNO_RULES_100003_10] (
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

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_SERIALNO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   (
             SKU IS NULL
          OR TRIM(SKU) = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_SERIALNO_STG WITH (ROWLOCK)
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
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SERIALNO_RULES_100003_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
   END

   IF @c_InParm2 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TRIM(StorerKey)
                    , ISNULL(TRIM(Sku), '')
      FROM dbo.SCE_DL_SERIALNO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'

      OPEN C_CHK

      FETCH NEXT FROM C_CHK
      INTO @c_Storerkey
         , @c_SKU

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N''

         IF NOT EXISTS (
            SELECT 1
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey
            AND SKU = @c_SKU
         )
         BEGIN
            SET @c_ttlMsg += N'/SKU (' + @c_SKU + N')  not exists in SKU table.'
         END

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION

            UPDATE dbo.SCE_DL_SERIALNO_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo = @n_BatchNo
            AND   STG_Status  = '1'
            AND   TRIM(StorerKey) = @c_Storerkey
            AND   ISNULL(TRIM(Sku), '') = @c_SKU

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 68001
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_SERIALNO_RULES_100003_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         FETCH NEXT FROM C_CHK
         INTO @c_Storerkey
            , @c_SKU
      END
      CLOSE C_CHK
      DEALLOCATE C_CHK
   END

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SERIALNO_RULES_100003_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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
SET ANSI_NULLS ON

GO