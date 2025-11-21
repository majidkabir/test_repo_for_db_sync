SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFEFO5                                         */
/* Creation Date: 24-Dec-2010                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : First Expired First Out, Qty Available*/
/*                                                                      */
/* Called By: nspOrderProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 05-Jan-2011  TLTING  1.1  bug on lottable04&lottable05 filter-tlting01*/
/************************************************************************/
CREATE PROC [dbo].[nspPRFEFO5]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 DATETIME ,
@d_lottable05 DATETIME ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),    -- added By Vicky for IDSV5 
@n_uombase INT ,
@n_qtylefttofulfill INT
AS
BEGIN
    SET CONCAT_NULL_YIELDS_NULL OFF
    SET NOCOUNT ON 
    
    DECLARE @n_StorerMinShelfLife  INT
           ,@c_Condition           NVARCHAR(510)
           ,@c_SQLStatement        NVARCHAR(3999) 
    
    IF ISNULL(RTrim(@c_lot),'') <> ''
    BEGIN
        /* Get Storer Minimum Shelf Life */
        
        SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
        FROM   Sku(NOLOCK)
              ,Storer(NOLOCK)
              ,Lot(NOLOCK)
        WHERE  Lot.Lot = @c_lot
        AND    Lot.Sku = Sku.Sku
        AND    Sku.Storerkey = Storer.Storerkey
        AND    Sku.Facility = @c_facility -- added By Vicky for IDSV5 
        
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY 
        FOR
            SELECT LOT.STORERKEY
                  ,LOT.SKU
                  ,LOT.LOT
                  ,QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
            FROM   LOT(NOLOCK)
                  ,Lotattribute (NOLOCK)
            WHERE  LOT.LOT = @c_lot
            AND    Lot.Lot = Lotattribute.Lot
            AND    DATEADD(DAY ,@n_StorerMinShelfLife ,Lotattribute.Lottable04) 
                   > GETDATE()
            ORDER BY
                   Lotattribute.Lottable04
                  ,(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED) 
    END
    ELSE
    BEGIN
        /* Get Storer Minimum Shelf Life */
        SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
        FROM   Sku(NOLOCK)
              ,Storer(NOLOCK)
        WHERE  Sku.Sku = @c_sku
        AND    Sku.Storerkey = @c_storerkey
        AND    Sku.Storerkey = Storer.Storerkey
        AND    Sku.Facility = @c_facility -- added By Vicky for IDSV5 
        
        IF @n_StorerMinShelfLife IS NULL
            SELECT @n_StorerMinShelfLife = 0
        
        IF ISNULL(RTrim(@c_Lottable01),'') <> ''
        BEGIN
            SELECT @c_Condition = " AND LOTTABLE01 = N'" + RTrim(@c_Lottable01) 
                   + "' "
        END
        IF ISNULL(RTrim(@c_Lottable02),'') <> ''
        BEGIN
            SELECT @c_Condition = RTrim(@c_Condition) + 
                   " AND LOTTABLE02 = N'" + RTrim(@c_Lottable02)
                   + "' "
        END
        IF ISNULL(RTrim(@c_Lottable03),'') <> ''
        BEGIN
            SELECT @c_Condition = RTrim(@c_Condition) + 
                   " AND LOTTABLE03 = N'" + RTrim(@c_Lottable03) 
                   + "' "
        END
        IF CONVERT(VARCHAR(8) ,@d_Lottable04 ,112)<>'19000101'            
           AND @d_Lottable04 IS NOT NULL
        BEGIN
            SELECT @c_Condition = RTrim(@c_Condition) + 
                   " AND LOTTABLE04 = N'" + CONVERT(VARCHAR(8) ,@d_Lottable04 ,112) 
                   + "' "

        END
        IF CONVERT(VARCHAR(8) ,@d_Lottable05 ,112)<>'19000101'            
           AND @d_Lottable05 IS NOT NULL
        BEGIN
            SELECT @c_Condition = RTrim(@c_Condition) + 
                   " AND LOTTABLE05 = N'" + CONVERT(VARCHAR(8) ,@d_Lottable05 ,112) 
                   + "' "
        END
          
        IF ISNULL(@n_StorerMinShelfLife,0) > 0
        BEGIN
            SELECT @c_Condition = RTrim(@c_Condition) + 
                   " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) 
                   + ", Lotattribute.Lottable04) > GetDate() "
        END 
        
        SELECT @c_SQLStatement = 
               " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
               " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " + 
               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +
               " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " + 
               " WHERE LOT.STORERKEY = N'" + RTrim(@c_storerkey) + "' " +
               " AND LOT.SKU = N'" + RTrim(@c_SKU) + "' " +
               " AND LOT.STATUS = 'OK' " +
               " AND LOT.LOT = LOTATTRIBUTE.LOT " +
               " AND LOTXLOCXID.Lot = LOT.LOT " +
               " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
               " AND LOTXLOCXID.LOC = LOC.LOC " +
               " AND LOTxLOCxID.ID = ID.ID " +
               " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
               " AND LOC.LocationFlag = 'NONE' " + 
               " AND LOC.Facility = N'" + RTrim(@c_facility) + "' " +
               " AND LOTATTRIBUTE.STORERKEY = N'" + RTrim(@c_storerkey) + "' " +
               " AND LOTATTRIBUTE.SKU = N'" + RTrim(@c_SKU) + "' " + RTrim(@c_Condition) + 
               " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04 " + 
               " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " +
               " ORDER BY Lotattribute.Lottable04, SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) "
        
        EXEC (@c_SQLStatement)
             
    END
END

GO