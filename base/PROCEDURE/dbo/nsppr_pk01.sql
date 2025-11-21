SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store Procedure:  nspPR_PK01                                           */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by:                                                            */
/*                                                                        */
/* Purpose:  Pre-Allocation Strategy of MANNING                           */
/*                                                                        */
/* Input Parameters:  @c_StorerKey char                                   */
/*                    @c_SKU char                                         */
/*                    @c_lot char                                         */
/*                    @c_Lottable01                                       */
/*                    @c_Lottable02                                       */
/*                    @c_Lottable03                                       */
/*                    @d_Lottable04                                       */
/*                    @d_Lottable05                                       */
/*                    @c_UOM                                              */
/*                    @c_Facility                                         */
/*                    @n_UOMBase                                          */
/*                    @n_QtyLeftToFulfill                                 */
/*                                                                        */
/* Output Parameters:  None                                               */
/*                                                                        */
/* Return Status:  None                                                   */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Local Variables:                                                       */
/*                                                                        */
/* Called By: Allocation Module                                           */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author  Ver  Purposes                                     */
/* 11-May-2010  Leong   1.0  SOS# 213668 - Strategy special design for    */
/*                                         Manning China.                 */
/* 24-FEB-2012  YTWAN   1.01 SOS#237041 - Change to FEFO.(Wan01)          */
/**************************************************************************/

CREATE PROCEDURE [dbo].[nspPR_PK01]
     @c_StorerKey        NVARCHAR(15)
   , @c_SKU              NVARCHAR(20)
   , @c_Lot              NVARCHAR(10)
   , @c_Lottable01       NVARCHAR(18)
   , @c_Lottable02       NVARCHAR(18)
   , @c_Lottable03       NVARCHAR(18)
   , @d_Lottable04       DATETIME
   , @d_Lottable05       DATETIME
   , @c_UOM              NVARCHAR(10)
   , @c_Facility         NVARCHAR(10)
   , @n_UOMBase          INT
   , @n_QtyLeftToFulfill INT
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @b_success          INT
         , @n_err              INT
         , @c_errmsg           NVARCHAR(250)
         , @b_debug      INT
         , @c_SQL              NVARCHAR(MAX)
         , @c_LimitString      NVARCHAR(255) -- To limit the where clause based on the user input
         , @c_Lottable04Label  NVARCHAR(20)
         , @n_ShelfLife        INT

   SELECT @b_success = 0
        , @n_err     = 0
        , @c_errmsg  = ''
        , @b_debug   = 0

   SELECT @n_ShelfLife = CASE WHEN ISNUMERIC(ISNULL(SKU.Susr2,'0')) = 1 THEN CONVERT(INT, ISNULL(SKU.Susr2,'0')) ELSE 0 END
   FROM SKU WITH (NOLOCK)
   WHERE SKU.Sku = @c_SKU
   AND SKU.Storerkey = @c_StorerKey

   IF @d_Lottable04 = '1900-01-01'
   BEGIN
      SELECT @d_Lottable04 = NULL
   END

   IF @d_Lottable05 = '1900-01-01'
   BEGIN
      SELECT @d_Lottable05 = NULL
   END

   IF @b_debug = 1
   BEGIN
      SELECT 'nspPR_PK01 : Before Lot Lookup .....'
      SELECT '@c_lot' = @c_lot
            ,'@c_Lottable01' = @c_Lottable01
            ,'@c_Lottable02' = @c_Lottable02
            ,'@c_Lottable03' = @c_Lottable03
            , '@d_Lottable04' = @d_Lottable04
            ,'@d_Lottable05' = @d_Lottable05
            ,'@c_SKU' = @c_SKU
            , '@c_StorerKey' = @c_StorerKey
            ,'@c_Facility' = @c_Facility
   END

   IF ISNULL(RTRIM(@c_lot),'') <> '' AND LEFT(@c_lot,1) <> '*'
   BEGIN
      /* Lot specific candidate set */
      DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR
         SELECT LOT.StorerKey
               ,LOT.SKU
               ,LOT.LOT
               ,QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT WITH (NOLOCK)
             ,LOTATTRIBUTE WITH (NOLOCK)
             ,LOTxLOCxID   WITH (NOLOCK)
             ,LOC          WITH (NOLOCK)
             ,SKUxLOC      WITH (NOLOCK)
         WHERE LOT.LOT = LOTATTRIBUTE.LOT AND
               LOTxLOCxID.Lot = LOT.LOT AND
               LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND
               LOTxLOCxID.LOC = LOC.LOC AND
               LOC.Facility = @c_Facility AND
               LOT.LOT = @c_lot AND
               SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND
               SKUxLOC.SKU = LOTxLOCxID.SKU AND
               SKUxLOC.LOC = LOTxLOCxID.LOC
         --(Wan01) - START
         --ORDER BY LOTATTRIBUTE.Lottable05
         ORDER BY LOTATTRIBUTE.Lottable04
         --(Wan01) - END

      IF @b_debug = 1
      BEGIN
         SELECT 'Lot not null'
               ,LOT.StorerKey
               ,LOT.SKU
               ,LOT.LOT
               ,QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
         FROM LOT WITH (NOLOCK)
             ,LOTATTRIBUTE WITH (NOLOCK)
             ,LOTxLOCxID   WITH (NOLOCK)
             ,LOC          WITH (NOLOCK)
             ,SKUxLOC      WITH (NOLOCK)
         WHERE LOT.LOT = LOTATTRIBUTE.LOT AND
               LOTxLOCxID.Lot = LOT.LOT AND
               LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND
               LOTxLOCxID.LOC = LOC.LOC AND
               LOC.Facility = @c_Facility AND
               LOT.LOT = @c_lot AND
               SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND
               SKUxLOC.SKU = LOTxLOCxID.SKU AND
               SKUxLOC.LOC = LOTxLOCxID.LOC
         ORDER BY LOTATTRIBUTE.Lottable04
      END
   END
   ELSE
   BEGIN

      SELECT @c_LimitString = ''

      IF ISNULL(RTRIM(@c_Lottable01) ,'') <> ''
      BEGIN
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable01 = N''' + LTRIM(RTRIM(@c_Lottable01)) + ''''
      END

      IF ISNULL(RTRIM(@c_Lottable02) ,'') <> ''
      BEGIN
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable02 = N''' + LTRIM(RTRIM(@c_Lottable02)) + ''''
      END

      IF ISNULL(RTRIM(@c_Lottable03) ,'') <> ''
      BEGIN
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable03 = N''' + LTRIM(RTRIM(@c_Lottable03)) + ''''
      END

      IF ISNULL(RTRIM(@d_Lottable04) ,'') <> '' AND ISNULL(RTRIM(@d_Lottable04) ,'') <> '1900-01-01'
      BEGIN
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable04 = N''' + LTRIM(RTRIM(CONVERT(VARCHAR(20) ,@d_Lottable04))) + ''''
      END

      IF ISNULL(RTRIM(@d_Lottable05) ,'') <> '' AND ISNULL(RTRIM(@d_Lottable05) ,'') <> '1900-01-01'
      BEGIN
         SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND Lottable05 = N''' + LTRIM(RTRIM(CONVERT(VARCHAR(20) ,@d_Lottable05))) + ''''
      END

      IF LEFT(@c_lot ,1) = '*' AND @n_ShelfLife = 0
      BEGIN
         SELECT @n_ShelfLife = CONVERT(INT ,SUBSTRING(@c_lot ,2 ,9))

         IF @n_ShelfLife < 13 -- it's month
         BEGIN
            SELECT @c_Limitstring = RTRIM(@c_LimitString) + ' AND Lottable04 > N''' + CONVERT(VARCHAR(15),DATEADD(MONTH,@n_ShelfLife,GETDATE()),106) + ''''
         END
         ELSE
         BEGIN
            SELECT @c_Limitstring = RTRIM(@c_LimitString) + ' AND Lottable04 > N''' + CONVERT(VARCHAR(15),DATEADD(DAY,@n_ShelfLife,GETDATE()),106) + ''''
         END
      END
      ELSE
      BEGIN
         IF @n_ShelfLife > 0
         BEGIN
            SELECT @c_Limitstring = RTRIM(@c_LimitString) + ' AND Lottable04 > N''' + CONVERT(VARCHAR(15),DATEADD(DAY,@n_ShelfLife,GETDATE()),106) + ''''
         END
      END

      IF @b_debug = 1
      BEGIN
          SELECT @c_limitstring '@c_limitstring'
      END

      SELECT @c_SQL = ' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR '
                     +' SELECT MIN(LOTxLOCxID.StorerKey) , MIN(LOTxLOCxID.SKU), LOT.LOT, '
                     +' CASE WHEN
                           SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0)) <
                           MIN(LOT.QTY) - MIN(LOT.QTYALLOCATED) - MIN(LOT.QTYPICKED) - MIN(LOT.QtyPreallocated) - MIN(LOT.QtyOnHold)
                           THEN SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0))
                           ELSE MIN(LOT.QTY) - MIN(LOT.QTYALLOCATED) - MIN(LOT.QTYPICKED) - MIN(LOT.QtyPreallocated) - MIN(LOT.QtyOnHold)
                        END '
                     +' FROM LOT WITH (NOLOCK) '
                     +' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot) '
                     +' JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '
                     +' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '+
                     +' JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '+
                     +' JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '
                     +' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) '
                     +                 ' FROM   PreallocatePickdetail P WITH (NOLOCK), ORDERS WITH (NOLOCK) '
                     +                 ' WHERE  P.Orderkey = ORDERS.Orderkey '
                     +                 ' AND    P.StorerKey = N''' + @c_StorerKey + ''' '
                     +                 ' AND    P.SKU = N''' + @c_SKU + ''' '
                     +                 ' AND    ORDERS.Facility = N''' + @c_Facility + ''' '
                     +                 ' AND    P.qty > 0 '
                     +                 ' AND    P.UOM IN (' + CASE WHEN @c_UOM = '6' THEN '''6''' ELSE '''2'',''7'''  END + ') '
                     +                 ' AND    P.PreAllocatePickCode = ''nspPR_PK01'''
                     +                 ' GROUP BY p.Lot, ORDERS.Facility) P '
                     +                 ' ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility '
                     +' WHERE LOTxLOCxID.StorerKey = N''' + @c_StorerKey + ''' '+
                     +' AND LOTxLOCxID.SKU = N''' + @c_SKU + ''' '+
                     +' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '
                     +' AND LOC.Facility = N''' + @c_Facility + '''' + @c_LimitString + ' '
                     +' AND SKUxLOC.LocationType = ''PICK'' '
                     +' GROUP BY LOT.LOT, SKUxLOC.LocationType, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 '
                     +' HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)- MIN(ISNULL(P.QtyPreallocated,0)) ) > 0 '
                     --(Wan01) - START
                     --+' ORDER BY LOTATTRIBUTE.Lottable05, LOT.LOT'
                     +' ORDER BY LOTATTRIBUTE.Lottable04, LOT.LOT'
                     --(Wan01) - END

      IF @b_debug = 1
      BEGIN
          SELECT @c_SQL '@c_SQL'
      END

      EXEC (@c_SQL)

   END
END

GO