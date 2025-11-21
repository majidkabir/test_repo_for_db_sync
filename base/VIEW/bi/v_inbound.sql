SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_Inbound]
AS
SELECT        r.ReceiptKey, r.ExternReceiptKey, r.ReceiptGroup, r.StorerKey, r.ReceiptDate, r.POKey, r.CarrierKey, r.CarrierName, r.CarrierAddress1, r.CarrierAddress2, r.CarrierCity, r.CarrierState, r.CarrierZip, r.CarrierReference,
                         r.WarehouseReference, r.OriginCountry, r.DestinationCountry, r.VehicleNumber, r.VehicleDate, r.PlaceOfLoading, r.PlaceOfDischarge, r.PlaceofDelivery, r.IncoTerms, r.TermsNote, r.ContainerKey, r.Signatory, r.PlaceofIssue,
                         r.OpenQty, r.Status, r.Notes, r.EffectiveDate, r.AddDate, r.AddWho, r.EditDate, r.EditWho, r.TrafficCop, r.ArchiveCop, r.ContainerType, r.ContainerQty, r.BilledContainerQty, r.RECType, r.ASNStatus, r.ASNReason, r.Facility,
                         r.MBOLKey, r.Appointment_No, r.LoadKey, r.xDockFlag, r.UserDefine01, r.PROCESSTYPE, r.UserDefine02, r.UserDefine03, r.UserDefine04, r.UserDefine05, r.UserDefine06, r.UserDefine07, r.UserDefine08, r.UserDefine09,
                         r.UserDefine10, r.DOCTYPE, r.RoutingTool, r.CTNTYPE1, r.CTNTYPE2, r.CTNTYPE3, r.CTNTYPE4, r.CTNTYPE5, r.CTNTYPE6, r.CTNTYPE7, r.CTNTYPE8, r.CTNTYPE9, r.CTNTYPE10, r.PACKTYPE1, r.PACKTYPE2, r.PACKTYPE3,
                         r.PACKTYPE4, r.PACKTYPE5, r.PACKTYPE6, r.PACKTYPE7, r.PACKTYPE8, r.PACKTYPE9, r.PACKTYPE10, r.CTNCNT1, r.CTNCNT2, r.CTNCNT3, r.CTNCNT4, r.CTNCNT5, r.CTNCNT6, r.CTNCNT7, r.CTNCNT8, r.CTNCNT9,
                         r.CTNCNT10, r.CTNQTY1, r.CTNQTY2, r.CTNQTY3, r.CTNQTY4, r.CTNQTY5, r.CTNQTY6, r.CTNQTY7, r.CTNQTY8, r.CTNQTY9, r.CTNQTY10, r.NoOfMasterCtn, r.NoOfTTLUnit, r.NoOfPallet, r.Weight, r.WeightUnit, r.Cube, r.CubeUnit,
                         r.GIS_ControlNo, r.Cust_ISA_ControlNo, r.Cust_GIS_ControlNo, r.GIS_ProcessTime, r.Cust_EDIAckTime, r.FinalizeDate, r.SellerName, r.SellerCompany, r.SellerAddress1, r.SellerAddress2, r.SellerAddress3, r.SellerAddress4,
                         r.SellerCity, r.SellerState, r.SellerZip, r.SellerCountry, r.SellerContact1, r.SellerContact2, r.SellerPhone1, r.SellerPhone2, r.SellerEmail1, r.SellerEmail2, r.SellerFax1, r.SellerFax2, rd.ReceiptKey AS DetReceiptKey,
                         rd.ReceiptLineNumber, rd.ExternReceiptKey AS DetExternReceiptKey, rd.ExternLineNo, rd.Sku, rd.AltSku, rd.Id, rd.DateReceived, rd.QtyExpected, rd.QtyAdjusted, rd.QtyReceived, rd.UOM, rd.PackKey AS DetPackKey,
                         rd.VesselKey, rd.VoyageKey, rd.XdockKey, rd.ContainerKey AS DetContainerKey, rd.ToLoc, rd.ToLot, rd.ToId, rd.ConditionCode, rd.Lottable01, rd.Lottable02, rd.Lottable03, rd.Lottable04, rd.Lottable05, rd.CaseCnt AS DetCaseCnt,

                         rd.InnerPack AS DetInnerPack, rd.Pallet AS DetPallet, rd.Cube AS DetCube, rd.GrossWgt AS DetGrossWgt, rd.NetWgt AS DetNetWgt, rd.OtherUnit1 AS DetOtherUnit1, rd.OtherUnit2 AS DetOtherUnit2, rd.UnitPrice,
                         rd.ExtendedPrice, rd.EffectiveDate AS DetEffectiveDate, rd.AddWho AS DetAddWho, rd.AddDate AS DetAddDate, rd.EditDate AS DetEditDate, rd.EditWho AS DetEditWho, rd.TariffKey, rd.FreeGoodQtyExpected,
                         rd.FreeGoodQtyReceived, rd.SubReasonCode, rd.FinalizeFlag, rd.DuplicateFrom, rd.BeforeReceivedQty, rd.PutawayLoc, rd.ExportStatus, rd.SplitPalletFlag, rd.POLineNumber, rd.LoadKey AS DetLoadKey, rd.ExternPoKey,
                         rd.UserDefine01 AS DetUserDefine01, rd.UserDefine02 AS DetUserDefine02, rd.UserDefine03 AS DetUserDefine03, rd.UserDefine04 AS DetUserDefine04, rd.UserDefine05 AS DetUserDefine05,
                         rd.UserDefine06 AS DetUserDefine06, rd.UserDefine07 AS DetUserDefine07, rd.UserDefine08 AS DetUserDefine08, rd.UserDefine09 AS DetUserDefine09, rd.UserDefine10 AS DetUserDefine10, rd.Lottable01 AS DetLottable01,
                         rd.Lottable02 AS DetLottable02, rd.Lottable03 AS DetLottable03, rd.Lottable04 AS DetLottable04, rd.Lottable05 AS DetLottable05, rd.Lottable06 AS DetLottable06, rd.Lottable07 AS DetLottable07, rd.Lottable08 AS DetLottable08,
                         rd.Lottable09 AS DetLottable09, rd.Lottable10 AS DetLottable10, rd.Lottable11 AS DetLottable11, rd.Lottable12 AS DetLottable12, rd.Lottable13 AS DetLottable13, rd.Lottable14 AS DetLottable14, rd.Lottable15 AS DetLottable15,
                         rd.Channel, rd.Channel_ID, k.DESCR AS SkuDESCR, k.MANUFACTURERSKU, k.PutawayZone, k.Style, k.Color, k.Size, k.itemclass, k.SUSR1, k.SUSR2, k.NOTES1, k.STDNETWGT, k.STDCUBE, f.Descr, p.PackKey, p.PackDescr,
                         p.PackUOM1, p.CaseCnt, p.ISWHQty1, p.ReplenishUOM1, p.ReplenishZone1, p.CartonizeUOM1, p.LengthUOM1, p.WidthUOM1, p.HeightUOM1, p.CubeUOM1, p.PackUOM2, p.InnerPack, p.ISWHQty2, p.ReplenishUOM2,
                         p.ReplenishZone2, p.CartonizeUOM2, p.LengthUOM2, p.WidthUOM2, p.HeightUOM2, p.CubeUOM2, p.PackUOM3, p.Qty, p.ISWHQty3, p.ReplenishUOM3, p.ReplenishZone3, p.CartonizeUOM3, p.LengthUOM3, p.WidthUOM3,
                         p.HeightUOM3, p.CubeUOM3, p.PackUOM4, p.Pallet, p.ISWHQty4, p.ReplenishUOM4, p.ReplenishZone4, p.CartonizeUOM4, p.LengthUOM4, p.WidthUOM4, p.HeightUOM4, p.CubeUOM4, p.PalletWoodLength, p.PalletWoodWidth,
                         p.PalletWoodHeight, p.PalletTI, p.PalletHI, p.PackUOM5, p.Cube AS PackCube, p.ISWHQty5, p.PackUOM6, p.GrossWgt, p.ISWHQty6, p.PackUOM7, p.NetWgt, p.ISWHQty7, p.PackUOM8, p.OtherUnit1, p.ISWHQty8,
                         p.ReplenishUOM8, p.ReplenishZone8, p.CartonizeUOM8, p.LengthUOM8, p.WidthUOM8, p.HeightUOM8, p.PackUOM9, p.OtherUnit2, p.ISWHQty9, p.ReplenishUOM9, p.ReplenishZone9, p.CartonizeUOM9, p.LengthUOM9,
                         p.WidthUOM9, p.HeightUOM9, p.AddDate AS PackAddDate, p.AddWho AS PackAddWho, p.EditDate AS PackEditDate, p.EditWho AS PackEditWho, k.RETAILSKU, k.StorerKey AS SKUStorerKey, k.Sku AS SKUSku, k.SUSR3,
                         k.SUSR4, k.SUSR5, k.RETAILSKU AS SKURETAILSKU, k.PACKKey AS SKUPACKKey, k.STDGROSSWGT, k.CLASS, k.SKUGROUP, k.LOTTABLE01LABEL, k.LOTTABLE02LABEL, k.LOTTABLE03LABEL, k.LOTTABLE04LABEL,
                         k.LOTTABLE05LABEL, k.InnerPack AS SKUInnerPack, k.Cube AS SKUCube, k.GrossWgt AS SKUGrossWgt, k.NetWgt AS SKUNetWgt, k.ABC, k.Price, k.Length, k.Width, k.Height, k.weight AS SKUweight, k.Facility AS SKUFacility,
                         k.HazardousFlag, k.OTM_SKUGroup, k.LottableCode, rd.POKey AS DetPOKey, rd.Status AS DetStatus,
						 c.Storerkey AS SCarrierKey, c.type AS SCarrierType, c.Company as SCarrierCompany, c.address1 as SCarrierAddress
FROM            RECEIPT AS r WITH (NOLOCK) LEFT OUTER JOIN
                         RECEIPTDETAIL AS rd WITH (NOLOCK) ON r.ReceiptKey = rd.ReceiptKey LEFT OUTER JOIN
                         SKU AS k WITH (NOLOCK) ON rd.Sku = k.Sku AND rd.StorerKey = k.StorerKey LEFT OUTER JOIN
                         STORER AS c WITH (NOLOCK) ON c.StorerKey = r.StorerKey LEFT OUTER JOIN
                         FACILITY AS f WITH (NOLOCK) ON f.Facility = r.Facility LEFT OUTER JOIN
                         PACK AS p WITH (NOLOCK) ON rd.PackKey = p.PackKey
WHERE        (r.ReceiptDate > DATEADD(month, - 3, GETDATE()))

GO