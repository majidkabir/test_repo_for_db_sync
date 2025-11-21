SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: nspPR_XD01                                         */    
/* Creation Date: 10-Jul-2013                                           */
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 08-Jul-2013  Shong     1.0   Creation SOS283166                      */   
/* 18-AUG-2015  YTWan     1.1   SOS#350432 - Project Merlion -          */
/*                              Allocation Strategy (Wan01)             */  
/* 13-SEP-2018  NJOW01    1.2   WMS-6255 Include the ID checking only   */
/*                              for XDOCK orders                        */
/************************************************************************/    
    
CREATE PROC [dbo].[nspPR_XD01]    
    @c_storerkey        NVARCHAR(15),    
    @c_sku              NVARCHAR(20),    
    @c_lot              NVARCHAR(10),    
    @c_lottable01       NVARCHAR(18),    
    @c_lottable02       NVARCHAR(18),    
    @c_lottable03       NVARCHAR(18),    
    @d_lottable04       DATETIME,    
    @d_lottable05       DATETIME,    
    @c_lottable06       NVARCHAR(30) ,  --(Wan01)  
    @c_lottable07       NVARCHAR(30) ,  --(Wan01)  
    @c_lottable08       NVARCHAR(30) ,  --(Wan01)
    @c_lottable09       NVARCHAR(30) ,  --(Wan01)
    @c_lottable10       NVARCHAR(30) ,  --(Wan01)
    @c_lottable11       NVARCHAR(30) ,  --(Wan01)
    @c_lottable12       NVARCHAR(30) ,  --(Wan01)
    @d_lottable13       DATETIME ,      --(Wan01)
    @d_lottable14       DATETIME ,      --(Wan01)   
    @d_lottable15       DATETIME ,      --(Wan01)
    @c_uom              NVARCHAR(10),    
    @c_facility         NVARCHAR(10),    
    @n_uombase          INT,    
    @n_qtylefttofulfill INT,    
    @c_OtherParms       NVARCHAR(200)= NULL    
AS    
BEGIN    
    SET NOCOUNT ON    
    
    DECLARE @b_debug INT    
    SELECT @b_debug = 0    
    
    -- user will key in as DDMMYYYY in lottable01 field, take d oldest date    
    DECLARE @n_SkuMinShelfLife     INT    
           ,@n_StorerMinShelfLife  INT    
           ,@c_OrderKey            NVARCHAR(10)    
           ,@c_OrderLineNumber     NVARCHAR(5)    
           ,@n_TotalShelfLife      INT    
           ,@c_Condition           NVARCHAR(MAX)    
           ,@c_ID                  NVARCHAR(18)    
           ,@n_OutGoingShelfLife   INT    
           ,@c_Contact2            NVARCHAR(45)    
           ,@c_OrderType           NVARCHAR(10) --NJOW01
    
    SET @n_StorerMinShelfLife = 0    
    SET @n_SkuMinShelfLife = 0    
    SET @n_TotalShelfLife = 0    
    SET @c_OrderKey = ''    
    SET @n_OutGoingShelfLife = 0    
            
    IF ISNULL(RTRIM(@c_OtherParms), '') <> ''    
    BEGIN    
       SET @c_OrderKey = SUBSTRING(RTRIM(@c_OtherParms), 1, 10)    
       SET @c_OrderLineNumber = SUBSTRING(RTRIM(@c_OtherParms), 11, 5)    
       
       --NJOW01
       SELECT @c_OrderType = Type
       FROM ORDERS (NOLOCK)
       WHERE Orderkey = @c_Orderkey     
    END    
    
    IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND ISNULL(RTRIM(@c_OrderLineNumber),'') <> ''   
    BEGIN    
       SET @c_ID = ''    
    
       IF @c_OrderType = 'XDOCK'  --NJOW01
       BEGIN
          SELECT @c_ID = ISNULL(RTRIM(OD.UserDefine01),'') + ISNULL(RTRIM(OD.UserDefine02),'')    
          FROM   OrderDetail OD WITH (NOLOCK)    
          WHERE  OD.OrderKey = @c_OrderKey    
          AND    OD.OrderLineNumber = @c_OrderLineNumber    
       END
    END    
    
      IF ISNULL(RTRIM(@c_lot),'') <> ''    
      BEGIN    
         DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY    
         FOR    
          SELECT LOT.STORERKEY    
                ,LOT.SKU    
                ,LOT.LOT    
                ,QTYAVAILABLE                = (    
                     LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED    
                 )    
          FROM   LOT(NOLOCK)    
                ,Lotattribute                (NOLOCK)    
                ,LOTXLOCXID                  (NOLOCK)    
                ,LOC                         (NOLOCK)    
          WHERE  LOT.LOT = LOTATTRIBUTE.LOT    
                 AND LOTXLOCXID.Lot = LOT.LOT    
                 AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT    
                 AND LOTXLOCXID.LOC = LOC.LOC    
                 AND LOC.Facility = @c_facility    
                 AND LOT.LOT = @c_lot    
      END    
      ELSE    
      BEGIN    
         IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''    
             SELECT @c_Condition = " AND LOTTABLE01 = N'"+ISNULL(RTRIM(@c_Lottable01) ,'')    
                                 + "' "    
    
         IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''    
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                                   " AND LOTTABLE02 = N'"+ISNULL(RTRIM(@c_Lottable02) ,'')+    
                                   "' "    
    
         IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''    
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                                " AND LOTTABLE03 = N'"+ISNULL(RTRIM(@c_Lottable03) ,'')+    
                                "' "    
                                     
         IF CONVERT(CHAR(10) ,@d_Lottable04 ,103)<>"01/01/1900"    
            AND @d_Lottable04 IS NOT NULL    
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                                   " AND LOTTABLE04 = N'"+ISNULL(RTRIM(CONVERT(CHAR(20) ,@d_Lottable04 ,106)) ,'')    
                                 + "' "    
    
         IF CONVERT(CHAR(10) ,@d_Lottable05 ,103)<>"01/01/1900"    
            AND @d_Lottable05 IS NOT NULL    
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                                   " AND LOTTABLE05 = N'"+ISNULL(RTRIM(CONVERT(CHAR(20) ,@d_Lottable05 ,106)) ,'')    
                                 + "' "    
    
         --(Wan01) - START
         IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable06 = N''' + ISNULL(RTRIM(@c_Lottable06),'') + '''' 
         END   

         IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable07 = N''' + ISNULL(RTRIM(@c_Lottable07),'') + '''' 
         END   

         IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable08 = N''' + ISNULL(RTRIM(@c_Lottable08),'') + '''' 
         END   

         IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable09 = N''' + ISNULL(RTRIM(@c_Lottable09),'') + '''' 
         END   

         IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
         BEGIN
  SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable10 = N''' + ISNULL(RTRIM(@c_Lottable10),'') + '''' 
         END   

         IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable11 = N''' + ISNULL(RTRIM(@c_Lottable11),'') + '''' 
         END   

         IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable12 = N''' + ISNULL(RTRIM(@c_Lottable12),'') + '''' 
         END  

         IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable13 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) + ''''
         END

         IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable14 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) + ''''
         END

         IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                             + ' AND Lottable15 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) + ''''
         END
         --(Wan01) - END

         IF ISNULL(RTRIM(@c_ID) ,'')<>''    
         BEGIN    
             SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                                   " AND LOTxLOCxID.ID = N'"+ISNULL(RTRIM(@c_ID) ,'')    
                                 + "' "    
         END   

   
         SELECT @c_condition = ISNULL(RTRIM(@c_Condition) ,'')+    
                             " ORDER BY LOT.Lot "    
    
         EXEC (   " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +    
                  " SELECT DISTINCT LOT.STORERKEY, "+    
                  "        LOT.SKU, "+    
                  "        LOT.LOT, "+    
                  "        QTYAVAILABLE = LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED  " +    
                  " FROM  LOTxLOCxID (NOLOCK) "+    
                  "       JOIN LOT (nolock) ON LOT.LOT = LOTxLOCxID.Lot  "+    
                  "       JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT) " +    
                  "       JOIN LOC (Nolock) ON LOTxLOCxID.Loc = LOC.Loc "+    
                  "       JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  "+      
                  " WHERE LOT.STORERKEY = N'"+@c_storerkey+"' "+    
                  " AND LOT.SKU = N'"+@c_SKU+"' "+    
                  " AND LOT.STATUS = 'OK' "+    
                  " AND ID.STATUS <> 'HOLD' "+    
                  " AND LOC.Status = 'OK' "+    
                  " AND LOC.Facility = N'"+@c_facility+"' "+    
                  " AND LOC.LocationFlag <> 'HOLD' "+    
                  " AND LOC.LocationFlag <> 'DAMAGE' "+
                  " AND LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED >= 1 " +    
                  @c_Condition    
              )    
      END
         
     RETURN    
    
     SKIPREALLOC:    
     -- Dummy Cursor when storer.minshelflife is zero/blank    
     DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY    
     FOR    
         SELECT LOT.STORERKEY    
               ,LOT.SKU    
               ,LOT.LOT    
               ,QTYAVAILABLE                = (    
                    LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED    
                )    
         FROM   LOT(NOLOCK)    
         WHERE  1=2    
         ORDER BY    
                Lot.Lot    
END

GO