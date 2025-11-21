SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Stored Procedure: nspPR_CH06                                         */  
/* Creation Date: 08-08-2008                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Vanessa                                                  */  
/*                                                                      */  
/* Purpose: New Allocattion Strategy for Fast Pick Area                 */  
/*                                                                      */  
/* Called By: Exceed Allocate Orders                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */
/* 25-Jul-2014  TLTING     Pass extra parm @c_OtherParms                */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[nspPR_CH06]    
@c_storerkey NVARCHAR(15) ,    
@c_sku NVARCHAR(20) ,    
@c_lot NVARCHAR(10) ,    
@c_lottable01 NVARCHAR(18) ,    
@c_lottable02 NVARCHAR(18) ,    
@c_lottable03 NVARCHAR(18) ,    
@d_lottable04 datetime ,    
@d_lottable05 datetime ,    
@c_uom NVARCHAR(10) ,  
@c_facility NVARCHAR(10)  ,  
@n_uombase int ,    
@n_qtylefttofulfill int,  -- new column  
@c_OtherParms NVARCHAR(200) = ''  --Orderinfo4PreAllocation    
AS  
BEGIN    
   SET NOCOUNT ON   
  
   DECLARE @b_success int,@n_err int,@c_errmsg NVARCHAR(250),@b_debug int    
   DECLARE @c_manual NVARCHAR(1)     
   DECLARE @c_LimitString NVARCHAR(255) -- To limit the where clause based on the user input    
   DECLARE @c_Limitstring1 NVARCHAR(255)  , @c_lottable04label NVARCHAR(20)  
   SELECT @b_success= 0, @n_err= 0, @c_errmsg='',@b_debug= 0  
   SELECT @c_manual = 'N'    
  
   declare @n_shelflife int   
   declare @n_continue int  
  
   DECLARE @c_UOMBase NVARCHAR(10)  
   
   SELECT @c_UOMBase = @n_uombase  
       
   If @d_lottable04 = '1900-01-01'  
 Begin  
  Select @d_lottable04 = null  
 End  
  
   If @d_lottable05 = '1900-01-01'  
 Begin  
  Select @d_lottable05 = null  
 End  
       
   -- when any of the lottables is supplied, get the specific lot    
   IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR     
       @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL) OR LEFT(@c_lot,1) = '*'  
   BEGIN    
     select @c_manual = 'Y'    
   END    
    
   IF @b_debug = 1    
   BEGIN    
      SELECT 'nspPR_CH06 : After Lot Lookup .....'    
      SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
  SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual    
  SELECT '@c_storerkey' = @c_storerkey  
   END    
       
   IF ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)),'') <> '' AND LEFT(@c_lot, 1) <> '*'  
   BEGIN       
  /* Lot specific candidate set */    
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT,    
             QTYAVAILABLE =  SUM(LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
      FROM LOTXLOCXID (NOLOCK)   
      INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot   
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot   
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC   
      INNER JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Loc = SKUXLOC.Loc AND LOTXLOCXID.Sku = SKUXLOC.sku   
   LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID   
      LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)   
             FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)   
             WHERE  p.Orderkey = ORDERS.Orderkey   
             AND    p.Storerkey = @c_storerkey   
             AND    p.SKU = @c_sku   
        AND    p.qty > 0   
        AND    p.PreAllocatePickCode = 'nspPR_CH06'   
             GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility   
      WHERE LOC.Facility = @c_facility  
   AND LOT.LOT = @c_lot  
  AND LOC.LocationType IN ('FASTPICK')  
  GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOC.LOC --LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05   
  ORDER BY LOC.LOC --LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05   
    
      IF @b_debug = 1  
  BEGIN  
   SELECT ' Lot not null'  
  END  
   END    
   ELSE    
   BEGIN              
      /* Everything Else when no lottable supplied */    
    IF @c_manual = 'N'     
    BEGIN    
         IF @b_debug = 1  
         BEGIN  
            SELECT 'MANUAL = N'  
         END  
  
   SELECT @n_shelflife = convert(int, SKU.SUSR2)  
   FROM SKU (NOLOCK)  
   WHERE SKU = @c_sku  
   AND STORERKEY = @c_storerkey  
           
         SELECT @c_lottable04label = SKU.Lottable04label  
         FROM SKU (NOLOCK)  
         WHERE SKU = @c_sku  
   AND STORERKEY = @c_storerkey  
           
         SELECT @c_Limitstring1 = ''  
  
         IF @c_lottable04label = 'MANDATE'  
         BEGIN  
    IF @n_shelflife > 0  
    BEGIN  
     SELECT @c_Limitstring1 = ISNULL(dbo.fnc_RTrim(@c_LimitString1),'') + ' AND lottable04  > '''  +  convert(char(15), DateAdd(day, - @n_shelflife, getdate()), 106) + ''''  
    END               
       END     
  
         IF @b_debug = 1  
         BEGIN  
            select 'limitstring' , @c_limitstring1  
         END  
           
         EXEC ('DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +   
            'SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,   ' +    
            'QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)))' +  
          'FROM LOTXLOCXID (NOLOCK) ' +  
          'INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot ' +  
          'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot ' +  
          'INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +  
          'INNER JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Loc = SKUXLOC.Loc AND LOTXLOCXID.Sku = SKUXLOC.sku ' +  
    'LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +      
          'LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) ' +  
          '       FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) ' +  
          '       WHERE  p.Orderkey = ORDERS.Orderkey ' +  
          '       AND    p.Storerkey = N''' + @c_storerkey + '''' +  
          '       AND    p.SKU = N''' + @c_sku + '''' +  
    '       AND    p.qty > 0 ' +  
    '       AND    p.PreAllocatePickCode = ''nspPR_CH06'' ' +   
          '       GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility ' +  
            ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' +  
            ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' '   +  
    ' AND LOC.LocationType IN (''FASTPICK'') ' +   
            ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' ' +    
            ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString1 + ' ' +   
   -- ' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 , LOTATTRIBUTE.Lottable02 ' +    
   ' GROUP BY LOT.LOT, LOC.LOC ' +    
            ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0) ' +  
            -- ' ORDER BY LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 ')    
   ' ORDER BY LOC.LOC ')    
  
         IF @b_debug = 1  
         BEGIN  
            SELECT 'Candidate lines'  
            SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,     
              QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)))  
          FROM LOTXLOCXID (NOLOCK)   
          INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot   
          INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot   
          INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC   
          INNER JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Loc = SKUXLOC.Loc AND LOTXLOCXID.Sku = SKUXLOC.sku  
    LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID  
          LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)   
                 FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)   
                 WHERE  p.Orderkey = ORDERS.Orderkey   
                 AND    p.Storerkey = @c_storerkey   
                 AND    p.SKU = @c_sku   
           AND    p.qty > 0   
           AND    p.PreAllocatePickCode = 'nspPR_CH06'   
                 GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility   
             WHERE LOTXLOCXID.STORERKEY = @c_storerkey   
             AND LOTXLOCXID.SKU = @c_sku   
       AND LOC.LocationType IN ('FASTPICK')   
             AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK' And LOC.LocationFlag = 'NONE'   
             AND LOC.FACILITY = @c_facility + ' ' + @c_LimitString1   
     GROUP BY LOT.LOT, LOC.LOC --LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 , LOTATTRIBUTE.Lottable02   
             HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0)  
             ORDER BY LOC.LOC --LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05   
         END  
      END    
      ELSE    
      BEGIN    
         IF @b_debug =1   
         BEGIN  
            SELECT 'MANUAL = Y'  
         END  
  
     SELECT @c_LimitString = ''    
  
   IF @c_lottable01 <> ' '    
   SELECT @c_LimitString =  ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND Lottable01= N''' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable01)),'') + ''''    
  
   IF @c_lottable02 <> ' '    
   SELECT @c_LimitString =  ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable02= N''' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable02)),'') + ''''    
  
   IF @c_lottable03 <> ' '    
   SELECT @c_LimitString =  ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable03= N''' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable03)),'') + ''''      
    
   IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
   SELECT @c_LimitString =  ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable04 = N''' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable04))),'') + ''''    
  
   IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'  
   SELECT @c_LimitString =  ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable05= N''' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(CONVERT(char(20), @d_lottable05))),'') + ''''    
  
   IF LEFT(@c_lot,1) = '*'  
   BEGIN  
     select @n_shelflife = convert(int, substring(@c_lot, 2, 9))  
         
   IF @n_shelflife < 13  
   -- it's month  
   BEGIN  
    SELECT @c_Limitstring = ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable04  > N'''  + convert(char(15), dateadd(month, @n_shelflife, getdate()), 106) + ''''  
   END  
   ELSE  
   BEGIN  
    SELECT @c_Limitstring = ISNULL(dbo.fnc_RTrim(@c_LimitString),'') + ' AND lottable04  > N''' + convert(char(15), DateAdd(day, @n_shelflife, getdate()), 106) + ''''  
   END  
   END  
  
         IF @b_debug = 1  
         BEGIN  
          SELECT 'c_limitstring', @c_limitstring  
         END  
  
   SELECT @c_StorerKey = ISNULL(dbo.fnc_RTrim(@c_StorerKey),'')    
   SELECT @c_Sku = ISNULL(dbo.fnc_RTrim(@c_SKU),'')    
         EXEC (' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  ' +   
     ' SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT,  ' +    
           ' QTYAVAILABLE = (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(p.QTYPREALLOCATED, 0))) ' +  
           'FROM LOTXLOCXID (NOLOCK) ' +  
           'INNER JOIN LOT (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot ' +  
           'INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.Lot = LOTATTRIBUTE.Lot ' +  
           'INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +  
           'INNER JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Loc = SKUXLOC.Loc AND LOTXLOCXID.Sku = SKUXLOC.sku ' +  
     'LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +      
           'LEFT OUTER JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty) ' +  
           '       FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) ' +  
           '       WHERE  p.Orderkey = ORDERS.Orderkey ' +  
           '       AND    p.Storerkey = N''' + @c_storerkey + ''' ' +  
           '       AND    p.SKU = N''' + @c_sku + ''' ' +  
     '       AND    p.qty > 0 ' +  
     '       AND    p.PreAllocatePickCode = ''nspPR_CH06'' ' +   
           '       GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility ' +  
                 ' WHERE LOTXLOCXID.STORERKEY = N''' + @c_storerkey + ''' ' +  
                 ' AND LOTXLOCXID.SKU = N''' + @c_sku +  ''' '   +   
     ' AND LOC.LocationType IN (''FASTPICK'') ' +     
                 ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' ' +    
             ' AND LOC.FACILITY = N''' + @c_facility + ''' ' + @c_LimitString + ' ' +    
                 -- ' GROUP BY LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.Lottable02 ' +   
        ' GROUP BY LOT.LOT, LOC.LOC ' +   
       ' HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QTYPREALLOCATED, 0)) > 0) ' +   
              --' ORDER BY LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE05 ')    
     ' ORDER BY LOC.LOC ')    
  END    
   END    
END  

GO