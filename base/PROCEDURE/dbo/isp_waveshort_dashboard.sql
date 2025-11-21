SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_WaveShort_Dashboard                            */
/* Creation Date: 15-FEB-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#266624 - Replenishment Dashboard                        */
/*                                                                      */
/* Called By: r_dw_waveshort_dashboard                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_WaveShort_Dashboard] (
         @c_wavekey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TEMP_Short
      (  WaveKey     NVARCHAR(10)
      ,  Storerkey   NVARCHAR(15)
      ,  Sku         NVARCHAR(20)
      ,  ShortQty    INT
      )

   INSERT INTO #TEMP_Short 
      (  WaveKey
      ,  Storerkey
      ,  Sku
      ,  ShortQty
      )

--   SELECT WAVEDETAIL.Wavekey
--         ,ORDERDETAIL.Storerkey
--         ,ORDERDETAIL.Sku 
--         ,ShortQty = SUM(ORDERDETAIL.OpenQty - (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked))
--   FROM WAVEDETAIL  WITH (NOLOCK) 
--   JOIN ORDERDETAIL WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERDETAIL.Orderkey)
--   WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
--   AND EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK) WHERE PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey
--                                                      AND   PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber )
--   --AND ORDERDETAIL.OpenQty > ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked
--   --AND ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked > 0
--   GROUP BY WAVEDETAIL.Wavekey
--         ,  ORDERDETAIL.Storerkey
--         ,  ORDERDETAIL.Sku

   SELECT WAVEDETAIL.Wavekey
         ,PICKDETAIL.Storerkey
         ,PICKDETAIL.Sku 
         ,ShortQty = SUM(PICKDETAIL.Qty)
   FROM WAVEDETAIL  WITH (NOLOCK) 
   JOIN PICKDETAIL WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
   WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
   AND PICKDETAIL.Status = '4'
   GROUP BY WAVEDETAIL.Wavekey
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.Sku


   SELECT TMP.Wavekey
         ,TMP.Storerkey
         ,TMP.Sku
         ,TMP.ShortQty
         ,AvailQty = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
         ,HNDQty   = SUM(CASE WHEN LOC.Locationflag IN ('HOLD', 'DAMAGE') THEN LOTxLOCxID.Qty 
                              WHEN LOT.Status <> 'OK' THEN LOTxLOCxID.Qty 
                              WHEN ID.Status  <> 'OK' THEN LOTxLOCxID.Qty 
                              ELSE 0
                              END)
--         ,HNDQty   = SUM(CASE WHEN LOC.Loc IS NOT NULL OR 
--                                   HID.Id  IS NOT NULL OR
--                                   HLT.Lot IS NOT NULL OR
--                                   HLC.Loc IS NOT NULL OR
--                                   HLTB.Storerkey IS NOT NULL
--                              THEN LOTxLOCxID.Qty ELSE 0 END)
   FROM #TEMP_Short TMP
   JOIN LOTxLOCxID   WITH (NOLOCK) ON (TMP.Storerkey = LOTxLOCxID.Storerkey)
                                   AND(TMP.Sku = LOTxLOCxID.Sku)
   JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
   JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
   JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.Id  = ID.Id)
--   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
--   LEFT JOIN LOC     WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
--                                  AND LOC.LocationFlag IN ('HOLD', 'DAMAGE')
--   LEFT JOIN INVENTORYHOLD HLT  WITH (NOLOCK) ON (LOTxLOCxID.Lot = HLT.Lot) AND (HLT.Loc = '') AND (HLT.ID = '') AND HLT.Hold = '1'
--   LEFT JOIN INVENTORYHOLD HLC  WITH (NOLOCK) ON (LOTxLOCxID.Loc = HLC.Loc) AND (HLC.Lot = '') AND (HLC.ID = '') AND HLC.Hold = '1'
--   LEFT JOIN INVENTORYHOLD HID  WITH (NOLOCK) ON (LOTxLOCxID.Id = HID.Id)   AND (HID.Lot = '') AND (HID.Loc = '')AND HID.Hold = '1' AND ISNULL(RTRIM(HID.Storerkey),'')  = ''
--   LEFT JOIN INVENTORYHOLD HLTB WITH (NOLOCK) ON (LOTATTRIBUTE.Storerkey = HLTB.Storerkey)  
--                                              AND(LOTATTRIBUTE.Sku = HLTB.Sku)
--                                              AND(LOTATTRIBUTE.Lottable01 = CASE WHEN ISNULL(RTRIM(HLTB.Lottable01),'') = '' 
--                                                                                  THEN LOTATTRIBUTE.Lottable01
--                                                                                  ELSE ISNULL(RTRIM(HLTB.Lottable01),'') END)
--                                              AND(LOTATTRIBUTE.Lottable02 = CASE WHEN ISNULL(RTRIM(HLTB.Lottable02),'') = '' 
--                                                                                  THEN LOTATTRIBUTE.Lottable02
--                                                                                  ELSE ISNULL(RTRIM(HLTB.Lottable02),'') END)
--                                              AND(LOTATTRIBUTE.Lottable03 = CASE WHEN ISNULL(RTRIM(HLTB.Lottable03),'') = '' 
--                                                                                  THEN LOTATTRIBUTE.Lottable03
--                                                                                  ELSE ISNULL(RTRIM(HLTB.Lottable03),'') END) 
--                                              AND(CONVERT(NVARCHAR(10),ISNULL(LOTATTRIBUTE.Lottable04,'19000101'),112) 
--                                                                          = CASE WHEN CONVERT(NVARCHAR(10),ISNULL(HLTB.Lottable04,'19000101'),112) = '19000101' 
--                                                                                 THEN CONVERT(NVARCHAR(10),ISNULL(LOTATTRIBUTE.Lottable04,'19000101'),112) 
--                                                                                 ELSE CONVERT(NVARCHAR(10),ISNULL(HLTB.Lottable04,'19000101'),112) END)  
--                                              AND(CONVERT(NVARCHAR(10),ISNULL(LOTATTRIBUTE.Lottable05,'19000101'),112) 
--                                                                          = CASE WHEN CONVERT(NVARCHAR(10),ISNULL(HLTB.Lottable05,'19000101'),112) = '19000101' 
--                                                                                 THEN CONVERT(NVARCHAR(10),ISNULL(LOTATTRIBUTE.Lottable05,'19000101'),112) 
--                                                                                 ELSE CONVERT(NVARCHAR(10),ISNULL(HLTB.Lottable05,'19000101'),112) END)
   GROUP BY TMP.Wavekey
         ,  TMP.Storerkey
         ,  TMP.Sku
         ,  TMP.ShortQty


END

GO