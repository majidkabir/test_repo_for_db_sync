SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_ASN_RULES_200001_10             */
/* Creation Date: 12-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into ASN target table             */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore ASN              */
/*                           @c_InParm1 =  '1'  ASN update is allow     */
/*   ByPass Receipt Details  @c_InParm2 =  '0'  Will not bypass         */
/*                           @c_InParm2 =  '1'  Will bypass             */
/*               ExplodeBOM  @c_InParm3 =  '0'  Turn Off                */
/*                           @c_InParm3 =  '1'  Turn On                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.2                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-Jan-2022  GHChan    1.1   Initial                                 */
/* 03-Nov-2022  WLChooi   1.2   Extend ExternReceiptkey to 50 (WL01)    */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_ASN_RULES_200001_10_bk] (
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

   DECLARE @n_RowRefNo         INT
         , @c_Storerkey        NVARCHAR(15)
         , @c_ExternReceiptkey NVARCHAR(50)   --WL01
         , @c_SKU              NVARCHAR(20)
         , @n_Qty              INT
         , @c_Receiptkey       NVARCHAR(10)
         , @c_UOM              NVARCHAR(10)
         , @c_Packkey          NVARCHAR(10)
         , @n_SUMQty           INT
         , @n_iNo              INT
         , @n_GetQty           INT
         , @n_CaseCnt          FLOAT
         , @c_TargetDBName     NVARCHAR(10)
         , @c_OrderGrp         NVARCHAR(20)
         , @c_LineNum          NVARCHAR(20)
         , @i                  INT
         , @n_TtlLen           INT
         , @c_ChkStatus        NVARCHAR(10)
         , @n_ActionFlag       INT
         , @c_ttlMsg           NVARCHAR(250);

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

   SET @n_StartTCnt = @@TRANCOUNT;
   SET @c_TargetDBName = DB_NAME();

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
        , ExternReceiptkey
   FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   GROUP BY Storerkey
          , ExternReceiptkey;

   OPEN C_HDR;
   FETCH NEXT FROM C_HDR
   INTO @c_Storerkey
      , @c_ExternReceiptkey;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_ActionFlag = 0;
      BEGIN TRAN;

      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
      WHERE STG_BatchNo    = @n_BatchNo
      AND   STG_Status       = '1'
      AND   Storerkey        = @c_Storerkey
      AND   ExternReceiptkey = @c_ExternReceiptkey
      ORDER BY STG_SeqNo ASC;

      SET @c_Receiptkey = N'';

      SELECT @c_Receiptkey = ISNULL(RTRIM(ReceiptKey), '')
           , @c_ChkStatus  = ASNStatus
      FROM dbo.V_RECEIPT WITH (NOLOCK)
      WHERE ExternReceiptKey = @c_ExternReceiptkey
      AND   StorerKey          = @c_Storerkey;

      IF @c_InParm1 = '1'
      BEGIN
         IF @c_Receiptkey <> ''
         BEGIN
            IF @c_ChkStatus = '9'
            BEGIN
               UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error:RECEIPT already Finalized,update failed'
               WHERE STG_BatchNo    = @n_BatchNo
               AND   STG_Status       = '1'
               AND   Storerkey        = @c_Storerkey
               AND   ExternReceiptkey = @c_ExternReceiptkey;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
               GOTO NEXTITEM;
            END;
            ELSE
            BEGIN
               SET @n_ActionFlag = 1; -- UPDATE
            END;
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;

      END;
      ELSE IF @c_InParm1 = '0'
      BEGIN
         IF @c_Receiptkey <> ''
         BEGIN
            UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error:RECEIPT already exists'
            WHERE STG_BatchNo    = @n_BatchNo
            AND   STG_Status       = '1'
            AND   Storerkey        = @c_Storerkey
            AND   ExternReceiptkey = @c_ExternReceiptkey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
            GOTO NEXTITEM;
         END;
         ELSE
         BEGIN
            SET @n_ActionFlag = 0; -- INSERT
         END;
      END;

      IF @n_ActionFlag = 1
      BEGIN

         UPDATE RCPT WITH (ROWLOCK)
         SET RCPT.ReceiptGroup = ISNULL(STG.ReceiptGroup, '')
           , RCPT.ReceiptDate = ISNULL(STG.ReceiptDate, GETDATE())
           , RCPT.POKey = ISNULL(STG.POKey, '')
           , RCPT.CarrierKey = ISNULL(RTRIM(STG.CarrierKey), '')
           , RCPT.CarrierName = STG.CarrierName
           , RCPT.CarrierAddress1 = STG.CarrierAddress1
           , RCPT.CarrierAddress2 = STG.CarrierAddress2
           , RCPT.CarrierCity = STG.CarrierCity
           , RCPT.CarrierState = STG.CarrierState
           , RCPT.CarrierZip = STG.CarrierZip
           , RCPT.CarrierReference = STG.CarrierReference
           , RCPT.WarehouseReference = STG.WarehouseReference
           , RCPT.OriginCountry = STG.OriginCountry
           , RCPT.DestinationCountry = STG.DestinationCountry
           , RCPT.VehicleNumber = STG.VehicleNumber
           , RCPT.VehicleDate = STG.VehicleDate
           , RCPT.PlaceOfLoading = STG.PlaceOfLoading
           , RCPT.PlaceOfDischarge = STG.PlaceOfDischarge
           , RCPT.PlaceofDelivery = STG.PlaceOfDelivery
           , RCPT.IncoTerms = STG.IncoTerms
           , RCPT.TermsNote = STG.TermsNote
           , RCPT.ContainerKey = STG.ContainerKey
           , RCPT.Signatory = STG.Signatory
           , RCPT.PlaceofIssue = STG.PlaceofIssue
           , RCPT.Notes = CAST(STG.Notes AS NVARCHAR(255))
           , RCPT.ContainerType = STG.ContainerType
           , RCPT.ContainerQty = STG.ContainerQty
           , RCPT.BilledContainerQty = ISNULL(STG.BilledContainerQty, 0)
           , RCPT.RECType = ISNULL(STG.RECType, 'NORMAL')
           , RCPT.ASNReason = ISNULL(STG.ASNReason, '')
           , RCPT.Facility = STG.Facility
           , RCPT.Appointment_No = STG.Appointment_No
           , RCPT.xDockFlag = ISNULL(STG.xDockFlag, 0)
           , RCPT.UserDefine01 = ISNULL(STG.HUSR01, '')
           , RCPT.UserDefine02 = ISNULL(STG.HUSR02, '')
           , RCPT.UserDefine03 = ISNULL(STG.HUSR03, '')
           , RCPT.UserDefine04 = ISNULL(STG.HUSR04, '')
           , RCPT.UserDefine05 = ISNULL(STG.HUSR05, '')
           , RCPT.UserDefine06 = ISNULL(STG.HUSR06, '')
           , RCPT.UserDefine07 = ISNULL(STG.HUSR07, '')
           , RCPT.UserDefine08 = ISNULL(STG.HUSR08, '')
           , RCPT.UserDefine09 = ISNULL(STG.HUSR09, '')
           , RCPT.UserDefine10 = ISNULL(STG.HUSR10, '')
           , RCPT.DOCTYPE = CASE WHEN ISNULL(STG.RECType, 'NORMAL') <> 'GRN' THEN ISNULL(STG.DOCTYPE, 'A')
                                 ELSE 'R'
                            END
           , RCPT.RoutingTool = STG.RoutingTool
           , RCPT.NoOfMasterCtn = STG.NoOfMasterCtn
           , RCPT.NoOfTTLUnit = STG.NoOfTTLUnit
           , RCPT.NoOfPallet = STG.NoOfPallet
           , RCPT.Weight = ISNULL(STG.HWeight, 0)
           , RCPT.WeightUnit = STG.WeightUnit
           , RCPT.Cube = ISNULL(STG.HCube, 0)
           , RCPT.CubeUnit = STG.CubeUnit
           , RCPT.PROCESSTYPE = STG.PROCESSTYPE
           , RCPT.SellerName = STG.SellerName
           , RCPT.SellerAddress1 = STG.SellerAddress1
           , RCPT.SellerAddress2 = STG.SellerAddress2
           , RCPT.SellerCity = STG.SellerCity
           , RCPT.SellerState = STG.SellerState
           , RCPT.SellerZip = STG.SellerZip
           , RCPT.SellerPhone1 = STG.SellerPhone1
           , RCPT.SellerPhone2 = STG.SellerPhone2
           , RCPT.EffectiveDate = CASE WHEN STG.EffectiveDate IS NOT NULL THEN STG.EffectiveDate
                                       ELSE RCPT.EffectiveDate
                                  END
           , EditWho = @c_Username
           , EditDate = GETDATE()
         FROM dbo.SCE_DL_ASN_STG STG WITH (NOLOCK)
         JOIN dbo.RECEIPT        RCPT
         ON (
             STG.ExternReceiptkey = RCPT.ExternReceiptKey
         AND STG.Storerkey    = RCPT.StorerKey
         )
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         DELETE FROM dbo.RECEIPTDETAIL
         WHERE ReceiptKey = @c_Receiptkey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

      --WHILE @@TRANCOUNT > 0
      --COMMIT TRAN;
      END;
      ELSE IF @n_ActionFlag = 0
      BEGIN
         SELECT @b_Success = 0;
         EXEC dbo.nspg_GetKey @KeyName = 'RECEIPT'
                            , @fieldlength = 10
                            , @keystring = @c_Receiptkey OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_ErrNo OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT;

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = CASE WHEN @n_ErrNo = 0 THEN 100001
                                ELSE @n_ErrNo
                           END;
            SET @c_ErrMsg = 'Failed to get a new ReceiptKey from nspg_getkey. (isp_SCE_DL_GENERIC_ASN_RULES_200001_10)';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         IF @b_Debug = 1
         BEGIN
            SELECT 'New Receiptkey : ' + @c_Receiptkey;
         END;

         INSERT INTO dbo.RECEIPT
         (
            ReceiptKey
          , ExternReceiptKey
          , ReceiptGroup
          , StorerKey
          , ReceiptDate
          , POKey
          , CarrierKey
          , CarrierName
          , CarrierAddress1
          , CarrierAddress2
          , CarrierCity
          , CarrierState
          , CarrierZip
          , CarrierReference
          , WarehouseReference
          , OriginCountry
          , DestinationCountry
          , VehicleNumber
          , VehicleDate
          , PlaceOfLoading
          , PlaceOfDischarge
          , PlaceofDelivery
          , IncoTerms
          , TermsNote
          , ContainerKey
          , Signatory
          , PlaceofIssue
          , Notes
          , ContainerType
          , ContainerQty
          , BilledContainerQty
          , RECType
          , ASNReason
          , Facility
          , Appointment_No
          , xDockFlag
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
          , DOCTYPE
          , RoutingTool
          , NoOfMasterCtn
          , NoOfTTLUnit
          , NoOfPallet
          , Weight
          , WeightUnit
          , Cube
          , CubeUnit
          , PROCESSTYPE
          , SellerName
          , SellerCompany
          , SellerAddress1
          , SellerAddress2
          , SellerAddress3
          , SellerAddress4
          , SellerPhone1
          , SellerPhone2
          , SellerCity
          , SellerState
          , SellerZip
          , SellerCountry
          , SellerContact1
          , SellerContact2
          , AddWho
          , EditWho
          , EffectiveDate
         )
         SELECT @c_Receiptkey
              , @c_ExternReceiptkey
              , ISNULL(STG.ReceiptGroup, '')
              , @c_Storerkey
              , ISNULL(STG.ReceiptDate, GETDATE())
              , ISNULL(STG.POKey, '')
              , ISNULL(RTRIM(STG.CarrierKey), '')
              , STG.CarrierName
              , STG.CarrierAddress1
              , STG.CarrierAddress2
              , STG.CarrierCity
              , STG.CarrierState
              , STG.CarrierZip
              , STG.CarrierReference
              , STG.WarehouseReference
              , STG.OriginCountry
              , STG.DestinationCountry
              , STG.VehicleNumber
              , STG.VehicleDate
              , STG.PlaceOfLoading
              , STG.PlaceOfDischarge
              , STG.PlaceOfDelivery
              , STG.IncoTerms
              , STG.TermsNote
              , STG.ContainerKey
              , STG.Signatory
              , STG.PlaceofIssue
              , CAST(STG.Notes AS NVARCHAR(255))
              , STG.ContainerType
              , STG.ContainerQty
              , ISNULL(STG.BilledContainerQty, 0)
              , ISNULL(STG.RECType, 'NORMAL')
              , ISNULL(STG.ASNReason, '')
              , STG.Facility
              , STG.Appointment_No
              , ISNULL(STG.xDockFlag, 0)
              , ISNULL(STG.HUSR01, '')
              , ISNULL(STG.HUSR02, '')
              , ISNULL(STG.HUSR03, '')
              , ISNULL(STG.HUSR04, '')
              , ISNULL(STG.HUSR05, '')
              , ISNULL(STG.HUSR06, '')
              , ISNULL(STG.HUSR07, '')
              , ISNULL(STG.HUSR08, '')
              , ISNULL(STG.HUSR09, '')
              , ISNULL(STG.HUSR10, '')
              , CASE WHEN ISNULL(STG.RECType, 'NORMAL') <> 'GRN' THEN ISNULL(STG.DOCTYPE, 'A')
                     ELSE 'R'
                END
              , STG.RoutingTool
              , STG.NoOfMasterCtn
              , STG.NoOfTTLUnit
              , STG.NoOfPallet
              , ISNULL(STG.HWeight, 0)
              , STG.WeightUnit
              , ISNULL(STG.HCube, 0)
              , STG.CubeUnit
              , PROCESSTYPE
              , STG.SellerName
              , STG.SellerCompany
              , STG.SellerAddress1
              , STG.SellerAddress2
              , STG.SellerAddress3
              , STG.SellerAddress4
              , STG.SellerPhone1
              , SellerPhone2
              , STG.SellerCity
              , STG.SellerState
              , STG.SellerZip
              , STG.SellerCountry
              , STG.SellerContact1
              , STG.SellerContact2
              , @c_Username
              , @c_Username
              , ISNULL(STG.EffectiveDate, GETDATE())
         FROM dbo.SCE_DL_ASN_STG STG WITH (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         /*CS23 start*/
         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET Receiptkey = @c_Receiptkey
         WHERE STG_BatchNo    = @n_BatchNo
         AND   STG_Status       = '1'
         AND   Storerkey        = @c_Storerkey
         AND   ExternReceiptkey = @c_ExternReceiptkey;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;
      END;

      IF EXISTS (
      SELECT 1
      FROM dbo.V_RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @c_Receiptkey
      )
      BEGIN
         SET @n_Continue = 3;
         SET @n_ErrNo = 100002;
         SET @c_ErrMsg = 'Logic Error. Unable to insert the ReceiptDetail. ReceiptKey(' + @c_Receiptkey
                         + '). (isp_SCE_DL_GENERIC_ASN_RULES_200001_10)';
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      SET @n_SUMQty = 0;
      SET @n_iNo = 0;

      DECLARE C_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
           , SKU
           , ISNULL(QtyExpected, 0)
           , Storerkey
           , UOM
           , Packkey
      FROM dbo.SCE_DL_ASN_STG WITH (NOLOCK)
      WHERE STG_BatchNo    = @n_BatchNo
      AND   STG_Status       = '1'
      AND   Storerkey        = @c_Storerkey
      AND   ExternReceiptkey = @c_ExternReceiptkey
      ORDER BY STG_SeqNo ASC;

      OPEN C_DET;
      FETCH NEXT FROM C_DET
      INTO @n_RowRefNo
         , @c_SKU
         , @n_Qty
         , @c_Storerkey
         , @c_UOM
         , @c_Packkey;

      WHILE @@FETCH_STATUS = 0
      BEGIN

         IF @c_InParm2 = '0'
         BEGIN
            IF ISNULL(@c_UOM, '') = ''
            BEGIN
               IF ISNULL(@c_Packkey, '') = ''
               BEGIN --Get PackKey IF Packkey is null

                  SELECT @c_Packkey = PACKKey
                  FROM dbo.V_SKU (NOLOCK)
                  WHERE StorerKey = RTRIM(@c_Storerkey)
                  AND   Sku         = @c_SKU;

                  IF @b_Debug = 1
                  BEGIN
                     SELECT 'Get PackKey IF UOM IS Null : ' + @c_Packkey;
                  END;
               END;

               SELECT @c_UOM = PackUOM3
               FROM dbo.V_PACK WITH (NOLOCK)
               WHERE PackKey = @c_Packkey;
            END;


            IF  @c_UOM <> ''
            AND ISNULL(RTRIM(@c_Packkey), '') = ''
            BEGIN --Get PackKey IF Packkey is null AND UOM NOT NULL
               SELECT @c_Packkey = PACKKey
               FROM dbo.V_SKU (NOLOCK)
               WHERE StorerKey = RTRIM(@c_Storerkey)
               AND   Sku         = @c_SKU;

               IF @b_Debug = 1
               BEGIN
                  SELECT 'Get PackKey IF UOM IS Null : ' + @c_Packkey;
               END;
            END; --Get PackKey IF Packkey is null AND UOM NOT NULL


            SELECT @n_CaseCnt = CaseCnt
                 , @n_GetQty  = CASE @c_UOM WHEN LTRIM(RTRIM(PackUOM1)) THEN CaseCnt * @n_Qty
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

            IF @b_Debug = 1
            BEGIN
               SELECT 'Open Qty is  : ' + CONVERT(VARCHAR(10), @n_GetQty);
            END;
         END;

         SET @n_SUMQty += @n_GetQty;
         SET @n_iNo += 1;

         IF @c_InParm2 = '0'
         BEGIN
            IF @c_InParm3 = '1'
            BEGIN
               SET @i = 0;
               SET @n_TtlLen = 0
               SET @c_LineNum = ''
               SET @c_LineNum = CAST(@n_iNo AS NVARCHAR(20));
               SET @n_TtlLen = 5 - LEN(@c_LineNum)
               WHILE @i < (@n_TtlLen)
               BEGIN
                  SET @c_LineNum += N'0';
                  SET @i += 1;
               END;

               INSERT INTO dbo.RECEIPTDETAIL
               (
                  ReceiptKey
                , ReceiptLineNumber
                , ExternReceiptKey
                , ExternLineNo
                , StorerKey
                , POKey
                , Sku
                , AltSku
                , Id
                , DateReceived
                , QtyExpected
                , BeforeReceivedQty
                , UOM
                , PackKey
                , VesselKey
                , VoyageKey
                , XdockKey
                , ContainerKey
                , ToLoc
                , ToLot
                , ToId
                , ConditionCode
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
                , CaseCnt
                , InnerPack
                , Pallet
                , Cube
                , GrossWgt
                , NetWgt
                , OtherUnit1
                , OtherUnit2
                , UnitPrice
                , ExtendedPrice
                , SubReasonCode
                , PutawayLoc
                , POLineNumber
                , ExternPoKey
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
                , Channel
                , AddWho
                , EditWho
               )
               SELECT @c_Receiptkey
                    , @c_LineNum
                      + CASE WHEN LEN(BOMat.Sequence) = 1 THEN '0' + LTRIM(RTRIM(BOMat.Sequence))
                             ELSE                                            LTRIM(RTRIM(BOMat.Sequence))
                        END
                    , ISNULL(STG.ExternReceiptkey, '')
                    , ISNULL(STG.ExternLineNo, '')
                    , @c_Storerkey
                    , ISNULL(STG.POKey, '')
                    , BOMat.ComponentSku
                    , ISNULL(STG.AltSKU, '')
                    , ISNULL(STG.ID, '')
                    , ISNULL(STG.DateReceived, GETDATE())
                    , ISNULL(@n_GetQty, 0)
                    , ISNULL(STG.BeforeReceivedQty, 0)
                    , @c_UOM
                    , ISNULL(@c_Packkey, '')
                    , STG.VesselKey
                    , STG.VoyageKey
                    , STG.XdockKey
                    , ISNULL(STG.ContainerKey, '')
                    , STG.ToLoc
                    , STG.ToLot
                    , ISNULL(STG.ToID, '')
                    , ISNULL(STG.ConditionCode, 'OK')
                    , ISNULL(STG.Lottable01, '')
                    , ISNULL(STG.Lottable02, '')
                    , ISNULL(STG.Lottable03, '')
                    , STG.Lottable04
                    , STG.Lottable05
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
                    , ISNULL(STG.CaseCnt, 0)
                    , ISNULL(STG.InnerPack, 0)
                    , ISNULL(STG.Pallet, 0)
                    , ISNULL(STG.DCube, 0)
                    , ISNULL(STG.DGrossWgt, 0)
                    , ISNULL(STG.DNetWgt, 0)
                    , ISNULL(STG.OtherUnit1, 0)
                    , ISNULL(STG.OtherUnit2, 0)
                    , ISNULL(STG.UnitPrice, 0)
                    , ISNULL(STG.ExtendedPrice, 0)
                    , ISNULL(STG.SubReasonCode, '')
                    , ISNULL(STG.PutawayLoc, '')
                    , ISNULL(STG.POLineNumber, '')
                    , STG.ExternPOKey
                    , ISNULL(STG.DUSR01, '')
                    , ISNULL(STG.DUSR02, '')
                    , ISNULL(STG.DUSR03, '')
                    , ISNULL(STG.DUSR04, '')
                    , ISNULL(STG.DUSR05, '')
                    , STG.DUSR06
                    , STG.DUSR07
                    , ISNULL(STG.DUSR08, '')
                    , ISNULL(STG.DUSR09, '')
                    , ISNULL(STG.DUSR10, '')
                    , ISNULL(STG.Channel, '')
                    , @c_Username
                    , @c_Username
               FROM dbo.SCE_DL_ASN_STG         STG WITH (NOLOCK)
               INNER JOIN dbo.V_BillOfMaterial BOMat WITH (NOLOCK)
               ON  STG.Storerkey       = BOMat.Storerkey
               AND STG.SKU            = BOMat.Sku
               INNER JOIN dbo.V_SKU            sku WITH (NOLOCK)
               ON  BOMat.Storerkey     = sku.StorerKey
               AND BOMat.ComponentSku = sku.Sku
               INNER JOIN dbo.V_SKU            sku1 WITH (NOLOCK)
               ON  STG.Storerkey       = sku1.StorerKey
               AND STG.SKU            = sku1.Sku
               WHERE STG.RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;
            ELSE
            BEGIN
               

               IF @b_Debug = 1
               BEGIN
                  SELECT '@c_Receiptkey : ' + @c_Receiptkey;
               END;

               INSERT INTO dbo.RECEIPTDETAIL
               (
                  ReceiptKey
                , ReceiptLineNumber
                , ExternReceiptKey
                , ExternLineNo
                , StorerKey
                , POKey
                , Sku
                , AltSku
                , Id
                , DateReceived
                , QtyExpected
                , BeforeReceivedQty
                , UOM
                , PackKey
                , VesselKey
                , VoyageKey
                , XdockKey
                , ContainerKey
                , ToLoc
                , ToLot
                , ToId
                , ConditionCode
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
                , CaseCnt
                , InnerPack
                , Pallet
                , Cube
                , GrossWgt
                , NetWgt
                , OtherUnit1
                , OtherUnit2
                , UnitPrice
                , ExtendedPrice
                , SubReasonCode
                , PutawayLoc
                , POLineNumber
                , ExternPoKey
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
                , Channel
                , AddWho
                , EditWho
               )
               SELECT @c_Receiptkey
                    , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(10))
                    , ISNULL(STG.ExternReceiptkey, '')
                    , ISNULL(STG.ExternLineNo, '')
                    , @c_Storerkey
                    , ISNULL(STG.POKey, '')
                    , @c_SKU
                    , ISNULL(STG.AltSKU, '')
                    , ISNULL(STG.ID, '')
                    , ISNULL(STG.DateReceived, GETDATE())
                    , ISNULL(@n_GetQty, 0)
                    , ISNULL(STG.BeforeReceivedQty, 0)
                    , @c_UOM
                    , ISNULL(@c_Packkey, '')
                    , STG.VesselKey
                    , STG.VoyageKey
                    , STG.XdockKey
                    , STG.ContainerKey
                    , STG.ToLoc
                    , STG.ToLot
                    , ISNULL(STG.ToID, '')
                    , ISNULL(STG.ConditionCode, 'OK')
                    , ISNULL(STG.Lottable01, '')
                    , ISNULL(STG.Lottable02, '')
                    , ISNULL(STG.Lottable03, '')
                    , STG.Lottable04
                    , STG.Lottable05
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
                    , ISNULL(STG.CaseCnt, 0)
                    , ISNULL(STG.InnerPack, 0)
                    , ISNULL(STG.Pallet, 0)
                    , ISNULL(STG.DCube, 0)
                    , ISNULL(STG.DGrossWgt, 0)
                    , ISNULL(STG.DNetWgt, 0)
                    , ISNULL(STG.OtherUnit1, 0)
                    , ISNULL(STG.OtherUnit2, 0)
                    , ISNULL(STG.UnitPrice, 0)
                    , ISNULL(STG.ExtendedPrice, 0)
                    , ISNULL(STG.SubReasonCode, '')
                    , ISNULL(STG.PutawayLoc, '')
                    , ISNULL(STG.POLineNumber, '')
                    , STG.ExternPOKey
                    , ISNULL(STG.DUSR01, '')
                    , ISNULL(STG.DUSR02, '')
                    , ISNULL(STG.DUSR03, '')
                    , ISNULL(STG.DUSR04, '')
                    , ISNULL(STG.DUSR05, '')
                    , STG.DUSR06
                    , STG.DUSR07
                    , ISNULL(STG.DUSR08, '')
                    , ISNULL(STG.DUSR09, '')
                    , ISNULL(STG.DUSR10, '')
                    , ISNULL(STG.Channel, '')
                    , @c_Username
                    , @c_Username
               FROM dbo.SCE_DL_ASN_STG AS STG (NOLOCK)
               INNER JOIN dbo.V_SKU    AS sku (NOLOCK)
               ON  STG.Storerkey = sku.StorerKey
               AND STG.SKU      = sku.Sku
               WHERE STG.RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;

               --WHILE @@TRANCOUNT > 0
               --COMMIT TRAN;
            END;
         END;

         UPDATE dbo.SCE_DL_ASN_STG WITH (ROWLOCK)
         SET STG_Status = '9'
         WHERE RowRefNo = @n_RowRefNo;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         IF @b_Debug = 1
         BEGIN
            SELECT '@c_ExternReceiptkey : ' + @c_ExternReceiptkey;
         END;

         FETCH NEXT FROM C_DET
         INTO @n_RowRefNo
            , @c_SKU
            , @n_Qty
            , @c_Storerkey
            , @c_UOM
            , @c_Packkey;
      END;

      CLOSE C_DET;
      DEALLOCATE C_DET;

      UPDATE dbo.RECEIPT WITH (ROWLOCK)
      SET OpenQty = @n_SUMQty
      WHERE ReceiptKey = @c_Receiptkey;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      NEXTITEM:
      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

      FETCH NEXT FROM C_HDR
      INTO @c_Storerkey
         , @c_ExternReceiptkey;
   END;
   CLOSE C_HDR;
   DEALLOCATE C_HDR;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_ASN_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN;

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;
   END;
   ELSE
   BEGIN
      SET @b_Success = 1;
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN;
      END;
   END;
END;

GO