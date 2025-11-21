SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
   CREATE VIEW [dbo].[V_DEL_ORDERDETAIL]  AS      
SELECT [OrderKey] , [OrderLineNumber] , [OrderDetailSysId] , [ExternOrderKey] , [ExternLineNo] , [Sku] , [StorerKey] , [ManufacturerSku] , [RetailSku] , [AltSku] ,     
EnteredQty,  [OriginalQty] , [OpenQty] , [ShippedQty] , [AdjustedQty]    
 , [QtyPreAllocated] , [QtyAllocated] , [QtyPicked] , [UOM] , [PackKey] , [PickCode] , [CartonGroup] , [Lot] , [ID] , [Facility] , [Status] , [UnitPrice] , [Tax01] ,   
 [Tax02] , [ExtendedPrice] , [UpdateSource] ,  [Lottable01] , [Lottable02] , [Lottable03] , [Lottable04] , [Lottable05] , [Lottable06] , [Lottable07] , [Lottable08] ,   
 [Lottable09] , [Lottable10] , [Lottable11] , [Lottable12] , [Lottable13] , [Lottable14] , [Lottable15], [EffectiveDate] , [AddDate] , [AddWho] , [EditDate] , [EditWho] , [TrafficCop] , [ArchiveCop] , [TariffKey] , [FreeGoodQty] , [GrossWeight] , [Capacity] , [LoadKey] , [MBOLKey] , [QtyToProcess] , [MinShelfLife] ,     
[UserDefine01] , [UserDefine02] , [UserDefine03] , [UserDefine04] , [UserDefine05] , [UserDefine06] , [UserDefine07] , [UserDefine08] , [UserDefine09] ,    
[UserDefine10], [POKey] , [ExternPOKey]     
FROM [DEL_ORDERDETAIL] (NOLOCK)       
GO