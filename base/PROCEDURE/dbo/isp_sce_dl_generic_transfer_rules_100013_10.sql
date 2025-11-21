SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TRANSFER_RULES_100013_10        */
/* Creation Date: 11-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Lottable Checking                                  */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*                                                                      */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-Apr-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TRANSFER_RULES_100013_10] (
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

   DECLARE @c_ToStorerKey     NVARCHAR(15)
         , @c_ToSku           NVARCHAR(20)
         , @c_TOLOTTABLE01    NVARCHAR(18)
         , @c_TOLOTTABLE02    NVARCHAR(18)
         , @c_TOLOTTABLE03    NVARCHAR(18)
         , @dt_TOLOTTABLE04   DATETIME
         , @dt_TOLOTTABLE05   DATETIME
         , @c_TOLOTTABLE06    NVARCHAR(30)
         , @c_TOLOTTABLE07    NVARCHAR(30)
         , @c_TOLOTTABLE08    NVARCHAR(30)
         , @c_TOLOTTABLE09    NVARCHAR(30)
         , @c_TOLOTTABLE10    NVARCHAR(30)
         , @c_TOLOTTABLE11    NVARCHAR(30)
         , @c_TOLOTTABLE12    NVARCHAR(30)
         , @c_LOTTABLE01LABEL NVARCHAR(20)
         , @c_LOTTABLE02LABEL NVARCHAR(20)
         , @c_LOTTABLE03LABEL NVARCHAR(20)
         , @c_LOTTABLE04LABEL NVARCHAR(20)
         , @c_LOTTABLE05LABEL NVARCHAR(20)
         , @c_LOTTABLE06LABEL NVARCHAR(20)
         , @c_LOTTABLE07LABEL NVARCHAR(20)
         , @c_LOTTABLE08LABEL NVARCHAR(20)
         , @c_LOTTABLE09LABEL NVARCHAR(20)
         , @c_LOTTABLE10LABEL NVARCHAR(20)
         , @c_LOTTABLE11LABEL NVARCHAR(20)
         , @c_LOTTABLE12LABEL NVARCHAR(20)
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

   IF  @c_InParm1 = '1'
   BEGIN

      DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(STG.ToSku), '')
           , ISNULL(RTRIM(STG.ToStorerKey), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE01), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE02), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE03), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE04), '1999-09-09')
           , ISNULL(RTRIM(STG.TOLOTTABLE05), '1999-09-09')
           , ISNULL(RTRIM(STG.TOLOTTABLE06), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE07), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE08), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE09), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE10), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE11), '')
           , ISNULL(RTRIM(STG.TOLOTTABLE12), '')
           , ISNULL(RTRIM(sku.LOTTABLE01LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE02LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE03LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE04LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE05LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE06LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE07LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE08LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE09LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE10LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE11LABEL), '')
           , ISNULL(RTRIM(sku.LOTTABLE12LABEL), '')
      FROM dbo.SCE_DL_TRANSFER_STG STG WITH (NOLOCK)
      INNER JOIN dbo.SKU           sku WITH (NOLOCK)
      ON (
          STG.ToSku           = sku.Sku
      AND STG.ToStorerKey = sku.StorerKey
      )
      WHERE STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status    = '1'
      GROUP BY ISNULL(RTRIM(STG.ToSku), '')
             , ISNULL(RTRIM(STG.ToStorerKey), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE01), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE02), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE03), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE04), '1999-09-09')
             , ISNULL(RTRIM(STG.TOLOTTABLE05), '1999-09-09')
             , ISNULL(RTRIM(STG.TOLOTTABLE06), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE07), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE08), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE09), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE10), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE11), '')
             , ISNULL(RTRIM(STG.TOLOTTABLE12), '')
             , ISNULL(RTRIM(sku.LOTTABLE01LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE02LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE03LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE04LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE05LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE06LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE07LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE08LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE09LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE10LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE11LABEL), '')
             , ISNULL(RTRIM(sku.LOTTABLE12LABEL), '');

      OPEN C_CHK_CONF;
      FETCH NEXT FROM C_CHK_CONF
      INTO @c_ToSku
         , @c_ToStorerKey
         , @c_TOLOTTABLE01
         , @c_TOLOTTABLE02
         , @c_TOLOTTABLE03
         , @dt_TOLOTTABLE04
         , @dt_TOLOTTABLE05
         , @c_TOLOTTABLE06
         , @c_TOLOTTABLE07
         , @c_TOLOTTABLE08
         , @c_TOLOTTABLE09
         , @c_TOLOTTABLE10
         , @c_TOLOTTABLE11
         , @c_TOLOTTABLE12
         , @c_LOTTABLE01LABEL
         , @c_LOTTABLE02LABEL
         , @c_LOTTABLE03LABEL
         , @c_LOTTABLE04LABEL
         , @c_LOTTABLE05LABEL
         , @c_LOTTABLE06LABEL
         , @c_LOTTABLE07LABEL
         , @c_LOTTABLE08LABEL
         , @c_LOTTABLE09LABEL
         , @c_LOTTABLE10LABEL
         , @c_LOTTABLE11LABEL
         , @c_LOTTABLE12LABEL;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_ttlMsg = N'';

         IF  @c_TOLOTTABLE01 = ''
         AND @c_LOTTABLE01LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable01 is Null';
         END;

         IF  @c_TOLOTTABLE02 = ''
         AND @c_LOTTABLE02LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable02 is Null';
         END;

         IF  @c_TOLOTTABLE03 = ''
         AND @c_LOTTABLE03LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable03 is Null';
         END;

         IF  @dt_TOLOTTABLE04 = '1999-09-09'
         AND @c_LOTTABLE04LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable04 is Null';
         END;

         IF  @dt_TOLOTTABLE05 = '1999-09-09'
         AND @c_LOTTABLE05LABEL = 'RCP_DATE'
         BEGIN
            
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_TRANSFER_STG WITH (ROWLOCK)
            SET TOLOTTABLE05 = GETDATE()
            WHERE STG_BatchNo                             = @n_BatchNo
            AND   STG_Status                                = '1'
            AND   ISNULL(RTRIM(ToSku), '')                  = @c_ToSku
            AND   ISNULL(RTRIM(ToStorerKey), '')            = @c_ToStorerKey
            AND   ISNULL(RTRIM(TOLOTTABLE01), '')           = @c_TOLOTTABLE01
            AND   ISNULL(RTRIM(TOLOTTABLE02), '')           = @c_TOLOTTABLE02
            AND   ISNULL(RTRIM(TOLOTTABLE03), '')           = @c_TOLOTTABLE03
            AND   ISNULL(RTRIM(TOLOTTABLE04), '1999-09-09') = @dt_TOLOTTABLE04
            AND   ISNULL(RTRIM(TOLOTTABLE05), '1999-09-09') = @dt_TOLOTTABLE05
            AND   ISNULL(RTRIM(TOLOTTABLE06), '')           = @c_TOLOTTABLE06
            AND   ISNULL(RTRIM(TOLOTTABLE07), '')           = @c_TOLOTTABLE07
            AND   ISNULL(RTRIM(TOLOTTABLE08), '')           = @c_TOLOTTABLE08
            AND   ISNULL(RTRIM(TOLOTTABLE09), '')           = @c_TOLOTTABLE09
            AND   ISNULL(RTRIM(TOLOTTABLE10), '')           = @c_TOLOTTABLE10
            AND   ISNULL(RTRIM(TOLOTTABLE11), '')           = @c_TOLOTTABLE11
            AND   ISNULL(RTRIM(TOLOTTABLE12), '')           = @c_TOLOTTABLE12;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            COMMIT;

         END;

         IF  @c_TOLOTTABLE06 = ''
         AND @c_LOTTABLE06LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable06 is Null';
         END;

         IF  @c_TOLOTTABLE07 = ''
         AND @c_LOTTABLE07LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable07 is Null';
         END;

         IF  @c_TOLOTTABLE08 = ''
         AND @c_LOTTABLE08LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable08 is Null';
         END;

         IF  @c_TOLOTTABLE09 = ''
         AND @c_LOTTABLE09LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable09 is Null';
         END;

         IF  @c_TOLOTTABLE10 = ''
         AND @c_LOTTABLE10LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable10 is Null';
         END;

         IF  @c_TOLOTTABLE11 = ''
         AND @c_LOTTABLE11LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable11 is Null';
         END;

         IF  @c_TOLOTTABLE12 = ''
         AND @c_LOTTABLE12LABEL <> ''
         BEGIN
            SET @c_ttlMsg = LTRIM(RTRIM(ISNULL(@c_ttlMsg, ''))) + N'/Lottable12 is Null';
         END;

         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.SCE_DL_TRANSFER_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo                = @n_BatchNo
            AND   STG_Status                   = '1'
            AND   ISNULL(RTRIM(ToSku), '')                  = @c_ToSku
            AND   ISNULL(RTRIM(ToStorerKey), '')            = @c_ToStorerKey
            AND   ISNULL(RTRIM(TOLOTTABLE01), '')           = @c_TOLOTTABLE01
            AND   ISNULL(RTRIM(TOLOTTABLE02), '')           = @c_TOLOTTABLE02
            AND   ISNULL(RTRIM(TOLOTTABLE03), '')           = @c_TOLOTTABLE03
            AND   ISNULL(RTRIM(TOLOTTABLE04), '1999-09-09') = @dt_TOLOTTABLE04
            AND   ISNULL(RTRIM(TOLOTTABLE05), '1999-09-09') = @dt_TOLOTTABLE05
            AND   ISNULL(RTRIM(TOLOTTABLE06), '')           = @c_TOLOTTABLE06
            AND   ISNULL(RTRIM(TOLOTTABLE07), '')           = @c_TOLOTTABLE07
            AND   ISNULL(RTRIM(TOLOTTABLE08), '')           = @c_TOLOTTABLE08
            AND   ISNULL(RTRIM(TOLOTTABLE09), '')           = @c_TOLOTTABLE09
            AND   ISNULL(RTRIM(TOLOTTABLE10), '')           = @c_TOLOTTABLE10
            AND   ISNULL(RTRIM(TOLOTTABLE11), '')           = @c_TOLOTTABLE11
            AND   ISNULL(RTRIM(TOLOTTABLE12), '')           = @c_TOLOTTABLE12;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 68001;
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_TRANSFER_RULES_100013_10)';
               ROLLBACK;
               GOTO STEP_999_EXIT_SP;
            END;

            COMMIT;

         END;

         FETCH NEXT FROM C_CHK_CONF
         INTO @c_ToSku
            , @c_ToStorerKey
            , @c_TOLOTTABLE01
            , @c_TOLOTTABLE02
            , @c_TOLOTTABLE03
            , @dt_TOLOTTABLE04
            , @dt_TOLOTTABLE05
            , @c_TOLOTTABLE06
            , @c_TOLOTTABLE07
            , @c_TOLOTTABLE08
            , @c_TOLOTTABLE09
            , @c_TOLOTTABLE10
            , @c_TOLOTTABLE11
            , @c_TOLOTTABLE12
            , @c_LOTTABLE01LABEL
            , @c_LOTTABLE02LABEL
            , @c_LOTTABLE03LABEL
            , @c_LOTTABLE04LABEL
            , @c_LOTTABLE05LABEL
            , @c_LOTTABLE06LABEL
            , @c_LOTTABLE07LABEL
            , @c_LOTTABLE08LABEL
            , @c_LOTTABLE09LABEL
            , @c_LOTTABLE10LABEL
            , @c_LOTTABLE11LABEL
            , @c_LOTTABLE12LABEL;
      END;

      CLOSE C_CHK_CONF;
      DEALLOCATE C_CHK_CONF;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TRANSFER_RULES_100013_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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