SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Extended_Validation] AS
SELECT 'MBOLExtendedValidation' AS ValidationType,
       'MBOL Ship Validation' AS ValidationDesc,
       'MBOLExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_MBOL_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'ASNExtendedValidation' AS ValidationType,
       'Receipt Finalize Validation' AS ValidationDesc,
       'ASNExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_ASN_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'TRFExtendedValidation' AS ValidationType,
       'Transfer Finalize Validation' AS ValidationDesc,
       'TRFExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_TRF_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'PODExtendedValidation' AS ValidationType,
       'POD Finalize Validation' AS ValidationDesc,
       'PODExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_POD_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'ADJExtendedValidation' AS ValidationType,
       'Adjustment Finalize Validation' AS ValidationDesc,
       'ADJExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_ADJ_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'BKOExtendedValidation' AS ValidationType,
       'Booking Out Finalize Validation' AS ValidationDesc,
       'BKOExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_BKO_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'REPLExtendedValidation' AS ValidationType,
       'Replenishment Validation' AS ValidationDesc,
       'REPLExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_REPL_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'IQCExtendedValidation' AS ValidationType,
       'IQC Finalize Validation' AS ValidationDesc,
       'IQCExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_IQC_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'MoveExtendedValidation' AS ValidationType,
       'Move Execute Validation' AS ValidationDesc,
       'MoveExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_MOVE_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'JOBExtendedValidation' AS ValidationType,
       'VAP JOB Extended Validation' AS ValidationDesc,
       'JOBExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_JOB_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
--INC0393977 Start
UNION ALL
SELECT 'PreAllocateExtendedValidation' as ValidateType,
       'PreAllocation Extended Validation' AS ValidationDesc,
       'PreAllocateExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Allocate_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'PostAllocateExtendedValidation' as ValidateType,
       'PostAllocation Extended Validation' AS ValidationDesc,
       'PostAllocateExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Allocate_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
--SELECT 'AllocateExtendedValidation' as ValidateType,
--       'Allocation Extended Validation' AS ValidationDesc,
--       'AllocateExtendedValidation' AS ValidateTable,
--       'Storer' AS ValidateBy,
--       '' AS CfgValSourceCol,
--       'isp_Allocate_ExtendedValidation' AS ValidationSP,
--       '' AS IsConso
--INC0393977 End
UNION ALL
SELECT 'LOADExtendedValidation' as ValidateType,
       'Load Extended Validation' AS ValidationDesc,
       'LoadExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Load_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'KitExtendedValidation' as ValidateType,
       'Kit Finalized Validation' AS ValidationDesc,
       'KitExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Kit_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL --WMS-9973 Start
SELECT 'CFMPackConsoExtValidation' as ValidateType,
       'Pack Confirm (By Load) Validation' AS ValidationDesc,
       'CFMPackConsoExtValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Pack_ExtendedValidation' AS ValidationSP,
       '1' AS IsConso
UNION ALL
SELECT 'CFMPackDiscreteExtValidation' as ValidateType,
       'Pack Confirm (By Order) Validation' AS ValidationDesc,
       'CFMPackDiscreteExtValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Pack_ExtendedValidation' AS ValidationSP,
       '0' AS IsConso
UNION ALL
SELECT 'PrePackDiscreteExtValidation' as ValidateType,
       'PrePack (By Order) Validation' AS ValidationDesc,
       'PrePackDiscreteExtValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_PrePack_ExtendedValidation' AS ValidationSP,
       '0' AS IsConso
UNION ALL
SELECT 'PrePackConsoExtValidation' as ValidateType,
       'PrePack (By Load) Validation' AS ValidationDesc,
       'PrePackConsoExtValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_PrePack_ExtendedValidation' AS ValidationSP,
       '1' AS IsConso
UNION ALL --WMS-9973 End
--WMS-14433 START
SELECT 'ASNCloseExtendedValidation' as ValidateType,
       'ASN Close Extended Validation ' AS ValidationDesc,
       'ASNCloseExtendedValidation ' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_ASN_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL --WMS-14433 END
--WMS-17048 START
SELECT 'ChannelTRFExtendedValidation' as ValidateType,
       'Channel Transfer Extended Validation ' AS ValidationDesc,
       'ChannelTRFExtendedValidation ' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_ChannelTRF_ExtendedValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL --WMS-17048 END
SELECT 'FacInputValidation' AS ValidationType,
       'Facility Input Record Validation' AS ValidationDesc,
       'Facility' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL  --WMS-17231
SELECT 'InvHoldInputValidation' AS ValidationType,
       'Inventory Hold Input Record Validation' AS ValidationDesc,
       'InventoryHold' AS ValidateTable,
       'Storer' AS ValidateBy,
       'InventoryHold.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'LocInputValidation' AS ValidationType,
       'Loc Input Record Validation' AS ValidationDesc,
       'Loc' AS ValidateTable,
       'Facility' AS ValidateBy,
       'Loc.Facility' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'StorerInputValidation' AS ValidationType,
       'Storer Input Record Validation' AS ValidationDesc,
       'Storer' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Storer.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'SkuInputValidation' AS ValidationType,
       'Sku Input Record Validation' AS ValidationDesc,
       'Sku' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Sku.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL               --LFWM-3669 - START
SELECT 'SkuxLocInputValidation' AS ValidationType,
       'SkuxLoc Input Record Validation' AS ValidationDesc,
       'SkuxLoc' AS ValidateTable,
       'Storer' AS ValidateBy,
       'SkuxLoc.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso    --LFWM-3669 - END
UNION ALL
SELECT 'POInputValidation' AS ValidationType,
       'PO Input Record Validation' AS ValidationDesc,
       'PO' AS ValidateTable,
       'Storer' AS ValidateBy,
       'PO.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'PODetInputValidation' AS ValidationType,
       'PODetail Input Record Validation' AS ValidationDesc,
       'PODetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'PODetail.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'RcptInputValidation' AS ValidationType,
       'Receipt Input Record Validation' AS ValidationDesc,
       'Receipt' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Receipt.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'RcptDetInputValidation' AS ValidationType,
       'ReceiptDetail Input Record Validation' AS ValidationDesc,
       'receiptDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ReceiptDetail.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'ORDInputValidation' AS ValidationType,
       'Orders Input Record Validation' AS ValidationDesc,
       'Orders' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Orders.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'OrderDetInputValidation' AS ValidationType,
       'OrderDetail Input Record Validation' AS ValidationDesc,
       'OrderDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'OrderDetail.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'PickDetInputValidation' AS ValidationType,
       'PickDetail Input Record Validation' AS ValidationDesc,
       'PickDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'PickDetail.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'TrfInputValidation' AS ValidationType,
       'Transfer Input Record Validation' AS ValidationDesc,
       'Transfer' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Transfer.FromStorerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'TrfDetInputValidation' AS ValidationType,
       'TransferDetail Input Record Validation' AS ValidationDesc,
       'TransferDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'TransferDetail.FromStorerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'AdjInputValidation' AS ValidationType,
       'Adjustment Input Record Validation' AS ValidationDesc,
       'Adjustment' AS ValidateTable,
       'Storer' AS ValidateBy,
       'Adjustment.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'AdjDetInputValidation' AS ValidationType,
       'AdjustmentDetail Input Record Validation' AS ValidationDesc,
       'AdjustmentDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'AdjustmentDetail.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'WaveInputValidation' AS ValidationType,
       'Wave Input Record Validation' AS ValidationDesc,
       'Wave' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'WaveDetInputValidation' AS ValidationType,
       'WaveDetail Input Record Validation' AS ValidationDesc,
       'WaveDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'LoadInputValidation' AS ValidationType,
       'Loadplan Input Record Validation' AS ValidationDesc,
       'Loadplan' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'LoadDetInputValidation' AS ValidationType,
       'LoadplanDetail Input Record Validation' AS ValidationDesc,
       'LoadplanDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'MBOLInputValidation' AS ValidationType,
       'MBOL Input Record Validation' AS ValidationDesc,
       'MBOL' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'MBOLDetInputValidation' AS ValidationType,
       'MBOLDetail Input Record Validation' AS ValidationDesc,
       'MBOLDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'ORDERS.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'KITInputValidation' AS ValidationType,
       'KIT Input Record Validation' AS ValidationDesc,
       'KIT' AS ValidateTable,
       'Storer' AS ValidateBy,
       'KIT.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'KITDetInputValidation' AS ValidationType,
       'KitDetail Input Record Validation' AS ValidationDesc,
       'KitDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'KITDETAIL.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'LOADPopulateValidation' AS ValidationType,
       'LOAD POPULATE ORDERS Validation' AS ValidationDesc,
       'LOADPopulateInputValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_LOAD_PopulateValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'MBOLPopulateValidation' AS ValidationType,
       'MBOL POPULATE LOADPLAN/ORDERS Validation' AS ValidationDesc,
       'MBOLPopulateInputValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_MBOL_PopulateValidation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'WORKORDERInputValidation' AS ValidationType,
       'WORKORDER Input Record Validation' AS ValidationDesc,
       'WORKORDER' AS ValidateTable,
       'Storer' AS ValidateBy,
       'WORKORDER.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL
SELECT 'WORKORDERDetInputValidation' AS ValidationType,
       'WORKORDER Detail Input Record Validation' AS ValidationDesc,
       'WorkorderDetail' AS ValidateTable,
       'Storer' AS ValidateBy,
       'WORKORDERDETAIL.Storerkey' AS CfgValSourceCol,
       'isp_Wrapup_Validation' AS ValidationSP,
       '' AS IsConso
UNION ALL --WMS-21757
SELECT 'UnAllocateExtendedValidation' as ValidateType,
       'UnAllocation Extended Validation' AS ValidationDesc,
       'UnAllocateExtendedValidation' AS ValidateTable,
       'Storer' AS ValidateBy,
       '' AS CfgValSourceCol,
       'isp_UnAllocate_ExtendedValidation' AS ValidationSP,
       '' AS IsConso



GO