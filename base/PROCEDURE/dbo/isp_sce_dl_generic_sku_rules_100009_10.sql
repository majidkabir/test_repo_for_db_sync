SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKU_RULES_100009_10             */
/* Creation Date: 04-Oct-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19371 - Perform SKU Validation                          */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 04-Oct-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKU_RULES_100009_10] (
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

   DECLARE @c_StorerKey       NVARCHAR(15)
         , @c_SKU             NVARCHAR(20)
         , @c_ttlMsg          NVARCHAR(250)
         , @c_Lottable01Label NVARCHAR(50)
         , @c_Lottable04Label NVARCHAR(50)
         , @c_BUSR6           NVARCHAR(50)
         , @c_BUSR10          NVARCHAR(50)
         , @c_IVAS            NVARCHAR(50)

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

   DECLARE C_CHK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(StorerKey)
        , TRIM(SKU)
        , ISNULL(TRIM(Lottable01Label),'')
        , ISNULL(TRIM(Lottable04Label),'')
        , ISNULL(TRIM(BUSR6),'')
        , ISNULL(TRIM(BUSR10),'')
        , ISNULL(TRIM(IVAS),'')
   FROM dbo.SCE_DL_SKU_STG WITH (NOLOCK)
   WHERE STG_BatchNo    = @n_BatchNo
   AND   STG_Status     = '1'
   AND   ISNULL(TRIM(SKU),'') <> ''
   GROUP BY TRIM(StorerKey)
          , TRIM(SKU)
          , ISNULL(TRIM(Lottable01Label),'')
          , ISNULL(TRIM(Lottable04Label),'')
          , ISNULL(TRIM(BUSR6),'')
          , ISNULL(TRIM(BUSR10),'')
          , ISNULL(TRIM(IVAS),'')

   OPEN C_CHK

   FETCH NEXT FROM C_CHK
   INTO @c_StorerKey
      , @c_SKU
      , @c_Lottable01Label
      , @c_Lottable04Label
      , @c_BUSR6          
      , @c_BUSR10         
      , @c_IVAS           

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF @c_InParm1 = '1'
      BEGIN
         IF ISNULL(@c_BUSR10, '') = ''
         BEGIN
            IF ISNULL(@c_IVAS, '') = '' OR @c_IVAS <> 'N'
            BEGIN
               SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                              + N'/BUSR10 blank and IVAS cannot be blank or must be N for SKU '
                              + @c_SKU
            END
            ELSE
            BEGIN
               IF UPPER(@c_BUSR6) IN ('L', 'S')
               BEGIN
                  IF ISNULL(@c_Lottable01Label, '') = ''
                  BEGIN
                     SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                                    + N'/BUSR10 blank and IVAS equal to N for busr6 in L and S the lottable01label needed for SKU '
                                    + @c_SKU
                  END
               END 
            END
         END
         ELSE IF @c_BUSR10 IN ('Rework', 'Recharge') 
         BEGIN 
            IF ISNULL(@c_IVAS, '') = 'Y'
            BEGIN
               IF(ISNULL(@c_Lottable01Label, '') = '' OR ISNULL(@c_Lottable04Label, '') = '')
                 OR UPPER(ISNULL(@c_BUSR6, '')) NOT IN ('L', 'S')
               BEGIN
                  SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                                 + N'/BUSR10 in Rework or Recharge lottable label needed and busr6 must in L or S for SKU '
                                 + @c_SKU
               END
            END
            ELSE IF ISNULL(@c_IVAS, '') = '' OR @c_IVAS = 'N'
            BEGIN
               SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                              + N'/BUSR10 in Rework or Recharge SKU IVAS must be Y for SKU '
                              + @c_SKU
            END            
         END
         
         IF @c_BUSR10 NOT IN ('Rework', 'Recharge')
         BEGIN
            SET @c_ttlMsg = TRIM(ISNULL(@c_ttlMsg, ''))
                           + N'/BUSR10 must in Rework or Recharge for SKU '
                           + @c_SKU
         END
      END

      IF @c_ttlMsg <> ''
      BEGIN
         BEGIN TRANSACTION

         UPDATE dbo.SCE_DL_SKU_STG WITH (ROWLOCK)
         SET STG_Status = '3'
           , STG_ErrMsg = @c_ttlMsg
         WHERE STG_BatchNo       = @n_BatchNo
         AND   STG_Status        = '1'
         AND   TRIM(StorerKey)   = @c_StorerKey
         AND   TRIM(SKU)         = @c_SKU
         AND   ISNULL(TRIM(Lottable01Label),'') = @c_Lottable01Label
         AND   ISNULL(TRIM(Lottable04Label),'') = @c_Lottable04Label
         AND   ISNULL(TRIM(BUSR6),'')           = @c_BUSR6          
         AND   ISNULL(TRIM(BUSR10),'')          = @c_BUSR10         
         AND   ISNULL(TRIM(IVAS),'')            = @c_IVAS           


         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 68001
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
                            + ': Update record fail. (isp_SCE_DL_GENERIC_SKU_RULES_100009_10)'
            ROLLBACK
            GOTO STEP_999_EXIT_SP
         END

         COMMIT
      END

      FETCH NEXT FROM C_CHK
      INTO @c_StorerKey
         , @c_SKU
         , @c_Lottable01Label
         , @c_Lottable04Label
         , @c_BUSR6          
         , @c_BUSR10         
         , @c_IVAS           
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKU_RULES_100009_10] EXIT... ErrMsg : ' + ISNULL(TRIM(@c_ErrMsg), '')
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