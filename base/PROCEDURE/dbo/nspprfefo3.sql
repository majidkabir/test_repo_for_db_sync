SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRFEFO3                                         */
/* Creation Date: 07-Apr-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: PreAllocateStrategy : First Expired First Out               */
/* 			Similar to nspPR_FEFO, modified for lot03 specific 			*/
/*			   UOM generated is 7=Piece/Each (special)							*/
/*                                                                      */
/* Called By: nspOrderProcessing		                                    */
/*                                                                      */
/* PVCS Version: 1.2		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 01-Aug-2008  YokeBeen  SOS#113059 - Modified requirements for        */
/*                        allocation. - (YokeBeen01)                    */
/* 07-Aug-2008  YokeBeen  Modified for SQL2005 Compatible.              */
/* 12-Aug-2008  TLTING    Remove SET some Option                        */
/* 26-Apr-2015  TLTING01 1.1  Add Other Parameter default value         */ 
/************************************************************************/

CREATE PROC [dbo].[nspPRFEFO3]
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
           @c_SQLStatement NVARCHAR(3999) 	   	  
	
   IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)),'') <> ''
   BEGIN
      /* Get Storer Minimum Shelf Life */      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
        FROM Sku WITH (NOLOCK) 
        JOIN Storer WITH (NOLOCK) ON (Sku.Storerkey = Storer.Storerkey) 
        JOIN Lot WITH (NOLOCK) ON (Lot.Sku = Sku.Sku AND LOT.Storerkey = SKU.Storerkey)
      WHERE Lot.Lot = @c_lot
      AND Sku.Facility = @c_facility  
      
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
              QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT WITH (NOLOCK) 
         JOIN Lotattribute WITH (NOLOCK) ON (Lot.Lot = Lotattribute.Lot AND LOT.Sku = LOTATTRIBUTE.Sku) 
        WHERE LOT.LOT = @c_lot 
          AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
        ORDER BY Lotattribute.Lottable04, Lot.Lot
   END
   ELSE
   BEGIN
	   /* Get Storer Minimum Shelf Life */
	   SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
	     FROM Sku WITH (NOLOCK) 
        JOIN Storer WITH (NOLOCK) ON (Sku.Storerkey = Storer.Storerkey) 
	    WHERE Sku.Sku = @c_sku
	      AND Sku.Storerkey = @c_storerkey   
	      AND Sku.Facility = @c_facility  
	
	   IF @n_StorerMinShelfLife IS NULL
	      SELECT @n_StorerMinShelfLife = 0
	
      IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)),'') <> '' 
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + ''' ' 
      END
      IF ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)),'') <> '' 
      BEGIN
         SELECT @c_Condition = ISNULL(dbo.fnc_RTrim(@c_Condition),'') + ' AND LOTTABLE02 = N''' + 
                               ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)),'') + ''' ' 
      END

      IF ISNULL(RTRIM(@c_Lottable03),'') = '' OR @c_Lottable03 IS NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND 1=2 '
      END

      IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = ISNULL(dbo.fnc_RTrim(@c_Condition),'') + ' AND LOTTABLE04 = N''' + 
                               ISNULL(dbo.fnc_RTrim(CONVERT(char(20), @d_Lottable04, 106)),'') + ''' '
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = ISNULL(dbo.fnc_RTrim(@c_Condition),'') + ' AND LOTTABLE05 = N''' + 
                               ISNULL(dbo.fnc_RTrim(CONVERT(char(20), @d_Lottable05, 106)),'') + ''' ' 
      END

      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = ISNULL(dbo.fnc_RTrim(@c_Condition),'') + ' AND DateAdd(Day, ' + 
                               CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', Lotattribute.Lottable04) > GetDate() ' 
      END 
   	
		SELECT @c_SQLStatement =  ' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
            ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, ' +
            ' QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  ' +
            ' FROM LOTATTRIBUTE WITH (NOLOCK) ' +
            ' JOIN LOT WITH (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT AND LOT.SKU = LOTATTRIBUTE.SKU) ' + 
            ' JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT AND ' + 
            ' LOTXLOCXID.SKU = LOT.SKU) ' + 
            ' JOIN LOC WITH (NOLOCK) ON (LOTXLOCXID.LOC = LOC.LOC) ' + 
            ' JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' + 
            ' WHERE LOT.STORERKEY = N''' + ISNULL(dbo.fnc_RTrim(@c_storerkey),'') + ''' ' +
            ' AND LOT.SKU = N''' + ISNULL(dbo.fnc_RTrim(@c_SKU),'') + ''' ' +
            ' AND LOT.STATUS = ''OK'' ' +
            ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' ' + 
            ' AND LOC.LocationFlag = ''NONE'' ' + 
      	   ' AND LOC.Facility = N''' + ISNULL(dbo.fnc_RTrim(@c_facility),'') + ''' ' +
            ' AND LOTATTRIBUTE.STORERKEY = N''' + ISNULL(dbo.fnc_RTrim(@c_storerkey),'') + ''' ' +
            ' AND LOTATTRIBUTE.SKU = N''' + ISNULL(dbo.fnc_RTrim(@c_SKU),'') + ''' ' +
				' AND LOTATTRIBUTE.Lottable03 <> '''' ' +  -- (YokeBeen01)
              ISNULL(dbo.fnc_RTrim(@c_Condition),'')  + 
            ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable04 ' +
            ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)   > 0  ' +
            ' ORDER BY Lotattribute.Lottable04, LOT.Lot ' 
	
	   EXEC(@c_SQLStatement)
	
	   --print @c_SQLStatement
 	END -- Lot is Null
END

GO