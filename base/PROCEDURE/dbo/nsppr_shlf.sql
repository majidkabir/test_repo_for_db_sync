SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPR_SHLF                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:  Ytwan                                                   */
/*                                                                      */
/*                                                                      */
/* Input Parameters: @c_storerkey       NVARCHAR(15)                        */
/*                   @c_facility        NVARCHAR(5)									*/
/*                   @b_debug           int = 0                         */
/*                   @n_Filekey         int										*/
/*                                                                      */
/* Output Parameters: @b_Success	int,                                   */
/*							 @n_err		int,												*/
/*							 @c_errmsg  NVARCHAR(250)										*/
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
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
/************************************************************************/

CREATE PROC [dbo].[nspPR_SHLF]
				@c_storerkey  NVARCHAR(15) ,
				@c_sku        NVARCHAR(20) ,
				@c_lot        NVARCHAR(10) ,
				@c_lottable01 NVARCHAR(18) ,
				@c_lottable02 NVARCHAR(18) ,
				@c_lottable03 NVARCHAR(18) ,
				@d_lottable04 datetime ,
				@d_lottable05 datetime ,
				@c_uom        NVARCHAR(10) ,
				@c_facility   NVARCHAR(10)  ,
				@n_uombase    int ,
				@n_qtylefttofulfill int  -- new column
AS
BEGIN
	SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_MinShelfLife int,
           @c_Condition    NVARCHAR(1000),
           @c_SQLStatement NVARCHAR(3999) 


	SET @n_MinShelfLife = 0
   
   IF ISNULL(RTRIM(@c_lot),'') <> '' AND LEFT(ISNULL(RTRIM(@c_lot),''),1) <> '*'
   BEGIN
      
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,
				 LOT.SKU,
				 LOT.LOT ,
      		 QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM  LOT WITH (NOLOCK)
      INNER JOIN Lotattribute WITH (NOLOCK)
		        ON (LOT.LOT = Lotattribute.LOT)
      WHERE LOT.LOT = @c_lot 
      AND DateAdd(Day, @n_MinShelfLife, Lotattribute.Lottable04) > GetDate() 
      ORDER BY Lotattribute.Lottable04, Lot.Lot

   END
   ELSE
   BEGIN
  
		IF Len(@c_lot) > 0
			SET @n_MinShelfLife = ISNULL(SUBSTRING(RTRIM(@c_lot),2,LEN(@c_lot)-1),0) * -1

      IF ISNULL(RTRIM(@c_Lottable01),'') <> '' 
      BEGIN
         SET @c_Condition = ' AND LOTTABLE01 = N''' + ISNULL(RTRIM(@c_Lottable01),'') + ''' '
      END
      IF ISNULL(RTRIM(@c_Lottable02),'') <> ''
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + 
                            ' AND LOTTABLE02 = N''' + ISNULL(RTRIM(@c_Lottable02),'') + ''' '
      END
      IF ISNULL(RTRIM(@c_Lottable03),'') <> ''
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + 
                            ' AND LOTTABLE03 = N''' + ISNULL(RTRIM(@c_Lottable03),'') + ''' '
      END
      IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') +
                            ' AND LOTTABLE04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''' '
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') +
                            ' AND LOTTABLE05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''' '
      END
   
--      IF @n_MinShelfLife <> 0 
--      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') +
                            ' AND DateAdd(Day, ' + CAST(@n_MinShelfLife AS NVARCHAR(10)) + 
                                          ', Lotattribute.Lottable04) > GetDate() ' 
--      END 
   
     	SET @c_SQLStatement =  ' DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
            ' SELECT LOT.STORERKEY, ' +
            '        LOT.SKU,       ' +
            '        LOT.LOT, ' +
            '        QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - 
                                     SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) )  ' +
            ' FROM LOTATTRIBUTE WITH (NOLOCK) ' +
            ' INNER JOIN LOT WITH (NOLOCK) '    +
            '         ON (LOTATTRIBUTE.LOT = LOT.LOT) ' +
            ' INNER JOIN LOTxLOCxID WITH (NOLOCK) '   +
				'         ON (LOTATTRIBUTE.LOT = LOTxLOCxID.LOT) ' +
            ' INNER JOIN LOC WITH (NOLOCK) ' +
				'         ON (LOC.LOC = LOTxLOCxID.LOC) ' +
            ' INNER JOIN ID  WITH (NOLOCK) ' + 
				'         ON (ID.ID = LOTxLOCxID.ID) '   +
            ' WHERE LOT.STATUS = ''OK'' ' +
            ' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK''  ' + 
            ' AND LOC.LocationFlag = ''NONE'' ' + 
      	   ' AND LOC.Facility = N''' + ISNULL(RTRIM(@c_facility),'') + ''' ' + 
            ' AND LOTATTRIBUTE.STORERKEY = N''' + ISNULL(RTRIM(@c_storerkey),'') + ''' ' +
            ' AND LOTATTRIBUTE.SKU = N''' + ISNULL(RTRIM(@c_SKU),'') + ''' ' + 
				ISNULL(RTRIM(@c_Condition),'') +
            ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04 ' +
            ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - 
                     SUM(LOTxLOCxID.QTYPICKED) - MAX(LOT.QTYPREALLOCATED) > 0   ' +
            ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot ' 

      EXEC(@c_SQLStatement)
      
   END
END

SET QUOTED_IDENTIFIER OFF 

GO