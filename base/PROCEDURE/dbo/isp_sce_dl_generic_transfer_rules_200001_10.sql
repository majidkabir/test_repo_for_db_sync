SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_TRANSFER_RULES_200001_10        */
/* Creation Date: 11-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into Transfer target table        */
/*                                                                      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Active Flag                                 */
/*         @c_InParm2 = '1' Convert SKU to Uppercase                    */
/*         @c_InParm3 = '1' Update tolottable10 and Tolottable11        */
/*                          (1_update,0_Ignore)                         */
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

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_TRANSFER_RULES_200001_10] (
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

   DECLARE @c_FromStorerKey NVARCHAR(15)
         , @c_ToStorerKey   NVARCHAR(15)
         , @c_FromFacility  NVARCHAR(15)
         , @c_Type          NVARCHAR(12)
         , @c_ReasonCode    NVARCHAR(10)
         , @c_CustRefNo     NVARCHAR(20)
         , @n_RowRefNo      INT
         , @c_Transferkey   NVARCHAR(10)
         , @n_FromGetQty    INT
         , @n_ToGetQty      INT
         , @n_FromCaseCnt   FLOAT
         , @n_ToCaseCnt     FLOAT
         , @c_FromUOM       NVARCHAR(10)
         , @c_ToUOM         NVARCHAR(10)
         , @c_FromPackkey   NVARCHAR(10)
         , @c_ToPackkey     NVARCHAR(10)
         , @c_FromSku       NVARCHAR(20)
         , @c_ToSku         NVARCHAR(20)
         , @n_FromQty       INT
         , @n_ToQty         INT
         , @c_TOLOTTABLE10  NVARCHAR(30)
         , @c_TOLOTTABLE11  NVARCHAR(30)
         , @n_SUMQty        INT
         , @n_iNo           INT
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

   IF @c_InParm1 = '1'
   BEGIN

      BEGIN TRANSACTION;

      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ISNULL(RTRIM(FromStorerKey), '')
                    , ISNULL(RTRIM(ToStorerKey), '')
                    , ISNULL(RTRIM(Facility), '')
                    , ISNULL(RTRIM([Type]), '')
                    , ISNULL(RTRIM(ReasonCode), '')
                    , ISNULL(RTRIM(CustomerRefNo), '')
      FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1';

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @c_FromStorerKey
         , @c_ToStorerKey
         , @c_FromFacility
         , @c_Type
         , @c_ReasonCode
         , @c_CustRefNo;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         SELECT TOP (1) @n_RowRefNo = RowRefNo
         FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
         WHERE STG_BatchNo                    = @n_BatchNo
         AND   STG_Status                       = '1'
         AND   ISNULL(RTRIM(FromStorerKey), '') = @c_FromStorerKey
         AND   ISNULL(RTRIM(ToStorerKey), '')   = @c_ToStorerKey
         AND   ISNULL(RTRIM(Facility), '')      = @c_FromFacility
         AND   ISNULL(RTRIM([Type]), '')        = @c_Type
         AND   ISNULL(RTRIM(ReasonCode), '')    = @c_ReasonCode
         AND   ISNULL(RTRIM(CustomerRefNo), '') = @c_CustRefNo
         ORDER BY STG_SeqNo ASC;

         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'Transfer'
                            , @fieldlength = 10
                            , @keystring = @c_Transferkey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @c_ErrMsg = 'Unable to get a new PO Key from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         INSERT INTO dbo.[TRANSFER]
         (
            TransferKey
          , FromStorerKey
          , ToStorerKey
          , [Type]
          , [Status]
          , GenerateHOCharges
          , GenerateIS_HICharges
          , ReLot
          , ReasonCode
          , CustomerRefNo
          , Remarks
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
          , ToFacility
          , AddWho
          , EditWho
         )
         SELECT @c_Transferkey
              , @c_FromStorerKey
              , @c_ToStorerKey
              , @c_Type
              , '0'
              , ISNULL(RTRIM(GenerateHOCharges), '1')
              , ISNULL(RTRIM(GenerateIS_HICharges), '1')
              , ISNULL(RTRIM(ReLot), '0')
              , @c_ReasonCode
              , @c_CustRefNo
              , ISNULL(RTRIM(Remarks), '')
              , @c_FromFacility
              , ISNULL(RTRIM(UserDefine01), '')
              , ISNULL(RTRIM(UserDefine02), '')
              , ISNULL(RTRIM(UserDefine03), '')
              , ISNULL(RTRIM(UserDefine04), '')
              , ISNULL(RTRIM(UserDefine05), '')
              , UserDefine06
              , UserDefine07
              , ISNULL(RTRIM(UserDefine08), 'N')
              , ISNULL(RTRIM(UserDefine09), '')
              , ISNULL(RTRIM(UserDefine10), '')
              , CASE WHEN ISNULL(RTRIM(ToFacility), '') = '' THEN @c_FromFacility
                     ELSE ToFacility
                END
              , @c_Username
              , @c_Username
         FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         SET @n_iNo = 0;
         SET @n_SUMQty = 0;

         DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , ISNULL(RTRIM(CASE WHEN @c_InParm2 = '1' THEN UPPER(FromSku)
                                  ELSE FromSku
                             END
                       ), ''
                )
              , ISNULL(RTRIM(CASE WHEN @c_InParm2 = '1' THEN UPPER(ToSku)
                                  ELSE ToSku
                             END
                       ), ''
                )
              , ISNULL(FromQty, 0)
              , ISNULL(ToQty, 0)
              , ISNULL(RTRIM(FromPackKey), '')
              , ISNULL(RTRIM(ToPackKey), '')
              , ISNULL(RTRIM(FromUOM), '')
              , ISNULL(RTRIM(ToUOM), '')
              , TOLOTTABLE10
              , TOLOTTABLE11
         FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
         WHERE STG_BatchNo                    = @n_BatchNo
         AND   STG_Status                       = '1'
         AND   ISNULL(RTRIM(FromStorerKey), '') = @c_FromStorerKey
         AND   ISNULL(RTRIM(ToStorerKey), '')   = @c_ToStorerKey
         AND   ISNULL(RTRIM(Facility), '')      = @c_FromFacility
         AND   ISNULL(RTRIM([Type]), '')        = @c_Type
         AND   ISNULL(RTRIM(ReasonCode), '')    = @c_ReasonCode
         AND   ISNULL(RTRIM(CustomerRefNo), '') = @c_CustRefNo;

         OPEN C_DET;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_FromSku
            , @c_ToSku
            , @n_FromQty
            , @n_ToQty
            , @c_FromPackkey
            , @c_ToPackkey
            , @c_FromUOM
            , @c_ToUOM
            , @c_TOLOTTABLE10
            , @c_TOLOTTABLE11;

         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @n_SUMQty += @n_ToGetQty;
            SET @n_iNo += 1;

            SELECT @c_FromPackkey = PACKKey
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE StorerKey = @c_FromStorerKey
               AND   Sku         = @c_FromSku;

            SELECT @c_FromUOM = PackUOM3
               FROM dbo.V_PACK WITH (NOLOCK)
               WHERE PackKey = @c_FromPackkey;

            SELECT @n_FromCaseCnt = CaseCnt
                 , @n_FromGetQty  = CASE @c_FromUOM WHEN LTRIM(RTRIM(PackUOM1)) THEN CaseCnt * @n_FromQty
                                                    WHEN LTRIM(RTRIM(PackUOM2)) THEN InnerPack * @n_FromQty
                                                    WHEN LTRIM(RTRIM(PackUOM3)) THEN Qty * @n_FromQty
                                                    WHEN LTRIM(RTRIM(PackUOM4)) THEN Pallet * @n_FromQty
                                                    WHEN LTRIM(RTRIM(PackUOM8)) THEN OtherUnit1 * @n_FromQty
                                                    WHEN LTRIM(RTRIM(PackUOM9)) THEN OtherUnit2 * @n_FromQty
                                                    ELSE 0
                                    END
            FROM dbo.V_PACK (NOLOCK)
            WHERE PackKey = @c_FromPackkey
            AND   (
                   PackUOM1      = @c_FromUOM
                OR PackUOM2 = @c_FromUOM
                OR PackUOM3 = @c_FromUOM
                OR PackUOM4 = @c_FromUOM
                OR PackUOM5 = @c_FromUOM
                OR PackUOM6 = @c_FromUOM
                OR PackUOM7 = @c_FromUOM
                OR PackUOM8 = @c_FromUOM
                OR PackUOM9 = @c_FromUOM
            );

             SELECT @c_ToPackkey = PACKKey
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE StorerKey = @c_ToStorerKey
               AND   Sku         = @c_ToSku;

            SELECT @c_ToUOM = PackUOM3
               FROM dbo.V_PACK WITH (NOLOCK)
               WHERE PackKey = @c_ToPackkey;

            SELECT @n_ToCaseCnt = CaseCnt
                 , @n_ToGetQty  = CASE @c_ToUOM WHEN LTRIM(RTRIM(PackUOM1)) THEN CaseCnt * @n_ToQty
                                                WHEN LTRIM(RTRIM(PackUOM2)) THEN InnerPack * @n_ToQty
                                                WHEN LTRIM(RTRIM(PackUOM3)) THEN Qty * @n_ToQty
                                                WHEN LTRIM(RTRIM(PackUOM4)) THEN Pallet * @n_ToQty
                                                WHEN LTRIM(RTRIM(PackUOM8)) THEN OtherUnit1 * @n_ToQty
                                                WHEN LTRIM(RTRIM(PackUOM9)) THEN OtherUnit2 * @n_ToQty
                                                ELSE 0
                                  END
            FROM dbo.V_PACK (NOLOCK)
            WHERE PackKey = @c_ToPackkey
            AND   (
                   PackUOM1      = @c_ToUOM
                OR PackUOM2 = @c_ToUOM
                OR PackUOM3 = @c_ToUOM
                OR PackUOM4 = @c_ToUOM
                OR PackUOM5 = @c_ToUOM
                OR PackUOM6 = @c_ToUOM
                OR PackUOM7 = @c_ToUOM
                OR PackUOM8 = @c_ToUOM
                OR PackUOM9 = @c_ToUOM
            );

            INSERT INTO dbo.TRANSFERDETAIL
            (
               TransferKey
             , TransferLineNumber
             , FromStorerKey
             , FromSku
             , FromLoc
             , FromLot
             , FromId
             , FromQty
             , FromPackKey
             , FromUOM
             , LOTTABLE01
             , LOTTABLE02
             , LOTTABLE03
             , LOTTABLE04
             , LOTTABLE05
             , ToStorerKey
             , ToSku
             , ToLoc
             , ToLot
             , ToId
             , ToQty
             , ToPackKey
             , ToUOM
             , [Status]
             , tolottable01
             , tolottable02
             , tolottable03
             , tolottable04
             , tolottable05
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
             , AddWho
             , EditWho
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
             , ToLottable06
             , ToLottable07
             , ToLottable08
             , ToLottable09
             , ToLottable10
             , ToLottable11
             , ToLottable12
             , ToLottable13
             , ToLottable14
             , ToLottable15
             , FromChannel
             , ToChannel
            )
            SELECT @c_Transferkey
                 , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(5))
                 , @c_FromStorerKey
                 , @c_FromSku
                 , ISNULL(FromLoc, '')
                 , ISNULL(FromLot, '')
                 , ISNULL(FromId, '')
                 , ISNULL(@n_FromGetQty, 0)
                 , @c_FromPackkey
                 , @c_FromUOM
                 , ISNULL(LOTTABLE01, '')
                 , ISNULL(LOTTABLE02, '')
                 , ISNULL(LOTTABLE03, '')
                 , LOTTABLE04
                 , LOTTABLE05
                 , @c_ToStorerKey
                 , CASE WHEN @c_ToSku = '' THEN @c_FromSku
                        ELSE @c_ToSku
                   END
                 , CASE WHEN ISNULL(ToLoc, '') = '' THEN ISNULL(FromLoc, '')
                        ELSE ISNULL(ToLoc, '')
                   END
                 , ISNULL(ToLot, '')
                 , CASE WHEN ISNULL(ToId, '') = '' THEN ISNULL(FromId, '')
                        ELSE ToId
                   END
                 , CASE WHEN ToQty = 0 THEN ISNULL(@n_FromGetQty, 0)
                        ELSE ISNULL(@n_ToGetQty, 0)
                   END
                 , @c_ToPackkey
                 , @c_ToUOM
                 , '0'
                 , CASE WHEN ISNULL(TOLOTTABLE01, '') = '' THEN ISNULL(LOTTABLE01, '')
                        ELSE TOLOTTABLE01
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE02, '') = '' THEN ISNULL(LOTTABLE02, '')
                        ELSE TOLOTTABLE02
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE03, '') = '' THEN ISNULL(LOTTABLE03, '')
                        ELSE TOLOTTABLE03
                   END
                 , ISNULL(TOLOTTABLE04, '')
                 , ISNULL(TOLOTTABLE05, '')
                 , ISNULL(UserDefine01, '')
                 , ISNULL(UserDefine02, '')
                 , ISNULL(UserDefine03, '')
                 , ISNULL(UserDefine04, '')
                 , ISNULL(UserDefine05, '')
                 , UserDefine06
                 , UserDefine07
                 , ISNULL(UserDefine08, 'N')
                 , ISNULL(UserDefine09, '')
                 , ISNULL(UserDefine10, '')
                 , @c_Username
                 , @c_Username
                 , ISNULL(LOTTABLE06, '')
                 , ISNULL(LOTTABLE07, '')
                 , ISNULL(LOTTABLE08, '')
                 , ISNULL(LOTTABLE09, '')
                 , ISNULL(LOTTABLE10, '')
                 , ISNULL(LOTTABLE11, '')
                 , ISNULL(LOTTABLE12, '')
                 , LOTTABLE13
                 , LOTTABLE14
                 , LOTTABLE15
                 , CASE WHEN ISNULL(TOLOTTABLE06, '') = '' THEN ISNULL(LOTTABLE06, '')
                        ELSE TOLOTTABLE06
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE07, '') = '' THEN ISNULL(LOTTABLE07, '')
                        ELSE TOLOTTABLE07
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE08, '') = '' THEN ISNULL(LOTTABLE08, '')
                        ELSE TOLOTTABLE08
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE09, '') = '' THEN ISNULL(LOTTABLE09, '')
                        ELSE TOLOTTABLE09
                   END
                 , CASE WHEN @c_InParm3 = '0' THEN @c_TOLOTTABLE10
                        ELSE IIF(ISNULL(RTRIM(@c_TOLOTTABLE10),'') = '', 'P', @c_TOLOTTABLE10)
                   END
                 , CASE WHEN @c_InParm3 = '0' THEN @c_TOLOTTABLE11
                        ELSE IIF(ISNULL(RTRIM(@c_TOLOTTABLE11),'') = '', 'H', @c_TOLOTTABLE11)
                   END
                 , CASE WHEN ISNULL(TOLOTTABLE12, '') = '' THEN ISNULL(LOTTABLE12, '')
                        ELSE TOLOTTABLE12
                   END
                 , ISNULL(TOLOTTABLE13, '')
                 , ISNULL(TOLOTTABLE14, '')
                 , ISNULL(TOLOTTABLE15, '')
                 , ISNULL(FromChannel, '')
                 , ISNULL(ToChannel, '')
            FROM dbo.SCE_DL_TRANSFER_STG WITH (NOLOCK)
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            UPDATE dbo.SCE_DL_TRANSFER_STG WITH (ROWLOCK)
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
               , @c_FromSku
               , @c_ToSku
               , @n_FromQty
               , @n_ToQty
               , @c_FromPackkey
               , @c_ToPackkey
               , @c_FromUOM
               , @c_ToUOM
               , @c_TOLOTTABLE10
               , @c_TOLOTTABLE11;
         END;
         CLOSE C_DET;
         DEALLOCATE C_DET;

         FETCH NEXT FROM C_HDR
         INTO @c_FromStorerKey
            , @c_ToStorerKey
            , @c_FromFacility
            , @c_Type
            , @c_ReasonCode
            , @c_CustRefNo;
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
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_TRANSFER_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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