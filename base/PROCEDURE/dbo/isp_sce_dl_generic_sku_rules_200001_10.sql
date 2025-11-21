SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SKU_RULES_200001_10             */
/* Creation Date: 12-Jan-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update into SKU target table             */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore SKU              */
/*                           @c_InParm1 =  '1'  SKU update is allow     */
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
/* 08-Mar-2023  WLChooi   1.2   JSM-134282 - Do not update column if    */
/*                              blank (WL01)                            */
/* 08-Mar-2023  WLChooi   1.2   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SKU_RULES_200001_10] (
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

   DECLARE @n_RowRefNo  INT
         , @c_Storerkey NVARCHAR(15)
         , @c_SKU       NVARCHAR(20)
         , @c_ttlMsg    NVARCHAR(250);

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

   DECLARE C_SKU_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(StorerKey), '')
        , ISNULL(RTRIM(Sku), '')
   FROM dbo.SCE_DL_SKU_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status    = '1'
   GROUP BY ISNULL(RTRIM(StorerKey), '')
          , ISNULL(RTRIM(Sku), '');

   OPEN C_SKU_HDR;
   FETCH NEXT FROM C_SKU_HDR
   INTO @c_Storerkey
      , @c_SKU;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRAN;

      SET @c_ttlMsg = N'';

      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_SKU_STG WITH (NOLOCK)
      WHERE STG_BatchNo                = @n_BatchNo
      AND   STG_Status                   = '1'
      AND   ISNULL(RTRIM(StorerKey), '') = @c_Storerkey
      AND   ISNULL(RTRIM(Sku), '')       = @c_SKU
      ORDER BY STG_SeqNo ASC;

      IF @c_InParm1 = '1'
      BEGIN
         IF EXISTS (
         SELECT 1
         FROM dbo.V_SKU WITH (NOLOCK)
         WHERE StorerKey = @c_Storerkey
         AND   Sku         = @c_SKU
         )
         BEGIN
            UPDATE S WITH (ROWLOCK)
            SET S.DESCR = ISNULL(STG.DESCR, S.DESCR)
              , S.SUSR1 = ISNULL(STG.SUSR1, S.SUSR1)
              , S.SUSR2 = ISNULL(STG.SUSR2, S.SUSR2)
              , S.SUSR3 = ISNULL(STG.SUSR3, S.SUSR3)
              , S.SUSR4 = ISNULL(STG.SUSR4, S.SUSR4)
              , S.SUSR5 = ISNULL(STG.SUSR5, S.SUSR5)
              , S.MANUFACTURERSKU = ISNULL(STG.MANUFACTURERSKU, S.MANUFACTURERSKU)
              , S.RETAILSKU = ISNULL(STG.RETAILSKU, S.RETAILSKU)
              , S.ALTSKU = ISNULL(STG.ALTSKU, S.ALTSKU)
              , S.PACKKey = ISNULL(STG.PACKKey, S.PACKKey)
              , S.STDGROSSWGT = ISNULL(STG.STDGROSSWGT, S.STDGROSSWGT)
              , S.STDNETWGT = ISNULL(STG.STDNETWGT, S.STDNETWGT)
              , S.STDCUBE = ISNULL(STG.STDCUBE, S.STDCUBE)
              , S.TARE = ISNULL(STG.TARE, S.TARE)
              , S.CLASS = ISNULL(STG.CLASS, S.CLASS)
              , S.ACTIVE = ISNULL(STG.ACTIVE, '1')
              , S.SKUGROUP = ISNULL(STG.SKUGROUP, S.SKUGROUP)
              , S.Tariffkey = ISNULL(STG.Tariffkey, S.Tariffkey)
              , S.BUSR1 = ISNULL(STG.BUSR1, S.BUSR1)
              , S.BUSR2 = ISNULL(STG.BUSR2, S.BUSR2)
              , S.BUSR3 = ISNULL(STG.BUSR3, S.BUSR3)
              , S.BUSR4 = ISNULL(STG.BUSR4, S.BUSR4)
              , S.BUSR5 = ISNULL(STG.BUSR5, S.BUSR5)
              , S.LOTTABLE01LABEL = ISNULL(STG.LOTTABLE01LABEL, S.LOTTABLE01LABEL)
              , S.LOTTABLE02LABEL = ISNULL(STG.LOTTABLE02LABEL, S.LOTTABLE02LABEL)
              , S.LOTTABLE03LABEL = ISNULL(STG.LOTTABLE03LABEL, S.LOTTABLE03LABEL)
              , S.LOTTABLE04LABEL = ISNULL(STG.LOTTABLE04LABEL, S.LOTTABLE04LABEL)
              , S.LOTTABLE05LABEL = ISNULL(STG.LOTTABLE05LABEL, S.LOTTABLE05LABEL)
              , S.LOTTABLE06LABEL = ISNULL(STG.LOTTABLE06LABEL, S.LOTTABLE06LABEL)
              , S.LOTTABLE07LABEL = ISNULL(STG.LOTTABLE07LABEL, S.LOTTABLE07LABEL)
              , S.LOTTABLE08LABEL = ISNULL(STG.LOTTABLE08LABEL, S.LOTTABLE08LABEL)
              , S.LOTTABLE09LABEL = ISNULL(STG.LOTTABLE09LABEL, S.LOTTABLE09LABEL)
              , S.LOTTABLE10LABEL = ISNULL(STG.LOTTABLE10LABEL, S.LOTTABLE10LABEL)
              , S.LOTTABLE11LABEL = ISNULL(STG.LOTTABLE11LABEL, S.LOTTABLE11LABEL)
              , S.LOTTABLE12LABEL = ISNULL(STG.LOTTABLE12LABEL, S.LOTTABLE12LABEL)
              , S.LOTTABLE13LABEL = ISNULL(STG.LOTTABLE13LABEL, S.LOTTABLE13LABEL)
              , S.LOTTABLE14LABEL = ISNULL(STG.LOTTABLE14LABEL, S.LOTTABLE14LABEL)
              , S.LOTTABLE15LABEL = ISNULL(STG.LOTTABLE15LABEL, S.LOTTABLE15LABEL)
              , S.NOTES1 = ISNULL(CAST(STG.NOTES1 AS NVARCHAR(255)), S.NOTES1)
              , S.NOTES2 = ISNULL(CAST(STG.NOTES2 AS NVARCHAR(255)), S.NOTES2)
              , S.PickCode = ISNULL(STG.PickCode, S.PickCode)
              , S.StrategyKey = ISNULL(STG.StrategyKey, S.StrategyKey)
              , S.CartonGroup = ISNULL(STG.CartonGroup, S.CartonGroup)
              , S.PutCode = ISNULL(STG.PutCode, S.PutCode)
              , S.PutawayLoc = ISNULL(STG.PutawayLoc, S.PutawayLoc)
              , S.PutawayZone = ISNULL(STG.PutawayZone, S.PutawayZone)
              , S.InnerPack = ISNULL(STG.InnerPack, S.InnerPack)
              , S.[Cube] = ISNULL(STG.[Cube], S.[Cube])
              , S.GrossWgt = ISNULL(STG.GrossWgt, S.GrossWgt)
              , S.NetWgt = ISNULL(STG.NetWgt, S.NetWgt)
              , S.ABC = ISNULL(STG.ABC, S.ABC)
              , S.CycleCountFrequency = STG.CycleCountFrequency
              , S.LastCycleCount = STG.LastCycleCount
              , S.ReorderPoint = STG.ReorderPoint
              , S.ReorderQty = STG.ReorderQty
              , S.StdOrderCost = STG.StdOrderCost
              , S.CarryCost = STG.CarryCost
              , S.Price = ISNULL(STG.Price, S.Price)
              , S.Cost = ISNULL(STG.Cost, S.Cost)
              , S.ReceiptHoldCode = ISNULL(STG.ReceiptHoldCode, S.ReceiptHoldCode)
              , S.ReceiptInspectionLoc = ISNULL(STG.ReceiptInspectionLoc, S.ReceiptInspectionLoc)
              , S.OnReceiptCopyPackkey = ISNULL(STG.OnReceiptCopyPackkey, '0')
              , S.IOFlag = STG.IOFlag
              , S.TareWeight = ISNULL(STG.TareWeight, 0)
              , S.LotxIdDetailOtherlabel1 = ISNULL(STG.LotxIdDetailOtherlabel1, 'Ser#')
              , S.LotxIdDetailOtherlabel2 = ISNULL(STG.LotxIdDetailOtherlabel2, 'CSID')
              , S.LotxIdDetailOtherlabel3 = ISNULL(STG.LotxIdDetailOtherlabel3, 'Other')
              , S.AvgCaseWeight = ISNULL(STG.AvgCaseWeight, 0)
              , S.TolerancePct = ISNULL(STG.TolerancePct, 0)
              , S.SkuStatus = ISNULL(STG.SkuStatus, 'Active')
              , S.Length = ISNULL(STG.Length, S.Length)
              , S.Width = ISNULL(STG.Width, S.Width)
              , S.Height = ISNULL(STG.Height, S.Height)
              , S.weight = ISNULL(STG.weight, S.weight)
              , S.itemclass = ISNULL(STG.itemclass, S.itemclass)
              , S.ShelfLife = ISNULL(STG.ShelfLife, S.ShelfLife)
              , S.Facility = ISNULL(STG.Facility, S.Facility)
              , S.BUSR6 = ISNULL(STG.BUSR6, S.BUSR6)
              , S.BUSR7 = ISNULL(STG.BUSR7, S.BUSR7)
              , S.BUSR8 = ISNULL(STG.BUSR8, S.BUSR8)
              , S.BUSR9 = ISNULL(STG.BUSR9, S.BUSR9)
              , S.BUSR10 = ISNULL(STG.BUSR10, S.BUSR10)
              , S.ReturnLoc = ISNULL(STG.ReturnLoc, S.ReturnLoc)
              , S.ReceiptLoc = ISNULL(STG.ReceiptLoc, S.ReceiptLoc)
              , S.XDockReceiptLoc = STG.XDockReceiptLoc
              , S.PrePackIndicator = ISNULL(STG.PrePackIndicator, S.PrePackIndicator)
              , S.PackQtyIndicator = ISNULL(STG.PackQtyIndicator, S.PackQtyIndicator)
              , S.StackFactor = ISNULL(STG.StackFactor, 0)
              , S.IVAS = ISNULL(STG.IVAS, S.IVAS)
              , S.OVAS = ISNULL(STG.OVAS, S.OVAS)
              , S.Style = ISNULL(STG.Style, S.Style)
              , S.Color = ISNULL(STG.Color, S.Color)
              , S.[Size] = ISNULL(STG.[Size], S.[Size])
              , S.Measurement = ISNULL(STG.Measurement, S.Measurement)
              , S.HazardousFlag = CASE WHEN ISNULL(STG.HazardousFlag,'') = '' THEN S.HazardousFlag ELSE STG.HazardousFlag END   --WL01
              , S.TemperatureFlag = CASE WHEN ISNULL(STG.TemperatureFlag,'') = '' THEN S.TemperatureFlag ELSE STG.TemperatureFlag END   --WL01
              , S.ProductModel = CASE WHEN ISNULL(STG.ProductModel,'') = '' THEN S.ProductModel ELSE STG.ProductModel END   --WL01
              , S.CtnPickQty = CASE WHEN ISNULL(STG.CtnPickQty,0) = 0 THEN S.CtnPickQty ELSE STG.CtnPickQty END   --WL01
              , S.CountryOfOrigin = ISNULL(STG.CountryOfOrigin, S.CountryOfOrigin)
              , S.IB_UOM = CASE WHEN ISNULL(STG.IB_UOM,'') = '' THEN S.IB_UOM ELSE STG.IB_UOM END   --WL01
              , S.IB_RPT_UOM = CASE WHEN ISNULL(STG.IB_RPT_UOM,'') = '' THEN S.IB_RPT_UOM ELSE STG.IB_RPT_UOM END   --WL01
              , S.OB_UOM = CASE WHEN ISNULL(STG.OB_UOM,'') = '' THEN S.OB_UOM ELSE STG.OB_UOM END   --WL01
              , S.OB_RPT_UOM = CASE WHEN ISNULL(STG.OB_RPT_UOM,'') = '' THEN S.OB_RPT_UOM ELSE STG.OB_RPT_UOM END   --WL01
              , S.ABCPL = CASE WHEN ISNULL(STG.ABCPL,'B') = 'B' THEN S.ABCPL ELSE STG.ABCPL END   --WL01
              , S.ABCCS = CASE WHEN ISNULL(STG.ABCCS,'B') = 'B' THEN S.ABCCS ELSE STG.ABCCS END   --WL01
              , S.ABCEA = CASE WHEN ISNULL(STG.ABCEA,'B') = 'B' THEN S.ABCEA ELSE STG.ABCEA END   --WL01
              , S.DisableABCCalc = CASE WHEN ISNULL(STG.DisableABCCalc,'N') = 'N' THEN S.DisableABCCalc ELSE STG.DisableABCCalc END   --WL01
              , S.ABCPeriod = CASE WHEN ISNULL(STG.ABCPeriod,'') = '' THEN S.ABCPeriod ELSE STG.ABCPeriod END   --WL01
              , S.ABCStorerkey = CASE WHEN ISNULL(STG.ABCStorerkey,'') = '' THEN S.ABCStorerkey ELSE STG.ABCStorerkey END   --WL01
              , S.ABCSku = CASE WHEN ISNULL(STG.ABCSku,'') = '' THEN S.ABCSku ELSE STG.ABCSku END   --WL01
              , S.OldStorerkey = CASE WHEN ISNULL(STG.OldStorerkey,'') = '' THEN S.OldStorerkey ELSE STG.OldStorerkey END   --WL01
              , S.OldSku = CASE WHEN ISNULL(STG.OldSku,'') = '' THEN S.OldSku ELSE STG.OldSku END   --WL01
              , S.OTM_SKUGroup = CASE WHEN ISNULL(STG.OTM_SKUGroup,'') = '' THEN S.OTM_SKUGroup ELSE STG.OTM_SKUGroup END   --WL01
              , S.LottableCode = CASE WHEN ISNULL(STG.LottableCode,'') = '' THEN S.LottableCode ELSE STG.LottableCode END   --WL01
              , S.Pressure = CASE WHEN ISNULL(STG.Pressure,'0') = '0' THEN S.Pressure ELSE STG.Pressure END   --WL01
              , S.SerialNoCapture = CASE WHEN ISNULL(STG.SerialNoCapture,'') = '' THEN S.SerialNoCapture ELSE STG.SerialNoCapture END   --WL01
              , S.EditWho = @c_Username
              , S.EditDate = GETDATE()
            FROM dbo.SCE_DL_SKU_STG STG WITH (NOLOCK)
            JOIN dbo.SKU            S
            ON (
                STG.StorerKey = S.StorerKey
            AND STG.Sku   = S.Sku
            )
            WHERE STG.RowRefNo = @n_RowRefNo;
         END;
         ELSE
         BEGIN
            INSERT INTO dbo.SKU
            (
               StorerKey
             , Sku
             , DESCR
             , SUSR1
             , SUSR2
             , SUSR3
             , SUSR4
             , SUSR5
             , MANUFACTURERSKU
             , RETAILSKU
             , ALTSKU
             , PACKKey
             , STDGROSSWGT
             , STDNETWGT
             , STDCUBE
             , TARE
             , CLASS
             , ACTIVE
             , SKUGROUP
             , Tariffkey
             , BUSR1
             , BUSR2
             , BUSR3
             , BUSR4
             , BUSR5
             , LOTTABLE01LABEL
             , LOTTABLE02LABEL
             , LOTTABLE03LABEL
             , LOTTABLE04LABEL
             , LOTTABLE05LABEL
             , LOTTABLE06LABEL
             , LOTTABLE07LABEL
             , LOTTABLE08LABEL
             , LOTTABLE09LABEL
             , LOTTABLE10LABEL
             , LOTTABLE11LABEL
             , LOTTABLE12LABEL
             , LOTTABLE13LABEL
             , LOTTABLE14LABEL
             , LOTTABLE15LABEL
             , NOTES1
             , NOTES2
             , PickCode
             , StrategyKey
             , CartonGroup
             , PutCode
             , PutawayLoc
             , PutawayZone
             , InnerPack
             , [Cube]
             , GrossWgt
             , NetWgt
             , ABC
             , CycleCountFrequency
             , LastCycleCount
             , ReorderPoint
             , ReorderQty
             , StdOrderCost
             , CarryCost
             , Price
             , Cost
             , ReceiptHoldCode
             , ReceiptInspectionLoc
             , OnReceiptCopyPackkey
             , IOFlag
             , TareWeight
             , LotxIdDetailOtherlabel1
             , LotxIdDetailOtherlabel2
             , LotxIdDetailOtherlabel3
             , AvgCaseWeight
             , TolerancePct
             , SkuStatus
             , Length
             , Width
             , Height
             , weight
             , itemclass
             , ShelfLife
             , Facility
             , BUSR6
             , BUSR7
             , BUSR8
             , BUSR9
             , BUSR10
             , ReturnLoc
             , ReceiptLoc
             , XDockReceiptLoc
             , PrePackIndicator
             , PackQtyIndicator
             , StackFactor
             , IVAS
             , OVAS
             , Style
             , Color
             , [Size]
             , Measurement
             , HazardousFlag
             , TemperatureFlag
             , ProductModel
             , CtnPickQty
             , CountryOfOrigin
             , IB_UOM
             , IB_RPT_UOM
             , OB_UOM
             , OB_RPT_UOM
             , ABCPL
             , ABCCS
             , ABCEA
             , DisableABCCalc
             , ABCPeriod
             , ABCStorerkey
             , ABCSku
             , OldStorerkey
             , OldSku
             , AddWho
             , EditWho
             , OTM_SKUGroup
             , LottableCode
             , Pressure
             , SerialNoCapture
            )
            SELECT @c_Storerkey
                 , @c_SKU
                 , DESCR
                 , SUSR1
                 , SUSR2
                 , ISNULL(SUSR3, '')
                 , SUSR4
                 , SUSR5
                 , ISNULL(MANUFACTURERSKU, '')
                 , ISNULL(RETAILSKU, '')
                 , ISNULL(ALTSKU, '')
                 , ISNULL(PACKKey, 'STD')
                 , ISNULL(ROUND(STDGROSSWGT, 7), 0)
                 , ISNULL(ROUND(STDNETWGT, 7), 0)
                 , ISNULL(ROUND(STDCUBE, 7), 0)
                 , ISNULL(TARE, 0)
                 , ISNULL(CLASS, 'STD')
                 , ISNULL(ACTIVE, '1')
                 , ISNULL(SKUGROUP, 'STD')
                 , ISNULL(Tariffkey, 'XXXXXXXXXX')
                 , BUSR1
                 , BUSR2
                 , BUSR3
                 , BUSR4
                 , BUSR5
                 , ISNULL(LOTTABLE01LABEL, '')
                 , ISNULL(LOTTABLE02LABEL, '')
                 , ISNULL(LOTTABLE03LABEL, '')
                 , ISNULL(LOTTABLE04LABEL, '')
                 , ISNULL(LOTTABLE05LABEL, '')
                 , ISNULL(LOTTABLE06LABEL, '')
                 , ISNULL(LOTTABLE07LABEL, '')
                 , ISNULL(LOTTABLE08LABEL, '')
                 , ISNULL(LOTTABLE09LABEL, '')
                 , ISNULL(LOTTABLE10LABEL, '')
                 , ISNULL(LOTTABLE11LABEL, '')
                 , ISNULL(LOTTABLE12LABEL, '')
                 , ISNULL(LOTTABLE13LABEL, '')
                 , ISNULL(LOTTABLE14LABEL, '')
                 , ISNULL(LOTTABLE15LABEL, '')
                 , CAST(NOTES1 AS NVARCHAR(255))
                 , CAST(NOTES2 AS NVARCHAR(255))
                 , ISNULL(PickCode, 'NSPRPFIFO')
                 , ISNULL(StrategyKey, 'STD')
                 , ISNULL(CartonGroup, 'STD')
                 , ISNULL(PutCode, 'NSPPASTD')
                 , ISNULL(PutawayLoc, 'UNKNOWN')
                 , ISNULL(PutawayZone, 'BULK')
                 , ISNULL(InnerPack, 0)
                 , ISNULL([Cube], 0)
                 , ISNULL(GrossWgt, 0)
                 , ISNULL(NetWgt, 0)
                 , ISNULL(ABC, 'B')
                 , CycleCountFrequency
                 , LastCycleCount
                 , ReorderPoint
                 , ReorderQty
                 , StdOrderCost
                 , CarryCost
                 , Price
                 , Cost
                 , ISNULL(ReceiptHoldCode, '')
                 , ISNULL(ReceiptInspectionLoc, 'QC')
                 , ISNULL(OnReceiptCopyPackkey, '0')
                 , IOFlag
                 , ISNULL(TareWeight, 0)
                 , ISNULL(LotxIdDetailOtherlabel1, 'Ser#')
                 , ISNULL(LotxIdDetailOtherlabel2, 'CSID')
                 , ISNULL(LotxIdDetailOtherlabel3, 'Other')
                 , ISNULL(AvgCaseWeight, 0)
                 , ISNULL(TolerancePct, 0)
                 , ISNULL(SkuStatus, 'Active')
                 , ISNULL(Length, 0)
                 , ISNULL(Width, 0)
                 , ISNULL(Height, 0)
                 , ISNULL(weight, 0)
                 , ISNULL(itemclass, '')
                 , ISNULL(ShelfLife, 0)
                 , Facility
                 , ISNULL(BUSR6, '')
                 , ISNULL(BUSR7, '')
                 , ISNULL(BUSR8, '')
                 , ISNULL(BUSR9, '')
                 , ISNULL(BUSR10, '')
                 , ReturnLoc
                 , ReceiptLoc
                 , XDockReceiptLoc
                 , ISNULL(PrePackIndicator, '')
                 , ISNULL(PackQtyIndicator, 0)
                 , ISNULL(StackFactor, 0)
                 , ISNULL(IVAS, '')
                 , ISNULL(OVAS, '')
                 , ISNULL(Style, '')
                 , ISNULL(Color, '')
                 , ISNULL([Size], '')
                 , ISNULL(Measurement, '')
                 , ISNULL(STG.HazardousFlag, '')
                 , ISNULL(STG.TemperatureFlag, '')
                 , ISNULL(STG.ProductModel, '')
                 , ISNULL(STG.CtnPickQty, 0)
                 , ISNULL(STG.CountryOfOrigin, '')
                 , ISNULL(STG.IB_UOM, '')
                 , ISNULL(STG.IB_RPT_UOM, '')
                 , ISNULL(STG.OB_UOM, '')
                 , ISNULL(STG.OB_RPT_UOM, '')
                 , ISNULL(STG.ABCPL, 'B')
                 , ISNULL(STG.ABCCS, 'B')
                 , ISNULL(STG.ABCEA, 'B')
                 , ISNULL(STG.DisableABCCalc, 'N')
                 , ISNULL(STG.ABCPeriod, 0)
                 , ISNULL(STG.ABCStorerkey, '')
                 , ISNULL(STG.ABCSku, '')
                 , ISNULL(STG.OldStorerkey, '')
                 , ISNULL(STG.OldSku, '')
                 , @c_Username
                 , @c_Username
                 , STG.OTM_SKUGroup
                 , ISNULL(STG.LottableCode, '')
                 , ISNULL(STG.Pressure, '0')
                 , ISNULL(SerialNoCapture, '')
            FROM dbo.SCE_DL_SKU_STG STG WITH (NOLOCK)
            WHERE STG.RowRefNo = @n_RowRefNo;
         END;
      END;


      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      UPDATE dbo.SCE_DL_SKU_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo;

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3;
         ROLLBACK TRAN;
         GOTO QUIT;
      END;

      WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

      FETCH NEXT FROM C_SKU_HDR
      INTO @c_Storerkey
         , @c_SKU;

   END;

   CLOSE C_SKU_HDR;
   DEALLOCATE C_SKU_HDR;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SKU_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
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