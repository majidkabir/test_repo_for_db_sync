SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SO_RULES_100013_10              */
/* Creation Date: 28-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform EcomPresale checking                               */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = 'ECPRESALE' ListName in Codelkup                */
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
/* 28-Dec-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SO_RULES_100013_10] (
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

   --DECLARE @c_Packkey   NVARCHAR(10)
   --      , @c_StorerKey NVARCHAR(15)
   --      , @c_SKU       NVARCHAR(20)
   --      , @c_AltSKU    NVARCHAR(20)
   --      , @c_ttlMsg    NVARCHAR(250);

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

   --IF EXISTS (
   --SELECT 1
   --FROM dbo.SCE_DL_SO_STG WITH (NOLOCK)
   --WHERE STG_BatchNo                = @n_BatchNo
   --AND   STG_Status                   = '1'
   --AND   (
   --       ECOM_PRESALE_FLAG IS NULL
   --    OR ISNULL(RTRIM(ECOM_PRESALE_FLAG), '') = ''
   --)
   --)
   --BEGIN
   --   BEGIN TRANSACTION;

   --   UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
   --   SET STG_Status = '5'
   --     , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/ECOM_PRESALE_FLAG is null'
   --   WHERE STG_BatchNo               = @n_BatchNo
   --   AND   STG_Status                  = '1'
   --   AND   (
   --          ECOM_PRESALE_FLAG IS NULL
   --       OR ISNULL(RTRIM(ECOM_PRESALE_FLAG), '') = ''
   --   );


   --   IF @@ERROR <> 0
   --   BEGIN
   --      SET @n_Continue = 3;
   --      SET @n_ErrNo = 68001;
   --      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
   --                      + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100013_10)';
   --      ROLLBACK;
   --      GOTO STEP_999_EXIT_SP;
   --   END;

   --   COMMIT;
   --END;

   IF @c_InParm1 <> ''
   BEGIN
      IF EXISTS (
      SELECT 1
      FROM dbo.SCE_DL_SO_STG STG WITH (NOLOCK)
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      AND (STG.ECOM_PRESALE_FLAG IS NOT NULL AND STG.ECOM_PRESALE_FLAG <> '')
      AND   NOT EXISTS (
      SELECT 1
      FROM dbo.V_CODELKUP CLKUP WITH (NOLOCK)
      WHERE CLKUP.LISTNAME = @c_InParm1
      AND   CLKUP.Code       = STG.ECOM_PRESALE_FLAG
      )
      )
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_SO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/EcomPreSaleFlag: ' + ECOM_PRESALE_FLAG
                          + N' not setup in codelkup '
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   NOT EXISTS (
         SELECT 1
         FROM dbo.V_CODELKUP CLKUP WITH (NOLOCK)
         WHERE CLKUP.LISTNAME = @c_InParm1
         AND   CLKUP.Code       = ECOM_PRESALE_FLAG
         );


         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SO_RULES_100013_10)';
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SO_RULES_100013_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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