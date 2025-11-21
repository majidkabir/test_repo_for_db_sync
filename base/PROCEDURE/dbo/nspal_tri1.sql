SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Stored Procedure: nspAL_TRI1                                         */            
/* Creation Date: 20/11/2017                                            */            
/* Copyright: LFL                                                       */            
/* Written by:                                                          */            
/*                                                                      */            
/* Purpose: WMS-3642 SG/TH Triple Allocate full UCC(2) from racking and */            
/*          Piece(6) from racking then shelving                         */
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
/* 14-Nov-2018  NJOW01    1.0   WMS-6765 add filter for XDOCK orders    */
/* 13-Oct-2022  NJOW02    1.1   WMS-20993 FIFO allocation for certain   */
/*                              orders                                  */
/* 13-Oct-2022  NJOW02    1.1   DEVOPS Combine Script                   */
/************************************************************************/            

CREATE PROC [dbo].[nspAL_TRI1]
   @c_Orderey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,    
   @c_Lottable06 NVARCHAR(30),    
   @c_Lottable07 NVARCHAR(30),    
   @c_Lottable08 NVARCHAR(30),    
   @c_Lottable09 NVARCHAR(30),    
   @c_Lottable10 NVARCHAR(30),    
   @c_Lottable11 NVARCHAR(30),    
   @c_Lottable12 NVARCHAR(30),    
   @d_Lottable13 DATETIME,    
   @d_Lottable14 DATETIME,    
   @d_Lottable15 DATETIME,    
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN   
   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition          NVARCHAR(MAX),
           @c_SQL                NVARCHAR(MAX), 
           @c_OrderKey           NVARCHAR(10),        
           @c_OrderLine          NVARCHAR(5),
           @c_Country            NVARCHAR(30),
           @n_QtyToTake          INT,
           @n_QtyAvailable       INT,
           --@n_PrevQtyAvailable   INT,
           @c_Lottable08Found    NVARCHAR(30),
           @c_FirstLottable08    NVARCHAR(30),
           @dt_Lottable05Found   DATETIME,
           --@dt_FirstLottable05   DATETIME,
           @c_Short              NVARCHAR(10),
           @c_Lot                NVARCHAR(10),
           @c_Loc                NVARCHAR(10), 
           @c_ID                 NVARCHAR(18),
           @c_UCCQty             INT,
           @c_LocationCategory   NVARCHAR(10),
           @n_PackQty            INT,
           @c_OtherValue         NVARCHAR(20),
           @n_UCCQty             INT,
           @c_LocationType       NVARCHAR(10),
           @c_OrderType          NVARCHAR(10),  --NJOW01
           @c_GroupingFields     NVARCHAR(200), --NJOW02
           @c_OrderGroup         NVARCHAR(10) --NJOW02
       
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
       SET @c_OrderKey  = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)            
       SET @c_OrderLine = SUBSTRING(RTRIM(@c_OtherParms) ,11 ,5)       
       
       --NJOW01
       IF ISNULL(@c_OrderLine,'') <> '' AND ISNULL(@c_Orderkey,'') <> ''
       BEGIN
          SELECT @c_OrderType = TYPE,
                 @c_Country = C_Country,
                 @c_OrderGroup = OrderGroup --NJOW02
          FROM ORDERS (NOLOCK)
          WHERE Orderkey = @c_Orderkey
       END
       ELSE   
       BEGIN
       	  --NJOW02
       	  SET @c_GroupingFields = SUBSTRING(RTRIM(@c_OtherParms) ,17, 184)   
          SELECT @c_OrderType = ColValue FROM dbo.fnc_DelimSplit(',',@c_GroupingFields) WHERE SeqNo = 1
          SELECT @c_Country = ColValue FROM dbo.fnc_DelimSplit(',',@c_GroupingFields) WHERE SeqNo = 2
          SELECT @c_OrderGroup = ColValue FROM dbo.fnc_DelimSplit(',',@c_GroupingFields) WHERE SeqNo = 3
       END       
   END        
                 
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
   	  IF @c_OrderType NOT IN('FTAD','NONFTA','NON-FTA','NA') --NJOW01 
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
   IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900"
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900"
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
   ELSE 
   	  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE07 = N'' " 
   	  
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
   IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> "01/01/1900"
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + "' "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> "01/01/1900"
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + "' "
   END
   IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> "01/01/1900"
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = N'" + dbo.fnc_RTrim(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + "' "
   END

   IF @c_UOM IN ('1','2')  --pallet / case only allocate from racking. 
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.LocationCategory IN ('RACK','RACKING') AND SKUXLOC.LocationType NOT IN('PICK','CASE') "
   END
   ELSE
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.LocationCategory IN ('RACK','RACKING','SHELVING') "
   END
    
   IF @n_StorerMinShelfLife > 0 
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() "       
   END 
   
   IF ISNULL(@c_Country,'') <> ''
   BEGIN
   	 SELECT TOP 1 @c_Short = CODELKUP.Short 
   	 FROM CODELKUP(NOLOCK) 
   	 WHERE Listname = 'TRIPLESOCO' 
      AND Storerkey = @c_Storerkey
      AND Short = @c_Country
   END
   
   IF ISNULL(@c_Short,'') <> '' 
   BEGIN
      SELECT TOP 1 @c_FirstLottable08 = LA.Lottable08
      FROM PICKDETAIL PD (NOLOCK)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
      WHERE Orderkey = @c_Orderkey
      ORDER BY LA.Lottable08 DESC
      
      IF ISNULL(@c_FirstLottable08,'') <> ''
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE08 = N'" + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FirstLottable08)) + "' "
      END      
   END   
   
   --NJOW01
   IF @c_OrderType = 'FTAE' AND ISNULL(@c_Lottable01,'') <> ''
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = N'BONDED' "
   END

   IF @c_OrderType IN('FTAD','NONFTA','NON-FTA','NA') 
   BEGIN
      SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = N'NONBOND' "
   END
   
   SELECT @c_SQL = "DECLARE CURSOR_TRI_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
          " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
          " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),  " +
          " LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable08, LOC.LocationCategory, SKUXLOC.LocationType " +
          " FROM LOTATTRIBUTE (NOLOCK) " +
          " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
          " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT " + 
          " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
          " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
          " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
          " WHERE LOT.STORERKEY = @c_storerkey " +
          " AND LOT.SKU = @c_SKU " +
          " AND LOT.STATUS = 'OK' " +
          " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
          " AND LOC.LocationFlag = 'NONE' " + 
    	    " AND LOC.Facility = @c_facility " + 
          " AND LOTATTRIBUTE.STORERKEY = @c_storerkey " +
          " AND LOTATTRIBUTE.SKU = @c_SKU " +
          " AND LOC.LocationCategory <> 'FLOWRACK' " +
          RTRIM(@c_Condition)  + 
          " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable08, LOC.LocationCategory, LOC.Loc, LOC.LogicalLocation, SKUXLOC.LocationType " +
          " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0 " + 
          " ORDER BY LOTATTRIBUTE.Lottable05 " + CASE WHEN (@c_Country='SGP' AND @c_OrderType IN('NONFTA','NON-FTA')) OR @c_OrderGroup='ECOM' THEN ' ASC ' ELSE ' DESC ' END +  --NJOW02
          "        , CASE WHEN LOC.LocationCategory IN('RACK','RACKING') AND SKUXLOC.LocationType NOT IN('PICK','CASE') THEN 1 ELSE 2 END, LOT.Lot DESC, LOC.LogicalLocation, LOC.Loc "  --loose allocate from rack then shelving

   EXEC sp_executesql @c_SQL 
      , N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5)'             
      , @c_StorerKey
      , @c_Sku
      , @c_Facility
   
   SET @c_SQL = ''
   --SET @n_PrevQtyAvailable = 0
   
   OPEN CURSOR_TRI_AVAILABLE                    
   FETCH NEXT FROM CURSOR_TRI_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @dt_Lottable05Found, @c_Lottable08Found, @c_LocationCategory, @c_LocationType
   
   --SET @dt_FirstLottable05 = @dt_Lottable05Found 

   SET @c_FirstLottable08 = @c_Lottable08Found
      
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
   BEGIN           	
      SET @n_QtyToTake = 0
      
      IF ISNULL(@c_Short,'') <> '' AND @c_Lottable08Found <> @c_FirstLottable08
      BEGIN
         GOTO NEXT_REC
      END
      
      SET @n_PackQty = @n_UOMBase
      SET @n_UCCQty = 0
      SET @c_OtherValue = '1'
      
      /*IF @c_LocationCategory IN('RACK','RACKING') AND @c_LocationType NOT IN('PICK','CASE') AND @c_UOM = '2'
      BEGIN
         SELECT TOP 1 @n_UCCQty = Qty  --Expect the location have same UCC qty
         FROM UCC (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
         AND Lot = @c_Lot
         AND Loc = @c_Loc
         AND Id = @c_Id
         AND Status < '3'     
         ORDER BY Qty DESC
         
         IF @n_UCCQty > 0
         BEGIN
            SET @n_PackQty = @n_UCCQty
            SET @c_OtherValue = 'UOM=' + LTRIM(CAST(@n_UCCQty AS NVARCHAR)) --instruct the allocation to take this as casecnt
         END
      END*/
                        
   	  /*IF @c_UOM NOT IN('6','7')
   	  BEGIN
   	  	  IF (DATEDIFF(day, @dt_FirstLottable05, @dt_Lottable05Found) > 0 AND @n_PrevQtyAvailable >= @n_QtyLeftToFulfill)   --Not to take full pack(pallet/carton) from next lot if current lot have loose qty can fulfil
   	  	     OR (@n_QtyLeftToFulfill < @n_UOMBase)  --No more fulll pack require
   	  	  	 BREAK
   	  	  ELSE
       	     IF @n_QtyAvailable > @n_QtyLeftToFulfill
   	           SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
   	        ELSE
   	           SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase      	           	  
   	  END
   	  ELSE
   	  BEGIN*/ 
   	     	     
   	     IF @n_QtyAvailable > @n_QtyLeftToFulfill
   	        SET @n_QtyToTake = FLOOR(@n_QtyLeftToFulfill / @n_PackQty) * @n_PackQty
   	     ELSE
   	        SET @n_QtyToTake = FLOOR(@n_QtyAvailable / @n_PackQty) * @n_PackQty      	           	  
   	  --END      
   	        	 
   	  IF @n_QtyToTake > 0       	        	  
   	  BEGIN
          IF ISNULL(@c_SQL,'') = ''
          BEGIN
             SET @c_SQL = N'   
                   DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                   SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                   '             
          END
          ELSE
          BEGIN
             SET @c_SQL = @c_SQL + N'  
                   UNION ALL
                   SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                   '
          END
       END
      
   	  SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake                	 
      --SET @n_PrevQtyAvailable = @n_PrevQtyAvailable + (@n_QtyAvailable - @n_QtyToTake)
      
      NEXT_REC:
             
      FETCH NEXT FROM CURSOR_TRI_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Loc, @c_ID, @n_QtyAvailable, @dt_Lottable05Found, @c_Lottable08Found, @c_LocationCategory, @c_LocationType 
   END -- END WHILE FOR CURSOR_TRI_AVAILABLE                
         
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_TRI_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_TRI_AVAILABLE          
      DEALLOCATE CURSOR_TRI_AVAILABLE          
   END    
   
   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END            

   EXIT_SP:
END

GO