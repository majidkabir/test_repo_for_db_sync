SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_ITRN2]
AS
SELECT CaptureTime            = Getdate(),
       StorerKey              = ITrn.StorerKey,
       Sku                    = ITrn.Sku,
       ITrnKey                = ITrn.ITrnKey,
       TranType               = ITrn.TranType,
       Descr                  = Sku.Descr,
       FromFacility           = FrLoc.Facility,
       FromLoc                = ITrn.FromLoc,
       ToFacility             = ToLoc.Facility,
       ToLoc                  = ITrn.ToLoc,
       SourceKey              = ITrn.SourceKey,
       SourceType             = CASE WHEN LEFT(ITrn.SourceType,3)='ntr' THEN SUBSTRING(ITrn.SourceType,4,30) ELSE ITrn.SourceType END,
       Lottable02_LotNo       = LotAttribute.Lottable02,
       Lottable04_ExpiryDate  = LotAttribute.Lottable04,
       Lottable05_ReceiptDate = LotAttribute.Lottable05,
       Qty                    = ITrn.Qty,
       AddDate                = ITrn.AddDate,

       ReceiptKey             = Receipt.ReceiptKey,
       RecType                = Receipt.RecType,
       ExternReceiptKey       = Receipt.ExternReceiptKey,
       WarehouseReference     = Receipt.WarehouseReference,
       ReceiptCondition       = ReceiptDetail.ConditionCode,
       SubReasonCode          = ReceiptDetail.SubReasonCode,

       OrderKey               = PickDetail.OrderKey,
       OrderType              = Orders.Type,
       ExternOrderKey         = Orders.ExternOrderKey,
       BuyerPO                = Orders.BuyerPO,
       CustomerName           = CASE WHEN ISNULL(Orders.C_Company,'')='' THEN Orders.ConsigneeKey ELSE Orders.C_Company END,
       OrderLineNumber        = PickDetail.OrderLineNumber,

       KitKey                 = Kit.KitKey,
       ExternKitKey           = Kit.ExternKitKey,

       IQC_Key                = InventoryQC.QC_Key,
       IQC_Reason             = InventoryQC.Reason,
       IQC_RefNo              = InventoryQC.Refno,

       AdjustmentKey          = Adjustment.AdjustmentKey,
       Adj_RefNo              = Adjustment.CustomerRefNo,
       AdjustmentType         = Adjustment.AdjustmentType,
       Adj_Remarks            = Adjustment.Remarks,

       TransferKey            = Transfer.TransferKey,
       Tfr_RefNo              = Transfer.CustomerRefNo,
       Tfr_ReasonCode         = Transfer.ReasonCode,
       Tfr_Remarks            = Transfer.Remarks

FROM      dbo.ITrn          ITrn          (nolock)
LEFT JOIN dbo.Sku           Sku           (nolock)
       ON ITrn.StorerKey = Sku.StorerKey and ITrn.sku = Sku.sku
LEFT JOIN dbo.Loc           FrLoc         (nolock)
       ON ITrn.FromLoc = FrLoc.Loc
LEFT JOIN dbo.Loc           ToLoc         (nolock)
       ON ITrn.ToLoc = ToLoc.Loc
LEFT JOIN dbo.LotAttribute  LotAttribute  (nolock)
       ON ITrn.Lot = LotAttribute.Lot
      AND ITrn.Storerkey = LotAttribute.Storerkey
      AND ITrn.Sku = LotAttribute.Sku

LEFT JOIN dbo.Receipt Receipt (nolock)
       ON LEFT(ITrn.SourceKey,10) = Receipt.ReceiptKey       AND ITrn.SourceType = 'ntrReceiptDetailUpdate'
LEFT JOIN dbo.ReceiptDetail ReceiptDetail (nolock)
       ON LEFT(ITrn.SourceKey,10) = ReceiptDetail.ReceiptKey  AND  RIGHT(ITrn.SourceKey,5) = ReceiptDetail.ReceiptLineNumber AND ITrn.SourceType = 'ntrReceiptDetailUpdate'    

LEFT JOIN dbo.PickDetail    PickDetail (nolock)
       ON ITrn.SourceKey = PickDetail.pickdetailkey          AND ITrn.SourceType = 'ntrPickDetailUpdate'
LEFT JOIN dbo.Orders        Orders (nolock)
       ON PickDetail.OrderKey = Orders.orderkey              AND ITrn.SourceType = 'ntrPickDetailUpdate'

LEFT JOIN dbo.Kit           Kit  (nolock)
       ON LEFT(ITrn.SourceKey,10) = Kit.kitkey               AND ITrn.SourceType in ('ntrKitDetailAdd', 'ntrKitDetailUpdate')

LEFT JOIN dbo.InventoryQC   InventoryQC (nolock)
       ON LEFT(ITrn.SourceKey,10) = InventoryQC.QC_Key       AND ITrn.SourceType = 'ntrInventoryQCDetailUpdate'

LEFT JOIN dbo.Adjustment    Adjustment (nolock)
       ON LEFT(ITrn.SourceKey,10) = Adjustment.AdjustmentKey AND ITrn.SourceType  in ('ntrAdjustmentDetailAdd', 'ntrAdjustmentDetailUpdate')

LEFT JOIN dbo.Transfer      Transfer (nolock)
       ON LEFT(ITrn.SourceKey,10) = Transfer.TransferKey     AND ITrn.SourceType = 'ntrTransferDetailUpdate'

GO