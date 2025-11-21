SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspALPICK2                                         */
/* Creation Date: 06-FEB-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Allocate from Load With Batch & SkipPreallocate turn on,    */
/*          Allocate By Lottables                                       */
/*          Copy and modify from nspALPICK1                             */
/* Called By:  nspLoadProcessing                                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 16-Jan-2020  NJOW01  1.0   WMS-11835 filter by loc.locationtype      */
/************************************************************************/
CREATE PROCEDURE [dbo].[nspALPICK2] 
   @c_LoadKey    NVARCHAR(10), 
   @c_Facility   NVARCHAR(5), 
   @c_StorerKey  NVARCHAR(15), 
   @c_SKU        NVARCHAR(20),
   @c_Lottable01 NVARCHAR(18),    --(Wan01)   
   @c_Lottable02 NVARCHAR(18),    --(Wan01)   
   @c_Lottable03 NVARCHAR(18),    --(Wan01) 
   @c_Lottable04 NVARCHAR(20),    --(Wan01)  
   @c_Lottable05 NVARCHAR(20),    --(Wan01)
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
           @c_SQL          NVARCHAR(MAX),
           @c_LocPick      NCHAR(1)
           
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
   
   --NJOW01
   IF EXISTS(SELECT 1
             FROM CODELKUP (NOLOCK)
             WHERE Listname = 'PKCODECFG'
             AND Storerkey = @c_Storerkey
             AND Code = 'LOCTYPEPICK'
             AND Long = 'nspALPICK2'
             AND ISNULL(Short,'') <> 'N' )
   BEGIN          
      SET @c_LocPick = 'Y'
   END
   ELSE
   BEGIN
      SET @c_LocPick = 'N'
   END            

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
                       + ' AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0' +   
                       CASE WHEN @c_LocPick = 'Y' THEN ' AND LOC.LocationType IN (''PICK'',''CASE'') '  --NJOW01
                          ELSE ' AND s.LocationType IN (''PICK'',''CASE'')'  END +
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END    
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END    
                       +  CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END    
                       +  CASE WHEN ISNULL(CONVERT(DATETIME, @c_Lottable04, 121), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'     
                               THEN '' ELSE ' AND LOTATTRIBUTE.Lottable04 = @c_Lottable04 ' END 
                       +  CASE WHEN ISNULL(CONVERT(DATETIME, @c_Lottable05, 121), '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000'     
                               THEN '' ELSE ' AND LOTATTRIBUTE.Lottable05 = @c_Lottable05 ' END 
                       + ' ORDER BY QTYAVAILABLE'
  
   SET @c_SQLArguements= N'@c_Facility    NVARCHAR(5)'
                       + ',@c_StorerKey   NVARCHAR(15)'
                       + ',@c_SKU         NVARCHAR(20)'
                       + ',@c_Lottable01  NVARCHAR(18)'
                       + ',@c_Lottable02  NVARCHAR(18)'
                       + ',@c_Lottable03  NVARCHAR(18)'
                       + ',@c_Lottable04  NVARCHAR(20)'
                       + ',@c_Lottable05  NVARCHAR(20)'
  
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
END

GO