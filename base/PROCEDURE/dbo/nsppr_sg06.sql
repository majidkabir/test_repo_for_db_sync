SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_SG06                                         */
/* Creation Date: 30-Apr-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-4778 SG BAT Pre-allocation by consignee shelf life      */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing		                          */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROC [dbo].[nspPR_SG06]
         @c_storerkey    NVARCHAR(15) ,
         @c_sku          NVARCHAR(20) ,
         @c_lot          NVARCHAR(10) ,
         @c_lottable01   NVARCHAR(18) ,
         @c_lottable02   NVARCHAR(18) ,
         @c_lottable03   NVARCHAR(18) ,
         @d_lottable04   datetime ,
         @d_lottable05   datetime ,
         @c_lottable06   NVARCHAR(30) , 
         @c_lottable07   NVARCHAR(30) , 
         @c_lottable08   NVARCHAR(30) , 
         @c_lottable09   NVARCHAR(30) , 
         @c_lottable10   NVARCHAR(30) , 
         @c_lottable11   NVARCHAR(30) , 
         @c_lottable12   NVARCHAR(30) , 
         @d_lottable13   DATETIME ,     
         @d_lottable14   DATETIME ,     
         @d_lottable15   DATETIME ,     
         @c_uom          NVARCHAR(10) ,
         @c_facility     NVARCHAR(10)  , 
         @n_uombase        int ,
         @n_qtylefttofulfill int,
         @c_OtherParms NVARCHAR(200)=''  
AS
BEGIN
   DECLARE @c_UOMBase NVARCHAR(10)

   IF @n_uombase <= 0 SELECT @n_uombase = 1
   SELECT @c_UOMBase = @n_uombase
   
   DECLARE @c_Condition NVARCHAR(4000), 
           @c_OrderBy   NVARCHAR(510),     
           @b_success int,
           @n_err int,
           @c_errmsg NVARCHAR(250),
           @n_shelflife int,
           @c_sql NVARCHAR(max),
           @c_OrderKey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_Susr1 NVARCHAR(18),
           @c_SQLStatement NVARCHAR(4000),
           @n_QtyToTake          INT,
           @n_QtyAvailable       INT,
           @n_PrevQtyAvailable   INT
              
   SELECT @c_Condition ='', @c_SQL = ''        

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL AND LEFT(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)), 1) <> "*" 
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
         FOR SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
                    QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM  LOT (nolock), LOTATTRIBUTE (nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK) 
         WHERE LOT.LOT = @c_lot
         AND LOT.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.Lot = LOT.LOT
         AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
         AND LOTXLOCXID.LOC = LOC.LOC
         AND LOC.Facility = @c_facility
         ORDER BY LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE05
   END
   ELSE
   BEGIN
      IF ISNULL(@c_OtherParms,'') <> ''
     	BEGIN
     	   SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
     	   SELECT @c_OrderLineNumber = SUBSTRING(RTRIM(@c_OtherParms),11,5)     	    
     	   
     	   SELECT @c_Susr1 = STORER.Susr1,  
     	          @n_shelflife  = ISNULL(STORER.MinShelfLife,0)
     	   FROM ORDERS (NOLOCK)
     	   JOIN STORER (NOLOCK) ON ORDERS.Consigneekey = STORER.Storerkey
     	   WHERE ORDERS.Orderkey = @c_Orderkey
     	   
     	   IF (ISNULL(@c_Susr1,'') <> 'LOOSE' AND @c_UOM IN(6,7)) OR ISNULL(@n_shelflife,0) = 0
     	   BEGIN
             DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    	   	
             SELECT TOP 0 NULL,NULL,NULL, 0 
             
             RETURN
     	   END 
     	END
     	
     	SELECT @n_shelflife = ISNULL(@n_shelflife,0)
     	    	
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> "" AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) + ''''
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> "" AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) + ''''
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> "" AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = N''' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) + ''''
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = '" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "'"
      END
           
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = N''' + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''''
      END
                  
      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   
 
      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(CHAR(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(CHAR(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = RTRIM(@c_Condition) + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
      
      IF @n_shelflife > 0
      BEGIN
         --SELECT @c_Condition = RTRIM(@c_Condition)  + ' AND CASE WHEN ISDATE(LEFT(Lottable03,8)) = 1 THEN DATEADD(Day, ' + RTRIM(CAST(@n_shelflife as NVARCHAR(10))) + ', CONVERT(DATETIME,LEFT(Lottable03,8))) ELSE GetDate() END <= GetDate() '		   	  	               	
         SELECT @c_Condition = RTRIM(@c_Condition)  + ' AND CASE WHEN ISDATE(LEFT(Lottable03,8)) = 1 THEN DATEDIFF(DAY,CONVERT(DATETIME,LEFT(Lottable03,8)),GETDATE()) ELSE 0 END <= ' + RTRIM(CAST(@n_shelflife AS NVARCHAR))		   	  	    
      END

      SET @c_OrderBy = ' ORDER BY LEFT(LOTATTRIBUTE.LOTTABLE03,8), LOTATTRIBUTE.LOTTABLE05, LOT.LOT '
            
      SELECT @c_sql = "DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR "
            + "SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, "
            + " QTYAVAILABLE = CASE WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) < " + @c_UOMBase +
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) % " + @c_UOMBase + " = 0 " +
            + "                THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                ELSE   " +
            + "                      SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0)) " +
            + "                      - ((SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) % " + @c_UOMBase + ") " +
            + "                END " + 
            + "FROM LOT (NOLOCK) "
            + "INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT "
            + "INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC "
            + "INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " 
            + "INNER JOIN ID  (NOLOCK) ON LOTXLOCXID.ID = ID.ID " 
            + "LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) "
            + "                  FROM   PreallocatePickDetail p (NOLOCK), ORDERS (NOLOCK) "
            + "                  WHERE  p.Orderkey = ORDERS.Orderkey "
            + "                  AND    p.Storerkey = N'" + @c_storerkey + "' " 
            + "                  AND    p.SKU = N'" + @c_sku + "' " 
            + "                  GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility "
            + "WHERE LOT.STORERKEY = N'" + @c_storerkey  + "' "
            + "AND LOT.SKU = '" + @c_sku + "' "
            + "AND LOC.Facility = N'" + @c_facility + "' "
            + "AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' AND LOC.LOCATIONFLAG <> 'HOLD' AND LOC.LOCATIONFLAG <> 'DAMAGE' "
            + "AND LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN "  
            + CASE WHEN ISNULL(@c_Susr1,'') = 'LOOSE' THEN ' > 0 ' ELSE ' >= ' + @c_UOMBase + " " END
            + @c_Condition   
            + "GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE05 "
            + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED - LOTXLOCXID.QTYREPLEN) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) "
            + CASE WHEN ISNULL(@c_Susr1,'') = 'LOOSE' THEN ' > 0 ' ELSE ' >= ' + @c_UOMBase + " " END            
            + @c_OrderBy
      
      EXEC ( @c_sql )      

      SET @c_SQLStatement = ''
      SET @n_PrevQtyAvailable = 0
      
      OPEN CURSOR_AVAILABLE                    
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable
            
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN           	
         SET @n_QtyToTake = 0
         
         IF ISNULL(@c_Susr1,'') = 'LOOSE'      	 
      	    SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_PrevQtyAvailable --to prevent take new lot if previous lot still have qty

         IF @n_QtyLeftToFulfill > 0      	  
      	 BEGIN 
      	    IF @n_QtyAvailable > @n_QtyLeftToFulfill
      	       SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
      	    ELSE
      	       SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase      	           	  

        	  SELECT @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake 
      	 END      
      	 
      	 IF @n_QtyToTake > 0       	      
      	 BEGIN  	  
            IF ISNULL(@c_SQLStatement,'') = ''
            BEGIN
               SET @c_SQLStatement = N'   
                     DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
            END
            ELSE
            BEGIN
               SET @c_SQLStatement = @c_SQLStatement + N'  
                     UNION ALL
                     SELECT '''  + @c_Storerkey + ''', ''' + @c_Sku + ''', ''' + @c_Lot + ''', ' + CAST(@n_QtyToTake AS NVARCHAR(10))
            END            
         END

    	 	 SET @n_PrevQtyAvailable = @n_QtyAvailable - @n_QtyToTake
                
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @n_QtyAvailable
      END -- END WHILE FOR CURSOR_AVAILABLE                
            
      IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
      BEGIN          
         CLOSE CURSOR_AVAILABLE          
         DEALLOCATE CURSOR_AVAILABLE          
      END    
      
      IF ISNULL(@c_SQLStatement,'') <> ''
      BEGIN
         EXEC sp_ExecuteSQL @c_SQLStatement
      END
      ELSE
      BEGIN
         DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TOP 0 NULL, NULL, NULL, NULL    
      END                        
   END
END 

GO