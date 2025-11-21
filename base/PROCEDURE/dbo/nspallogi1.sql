SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALLOGI1                                         */
/* Creation Date: 24-Mar-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-1413 CN/SG Logitech allocation                         */
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
/* Date        Author  Ver. Purposes                                    */
/* 13/09/2019  WLChooi 1.1  WMS-10163 - Use Codelkup to control if need */
/*                                       to allocate from DPP Loc (WL01)*/
/* 02-Jan-2020 Wan01   1.2  Dynamic SQL review, impact SQL cache log    */ 
/* 07-Apr-2021 NJOW01  1.3  WMS-16775 Cater for ecom allocation         */
/************************************************************************/

CREATE PROC [dbo].[nspALLOGI1] 
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
   
	 DECLARE @c_OrderKey          NVARCHAR(10),
	         @c_OrderLineNumber   NVARCHAR(5),
	         @c_Condition         NVARCHAR(2000),
	         @c_OrderBy           NVARCHAR(1000),
	         @c_SQL               NVARCHAR(MAX),
           @c_AllocateFromDPP   NVARCHAR(10) = 'N',    --WL01
           @c_Storerkey         NVARCHAR(20),           --WL01
           @c_SQLParms          NVARCHAR(4000) = '',    --(Wan01)   
           @c_ECOM_Mode         NCHAR(1) 
           
   SET @c_ECOM_Mode = 'N'
           	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)

      SELECT @c_Storerkey = Storerkey
      FROM ORDERS (NOLOCK)
      WHERE ORDERKEY = @c_OrderKey
                       
      --NJOW01                                      
      IF EXISTS(SELECT 1 FROM LOTATTRIBUTE(NOLOCK) WHERE Lot = @c_Lot AND ISNULL(Lottable08,'') = 'AP1BCH')   
      BEGIN                              
         IF EXISTS(SELECT 1
                   FROM ORDERS O (NOLOCK)
                   JOIN CODELKUP CL (NOLOCK) ON O.Consigneekey = CL.Code AND CL.Listname = 'LOGICCLG'
                   WHERE O.Orderkey = @c_Orderkey)          
         BEGIN
         	  SET @c_ECOM_Mode = 'Y'
         END    
         ELSE
         BEGIN                  
            DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
               SELECT TOP 0 NULL, NULL, NULL, NULL
         
            RETURN      
         END      
      END    
   END   

   --WL01 Start      
   IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)  
             WHERE ListName = 'PKCODECFG'  
             AND Storerkey = @c_Storerkey  
             AND Code = 'AllocateFromDPP'  
             AND Long = 'nspALLOGI1'  
             AND ISNULL(Short,'') <> 'N')   
      SET @c_AllocateFromDPP = 'Y'  
   ELSE  
      SET @c_AllocateFromDPP = 'N'   
   --WL01 End   
   
   SELECT @c_Condition = '', @c_OrderBy = ''

   IF @c_ECOM_Mode = 'Y' --NJOW01
   BEGIN
   	  SELECT @c_Condition = " AND LOC.LocationType= 'PICK' "
   END
   ELSE IF @c_UOM IN ('1','2')
   BEGIN  --WL01 Start
      IF @c_AllocateFromDPP = 'N'
         SELECT @c_Condition = " AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationCategory <> 'DYNPPICK' "
      ELSE
         SELECT @c_Condition = ''
   END  --WL01 End
   
   IF @c_UOM IN('6','7')
      SELECT  @c_Orderby =  " ORDER BY CASE WHEN SKUXLOC.LocationType IN('PICK','CASE') OR LOC.LocationType IN('PICK','CASE','DYNPPICK') OR LOC.LocationCategory = 'DYNPPICK' " + 
                                          " THEN 1 " +
                                          " WHEN LOC.LocationHandling = '2' AND LOC.LocationCategory = 'SHELVING' THEN 2 ELSE 3 END,3, LOC.LogicalLocation, LOC.LOC " 
   ELSE
      SELECT  @c_Orderby =  " ORDER BY 3, LOC.LogicalLocation, LOC.LOC " 
   
   SELECT @c_SQL =  " DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY " +
                    " FOR SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID, " +
                    "            QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), '1' " +
                    " FROM LOTxLOCxID (NOLOCK) " +
                    " JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC " +
                    " JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku " +
                    "                          AND LOTxLOCxID.Loc = SKUxLOC.Loc " +
                    " JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID " +
                    " WHERE LOTxLOCxID.Lot = @c_lot" +
                    " AND LOC.Facility = @c_Facility" +
                    " AND LOC.Locationflag <>'HOLD' " +
                    " AND LOC.Locationflag <> 'DAMAGE' " +
                    " AND LOC.Status <> 'HOLD' " +
                    " AND ID.Status = 'OK' " +
                    " AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0  " +      
                    @C_Condition + ' ' +
                    @C_Orderby
      --(Wan01) - START                      
      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                     + ',@c_lot        NVARCHAR(10)'
                    
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParms, @c_facility, @c_lot        
   --EXEC (@c_SQL) 
      --(Wan01) - END                   
END

GO