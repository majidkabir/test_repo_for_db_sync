SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALPICK1                                         */
/* Creation Date: 05-Aug-2002                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author        Purposes                                  */
/* 31-Sep-2009  Shong         Pick From Pick Location                   */
/*                                                                      */
/************************************************************************/
CREATE PROCEDURE [dbo].[nspALPICK1] 
   @c_LoadKey    NVARCHAR(10), 
   @c_Facility   NVARCHAR(5), 
   @c_StorerKey  NVARCHAR(15), 
   @c_SKU        NVARCHAR(20),
   @c_UOM        NVARCHAR(10),
   @c_HostWHCode NVARCHAR(10),
   @n_UOMBase    INT,
   @n_QtyLeftToFulfill INT    
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug int,  
           @c_Manual NVARCHAR(1),
           @c_LimitString NVARCHAR(MAX), 
	        @n_ShelfLife int,
		     @c_SQL NVARCHAR(4000)
		     
   DECLARE             
           @b_Success    INT 
          ,@n_err        INT
          ,@c_errmsg     NVARCHAR(250)   
                
      
   DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC, 
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - 
                             LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), 
             '1' 
      FROM LOTxLOCxID (NOLOCK) 
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> 'HOLD') 
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')   
      JOIN LOTATTRIBUTE (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT 
      JOIN SKUxLOC s (NOLOCK) ON s.StorerKey = LOTxLOCxID.StorerKey AND s.Sku = LOTxLOCxID.Sku AND 
                   s.Loc = LOTxLOCxID.Loc	    
      WHERE LOC.LocationFlag <> 'HOLD'
      AND LOC.LocationFlag <> 'DAMAGE'
      AND LOC.Status <> 'HOLD'
      AND LOC.Facility = @c_Facility      
	   AND LOTxLOCxID.STORERKEY = @c_StorerKey 
	   AND LOTxLOCxID.SKU = @c_SKU  
	   AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0 
	   AND s.LocationType IN ('PICK','CASE')
      ORDER BY QTYAVAILABLE 
       
END

GO