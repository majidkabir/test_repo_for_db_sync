SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispALVF005                                         */    
/* Creation Date: 30-Sep-2012                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Step 5 - Pick loose from DPP (For Launch Only) UOM:7        */
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 1.1                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */ 
/* 2023-05-16  Wan01    1.1   SVT Performance Tune & DevOps Combine Script*/  
/************************************************************************/    
CREATE   PROC [dbo].[ispALVF005]   
   @c_WaveKey    NVARCHAR(10),  
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

   DECLARE @b_debug       INT,      
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @c_LocationType     NVARCHAR(10),    
           @c_LocationCategory NVARCHAR(10),
           @c_WaveType         NVARCHAR(20),
           @c_ListName         NVARCHAR(10)

   SET @c_LocationType = 'DYNPPICK'    
   SET @c_LocationCategory = 'SHELVING'    

   SET @c_ListName = 'ORDERGROUP'

   -- GET WaveType FROM WAVE
   SELECT @c_WaveType = UserDefine01
   FROM WAVE WITH (NOLOCK)
   WHERE WaveKey = @c_WaveKey 

   IF ISNULL(@c_WaveType,'') = ''
   BEGIN
      -- GET FROM ORDERS
      --SELECT TOP 1 @c_WaveType = CODELKUP.Short                                   --Wan01 2022-05-16 Performance Tune  
      --FROM WAVEDETAIL WD WITH (NOLOCK) 
      --JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
      --JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)
      --WHERE WD.WaveKey = @c_WaveKey 
      --  AND CODELKUP.Listname = @c_ListName
      
      SELECT TOP 1 @c_WaveType = CODELKUP.Short          
      FROM ORDERS O WITH (NOLOCK) 
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup  AND CODELKUP.Listname = @c_ListName)
      WHERE O.OrderKey IN ( SELECT TOP 1 Orderkey from WAVEDETAIL WD WITH (NOLOCK)
                            WHERE WD.WaveKey = @c_WaveKey 
                            AND WD.OrderKey <> '' )                                 --Wan01 2022-05-16 Performance Tune  
   END

   -- IF LAUNCH WAVE, GET FROM DDP LOCATION
   IF ISNULL(@c_WaveType,'') = 'L'
   BEGIN   
      SET @c_SQL = N'    
         DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
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
         AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0    
         AND LOTxLOCxID.STORERKEY = @c_StorerKey 
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +      
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                
         'ORDER BY LOC.LogicalLocation, LOC.LOC' 
       
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '     
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03
   END
   ELSE
   BEGIN
      -- SKIP THIS STEP FOR NORMAL WAVE
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END

END -- Procedure

GO