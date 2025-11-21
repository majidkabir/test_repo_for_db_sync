SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspPRFEFO1                                          */  
/* Creation Date:                                                        */  
/* Copyright: IDS                                                        */  
/* Written by: IDS                                                       */  
/*                                                                       */  
/* Purpose: PGD TH Preallocation Strategy                                */  
/*                                                                       */  
/* Called By: Exceed Allocate Orders                                     */  
/*                                                                       */  
/* PVCS Version: 1.3                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author     Ver   Purposes                                */  
/* 18-Aug-2014  Leong      1.1   SOS# 318572 - Revise RTRIM/LTRIM        */  
/*                                           - Revise MinShelfLife60Mth  */  
/* 31-Aug-2018  NJOW01     1.2   WMS-6088 - Filter by hostwhcode based on*/  
/*                               loadplan.Load_Userdef1 and codelkup     */  
/* 02-Jan-2020  Wan01      1.3   Dynamic SQL review, impact SQL cache log*/  
/* 12-May-2020  LZG        1.4   INC1138834 - Fixed MinShelfLife         */ 
/*                               conversion (ZG01)                       */
/* 11-Jan-2021 BeeTin      1.5   INC1398518 - extend @c_LimitString to   */
/*                               1000                                    */
/*************************************************************************/  
  
CREATE PROC [dbo].[nspPRFEFO1]  
   @c_StorerKey        NVARCHAR(15),  
   @c_sku              NVARCHAR(20),  
   @c_lot              NVARCHAR(10),  
   @c_lottable01       NVARCHAR(18),  
   @c_lottable02       NVARCHAR(18),  
   @c_lottable03       NVARCHAR(18),  
   @d_lottable04       DATETIME,  
   @d_lottable05       DATETIME,  
   @c_lottable06       NVARCHAR(30) ,    
   @c_lottable07       NVARCHAR(30) ,    
   @c_lottable08       NVARCHAR(30) ,    
   @c_lottable09       NVARCHAR(30) ,    
   @c_lottable10       NVARCHAR(30) ,    
   @c_lottable11       NVARCHAR(30) ,    
   @c_lottable12       NVARCHAR(30) ,    
   @d_lottable13       DATETIME ,        
   @d_lottable14       DATETIME ,        
   @d_lottable15       DATETIME ,           
   @c_uom              NVARCHAR(10),  
   @c_facility         NVARCHAR(10),  
   @n_uombase          INT,  
   @n_qtylefttofulfill INT,  -- new column  
   @c_OtherParms NVARCHAR(200) = ''     
AS  
  
DECLARE @b_success INT, @n_err INT, @c_errmsg NVARCHAR(250), @b_debug INT,  
        @c_manual  NVARCHAR(1),  
        @c_LimitString NVARCHAR(1000),-- INC1398518
        @n_shelflife INT,  
        @c_sql NVARCHAR(MAX)  
          
DECLARE @c_Lottable04Label NVARCHAR(20),  
        @c_SortOrder       NVARCHAR(255)  
DECLARE @c_UOMBase         NVARCHAR(10)  
  
--NJOW01  
DECLARE @c_key1             NVARCHAR(10),      
        @c_key2             NVARCHAR(5),      
        @c_key3             NCHAR(1),  
        @c_Loadkey          NVARCHAR(10),  
        @c_Load_Userdef1    NVARCHAR(20),  
        @c_FilterHOSTWHCode NVARCHAR(10)      
            
SELECT @b_success = 0, @n_err = 0, @c_errmsg = "", @b_debug = 0, @c_manual = 'N', @c_FilterHOSTWHCode = 'N', @c_Load_Userdef1 = ''  
  
SELECT @c_UOMBase = @n_uombase  
  
DECLARE @c_SQLParms        NVARCHAR(4000) = ''  --(Wan01)   
     
--NJOW01 S  
IF EXISTS (SELECT 1    
           FROM CODELKUP (NOLOCK)  
           WHERE Listname = 'PKCODECFG'  
           AND Storerkey = @c_Storerkey  
           AND Code = 'FILTERHOSTWHCODE'  
           AND (Code2 = @c_Facility OR ISNULL(Code2,'') = '')  
           AND Long IN('nspPRFEFO1','nspAL_TH03')  
           AND Short <> 'N')  
BEGIN             
   SET @c_FilterHOSTWHCode = 'Y'  
END             
  
IF LEN(@c_OtherParms) > 0 AND @c_FilterHOSTWHCode = 'Y'  
BEGIN     
   SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)  
   SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
   SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave       
     
   IF @c_Key2 <> ''  
   BEGIN  
      SELECT @c_Loadkey = Loadkey  
      FROM ORDERS (NOLOCK)  
      WHERE Orderkey = @c_key1  
   END   
     
   IF @c_key2 = '' AND @c_key3 = ''  
   BEGIN  
      SELECT @c_Loadkey = Loadkey  
      FROM LOADPLAN (NOLOCK)  
      WHERE Loadkey = @c_Key1  
   END  
  
   IF @c_key2 = '' AND @c_key3 = 'W'  
   BEGIN  
      SELECT TOP 1 @c_Loadkey = O.Loadkey  
      FROM WAVEDETAIL WD (NOLOCK)  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey   
      WHERE WD.Wavekey = @c_Key1  
   END  
     
   SELECT @c_Load_Userdef1 = Load_Userdef1  
   FROM LOADPLAN (NOLOCK)  
   WHERE Loadkey = @c_Loadkey          
END  
--NJOW01 E  
  
IF @d_lottable04 = '1900-01-01'  
BEGIN  
   SELECT @d_lottable04 = NULL  
END  
  
IF @d_lottable05 = '1900-01-01'  
BEGIN  
   SELECT @d_lottable05 = NULL  
END  
  
IF @d_lottable13 = '1900-01-01'  
BEGIN  
   SELECT @d_lottable13 = NULL  
END  
  
IF @d_lottable14 = '1900-01-01'  
BEGIN  
   SELECT @d_lottable14 = NULL  
END  
  
IF @d_lottable15 = '1900-01-01'  
BEGIN  
   SELECT @d_lottable15 = NULL  
END  
  
IF @b_debug = 1  
BEGIN  
   SELECT "nspPRFEFO1 : Before Lot Lookup ....."  
   SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
   SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  , '@c_sku' = @c_sku  
   SELECT '@c_StorerKey' = @c_StorerKey, '@c_facility' = @c_facility  
END  
  
-- when any of the lottables is supplied, get the specific lot  
IF (@c_lottable01<>'' OR @c_lottable02<>'' OR @c_lottable03<>'' OR  
    @d_lottable04 IS NOT NULL OR @d_lottable05 IS NOT NULL OR  
    @c_lottable06<>'' OR @c_lottable07<>'' OR @c_lottable08<>'' OR  
    @c_lottable09<>'' OR @c_lottable10<>'' OR @c_lottable11<>'' OR  
    @c_lottable12<>'' OR @d_lottable13 IS NOT NULL OR   
    @d_lottable14 IS NOT NULL OR @d_lottable15 IS NOT NULL                   
    ) OR LEFT(@c_lot,1) = '*' OR @c_FilterHOSTWHCode = 'Y'  
BEGIN  
   SELECT @c_manual = 'N'  
END  
  
IF @b_debug = 1  
BEGIN  
   SELECT "nspPRFEFO1 : After Lot Lookup ....."  
   SELECT '@c_lot'=@c_lot,'@c_lottable01'=@c_lottable01, '@c_lottable02'=@c_lottable02, '@c_lottable03'=@c_lottable03  
   SELECT '@d_lottable04' = @d_lottable04, '@d_lottable05' = @d_lottable05, '@c_manual' = @c_manual  
   SELECT '@c_StorerKey' = @c_StorerKey  
END  
  
IF ISNULL(LTRIM(RTRIM(@c_lot)),'') <> '' AND LEFT(ISNULL(LTRIM(RTRIM(@c_lot)),''), 1) <> '*'  
BEGIN  
   /* Lot specific candidate set */  
   DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
         QTYAVAILABLE = CASE WHEN  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) <  @n_UOMBase  
                              THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                              WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase = 0  
                              THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                        ELSE  
                           SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                           -  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase  
                        END  
   FROM  LOT  
   INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT  
   INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
   INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT  
   LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)  
                    FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)  
                    WHERE  p.Orderkey = ORDERS.Orderkey  
                    GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility  
   WHERE LOC.Facility = @c_facility  
   AND   LOT.LOT = @c_lot  
   GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05  
   ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT ' Lot not NULL'  
      SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT,  
            QTYAVAILABLE = CASE WHEN  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) <  @n_UOMBase  
                                 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                                 WHEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase = 0  
                                 THEN SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                           ELSE  
                              SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0))  
                              -  SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED, 0)) % @n_UOMBase  
                           END  
      FROM  LOT  
      INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT  
      INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
      INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT  
      LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)  
                       FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)  
                       WHERE  p.Orderkey = ORDERS.Orderkey  
                       AND    p.SKU = @c_SKU  
                       AND    p.StorerKey = @c_StorerKey  
                       AND    p.Qty > 0  
                       GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility  
      WHERE LOC.Facility = @c_facility  
      AND   LOT.LOT = @c_lot  
      GROUP BY LOT.STORERKEY, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.LOTTABLE02, LOTATTRIBUTE.Lottable05  
      ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot  
   END  
END  
ELSE  
BEGIN  
   /* Everything Else when no lottable supplied */  
   IF @c_manual = 'N'  
   BEGIN  
      SELECT @c_LimitString = ''  
  
      IF @c_lottable01 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND Lottable01= @c_lottable01"    
  
      IF @c_lottable02 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable02= @c_lottable02"     
  
      IF @c_lottable03 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable03= @c_lottable03"     
  
      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable04 = @d_lottable04"    
  
      IF @d_lottable05 IS NOT NULL AND @d_lottable05 <> '1900-01-01'  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable05= @d_lottable05"     
  
      IF @c_lottable06 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable06= @c_lottable06"    
  
      IF @c_lottable07 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable07= @c_lottable07"     
  
      IF @c_lottable08 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable08= @c_lottable08"     
  
      IF @c_lottable09 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable09= @c_lottable09"     
  
      IF @c_lottable10 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable10= @c_lottable10"  
  
      IF @c_lottable11 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable11= @c_lottable11"  
  
      IF @c_lottable12 <> ' '  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable12= @c_lottable12"  
  
      IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable13 = @d_lottable13"  
  
      IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable14 = @d_lottable14"  
  
      IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'  
         SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'') + " AND lottable15 = @d_lottable15"  
  
      SELECT @c_Lottable04Label = ISNULL(LOTTABLE04LABEL, '')  
      FROM  SKU (NOLOCK)  
      WHERE SKU = @c_sku  
      AND   STORERKEY = @c_StorerKey  
  
      SELECT @c_SortOrder = ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot'  
  
      -- Min Shelf Life Checking  
      IF ISNULL(RTRIM(@c_Lottable04Label),'') <> ''  
      BEGIN  
         IF LEFT(ISNULL(LTRIM(RTRIM(@c_lot)),''), 1) = '*'  
         BEGIN  
            SELECT @n_shelflife = CONVERT(INT, SUBSTRING(@c_lot, 2, 9))  
  
            -- Add by June 08.Dec.2003 (SOS17522), requested by Tomy to treat 1 - 60 as months & > 60 as days  
            DECLARE @c_MinShelfLife60Mth NVARCHAR(1)  
            SELECT @c_MinShelfLife60Mth = '0'  
            SELECT @b_success = 0  
            EXECUTE nspGetRight NULL,                       -- Facility  
                             @c_storerkey,                  -- Storer  
                             NULL,                          -- Sku  
                             'MinShelfLife60Mth',  
                             @b_success           OUTPUT,  
                             @c_MinShelfLife60Mth OUTPUT,  
                             @n_err               OUTPUT,  
                             @c_errmsg            OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @c_errmsg = 'nspPreAllocateOrderProcessing : ' + ISNULL(RTRIM(@c_errmsg),'')  
            END  
  
            IF @c_MinShelfLife60Mth = '1'  
            BEGIN  
               /*  
               SOS# 318572: nspPreAllocateOrderProcessing will convert OrderDetail.MinShelfLife to number of days  
                            before pass into preallocate strategy.  
  
                            --> IF @n_MinShelfLife IS NULL  
                            --> BEGIN  
                            -->    SELECT @n_MinShelfLife = 0  
                            --> END  
                            --> ELSE IF @c_MinShelfLife60Mth = '1'  
                            --> BEGIN  
                            -->    IF @n_MinShelfLife < 61  
                            -->       SELECT @n_MinShelfLife = @n_MinShelfLife * 30  
                            --> END  
                            --> ELSE IF @c_ShelfLifeInDays = '1'  
                            --> BEGIN  
                            -->    SELECT @n_MinShelfLife = @n_MinShelfLife  -- No conversion, only in days  
                            --> END                                          -- End Changes - FBR18050 NZMM  
                            --> ELSE IF @n_MinShelfLife < 13  
                            --> BEGIN  
                            -->    SELECT @n_MinShelfLife = @n_MinShelfLife * 30  
                            --> END  
               IF @n_shelflife < 61  
                  SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'"  + convert(char(8), DateAdd(MONTH, @n_shelflife, getdate()), 112) + "'"  
               ELSE                    SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND convert(char(8),Lottable04, 112) >= N'"  + convert(char(8), DateAdd(DAY, @n_shelflife, getdate()), 112) + "'"  
               */  
               SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND CONVERT(CHAR(8),Lottable04, 112) >= CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112)"  
            END  
            ELSE  
            BEGIN  
               IF @n_shelflife < 13  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND CONVERT(CHAR(8),Lottable04, 112) >= CONVERT(CHAR(8), DATEADD(MONTH, @n_shelflife, GETDATE()), 112) " -- ZG01
               ELSE  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND CONVERT(CHAR(8),Lottable04, 112) >= CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112) "   -- ZG01
            END  
  
            /*  
            IF @n_shelflife < 13  -- it's month  
            BEGIN  
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(CHAR(8),Lottable04, 112) >= '"  + CONVERT(CHAR(8), DATEADD(MONTH, @n_shelflife, GETDATE()), 112) + "'"  
            END  
            ELSE BEGIN  
                SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND CONVERT(CHAR(8),Lottable04, 112) >= '" + CONVERT(CHAR(8), DATEADD(DAY, @n_shelflife, GETDATE()), 112) + "'"  
            END  
            */  
            -- END - SOS17522  
         END  
         ELSE  
         BEGIN  
            -- IF Shelf Life not provided, filter Lottable04 < Today date  
            SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND CONVERT(CHAR(8),Lottable04, 112) >= CONVERT(CHAR(8), GETDATE(), 112) "  
         END  
      END                                                 
        
      --NJOW01       
      IF @c_FilterHOSTWHCode = 'Y' AND ISNULL(@c_Load_Userdef1,'') <> ''  
      BEGIN         
       SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND LOC.HOSTWHCode = @c_Load_Userdef1 "  
      END  
  
      IF @b_debug = 1  
      BEGIN  
        SELECT 'c_limitstring', @c_limitstring  
      END  
  
      SELECT @c_StorerKey   = ISNULL(RTRIM(@c_StorerKey),'')  
      SELECT @c_Sku         = ISNULL(RTRIM(@c_SKU),'')  
      SELECT @c_facility    = ISNULL(RTRIM(@c_facility),'')  
      SELECT @c_UOMBase     = ISNULL(RTRIM(@c_UOMBase),'')  
      SELECT @c_LimitString = ISNULL(RTRIM(@c_LimitString),'')  
  
      SELECT @c_sql = " DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +  
         " SELECT MIN(LOTXLOCXID.STORERKEY) , MIN(LOTXLOCXID.SKU), LOT.LOT," +  
         " QTYAVAILABLE = CASE WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +  
          " SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) < @n_UOMBase" +    
                  " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +  
                       " - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +  
                  " WHEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - " +  
                        " SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) % @n_UOMBase = 0 " +  
                  " THEN ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) " +  
                        " - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +  
                  " ELSE " +  
                  " ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated, 0))) " +  
                  " -  ( SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QTYALLOCATED) - SUM(LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0))) % @n_UOMBase " +    
                  " END " +  
         " FROM LOT (NOLOCK) " +  
         " INNER JOIN LOTXLOCXID (NOLOCK) ON LOT.LOT = LOTXLOCXID.LOT " +  
         " INNER JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC " +  
         " INNER JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +  
         " LEFT OUTER JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID " +  
         CASE WHEN @c_FilterHOSTWHCode = 'Y' AND ISNULL(@c_Load_Userdef1,'') <> '' THEN  --NJOW01  
         " LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +  
         "             FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK), LOADPLAN (NOLOCK) " +  
         "             WHERE  p.Orderkey = ORDERS.Orderkey " +  
         "             AND    ORDERS.Loadkey = LOADPLAN.Loadkey " +  
         "             AND    LOADPLAN.Load_Userdef1 = @c_Load_Userdef1" +           
         "             AND    p.SKU = @c_Sku" +  
         "             AND    p.StorerKey = @c_StorerKey" +  
         "             AND    p.Qty > 0 " +  
         "             GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility "   
         ELSE  
         " LEFT OUTER JOIN (SELECT p.Lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) " +  
         "             FROM   PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK) " +  
         "             WHERE  p.Orderkey = ORDERS.Orderkey " +  
         "             AND    p.SKU = @c_Sku" +  
         "             AND    p.StorerKey = @c_StorerKey" +  
         "             AND    p.Qty > 0 " +  
         "             GROUP BY p.Lot, ORDERS.Facility) As P ON LOTXLOCXID.Lot = P.Lot AND LOC.Facility = P.Facility "   
         END +  
         " WHERE LOTXLOCXID.STORERKEY = @c_StorerKey AND LOTXLOCXID.SKU = @c_Sku " +  
         " AND LOT.STATUS = 'OK' AND LOC.STATUS = 'OK' AND ID.STATUS = 'OK'  And LOC.LocationFlag = 'NONE' " +  
         " AND LOC.FACILITY = @c_facility "  +  
         " AND LOTATTRIBUTE.STORERKEY = @c_StorerKey AND LOTATTRIBUTE.SKU = @c_Sku " +  
         @c_LimitString + " " +  
         " GROUP BY LOT.LOT , LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 " +  
         " HAVING (SUM(LOTXLOCXID.QTY) - SUM(LOTXLOCXID.QtyAllocated) - SUM(LOTXLOCXID.QTYPicked)- MIN(ISNULL(P.QtyPreAllocated, 0))) >= @n_UOMBase " +  
         @c_SortOrder  
  
      --Wan01 - START  
      --EXEC (@c_sql)  
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
                     + ',@n_shelflife  int'  
                     + ',@n_UOMBase    int'  
                     + ',@c_Load_Userdef1 NVARCHAR(20)'  
        
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU  
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05  
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10  
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15  
                        ,@n_shelflife, @n_UOMBase, @c_Load_Userdef1   
      --Wan01 - END  
  
      IF @b_debug = 1 SELECT @c_sql  
   END  
END  

GO