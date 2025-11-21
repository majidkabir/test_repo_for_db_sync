SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_PH04                                         */
/* Creation Date: 23-Jan-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-978 PH GCI PreAllocation Strategy - CASE(CARTON)        */
/*                                                                      */
/* Called By: nspPrealLOCateOrderProcessing                               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 17-Jan-2020  Wan01   1.1   Dynamic SQL review, impact SQL cache log  */  
/************************************************************************/

CREATE PROC [dbo].[nspPR_PH04]
   @c_storerkey NVARCHAR(15),
   @c_sku NVARCHAR(20),
   @c_lot NVARCHAR(10),
   @c_lottable01 NVARCHAR(18),
   @c_lottable02 NVARCHAR(18),
   @c_lottable03 NVARCHAR(18),
   @d_lottable04 DATETIME,
   @d_lottable05 DATETIME,
   @c_lottable06 NVARCHAR(30),
   @c_lottable07 NVARCHAR(30),
   @c_lottable08 NVARCHAR(30),
   @c_lottable09 NVARCHAR(30),
   @c_lottable10 NVARCHAR(30),
   @c_lottable11 NVARCHAR(30),
   @c_lottable12 NVARCHAR(30),
   @d_lottable13 DATETIME,
   @d_lottable14 DATETIME,
   @d_lottable15 DATETIME,
   @c_uom NVARCHAR(10),
   @c_facility NVARCHAR(10),
   @n_uombase INT,
   @n_qtylefttofulfill INT,
   @c_OtherParms NVARCHAR(200)
AS
BEGIN 
   DECLARE 
      @b_debug                   INT,
      @c_SQLStmt                 NVARCHAR(4000),
      @b_Success                 INT,
      @n_Err                     INT,
      @c_ErrMsg                  NVARCHAR(255),
      @c_LimitString             NVARCHAR(2000),  
      @c_OrderBy                 NVARCHAR(1000),
      @c_OrderKey                NVARCHAR(10),
      @c_OrderLineNumber         NVARCHAR(5),
      @n_SkuShelfLife            INT,
      @n_SkuOutgoingShelfLife    INT, -- SKU.Busr6
      @n_ConsigneeShelfLife      INT,
      @c_Lottable04label         NVARCHAR(20),
      @n_QtyAvailable            INT
           
   DECLARE @c_SQLParms           NVARCHAR(4000) = ''        --(Wan01)   
               
   SELECT @b_debug = 0
   SELECT @c_SQLStmt = '', @c_OrderBy = ''
   SELECT @c_errmsg = '', @n_err = 0, @b_success = 0, @c_LimitString = '', @c_LimitString = '', @c_Lottable04Label = '', @n_SkuOutgoingShelfLife = 0, @n_SkuShelfLife = 0

   IF ISNULL(@c_LOT,'') <> ''
   BEGIN
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, 
               QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0))
      FROM LOTXLOCXID (NOLOCK) 
         JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT
      JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
      JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID 
      LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) 
                               FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) 
                               WHERE  P.Orderkey = ORDERS.Orderkey 
                               AND    P.StorerKey = dbo.fnc_RTrim(@c_storerkey)
                               AND    P.SKU = dbo.fnc_RTrim(@c_sku)
                               AND    P.Qty > 0
                               GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility  
         WHERE LOTXLOCXID.LOT = @c_LOT
            AND LOTXLOCXID.Qty > 0
            AND LOT.Status = 'OK'
        AND ID.Status = 'OK' 
            AND LOC.Facility = dbo.fnc_RTrim(@c_facility)
        AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'
         GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT
        HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0
   END
   ELSE
   BEGIN    
      IF ISNULL(@c_OtherParms,'') <> ''
      BEGIN
         SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
         SELECT @c_OrderLineNumber = SUBSTRING(RTRIM(@c_OtherParms),11,5)           
      END
       
      SELECT @n_SkuShelfLife = ISNULL(SKU.Shelflife, 0),
            @n_SkuOutgoingShelfLife = ISNULL( CAST( SKU.BUSR6 AS INT), 0),
            @c_Lottable04Label = ISNULL(SKU.Lottable04Label,'')
      FROM  SKU (NOLOCK)
      WHERE SKU.StorerKey = @c_storerkey
      AND SKU.SKU = @c_sku
    
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable01= @c_lottable01 '  
          
      IF @c_lottable02 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable02= @c_lottable02 ' 
        
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable03= @c_lottable03 '  
             
      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04 = @d_lottable04 '  
          
      IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable05= @d_lottable05 '          

      IF @c_lottable06 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable06= @c_lottable06 '  

      IF @c_lottable07 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable07= @c_lottable07 '  

      IF @c_lottable08 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable08= @c_lottable08 '   

      IF @c_lottable09 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable09= @c_lottable09 '  

      IF @c_lottable10 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable10= @c_lottable10 '  

      IF @c_lottable11 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable11= @c_lottable11 '  

      IF @c_lottable12 <> ' '  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable12= @c_lottable12 '  

      IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable13 = @d_lottable13 '  

      IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable14 = @d_lottable14 '  

      IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable15 = @d_lottable15 '  
         
      IF @c_Lottable04Label = 'EXP_DATE'  AND ISNULL(@n_SkuOutgoingShelfLife, 0) > 0
      BEGIN
         IF ISNULL(@n_SkuOutgoingShelfLife, 0) > 0
            SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, @n_SkuOutgoingShelfLife * -1, Lottable04) >= GetDate() '      
         ELSE
            SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable04 > GetDate() '                                   
      END   

      IF @c_Lottable04Label = 'PRODN_DATE'   AND ISNULL(@n_SkuShelfLife, 0) > 0
      BEGIN
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, @n_SkuShelfLife, Lottable04) >= GetDate() '      
      END            
       
      SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Loc.LocationType IN (''CASE'') '
      SET @c_OrderBy = ' ORDER BY LOTATTRIBUTE.LOTTABLE04, LOT.LOT, LOTATTRIBUTE.Lottable05 '
           
      SELECT @c_SQLStmt = N'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
       ' SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, ' +
       ' QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) ' +
       ' FROM LOTXLOCXID (NOLOCK) ' +
       ' JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT ' +
       ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +
       ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +
       ' JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +  
       ' LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +
       '               FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) ' +
       '               WHERE  P.Orderkey = ORDERS.OrderKey ' +
       '               AND    P.StorerKey = @c_storerkey ' + 
       '               AND    P.SKU = @c_sku ' +
       '               AND    P.Qty > 0 ' +
       '            AND    P.PreAllocatePickCode = ''nspPR_PH04'' ' +
       '               GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility ' +
       ' WHERE LOTXLOCXID.StorerKey = @c_storerkey ' +
       ' AND LOTXLOCXID.SKU = @c_sku ' +
       ' AND LOTXLOCXID.Qty > 0 ' +
       ' AND LOT.Status = ''OK'' ' +
       ' AND LOC.Facility = @c_facility ' +
       ' AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +
       ' AND ID.Status = ''OK'' ' +   
       RTRIM(@c_LimitString) + ' ' +
        ' GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05 ' + 
          ' HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0 ' +
        RTRIM(@c_OrderBy)
    
      --(Wan01) - START
      --EXEC (@c_SQLStmt)
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_storerkey  NVARCHAR(15)'
                     + ',@c_SKU        NVARCHAR(20)'
                     + ',@c_Lottable01 NVARCHAR(18)'
                     + ',@c_Lottable02 NVARCHAR(18)'
                     + ',@c_Lottable03 NVARCHAR(18)'
                     + ',@d_lottable04 datetime'
                     + ',@d_lottable05 datetime'
                     + ',@c_Lottable06 NVARCHAR(30)'
                     + ',@c_Lottable07 NVARCHAR(30)'
                     + ',@c_Lottable08 NVARCHAR(30)'
                     + ',@c_Lottable09 NVARCHAR(30)'
                     + ',@c_Lottable10 NVARCHAR(30)'
                     + ',@c_Lottable11 NVARCHAR(30)'
                     + ',@c_Lottable12 NVARCHAR(30)'
                     + ',@d_lottable13 datetime'
                     + ',@d_lottable14 datetime'
                     + ',@d_lottable15 datetime'
                     + ',@n_SkuOutgoingShelfLife int'
                     + ',@n_SkuShelfLife int'

      
      EXEC sp_ExecuteSQL @c_SQLStmt, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_SkuOutgoingShelfLife, @n_SkuShelfLife        
      --(Wan01) - END

      IF @b_debug = 1  PRINT @c_SQLStmt      
                    
   END
END

GO