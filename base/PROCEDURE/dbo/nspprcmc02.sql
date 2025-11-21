SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRCMC02                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author    Ver  Purposes                                   */
/* 2009-02-10 SHONG     1.1  SOS#127940 Make it more generic for other  */
/*                           storer to use.                             */
/* 19-Mar-2009  Audrey        SOS131215 : Add in ID.Status ='OK'        */
/************************************************************************/
CREATE PROC [dbo].[nspPRCMC02]
      @c_StorerKey NVARCHAR(15) ,
      @c_SKU NVARCHAR(20) ,
      @c_LOT NVARCHAR(10) ,
      @c_Lottable01 NVARCHAR(18) ,
      @c_Lottable02 NVARCHAR(18) ,
      @c_Lottable03 NVARCHAR(18) ,
      @c_Lottable04 datetime,
      @c_Lottable05 datetime,
      @c_uom NVARCHAR(10) ,
      @c_Facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
      @n_uombase int ,
      @n_Qtylefttofulfill int,
      @c_OtherParms NVARCHAR(200) = NULL
AS
begin -- main
	      

   /* Get SKU Shelf Life */
   DECLARE @n_Acceptage int,
           @n_ShelfLife int
           
   SELECT @n_Acceptage = BUSR6,
          @n_ShelfLife = ShelfLife
   FROM  Sku (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   SKU = @c_SKU
   
   IF ISNULL(RTrim(@n_Acceptage),'') = '' SELECT @n_Acceptage = 0
   IF ISNULL(RTrim(@n_ShelfLife),'') = '' SELECT @n_ShelfLife = 0

   If ISNULL(RTrim(@c_LOT),'') <> ''
   Begin
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,
             QtyAvailable = SUM(LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))
      from LOTxLOCxID (NOLOCK)
      JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
      JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.LOT = LotAttribute.LOT
      JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
      JOIN ID (NOLOCK) on LOTxLOCxID.ID = ID.ID -- SOS131215
      LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                       FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
                       WHERE  p.Orderkey = ORDERS.Orderkey
                       AND    p.StorerKey = @c_StorerKey
                       AND    p.SKU = @c_SKU
                       AND    p.Qty > 0
                       GROUP BY p.LOT, ORDERS.Facility) 
                       P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility
      WHERE LOTxLOCxID.LOT = @c_LOT
      AND LOTxLOCxID.Qty > 0
      AND LOT.Status = 'OK' AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
      AND Id.Status = 'OK'  --SOS131215
      AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5
      AND LOC.locationflag = 'NONE'
      AND (LOC.locationtype = 'CASE' or LOC.locationtype = 'PICK')
      AND (DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_Acceptage OR Lottable04 IS NULL)
      GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, Lottable04, Lottable05
      HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
      ORDER BY Lottable04, Lottable05
   End
   Else -- if LTrim(RTrim(@c_LOT)) is not null
   Begin
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,
             QtyAvailable = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(p.QtyPreallocated, 0))
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
      JOIN LotAttribute (NOLOCK) ON LOTxLOCxID.LOT = LotAttribute.LOT
      JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID -- SOS131215
      LEFT OUTER JOIN (SELECT p.LOT, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)
                       FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)
                       WHERE  p.Orderkey = ORDERS.Orderkey
                       AND    p.StorerKey = @c_StorerKey
                       AND    p.SKU = @c_SKU
                       AND    p.Qty > 0
                       GROUP BY p.LOT, ORDERS.Facility) P ON LOTxLOCxID.LOT = p.LOT AND p.Facility = LOC.Facility
      where LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND LOTxLOCxID.Qty > 0
      AND LOT.Status = 'OK' AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
      AND ID.STATUS = 'OK'  -- SOS131215 
      AND LOC.Facility = @c_Facility  -- Added By Ricky for IDSV5
      AND LOC.locationflag = 'NONE'
      AND (LOC.locationtype = 'CASE' or LOC.locationtype = 'PICK')
      AND (DATEDIFF(DAY, GETDATE(), Lottable04) >= @n_Acceptage OR Lottable04 IS NULL)
      GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, Lottable04, Lottable05 
      HAVING SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
      ORDER BY Lottable04, Lottable05 
   end
end -- main

GO