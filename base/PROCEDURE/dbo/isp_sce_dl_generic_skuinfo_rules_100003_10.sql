SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKUINFO_RULES_100003_10         */
/* Creation Date: 06-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21909 - Perform Update/Insert Checking                  */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 =  '0'  Reject Update                             */
/*         @c_InParm1 =  '1'  Allow Update                              */
/*         @c_InParm2 =  '0'  Reject Insert New                         */
/*         @c_InParm2 =  '1'  Allow Insert New                          */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 06-Mar-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKUINFO_RULES_100003_10]
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

   DECLARE @c_StorerKey NVARCHAR(15)
         , @c_ttlMsg    NVARCHAR(250)
         , @c_Sku       NVARCHAR(20)
         , @n_IsExists  INT = 0

   DECLARE @c_ExtendedField01 NVARCHAR(30)
         , @c_ExtendedField02 NVARCHAR(30)
         , @c_ExtendedField03 NVARCHAR(30)
         , @c_ExtendedField04 NVARCHAR(30)
         , @c_ExtendedField05 NVARCHAR(30)
         , @c_ExtendedField06 NVARCHAR(30)
         , @c_ExtendedField07 NVARCHAR(30)
         , @c_ExtendedField08 NVARCHAR(30)
         , @c_ExtendedField09 NVARCHAR(30)
         , @c_ExtendedField10 NVARCHAR(30)
         , @c_ExtendedField11 NVARCHAR(30)
         , @c_ExtendedField12 NVARCHAR(30)
         , @c_ExtendedField13 NVARCHAR(30)
         , @c_ExtendedField14 NVARCHAR(30)
         , @c_ExtendedField15 NVARCHAR(30)
         , @c_ExtendedField16 NVARCHAR(30)
         , @c_ExtendedField17 NVARCHAR(30)
         , @c_ExtendedField18 NVARCHAR(30)
         , @c_ExtendedField19 NVARCHAR(30)
         , @c_ExtendedField20 NVARCHAR(30)
         , @c_ExtendedField21 NVARCHAR(4000)
         , @c_ExtendedField22 NVARCHAR(4000)

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

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ISNULL(TRIM(StorerKey), '')
                 , ISNULL(TRIM(SKU), '')
                 , ISNULL(TRIM(ExtendedField01), '')
                 , ISNULL(TRIM(ExtendedField02), '')
                 , ISNULL(TRIM(ExtendedField03), '')
                 , ISNULL(TRIM(ExtendedField04), '')
                 , ISNULL(TRIM(ExtendedField05), '')
                 , ISNULL(TRIM(ExtendedField06), '')
                 , ISNULL(TRIM(ExtendedField07), '')
                 , ISNULL(TRIM(ExtendedField08), '')
                 , ISNULL(TRIM(ExtendedField09), '')
                 , ISNULL(TRIM(ExtendedField10), '')
                 , ISNULL(TRIM(ExtendedField11), '')
                 , ISNULL(TRIM(ExtendedField12), '')
                 , ISNULL(TRIM(ExtendedField13), '')
                 , ISNULL(TRIM(ExtendedField14), '')
                 , ISNULL(TRIM(ExtendedField15), '')
                 , ISNULL(TRIM(ExtendedField16), '')
                 , ISNULL(TRIM(ExtendedField17), '')
                 , ISNULL(TRIM(ExtendedField18), '')
                 , ISNULL(TRIM(ExtendedField19), '')
                 , ISNULL(TRIM(ExtendedField20), '')
                 , ISNULL(TRIM(ExtendedField21), '')
                 , ISNULL(TRIM(ExtendedField22), '')
   FROM dbo.SCE_DL_SKUINFO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1'

   OPEN C_CHK

   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_Sku
      , @c_ExtendedField01
      , @c_ExtendedField02
      , @c_ExtendedField03
      , @c_ExtendedField04
      , @c_ExtendedField05
      , @c_ExtendedField06
      , @c_ExtendedField07
      , @c_ExtendedField08
      , @c_ExtendedField09
      , @c_ExtendedField10
      , @c_ExtendedField11
      , @c_ExtendedField12
      , @c_ExtendedField13
      , @c_ExtendedField14
      , @c_ExtendedField15
      , @c_ExtendedField16
      , @c_ExtendedField17
      , @c_ExtendedField18
      , @c_ExtendedField19
      , @c_ExtendedField20
      , @c_ExtendedField21
      , @c_ExtendedField22

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''
      SET @n_IsExists = 0

      IF EXISTS (  SELECT 1
                   FROM SkuInfo (NOLOCK)
                   WHERE Storerkey = @c_StorerKey AND Sku = @c_Sku)
      BEGIN
         SET @n_IsExists = 1
      END
      ELSE
      BEGIN
         SET @n_IsExists = 0
      END

      IF @c_InParm1 = '0' AND @n_IsExists = 1 --Reject Update
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/SKUINFO with Storer ' + TRIM(@c_StorerKey) + N' and SKU '
                         + TRIM(@c_Sku) + N' already exists, update rejected.'
      END

      IF @c_InParm2 = '0' AND @n_IsExists = 0 --Reject Insert
      BEGIN
         SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, '')) + N'/Not allow to insert new SKUINFO with Storer '
                         + TRIM(@c_StorerKey) + N' and SKU ' + TRIM(@c_Sku)
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_SKUINFO_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1' AND StorerKey = @c_StorerKey AND SKU = @c_Sku

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SKUINFO_RULES_100003_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END

         COMMIT
      END

      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_Sku
         , @c_ExtendedField01
         , @c_ExtendedField02
         , @c_ExtendedField03
         , @c_ExtendedField04
         , @c_ExtendedField05
         , @c_ExtendedField06
         , @c_ExtendedField07
         , @c_ExtendedField08
         , @c_ExtendedField09
         , @c_ExtendedField10
         , @c_ExtendedField11
         , @c_ExtendedField12
         , @c_ExtendedField13
         , @c_ExtendedField14
         , @c_ExtendedField15
         , @c_ExtendedField16
         , @c_ExtendedField17
         , @c_ExtendedField18
         , @c_ExtendedField19
         , @c_ExtendedField20
         , @c_ExtendedField21
         , @c_ExtendedField22
   END
   CLOSE C_CHK
   DEALLOCATE C_CHK

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_CHK') IN (0 , 1)
   BEGIN
      CLOSE C_CHK
      DEALLOCATE C_CHK   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKUINFO_RULES_100003_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '')
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