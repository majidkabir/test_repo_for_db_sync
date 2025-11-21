SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_SG01                                         */
/* Creation Date: 07-Sep-2015                                           */
/* Copyright: LF                                                        */
/* Written by:  YTWan                                                   */
/*                                                                      */
/* Purpose: PreAllocateStrategy : Order by lottable01 - (Batch #)       */
/*                                                                      */
/* Called By: nspPreAllocateOrderProcessing                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev  Purposes                                   */      
/************************************************************************/

CREATE PROC [dbo].[nspPR_SG01]
   @c_storerkey         NVARCHAR(15) 
,  @c_sku               NVARCHAR(20) 
,  @c_lot               NVARCHAR(10) 
,  @c_lottable01        NVARCHAR(18) 
,  @c_lottable02        NVARCHAR(18) 
,  @c_lottable03        NVARCHAR(18) 
,  @d_lottable04        DATETIME 
,  @d_lottable05        DATETIME 
,  @c_lottable06        NVARCHAR(30) 
,  @c_lottable07        NVARCHAR(30)   
,  @c_lottable08        NVARCHAR(30)    
,  @c_lottable09        NVARCHAR(30)   
,  @c_lottable10        NVARCHAR(30)  
,  @c_lottable11        NVARCHAR(30)   
,  @c_lottable12        NVARCHAR(30)   
,  @d_lottable13        DATETIME       
,  @d_lottable14        DATETIME       
,  @d_lottable15        DATETIME       
,  @c_uom               NVARCHAR(10)
,  @c_facility          NVARCHAR(5)
,  @n_uombase           INT 
,  @n_qtylefttofulfill  INT
,  @c_OtherParms        NVARCHAR(200)=''
AS
BEGIN
   DECLARE @c_Condition          NVARCHAR(4000)      
         , @c_SQLStatement       NVARCHAR(4000) 
   
   IF RTRIM(@c_lot) <> '' AND @c_Lot IS NOT NULL   
   BEGIN
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY
            ,LOT.SKU
            ,LOT.LOT 
            ,QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT WITH(NOLOCK)
      JOIN LOTATTRIBUTE WITH(NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot )
      WHERE LOT.LOT = @c_lot 
      ORDER BY Lot.Lot
   END
   ELSE
   BEGIN

      IF RTRIM(@c_Lottable01) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = N''' + RTRIM(@c_Lottable01) + ''' '
      END
      IF RTRIM(@c_Lottable02) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE02 = N''' + RTRIM(@c_Lottable02) + ''' '
      END
      IF RTRIM(@c_Lottable03) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE03 = N''' + RTRIM(@c_Lottable03) + ''' '
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''' '
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOTTABLE05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''' '
      END

      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = N''' + RTRIM(@c_Lottable06) + '''' 
      END   

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = N''' + RTRIM(@c_Lottable07) + '''' 
      END   

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = N''' + RTRIM(@c_Lottable08) + '''' 
      END   

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = N''' + RTRIM(@c_Lottable09) + '''' 
      END   

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = N''' + RTRIM(@c_Lottable10) + '''' 
      END   

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = N''' + RTRIM(@c_Lottable11) + '''' 
      END   

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = N''' + RTRIM(@c_Lottable12) + '''' 
      END  

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
      END
   
      SET @c_SQLStatement = N'DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'  
         + ' SELECT LOT.Storerkey'
         + ', LOT.Sku'
         + ', LOT.Lot' 
         + ', QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )' 
         + ' FROM LOTATTRIBUTE WITH (NOLOCK)'  
         + ' JOIN LOT WITH (NOLOCK) ON (LOTATTRIBUTE.Lot = LOT.Lot)'  
         + ' JOIN LOTxLOCxID WITH (NOLOCK) ON (LOT.Lot = LOTxLOCxID.Lot)' 
         + ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)'
         + ' JOIN ID  WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID'   
         + ' WHERE LOT.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''  
         + ' AND LOT.Sku = N''' + RTRIM(@c_Sku) + ''' ' 
         + ' AND LOT.Status= ''OK'''
         + ' AND LOC.Status= ''OK''' 
         + ' AND ID.Status = ''OK'''  
         + ' AND LOC.LocationFlag <> ''HOLD'' AND LOC.LocationFlag <> ''DAMAGE''' 
         + ' AND LOC.Facility = N''' + RTRIM(@c_facility) + ''''  
         +  dbo.fnc_RTrim(@c_Condition)  
         + ' GROUP By LOT.Storerkey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable01' 
         + ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED)> 0' 
         + ' ORDER BY LOTATTRIBUTE.Lottable01, LOT.Lot ' 

      EXEC(@c_SQLStatement)

   END
END

GO