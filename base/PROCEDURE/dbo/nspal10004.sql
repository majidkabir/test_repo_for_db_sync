SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: nspAL10004                                         */      
/* Creation Date: 27-Mar-2014                                           */      
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
/* Date         Author  Ver   Purposes                                  */      
/************************************************************************/      
CREATE PROC    [dbo].[nspAL10004]      
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
         
           
   DECLARE @b_debug int,        
           @c_Manual NVARCHAR(1),      
           @c_LimitString NVARCHAR(MAX),       
           @n_ShelfLife int,      
           @c_SQL NVARCHAR(MAX),      
           @c_SQLParm NVARCHAR(MAX)      
            
   DECLARE @c_LocationType     NVARCHAR(10),      
           @c_LocationCategory NVARCHAR(10)      
               
                 
   SET @c_LocationType = ''      
   SET @c_LocationCategory = ''      
                       
   SET @c_SQL = N'      
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT LLI.LOT,      
             LLI.LOC,       
             LLI.ID,      
             QTYAVAILABLE = 
           CASE WHEN (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) < '+ CAST(@n_QtyLeftToFulfill AS VARCHAR(10)) +' AND
                       dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC) > 0 
                  THEN FLOOR((LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) / dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC))
                     * dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC)  
                  ELSE     
                    (FLOOR('+ CAST(@n_QtyLeftToFulfill AS VARCHAR(10)) +'  / dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC))
                     * dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC))  
             END,
             dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC)  
      FROM LOTxLOCxID LLI (NOLOCK)       
      JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC)      
      JOIN ID (NOLOCK) ON (LLI.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
      JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA. LOT    
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = ''LOCCATEGRY'' AND LOC.LocationCategory = CL.Code)      
      WHERE LOC.LocationFlag <> ''HOLD''       
      AND LOC.LocationFlag <> ''DAMAGE''       
      AND LOC.Status <> ''HOLD''       
      AND LOC.Facility = @c_Facility 
      AND ISNULL(RTRIM(CL.Short),''R'') <> ''S''             
      AND LOC.LocationType <> ''DYNPICKP''      
      AND LOT.Qty - LOT.QTYALLOCATED - LOT.QTYPICKED > 0' +
    ' AND dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC) > 0 ' +
    ' AND CASE WHEN (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) < '+ CAST(@n_QtyLeftToFulfill AS VARCHAR(10)) +' 
                    AND dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC) > 0   
                        THEN FLOOR((LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) / dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC))
                           * dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC)                
                  ELSE     
                       FLOOR('+ CAST(@n_QtyLeftToFulfill AS VARCHAR(10)) +' / dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC))
                           * dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC)
             END >= dbo.fnc_GetLocUccPackSize(LLI.StorerKey, LLI.SKU, LLI.LOC) 
      AND LLI.STORERKEY = @c_StorerKey AND LLI.SKU = @c_SKU ' + master.dbo.fnc_GetCharASCII(13) +      
   
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
      'ORDER BY (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen), ' + 
      ' CASE LOC.LocationCategory WHEN ''SHELVING'' THEN 1 WHEN ''DECK'' THEN 2 WHEN ''BULK'' THEN 3 ELSE 99 END,        
       LA.Lottable05, LA.Lottable04, LOC.LogicalLocation, LLI.Loc'    
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +      
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +       
                      '@d_Lottable04 NVARCHAR(18), @d_Lottable05 NVARCHAR(18), @n_QtyLeftToFulfill INT'      


   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @n_QtyLeftToFulfill      
END      

GO