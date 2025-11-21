SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspALRFM01                                         */
/* Creation Date: 09-DEC-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 327559-RFM PH Allocation                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 27-Feb-2017  TLTING  1.1  Variable Nvarchar                          */
/* 01-Mar-2017  TLTING  1.2  Version from PH                            */
/* 17-Jan-2020  Wan01   1.3  Dynamic SQL review, impact SQL cache log   */  
/************************************************************************/

CREATE PROC [dbo].[nspALRFM01] 
@c_lot NVARchar(10) ,
@c_uom NVARchar(10) ,
@c_HostWHCode NVARchar(10),
@c_Facility NVARchar(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(20) = ''   
      
AS
BEGIN
   SET NOCOUNT ON 
   
    DECLARE @c_OrderKey          NVARCHAR(10),
            @c_OrderLineNumber   NVARCHAR(5),
            @c_OrderType         NVARCHAR(10),  
            @c_StrategyType      NVARCHAR(10),
            @c_SQL               NVARCHAR(MAX),
            @c_Condition         NVARCHAR(MAX),
            @c_Lottable01        NVARCHAR(18),
            @c_StorerKey         NVARCHAR(15)

         ,  @c_SQLParms          NVARCHAR(4000) = ''        --(Wan01)   
 
   SET @c_StrategyType = 'NORMAL'     
   SET @c_HostWHCode = ''   
   SET @c_SQL = ''   
   SET @c_Condition = ''    
   SET @c_StorerKey = ''   
                                   
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)

      SELECT @c_OrderType = ORDERS.Type, @c_HostWHCode = ORDERDETAIL.Userdefine01,
             @c_Lottable01 = ORDERDETAIL.Lottable01 ,
          @c_StorerKey = ORDERDETAIL.StorerKey 
      FROM   ORDERS WITH (NOLOCK)  
      JOIN   ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
      WHERE  ORDERS.OrderKey = @c_OrderKey
      AND ORDERDETAIL.OrderLineNumber = @c_OrderLineNumber

      IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ORDERTYPE' AND Code = @c_OrderType AND Long = 'REPLEN' AND StorerKey = @c_StorerKey )
          SET @c_StrategyType = 'REPLEN'
      ELSE
         SET @c_StrategyType = 'NORMAL'                                                        
   END   
   
   IF ISNULL(RTRIM(@c_HostWHCode), '') <> ''  
   BEGIN               
      SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOC.HostWHCode = N'" + RTRIM(@c_HostWHCode) + "' "  
   END    
   
   IF @c_UOM = '1' 
   BEGIN
       SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY Case When LOC.LocationType NOT IN ('PICK','CASE') THEN 0 ELSE 1 END, "
   END           
   ELSE
   BEGIN
       SELECT @c_Condition = RTRIM(@c_Condition) + " ORDER BY Case When LOC.LocationType IN ('PICK','CASE') THEN 0 ELSE 1 END,  "
   END
   
   SELECT @c_Condition = RTRIM(@c_Condition) + " LOC.LogicalLocation, LOC.LOC "                          

   --(Wan01) - START
   SELECT @c_SQL = "DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                   " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                   " QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), '1' "  +
                   " FROM LOTxLOCxID (NOLOCK) " +
                   " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                   " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                   "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                   " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                   " WHERE LOTxLOCxID.Lot = @c_Lot " +
                   " AND LOC.Facility = @c_Facility " + 
                   " AND LOC.Locationflag <>'HOLD' " +
                   " AND LOC.Locationflag <> 'DAMAGE' " +
                   " AND LOC.Status <> 'HOLD' " +
                   " AND ID.Status = 'OK'     " +
                   " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_uombase "  +
                   @c_Condition 
   
   --EXEC (@c_SQL)  
   SET @c_SQLParms= N'@c_Facility   NVARCHAR(5)'
                  + ',@c_Lot        NVARCHAR(10)'
                  + ',@n_UOMBase    int'
                    
      
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_Facility, @c_Lot, @n_UOMBase
   --(Wan01) - END                          
END

GO