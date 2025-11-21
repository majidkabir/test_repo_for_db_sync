SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/            
/* Stored Procedure: nspPR_CH08                                         */            
/* Creation Date: 22/11/2016                                            */            
/* Copyright: LF                                                        */            
/* Written by:                                                          */            
/*                                                                      */            
/* Purpose: WMS-624 CN LBI MAST Backroom pre-allocation                 */     
/*          Full carton by lottable10(casecnt)                          */       
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
/* Date         Author    Ver.  Purposes                                */ 
/* 17-Apr-2017  TLTING    1.1   Performance tune                        */      
/************************************************************************/            

CREATE PROC [dbo].[nspPR_CH08]
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) , 
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_lottable06 NVARCHAR(30),
@c_lottable07 NVARCHAR(30),
@c_lottable08 NVARCHAR(30),
@c_lottable09 NVARCHAR(30),
@c_lottable10 NVARCHAR(30),
@c_lottable11 NVARCHAR(30),
@c_lottable12 NVARCHAR(30),
@d_lottable13 datetime,
@d_lottable14 datetime,
@d_lottable15 datetime,
@c_uom NVARCHAR(10) ,
@c_facility NVARCHAR(5),    
@n_uombase int ,
@n_qtylefttofulfill INT,
@c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition    NVARCHAR(MAX),
           @c_SQL          NVARCHAR(MAX), 
           @c_OrderKey     NVARCHAR(10),        
           @c_OrderLine    NVARCHAR(5),   
           @n_QtyToTake     INT,
           @n_QtyAvailable  INT,
           @n_Casecnt       INT,
           @n_CaseAvailable INT,
           @n_CaseNeed      INT
    
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
       SET @c_OrderKey  = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)            
       SET @c_OrderLine = SUBSTRING(RTRIM(@c_OtherParms) ,11 ,5)              
   END        
                 
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (Nolock), Lotattribute (Nolock)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable05, Lot.Lot
   END
   ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
   
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = " AND LOTTABLE01 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE07 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE08 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE09 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE10 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE11 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) + "' "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE12 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> "01/01/1900" AND @d_Lottable13 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> "01/01/1900" AND @d_Lottable14 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + "' "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> "01/01/1900" AND @d_Lottable15 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + "' "
      END

      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() "       
      END 
         
     SELECT @c_SQL = " DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable10, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) )  " +
            " FROM LOTATTRIBUTE (NOLOCK) " +
            " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
            " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " + 
            " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
            " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
            " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
            " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +         
            "       FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
            "       WHERE p.Orderkey = ORDERS.Orderkey " +         
            "       AND   p.Storerkey = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +         
            "       AND   p.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +         
          --"       AND   P.PreAllocatePickCode IN('nspPR_CH08') " + 
            "       GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot " +         
            "             AND p.Facility = LOC.Facility " +                                
            " WHERE SKUXLOC.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
            " AND SKUXLOC.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
            " AND LOC.LocationFlag = 'NONE' " + 
      	    " AND LOC.Facility = N'" + dbo.fnc_RTrim(@c_facility) + "' " + 
          --  " AND LOTATTRIBUTE.STORERKEY = N'" + dbo.fnc_RTrim(@c_storerkey) + "' " +
         --   " AND LOTATTRIBUTE.SKU = N'" + dbo.fnc_RTrim(@c_SKU) + "' " +
            " AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') " +
            " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen >= ISNULL(CAST(LOTATTRIBUTE.Lottable10 AS INT),0) " +
            dbo.fnc_RTrim(@c_Condition)  + 
            " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable10 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) >= ISNULL(CAST(LOTATTRIBUTE.Lottable10 AS INT),0) " +  
            " ORDER BY ISNULL(CAST(LOTATTRIBUTE.Lottable10 AS INT),0) DESC, LOTATTRIBUTE.Lottable05, LOT.Lot " 

      EXEC(@c_SQL)
   
      SET @c_SQL = ''
      SET @n_QtyToTake = 0
      SET @n_CaseAvailable = 0
      SET @n_CaseNeed = 0
      
      OPEN CURSOR_AVAILABLE                    
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Lottable10, @n_QtyAvailable   
             
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN    
      	 SET @n_Casecnt = 0
      	 
      	 IF ISNUMERIC(@c_Lottable10) = 1
      	    SELECT @n_Casecnt = CAST(@c_Lottable10 AS INT)
      	    
      	 IF @n_Casecnt = 0
      	    GOTO NEXTLOT
      	
      	 SELECT @n_CaseAvailable = Floor(@n_QtyAvailable / @n_Casecnt)
      	 SELECT @n_CaseNeed = Floor(@n_QtyLeftToFulFill / @n_Casecnt)
      	 
      	 IF @n_CaseNeed = 0 OR @n_CaseAvailable = 0
      	    GOTO NEXTLOT
      	    
      	 IF @n_CaseAvailable > @n_CaseNeed
      	    SELECT @n_QtyToTake = @n_CaseNeed * @n_Casecnt
      	 ELSE
      	    SELECT @n_QtyToTake = @n_CaseAvailable * @n_Casecnt
      	 
      	 IF @n_QtyToTake > 0
         BEGIN         	
            IF ISNULL(@c_SQL,'') = ''
            BEGIN
               SET @c_SQL = N'   
                     DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
            END
            ELSE
            BEGIN
               SET @c_SQL = @c_SQL + N'  
                     UNION ALL
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
            END

            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
         END
         
         NEXTLOT:
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Lottable10, @n_QtyAvailable 
      END -- END WHILE FOR CURSOR_AVAILABLE          
   END

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    

   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL    
   END   
END

GO