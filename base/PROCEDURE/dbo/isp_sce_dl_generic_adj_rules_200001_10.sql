SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ADJ_RULES_200001_10             */
/* Creation Date: 09-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert into Adjustment target table     	        */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ADJ_RULES_200001_10] (
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

   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Facility       NVARCHAR(5)
         , @c_AdjustmentType NVARCHAR(5)
         , @c_CustomerRefNo  NVARCHAR(10)
         , @n_RowRefNo       INT
         , @c_AdjustmentKey  NVARCHAR(10)
         , @n_GetQty         INT
         , @c_UOM            NVARCHAR(10)
         , @c_Packkey        NVARCHAR(10)
         , @c_Sku            NVARCHAR(20)
         , @n_Qty            INT
         , @n_iNo            INT
         , @c_ttlMsg         NVARCHAR(250);

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

      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RTRIM(StorerKey)
                    , ISNULL(RTRIM(CustomerRefNo), '')
                    , ISNULL(RTRIM(AdjustmentType), '')
                    , ISNULL(RTRIM(Facility), '')
      FROM dbo.SCE_DL_ADJ_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @c_Storerkey
         , @c_CustomerRefNo
         , @c_AdjustmentType
         , @c_Facility;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT TOP (1) @n_RowRefNo = RowRefNo
         FROM dbo.SCE_DL_ADJ_STG WITH (NOLOCK)
         WHERE STG_BatchNo                     = @n_BatchNo
         AND   STG_Status                        = '1'
         AND   ISNULL(RTRIM(StorerKey), '')      = @c_Storerkey
         AND   ISNULL(RTRIM(CustomerRefNo), '')  = @c_CustomerRefNo
         AND   ISNULL(RTRIM(AdjustmentType), '') = @c_AdjustmentType
         AND   ISNULL(RTRIM(Facility), '')       = @c_Facility
         ORDER BY STG_SeqNo ASC;

         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'Adjustment'
                            , @fieldlength = 10
                            , @keystring = @c_AdjustmentKey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new Adjustment Key from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         INSERT INTO dbo.ADJUSTMENT
         (
            AdjustmentKey
          , StorerKey
          , CustomerRefNo
          , AdjustmentType
          , Facility
          , UserDefine01
          , UserDefine02
          , UserDefine03
          , UserDefine04
          , UserDefine05
          , UserDefine06
          , UserDefine07
          , UserDefine08
          , UserDefine09
          , UserDefine10
          , DocType
          , Remarks
          , FromToWhse
          , AddWho
          , EditWho
         )
         SELECT @c_AdjustmentKey
              , @c_Storerkey
              , @c_CustomerRefNo
              , @c_AdjustmentType
              , @c_Facility
              , ISNULL(STG.HUdef01, '')
              , ISNULL(STG.HUdef02, '')
              , ISNULL(STG.HUdef03, '')
              , ISNULL(STG.HUdef04, '')
              , ISNULL(STG.HUdef05, '')
              , STG.HUdef06
              , STG.HUdef07
              , ISNULL(STG.HUdef08, '')
              , ISNULL(STG.HUdef09, '')
              , ISNULL(STG.HUdef10, '')
              , ISNULL(STG.DocType, 'A')
              , ISNULL(STG.Remarks, '')
              , ISNULL(STG.FromToWhse, '')
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_ADJ_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         SET @n_iNo = 0;

         DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , ISNULL(RTRIM(CASE WHEN @c_InParm2 = '1' THEN UPPER(Sku)
                                  ELSE Sku
                             END
                       ), ''
                )
              , ISNULL(Qty, 0)
              , ISNULL(RTRIM(PackKey), '')
              , ISNULL(RTRIM(UOM), '')
         FROM dbo.SCE_DL_ADJ_STG WITH (NOLOCK)
         WHERE STG_BatchNo                     = @n_BatchNo
         AND   STG_Status                        = '1'
         AND   ISNULL(RTRIM(StorerKey), '')      = @c_Storerkey
         AND   ISNULL(RTRIM(CustomerRefNo), '')  = @c_CustomerRefNo
         AND   ISNULL(RTRIM(AdjustmentType), '') = @c_AdjustmentType
         AND   ISNULL(RTRIM(Facility), '')       = @c_Facility;

         OPEN C_DET;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_Sku
            , @n_Qty
            , @c_Packkey
            , @c_UOM;

         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @n_iNo += 1;

            SELECT @n_GetQty = CASE @c_UOM WHEN LTRIM(RTRIM(PackUOM1)) THEN CaseCnt * @n_Qty
                                           WHEN LTRIM(RTRIM(PackUOM2)) THEN InnerPack * @n_Qty
                                           WHEN LTRIM(RTRIM(PackUOM3)) THEN Qty * @n_Qty
                                           WHEN LTRIM(RTRIM(PackUOM4)) THEN Pallet * @n_Qty
                                           WHEN LTRIM(RTRIM(PackUOM8)) THEN OtherUnit1 * @n_Qty
                                           WHEN LTRIM(RTRIM(PackUOM9)) THEN OtherUnit2 * @n_Qty
                                           ELSE 0
                               END
            FROM dbo.V_PACK (NOLOCK)
            WHERE PackKey = @c_Packkey
            AND   (
                   PackUOM1      = @c_UOM
                OR PackUOM2 = @c_UOM
                OR PackUOM3 = @c_UOM
                OR PackUOM4 = @c_UOM
                OR PackUOM5 = @c_UOM
                OR PackUOM6 = @c_UOM
                OR PackUOM7 = @c_UOM
                OR PackUOM8 = @c_UOM
                OR PackUOM9 = @c_UOM
            );


            INSERT INTO dbo.ADJUSTMENTDETAIL
            (
               AdjustmentKey
             , AdjustmentLineNumber
             , StorerKey
             , Sku
             , Loc
             , Lot
             , Id
             , ReasonCode
             , UOM
             , PackKey
             , Qty
             , UserDefine01
             , UserDefine02
             , UserDefine03
             , UserDefine04
             , UserDefine05
             , UserDefine06
             , UserDefine07
             , UserDefine08
             , UserDefine09
             , UserDefine10
             , Lottable01
             , Lottable02
             , Lottable03
             , Lottable04
             , Lottable05
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
             , UCCNo
             , Channel
             , AddWho
             , EditWho
            )
            SELECT @c_AdjustmentKey
                 , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(5))
                 , @c_Storerkey
                 , @c_Sku
                 , ISNULL(Loc, '')
                 , ISNULL(Lot, '')
                 , ISNULL(Id, '')
                 , ReasonCode
                 , @c_UOM
                 , @c_Packkey
                 , @n_GetQty
                 , ISNULL(DUdef01, '')
                 , ISNULL(DUdef02, '')
                 , ISNULL(DUdef03, '')
                 , ISNULL(DUdef04, '')
                 , ISNULL(DUdef05, '')
                 , DUdef06
                 , DUdef07
                 , ISNULL(DUdef08, '')
                 , ISNULL(DUdef09, '')
                 , ISNULL(DUdef10, '')
                 , ISNULL(Lottable01, '')
                 , ISNULL(Lottable02, '')
                 , ISNULL(Lottable03, '')
                 , Lottable04
                 , Lottable05
                 , ISNULL(Lottable06, '')
                 , ISNULL(Lottable07, '')
                 , ISNULL(Lottable08, '')
                 , ISNULL(Lottable09, '')
                 , ISNULL(Lottable10, '')
                 , ISNULL(Lottable11, '')
                 , ISNULL(Lottable12, '')
                 , Lottable13
                 , Lottable14
                 , Lottable15
                 , ISNULL(UCCNo, '')
                 , ISNULL(Channel, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_ADJ_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            UPDATE dbo.SCE_DL_ADJ_STG WITH (ROWLOCK)
            SET STG_Status = '9'
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            FETCH NEXT FROM C_DET
            INTO @n_RowRefNo
               , @c_Sku
               , @n_Qty
               , @c_Packkey
               , @c_UOM;
         END;
         CLOSE C_DET;
         DEALLOCATE C_DET;

         FETCH NEXT FROM C_HDR
         INTO @c_Storerkey
            , @c_CustomerRefNo
            , @c_AdjustmentType
            , @c_Facility;
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ADJ_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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