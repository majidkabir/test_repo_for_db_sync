SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL_TW01                                         */
/* Creation Date: 04-Jan-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-666 TW PMA Allocation by floor                          */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspAL_TW01]
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

	 DECLARE @c_OrderKey VARCHAR(10),
	         @c_OrderLineNumber VARCHAR(5),
           @c_Condition NVARCHAR(2000),
           @c_LoadPickMethod NVARCHAR(10),
           @c_Storerkey NVARCHAR(15) 
   
   SET @c_Condition = ''        
	                     
   IF LEN(@c_OtherParms) > 0  -- when storerconfig 'Orderinfo4Allocation' is turned on
   BEGIN        
      SET @c_OrderKey = LEFT(@c_OtherParms,10)         
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms,11,5)
      
      SELECT TOP 1 @c_LoadPickMethod = ISNULL(L.LoadPickMethod,''),
                   @c_Storerkey = O.Storerkey
   		FROM ORDERS O (NOLOCK) 
   		JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey
   		WHERE O.Orderkey = @c_OrderKey 
   END
   
   IF ISNULL(@c_HostWHCode,'') <> ''
      SELECT @c_Condition = RTRIM(@c_Condition) + ' AND LOC.HostWhCode = N''' + RTRIM(ISNULL(@c_HostWHCode,'')) + ''' '

   IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
              WHERE CL.Storerkey = @c_Storerkey
              AND CL.Code = 'ALLOCBYFLOOR'
              AND CL.Listname = 'PKCODECFG'
              AND CL.Long IN('nspPRTW_NK','nspAL_TW01')
              AND ISNULL(CL.Short,'') <> 'N') AND @c_LoadPickMethod <> 'L-ORDER'  
   BEGIN           
      EXEC(' DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
           ' SELECT LOTxLOCxID.LOC,LOTxLOCxID.ID, ' +
           ' QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED), ''1'' '+
           ' FROM LOTxLOCxID (NOLOCK) ' +
           ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC) ' +
           ' JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID) ' +
           ' WHERE LOTxLOCxID.Lot = ''' + @c_lot + ''' ' +
           ' AND LOC.Locationflag <> ''HOLD'' ' +
           ' AND LOC.Locationflag <> ''DAMAGE'' ' +
           ' AND LOC.Status <> ''HOLD'' ' +
           ' AND LOC.Facility = ''' + @c_Facility + ''' '  +
           ' AND ID.STATUS <> ''HOLD'' ' +
            @c_Condition +
           ' ORDER BY LOC.Floor DESC, LOC.LogicalLocation, LOC.Loc ')
   END     
   ELSE
   BEGIN
       DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOTxLOCxID.Loc
                  ,LOTxLOCxID.ID
                  ,QTYAVAILABLE = 0
                  ,'1'
            FROM   LOTxLOCxID (NOLOCK)
            WHERE 1=2
   END 
END

GO