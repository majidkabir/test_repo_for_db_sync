SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: nspPRTWPG3                                            */
/* Copyright: IDS                                                          */
/* PVCS Version: 1.8                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author     Ver   Purposes                                  */
/* 06-Feb-2015  Leong      1.1   SOS# 332576 - Bug fix.                    */
/* 19-Sep-2016  NJOW01     1.2   WMS-248 full pallet from bulk only        */
/* 08-Nov-2015  SHONG01    1.3   Minus Qty Avaialble with Overallocated Qty*/
/* 06-Jan-2017  NJOW02     1.4   Fix facility filtering and qtyexclude     */
/* 19-Jan-2017  NJOW03     1.5   Fix qtyavailable formula cater scenario of*/
/*                               with or without qtyreplen                 */
/* 22-Sep-2021  WLChooi    1.6   DEVOPS Combine Script                     */
/* 22-Sep-2021  WLChooi    1.7   WMS-18018 - Filter LocationCategory based */
/*                               on Codelkup (WL01)                        */
/* 01-Oct-2021  WLChooi    1.8   Bug Fix for WMS-18018 (WL02)              */
/***************************************************************************/
CREATE PROC [dbo].[nspPRTWPG3] (
   @c_StorerKey        NVARCHAR(15),
   @c_SKU              NVARCHAR(20),
   @c_LOT              NVARCHAR(10),
   @c_Lottable01       NVARCHAR(18),
   @c_Lottable02       NVARCHAR(18),
   @c_Lottable03       NVARCHAR(18),
   @d_Lottable04       DATETIME,
   @d_Lottable05       DATETIME,
   @c_UOM              NVARCHAR(10),
   @c_Facility         NVARCHAR(10),  -- added By Ricky for IDSV5
   @n_UOMBase          INT,
   @n_QtyLeftToFulfill INT,
   @c_OtherParms       NVARCHAR(20) = ''
)
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF     
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF    

    DECLARE @n_ConsigneeMinShelfLife  INT
           ,@c_Condition              NVARCHAR(MAX)
           ,@c_UOMBase                NVARCHAR(10)

    --WL01  
    DECLARE @c_LocationCategory       NVARCHAR(255) = ''
          , @c_LeftJoinCondition      NVARCHAR(4000) = ''
          , @c_JoinTable              NVARCHAR(4000) = ''   --WL02

    SET @c_UOMBase = RTRIM(CAST(@n_uombase AS NVARCHAR(10)))
    SET @c_Condition = '' -- SOS# 332576

    --WL01 S
    SELECT @c_LocationCategory = ISNULL(CL.Code2,'')
    FROM CODELKUP CL (NOLOCK)
    WHERE CL.LISTNAME = 'PKCODECFG'
    AND CL.Code = 'FILTERLOCCATEGRY'
    AND CL.Short = 'Y'
    AND CL.Storerkey = @c_StorerKey
    --WL01 E

    SET @c_UOMBase = RTRIM(CAST(@n_uombase AS NVARCHAR(10)))
    SET @c_Condition = '' -- SOS# 332576

    IF ISNULL(LTRIM(RTRIM(@c_LOT)) ,'') <> ''
    AND LEFT(@c_LOT ,1) <> '*'
    BEGIN
        /* Get Storer Minimum Shelf Life */
        SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife ,0)
        FROM   STORER(NOLOCK)
        WHERE  StorerKey = @c_Lottable03

        SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife ,0) * @n_ConsigneeMinShelfLife /100) * -1)
        FROM   Sku(NOLOCK)
        WHERE  Sku.Sku = @c_SKU
        AND    Sku.StorerKey = @c_StorerKey

        DECLARE PREALLOCATE_CURSOR_CANDIDATES  CURSOR FAST_FORWARD READ_ONLY
        FOR
            SELECT LOT.StorerKey
                  ,LOT.SKU
                  ,LOT.LOT
                  ,QTYAVAILABLE  = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
            FROM   LOT(NOLOCK)
                  ,Lotattribute                (NOLOCK)
                  ,LOTxLOCxID                  (NOLOCK)
                  ,LOC                         (NOLOCK)
            WHERE  LOT.LOT = @c_LOT
            AND    Lot.Lot = Lotattribute.Lot
            AND    LOTxLOCxID.Lot = LOT.LOT
            AND    LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
            AND    LOTxLOCxID.LOC = LOC.LOC
            AND    LOC.Facility = @c_Facility
            AND    DATEADD(DAY ,@n_ConsigneeMinShelfLife ,Lotattribute.Lottable04)
                   > GETDATE()
            ORDER BY
                   Lotattribute.Lottable04
                  ,LOT.Lot
    END
    ELSE
    BEGIN
        DECLARE @c_OrderKey   NVARCHAR(10)
               ,@c_OrderType  NVARCHAR(10)

        IF LEN(@c_OtherParms) > 0
        BEGIN
            SET @c_OrderKey = LEFT(@c_OtherParms ,10)

            SET @c_OrderType = ''
            SELECT @c_OrderType = TYPE
            FROM   ORDERS WITH (NOLOCK)
            WHERE  OrderKey = @c_OrderKey

            IF @c_OrderType = 'VAS'
            BEGIN
                SELECT @c_Condition = RTRIM(@c_Condition) +
                       " AND RIGHT(RTRIM(Lotattribute.Lottable02),1) <> 'Z' "
            END
        END

        --WL01 S
        IF ISNULL(@c_LocationCategory,'') <> ''
        BEGIN
           SELECT @c_LeftJoinCondition = RTRIM(@c_LeftJoinCondition) +
                                         ' AND LOC.LocationCategory NOT IN (SELECT DISTINCT ColValue FROM dbo.fnc_delimsplit ('','', N''' + @c_LocationCategory + ''') ) '
        END
        --WL01 E

        IF LEN(ISNULL(RTRIM(@c_LOT) ,'')) > 1
        BEGIN
            SELECT @n_ConsigneeMinShelfLife = CASE
                                                   WHEN ISNUMERIC(RIGHT(RTRIM(@c_LOT) ,LEN(RTRIM(@c_LOT)) - 1))
                                                        = 1 THEN CAST(RIGHT(RTRIM(@c_LOT) ,LEN(RTRIM(@c_LOT)) - 1) AS INT)
                                                        * -1
                                                   ELSE 0
                                              END
        END

        /* Get Storer Minimum Shelf Life */
        /* Lottable03 = Consignee Key */
        IF ISNULL(@n_ConsigneeMinShelfLife ,0) = 0
        BEGIN
            SELECT @n_ConsigneeMinShelfLife = ISNULL(Storer.MinShelflife ,0)
            FROM   STORER(NOLOCK)
            WHERE  StorerKey = RTRIM(@c_Lottable03)

        SELECT @n_ConsigneeMinShelfLife = ((ISNULL(Sku.Shelflife ,0) * @n_ConsigneeMinShelfLife / 100) * -1)
            FROM   Sku(NOLOCK)
            WHERE  Sku.Sku = @c_SKU
            AND    Sku.StorerKey = @c_StorerKey

            IF @n_ConsigneeMinShelfLife IS NULL
                SELECT @n_ConsigneeMinShelfLife = 0
        END

        -- Lottable01 is used for loc.HostWhCode -- modified by Jeff
        --IF ISNULL(RTRIM(@c_Lottable01) ,'') <> ''
        --AND @c_Lottable01 IS NOT NULL
        --BEGIN
        --    SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') + -- SOS# 332576
        --                        " AND LOC.HostWhCode = N'" + ISNULL(RTRIM(@c_Lottable01) ,'')
        --                        + "' "
        --END
        SET @c_Lottable01 = ISNULL(RTRIM(@c_Lottable01) ,'')

        IF ISNULL(RTRIM(@c_Lottable02) ,'') <> ''
        AND @c_Lottable02 IS NOT NULL
        BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                                " AND Lottable02 = N'" + ISNULL(RTRIM(@c_Lottable02) ,'') +
                                "' "
        END

        IF CONVERT(CHAR(10) ,@d_Lottable04 ,103) <> "01/01/1900"
        AND @d_Lottable04 IS NOT NULL
        BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                                " AND ( Lotattribute.Lottable04 >= N'" + RTRIM(CONVERT(CHAR(10) ,@d_Lottable04 ,112))
                                + "' ) "
        END
        ELSE
        BEGIN
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                                " AND ( DateAdd(Day, " + CAST(@n_ConsigneeMinShelfLife AS NVARCHAR(10))
                                + ", Lotattribute.Lottable04) > GetDate() "
            SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                                " OR Lotattribute.Lottable04 IS NULL ) "
        END
                             
        SELECT @c_Condition = ISNULL(RTRIM(@c_Condition) ,'') +
                           " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot, QTYAVAILABLE "

        --WL02 S
        SET @c_JoinTable = ''

        IF ISNULL(@c_LocationCategory,'') <> '' AND ISNULL(@c_LeftJoinCondition,'') <> ''
        BEGIN
           SELECT @c_JoinTable = " JOIN ( " + 
                                 " SELECT LOTxLOCxID.LOT, " + 
                                         " SUM(LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED) AS QtyAvailable, " +  
                                         " SUM(CASE WHEN (ID.Status = 'HOLD' AND LOC.Status = 'HOLD') OR " + 
				                                   "             (LOC.LocationFlag IN ('HOLD','DAMAGE')) " + 
				                                          " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " + 
				                                          " ELSE 0 END) AS HoldQty, " +  
  			                                 " SUM(CASE WHEN SKUxLOC.LocationType IN ('CASE','PICK') " +   
  			                                          " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +    
				                                          " ELSE 0 END) AS QtyInPickLoc, " +  
		                                     " SUM(CASE WHEN LOC.HostWhCode <> N'" + @c_Lottable01 + "' AND '" + @c_Lottable01 + "' <> '' "  +   
		                                              " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +  
				                                          " ELSE 0 END) AS QtyExclude, " + 
		                                     " SUM( LOTxLOCxID.QtyReplen ) AS QtyReplen, " +        
		                                     " SUM(CASE WHEN LOC.Facility <> N'" + @c_Facility + "' " +   
		                                              " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +  
				                                          " ELSE 0 END) AS QtyOtherFacility " + 
                                 " FROM LOTxLOCxID (NOLOCK) " +  
                                 " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " + 
                                 " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
                                 " JOIN SKUxLOC(NOLOCK) " + 
                                 " ON  SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " + 
                                 " AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
                                 " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +       
                                 " WHERE LOTxLOCxID.StorerKey = N'" + @c_StorerKey + "' "+  
                                 " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " + 
                                 " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED <> 0 " +
                                 @c_LeftJoinCondition +
                                 " GROUP BY LOTxLOCxID.LOT) AS LOT3 ON LOT3.LOT = LOT.LOT  "
        END
        --WL02 E

        EXEC (   " DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " + 
                 " SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, " +                   
                 " QTYAVAILABLE = " + 
                 " FLOOR(CASE WHEN LOT2.QtyInPickLoc < 0 AND (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) > 0 " +   -- if overallocted with extract qtyreplen then deduct the extra qtyreplen from bulk qtyavailable
                            " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                                  " - ISNULL(LOT2.HoldQty,0) - (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +  
                            " WHEN LOT2.QtyInPickLoc < 0 AND (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) <= 0 " +  -- if overallocted without extract qtyreplen then no deduct qtyreplen from bulk qtyavailable
                            " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                                  " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +                                   
                            " ELSE LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  -- if no overallocation deduct qtyreplen from bulk qtyavailable
                            " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyReplen,0) - ISNULL(LOT2.QtyInPickLoc,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " + 
                       " END / " + @c_UOMBase + " ) * " + @c_UOMBase +  
                 --" QTYAVAILABLE = " + 
                 --" FLOOR(CASE WHEN LOT2.QtyInPickLoc < 0 " +   
                 --           " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                 --                 " - ISNULL(LOT2.HoldQty,0) - (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +  
                 --           " ELSE LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                 --           " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyReplen,0) - ISNULL(LOT2.QtyInPickLoc,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " + 
                 --      " END / " + @c_UOMBase + " ) * " + @c_UOMBase +  
                 " FROM LOT WITH (NOLOCK)  " +
                 " JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT " +  
                 " LEFT OUTER JOIN ( " + 
                                  " SELECT LOTxLOCxID.LOT, " + 
                                         " SUM(LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED) AS QtyAvailable, " +  
                                         " SUM(CASE WHEN (ID.Status = 'HOLD' AND LOC.Status = 'HOLD') OR " + 
				                                   "             (LOC.LocationFlag IN ('HOLD','DAMAGE')) " + 
				                                          " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " + 
				                                          " ELSE 0 END) AS HoldQty, " +  
  			                                 " SUM(CASE WHEN SKUxLOC.LocationType IN ('CASE','PICK') " +   
  			                                          " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +    
				                                          " ELSE 0 END) AS QtyInPickLoc, " +  
		                                     " SUM(CASE WHEN LOC.HostWhCode <> N'" + @c_Lottable01 + "' AND '" + @c_Lottable01 + "' <> '' "  +   
		                                              " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +  
				                                          " ELSE 0 END) AS QtyExclude, " + 
		                                     " SUM( LOTxLOCxID.QtyReplen ) AS QtyReplen, " +        
		                                     " SUM(CASE WHEN LOC.Facility <> N'" + @c_Facility + "' " +   
		                                              " THEN LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED " +  
				                                          " ELSE 0 END) AS QtyOtherFacility " + 
		                              " FROM LOTxLOCxID (NOLOCK) " +  
		                              " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.Loc " + 
		                              " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " + 
		                              " JOIN SKUxLOC(NOLOCK) " + 
      		                        " ON  SKUxLOC.StorerKey = LOTxLOCxID.StorerKey " + 
		                              " AND SKUxLOC.SKU = LOTxLOCxID.SKU " + 
      		                        " AND SKUxLOC.LOC = LOTxLOCxID.LOC " +       
		                              " WHERE LOTxLOCxID.StorerKey = N'" + @c_StorerKey + "' "+  
                                  " AND LOTxLOCxID.SKU = N'" + @c_SKU + "' " + 
                                  " AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED <> 0 " +
                                  @c_LeftJoinCondition +   --WL01
                                  " GROUP BY LOTxLOCxID.LOT) AS LOT2 ON LOT2.LOT = LOT.LOT  " + @c_JoinTable +   --WL02
                 " WHERE LOT.StorerKey = N'" + @c_StorerKey + "' "+ 
                 " AND LOT.SKU = N'" + @c_SKU + "' "+ 
                 " AND LOT.STATUS = 'OK' " +  
                 " AND FLOOR(CASE WHEN LOT2.QtyInPickLoc < 0 AND (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) > 0 " +   
                            " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                                  " - ISNULL(LOT2.HoldQty,0) - (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +  
                            " WHEN LOT2.QtyInPickLoc < 0 AND (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) <= 0 " +   
                            " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                                  " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +                                   
                            " ELSE LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                            " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyReplen,0) - ISNULL(LOT2.QtyInPickLoc,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " + 
                       " END / " + @c_UOMBase + " ) * " + @c_UOMBase +   " > 0 " +                   
                 --" AND FLOOR(CASE WHEN LOT2.QtyInPickLoc < 0 " +   
                 --           " THEN LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                 --                " - ISNULL(LOT2.HoldQty,0) - (ISNULL(LOT2.QtyReplen,0) + ISNULL(LOT2.QtyInPickLoc,0)) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " +  
                 --           " ELSE LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated " +  
                 --                " - ISNULL(LOT2.HoldQty,0) - ISNULL(LOT2.QtyReplen,0) - ISNULL(LOT2.QtyInPickLoc,0) - ISNULL(LOT2.QtyOtherFacility,0) - ISNULL(LOT2.QtyExclude,0) " + 
                 --           " END / " + @c_UOMBase + " ) * " + @c_UOMBase + " > 0 " +                   
                 @c_Condition
              )
    END
END

GO