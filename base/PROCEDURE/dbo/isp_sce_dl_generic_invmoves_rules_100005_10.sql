SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_INVMOVES_RULES_100005_10        */
/* Creation Date: 05-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20470 - Perform Lot Checking                            */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Perform Lot Null Checking                   */
/*         @c_InParm2 = '1' Perform Lot Exist Checking                  */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_INVMOVES_RULES_100005_10] (
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

   DECLARE @c_Lot         NVARCHAR(10)
         , @c_StorerKey   NVARCHAR(15)
         , @c_Sku         NVARCHAR(20)
         , @c_Lottable01  NVARCHAR(18)
         , @c_Lottable02  NVARCHAR(18)
         , @c_Lottable03  NVARCHAR(18)
         , @dt_Lottable04 DATETIME
         , @dt_Lottable05 DATETIME
         , @c_ttlMsg      NVARCHAR(250)

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
      FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   (Lot IS NULL OR RTRIM(Lot) = '')
      )
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_INVMOVES_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = LTRIM(RTRIM(ISNULL(STG_ErrMsg, ''))) + '/Lot is Null'
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status  = '1'
         AND   (Lot IS NULL OR RTRIM(Lot) = '')

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 63777
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_INVMOVES_RULES_100005_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END
         COMMIT
      END
   END

   IF @c_InParm2 = '1'
   BEGIN
      DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RTRIM(Lot)
                    , RTRIM(StorerKey)
                    , RTRIM(Sku)
                    , ISNULL(RTRIM(Lottable01), '')
                    , ISNULL(RTRIM(Lottable02), '')
                    , ISNULL(RTRIM(Lottable03), '')
                    , Lottable04
                    , Lottable05
      FROM dbo.SCE_DL_INVMOVES_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   Lot IS NOT NULL
      AND   Lot         <> ''

      OPEN C_CHK

      FETCH NEXT FROM C_CHK
      INTO @c_Lot
         , @c_StorerKey
         , @c_Sku
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @dt_Lottable04
         , @dt_Lottable05

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SET @c_ttlMsg = N''

         IF EXISTS (
         SELECT 1
         FROM dbo.V_LOT WITH (NOLOCK)
         WHERE Lot       = @c_Lot
         AND   StorerKey <> @c_StorerKey
         AND   Sku       <> @c_Sku
         )
         BEGIN
            SET @c_ttlMsg += N'/Storerkey : ' + @c_StorerKey + N' OR SKU : ' + @c_Sku
                             + N' difference in Lot table for Lot No :  ' + @c_Lot
         END

         IF  NOT EXISTS (
         SELECT 1
         FROM dbo.V_LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey   = @c_StorerKey
         AND   Sku         = @c_Sku
         AND   Lot         = @c_Lot
         )
         AND (
              @c_Lottable01 = ''
          AND @c_Lottable02 = ''
          AND @c_Lottable03 = ''
          AND @dt_Lottable04 IS NULL
          AND @dt_Lottable05 IS NULL
         )
         BEGIN
            SET @c_ttlMsg += N'/Lot(' + @c_Lot + N') not exists in LOTxLOCxID table.'
         END


         IF @c_ttlMsg <> ''
         BEGIN
            BEGIN TRANSACTION

            UPDATE dbo.SCE_DL_INVMOVES_STG WITH (ROWLOCK)
            SET STG_Status = '3'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo                 = @n_BatchNo
            AND   STG_Status                    = '1'
            AND   RTRIM(Lot)                    = @c_Lot
            AND   RTRIM(StorerKey)              = @c_StorerKey
            AND   RTRIM(Sku)                    = @c_Sku
            AND   ISNULL(RTRIM(Lottable01), '') = @c_Lottable01
            AND   ISNULL(RTRIM(Lottable02), '') = @c_Lottable02
            AND   ISNULL(RTRIM(Lottable03), '') = @c_Lottable03
            AND   Lottable04                    = @dt_Lottable04
            AND   Lottable05                    = @dt_Lottable05

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_ErrNo = 63778
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                               + ': Update record fail. (isp_SCE_DL_GENERIC_INVMOVES_RULES_100005_10)'
               ROLLBACK TRANSACTION
               GOTO STEP_999_EXIT_SP
            END

            COMMIT TRANSACTION
         END

         FETCH NEXT FROM C_CHK
         INTO @c_Lot
            , @c_StorerKey
            , @c_Sku
            , @c_Lottable01
            , @c_Lottable02
            , @c_Lottable03
            , @dt_Lottable04
            , @dt_Lottable05
      END
      CLOSE C_CHK
      DEALLOCATE C_CHK
   END
   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_INVMOVES_RULES_100005_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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