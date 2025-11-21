SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRPS01                                          */    
/* Creation Date: 20-JUL-2016                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 358754 - HK Pearson - Pre-Allocation process to allocate    */
/*          full pallet by single order                                 */
/*          Set to storerconfig PreProcessingStrategyKey                */ 
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/    
CREATE PROC [dbo].[ispPRPS01]        
    @c_WaveKey                      NVARCHAR(10)
  , @c_UOM                          NVARCHAR(10)
  , @c_LocationTypeOverride         NVARCHAR(10)
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)
  , @b_Success                      INT           OUTPUT  
  , @n_Err                          INT           OUTPUT  
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT  
  , @b_Debug                        INT = 0
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE  
      @n_Continue    INT,  
      @n_StartTCnt   INT,
      @c_SQL         NVARCHAR(MAX),    
      @c_SQLParm     NVARCHAR(MAX),
      @n_LowerBound  INT

   DECLARE 
      @n_OrderQty          INT,
      @n_InsertQty         INT,
      @n_IDQty             INT,
      @n_OrderLineQty      INT, 
      @c_Loc               NVARCHAR(10),
      @c_Lot               NVARCHAR(10),
      @c_ID                NVARCHAR(18),
      @c_OrderKey          NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_Facility          NVARCHAR(5),     
      @c_StorerKey         NVARCHAR(15),     
      @c_LocationType      NVARCHAR(50),    
      @c_LocationCategory  NVARCHAR(50),
      @c_SKU               NVARCHAR(20),    
      @c_Lottable01        NVARCHAR(18),    
      @c_Lottable02        NVARCHAR(18),    
      @c_Lottable03        NVARCHAR(18),
      @c_Lottable06        NVARCHAR(30),
      @c_Lottable07        NVARCHAR(30),
      @c_Lottable08        NVARCHAR(30),
      @c_Lottable09        NVARCHAR(30),
      @c_Lottable10        NVARCHAR(30),
      @c_Lottable11        NVARCHAR(30),
      @c_Lottable12        NVARCHAR(30),
      @c_PickDetailKey     NVARCHAR(10),
      @n_PickQty           INT,
      @c_PackKey           NVARCHAR(10),  
      @c_PickMethod        NVARCHAR(1),
      --@c_Wavekey           NVARCHAR(10),
      @c_WaveType          NVARCHAR(10)

   -- FROM BULK Area 
   SET @c_LocationType = '''OTHER'',''BULK'''      
   SET @c_LocationCategory = ''
   SET @c_PickMethod = 'P'
   SET @c_UOM = '1'

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''
           
   
   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES (  
      SeqNo             INT IDENTITY(1, 1),  
      OrderKey          NVARCHAR(10),
      OrderQty          INT, 
      SKU               NVARCHAR(20),
      PackKey           NVARCHAR(10), 
      StorerKey         NVARCHAR(15), 
      Facility          NVARCHAR(5),  
      Lottable01        NVARCHAR(18), 
      Lottable02        NVARCHAR(18), 
      Lottable03        NVARCHAR(18),
      Lottable06        NVARCHAR(30),
      Lottable07        NVARCHAR(30),
      Lottable08        NVARCHAR(30),
      Lottable09        NVARCHAR(30),
      Lottable10        NVARCHAR(30),
      Lottable11        NVARCHAR(30),
      Lottable12        NVARCHAR(30)
   )

   IF OBJECT_ID('tempdb..#LOTxLOCxID','u') IS NOT NULL
      DROP TABLE #LOTxLOCxID;

   -- Store Stock in Inventory (LOTxLOCxID info)
   CREATE TABLE #LOTxLOCxID (  
      Loc               NVARCHAR(10), 
      LogicalLocation   NVARCHAR(18), 
      [Lot]             NVARCHAR(10), 
      [ID]              NVARCHAR(18),
      Qty               INT,
      QtyAvailable      INT
   )

   IF OBJECT_ID('tempdb..#IDxLOC','u') IS NOT NULL
      DROP TABLE #IDxLOC;

   CREATE TABLE #IDxLOC (  
      SeqNo        INT IDENTITY(1, 1),
      ID           NVARCHAR(18), 
      LOC          NVARCHAR(10),
      QtyAvailable INT
   )

   /***************************************************************/
   /***  GET ORDERLINES OF WAVE Group By Order#                 ***/
   /***************************************************************/
   INSERT INTO #ORDERLINES (Orderkey,
                            OrderQty,
                            SKU, 
                            PackKey, 
                            StorerKey,
                            Facility,
                            Lottable01,
                            Lottable02,
                            Lottable03,
                            Lottable06,
                            Lottable07,
                            Lottable08,
                            Lottable09,
                            Lottable10,
                            Lottable11,
                            Lottable12)
   SELECT  
      ISNULL(RTRIM(O.Orderkey),''), 
      SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),''),
      ISNULL(RTRIM(OD.Lottable06),''),
      ISNULL(RTRIM(OD.Lottable07),''),
      ISNULL(RTRIM(OD.Lottable08),''),
      ISNULL(RTRIM(OD.Lottable09),''),
      ISNULL(RTRIM(OD.Lottable10),''),
      ISNULL(RTRIM(OD.Lottable11),''),
      ISNULL(RTRIM(OD.Lottable12),'')
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.Wavekey = @c_WaveKey
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
   GROUP BY 
      ISNULL(RTRIM(O.Orderkey),''),
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),''),
      ISNULL(RTRIM(OD.Lottable06),''),
      ISNULL(RTRIM(OD.Lottable07),''),
      ISNULL(RTRIM(OD.Lottable08),''),
      ISNULL(RTRIM(OD.Lottable09),''),
      ISNULL(RTRIM(OD.Lottable10),''),
      ISNULL(RTRIM(OD.Lottable11),''),
      ISNULL(RTRIM(OD.Lottable12),'')

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   /*******************************/
   /***  LOOP BY DISTINCT SKU   ***/
   /*******************************/

   DECLARE CURSOR_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU, StorerKey, Facility, Packkey, Lottable01, Lottable02, Lottable03, Lottable06, 
                   Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12
   FROM #ORDERLINES

   OPEN CURSOR_ORDERLINES               
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Packkey, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                          @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable03 + CHAR(13) + 
               ', @c_Lottable06: ' + @c_Lottable06 + CHAR(13) + 
               ', @c_Lottable07: ' + @c_Lottable07 + CHAR(13) + 
               ', @c_Lottable08: ' + @c_Lottable08 + CHAR(13) + 
               ', @c_Lottable09: ' + @c_Lottable09 + CHAR(13) + 
               ', @c_Lottable10: ' + @c_Lottable10 + CHAR(13) + 
               ', @c_Lottable11: ' + @c_Lottable11 + CHAR(13) + 
               ', @c_Lottable12: ' + @c_Lottable12 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               '--------------------------------------------' 
      END

      /************************************************/
      /***  INSERT LOTxLOCxID FOR CURRENT SKU   ***/
      /************************************************/
      SET @c_SQL = N'
      INSERT INTO #LOTxLOCxID (Loc, LogicalLocation, Lot, ID, Qty, QtyAvailable)
      SELECT Loc.Loc, Loc.LogicalLocation, LOTxLOCxID.LOT, LOTxLOCxID.ID, LOTXLOCXID.Qty,
             (LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable
      FROM LOTxLOCxID WITH (NOLOCK)      
         JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
         JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
         JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
      WHERE LOC.LocationFlag <> ''HOLD''       
         AND LOC.LocationFlag <> ''DAMAGE''       
         AND LOC.Status <> ''HOLD''       
         AND LOC.Facility = @c_Facility   
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType IN (' + @c_LocationType + ')' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory IN (' + @c_LocationCategory + ')' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' + CHAR(13) END +  
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' + CHAR(13) END +  
         ' AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) > 0'
         
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
      
      --Remove pallet with multi-sku, partial allocated
      DELETE FROM #LOTxLOCxID      
      WHERE ID IN (
                    SELECT LID.ID
                    FROM #LOTxLOCxID LID
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LID.LOT = LA.LOT
                    WHERE ISNULL(LID.ID,'') <> ''            
                    GROUP BY LID.ID
                    HAVING COUNT(DISTINCT LA.Sku) > 1 OR SUM(LID.Qty - LID.QtyAvailable) > 0
                  )
      
      DELETE FROM #IDxLOC
      
      --Retrieve sum qty for the pallet and loc
      INSERT INTO #IDxLOC (ID, LOC, QtyAvailable)
      SELECT LLI.ID, LLI.LOC, SUM(LLI.QtyAvailable)
      FROM #LOTxLOCxID LLI
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
      GROUP BY LLI.ID, LLI.LOC, LLI.LogicalLocation
      ORDER BY MIN(LA.Lottable05), MIN(LLI.Lot), LLI.LogicalLocation, LLI.Loc, LLI.ID
                  
      --Get Lower Bound to reduce loop size
      SELECT @n_LowerBound = MIN(QtyAvailable)      
      FROM #IDxLOC

      /*****************************************************************************/
      /***  START ALLOC BY ORDER GROUP (Order No)                                ***/
      /*****************************************************************************/
      SET @c_SQL = N'
      DECLARE CURSOR_ORDERLINE_SKU CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT Orderkey, OrderQty
      FROM #ORDERLINES WITH (NOLOCK)
      WHERE OrderQty >= @n_LowerBound 
        AND SKU = @c_SKU 
        AND StorerKey = @c_StorerKey
        AND Facility = @c_Facility ' + CHAR(13) + 
        CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND Lottable03 = @c_Lottable03 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND Lottable08 = @c_Lottable08 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND Lottable11 = @c_Lottable11 ' + CHAR(13) END +      
        CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND Lottable12 = @c_Lottable12 ' END
 
      SET @c_SQLParm =  N'@n_LowerBound INT, @c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), '  +
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), '  +
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @n_LowerBound, @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12

      OPEN CURSOR_ORDERLINE_SKU               
      FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_Orderkey, @n_OrderQty
      
      --Retrieve all the order groups of the sku      
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN    
         IF @b_Debug = 1
         BEGIN
            SELECT @c_Orderkey AS 'Orderkey', @n_OrderQty AS 'OrderQty'
            PRINT 'Orderkey: ' + @c_Orderkey + ', OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) 
            PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END         
         
         --Allocate the order 
         WHILE @n_OrderQty > 0
         BEGIN         
            SELECT @c_ID = '', @c_Loc ='',  @n_IDQty = 0, @n_PickQty = 0
            
            --Find the full pallet
            SELECT TOP 1 @c_ID = ID, @c_Loc = Loc, @n_IDQty = QtyAvailable
            FROM #IDxLOC
            WHERE QtyAvailable <= @n_OrderQty
            AND QtyAvailable > 0
            ORDER BY SeqNo
            
            IF ISNULL(@n_IDQty,0) = 0
               BREAK
            
            DECLARE CURSOR_PICKID CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT Lot, QtyAvailable
            FROM #LOTxLOCxID WITH (NOLOCK)
            WHERE ID = @c_ID
            AND LOC = @c_Loc

            OPEN CURSOR_PICKID               
            FETCH NEXT FROM CURSOR_PICKID INTO @c_Lot, @n_PickQty
                   
            --Retrieve all lots of the pallet
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN 
               SET @c_SQL = N'
               DECLARE CURSOR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT O.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty
               FROM ORDERS O (NOLOCK)
               JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
               JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey
               WHERE O.Orderkey = @c_Orderkey
               AND OD.SKU = @c_SKU 
               AND O.StorerKey = @c_StorerKey
               AND WD.Wavekey = @c_Wavekey
               AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0
               AND O.Facility = @c_Facility ' + CHAR(13) + 
               CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND OD.Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND OD.Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND OD.Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND OD.Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND OD.Lottable08 = @c_Lottable08 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND OD.Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND OD.Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND OD.Lottable11 = @c_Lottable11 ' + CHAR(13) END +      
               CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND OD.Lottable12 = @c_Lottable12 ' END +
               'ORDER BY O.Orderkey, OD.OrderLineNumber'
               
               SET @c_SQLParm =  N'@c_Orderkey NVARCHAR(10), @c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Facility NVARCHAR(5), ' +      
                                  '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                                  '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                                  '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                                  '@c_Lottable12 NVARCHAR(30) ' 
                  
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Orderkey, @c_SKU, @c_StorerKey, @c_Wavekey, @c_Facility, @c_Lottable01, @c_Lottable02, 
                                  @c_Lottable03, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
                        
               OPEN CURSOR_ORDLINE               
               FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
               
               --Retrieve all order lines for the order group and create pickdetail
               WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0         
               BEGIN 
               	 IF @n_OrderLineQty <= @n_PickQty 
               	 BEGIN
               	    SET @n_InsertQty = @n_OrderLineQty
               	    SET @n_PickQty = @n_PickQty - @n_OrderLineQty
               	 END
               	 ELSE
               	 BEGIN
               	 	  SET @n_InsertQty = @n_PickQty
               	 	  SET @n_PickQty = 0
               	 END
               	    
                  -- INSERT #PickDetail
                  EXECUTE nspg_getkey  
                    'PickDetailKey'  
                    , 10  
                    , @c_PickDetailKey OUTPUT  
                    , @b_Success       OUTPUT  
                    , @n_Err           OUTPUT  
                    , @c_ErrMsg        OUTPUT  
                  
                  IF @b_Success <> 1  
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 13000
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Get PickDetailKey Failed. (ispPRPS01)'
                     GOTO Quit
                  END
                  ELSE
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                              'OrderKey: ' + @c_OrderKey + CHAR(13) +
                              'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                              'PickQty: ' + CAST(@n_PickQty AS NVARCHAR) + CHAR(13) +
                              'InsertQty: ' + CAST(@n_InsertQty AS NVARCHAR) + CHAR(13) +
                              'SKU: ' + @c_SKU + CHAR(13) +
                              'PackKey: ' + @c_PackKey + CHAR(13) +
                              'Lot: ' + @c_Lot + CHAR(13) +
                              'Loc: ' + @c_Loc + CHAR(13) +
                              'ID: ' + @c_ID + CHAR(13) +
                              'UOM: ' + @c_UOM + CHAR(13)
                     END
                                          
                     INSERT PICKDETAIL (  
                         PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                         Lot, StorerKey, Sku, UOM, UOMQty, Qty, 
                         Loc, Id, PackKey, CartonGroup, DoReplenish,  
                         replenishzone, doCartonize, Trafficcop, PickMethod  
                     ) VALUES (  
                         @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                         @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_InsertQty, @n_InsertQty, 
                         @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                         '', NULL, 'U', @c_PickMethod  
                     ) 
                  
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 13001
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                        ': Insert PickDetail Failed. (ispPRPS01)'
                        GOTO Quit
                     END
                  END -- IF @b_Success = 1                  	 
               	 
                  FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
               END
               CLOSE CURSOR_ORDLINE         
               DEALLOCATE CURSOR_ORDLINE      
                               	
               FETCH NEXT FROM CURSOR_PICKID INTO @c_Lot, @n_PickQty
            END
            CLOSE CURSOR_PICKID         
            DEALLOCATE CURSOR_PICKID
            
            SET @n_OrderQty = @n_OrderQty - @n_IDQty
            
            DELETE FROM #LOTxLOCxID WHERE ID = @c_ID AND LOC = @c_Loc
            DELETE FROM #IDxLOC WHERE ID = @c_ID AND LOC = @c_Loc
         END

         FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_Orderkey, @n_OrderQty
      END -- END WHILE FOR CURSOR_ORDERLINE_SKU              
      CLOSE CURSOR_ORDERLINE_SKU
      DEALLOCATE CURSOR_ORDERLINE_SKU

      
      /*****************************/
      /***  Clear All TEMP Table ***/
      /*****************************/
      DELETE FROM #LOTxLOCxID
      DELETE FROM #IDXLOC

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Packkey, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                             @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
   END -- END WHILE FOR CURSOR_ORDERLINES             
   CLOSE CURSOR_ORDERLINES          
   DEALLOCATE CURSOR_ORDERLINES

   IF @b_Debug = 1
   BEGIN
      SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber, PD.Qty, PD.SKU, PD.PackKey, PD.Lot, PD.Loc, PD.ID, PD.UOM
      FROM PickDetail PD WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
      WHERE WD.Wavekey = @c_Wavekey
   END

QUIT:

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINE_SKU')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINE_SKU           
      DEALLOCATE CURSOR_ORDERLINE_SKU      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKID')) >=0 
   BEGIN
      CLOSE CURSOR_PICKUCC           
      DEALLOCATE CURSOR_PICKUCC      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDLINE')) >=0 
   BEGIN
      CLOSE CURSOR_ORDLINE           
      DEALLOCATE CURSOR_ORDLINE      
   END  
   
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   IF OBJECT_ID('tempdb..#LOTxLOCxID','u') IS NOT NULL
      DROP TABLE #LOTxLOCxID;

   IF OBJECT_ID('tempdb..#IDxLOC','u') IS NOT NULL
      DROP TABLE #IDxLOC;

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRPS01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  

END -- Procedure

GO