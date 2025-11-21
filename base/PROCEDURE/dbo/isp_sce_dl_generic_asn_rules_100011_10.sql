SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_RULES_100011_10             */
/* Creation Date: 04-Feb-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Lottable Checking                                  */
/*                                                                      */
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
/* 04-Feb-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_RULES_100011_10] (
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

   DECLARE @c_StorerKey     NVARCHAR(15)
         , @c_SKU           NVARCHAR(20)
         , @c_Lottable01    NVARCHAR(18)
         , @c_Lottable02    NVARCHAR(18)
         , @c_Lottable03    NVARCHAR(18)
         , @c_Lottable04    DATETIME
         , @c_LottableLBL01 NVARCHAR(20)
         , @c_LottableLBL02 NVARCHAR(20)
         , @c_LottableLBL03 NVARCHAR(20)
         , @c_LottableLBL04 NVARCHAR(20)
         , @c_ttlMsg        NVARCHAR(250);

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
   SELECT STG.SKU
        , STG.Storerkey
        , ISNULL(RTRIM(sku.LOTTABLE01LABEL), '')
        , ISNULL(RTRIM(sku.LOTTABLE02LABEL), '')
        , ISNULL(RTRIM(sku.LOTTABLE03LABEL), '')
        , ISNULL(RTRIM(sku.LOTTABLE04LABEL), '')
        , ISNULL(RTRIM(STG.Lottable01), '')
        , ISNULL(RTRIM(STG.Lottable02), '')
        , ISNULL(RTRIM(STG.Lottable03), '')
        , ISNULL(STG.Lottable04, '1999-09-09')
   FROM dbo.SCE_DL_ASN_STG STG WITH (NOLOCK)
   JOIN dbo.V_SKU          sku WITH (NOLOCK)
   ON (
       STG.SKU           = sku.Sku
   AND STG.Storerkey = sku.StorerKey
   )
   WHERE STG.STG_BatchNo = @n_BatchNo
   AND   STG.STG_Status    = '1'
   GROUP BY ISNULL(RTRIM(sku.LOTTABLE01LABEL), '')
          , ISNULL(RTRIM(sku.LOTTABLE02LABEL), '')
          , ISNULL(RTRIM(sku.LOTTABLE03LABEL), '')
          , ISNULL(RTRIM(sku.LOTTABLE04LABEL), '')
          , ISNULL(RTRIM(STG.Lottable01), '')
          , ISNULL(RTRIM(STG.Lottable02), '')
          , ISNULL(RTRIM(STG.Lottable03), '')
          , ISNULL(STG.Lottable04, '1999-09-09')
          , STG.SKU
          , STG.Storerkey;

   OPEN C_CHK;

   FETCH NEXT FROM C_CHK
   INTO @c_SKU
      , @c_StorerKey
      , @c_LottableLBL01
      , @c_LottableLBL02
      , @c_LottableLBL03
      , @c_LottableLBL04
      , @c_Lottable01
      , @c_Lottable02
      , @c_Lottable03
      , @c_Lottable04;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N'';

      IF  @c_Lottable01 = ''
      AND @c_LottableLBL01 <> ''
      BEGIN
         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable01 is Null';
      END;

      IF  @c_Lottable02 = ''
      AND @c_LottableLBL02 <> ''
      BEGIN
         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable02 is Null';
      END;

      IF  @c_Lottable03 = ''
      AND @c_LottableLBL03 <> ''
      BEGIN
         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable03 is Null';
      END;

      IF  @c_Lottable04 = '1999-09-09'
      AND @c_LottableLBL04 <> ''
      BEGIN
         SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable04 is Null';
      END;

      NEXTITEM:
      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION;

         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + @c_ttlMsg
         WHERE ISNULL(RTRIM(Lottable01), '')  = @c_Lottable01
         AND   ISNULL(RTRIM(Lottable02), '')    = @c_Lottable02
         AND   ISNULL(RTRIM(Lottable03), '')    = @c_Lottable03
         AND   ISNULL(Lottable04, '1999-09-09') = @c_Lottable04
         AND   Storerkey                        = @c_StorerKey
         AND   SKU                              = @c_SKU;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 68001;
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_ASN_RULES_100011_10)';
            ROLLBACK;
            GOTO STEP_999_EXIT_SP;
         END;

         COMMIT;
      END;

      FETCH NEXT FROM C_CHK
      INTO @c_SKU
         , @c_StorerKey
         , @c_LottableLBL01
         , @c_LottableLBL02
         , @c_LottableLBL03
         , @c_LottableLBL04
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @c_Lottable04;
   END;

   CLOSE C_CHK;
   DEALLOCATE C_CHK;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_RULES_100011_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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