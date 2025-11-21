SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_TH01                                         */
/* Creation Date: 27-Dec-2011                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : SOS#232803 First Expired First Out    */
/*                                and Lottable01='U' for Mars           */
/*                                (modified from nsp_PRFEFO)            */
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver. Purposes                                    */
/* 27-FEB-2012	NJOW01 1.0  237150-allocate by orderdetail.minshelflife */
/* 05-MAR-2013  NJOW02 1.1  270658-allow storerconfig to define         */
/*                          lottable01 value to filter                  */
/* 23-Aug-2013	NJOW03 1.2  287462-Sorting by Max Available Qty         */
/* 28-Nov-2013  NJOW04 1.3  287462-ADD storerconfig to enable Sorting by*/
/*                          Max Available Qty                           */    
/* 29-Mar-2014  NJOW05 1.4  312265-Preallocation for order type M-SCPO  */
/* 11-Nov-2014  NJOW06 1.5  324900-If turn on nspPR_TH01_SortInclLot2   */
/*                          will have different sorting                 */
/************************************************************************/

CREATE PROC [dbo].[nspPR_TH01]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),     
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''  --Orderinfo4PreAllocation   
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
    SET NOCOUNT ON 
    
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(510),
           @c_SQLStatement NVARCHAR(3999) ,
           @n_OutGoingMinshelfLife int,  --NJOW01
           @b_success int,
           @c_lot01value NVARCHAR(10),
           @c_Sortbymaxqtybal NVARCHAR(10), --NJOW04
           @c_hostwhcodevalue NVARCHAR(10),
           @c_ConditionWHCode NVARCHAR(100),
           @n_err int,
           @c_errmsg NVARCHAR(250), 
           @c_ChkM_SCPO NVARCHAR(10), --NJOW05
           @c_OrderType NVARCHAR(10), --NJOW05
           @c_PR_TH01_SortInclLot2 NVARCHAR(10) --NJOW06
   
   IF ISNULL(@c_lot,'') <> '' AND LEFT(LTRIM(@c_lot),1) <> '*'  --NJOW01
   BEGIN
      /* Get Storer Minimum Shelf Life */
           
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable04, Lot.Lot
   END
   ELSE
   BEGIN
   	  IF LEFT(LTRIM(@c_lot),1) = '*'
      BEGIN
         SELECT @n_OutGoingMinshelfLife = CONVERT(int, SUBSTRING(LTRIM(@c_lot), 2, 9))
      END
      ELSE
      BEGIN
         /* Get Storer Minimum Shelf Life */
         SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
         FROM Sku (nolock), Storer (nolock)
         WHERE Sku.Sku = @c_sku
         AND Sku.Storerkey = @c_storerkey   
         AND Sku.Storerkey = Storer.Storerkey
         AND Sku.Facility = @c_facility  
      END

      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
      
      IF @n_OutGoingMinshelfLife IS NULL  --NJOW01
         SELECT @n_OutGoingMinshelfLife = 0
      
      /*
      IF ISNULL(@c_Lottable01,'') <> '' 
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = '" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
      END
      */
      
      --NJOW01  
      SELECT @b_success = 0
      Execute nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      @c_Sku,                    
      'nspPR_TH01_LOT1', -- Configkey
      @b_success    OUTPUT,
      @c_lot01value OUTPUT,
      @n_err        OUTPUT,
      @c_errmsg     OUTPUT
  
      IF @b_success = 1 AND ISNULL(@c_lot01value,'') <> ''
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = N'" + RTRIM(@c_lot01value) + "' "
      END
      ELSE
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = 'U' "
      END
        
      SELECT @b_success = 0
      Execute nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      @c_Sku,                    
      'nspPR_TH01_WHCODE', -- Configkey
      @b_success         OUTPUT,
      @c_hostwhcodevalue OUTPUT,
      @n_err             OUTPUT,
      @c_errmsg          OUTPUT
  
      IF @b_success = 1 AND ISNULL(@c_hostwhcodevalue,'') NOT IN('','0')
      BEGIN
      	 IF @c_hostwhcodevalue = 'NOCHECK'  	 
            SELECT @c_ConditionWHCode = ""
         ELSE
            SELECT @c_ConditionWHCode = " AND LOC.HOSTWHCODE = N'" + RTRIM(@c_hostwhcodevalue) + "' "
      END
      ELSE
      BEGIN
         SELECT @c_ConditionWHCode = " AND LOC.HOSTWHCODE='0001' "
      END       
      
      --NJOW05
      SELECT @b_success = 0
      Execute nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      @c_Sku,                    
      'nspPR_TH01_ChkM-SCPO', -- Configkey
      @b_success         OUTPUT,
      @c_ChkM_SCPO       OUTPUT,
      @n_err             OUTPUT,
      @c_errmsg          OUTPUT
      
      IF @c_ChkM_SCPO = '1'
      BEGIN
      	 SELECT @c_OrderType = TYPE  
         FROM   ORDERS WITH (NOLOCK)  
         WHERE  OrderKey = LEFT(@c_OtherParms, 10)   

      	 IF @c_OrderType = 'M-SCPO'
      	 BEGIN
      	    SELECT @c_Condition = " AND LOTTABLE01 = 'S' "
            SELECT @c_ConditionWHCode = " AND LOC.HOSTWHCODE='0003' "
         END
      END
            
      IF ISNULL(@c_Lottable02,'') <> ''      
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
      END
      IF ISNULL(@c_Lottable03,'') <> ''      
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = '" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = '" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
      END
 
      IF @n_OutGoingMinshelfLife <> 0  --NJOW01
      BEGIN
         /*IF @n_OutGoingMinshelfLife < 13  -- it's month
         BEGIN
            SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND convert(char(8),Lottable04, 112) >= '"  + convert(char(8), dateadd(month, @n_OutGoingMinshelfLife, getdate()), 112) + "'"
         END
         ELSE 
         BEGIN*/
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND convert(char(8),Lottable04, 112) >= '" + convert(char(8), DateAdd(day, @n_OutGoingMinshelfLife, getdate()), 112) + "'"
         --END      	 
      END
      ELSE IF @n_StorerMinShelfLife <> 0
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() " 
      END 
      
     SELECT @c_SQLStatement =  " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  " +
            " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)     " + 
            " WHERE LOT.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOT.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOT.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.Lot = LOT.LOT " +
      	   " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " +
      	   " AND LOTXLOCXID.LOC = LOC.LOC " +
            " AND LOTxLOCxID.ID = ID.ID " +
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' " + @c_ConditionWHCode + -- AND LOC.HOSTWHCODE='0001' "  +
            " AND LOC.LocationFlag = 'NONE' " + 
      	   " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "' " +
            " AND LOTATTRIBUTE.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND LOTATTRIBUTE.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            dbo.fnc_RTrim(@c_Condition)  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable02, Lotattribute.Lottable04 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  " 
            --" ORDER BY Lotattribute.Lottable04, 4 DESC, LOT.Lot " 
            
      --NJOW06     
      SELECT @b_success = 0
      Execute nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      @c_Sku,                    
      'nspPR_TH01_SortInclLot2', -- Configkey
      @b_success         OUTPUT,
      @c_PR_TH01_SortInclLot2 OUTPUT,
      @n_err             OUTPUT,
      @c_errmsg          OUTPUT
      
      --NJOW04      
      SELECT @b_success = 0
      Execute nspGetRight 
      @c_facility,  
      @c_StorerKey,              
      @c_Sku,                    
      'nspPR_TH01_SortByMaxBal', -- Configkey
      @b_success         OUTPUT,
      @c_Sortbymaxqtybal OUTPUT,
      @n_err             OUTPUT,
      @c_errmsg          OUTPUT
  
      IF @b_success = 1 
      BEGIN
      	 IF ISNULL(@c_PR_TH01_SortInclLot2,'') = '1' AND ISNULL(@c_Sortbymaxqtybal,'') = '1' --NJOW06
            SELECT @c_SQLStatement = @c_SQLStatement + " ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable02, 4 DESC, LOT.Lot " 
      	 ELSE IF ISNULL(@c_PR_TH01_SortInclLot2,'') = '1' AND ISNULL(@c_Sortbymaxqtybal,'') <> '1' --NJOW06 	 
            SELECT @c_SQLStatement = @c_SQLStatement + " ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable02, LOT.Lot " 
      	 ELSE IF ISNULL(@c_PR_TH01_SortInclLot2,'') <> '1' AND ISNULL(@c_Sortbymaxqtybal,'') = '1'  
            SELECT @c_SQLStatement = @c_SQLStatement + " ORDER BY Lotattribute.Lottable04, 4 DESC, LOT.Lot " 
         ELSE
            SELECT @c_SQLStatement = @c_SQLStatement + " ORDER BY Lotattribute.Lottable04, LOT.Lot " 
      END
      ELSE
      BEGIN
         SELECT @c_SQLStatement = @c_SQLStatement + " ORDER BY Lotattribute.Lottable04, LOT.Lot " 
      END                        

      EXEC(@c_SQLStatement)
   
   END
END

GO