SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_FormUsage]
AS
SELECT CASE [UDF03]
            WHEN 'w_wave_maintenance'         THEN 'Wave Planning'
            WHEN 'w_inventory_move'           THEN 'Inventory Move'
            WHEN 'w_orders_maintenance'       THEN 'Shipment Orders'
            WHEN 'w_receipt_maintenance'      THEN 'Receipt'
            WHEN 'w_inventory_report_balance' THEN 'Inventory Balance Inquiry'
            WHEN 'nep_w_loadplan_maintenance' THEN 'Load Planning'
            WHEN 'w_itran'                    THEN 'Inventory Transaction Inquiry'
            WHEN 'nep_w_packing_maintenance'  THEN 'Packing'
            WHEN 'w_pod_update_maintenance'   THEN 'Proof Of Delivery (Batch)'
            WHEN 'w_inventoryqc_maintenance'  THEN 'Inventory QC'
            WHEN 'w_scanin_pickerid'          THEN 'Scan-In'
            WHEN 'w_loadplan_orderscaning'    THEN 'Scan to Load'
            WHEN 'w_sku_maintenance'          THEN 'SKU Maintenance'
            WHEN 'w_po_maintenance'           THEN 'Purchase Order'
            WHEN 'w_scanout_pickerid'         THEN 'Scan-Out'
            WHEN 'w_transfer_maintenance'     THEN 'Inventory Transfer'
            WHEN 'w_pod_maintenance'          THEN 'Proof Of Delivery'
            WHEN 'w_mbol_maintenance'         THEN 'MBOL Maintenance'
            WHEN 'w_report_view'              THEN 'Report Module'
            WHEN 'w_adjustment_maintenance'   THEN 'Inventory Adjustment'
            WHEN 'nep_w_kit_maintenance'      THEN 'Kitting'
            WHEN 'w_unallocate'               THEN 'Unallocate Orders'
            WHEN 'w_stocktake_parm_maintenance_new' THEN 'Stock Take '
            ELSE [UDF03]
      END as WindowName,
      DATEPART(year,  LogDate) As [Year],
      DATEPART(month, LogDate) As [Month],
       Count( DISTINCT Convert(char(10), LogDate, 112) ) NoOfDays,
       Count( DISTINCT UDF05) as NoOfUsers,
       ( Count(*) / Count( DISTINCT Convert(char(10), LogDate, 112) ) ) AS EverageDayClicked
  FROM [IDS_GeneralLog] WITH (NOLOCK)
WHERE UDF04 = 'OPENWIN'
GROUP BY [UDF03],
      DATEPART(year,  LogDate),
      DATEPART(month, LogDate)


GO