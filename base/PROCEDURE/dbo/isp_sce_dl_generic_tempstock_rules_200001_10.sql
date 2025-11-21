SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TEMPSTOCK_RULES_200001_10       */
/* Creation Date: 09-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into TempStock target table     	         */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*         @c_InParm2 = '1' Convert SKU to Uppercase                    */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-May-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TEMPSTOCK_RULES_200001_10] (
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

   DECLARE @c_Storerkey  NVARCHAR(15)
         , @n_RowRefNo   INT
         , @c_GetDate    NVARCHAR(10)
         , @c_SourceType NVARCHAR(30)
         , @c_ttlMsg     NVARCHAR(250);

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
      SET @c_GetDate = REPLACE(CONVERT(NVARCHAR(10), GETDATE(), 103), '/', '');
      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , StorerKey
      FROM dbo.SCE_DL_TEMPSTOCK_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Storerkey;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_SourceType = N'ExcelLoader' + @c_GetDate + RIGHT('00000' + CAST(@n_RowRefNo AS VARCHAR(5)), 5);

         INSERT INTO dbo.TempStock
         (
            StorerKey
          , SKU
          , ID
          , Loc
          , Qty
          , Lottable01
          , Lottable02
          , Lottable03
          , Lottable04
          , Lottable05
          , Sourcekey
          , Sourcetype
          , Lottable06
          , Lottable07
          , Lottable08
          , Lottable09
          , Lottable10
          , Lottable11
          , Lottable12
          , Lottable13
          , Lottable14
          , Lottable15
         )
         SELECT STG.StorerKey
              , STG.SKU
              , STG.ID
              , STG.Loc
              , STG.Qty
              , ISNULL(STG.Lottable01, '')
              , ISNULL(STG.Lottable02, '')
              , ISNULL(STG.Lottable03, '')
              , ISNULL(STG.Lottable04, '')
              , ISNULL(STG.Lottable05, '')
              , STG.Sourcekey
              , @c_SourceType
              , ISNULL(STG.Lottable06, '')
              , ISNULL(STG.Lottable07, '')
              , ISNULL(STG.Lottable08, '')
              , ISNULL(STG.Lottable09, '')
              , ISNULL(STG.Lottable10, '')
              , ISNULL(STG.Lottable11, '')
              , ISNULL(STG.Lottable12, '')
              , STG.Lottable13
              , STG.Lottable14
              , STG.Lottable15
         FROM dbo.SCE_DL_TEMPSTOCK_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         EXECUTE dbo.isp_InsertStockByStorerkey @b_success = @b_Success OUTPUT
                                              , @c_StorerKey = @c_Storerkey;

         IF @@ERROR <> 0
         OR @b_Success <> 1
         BEGIN
            --SET @n_Continue= 3    
            SET @n_ErrNo = 63502;
            SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_ErrNo) + N': Failed to EXEC isp_InsertStockByStorerkey';
         --GOTO QUIT                          
         END;

         UPDATE dbo.SCE_DL_TEMPSTOCK_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         FETCH NEXT FROM C_HDR
         INTO @n_RowRefNo
            , @c_Storerkey;

      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TEMPSTOCK_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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