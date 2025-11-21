SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALLocA1                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 7-May-15    TLTING         Std Parameter name                        */
/* 02-Jan-2020 Wan01    1.2   Dynamic SQL review, impact SQL cache log  */ 
/************************************************************************/

CREATE PROC  [dbo].[nspALLocA1]
@c_lot              NVARCHAR(10) ,
@c_uom              NVARCHAR(10) ,
@c_HostWHCode       NVARCHAR(10),
@c_Facility         NVARCHAR(5),
@n_uombase          int ,
@n_qtylefttofulfill int
AS
BEGIN
   SET NOCOUNT ON 

    DECLARE @n_ConsigneeMinShelfLife int,
            @c_LimitString           nvarchar(512) 
   
    DECLARE @c_OrderKey          NVARCHAR(10) 
         ,  @c_SQLParms          NVARCHAR(4000) = ''     --(Wan01)   
    
    SET @c_OrderKey = @c_HostWHCode
    
    IF dbo.fnc_RTrim(@c_OrderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_OrderKey) <> ''
    BEGIN
       SELECT @n_ConsigneeMinShelfLife = ISNULL(STORER.MinShelfLife,0) 
       FROM   ORDERS (NOLOCK)
       JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)
       WHERE ORDERS.OrderKey = @c_OrderKey

       IF @n_ConsigneeMinShelfLife > 0 
       BEGIN
          SELECT @c_Limitstring = dbo.fnc_RTrim(@c_LimitString) + " AND DATEDIFF(day, GETDATE(), Lottable04) >= @n_ConsigneeMinShelfLife "  
       END
       ELSE
       BEGIN
          SELECT @c_Limitstring = " AND 1=2 "
       END
   END

   DECLARE @c_SQLStatement nvarchar(1024) 

   SELECT  @c_SQLStatement = "DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                             "FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
      "QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' " + 
      "FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), SKUxLOC (NOLOCK), LOTAttribute (NOLOCK) " + 
      "WHERE LOTxLOCxID.Lot = @c_lot " + 
      "AND LOTxLOCxID.Loc = LOC.LOC " + 
      "AND LOTxLOCxID.Storerkey = SKUxLOC.Storerkey " + 
      "AND LOTxLOCxID.Sku = SKUxLOC.Sku " + 
      "AND LOTxLOCxID.Loc = SKUxLOC.Loc " + 
      "AND SKUxLOC.Locationtype NOT IN ('PICK', 'CASE') " + 
      "AND LOC.Locationflag <> 'HOLD' " + 
      "AND LOC.Locationflag <> 'DAMAGE' " + 
      "AND LOC.Status <> 'HOLD' " + 
      "AND LOC.Facility = @c_Facility " +
      "AND LOTxLOCxID.LOT = LOTAttribute.LOT " +
      dbo.fnc_RTrim(@c_Limitstring) + " " + 
      "ORDER BY LOC.LOC " 

   --(Wan01) - START                      
   SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                  + ',@c_lot        NVARCHAR(10)'
                  + ',@n_ConsigneeMinShelfLife INT'
                    
      
   EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_lot, @n_ConsigneeMinShelfLife        
   --(Wan01) - END   
END

GO