SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPR_CH07                                         */
/* Creation Date: 23-07-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: New Preallocation Strategy for E1 CN SOS181973              */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 06-Jul-2011  NJOW01  1.0 Validate qtypreallocated qty also when      */
/*                          userdefine03 <> ''                          */
/* 12-JUL-2011  SPChin  1.1 SOS220849 - Bug Fixed                       */
/* 04-JAN-2013  YTWan   1.2 SOS#264963:CN_IDSD_PreAllocate Strtategy    */
/*                          (Wan01)                                     */
/* 13-MAY-2013  YTWan   1.3 SOS#277657:CN_IDSD_add checking (LOC.Status)*/
/*                          in preallocate pick code (Wan02)            */
/* 25-Jul-2014  TLTING     Pass extra parm @c_OtherParms                */
/************************************************************************/

CREATE PROC [dbo].[nspPR_CH07]   
@c_storerkey NVARCHAR(15) ,  
@c_sku NVARCHAR(20) ,  
@c_lot NVARCHAR(10) ,  
@c_lottable01 NVARCHAR(18) ,  
@c_lottable02 NVARCHAR(18) ,  
@c_lottable03 NVARCHAR(18) ,  
@d_lottable04 datetime,  
@d_lottable05 datetime,  
@c_uom NVARCHAR(10),  
@c_facility NVARCHAR(10)  ,  
@n_uombase int ,  
@n_qtylefttofulfill int,  
@c_OtherParms NVARCHAR(200) = ''  
AS  
BEGIN  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
  
   Declare @b_debug int  
   SELECT @b_debug= 0
  
   IF ISNULL(LTrim(RTrim(@c_lot)),'') <> '' AND LEFT(@c_lot, 1) <> '*'  
   BEGIN  
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
      FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)  
      WHERE LOT.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.Lot = LOT.LOT  
      AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
      AND LOTXLOCXID.LOC = LOC.LOC  
      AND LOC.Facility = @c_facility  
      AND LOT.LOT = @c_lot  
      ORDER BY LOTATTRIBUTE.LOTTABLE04  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
         FROM LOT (NOLOCK), LOTATTRIBUTE (NOLOCK), LOTXLOCXID (NOLOCK), LOC (NOLOCK)  
         WHERE LOT.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.Lot = LOT.LOT  
         AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
         AND LOTXLOCXID.LOC = LOC.LOC  
         AND LOC.Facility = @c_facility  
         AND LOT.LOT = @c_lot  
         ORDER BY LOTATTRIBUTE.LOTTABLE04  
      END  
   END  
   ELSE  
   BEGIN  
      DECLARE @c_AllowSwitchPreallocate    NVARCHAR(1)

      SELECT @c_AllowSwitchPreallocate = ISNULL(RTRIM(SValue), '') 
      FROM StorerConfig (nolock)
      WHERE StorerKey = @c_storerkey
      AND Facility    = @c_facility
      AND ConfigKey   = 'AllowSwitchPreallocate'

      IF @c_AllowSwitchPreallocate <> '1'
      BEGIN
         IF @b_debug = 1  
         BEGIN  
            SELECT 'Executing nspPR_CH05...'
         END  

         EXEC nspPR_CH05
               @c_storerkey         = @c_storerkey,
               @c_sku               = @c_sku,
               @c_lot               = @c_lot,
               @c_lottable01        = @c_lottable01,
               @c_lottable02        = @c_lottable02,
               @c_lottable03        = @c_lottable03,
               @d_lottable04        = @d_lottable04,
               @d_lottable05        = @d_lottable05,
               @c_uom               = @c_uom,
               @c_facility          = @c_facility,
               @n_uombase           = @n_uombase,
               @n_qtylefttofulfill  = @n_qtylefttofulfill
      END
      ELSE
      BEGIN
         -- Get OrderKey and line Number  
         DECLARE @c_OrderKey        NVARCHAR(10),  
                 @c_OrderLineNumber NVARCHAR(5)  
     
         IF @b_debug = 1  
         BEGIN  
            SELECT '@c_OtherParms' = @c_OtherParms  
         END  
     
         IF ISNULL(RTrim(@c_OtherParms),'') <> ''  
         BEGIN  
            SELECT @c_OrderKey = LEFT(ISNULL(RTrim(@c_OtherParms),''), 10)  
            SELECT @c_OrderLineNumber = SUBSTRING(ISNULL(RTrim(@c_OtherParms),''), 11, 5)  
         END  
     
         IF @b_debug = 1  
         BEGIN  
            SELECT '@c_OrderKey' = @c_OrderKey, '@c_OrderLineNumber' = @c_OrderLineNumber  
         END  
         -- Get MinShelfLife  
         DECLARE @n_MinShelfLife    int,  
                 @n_Factor          FLOAT,  
                 @n_LeadTime        FLOAT, 
                 @n_Code            int, 
                 @n_PackQTY         FLOAT,
                 @c_OrderUOM      NVARCHAR(10), 
                 @c_Userdefine03  NVARCHAR(18), 
                 @c_LimitString     nvarchar(1000)  
     
         SELECT @n_MinShelfLife = 0  
         SELECT @n_Factor       = 0  
         SELECT @n_LeadTime     = 0  
         SELECT @n_Code         = 0  
         SELECT @n_PackQTY      = 0  
         SELECT @c_OrderUOM     = ''  
         SELECT @c_Userdefine03 = ''  
     
         SELECT @n_MinShelfLife = ISNULL(ORDERDETAIL.MinShelfLife,0), 
                @n_Factor       = CONVERT(FLOAT, ISNULL(RTRIM(CODELKUP.Short), 0)),
                @n_LeadTime     = CONVERT(FLOAT, ISNULL(RTRIM(CODELKUP.Long), 0)),
                @n_Code         = CONVERT(INT, ISNULL(RTRIM(CODELKUP.Code), 0)),
                @n_PackQTY      = CASE ISNULL(ORDERDETAIL.UOM,'') 
                                     WHEN Pack.PackUOM1 
                                        THEN Pack.CaseCnt
                                     WHEN Pack.PackUOM2 
                                        THEN Pack.InnerPack
                                     WHEN Pack.PackUOM3
                                        THEN Qty
                                  ELSE 0 END,
                @c_OrderUOM     = CASE ISNULL(ORDERDETAIL.UOM,'') 
                                     WHEN Pack.PackUOM1 
                                        THEN '2'
                                     WHEN Pack.PackUOM2 
                                        THEN '3'
                                     WHEN Pack.PackUOM3
                                        THEN '6'
                                   ELSE '0' END,
                @c_Userdefine03 = ORDERDETAIL.Userdefine03 
         FROM   ORDERDETAIL (NOLOCK)  
         JOIN   PACK (NOLOCK) ON (ORDERDETAIL.PACKKEY = PACK.PACKKEY)
         LEFT OUTER JOIN CODELKUP (NOLOCK) ON (ORDERDETAIL.MinShelfLife = CODELKUP.Code
                                AND CODELKUP.LISTNAME = 'SHELFLIFE'
                                AND ISNUMERIC(ISNULL(CODELKUP.Short, 0)) = 1 
                                AND ISNUMERIC(ISNULL(CODELKUP.Long, 0))  = 1)
         WHERE ORDERDETAIL.OrderKey        = @c_OrderKey  
           AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber

         IF @b_debug = 1  
         BEGIN  
            SELECT '@n_MinShelfLife' = @n_MinShelfLife, '@n_Factor' = @n_Factor, 
                   '@n_LeadTime' = @n_LeadTime, '@n_Code' = @n_Code 
         END 

         --(Wan01) - START
         IF EXISTS (SELECT 1
                    FROM FACILITY WITH (NOLOCK)
                    WHERE Facility = @c_facility
                    AND RTRIM(Userdefine06) = 'Claim' ) AND
            (RTRIM(@c_Userdefine03) = '' OR @c_Userdefine03 IS NULL) 
         BEGIN
            DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
            SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,  
            QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)  
            FROM LOT WITH (NOLOCK) 
            WHERE 1 = 0 

            GOTO EXIT_SP
         END
         --(Wan01) - END

         IF ISNULL(RTrim(@c_OrderKey),'') <> ''  
         BEGIN  
            SELECT @c_LimitString = ''
            IF @c_lottable01 <> ' '
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND Lottable01= N'" + LTrim(RTrim(@c_lottable01)) + "'"
            END

            IF @c_lottable02 <> ' '
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable02= N'" + LTrim(RTrim(@c_lottable02)) + "'"
            END
            /* SOS220849 Start
            ELSE
            BEGIN 
               IF @n_MinShelfLife = @n_Code AND @n_MinShelfLife > 0
               BEGIN  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND DateAdd(Day, @n_Factor*DATEDIFF(day, LOTATTRIBUTE.NewLot01,LOTATTRIBUTE.lottable04)+@n_LeadTime, GETDATE()) < LOTATTRIBUTE.lottable04 " 
                                                                           + " AND ISNULL(LOTATTRIBUTE.NewLot01, '') <> '' " +
                                                                           + " AND ISDATE(LOTATTRIBUTE.lottable01) = 1 " 
        
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT '@c_Limitstring' = @c_Limitstring  
                  END  
               END  
               ELSE  
               BEGIN  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND DateAdd(Day, @n_MinShelfLife, GETDATE()) < LOTATTRIBUTE.lottable04 "  
        
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT '@c_Limitstring' = @c_Limitstring  
                  END 
               END  
            END
           SOS220849 End */

            IF @c_lottable03 <> ' '
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable03= N'" + LTrim(RTrim(@c_lottable03)) + "'"
            END

            IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable04 = N'" + LTrim(RTrim(CONVERT(char(20), @d_lottable04))) + "'"
            END

            IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND lottable05= N'" + LTrim(RTrim(CONVERT(char(20), @d_lottable05))) + "'"
            END

            IF ISNULL(RTRIM(@c_Userdefine03),'') <> ''
            BEGIN
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " AND LOC.HOSTWHCODE= N'" + LTrim(RTrim(@c_Userdefine03)) + "'"
            END

            --SELECT @c_LimitString =  RTrim(@c_LimitString) + " GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01,  LOC.LOC, LOTXLOCXID.ID "  
            --SELECT @c_LimitString =  RTrim(@c_LimitString) + " GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01 "  
            SELECT @c_LimitString =  RTrim(@c_LimitString) + " GROUP BY LOT.STORERKEY,LOT.SKU,LOT.LOT, LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.NewLot01 "   --SOS220849

            IF @b_debug = 1  
            BEGIN  
               SELECT '@n_PackQTY' = @n_PackQTY, '@c_uom' = @c_uom, '@c_OrderUOM' = @c_OrderUOM
            END  

            IF @n_PackQTY <> 0 AND @c_uom = @c_OrderUOM 
            BEGIN
               --SELECT @c_LimitString =  RTrim(@c_LimitString) + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - CASE WHEN N'"+ISNULL(RTRIM(@c_Userdefine03),'')+ "' = '' THEN MIN(ISNULL(P.QTYPREALLOCATED,0)) ELSE 0 END >= @n_PackQTY "  --Add >= To allow same PackQTY allocated.
               --SELECT @c_LimitString =  RTrim(@c_LimitString) + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED,0)) >= @n_PackQTY "  --Add >= To allow same PackQTY allocated.
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED,0)) >= " + CAST(@n_PackQTY AS NVARCHAR(10)) + " "  --Add >= To allow same PackQTY allocated.  --SOS220849
            END
            ELSE
            BEGIN
               --SELECT @c_LimitString =  RTrim(@c_LimitString) + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - CASE WHEN N'"+ISNULL(RTRIM(@c_Userdefine03),'')+ "' = '' THEN MIN(ISNULL(P.QTYPREALLOCATED,0)) ELSE 0 END = 0 "  --Add >= To not allow allocate.
               SELECT @c_LimitString =  RTrim(@c_LimitString) + " HAVING SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED,0)) = 0 "  --Add >= To not allow allocate.
            END
            
        /* SOS220849 Start */
            IF @c_lottable02 = ' '
            BEGIN 
               IF @n_MinShelfLife = @n_Code AND @n_MinShelfLife > 0
               BEGIN  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND DateAdd(Day, " + CAST(@n_Factor AS NVARCHAR(10)) + " * DATEDIFF(day, LOTATTRIBUTE.NewLot01,LOTATTRIBUTE.lottable04)+ " + CAST(@n_LeadTime AS NVARCHAR(10)) + ", GETDATE()) < LOTATTRIBUTE.lottable04 " 
                                                                           + " AND ISNULL(LOTATTRIBUTE.NewLot01, '') <> '' " +
                                                                           + " AND ISDATE(LOTATTRIBUTE.lottable01) = 1 " 
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT '@c_Limitstring' = @c_Limitstring  
                  END  
               END  
               ELSE  
               BEGIN  
                  SELECT @c_Limitstring = ISNULL(RTRIM(@c_LimitString),'') + " AND DateAdd(Day, @n_MinShelfLife, GETDATE()) < LOTATTRIBUTE.lottable04 "  
        
                  IF @b_debug = 1  
                  BEGIN  
                     SELECT '@c_Limitstring' = @c_Limitstring  
                  END 
               END  
            END
           /* SOS220849 End */
            
            DECLARE @c_SQLStatement nvarchar(4000),
                      @c_ExecArgument nvarchar(4000)   
        
            /*SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +  
            " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +  
            " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - CASE WHEN N'"+ISNULL(RTRIM(@c_Userdefine03),'')+ "' = '' THEN MIN(LOT.QTYPREALLOCATED) ELSE 0 END " +  
            " FROM LOT (NOLOCK), (SELECT CASE ISDATE(LOTATTRIBUTE.lottable01) WHEN 1
                                             THEN LOTATTRIBUTE.lottable01
                                         ELSE NULL END AS NewLot01, * FROM LOTATTRIBUTE (NOLOCK) 
                                   WHERE LOTATTRIBUTE.STORERKEY = N'" + ISNULL(RTrim(@c_storerkey),'') + 
            "') LOTATTRIBUTE, LOTXLOCXID (NOLOCK), LOC (NOLOCK)"  +  
            " WHERE LOT.LOT = LOTATTRIBUTE.LOT" +  
            " AND LOTXLOCXID.Lot = LOT.LOT" +  
            " AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT" +  
            " AND LOTXLOCXID.LOC = LOC.LOC" +  
            " AND LOC.Facility = N'" + ISNULL(RTrim(@c_facility),'') + "'" +  
            " AND LOC.LocationFlag IN ('NONE', 'DAMAGE')" +  
            " AND LOT.STORERKEY = N'" + ISNULL(RTrim(@c_storerkey),'') + "'" +  
            " AND LOT.SKU = N'" + ISNULL(RTrim(@c_sku),'') + "'" +  
            " AND LOT.STATUS = 'OK' " +  
            ISNULL(RTrim(@c_Limitstring),'') +  
            " ORDER BY LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01 "  */
            --" ORDER BY LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01,  LOC.LOC, LOTXLOCXID.ID "  
   
             SELECT @c_SQLStatement = "DECLARE  PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY FOR " +  
            " SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT," +  
--          " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - CASE WHEN N'"+ISNULL(RTRIM(@c_Userdefine03),'')+ "' = '' THEN MIN(ISNULL(P.QTYPREALLOCATED,0)) ELSE 0 END " +  
            " QTYAVAILABLE = SUM(LOTXLOCXID.QTY - LOTXLOCXID.QTYALLOCATED - LOTXLOCXID.QTYPICKED) - MIN(ISNULL(P.QTYPREALLOCATED,0)) " +  
            " FROM LOT (NOLOCK) JOIN (SELECT CASE ISDATE(LOTATTRIBUTE.lottable01) WHEN 1
                                             THEN LOTATTRIBUTE.lottable01
                                         ELSE NULL END AS NewLot01, * FROM LOTATTRIBUTE (NOLOCK) 
                                   WHERE LOTATTRIBUTE.STORERKEY = N'" + ISNULL(RTrim(@c_storerkey),'') + 
            "') LOTATTRIBUTE ON LOT.Lot = LOTATTRIBUTE.Lot" + 
            " JOIN LOTXLOCXID (NOLOCK) ON LOTXLOCXID.Lot = LOT.Lot" +
            " JOIN LOC (NOLOCK) ON LOC.Loc = LOTXLOCXID.Loc"  +  
            " LEFT JOIN (SELECT p.lot, ORDERS.Facility, QtyPreallocated = SUM(p.Qty)" +
               "            FROM PreallocatePickdetail p (NOLOCK), ORDERS (NOLOCK)" +
               "            WHERE  p.Orderkey = ORDERS.Orderkey" + 
               "              AND    p.Storerkey = N'" + ISNULL(RTrim(@c_storerkey),'') + "'" + 
               "              AND    p.SKU = N'" + ISNULL(RTrim(@c_sku),'') + "'" +
               "               AND    p.Qty > 0" +
               "               GROUP BY p.Lot, ORDERS.Facility) P ON LOTXLOCXID.Lot = p.Lot AND p.Facility = LOC.Facility" +
            " WHERE LOC.Facility = N'" + ISNULL(RTrim(@c_facility),'') + "'" +  
            " AND LOC.LocationFlag IN ('NONE', 'DAMAGE')" +  
            " AND LOC.STATUS = 'OK' " +                                                                     --(Wan02) 
            " AND LOT.STORERKEY = N'" + ISNULL(RTrim(@c_storerkey),'') + "'" +  
            " AND LOT.SKU = N'" + ISNULL(RTrim(@c_sku),'') + "'" +  
            " AND LOT.STATUS = 'OK' " +  
            ISNULL(RTrim(@c_Limitstring),'') +  
            " ORDER BY LOTATTRIBUTE.LOTTABLE04,  LOTATTRIBUTE.LOTTABLE02,  LOTATTRIBUTE.LOTTABLE01 "  

        
            SET @c_ExecArgument = 
                  N'@n_MinShelfLife    int, ' + 
                   '@n_Factor          FLOAT, ' + 
                   '@n_LeadTime        FLOAT, ' + 
                   '@n_Code            int, ' + 
                   '@n_PackQTY         FLOAT ' 

            EXEC sp_executesql @c_SQLStatement, @c_ExecArgument, 
                               @n_MinShelfLife,
                               @n_Factor, 
                               @n_LeadTime,  
                               @n_Code,
                               @n_PackQTY
        
            IF @b_debug = 1  
            BEGIN  
               PRINT @c_SQLStatement
               SELECT '@c_SQLStatement' = @c_SQLStatement  
            END  
         END -- ISNULL(RTrim(@c_OrderKey),'') <> ''  
      END -- @c_AllowSwitchPreallocate = ''
   END 
   EXIT_SP: --(Wan01) 
END  

GO