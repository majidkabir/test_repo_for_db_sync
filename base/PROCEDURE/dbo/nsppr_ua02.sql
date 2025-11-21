SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/*************************************************************************/            
/* Stored Procedure: nspPR_UA02                                          */            
/* Creation Date: 12/06/2015                                             */            
/* Copyright: LF                                                         */            
/* Written by:                                                           */            
/*                                                                       */            
/* Purpose: 342109-CN Under Armour (UA) Allocation Strategy              */            
/*          loose carton from DPP                                        */       
/*                                                                       */            
/* Called By:                                                            */            
/*                                                                       */            
/* PVCS Version: 1.0                                                     */            
/*                                                                       */            
/* Version: 5.4                                                          */            
/*                                                                       */            
/* Data Modifications:                                                   */            
/*                                                                       */            
/* Updates:                                                              */            
/* Date         Author    Ver.  Purposes                                 */            
/* 27-Aug-2015  NJOW01    1.0   Fix lot preallocated qty filter by       */
/*                              PreAllocatePickCode                      */
/* 24-Apr-2018  TLTING    1.1   Dynamic SQL cache issue                  */        
/* 10-Sep-2021  NJOW02    1.2   WMS-17912 new logic for HK UA. Allocate  */
/*                              location sequence from dynppick and pick.*/
/*                              Filter lottable07                        */                                        
/* 16-Oct-2021  NJOW02    1.2   DEVOPS combine script                    */
/*************************************************************************/            

CREATE PROC [dbo].[nspPR_UA02]
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
           @c_Condition    NVARCHAR(MAX)='',
           @c_SQL          NVARCHAR(MAX), 
           @c_SQLParm      NVARCHAR(2000),
           @c_OrderKey     NVARCHAR(10),        
           @c_OrderLine    NVARCHAR(5),   
           @n_QtyToTake     INT,
           @n_QtyAvailable  INT,
           @n_Casecnt       INT,
           @n_CaseAvailable INT,
           @n_CaseNeed      INT,
           @c_Country       NVARCHAR(30),
           @c_countryflag   NVARCHAR(10), --NJOW02     
           @c_Orderby       NVARCHAR(1000)='', --NJOW02
           @c_Groupby       NVARCHAR(1000)='' --NJOW02
    
   IF ISNULL(RTRIM(@c_OtherParms) ,'')<>''          
   BEGIN        
       SET @c_OrderKey  = SUBSTRING(RTRIM(@c_OtherParms) ,1 ,10)            
       SET @c_OrderLine = SUBSTRING(RTRIM(@c_OtherParms) ,11 ,5)       
       
       SELECT @c_Country = C_Country
       FROM ORDERS(NOLOCK)
       WHERE Orderkey = @c_Orderkey               
   END        
   
   --NJOW02        
   SELECT @c_countryflag = NSQLValue
   FROM NSQLCONFIG (NOLOCK)
   WHERE Configkey = 'Country'         
                 
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
         OR @c_countryflag = 'HK' --NJOW02
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
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() "       
      END 
      
      IF ISNULL(@c_Country,'') <> ''
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOTATTRIBUTE.Lottable08 NOT IN (SELECT Code2 FROM CODELKUP(NOLOCK) WHERE Listname = N'UACOOBLK' " +  
                " AND Storerkey = @c_Storerkey AND Short = @c_Country ) " 
      END
      
      --NJOW02
      IF @c_countryflag = 'HK'
      BEGIN
        SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.Locationtype IN ('DYNPPICK','PICK') "
        SELECT @c_Orderby = " ORDER BY CASE WHEN LOC.LocationType = 'DYNPPICK' THEN 1 ELSE 2 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "
        SELECT @c_GroupBy = " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOC.LocationType "
      END  
      ELSE
      BEGIN
        SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + " AND LOC.Locationtype IN ('DYNPPICK') "
        SELECT @c_Orderby = " ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot "
        SELECT @c_GroupBy = " GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 "
      END
   
     SELECT @c_SQL = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +
            " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +
            " QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) )  " +
            " FROM LOTATTRIBUTE (NOLOCK) " +
            " JOIN LOT (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +
            " JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT   " + 
            " JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc " +
            " JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +
            " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
            " LEFT OUTER JOIN (SELECT p.lot, ORDERS.facility, QtyPreallocated = SUM(p.Qty) " +         
            "       FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +
            "       WHERE p.Orderkey = ORDERS.Orderkey " +         
            "       AND   p.Storerkey = @c_storerkey " +         
            "       AND   p.SKU = @c_SKU " +    
            "       AND   P.PreAllocatePickCode = 'nspPR_UA02' " +   --NJOW01  
            "       GROUP BY p.Lot, ORDERS.Facility) p ON LOTXLOCXID.Lot = p.Lot " +         
            "             AND p.Facility = LOC.Facility " +                                
            " WHERE LOT.STORERKEY = @c_storerkey " +
            " AND LOT.SKU = @c_SKU " +
            " AND LOT.STATUS = 'OK' " +
            " AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  " + 
            " AND LOC.LocationFlag = 'NONE' " + 
      	    " AND LOC.Facility = @c_facility " + 
            --" AND LOC.Locationtype IN ('DYNPPICK') " + 
            RTRIM(ISNULL(@c_Condition,''))  + 
            RTRIM(ISNULL(@c_groupBy,'')) +  --NJOW02
            --" GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 " +
            " HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - SUM(LOTxLOCxID.QtyReplen) - MAX(ISNULL(p.QTYPREALLOCATED,0)) > 0 " +
            ISNULL(@c_Orderby,'')  --NJOW02
            --" ORDER BY LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, LOT.Lot " 

      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
                         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
                         '@c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_StorerMinShelfLife INT,  @c_Country Nvarchar(30) '     
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
                         @n_StorerMinShelfLife, @c_Country   


  --    EXEC(@c_SQL)
      
   END

   EXIT_SP:
END

GO