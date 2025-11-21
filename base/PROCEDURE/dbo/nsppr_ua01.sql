SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/            
/* Stored Procedure: nspPR_UA01                                         */            
/* Creation Date: 12/06/2015                                            */            
/* Copyright: LF                                                        */            
/* Written by:                                                          */            
/*                                                                      */            
/* Purpose: 342109-CN Under Armour (UA) Allocation Strategy             */     
/*          Full carton from bulk                                       */       
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
/* Date        Author  Ver.  Purposes                                   */       
/* 26-Aug-2015 NJOW01  1.0   filter lot with full carton only.          */     
/*                           Fix lot preallocated qty filter by         */
/*                           PreAllocatePickCode                        */        
/* 25-Aug-2017 NJOW02  1.1   WMS-1995 Use pack.casecnt instead of lot10 */
/*                           if AllocateGetCasecntFrLottable is turned  */
/*                           off                                        */
/* 24-Apr-2018 TLTING  1.2   Dynamic SQL cache issue                    */
/* 12-Jul-2018 NJOW03  1.3   WMS-5692 Change lot sorting by locationgroup*/
/*                           for full case. CN only.                    */
/* 10-Sep-2021 NJOW04  1.4   WMS-17912 new logic for HK UA. Allocate    */
/*                           location sequence from dynppick and pick.  */
/*                           Filter lottable07                          */           
/* 16-Oct-2021 NJOW04  1.4   DEVOPS combine script                      */
/************************************************************************/            

CREATE PROC [dbo].[nspPR_UA01]
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
   
   DECLARE @n_StorerMinShelfLife           INT,
           @c_Condition                    NVARCHAR(MAX)='',
           @c_SQL                          NVARCHAR(MAX), 
           @c_SQLParm                      NVARCHAR(2000),
           @c_OrderKey                     NVARCHAR(10),        
           @c_OrderLine                    NVARCHAR(5),   
           @n_QtyToTake                    INT,
           @n_QtyAvailable                 INT,
           @n_Casecnt                      INT,
           @n_CaseAvailable                INT,
           @n_CaseNeed                     INT,
           @c_Country                      NVARCHAR(30),
           @c_AllocateGetCasecntFrLottable NVARCHAR(10), --NJOW02
           @c_countryflag                  NVARCHAR(10) --NJOW03
   
   --NJOW03        
   SELECT @c_countryflag = NSQLValue
   FROM NSQLCONFIG (NOLOCK)
   WHERE Configkey = 'Country'        
	                 
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
       SET @c_OrderKey  = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)            
       SET @c_OrderLine = SUBSTRING(RTRIM(@c_OtherParms) ,11 ,5)       
       
       SELECT @c_Country = C_Country
       FROM ORDERS(NOLOCK)
       WHERE Orderkey = @c_Orderkey               
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
         SELECT @c_Condition = " AND LOTTABLE01 = @c_Lottable01 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE02 = @c_Lottable02 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE03 = @c_Lottable03 "
      END
            IF CONVERT(NVARCHAR(10), @d_Lottable04, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE04 = @d_Lottable04 "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable05, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE05 = @d_Lottable05 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable06)) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE06 = @c_Lottable06 "
      END
      IF (dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable07)) <> '' AND @c_Lottable07 IS NOT NULL)
         OR @c_countryflag = 'HK' --NJOW04
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE07 = @c_Lottable07 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable08)) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE08 = @c_Lottable08 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable09)) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE09 = @c_Lottable09 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable10)) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE10 = @c_Lottable10 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable11)) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE11 = @c_Lottable11 "
      END
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable12)) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE12 = @c_Lottable12 "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable13, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE13 = @d_Lottable13 "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable14, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE14 = @d_Lottable14 "
      END
      IF CONVERT(NVARCHAR(10), @d_Lottable15, 103) <> "01/01/1900"
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTTABLE15 = @d_Lottable15 "
      END

      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day,  @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() "       
      END 
      
      IF ISNULL(@c_Country,'') <> ''
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTATTRIBUTE.Lottable08 NOT IN (SELECT Code2 FROM CODELKUP(NOLOCK) WHERE Listname = N'UACOOBLK' " +  
                " AND Storerkey =  @c_Storerkey AND Short = @c_Country ) " 
      END
      
      --NJOW04
      IF @c_countryflag = 'HK'
      	  SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.Locationtype = 'OTHER' " 
      ELSE
          SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') AND LOC.Locationtype NOT IN ('DYNPPICK') " 
         
     IF @c_countryflag = 'CN' AND @c_UOM = '2'      
     BEGIN
     	  --NJOW03
        SELECT @c_SQL = " DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
               " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable10, " +
               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) )  " +
               " FROM LOTATTRIBUTE (NOLOCK) " +
               " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
               " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT " + 
               " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
               " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
               " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
               " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +         
               "       FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
               "       WHERE p.Orderkey = ORDERS.Orderkey " +         
               "       AND   p.Storerkey = @c_storerkey " +         
               "       AND   p.SKU = @c_SKU " +         
               "       AND   P.PreAllocatePickCode IN('nspPR_UA01','nspPR_UA03') " + --NJOW01
               "       GROUP BY p.Lot, ORDERS.Facility ) p ON LOT.Lot = p.Lot " +         
               "             AND p.Facility = LOC.Facility " +                                
               " WHERE LOT.STORERKEY = @c_storerkey " +
               " AND LOT.SKU = @c_SKU " +
               " AND LOT.STATUS = 'OK' " +
               " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
               " AND LOC.LocationFlag = 'NONE' " + 
         	     " AND LOC.Facility = @c_facility " + 
               --" AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') " +
               --" AND LOC.Locationtype NOT IN ('DYNPPICK') " + 
               " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen >= @n_uombase " + --NJOW01
               dbo.fnc_RTrim(@c_Condition)  + 
               " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable10, LOC.LocationGroup, LOC.LocLevel " +
               " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) >= CAST(LOTATTRIBUTE.Lottable10 AS INT) " +  --NJOW01
               " ORDER BY LOC.LocationGroup, LOC.LocLevel, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot " 
     END
     ELSE
     BEGIN
        SELECT @c_SQL = " DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR " +
               " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable10, " +
               " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) )  " +
               " FROM LOTATTRIBUTE (NOLOCK) " +
               " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
               " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT " + 
               " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
               " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
               " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
               " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +         
               "       FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
               "       WHERE p.Orderkey = ORDERS.Orderkey " +         
               "       AND   p.Storerkey = @c_storerkey " +         
               "       AND   p.SKU = @c_SKU " +         
               "       AND   P.PreAllocatePickCode IN('nspPR_UA01','nspPR_UA03') " + --NJOW01
               "       GROUP BY p.Lot, ORDERS.Facility ) p ON LOT.Lot = p.Lot " +         
               "             AND p.Facility = LOC.Facility " +                                
               " WHERE LOT.STORERKEY = @c_storerkey " +
               " AND LOT.SKU = @c_SKU " +
               " AND LOT.STATUS = 'OK' " +
               " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
               " AND LOC.LocationFlag = 'NONE' " + 
         	     " AND LOC.Facility = @c_facility " + 
               --" AND SKUXLOC.Locationtype NOT IN ('PICK','CASE') " +
               --" AND LOC.Locationtype NOT IN ('DYNPPICK') " + 
               " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen >= CAST(LOTATTRIBUTE.Lottable10 AS INT) " + --NJOW01
               dbo.fnc_RTrim(@c_Condition)  + 
               " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOTATTRIBUTE.Lottable10 " +
               " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) >= CAST(LOTATTRIBUTE.Lottable10 AS INT) " +  --NJOW01
               " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot " 
      END       
             
      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
                         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
                         '@c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_StorerMinShelfLife INT,  @c_Country Nvarchar(30), 		@n_uombase INT ' --NJOW03    
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
                         @n_StorerMinShelfLife, @c_Country, @n_uombase --NJOW03   
 
   
      SET @c_SQL = ''
      SET @c_SQLParm = ''
      SET @n_QtyToTake = 0
      SET @n_CaseAvailable = 0
      SET @n_CaseNeed = 0
      
      SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable')  --NJOW02 
      
      SELECT @n_Casecnt = PACK.Casecnt
      FROM SKU (NOLOCK) 
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      WHERE SKU.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_Sku
                  
      OPEN CURSOR_AVAILABLE                    
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Storerkey, @c_Sku, @c_LOT, @c_Lottable10, @n_QtyAvailable   
             
      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)          
      BEGIN 
  	     IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW02
  	     BEGIN   
      	    SET @n_Casecnt = 0
      	 
      	    IF ISNUMERIC(@c_Lottable10) = 1
      	       SELECT @n_Casecnt = CAST(@c_Lottable10 AS INT)      	       
      	 END
      	 
    	   IF @n_Casecnt = 0
      	    BREAK
      	
      	 SELECT @n_CaseAvailable = Floor(@n_QtyAvailable / @n_Casecnt)
      	 SELECT @n_CaseNeed = Floor(@n_QtyLeftToFulFill / @n_Casecnt)
      	 
      	 IF @n_CaseNeed = 0 OR @n_CaseAvailable = 0
      	    BREAK
      	    
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