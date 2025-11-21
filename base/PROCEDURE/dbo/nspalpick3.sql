SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspALPICK3                                         */  
/* Creation Date: 18-MAR-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: SHONG                                                    */  
/*                                                                      */  
/* Purpose: 336160 Allocate fr Load With Batch & SkipPreallocate turn on*/  
/*          Allocate By Lottables                                       */  
/*          Copy and modify from nspALPICK2                             */  
/* Called By:  nspLoadProcessing                                        */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 11-Nov-2015  Shong01 1.1   Bug Fixing                                */
/* 15-Jul-2022  WLChooi 1.2   WMS-20191 - Filter Lottable06-15 if have  */
/*                            value (WL01)                              */
/* 15-Jul-2022  WLChooi 1.2   DevOps Combine Script                     */
/************************************************************************/  
CREATE PROCEDURE [dbo].[nspALPICK3]   
   @c_LoadKey    NVARCHAR(10),   
   @c_Facility   NVARCHAR(5),   
   @c_StorerKey  NVARCHAR(15),   
   @c_SKU        NVARCHAR(20),  
   @c_Lottable01 NVARCHAR(18),    --(Wan01)     
   @c_Lottable02 NVARCHAR(18),    --(Wan01)     
   @c_Lottable03 NVARCHAR(18),    --(Wan01)   
   @c_Lottable04 NVARCHAR(20),    --(Wan01)    
   @c_Lottable05 NVARCHAR(20),    --(Wan01) 
   @c_Lottable06 NVARCHAR(30),    --WL01    
   @c_Lottable07 NVARCHAR(30),    --WL01    
   @c_Lottable08 NVARCHAR(30),    --WL01    
   @c_Lottable09 NVARCHAR(30),    --WL01    
   @c_Lottable10 NVARCHAR(30),    --WL01    
   @c_Lottable11 NVARCHAR(30),    --WL01    
   @c_Lottable12 NVARCHAR(30),    --WL01    
   @d_Lottable13 DATETIME,        --WL01
   @d_Lottable14 DATETIME,        --WL01
   @d_Lottable15 DATETIME,        --WL01
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
     
   DECLARE @b_debug        int,    
           @c_Manual       char(1),  
           @c_LimitString  NVARCHAR(MAX),   
           @n_ShelfLife    int,  
           @c_SQL          NVARCHAR(MAX)  
             
   DECLARE               
           @b_Success      INT   
          ,@n_err          INT  
          ,@c_errmsg       NVARCHAR(250)     
  
   --(Wan01) - START  
   DECLARE @c_SQLStatement    NVARCHAR(MAX)  
         , @c_SQLArguements   NVARCHAR(MAX)  
  
   SET @c_SQLStatement = ''  
   SET @c_SQLArguements= ''  
   --(Wan02) - END                  
  
   SET @c_SQLStatement = N'DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'  
                       + ' SELECT LOTxLOCxID.LOT,'  
                       + 'LOTxLOCxID.LOC,'   
                       + 'LOTxLOCxID.ID,'  
                       + 'QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED -'   
                       +                'LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),'   
                       + '''1'''   
                       + ' FROM LOTxLOCxID WITH (NOLOCK)'   
                       + ' JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)'   
                       + ' JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')'    
                       + ' JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')'      
                       + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOT.LOT = LOTATTRIBUTE.LOT'    
                       + ' JOIN SKUxLOC s WITH (NOLOCK) ON  s.StorerKey = LOTxLOCxID.StorerKey AND s.Sku = LOTxLOCxID.Sku '    
                       +                              ' AND s.Loc = LOTxLOCxID.Loc'          
                       + ' WHERE LOC.LocationFlag <> ''HOLD'''  
                       + ' AND LOC.LocationFlag <> ''DAMAGE'''   
                       + ' AND LOC.Status <> ''HOLD'''   
                       + ' AND LOC.Facility = @c_Facility'        
                       + ' AND LOTxLOCxID.STORERKEY = @c_StorerKey'    
                       + ' AND LOTxLOCxID.SKU = @c_SKU'    
                       + ' AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0' 
                       + ' AND LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED > 0  '  -- Shong01
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END      
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END      
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END      
                       +  CASE WHEN ISNULL(CONVERT(DATETIME, @c_Lottable04, 121), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'       
                               THEN '' ELSE ' AND LOTATTRIBUTE.Lottable04 = @c_Lottable04 ' END   
                       +  CASE WHEN ISNULL(CONVERT(DATETIME, @c_Lottable05, 121), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'       
                               THEN '' ELSE ' AND LOTATTRIBUTE.Lottable05 = @c_Lottable05 ' END   
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +  --WL01
                       + CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +  --WL01
                       + CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +  --WL01
                       + CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +  --WL01
                       + CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +  --WL01
                       + ' ORDER BY LOC.LocLevel, QTYAVAILABLE, LOC.LOC '  
    
   SET @c_SQLArguements= N'@c_Facility    NVARCHAR(5)'  
                       + ',@c_StorerKey   NVARCHAR(15)'  
                       + ',@c_SKU         NVARCHAR(20)'  
                       + ',@c_Lottable01  NVARCHAR(18)'  
                       + ',@c_Lottable02  NVARCHAR(18)'  
                       + ',@c_Lottable03  NVARCHAR(18)'  
                       + ',@c_Lottable04  NVARCHAR(20)'  
                       + ',@c_Lottable05  NVARCHAR(20)' 
                       + ',@c_Lottable06  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable07  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable08  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable09  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable10  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable11  NVARCHAR(30)'   --WL01
                       + ',@c_Lottable12  NVARCHAR(30)'   --WL01
                       + ',@d_Lottable13  DATETIME'       --WL01
                       + ',@d_Lottable14  DATETIME'       --WL01
                       + ',@d_Lottable15  DATETIME'       --WL01
    
   EXEC sp_ExecuteSQL @c_SQLStatement  
                     ,@c_SQLArguements  
                     ,@c_Facility  
                     ,@c_StorerKey  
                     ,@c_SKU   
                     ,@c_Lottable01  
                     ,@c_Lottable02  
                     ,@c_Lottable03  
                     ,@c_Lottable04  
                     ,@c_Lottable05 
                     ,@c_Lottable06   --WL01
                     ,@c_Lottable07   --WL01
                     ,@c_Lottable08   --WL01
                     ,@c_Lottable09   --WL01
                     ,@c_Lottable10   --WL01
                     ,@c_Lottable11   --WL01
                     ,@c_Lottable12   --WL01
                     ,@d_Lottable13   --WL01
                     ,@d_Lottable14   --WL01
                     ,@d_Lottable15   --WL01
END  

GO