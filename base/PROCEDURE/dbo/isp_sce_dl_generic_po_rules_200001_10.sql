SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_PO_RULES_200001_10              */
/* Creation Date: 10-Dec-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into PO target table              */
/*                                                                      */
/*                                                                      */
/* Usage:  Insert PO ONLY if @c_InParm1 =  '0'  PO update is allow      */
/*                           @c_InParm1 =  '1'  PO update is not allow  */
/*         Update or Ignore  @c_InParm2 =  '0'  Ignore PO               */
/*                           @c_InParm2 =  '1'  PO update is allow      */
/*                           @c_InParm2 =  '2'  Insert new PO only      */
/*       Concat POKey Prefix @c_InParm3 =  '0'  Turn Off                */
/*                           @c_InParm3 =  '1'  Turn On                 */
/*       Get UserDefine      @c_InParm4 =  '0'  Turn Off                */
/*                           @c_InParm4 =  '1'  Turn On                 */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Dec-2021  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_PO_RULES_200001_10] (
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

   DECLARE @n_RowRefNo    INT
         , @c_ExternPOkey NVARCHAR(20)
         , @c_Storerkey   NVARCHAR(20)
         , @c_POkey       NVARCHAR(10)
         , @c_ChkStatus   NVARCHAR(10)
         , @c_ttlMsg      NVARCHAR(250)
         , @c_SKU         NVARCHAR(20)
         , @n_Qty         INT
         , @c_UOM         NVARCHAR(10)
         , @c_Packkey     NVARCHAR(10)
         , @c_DUDF01      NVARCHAR(30)
         , @c_DUDF02      NVARCHAR(30)
         , @n_SUMQty      INT
         , @n_iNo         INT
         , @c_HUDF01      NVARCHAR(30)
         , @c_HUDF02      NVARCHAR(30)
         , @n_SumDUDF01   FLOAT
         , @n_SumDUDF02   FLOAT
         , @n_GetQty      INT
         , @n_CaseCnt     FLOAT
         , @c_SKUDesc     NVARCHAR(60);

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

   IF @c_InParm1 = '0'
   BEGIN
      DECLARE C_PO_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ExternPOKey
           , StorerKey
      FROM dbo.SCE_DL_PO_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status    = '1'
      GROUP BY ExternPOKey
             , StorerKey;

      OPEN C_PO_HDR;
      FETCH NEXT FROM C_PO_HDR
      INTO @c_ExternPOkey
         , @c_Storerkey;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRAN;

         SET @c_ttlMsg = N'';
         SET @c_POkey = N'';

         SELECT TOP (1) @n_RowRefNo = RowRefNo
         FROM dbo.SCE_DL_PO_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   StorerKey     = @c_Storerkey
         AND   ExternPOKey   = @c_ExternPOkey
         ORDER BY STG_SeqNo ASC;

         SELECT @c_POkey = ISNULL(RTRIM(POKey), '')
         FROM dbo.V_PO WITH (NOLOCK)
         WHERE ExternPOKey = @c_ExternPOkey
         AND   StorerKey     = @c_Storerkey;

         IF @b_Debug = 1
         BEGIN
            SELECT '@c_POKey : ' + @c_POkey;
         END;

         IF @c_InParm2 = '1'
         BEGIN --PO  
            IF @c_POkey <> ''
            BEGIN
               UPDATE PO WITH (ROWLOCK)
               SET PoGroup = ISNULL(WPO.PoGroup, '')
                 , PODate = ISNULL(WPO.PODate, GETDATE())
                 , SellersReference = ISNULL(WPO.SellersReference, '')
                 , BuyersReference = ISNULL(WPO.BuyersReference, '')
                 , OtherReference = ISNULL(WPO.OtherReference, '')
                 , POType = ISNULL(WPO.POType, '')
                 , SellerName = ISNULL(WPO.SellerName, '')
                 , SellerAddress1 = ISNULL(WPO.SellerAddress1, '')
                 , SellerAddress2 = ISNULL(WPO.SellerAddress2, '')
                 , SellerAddress3 = ISNULL(WPO.SellerAddress3, '')
                 , SellerAddress4 = ISNULL(WPO.SellerAddress4, '')
                 , SellerCity = ISNULL(WPO.SellerCity, '')
                 , SellerState = ISNULL(WPO.SellerState, '')
                 , SellerZip = ISNULL(WPO.SellerZip, '')
                 , SellerPhone = ISNULL(WPO.SellerPhone, '')
                 , SellerVat = ISNULL(WPO.SellerVat, '')
                 , BuyerName = ISNULL(WPO.BuyerName, '')
                 , BuyerAddress1 = ISNULL(WPO.BuyerAddress1, '')
                 , BuyerAddress2 = ISNULL(WPO.BuyerAddress2, '')
                 , BuyerAddress3 = ISNULL(WPO.BuyerAddress3, '')
                 , BuyerAddress4 = ISNULL(WPO.BuyerAddress4, '')
                 , BuyerCity = ISNULL(WPO.BuyerCity, '')
                 , BuyerState = ISNULL(WPO.BuyerState, '')
                 , BuyerZip = ISNULL(WPO.BuyerZip, '')
                 , BuyerPhone = ISNULL(WPO.BuyerPhone, '')
                 , BuyerVAT = ISNULL(WPO.BuyerVAT, '')
                 , OriginCountry = ISNULL(WPO.OriginCountry, '')
                 , DestinationCountry = ISNULL(WPO.DestinationCountry, '')
                 , Vessel = ISNULL(WPO.Vessel, '')
                 , VesselDate = WPO.VesselDate
                 , PlaceOfLoading = ISNULL(WPO.PlaceOfLoading, '')
                 , PlaceOfDischarge = ISNULL(WPO.PlaceOfDischarge, '')
                 , PlaceofDelivery = ISNULL(WPO.PlaceofDelivery, '')
                 , IncoTerms = ISNULL(WPO.IncoTerms, '')
                 , Pmtterm = ISNULL(WPO.Pmtterm, '')
                 , TransMethod = ISNULL(WPO.TransMethod, '')
                 , TermsNote = ISNULL(WPO.TermsNote, '')
                 , Signatory = ISNULL(WPO.Signatory, '')
                 , PlaceofIssue = ISNULL(WPO.PlaceofIssue, '')
                 , Notes = CAST(WPO.Notes AS NVARCHAR(255))
                 , EffectiveDate = ISNULL(WPO.EffectiveDate, GETDATE())
                 , LoadingDate = WPO.LoadingDate
                 , ReasonCode = ISNULL(WPO.ReasonCode, '')
                 , UserDefine01 = ISNULL(WPO.HUdef01, '')
                 , UserDefine02 = ISNULL(WPO.HUdef02, '')
                 , UserDefine03 = ISNULL(WPO.HUdef03, '')
                 , UserDefine04 = ISNULL(WPO.HUdef04, '')
                 , UserDefine05 = ISNULL(WPO.HUdef05, '')
                 , UserDefine06 = WPO.HUdef06
                 , UserDefine07 = WPO.HUdef07
                 , UserDefine08 = ISNULL(WPO.HUdef08, '')
                 , UserDefine09 = ISNULL(WPO.HUdef09, '')
                 , UserDefine10 = ISNULL(WPO.HUdef10, '')
                 , xdockpokey = WPO.xdockpokey
                 , EditWho = @c_Username
                 , EditDate = GETDATE()
               FROM dbo.SCE_DL_PO_STG WPO WITH (NOLOCK)
               JOIN dbo.PO            PO
               ON (
                   WPO.StorerKey      = PO.StorerKey
               AND PO.ExternPOKey = WPO.ExternPOKey
               )
               WHERE WPO.RowRefNo = @n_RowRefNo;
               --AND  PO.POKey     = @c_POkey
               --AND   WPO.ExcelRowNo = @n_ExcelRowNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;

               DELETE FROM dbo.PODETAIL
               WHERE POKey = @c_POkey;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;
            ELSE
            BEGIN
               SELECT @b_Success = 0;
               EXEC dbo.nspg_GetKey @KeyName = 'PO'
                                  , @fieldlength = 10
                                  , @keystring = @c_POkey OUTPUT
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

               IF @c_InParm3 = '1'
               BEGIN
                  SET @c_ExternPOkey = SUBSTRING(@c_ExternPOkey, 1, 4) + N'-' + @c_POkey;
               END;

               INSERT INTO dbo.PO
               (
                  POKey
                , ExternPOKey
                , PoGroup
                , StorerKey
                , PODate
                , SellersReference
                , BuyersReference
                , OtherReference
                , POType
                , SellerName
                , SellerAddress1
                , SellerAddress2
                , SellerAddress3
                , SellerAddress4
                , SellerCity
                , SellerState
                , SellerZip
                , SellerPhone
                , SellerVat
                , BuyerName
                , BuyerAddress1
                , BuyerAddress2
                , BuyerAddress3
                , BuyerAddress4
                , BuyerCity
                , BuyerState
                , BuyerZip
                , BuyerPhone
                , BuyerVAT
                , OriginCountry
                , DestinationCountry
                , Vessel
                , VesselDate
                , PlaceOfLoading
                , PlaceOfDischarge
                , PlaceofDelivery
                , IncoTerms
                , Pmtterm
                , TransMethod
                , TermsNote
                , Signatory
                , PlaceofIssue
                , Notes
                , EffectiveDate
                , LoadingDate
                , ReasonCode
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
                , xdockpokey
                , AddWho
                , EditWho
               )
               SELECT @c_POkey
                    , @c_ExternPOkey
                    , ISNULL(WPO.PoGroup, '')
                    , @c_Storerkey
                    , ISNULL(WPO.PODate, GETDATE())
                    , ISNULL(WPO.SellersReference, '')
                    , ISNULL(WPO.BuyersReference, '')
                    , ISNULL(WPO.OtherReference, '')
                    , ISNULL(WPO.POType, '')
                    , ISNULL(WPO.SellerName, '')
                    , ISNULL(WPO.SellerAddress1, '')
                    , ISNULL(WPO.SellerAddress2, '')
                    , ISNULL(WPO.SellerAddress3, '')
                    , ISNULL(WPO.SellerAddress4, '')
                    , ISNULL(WPO.SellerCity, '')
                    , ISNULL(WPO.SellerState, '')
                    , ISNULL(WPO.SellerZip, '')
                    , ISNULL(WPO.SellerPhone, '')
                    , ISNULL(WPO.SellerVat, '')
                    , ISNULL(WPO.BuyerName, '')
                    , ISNULL(WPO.BuyerAddress1, '')
                    , ISNULL(WPO.BuyerAddress2, '')
                    , ISNULL(WPO.BuyerAddress3, '')
                    , ISNULL(WPO.BuyerAddress4, '')
                    , ISNULL(WPO.BuyerCity, '')
                    , ISNULL(WPO.BuyerState, '')
                    , ISNULL(WPO.BuyerZip, '')
                    , ISNULL(WPO.BuyerPhone, '')
                    , ISNULL(WPO.BuyerVAT, '')
                    , ISNULL(WPO.OriginCountry, '')
                    , ISNULL(WPO.DestinationCountry, '')
                    , ISNULL(WPO.Vessel, '')
                    , WPO.VesselDate
                    , ISNULL(WPO.PlaceOfLoading, '')
                    , ISNULL(WPO.PlaceOfDischarge, '')
                    , ISNULL(WPO.PlaceofDelivery, '')
                    , ISNULL(WPO.IncoTerms, '')
                    , ISNULL(WPO.Pmtterm, '')
                    , ISNULL(WPO.TransMethod, '')
                    , ISNULL(WPO.TermsNote, '')
                    , ISNULL(WPO.Signatory, '')
                    , ISNULL(WPO.PlaceofIssue, '')
                    , CAST(WPO.Notes AS NVARCHAR(255))
                    , ISNULL(WPO.EffectiveDate, GETDATE())
                    , WPO.LoadingDate
                    , ISNULL(WPO.ReasonCode, '')
                    , ISNULL(WPO.HUdef01, '')
                    , ISNULL(WPO.HUdef02, '')
                    , ISNULL(WPO.HUdef03, '')
                    , ISNULL(WPO.HUdef04, '')
                    , ISNULL(WPO.HUdef05, '')
                    , WPO.HUdef06
                    , WPO.HUdef07
                    , ISNULL(WPO.HUdef08, '')
                    , ISNULL(WPO.HUdef09, '')
                    , ISNULL(WPO.HUdef10, '')
                    , ISNULL(WPO.xdockpokey, '')
                    , @c_Username
                    , @c_Username
               FROM dbo.SCE_DL_PO_STG WPO WITH (NOLOCK)
               WHERE WPO.RowRefNo = @n_RowRefNo;

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3;
                  ROLLBACK TRAN;
                  GOTO QUIT;
               END;
            END;
         END;

         IF EXISTS (
         SELECT 1
         FROM dbo.V_PODetail WITH (NOLOCK)
         WHERE POKey = @c_POkey
         )
         BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 100001;
            SET @c_ErrMsg = 'Unable to get a new PO Key from nspg_getkey.';
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         SET @n_SUMQty = 0;
         SET @n_iNo = 0;
         SET @c_HUDF01 = N'';
         SET @c_HUDF02 = N'';
         SET @n_SumDUDF01 = 0;
         SET @n_SumDUDF02 = 0;

         DECLARE C_PO_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , ISNULL(RTRIM(Sku), '')
              , ISNULL(QtyOrdered, 0)
              , ISNULL(LTRIM(RTRIM(UOM)), '')
              , ISNULL(RTRIM(Packkey), '')
              , ISNULL(RTRIM(DUdef01), '')
              , ISNULL(RTRIM(DUdef02), '')
         FROM dbo.SCE_DL_PO_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1'
         AND   StorerKey     = @c_Storerkey
         AND   ExternPOKey   = @c_ExternPOkey;


         OPEN C_PO_DET;
         FETCH NEXT FROM C_PO_DET
         INTO @n_RowRefNo
            , @c_SKU
            , @n_Qty
            , @c_UOM
            , @c_Packkey
            , @c_DUDF01
            , @c_DUDF02;

         WHILE @@FETCH_STATUS = 0
         BEGIN

            IF @c_Packkey = ''
            BEGIN --Get PackKey IF Packkey is null     
               SELECT @c_Packkey = PACKKey
               FROM dbo.V_SKU WITH (NOLOCK)
               WHERE StorerKey = @c_Storerkey
               AND   Sku         = @c_SKU;

               IF @b_Debug = 1
               BEGIN
                  SELECT '@c_Packkey is : ' + @c_UOM;
               END;
            END;

            IF @c_UOM = ''
            BEGIN
               SELECT @c_UOM = PackUOM3
               FROM dbo.V_PACK WITH (NOLOCK)
               WHERE PackKey = @c_Packkey;

               IF @b_Debug = 1
               BEGIN
                  SELECT '@c_UOM is : ' + @c_UOM;
               END;
            END;


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

            SET @n_SUMQty += @n_GetQty;
            SET @n_iNo += 1;

            IF @c_InParm4 = 1
            BEGIN
               SET @n_SumDUDF01 += CAST((CAST(@c_DUDF01 AS FLOAT) * (@n_GetQty / NULLIF(@n_CaseCnt, 0))) AS NVARCHAR(20)); --CS13  
               SET @n_SumDUDF02 += CAST((CAST(@c_DUDF02 AS FLOAT) * (@n_GetQty / NULLIF(@n_CaseCnt, 0))) AS NVARCHAR(20)); --CS13  
            END;

            SELECT @c_SKUDesc = DESCR
            FROM dbo.V_SKU WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey
            AND   Sku         = @c_SKU;

            IF @b_Debug = 1
            BEGIN
               SELECT '@c_POkey : ' + @c_POkey;
               SELECT '@SKU DESCR : ' + @c_SKUDesc;
            END;

            INSERT INTO dbo.PODETAIL
            (
               POKey
             , POLineNumber
             , ExternPOKey
             , PODetailKey
             , ExternLineNo
             , StorerKey
             , MarksContainer
             , Sku
             , SKUDescription
             , AltSku
             , QtyOrdered
             , PackKey
             , UnitPrice
             , UOM
             , Facility
             , ToId
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
             , Notes
             , AddWho
             , EditWho
            )
            SELECT @c_POkey
                 , CAST(FORMAT(@n_iNo, 'D5') AS NVARCHAR(5))
                 , ISNULL(@c_ExternPOkey, '')
                 , ISNULL(WPO.PODetailKey, '')
                 , ISNULL(WPO.ExternLineNo, '')
                 , @c_Storerkey
                 , ISNULL(WPO.MarksContainer, '')
                 , ISNULL(@c_SKU, '')
                 , ISNULL(@c_SKUDesc, '')
                 , ISNULL(WPO.ALTSKU, '')
                 , ISNULL(@n_GetQty, 0)
                 , @c_Packkey
                 , ISNULL(WPO.UnitPrice, 0)
                 , @c_UOM
                 , ISNULL(WPO.Facility, '')
                 , ISNULL(WPO.ToID, '')
                 , ISNULL(WPO.Lottable01, '')
                 , ISNULL(WPO.Lottable02, '')
                 , ISNULL(WPO.Lottable03, '')
                 , WPO.Lottable04
                 , WPO.Lottable05
                 , ISNULL(WPO.Lottable06, '')
                 , ISNULL(WPO.Lottable07, '')
                 , ISNULL(WPO.Lottable08, '')
                 , ISNULL(WPO.Lottable09, '')
                 , ISNULL(WPO.Lottable10, '')
                 , ISNULL(WPO.Lottable11, '')
                 , ISNULL(WPO.Lottable12, '')
                 , WPO.Lottable13
                 , WPO.Lottable14
                 , WPO.Lottable15
                 , ISNULL(WPO.DUdef01, '')
                 , ISNULL(WPO.DUdef02, '')
                 , ISNULL(WPO.DUdef03, '')
                 , ISNULL(WPO.DUdef04, '')
                 , ISNULL(WPO.DUdef05, '')
                 , WPO.DUdef06
                 , WPO.DUdef07
                 , ISNULL(WPO.DUdef08, '')
                 , ISNULL(WPO.DUdef09, '')
                 , ISNULL(WPO.DUdef10, '')
                 , ISNULL(WPO.Channel, '')
                 , ISNULL(WPO.DNotes, '')
                 , @c_Username
                 , @c_Username
            FROM dbo.SCE_DL_PO_STG AS WPO WITH (NOLOCK)
            WHERE WPO.RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            UPDATE dbo.SCE_DL_PO_STG WITH (ROWLOCK)
            SET STG_Status = '9'
            WHERE RowRefNo = @n_RowRefNo;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;

            FETCH NEXT FROM C_PO_DET
            INTO @n_RowRefNo
               , @c_SKU
               , @n_Qty
               , @c_UOM
               , @c_Packkey
               , @c_DUDF01
               , @c_DUDF02; --CS13     
         END;

         CLOSE C_PO_DET;
         DEALLOCATE C_PO_DET;

         IF @c_InParm4 = 1
         BEGIN
            UPDATE dbo.PO WITH (ROWLOCK)
            SET OpenQty = @n_SUMQty
              , UserDefine01 = CAST(@n_SumDUDF01 AS NVARCHAR(30))
              , UserDefine02 = CAST(@n_SumDUDF02 AS NVARCHAR(30))
              , EditDate = GETDATE()
            WHERE POKey = @c_POkey;

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3;
               ROLLBACK TRAN;
               GOTO QUIT;
            END;
         END;

         WHILE @@TRANCOUNT > 0
         COMMIT TRAN;

         FETCH NEXT FROM C_PO_HDR
         INTO @c_ExternPOkey
            , @c_Storerkey;
      END;

      CLOSE C_PO_HDR;
      DEALLOCATE C_PO_HDR;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_PO_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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