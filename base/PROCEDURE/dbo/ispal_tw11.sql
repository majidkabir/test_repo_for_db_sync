SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispAL_TW11                                         */  
/* Creation Date: 06-Jun-2017                                           */
/* Copyright: LFL                                                       */
/* Purpose: WMS-1914 - TW NIKE Allocation by bulk zone with custom      */
/*                     Sorting (duplicate from ispAL_TW05)              */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         	Author  	Ver. Purposes                                */  
/* 06-Jun-2017  	NJOW01  	1.5  WMS-1914 Add sorting logic              */
/* 28-Nov-2017  	CSCHONG  1.6  WMS-3481-revised Avail qty logic (CS01) */
/* 23-Apr-2018	   LZG	   1.7  Added StorerKey filter (INC0178826)     */
/* 29-Dec-2020    SPChin   1.8  INC1098384 - Bug Fixed                  */
/************************************************************************/  
CREATE PROC  [dbo].[ispAL_TW11]     
   @c_lot NVARCHAR(10) ,  
   @c_uom NVARCHAR(10) ,  
   @c_HostWHCode NVARCHAR(10),  
   @c_Facility NVARCHAR(5),  
   @n_uombase int ,  
   @n_qtylefttofulfill int,  
   @c_OtherParms NVARCHAR(200) = ''  
AS  
BEGIN  
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON   
  
   DECLARE @c_Orderkey NVARCHAR(10),                           
           @c_LoadPickMethod NVARCHAR(10), 
           @c_Orderby  NVARCHAR(2000), 
           @c_CaseCond NVARCHAR(2000),
           @c_uombase  NVARCHAR(10),
		     @c_Storerkey NVARCHAR(15)                  -- INC0178826
                       
   SELECT @c_uombase = CAST(@n_uombase AS NVARCHAR)   
   SELECT @c_OrderBy = ' ORDER BY LOC.LogicalLocation, LOTxLOCxID.LOC'
   SELECT @c_HostWHCode = ISNULL(@c_HostWHCode, '')
   
   IF ISNULL(@c_OtherParms,'') <> ''
   BEGIN
      SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
      
      SELECT @c_Storerkey = O.Storerkey, @c_LoadPickMethod = ISNULL(L.LoadPickMethod,'')
      FROM ORDERS O (NOLOCK) 
      --JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey      --INC1098384
      LEFT JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey   --INC1098384
      WHERE O.Orderkey = @c_OrderKey 
      
      SET @c_Casecond = ''
      IF EXISTS (SELECT 1 FROM CODELKUP(NOLOCK) 
                 WHERE LISTNAME = 'NIKALC' )
      BEGIN
         IF @c_LoadPickMethod = 'L-ORDER'
         BEGIN
            SET @c_casecond = ' CASE LOC.PutawayZone '
            SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF01) AS NVARCHAR)  
            FROM CODELKUP(NOLOCK) 
            WHERE LISTNAME = 'NIKALC'         
			AND Storerkey = @c_Storerkey									-- INC0178826
            ORDER BY UDF01
            SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
         END   			          			       
         ELSE IF @c_LoadPickMethod = 'R-ORDER'
         BEGIN
            SET @c_casecond = ' CASE LOC.PutawayZone '
            SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF02) AS NVARCHAR)  
            FROM CODELKUP(NOLOCK) 
            WHERE LISTNAME = 'NIKALC'
			AND Storerkey = @c_Storerkey									-- INC0178826
            ORDER BY UDF02
            SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
         END
         ELSE
         BEGIN
            SET @c_casecond = ' CASE LOC.PutawayZone '
            SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF03) AS NVARCHAR)  
            FROM CODELKUP(NOLOCK) 
            WHERE LISTNAME = 'NIKALC'
			AND Storerkey = @c_Storerkey									-- INC0178826
            ORDER BY UDF03
            SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
         END
      END
      
      IF ISNULL(@c_casecond,'') <> ''
         SET @c_OrderBy = ' ORDER BY ' + @c_Casecond + ', LOC.LogicalLocation, LOTxLOCxID.LOC '
   END      
   			         
   EXEC('DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR    
         SELECT LOTxLOCxID.LOC, LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED-LOTxLOCxID.QtyReplen), ''1''         
         FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK), SKUxLOC (NOLOCK)  
         WHERE LOTxLOCxID.Lot = ''' + @c_lot + ''' ' +
        'AND LOTxLOCxID.Loc = LOC.LOC  
         AND LOTxLOCxID.Loc = SKUxLOC.Loc  
         AND LOTxLOCxID.Sku = SKUxLOC.Sku  
         AND LOTxLOCxID.ID = ID.ID  
         AND ID.Status <> ''HOLD''
         AND LOC.Facility = ''' + @c_Facility + ''' ' +
        'AND LOC.Locationflag <> ''HOLD''
         AND LOC.Locationflag <> ''DAMAGE''  
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= ' + @c_uombase + ' ' +
        'AND LOC.Status <> ''HOLD''  
         AND SKUxLOC.LocationType NOT IN (''PICK'', ''CASE'') 
         AND (LOC.HostWhCode = ''' + @c_HostWHCode + ''' OR ''' + @c_HostWHCode + ''' = '''') ' +
         @c_OrderBy)
END  

GO