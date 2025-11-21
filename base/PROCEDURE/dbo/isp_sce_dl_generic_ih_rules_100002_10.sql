SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_IH_RULES_100002_10              */
/* Creation Date: 17-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform SKU checking                                       */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform SKU checking between SKU Table            */
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
/* 17-Mar-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_IH_RULES_100002_10] (
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

   DECLARE @n_RowRefNo         INT
         , @c_InventoryHoldKey NVARCHAR(10);

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
      FROM dbo.INVENTORYHOLD_STG STG WITH (NOLOCK)
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      AND   (
             STG.SKU IS NULL
          OR STG.SKU    = ''
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'SKU cannot be Empty or NULL'
         FROM dbo.INVENTORYHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status    = '1'
         AND   (
                STG.SKU IS NULL
             OR STG.SKU    = ''
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_IH_RULES_100002_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;
      END;

      IF EXISTS (
      SELECT 1
      FROM dbo.INVENTORYHOLD_STG STG WITH (NOLOCK)
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      AND   NOT EXISTS (
      SELECT 1
      FROM dbo.V_SKU S WITH (NOLOCK)
      WHERE S.Sku     = STG.SKU
      AND   S.StorerKey = STG.Storerkey
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE STG WITH (ROWLOCK)
         SET STG.STG_Status = '3'
           , STG.STG_ErrMsg = 'Invalid SKU(' + STG.SKU + '). SKU not found from SKU table.'
         FROM dbo.INVENTORYHOLD_STG STG
         WHERE STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status    = '1'
         AND   NOT EXISTS (
         SELECT 1
         FROM dbo.V_SKU S WITH (NOLOCK)
         WHERE S.Sku     = STG.Sku
         AND   S.StorerKey = STG.StorerKey
         );

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_IH_RULES_100002_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;

         END;

         COMMIT;
      END;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_IH_RULES_100002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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