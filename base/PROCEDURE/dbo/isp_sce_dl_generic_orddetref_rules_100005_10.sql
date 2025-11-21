SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ORDDETREF_RULES_100005_10       */
/* Creation Date: 12-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform OrderDetailRef Checking                            */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Check existing Type 1                       */
/* Usage:  @c_InParm1 = '2' Check existing Type 2                       */
/* Usage:  @c_InParm2 = '1' Check duplicate Type 1                      */
/* Usage:  @c_InParm2 = '2' Check duplicate Type 2                      */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Apr-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ORDDETREF_RULES_100005_10] (
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

   DECLARE @c_StorerKey       NVARCHAR(15)
         , @c_OrderKey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_ParentSKU       NVARCHAR(20)
         , @c_Note1           NVARCHAR(1000)
         , @n_BOMQty          INT
         , @c_RefType         NVARCHAR(10)
         , @n_ttlCount        INT
         , @c_ttlMsg          NVARCHAR(250);

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


   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RTRIM(StorerKey)
                 , RTRIM(OrderKey)
                 , RTRIM(OrderLineNumber)
                 , RTRIM(ParentSku)
                 , RTRIM(Note1)
                 , BOMQty
                 , RTRIM(RefType)
   FROM dbo.SCE_DL_ORDDETREF_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1';

   OPEN C_CHK;

   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_OrderKey
      , @c_OrderLineNumber
      , @c_ParentSKU
      , @c_Note1
      , @n_BOMQty
      , @c_RefType;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';

      IF @c_InParm1 = '1'
      BEGIN
         IF NOT EXISTS (
         SELECT 1
         FROM dbo.V_OrderDetailRef WITH (NOLOCK)
         WHERE Orderkey      = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   StorerKey       = @c_StorerKey
         AND   ParentSKU       = @c_ParentSKU
         )
         BEGIN
            SET @c_ttlMsg += N'/OrderDetailRef exists for storerkey ' + RTRIM(@c_StorerKey) + N' and ParentSKU '
                             + RTRIM(@c_ParentSKU) + N' and Orderkey ' + @c_OrderKey + N' Insert Not allow ';
         END;
      END;
      ELSE IF @c_InParm1 = '2'
      BEGIN
         IF NOT EXISTS (
         SELECT 1
         FROM dbo.V_OrderDetailRef WITH (NOLOCK)
         WHERE Orderkey      = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   StorerKey       = @c_StorerKey
         )
         BEGIN
            SET @c_ttlMsg += N'/OrderDetailRef exists for storerkey ' + RTRIM(@c_StorerKey) + N' and Orderkey ' + @c_OrderKey
                             + N' Insert Not allow ';
         END;
      END;
      SET @n_ttlCount = 1;
      IF @c_InParm2 = '1'
      BEGIN
         SELECT @n_ttlCount = COUNT(1)
         FROM dbo.SCE_DL_ORDDETREF_STG WITH (NOLOCK)
         WHERE STG_BatchNo          = @n_BatchNo
         AND   STG_Status             = '1'
         AND   RTRIM(StorerKey)       = @c_StorerKey
         AND   RTRIM(OrderKey)        = @c_OrderKey
         AND   RTRIM(OrderLineNumber) = @c_OrderLineNumber
         AND   RTRIM(ParentSku)       = @c_ParentSKU
         AND   RTRIM(Note1)           = @c_Note1;

         IF @n_ttlCount > 1
         BEGIN
            SET @c_ttlMsg += N'/Orderkey: ' + RTRIM(@c_OrderKey) + N',OrderlineNumber:' + @c_OrderLineNumber + N',Parentsku :'
                             + @c_ParentSKU + N',Note1 : ' + @c_Note1 + N' is duplicate';
         END;
      END;
      ELSE IF @c_InParm2 = '2'
      BEGIN
         SELECT @n_ttlCount = COUNT(1)
         FROM dbo.SCE_DL_ORDDETREF_STG WITH (NOLOCK)
         WHERE STG_BatchNo          = @n_BatchNo
         AND   STG_Status             = '1'
         AND   RTRIM(StorerKey)       = @c_StorerKey
         AND   RTRIM(OrderKey)        = @c_OrderKey
         AND   RTRIM(OrderLineNumber) = @c_OrderLineNumber
         AND   RTRIM(ParentSku)       = @c_ParentSKU
         AND   RTRIM(Note1)           = @c_Note1
         AND   BOMQty                 = @n_BOMQty
         AND   RTRIM(RefType)         = @c_RefType;

         IF @n_ttlCount > 1
         BEGIN
            SET @c_ttlMsg += N'/Orderkey: ' + RTRIM(@c_OrderKey) + N',OrderlineNumber:' + @c_OrderLineNumber + N',Parentsku :'
                             + @c_ParentSKU + N',Note1 : ' + @c_Note1 + N',BOMQty :' + CAST(@n_BOMQty AS NVARCHAR(10))
                             + N',reftype:' + @c_RefType + N' is duplicate';
         END;
      END;


      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_ORDDETREF_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo          = @n_BatchNo
         AND   STG_Status             = '1'
         AND   RTRIM(StorerKey)       = @c_StorerKey
         AND   RTRIM(OrderKey)        = @c_OrderKey
         AND   RTRIM(OrderLineNumber) = @c_OrderLineNumber
         AND   RTRIM(ParentSku)       = @c_ParentSKU
         AND   RTRIM(Note1)           = @c_Note1
         AND   BOMQty                 = @n_BOMQty
         AND   RTRIM(RefType)         = @c_RefType;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68002;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ORDDETREF_RULES_100002_10)';
            ROLLBACK TRANSACTION;
            GOTO STEP_999_EXIT_SP;
         END;

         COMMIT TRANSACTION;
      END;

      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_OrderKey
         , @c_OrderLineNumber
         , @c_ParentSKU
         , @c_Note1
         , @n_BOMQty
         , @c_RefType;
   END;
   CLOSE C_CHK;
   DEALLOCATE C_CHK;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ORDDETREF_RULES_100005_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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