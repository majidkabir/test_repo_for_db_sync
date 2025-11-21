SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALVSE1                                          */
/* Creation Date: 07-APR-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: PreAllocateStrategy : WMS-1577 CN Victoria Secret Ecom      */
/*                                UOM 6 - locationcategory MEZZANINE    */
/*                                UOM 7 - locationcategory VNA          */
/*                                Locationtype - Other                  */
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
/* 28-Jun-2017  NJOW01  1.0  WMS-1577 UCC allocation                    */
/* 02-Oct-2017  NJOW02  1.1  WMS-3101 remove lot from sorting           */
/* 06-Mar-2018  NJOW03  1.2  WMS-4004 Remove allocate UCC               */
/* 02-Jan-2020  Wan01   1.3  Dynamic SQL review, impact SQL cache log   */ 
/************************************************************************/

CREATE PROC [dbo].[nspALVSE1] 
@c_lot NVARCHAR(10) ,
@c_uom NVARCHAR(10) ,
@c_HostWHCode NVARCHAR(10),
@c_Facility NVARCHAR(5),
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200) = ''         
AS
BEGIN
   SET NOCOUNT ON 
   
    DECLARE @c_OrderKey     NVARCHAR(10),
            @c_OrderLineNumber NVARCHAR(5),
           @c_SQLStatement    NVARCHAR(MAX), 
           @c_Condition       NVARCHAR(MAX),
           @c_Key1               NVARCHAR(10),
           @c_Key2               NVARCHAR(5),
           @c_key3               NCHAR(1)

         ,  @c_SQLParms          NVARCHAR(4000) = ''     --(Wan01)   
                        
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
      
      SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)
      SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
      SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave          
      
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         WHERE O.Loadkey = @c_key1
         --AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END                       
     
      IF ISNULL(@c_key2,'')='' AND ISNULL(@c_key3,'')='W' 
      BEGIN
         SET @c_Orderkey = ''
         SELECT TOP 1 @c_Orderkey = O.Orderkey
         FROM ORDERS O (NOLOCK) 
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN WAVEDETAIL WD  (NOLOCK) ON O.Orderkey = WD.Orderkey --(Wan01) Fixed to Retrieve By Index instead on O.Userdefine09  
         WHERE WD.Wavekey = @c_key1                               --(Wan01) Fixed to Retrieve By Index instead on O.Userdefine09  
         --AND OD.Sku = @c_SKU
         ORDER BY O.Orderkey, OD.OrderLineNumber
      END              
      
      --NJOW03      
      /*
      IF EXISTS(SELECT 1
                FROM ORDERS O (NOLOCK)
                JOIN WAVE W (NOLOCK) ON O.Userdefine09 = W.Wavekey
                WHERE O.Orderkey = @c_Orderkey
                AND W.Wavetype = 'B2B')
      BEGIN
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT TOP 0 NULL, NULL, NULL, NULL          
         RETURN
      END
      */                            
   END   
   
   IF @c_UOM = '6'
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType = 'OTHER' AND LOC.LocationCategory = 'MEZZANINE' " 

      SELECT @c_SQLStatement  = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                                " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                                "            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '' " +
                                " FROM LOTxLOCxID (NOLOCK) " +
                                " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                                " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                                "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                                " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                                " WHERE LOTxLOCxID.Lot = @c_lot "  +
                                " AND LOC.Facility = @c_Facility " +
                                " AND LOC.Locationflag <>'HOLD' " +
                                " AND LOC.Locationflag <> 'DAMAGE' " +
                                " AND LOC.Status <> 'HOLD' " +
                                " AND ID.Status = 'OK' " +
                                " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0  " +
                                ISNULL(RTRIM(@c_Condition),'') +
                                " ORDER BY LOC.LogicalLocation, LOC.LOC, 3 "
   END

   IF @c_UOM = '7'
   BEGIN
      SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + " AND LOC.LocationType = 'OTHER' AND LOC.LocationCategory = 'VNA' " 

      SELECT @c_SQLStatement  = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                                " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                                "            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '' " +
                                " FROM LOTxLOCxID (NOLOCK) " +
                                " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                                " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                                "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                                " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                                " WHERE LOTxLOCxID.Lot = @c_lot "  +
                                " AND LOC.Facility = @c_Facility " +
                                " AND LOC.Locationflag <>'HOLD' " +
                                " AND LOC.Locationflag <> 'DAMAGE' " +
                                " AND LOC.Status <> 'HOLD' " +
                                " AND ID.Status = 'OK' " +
                                ISNULL(RTRIM(@c_Condition),'') +
                                " ORDER BY 3, LOC.LogicalLocation, LOC.LOC "

      /*
      SELECT @c_SQLStatement  = " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                                " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                                "            QTYAVAILABLE = UCC.QTY, UCC.UCCNo " +
                                " FROM LOTxLOCxID (NOLOCK) " +
                                " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                                " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                                "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                                " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                                " JOIN UCC (NOLOCK) ON (UCC.StorerKey = LOTxLOCxID.StorerKey AND UCC.SKU = LOTxLOCxID.SKU AND " + 
                                "                            UCC.LOT = LOTxLOCxID.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID AND UCC.Status < '3') " +    
                                " WHERE LOTxLOCxID.Lot = '" + @c_lot + "'"  +
                                " AND LOC.Facility = '" +  @c_Facility + "' " +
                                " AND LOC.Locationflag <>'HOLD' " +
                                " AND LOC.Locationflag <> 'DAMAGE' " +
                                " AND LOC.Status <> 'HOLD' " +
                                " AND ID.Status = 'OK' " +
                                " AND UCC.QTY > 0  " +
                                ISNULL(RTRIM(@c_Condition),'') +
                                " ORDER BY 3, LOC.LogicalLocation, LOC.LOC "
       */                                
   END
      
   --(Wan01) - START                      
   SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                  + ',@c_lot        NVARCHAR(10)'
                    
   EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_lot        
   --(Wan01) - END   
                             
END

GO