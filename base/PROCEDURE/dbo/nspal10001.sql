SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspAL10001                                         */  
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
/* 31-Sep-2009  Shong         Only Return When Qty Available > 0        */  
/* 02-Dec-2011  ChewKp        Order by DP Location First SJ Outbound    */  
/*                            Phase 1 (ChewKP01)                        */  
/* 19-Jul-2012  Shong         Minus Qty Replen for Qty Available        */
/************************************************************************/  
CREATE PROC    [dbo].[nspAL10001]  
   @c_LoadKey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),   
   @c_StorerKey  NVARCHAR(15),   
   @c_SKU        NVARCHAR(20),  
   @c_Lottable01 NVARCHAR(18),  
   @c_Lottable02 NVARCHAR(18),  
   @c_Lottable03 NVARCHAR(18),  
   @d_Lottable04 NVARCHAR(20),  
   @d_Lottable05 NVARCHAR(20),  
   @c_UOM        NVARCHAR(10),  
   @c_HostWHCode NVARCHAR(10),  
   @n_UOMBase    INT,  
   @n_QtyLeftToFulfill INT   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
     
     
   DECLARE @b_Debug       INT,    
           @c_Manual      NVARCHAR(1),  
           @c_LimitString NVARCHAR(MAX),   
           @n_ShelfLife   INT,  
           @c_SQL         NVARCHAR(MAX),  
           @c_SQLParm     NVARCHAR(MAX)  
        
   DECLARE @c_LocationType     NVARCHAR(10),  
           @c_LocationCategory NVARCHAR(10)  
  
   SET @c_LocationType = ''  
   SET @c_LocationCategory = ''  
  
     
     
   SET @c_SQL = N'  
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.LOT,  
             LOTxLOCxID.LOC,   
             LOTxLOCxID.ID,  
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), ''1''   
      FROM LOTxLOCxID (NOLOCK)   
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')   
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')     
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT        
      WHERE LOC.LocationFlag <> ''HOLD''   
      AND LOC.LocationFlag <> ''DAMAGE''   
      AND LOC.Status <> ''HOLD''   
      AND LOC.Facility = @c_Facility    
      AND LOC.LocationType <> ''DYNPICKP''      
      AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey AND LOTxLOCxID.SKU = @c_SKU ' + master.dbo.fnc_GetCharASCII(13) +  
  
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' ELSE ' AND LOC.LocationType = N''' + @c_LocationType + '''' + master.dbo.fnc_GetCharASCII(13)   
      END +  
  
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''   
           ELSE ' AND LOC.LocationCategory = N''' + @c_LocationCategory + '''' + master.dbo.fnc_GetCharASCII(13)   
      END +  
  
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + master.dbo.fnc_GetCharASCII(13) END +  
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + master.dbo.fnc_GetCharASCII(13) END +  
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + master.dbo.fnc_GetCharASCII(13) END +  
  
      CASE WHEN ISNULL(CONVERT(DATETIME, @d_Lottable04, 112), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'   
                THEN '' ELSE ' AND LA.Lottable04 = @d_Lottable04 ' + master.dbo.fnc_GetCharASCII(13) END +  
  
      CASE WHEN ISNULL(CONVERT(DATETIME, @d_Lottable05, 112), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'   
                THEN '' ELSE ' AND LA.Lottable05 = @d_Lottable05 ' + master.dbo.fnc_GetCharASCII(13) END +                    
  
      'ORDER BY CASE LOC.LocationType WHEN ''DYNPPICK'' THEN 1 ELSE 99 END   
      ,LA.Lottable05, LA.Lottable04, LOC.LogicalLocation, LOTxLOCxID.Loc' -- (ChewKP01)   
  
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +  
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                      '@d_Lottable04 NVARCHAR(18), @d_Lottable05 NVARCHAR(18)'  
  
     
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05  
      
END  

GO