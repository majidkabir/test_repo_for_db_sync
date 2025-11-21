SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Stored Procedure: nspPRCMC06                                         */      
/* Creation Date: 14-Aug-2013                                           */      
/* Copyright: IDS                                                       */      
/* Written by: YTWan                                                    */      
/*                                                                      */      
/* Purpose: Copy and modified from nspPRCMC04                           */ 
/*        : IDSPH: CPPI Strategy                                        */   
/*         : IF ORder Qty is Full Pallet , stock takes from 'PALLET'    */
/*         : locationtype                                               */
/*         : IF Order Qty is CASE, stock takes from 'CASE' locationtype */
/*         : IF order Qty is loose, stock takes from 'PICK' locationtype*/
/*         : OTHERWISE take from BULK Location (LocationTYPE <> 'PALLET'*/
/*         : , <> 'CASE', <> 'PICK')                                    */
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author  Ver   Purposes                                  */      
/* 24-Apr-2018  NJOW01  1.0   WMS-4188 exclude qtyreplen                */
/************************************************************************/      
      
CREATE PROC [dbo].[nspPRCMC06]      
      @c_Storerkey         NVARCHAR(15)        
   ,  @c_SKU               NVARCHAR(20)       
   ,  @c_lot               NVARCHAR(10)      
   ,  @c_Lottable01        NVARCHAR(18)       
   ,  @c_Lottable02        NVARCHAR(18)       
   ,  @c_Lottable03        NVARCHAR(18)       
   ,  @c_Lottable04        DATETIME       
   ,  @c_Lottable05        DATETIME       
   ,  @c_UOM               NVARCHAR(10)       
   ,  @c_Facility          NVARCHAR(10)     
   ,  @n_UOMbase           INT     
   ,  @n_QtyleftToFulfill  INT     
   ,  @c_OtherParms        NVARCHAR(200) = NULL       
  AS      
BEGIN -- main      
   SET NOCOUNT ON      
   /* Get SKU Shelf Life */      
   DECLARE @n_AcceptAge INT     
  
   SET @n_AcceptAge = 0  
    
   SELECT @n_AcceptAge = CASE WHEN ISNUMERIC(ISNULL(RTRIM(BUSR6),'0')) = 1 THEN  CONVERT(INT, ISNULL(RTRIM(BUSR6),'0')) ELSE 0 END      
   FROM  SKU WITH (NOLOCK)      
   WHERE Storerkey = @c_Storerkey       
   AND   SKU = @c_SKU      
      
   IF RTRIM(@c_LOT) IS NOT NULL AND RTRIM(@c_LOT) <> ''      
   BEGIN      
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT LOT.Storerkey
            ,LOT.sku
            ,LOT.lot
            ,Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) - MIN(ISNULL(p.QtyPreallocated, 0))      
      FROM LOTxLOCxID   WITH (NOLOCK)       
      JOIN LOT          WITH (NOLOCK) ON LOTxLOCxID.lot = LOT.lot      
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTxLOCxID.lot = LOTATTRIBUTE.lot      
      JOIN LOC          WITH (NOLOCK) ON LOTxLOCxID.loc = LOC.loc      
      JOIN ID           WITH (NOLOCK) ON LOTXLOCXID.ID = ID.ID
 
      LEFT OUTER JOIN ( SELECT p.lot
                              ,ORDERS.Facility
                              ,QtyPreallocated = SUM(p.Qty)       
                        FROM   PREALLOCATEPICKDETAIL p WITH (NOLOCK)
                        JOIN   ORDERS WITH (NOLOCK) ON (p.Orderkey = ORDERS.Orderkey)     
                        WHERE  p.Storerkey= RTRIM(@c_Storerkey)
                        AND    p.SKU      = RTRIM(@c_SKU)      
                        AND    p.Qty > 0      
                        GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility       
      WHERE LOTxLOCxID.LOT = @c_lot      
      AND LOTxLOCxID.Qty > 0      
      AND LOT.Status = 'OK'       
      AND LOC.Status = 'OK'       
      AND ID.Status  = 'OK'      
      AND LOC.LocationFlag <> 'HOLD'     
      AND LOC.LocationFlag <> 'DAMAGE'      
      AND LOC.LocationType = CASE @c_UOM WHEN '1' THEN 'PALLET'
                                         WHEN '2' THEN 'CASE'
                                         WHEN '6' THEN 'PICK'
                                         END     
      AND LOC.Facility = @c_Facility       
      AND DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_AcceptAge      
      GROUP BY LOT.Storerkey, LOT.SKU, LOT.LOT, Lottable04, Lottable02       
      HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0      
      ORDER BY Lottable04, Lottable02      
   END      
   ELSE        
   BEGIN 
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
      SELECT LOT.Storerkey
            ,LOT.sku
            ,LOT.lot
            ,Qtyavailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) - MIN(ISNULL(p.QtyPreallocated, 0))      
      FROM LOTxLOCxID   WITH (NOLOCK)       
      JOIN LOT          WITH (NOLOCK) ON LOTxLOCxID.lot = LOT.lot      
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTxLOCxID.lot = LOTATTRIBUTE.lot      
      JOIN LOC          WITH (NOLOCK) ON LOTxLOCxID.loc = LOC.loc      
      JOIN ID           WITH (NOLOCK) ON LOTXLOCXID.ID = ID.ID    
      LEFT OUTER JOIN ( SELECT p.lot
                              ,ORDERS.Facility
                              ,QtyPreallocated = SUM(p.Qty)       
                        FROM   PREALLOCATEPICKDETAIL p WITH (NOLOCK)
                        JOIN   ORDERS WITH (NOLOCK) ON (p.Orderkey = ORDERS.Orderkey)     
                        WHERE  p.Storerkey= RTRIM(@c_Storerkey)
                        AND    p.SKU      = RTRIM(@c_SKU)      
                        AND    p.Qty > 0      
                        GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = p.Lot AND p.Facility = LOC.Facility          
      WHERE LOTxLOCxID.Storerkey = @c_Storerkey      
      AND LOTxLOCxID.sku = @c_SKU      
      AND LOTxLOCxID.Qty > 0      
      AND LOT.Status = 'OK'       
      AND LOC.Status = 'OK'       
      AND ID.Status  = 'OK'     
      AND LOC.LocationFlag <> 'HOLD'     
      AND LOC.LocationFlag <> 'DAMAGE'      
      AND LOC.LocationType = CASE @c_UOM WHEN '1' THEN 'PALLET'
                                         WHEN '2' THEN 'CASE'
                                         WHEN '6' THEN 'PICK'
                                         END 
      AND LOC.Facility = @c_Facility     
      AND LOTATTRIBUTE.Lottable01 = CASE WHEN RTRIM(@c_Lottable01) <> '' AND @c_Lottable01 IS NOT NULL THEN @c_Lottable01 ELSE LOTATTRIBUTE.Lottable01 END
      AND DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_AcceptAge
      GROUP BY LOT.Storerkey, LOT.sku, LOT.lot, ISNULL(Lottable04, '1900-01-01'), ISNULL(RTRIM(Lottable02),'')
            ,  ISNULL(RTRIM(LOC.LocationType),'')      
      HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0      
      ORDER BY ISNULL(Lottable04, '1900-01-01'), ISNULL(RTRIM(Lottable02),'')
  
   END      
END -- main     

GO