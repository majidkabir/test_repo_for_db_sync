SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure: isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10   */
/* Creation Date: 13-Sep-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23299 - Perform Storerkey/SKU/Channel_ID Checking       */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform StorerKey Checking                        */
/*   @c_InParm2 = '1' Perform SKU Checking                              */
/*   @c_InParm3 = '1' Perform Channel_ID Checking                       */
/*   @c_InParm4 = '1' Perform Duplicate Channel_ID Checking             */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13-Sep-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10]
(
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

   DECLARE @n_RowRefNo         INT

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (SPName NVARCHAR(300) '$.SubRuleSP'
          , InParm1 NVARCHAR(60) '$.InParm1'
          , InParm2 NVARCHAR(60) '$.InParm2'
          , InParm3 NVARCHAR(60) '$.InParm3'
          , InParm4 NVARCHAR(60) '$.InParm4'
          , InParm5 NVARCHAR(60) '$.InParm5')
   WHERE SPName = OBJECT_NAME(@@PROCID)

   IF @c_InParm1 = '1'
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo
                   AND   STG.STG_Status = '1'
                   AND   (STG.Storerkey IS NULL OR STG.Storerkey = ''))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Storer Key cannot be Empty or NULL'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo AND STG.STG_Status = '1' AND (STG.Storerkey IS NULL OR STG.Storerkey = '')

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END

      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo
                   AND   STG.STG_Status = '1'
                   AND   NOT EXISTS (  SELECT 1
                                       FROM dbo.V_STORER S WITH (NOLOCK)
                                       WHERE S.StorerKey = STG.StorerKey))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Invalid StorerKey(' + STG.Storerkey + '). StorerKey not found in Storer table.'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   NOT EXISTS (  SELECT 1
                             FROM dbo.V_STORER S WITH (NOLOCK)
                             WHERE S.StorerKey = STG.StorerKey)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68002
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END
   END

   IF @c_InParm2 = '1'
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo AND STG.STG_Status = '1' AND (STG.SKU IS NULL OR STG.SKU = ''))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'SKU cannot be Empty or NULL'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo AND STG.STG_Status = '1' AND (STG.SKU IS NULL OR STG.SKU = '')

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68003
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END

      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo
                   AND   STG.STG_Status = '1'
                   AND   NOT EXISTS (  SELECT 1
                                       FROM dbo.V_SKU S WITH (NOLOCK)
                                       WHERE S.Sku = STG.Sku AND S.StorerKey = STG.StorerKey))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Invalid SKU(' + STG.SKU + '). SKU not found from SKU table.'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   NOT EXISTS (  SELECT 1
                             FROM dbo.V_SKU S WITH (NOLOCK)
                             WHERE S.Sku = STG.Sku AND S.StorerKey = STG.StorerKey)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68004
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END
   END

   IF @c_InParm3 = '1'
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo
                   AND   STG.STG_Status = '1'
                   AND   (STG.Channel_ID IS NULL OR STG.Channel_ID = 0))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Channel_ID cannot be 0 or NULL'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo AND STG.STG_Status = '1' AND (STG.Channel_ID IS NULL OR STG.Channel_ID = 0)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68005
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END

      IF EXISTS (  SELECT 1
                   FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG WITH (NOLOCK)
                   WHERE STG.STG_BatchNo = @n_BatchNo
                   AND   STG.STG_Status = '1'
                   AND   NOT EXISTS (  SELECT 1
                                       FROM dbo.ChannelInv S WITH (NOLOCK)
                                       WHERE S.Channel_ID = STG.Channel_ID))
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Invalid Channel_ID (' + CAST(STG.Channel_ID AS NVARCHAR)
                              + '). Channel_ID not found from ChannelInv table.'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   NOT EXISTS (  SELECT 1
                             FROM dbo.ChannelInv S WITH (NOLOCK)
                             WHERE S.Channel_ID = STG.Channel_ID)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68006
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END
   END

   IF @c_InParm4 = '1'
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
                  WHERE STG.STG_BatchNo = @n_BatchNo
                  AND   STG.STG_Status = '1'
                  GROUP BY Channel_ID
                  HAVING COUNT(Channel_ID) > 1 )
      BEGIN
         BEGIN TRANSACTION

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Duplicated Channel_ID in same batch.'
         FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.Channel_ID IN ( SELECT Channel_ID
                                  FROM dbo.SCE_DL_CHANNELINVHOLD_STG STG
                                  WHERE STG.STG_BatchNo = @n_BatchNo
                                  AND   STG.STG_Status = '1'
                                  GROUP BY Channel_ID
                                  HAVING COUNT(Channel_ID) > 1 )

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68007
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP

         END

         COMMIT TRANSACTION
      END
   END

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CHANNELINVHOLD_RULES_100001_10] EXIT... ErrMsg : '
             + ISNULL(RTRIM(@c_ErrMsg), '')
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