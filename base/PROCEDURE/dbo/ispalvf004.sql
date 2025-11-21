SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: ispALVF004                                         */      
/* Creation Date: 09-Apr-2013                                           */      
/* Copyright: IDS                                                       */      
/* Written by: Chee Jun Yan                                             */      
/*                                                                      */      
/* Purpose: Step 4 - Pick loose from BULK Area (Oddsize/Case/Pallet)    */
/*                   UOM:7, Check Wave Type                             */
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
/* Date        Author   Ver   Purposes                                  */ 
/* 2023-05-16  Wan01    1.1   SVT Performance Tune & DevOps Combine Script*/        
/************************************************************************/      
CREATE   PROC [dbo].[ispALVF004]     
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
           @c_CurrentWaveType  NVARCHAR(20), 
           @c_PreviousWaveType NVARCHAR(20), 
           @c_PreviousWaveKey  NVARCHAR(10),
           @c_ListName         NVARCHAR(10)

   DECLARE @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18),
           @n_QtyAvailable     INT,  
           @n_UCCQty           INT
  
   SET @c_LocationType = 'OTHER'        
   SET @c_LocationCategory = 'VNA'  

   SET @c_ListName = 'ORDERGROUP'

   -- GET WaveType FROM WAVE
   SELECT @c_CurrentWaveType = UserDefine01
   FROM WAVE WITH (NOLOCK)
   WHERE WaveKey = @c_WaveKey 

   IF ISNULL(@c_CurrentWaveType,'') = ''
   BEGIN
      -- Get From Orders Table
      --SELECT TOP 1 @c_CurrentWaveType = CODELKUP.Short                            --Wan01 2022-05-16 Performance Tune
      --FROM WAVEDETAIL WD WITH (NOLOCK) 
      --JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
      --JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)
      --WHERE WD.WaveKey = @c_WaveKey 
      --  AND CODELKUP.Listname = @c_ListName
        
      SELECT TOP 1 @c_CurrentWaveType = CODELKUP.Short   
      FROM ORDERS O WITH (NOLOCK) 
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup  AND CODELKUP.Listname = @c_ListName)
      WHERE O.OrderKey IN ( SELECT TOP 1 Orderkey from WAVEDETAIL WD WITH (NOLOCK)
                            WHERE WD.WaveKey = @c_WaveKey 
                            AND WD.OrderKey <> '' )                                 --Wan01 2022-05-16 Performance Tune  
   END

   -- Get All Available Location In Bulk Area for the SKU
   SET @c_SQL = N'      
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR   
      SELECT   
         LOTxLOCxID.LOT,  
         LOTxLOCxID.LOC,  
         LOTxLOCxID.ID,  
         QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen), UCC.Qty  
      FROM LOTxLOCxID (NOLOCK)  
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)  
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')  
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT     
      LEFT OUTER JOIN UCC (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID  
                                       AND UCC.Status < ''4'')  
      WHERE LOC.LocationFlag <> ''HOLD''  
      AND LOC.LocationFlag <> ''DAMAGE''  
      AND LOC.Status <> ''HOLD''  
      AND LOC.Facility = @c_Facility  
      AND LOTxLOCxID.STORERKEY = @c_StorerKey  
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_QtyLeftToFulfill
      AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +        
      CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ''   
           ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''         
           ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +        
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +                  
      'GROUP BY LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, LOTxLOCxID.QTY, LOTxLOCxID.QTYALLOCATED,  
                LOTxLOCxID.QTYPICKED, LOTxLOCxID.QtyReplen, LOC.LocationHandling, LOC.LogicalLocation, LOC.LOC, UCC.Qty    
       ORDER BY LOC.LocationHandling DESC, LOC.LogicalLocation, LOC.LOC'
      
   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, ' +        
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '   
       
   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Lottable01, @c_Lottable02, @c_Lottable03  

   SET @c_SQL = ''

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UCCQty
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN   
      /*************************************************************************************/
      /***  Check Wave Type to avoid allocating allocated UCC from different wave type   ***/
      /*************************************************************************************/
      SET @c_PreviousWaveType = NULL
      SET @c_PreviousWaveKey = NULL

      SELECT TOP 1 @c_PreviousWaveKey = WD.WaveKey
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)
      WHERE PD.StorerKey = @c_StorerKey
        AND PD.SKU = @c_SKU
        AND PD.UOM = @c_UOM
        AND PD.Lot = @c_LOT
        AND PD.Loc = @c_LOC
        AND PD.ID = @c_ID
        AND PD.Status = '0'

      IF ISNULL(@c_PreviousWaveKey, '') <> ''
      BEGIN
         SELECT @c_PreviousWaveType = UserDefine01
         FROM WAVE WITH (NOLOCK)
         WHERE WaveKey = @c_PreviousWaveKey 

         IF ISNULL(@c_PreviousWaveType,'') = ''
         BEGIN
            -- Get From Orders Table
            --SELECT TOP 1 @c_PreviousWaveType = CODELKUP.Short                           --Wan01 2022-05-16 Performance Tune 
            --FROM WAVEDETAIL WD WITH (NOLOCK) 
            --JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
            --JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)
            --WHERE WD.WaveKey = @c_PreviousWaveKey 
            --  AND CODELKUP.Listname = @c_ListName
              
            SELECT TOP 1 @c_PreviousWaveType = CODELKUP.Short   
            FROM ORDERS O WITH (NOLOCK) 
            JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup  AND CODELKUP.Listname = @c_ListName)
            WHERE O.OrderKey IN ( SELECT TOP 1 Orderkey from WAVEDETAIL WD WITH (NOLOCK)
                                  WHERE WD.WaveKey = @c_PreviousWaveKey 
                                  AND WD.OrderKey <> '' )                                 --Wan01 2022-05-16 Performance Tune  
         END
      END -- IF ISNULL(@c_PreviousWaveKey, '') <> ''

      -- No Wave allocated, can allocate
      IF ISNULL(@c_PreviousWaveType,'') = ''
      BEGIN
         IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'   
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'  
                  UNION
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                  '
         END -- IF ISNULL(@c_SQL,'') <> ''
      END
      ELSE
      BEGIN
         -- Different Wave Type, allocate another UCC if available, else skip
         IF ISNULL(@c_CurrentWaveType,'') <> ISNULL(@c_PreviousWaveType,'')
         BEGIN
            -- Location has more than 1 UCC, can allocate
            IF @n_QtyAvailable / @n_UCCQty > 0
            BEGIN
               IF ISNULL(@c_SQL,'') = ''
               BEGIN
                  SET @c_SQL = N'   
                        DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                        SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                        '
               END
               ELSE
               BEGIN
                  SET @c_SQL = @c_SQL + N'  
                        UNION
                        SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                        '
               END -- IF ISNULL(@c_SQL,'') <> ''
            END -- IF @n_QtyAvailable/@n_UCCQty > 0
         END
         -- Same Wave Type, Allow allocation of same UCC
         ELSE
         BEGIN
            IF ISNULL(@c_SQL,'') = ''
            BEGIN
               SET @c_SQL = N'   
                     DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                     SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                     '
            END
            ELSE
            BEGIN
               SET @c_SQL = @c_SQL + N'  
                     UNION
                     SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyAvailable AS NVARCHAR(10)) + ''', ''1''
                     '
            END -- IF ISNULL(@c_SQL,'') <> ''
         END
      END

      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @n_UCCQty
   END -- END WHILE FOR CURSOR_AVAILABLE              
   CLOSE CURSOR_AVAILABLE          
   DEALLOCATE CURSOR_AVAILABLE
   
   IF ISNULL(@c_SQL,'') <> ''
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END  

END -- Procedure  

GO