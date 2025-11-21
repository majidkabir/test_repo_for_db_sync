SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRCAR02                                         */    
/* Creation Date: 02-Feb-2016                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: 358754 - CN Carters SZ - Pre-Allocation process to allocate */
/*          full carton by ship-to(M_Address4) and omnia order#         */
/*          (Userdefine03) or single order(AE) from case->pallet location*/ 
/*          For IFC, Traditional, Asia Ecom and skip hop only.          */
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
/* 23-Feb-2018  NJOW01    1.0   WMS-4038 change M_ISOCntrycode to       */
/*                              M_address4. Include AE single order.    */
/* 22-Jan-2020  NJOW02    1.1   WMS-11883 Include Skip Hop              */
/************************************************************************/    
CREATE PROC [dbo].[ispPRCAR02]        
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
      @c_SQLParm     NVARCHAR(MAX)

   DECLARE 
      @n_OrderQty        INT,
      @n_UCCQty          INT,
      @n_CntCount        INT,
      @n_LowerBound      INT,
      @n_CntNeeded       INT,
      @b_Found           INT,
      @n_Count           INT,
      @n_Sum             INT,
      @n_Number          INT, 
      @n_Pos             INT,
      @c_Subset          NVARCHAR(MAX), 
      @n_Result          INT,
      @c_Result          NVARCHAR(MAX),
      @c_TempStr         NVARCHAR(MAX),
      @b_Flag            INT,
      @n_Qty             INT,
      @n_InsertQty       INT

   DECLARE 
      @c_Loc               NVARCHAR(10),
      @c_Lot               NVARCHAR(10),
      @c_ID                NVARCHAR(18),
      @c_OrderKey          NVARCHAR(10),
      @c_OrderLineNumber   NVARCHAR(5),
      @c_Facility          NVARCHAR(5),     
      @c_StorerKey         NVARCHAR(15),     
      @c_LocationType      NVARCHAR(10),    
      @c_LocationCategory  NVARCHAR(10),
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
      @c_WaveType          NVARCHAR(10),
      @c_ShipTo            NVARCHAR(45), --NJOW01
      @c_OmniaOrderNo      NVARCHAR(20),
      @c_LocationHandling  NVARCHAR(10),
      @n_SeqNo             INT --NJOW02

   -- FROM BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'BULK'
   SET @c_PickMethod = 'C'
   SET @c_UOM = '2'
   SET @c_LocationHandling = '2'

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''
   
   --SELECT TOP 1 @c_Wavekey = Userdefine09
   --FROM ORDERS(NOLOCK)
   --WHERE Loadkey = @c_Loadkey
        
   SELECT @c_WaveType = DispatchPiecePickMethod
   FROM WAVE (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF ISNULL(@c_WaveType,'') NOT IN('I','T','H','E','S')
   BEGIN   
      SET @n_Err = 13000
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Invalid Wave Piece Pick Task Dispatch Method. Must Be I,H,T,E or S (ispPRCAR02)'
      GOTO Quit
   END                     
   
   IF ISNULL(@c_WaveType,'') = 'H' 
     GOTO Quit

   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES (  
      SeqNo             INT IDENTITY(1, 1),  
      ShipTo            NVARCHAR(45), --Orders.M_Address4
      OmniaOrderNo      NVARCHAR(20), --Orders.Userdefine03
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
      Lottable12        NVARCHAR(30),
      Result            NVARCHAR(MAX) 
   )

   IF OBJECT_ID('tempdb..#UCCxLOTxLOCxID','u') IS NOT NULL
      DROP TABLE #UCCxLOTxLOCxID;

   -- Store Stock in Inventory (UCC & LOTxLOCxID info)
   CREATE TABLE #UCCxLOTxLOCxID (  
      SeqNo             INT IDENTITY(1, 1),  --NJOW02
      UCCQty            INT, 
      CntCount          INT, 
      Loc               NVARCHAR(10), 
      LocationHandling  NVARCHAR(10), 
      LogicalLocation   NVARCHAR(18), 
      [Lot]             NVARCHAR(10), 
      [ID]              NVARCHAR(18),
      AllocFullPallet   INT DEFAULT 0
   )

   IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
      DROP TABLE #NumPool;

   -- For  Pre-Alloc UCC processing
   CREATE TABLE #NumPool (  
      UCCQty        INT,
      CntCount      INT DEFAULT 0, 
      CntAllocated  INT DEFAULT 0
   )

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   -- Store all possible combination numbers
   CREATE TABLE #CombinationPool (
      [Sum]    INT, 
      Subset   NVARCHAR(MAX)
   )

   IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
      DROP TABLE #SplitList;

   -- Store SPLIT of #CombinationPool.Subset
   CREATE TABLE #SplitList (  
      UCCQty            INT, 
      CntCount          INT
   )

START:

   /*********************************/
   /***  GET ORDERLINES OF WAVE   ***/
   /*********************************/
   INSERT INTO #ORDERLINES (ShipTo,
                            OmniaOrderNo,
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
                            Lottable12,
                            Result)
   SELECT  
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.M_Address4),'') END,  --NJOW01 
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.Userdefine03),'') END, --NJOW01
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
      ISNULL(RTRIM(OD.Lottable12),''),
      ''
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
     AND O.OpenQty = CASE WHEN @c_WaveType = 'E' THEN 1 ELSE O.OpenQty END --NJOW01  
   GROUP BY 
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.M_Address4),'') END,  --NJOW01
      CASE WHEN @c_WaveType = 'E' THEN ''
        ELSE ISNULL(RTRIM(O.Userdefine03),'') END, --NJOW01
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

   DECLARE CURSOR_ORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU, StorerKey, Facility, Lottable01, Lottable02, Lottable03, Lottable06, 
                   Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12
   FROM #ORDERLINES

   OPEN CURSOR_ORDERLINES               
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
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
      /***  INSERT UCCxLOTxLOCxID FOR CURRENT SKU   ***/
      /************************************************/
      -- FIXED: Corrected number of carton (UCC) that can be allocated (UCC.Status does not update until pallet build)
      SET @c_SQL = N'
      INSERT INTO #UCCxLOTxLOCxID (UCCQty, CntCount, Loc, LocationHandling, LogicalLocation, Lot, ID)
      SELECT DISTINCT UCC.Qty, COUNT(1) - CEILING((LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYREPLEN)/(UCC.Qty * 1.0)), Loc.Loc, Loc.LocationHandling, Loc.LogicalLocation, LOTxLOCxID.LOT, LOTxLOCxID.ID 
      FROM LOTxLOCxID WITH (NOLOCK)      
         JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)      
         JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')       
         JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')         
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LOT.LOT = LA.LOT            
         JOIN UCC WITH (NOLOCK) ON (UCC.SKU = LOTxLOCxID.SKU AND UCC.LOT = LOT.LOT AND UCC.LOC = LOC.LOC AND UCC.ID = ID.ID
                                          AND UCC.Status < ''3'')
      WHERE LOC.LocationFlag <> ''HOLD''       
         AND LOC.LocationFlag <> ''DAMAGE''       
         AND LOC.Status <> ''HOLD''       
         AND LOC.Facility = @c_Facility   
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU ' + CHAR(13) +
         CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN '' 
              ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
              ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_LocationHandling),'') = '' THEN ''       
              ELSE ' AND LOC.LocationHandling = ''' + @c_LocationHandling + '''' + CHAR(13) END +      
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
         'AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= UCC.Qty
      GROUP BY UCC.Qty, Loc.LocationHandling, Loc.LogicalLocation, LOC.LOC, LOTxLOCxID.LOT, LOTxLOCxID.ID, LOTxLOCxID.QTYALLOCATED, LOTxLOCxID.QTYREPLEN
      HAVING COUNT(1) - CEILING((LOTxLOCxID.QTYALLOCATED + LOTxLOCxID.QTYREPLEN)/(UCC.Qty * 1.0)) > 0 
      ORDER BY Loc.LocationHandling DESC, Loc.LogicalLocation, LOC.LOC'

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
      

      --NJOW02
      IF ISNULL(@c_WaveType,'') = 'S'
      BEGIN
      	 --Remove lot not reserved
      	 DELETE #UCCxLOTxLOCxID
         FROM #UCCxLOTxLOCxID
         LEFT JOIN ##CARLOT (NOLOCK) ON #UCCxLOTxLOCxID.Lot = ##CARLOT.Lot AND ##CARLOT.SP_ID = @@SPID AND ##CARLOT.Qty - ##CARLOT.QtyAllocated > 0
         WHERE ##CARLOT.Lot IS NULL          
         
         --loop to remove ucc not suffience qty with reserved lot        
         DECLARE CURSOR_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT ##CARLOT.Lot, ##CARLOT.Qty - ##CARLOT.QtyAllocated AS QtyAvailable
            FROM ##CARLOT (NOLOCK) 
            WHERE ##CARLOT.SP_ID= @@SPID 
            AND ##CARLOT.Qty - ##CARLOT.QtyAllocated > 0
            ORDER BY ##CARLOT.Lot
         
         OPEN CURSOR_LOT           
          
         FETCH NEXT FROM CURSOR_LOT INTO @c_Lot, @n_Qty
          
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN         	  
         	  DECLARE CURSOR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         	     SELECT Seqno, UCCQty
         	     FROM #UCCxLOTxLOCxID 
         	     WHERE Lot = @c_Lot
         	     ORDER BY LocationHandling DESC, LogicalLocation, LOC

            OPEN CURSOR_UCC
            
            FETCH NEXT FROM CURSOR_UCC INTO @n_SeqNo, @n_UCCQty
         	
         	  WHILE (@@FETCH_STATUS <> -1) 
         	  BEGIN
         	  	 IF @n_Qty >= @n_UCCQty
         	  	    SET @n_Qty = @n_Qty - @n_UCCQty
         	  	 ELSE IF @n_Qty < @n_UCCQty
         	  	 BEGIN
         	  	    DELETE FROM #UCCxLOTxLOCxID 
         	  	    WHERE Seqno = @n_Seqno
         	  	    
         	  	    SET @n_Qty = 0
         	  	 END          	  	       
         	  	 
               FETCH NEXT FROM CURSOR_UCC INTO @n_SeqNo, @n_UCCQty
         	  END      
         	  CLOSE CURSOR_UCC
         	  DEALLOCATE CURSOR_UCC  
         	
            FETCH NEXT FROM CURSOR_LOT INTO @c_Lot, @n_Qty
         END
         CLOSE CURSOR_LOT
         DEALLOCATE CURSOR_LOT         
      END                                                  

      INSERT INTO #NumPool (UCCQty, CntCount)
      SELECT UCCQty, SUM(CntCount)
      FROM #UCCxLOTxLOCxID WITH (NOLOCK)
      GROUP BY UCCQty
            
      -- Get Lower Bound to reduce loop size
      SELECT @n_LowerBound = MIN(UCCQty)
      FROM #NumPool

      /*****************************************************************************/
      /***  START PRE-ALLOC UCC (Get Combination of pool numbers for orderQty)   ***/
      /*****************************************************************************/
      SET @c_SQL = N'
      DECLARE CURSOR_ORDERLINE_SKU CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT ShipTo, OmniaOrderNo, OrderQty
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
      FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty
             
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN    
         -- 1 = FOUND
         SET @b_Found = 0
         SET @c_Result = ''

         IF @b_Debug = 1
         BEGIN
            SELECT @c_ShipTo AS 'ShipTo', @c_OmniaOrderNo AS 'OmniaOrderNo', @n_OrderQty AS 'OrderQty'
            PRINT 'ShipTo: ' + @c_ShipTo + ', OmniaOrderNo: ' + @c_OmniaOrderNo + ', OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) 
            PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /*********************************************************************************************/
         /***  STEP 1: Try MOD OrderQty with all number in NumPool = 0, GOTO STEP 2 IF no result   ***/
         /*********************************************************************************************/
         SET @n_UCCQty = 0

         --find the ucc size fit the order qty.
         SELECT TOP 1 @n_UCCQty = UCCQty
         FROM #NumPool WITH (NOLOCK)
         WHERE @n_OrderQty % UCCQty = 0
           AND @n_OrderQty/UCCQty <= CntCount
           AND CntCount > 0

         IF ISNULL(@n_UCCQty,0) <> 0
         BEGIN
            SET @b_Found = 1
            SET @n_CntNeeded = @n_OrderQty/@n_UCCQty
            SET @c_Result = CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntNeeded AS NVARCHAR)
            SET @n_Result = @n_CntNeeded * @n_UCCQty

            -- Update Result to #ORDERLINES
            UPDATE #ORDERLINES WITH (ROWLOCK)
            SET Result = @c_Result
            WHERE ShipTo = @c_ShipTo
            AND OmniaOrderNo = @c_OmniaOrderNo
            AND Facility = @c_Facility
            AND Storerkey = @c_Storerkey
            AND Sku = @c_Sku
            AND Lottable01 = @c_Lottable01 
            AND Lottable02 = @c_Lottable02 
            AND Lottable03 = @c_Lottable03 
            AND Lottable06 = @c_Lottable06 
            AND Lottable07 = @c_Lottable07 
            AND Lottable08 = @c_Lottable08 
            AND Lottable09 = @c_Lottable09 
            AND Lottable10 = @c_Lottable10 
            AND Lottable11 = @c_Lottable11 
            AND Lottable12 = @c_Lottable12 

            SELECT 
               @n_CntCount = CntCount,
               @n_Count = CntCount - @n_CntNeeded
            FROM #NumPool WITH (NOLOCK)
            WHERE UCCQty = @n_UCCQty

            -- Update #NumPool.cntCount
            UPDATE #NumPool WITH (ROWLOCK)
            SET CntCount = @n_Count, 
                CntAllocated = CntAllocated + @n_CntNeeded
            WHERE UCCQty = @n_UCCQty

            IF @n_Count > 0
            BEGIN
               WHILE (@n_CntCount > @n_Count)
               BEGIN
                  DELETE FROM #CombinationPool WITH (ROWLOCK)
                  WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntCount AS NVARCHAR), Subset) > 0 

                  IF @b_Debug = 1
                  BEGIN
                     PRINT '/** REMOVED ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntCount AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
                  END
                  SET @n_CntCount = @n_CntCount - 1
               END
            END -- IF @n_Count > 0
            ELSE
            BEGIN
               DELETE FROM #CombinationPool WITH (ROWLOCK)
               WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) > 0

               IF @b_Debug = 1
               BEGIN
                  PRINT '/** REMOVED ' + CAST(@n_UCCQty AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
               END
            END -- IF @n_Count <= 0
         END -- IF ISNULL(@n_UCCQty,'') <> ''

         IF @b_Debug = 1
         BEGIN
            PRINT 'STEP 1: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /***************************************************************************************************/
         /***  STEP 2: Get all possible combination of numbers, GET Combination with least Remainder,     ***/
         /***  exit if no result                                                                          ***/
         /***************************************************************************************************/
         IF @b_Found <> 1
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
            END

            SELECT @n_Count = COUNT(1) 
            FROM #CombinationPool WITH (NOLOCK)

            /*********************************************************************/
            /***   START: Get all possible combination of NumPool (once only)  ***/
            /*********************************************************************/
            IF @n_Count = 0
            BEGIN
               DECLARE CURSOR_COMBINATION CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT UCCQty, CntCount
               FROM #NumPool WITH (ROWLOCK)
               WHERE CntCount > 0

               OPEN CURSOR_COMBINATION               
               FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount
                      
               WHILE (@@FETCH_STATUS <> -1)          
               BEGIN
                  SET @n_Count = 1

                  WHILE (@n_Count <= @n_CntCount)
                  BEGIN
                     INSERT INTO #CombinationPool 
                     VALUES (@n_UCCQty * @n_Count, 
                             CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     DECLARE CURSOR_COMBINATION_INNER CURSOR FAST_FORWARD READ_ONLY FOR 
                     SELECT [Sum], Subset 
                     FROM #CombinationPool WITH (NOLOCK)
                     WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) = 0 
                     --WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR), Subset) = 0

                     OPEN CURSOR_COMBINATION_INNER               
                     FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     WHILE (@@FETCH_STATUS <> -1)          
                     BEGIN

                        INSERT INTO #CombinationPool 
                        VALUES (@n_Sum + @n_UCCQty * @n_Count, 
                                @c_Subset + ' + ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                        FETCH NEXT FROM CURSOR_COMBINATION_INNER INTO @n_Sum, @c_Subset
                     END -- END WHILE FOR CURSOR_COMBINATION_INNER      
                     CLOSE CURSOR_COMBINATION_INNER          
                     DEALLOCATE CURSOR_COMBINATION_INNER 

                     SET @n_Count = @n_Count + 1
                  END

                  FETCH NEXT FROM CURSOR_COMBINATION INTO @n_UCCQty, @n_CntCount
               END -- END WHILE FOR CURSOR_COMBINATION      
               CLOSE CURSOR_COMBINATION
               DEALLOCATE CURSOR_COMBINATION  

               IF @b_Debug = 1
               BEGIN
                  SELECT @c_SKU, * 
                  FROM #CombinationPool 
                  ORDER BY [Sum] DESC,
                           LEN(Subset) - LEN(REPLACE(Subset, '+', ''))
               END   
            END -- IF @n_Count = 0
            /*******************************************************************/
            /***   END: Get all possible combination of NumPool (once only)  ***/
            /*******************************************************************/

            SET @c_Result = ''
            -- GET Combination with least Remainder, least number combination
            SELECT TOP 1 @c_Result = Subset, @n_Result = [Sum]
            FROM #CombinationPool WITH (NOLOCK)
            WHERE [Sum] <= @n_OrderQty               
            ORDER BY [Sum] DESC,
                     LEN(Subset) - LEN(REPLACE(Subset, '+', ''))   --less combination

            IF ISNULL(@c_Result,'') <> ''
            BEGIN
               SET @b_Found = 1

               -- Update Result to #ORDERLINES 
               UPDATE #ORDERLINES WITH (ROWLOCK)
               SET Result = @c_Result
               WHERE ShipTo = @c_ShipTo
               AND OmniaOrderNo = @c_OmniaOrderNo
               AND Facility = @c_Facility
               AND Storerkey = @c_Storerkey
               AND Sku = @c_Sku
               AND Lottable01 = @c_Lottable01 
               AND Lottable02 = @c_Lottable02 
               AND Lottable03 = @c_Lottable03 
               AND Lottable06 = @c_Lottable06 
               AND Lottable07 = @c_Lottable07 
               AND Lottable08 = @c_Lottable08 
               AND Lottable09 = @c_Lottable09 
               AND Lottable10 = @c_Lottable10 
               AND Lottable11 = @c_Lottable11 
               AND Lottable12 = @c_Lottable12 

               -- Clear #SplitList
               DELETE FROM #SplitList
               SET @c_TempStr = @c_Result

               -- Convert Result string into #SplitList table
               WHILE CHARINDEX('+', @c_TempStr) > 0
               BEGIN
                  SET @n_Pos  = CHARINDEX('+', @c_TempStr)  
                  SET @c_Subset = SUBSTRING(@c_TempStr, 1, @n_Pos-2)
                  SET @c_TempStr = SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr)-@n_Pos)

                  SET @n_Pos  = CHARINDEX('*', @c_Subset)
                  SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
                  SET @n_CntCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
                  INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 
               END -- WHILE CHARINDEX('+', @c_Result) > 0

               SET @n_Pos  = CHARINDEX('*', @c_TempStr)
               SET @n_Number = CAST(SUBSTRING(@c_TempStr, 1, @n_Pos-2) AS INT)
               SET @n_CntCount = CAST(SUBSTRING(@c_TempStr, @n_Pos+2, LEN(@c_TempStr) - @n_Pos+2) AS INT)
               INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 

               -- Clear #CombinationPool  
               DECLARE CURSOR_SPLITLIST CURSOR FAST_FORWARD READ_ONLY FOR 
               SELECT UCCQty, CntCount 
               FROM #SplitList WITH (NOLOCK)

               OPEN CURSOR_SPLITLIST
               FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_UCCQty, @n_CntNeeded

               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  SELECT 
                     @n_CntCount = CntCount,
                     @n_Count = CntCount - @n_CntNeeded
                  FROM #NumPool WITH (NOLOCK)
                  WHERE UCCQty = @n_UCCQty

                  -- Update #NumPool.cntCount
                  UPDATE #NumPool WITH (ROWLOCK)
                  SET CntCount = @n_Count, 
                      CntAllocated = CntAllocated + @n_CntNeeded
                  WHERE UCCQty = @n_UCCQty

                  IF @n_Count > 0
                  BEGIN
                     WHILE (@n_CntCount > @n_Count)
                     BEGIN
                        DELETE FROM #CombinationPool WITH (ROWLOCK)
                        WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntCount AS NVARCHAR), Subset) > 0 

                        IF @b_Debug = 1
                        BEGIN
                           PRINT '/** REMOVED ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CntCount AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
                        END
                        SET @n_CntCount = @n_CntCount - 1
                     END
                  END -- IF @n_Count > 0
                  ELSE
                  BEGIN
                     DELETE FROM #CombinationPool WITH (ROWLOCK)
                     WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) > 0

                     IF @b_Debug = 1
                     BEGIN
                        PRINT '/** REMOVED ' + CAST(@n_UCCQty AS NVARCHAR) + ' FROM COMBINATION POOL  **/' 
                     END
                  END -- IF @n_Count <= 0

                  FETCH NEXT FROM CURSOR_SPLITLIST INTO @n_UCCQty, @n_CntNeeded
               END -- END WHILE FOR CURSOR_SPLITLIST      
               CLOSE CURSOR_SPLITLIST          
               DEALLOCATE CURSOR_SPLITLIST 
            END -- IF ISNULL(@c_Result,'') <> ''

            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
            END   
         END -- [STEP 2]

         IF @b_Debug = 1
         BEGIN
            IF @b_Found <> 1
               PRINT 'NO RESULT' + CHAR(13)
            ELSE
               PRINT 'RESULT FOR ' + CAST(@n_OrderQty AS NVARCHAR) + ': ' + @c_Result + 
                     ' (Remainder: ' + CAST((@n_OrderQty - @n_Result) AS NVARCHAR) + ')' + CHAR(13) 
         END

         FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty
      END -- END WHILE FOR CURSOR_ORDERLINE_SKU              
      CLOSE CURSOR_ORDERLINE_SKU
      DEALLOCATE CURSOR_ORDERLINE_SKU

      IF @b_Debug = 1
      BEGIN
         SELECT * FROM #NumPool WITH (NOLOCK)
      END

      /***************************/
      /***  END PRE-ALLOC UCC  ***/
      /***************************/
      SET @c_SQL = N'
      SELECT @n_Count = COUNT(1)
      FROM #ORDERLINES WITH (NOLOCK)
      WHERE ISNULL(Result,'''') <> ''''
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
 
      SET @c_SQLParm =  N'@c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                         '@c_Lottable12 NVARCHAR(30), @n_Count INT OUTPUT' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_Count OUTPUT

      IF @n_Count > 0   
      BEGIN
         /**************************************************************/
         /***  START ALLOC UCC (Get Min Location of Pre-Alloc Qty)   ***/
         /**************************************************************/

         IF @b_Debug = 1
         BEGIN
            PRINT 'START Alloc UCC - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END
         
         -- ALLOCATE ALL AVAILABLE FULL PALLET LOCATION
         /*
         DECLARE CURSOR_ALLOCATE_FULLPALLET CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT UCCQty, CntAllocated
         FROM #NumPool WITH (NOLOCK)
         WHERE CntAllocated > 0

         OPEN CURSOR_ALLOCATE_FULLPALLET               
         FETCH NEXT FROM CURSOR_ALLOCATE_FULLPALLET INTO @n_UCCQty, @n_Count
                
         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN 
 
            WHILE (@n_Count > 0)
            BEGIN
               SET @c_Loc = ''

               -- Get Full Pallet Location
               SELECT TOP 1 @c_Loc = Loc, @c_Lot = Lot, @c_ID = ID, @n_CntCount = CntCount
               FROM #UCCxLOTxLOCxID WITH (NOLOCK)
               WHERE UCCQty = @n_UCCQty
               AND LocationHandling IN ('1')
               AND CntCount > 0
               AND CntCount <= @n_Count
               AND AllocFullPallet = 0
               ORDER BY LogicalLocation, Loc

               IF ISNULL(@c_Loc, '') <> ''
               BEGIN
                  -- Update AllocFullPallet for loop below
                  UPDATE #UCCxLOTxLOCxID WITH (ROWLOCK)
                  SET AllocFullPallet = 1
                  WHERE Loc = @c_Loc AND Lot = @c_Lot 
                    AND ID = @c_ID AND CntCount = @n_CntCount

                  SET @n_Count = @n_Count - @n_CntCount
               END -- ISNULL(@c_Loc, '') <> '' 
               ELSE
               BEGIN
                  BREAK
               END 
            END -- WHILE (@n_Count > 0)

            FETCH NEXT FROM CURSOR_ALLOCATE_FULLPALLET INTO @n_UCCQty, @n_Count
         END -- END WHILE FOR CURSOR_ALLOCATE_FULLPALLET      
         CLOSE CURSOR_ALLOCATE_FULLPALLET          
         DEALLOCATE CURSOR_ALLOCATE_FULLPALLET

         IF @b_Debug = 1
         BEGIN
            SELECT * FROM #UCCxLOTxLOCxID WITH (NOLOCK)
         END
         */

         -- ALLOCATE BY ORDERLINE OF SHIPTO + OMNIAORDERNO
         SET @c_SQL = N'
         DECLARE CURSOR_ORDERLINE_SKU CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT ShipTo, OmniaOrderNo, OrderQty, PackKey, Result
         FROM #ORDERLINES WITH (NOLOCK)
         WHERE ISNULL(Result,'''') <> ''''
         AND SKU = @c_SKU 
         AND StorerKey = @c_StorerKey
         AND Facility = @c_Facility ' + CHAR(13) + 
         CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND Lottable06 = @c_Lottable06 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND Lottable07 = @c_Lottable07 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND Lottable08 = @c_Lottable08 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND Lottable09 = @c_Lottable09 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND Lottable10 = @c_Lottable10 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND Lottable11 = @c_Lottable11 ' + CHAR(13) END +      
         CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND Lottable12 = @c_Lottable12 ' END +
         'ORDER BY OrderQty DESC'

         SET @c_SQLParm =  N'@c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), ' +      
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                            '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                            '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                            '@c_Lottable12 NVARCHAR(30) ' 
            
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
         
 
         OPEN CURSOR_ORDERLINE_SKU               
         FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty, @c_PackKey, @c_Result

         WHILE (@@FETCH_STATUS <> -1)          
         BEGIN 
            -- Clear #SplitList
            DELETE FROM #SplitList

            -- Convert Result string into #SplitList table
            WHILE CHARINDEX('+', @c_Result) > 0
            BEGIN
               SET @n_Pos  = CHARINDEX('+', @c_Result)  
               SET @c_Subset = SUBSTRING(@c_Result, 1, @n_Pos-2)
               SET @c_Result = SUBSTRING(@c_Result, @n_Pos+2, LEN(@c_Result)-@n_Pos)

               SET @n_Pos  = CHARINDEX('*', @c_Subset)
               SET @n_Number = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
               SET @n_CntCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)
               INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 
            END -- WHILE CHARINDEX('+', @c_Result) > 0

            SET @n_Pos  = CHARINDEX('*', @c_Result)
            SET @n_Number = CAST(SUBSTRING(@c_Result, 1, @n_Pos-2) AS INT)
            SET @n_CntCount = CAST(SUBSTRING(@c_Result, @n_Pos+2, LEN(@c_Result) - @n_Pos+2) AS INT)
            INSERT INTO #SplitList VALUES (@n_Number, @n_CntCount) 

            DECLARE CURSOR_PICKUCC CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT UCCQty, CntCount
            FROM #SplitList WITH (NOLOCK)

            OPEN CURSOR_PICKUCC               
            FETCH NEXT FROM CURSOR_PICKUCC INTO @n_UCCQty, @n_Count
                   
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN 
               WHILE @n_Count > 0
               BEGIN
               	  IF ISNULL(@c_WaveType,'') = 'S'  --NJOW02
               	  BEGIN
                     SELECT TOP 1 @c_Loc = LLI.Loc, @c_Lot = LLI.Lot, @c_ID = LLI.ID, @n_CntCount = LLI.CntCount
                     FROM #UCCxLOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                     WHERE LLI.UCCQty = @n_UCCQty
                     AND LLI.CntCount > 0
                     ORDER BY LLI.LocationHandling DESC, LA.Lottable05, LA.Lot, LLI.LogicalLocation, LLI.Loc, LLI.CntCount DESC               	  	
               	  END
               	  ELSE
               	  BEGIN
                     SELECT TOP 1 @c_Loc = Loc, @c_Lot = Lot, @c_ID = ID, @n_CntCount = CntCount
                     FROM #UCCxLOTxLOCxID WITH (NOLOCK)
                     WHERE UCCQty = @n_UCCQty
                     AND CntCount > 0
                     ORDER BY LocationHandling DESC, LogicalLocation, Loc, CntCount DESC
                     --ORDER BY AllocFullPallet DESC, LocationHandling DESC, LogicalLocation, Loc, CntCount DESC
                  END
                  
                  IF ISNULL(@c_Lot,'') = ''
                     BREAK

                  -- UPDATE @n_Count
                  IF (@n_CntCount - @n_Count) >= 0
                  BEGIN
                     SET @n_CntCount = @n_Count
                     SET @n_Count = 0
                  END
                  ELSE
                  BEGIN
                     SET @n_Count = @n_Count - @n_CntCount
                  END

                  -- UPDATE #UCCxLOTxLOCxID
                  UPDATE #UCCxLOTxLOCxID WITH (ROWLOCK)
                  SET CntCount = CntCount - @n_CntCount
                  WHERE UCCQty = @n_UCCQty
                  AND Loc = @c_Loc
                  AND Lot = @c_Lot
                  AND ID  = @c_ID

                  SET @n_PickQty = @n_UCCQty * @n_CntCount
                  
                  -- Create pickdetail 
                  SET @c_SQL = N'
                  DECLARE CURSOR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR 
                  SELECT O.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty
                  FROM ORDERS O (NOLOCK)
                  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                  JOIN WAVEDETAIL WD (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE OD.SKU = @c_SKU 
                  AND O.StorerKey = @c_StorerKey
                  AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0 ' +
                  CASE WHEN @c_WaveType = 'E' THEN '' ELSE ' AND O.M_Address4 = @c_ShipTo ' END +   --NJOW01
                  CASE WHEN @c_WaveType = 'E' THEN '' ELSE ' AND O.Userdefine03 = @c_OmniaOrderNo ' END +  --NJOW01
                ' AND WD.Wavekey = @c_Wavekey
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
                  'ORDER BY O.Orderkey'
                  
                  SET @c_SQLParm =  N'@c_Shipto NVARCHAR(45), @c_OmniaOrderno NVARCHAR(20), @c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Facility NVARCHAR(5), ' +      
                                     '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +
                                     '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' +
                                     '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +
                                     '@c_Lottable12 NVARCHAR(30) ' 
                     
                  EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_ShipTo, @c_OmniaOrderNo, @c_SKU, @c_StorerKey, @c_Wavekey, @c_Facility, @c_Lottable01, @c_Lottable02, 
                                     @c_Lottable03, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
                           
                  OPEN CURSOR_ORDLINE               
                  FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_Qty
                   
                  WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0         
                  BEGIN 
                  	 IF @n_Qty <= @n_PickQty 
                  	 BEGIN
                  	    SET @n_InsertQty = @n_Qty
                  	    SET @n_PickQty = @n_PickQty - @n_Qty
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
                                        ': Get PickDetailKey Failed. (ispPRCAR02)'
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
                            @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UCCQty, @n_InsertQty, 
                            @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                            '', NULL, 'U', @c_PickMethod  
                        ) 
                     
                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 13001
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                           ': Insert PickDetail Failed. (ispPRCAR02)'
                           GOTO Quit
                        END
                        
                        --NJOW02
                        IF ISNULL(@c_WaveType,'') = 'S' 
                        BEGIN 
                           UPDATE ##CARLOT WITH (ROWLOCK)
                           SET QtyAllocated = QtyAllocated + @n_InsertQty
                           WHERE Lot = @c_Lot
                           AND SP_ID = @@SPID
                        END                         
                     END -- IF @b_Success = 1                  	 
                  	 
                     FETCH NEXT FROM CURSOR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_Qty
                  END
                  CLOSE CURSOR_ORDLINE         
                  DEALLOCATE CURSOR_ORDLINE                
               END

               FETCH NEXT FROM CURSOR_PICKUCC INTO @n_UCCQty, @n_Count
            END -- END WHILE FOR CURSOR_PICKDETAIL      
            CLOSE CURSOR_PICKUCC         
            DEALLOCATE CURSOR_PICKUCC

            -- UPDATE Result so wont repeat pickdetail insert
            UPDATE #ORDERLINES WITH (ROWLOCK)
            SET Result = ''
            WHERE ShipTo = @c_ShipTo
            AND OmniaOrderNo = @c_OmniaOrderNo
            AND Facility = @c_Facility
            AND Storerkey = @c_Storerkey
            AND Sku = @c_Sku
            AND Lottable01 = @c_Lottable01 
            AND Lottable02 = @c_Lottable02 
            AND Lottable03 = @c_Lottable03 
            AND Lottable06 = @c_Lottable06 
            AND Lottable07 = @c_Lottable07 
            AND Lottable08 = @c_Lottable08 
            AND Lottable09 = @c_Lottable09 
            AND Lottable10 = @c_Lottable10 
            AND Lottable11 = @c_Lottable11 
            AND Lottable12 = @c_Lottable12 

            FETCH NEXT FROM CURSOR_ORDERLINE_SKU INTO @c_ShipTo, @c_OmniaOrderNo, @n_OrderQty, @c_PackKey, @c_Result
         END -- END WHILE FOR CURSOR_ORDERLINE_SKU      
         CLOSE CURSOR_ORDERLINE_SKU          
         DEALLOCATE CURSOR_ORDERLINE_SKU

         IF @b_Debug = 1
         BEGIN
            PRINT 'END Alloc UCC - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /***********************/
         /***  END ALLOC UCC  ***/
         /***********************/

      END -- IF @n_Count > 0  

      /*****************************/
      /***  Clear All TEMP Table ***/
      /*****************************/
      DELETE FROM #UCCxLOTxLOCxID
      DELETE FROM #NumPool
      DELETE FROM #CombinationPool

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
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
      WHERE WD.WaveKey = @c_WaveKey
   END
   
   IF @n_continue IN(1,2) AND @c_LocationHandling = '2' 
   BEGIN
   	  SET @c_LocationHandling = '1'
      DELETE FROM #UCCxLOTxLOCxID
      DELETE FROM #NumPool
      DELETE FROM #CombinationPool
      DELETE FROM #ORDERLINES
	    DELETE FROM #SplitList
   	  GOTO START
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

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION')) >=0 
   BEGIN
      CLOSE CURSOR_COMBINATION           
      DEALLOCATE CURSOR_COMBINATION      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_COMBINATION_INNER')) >=0 
   BEGIN
      CLOSE CURSOR_COMBINATION_INNER           
      DEALLOCATE CURSOR_COMBINATION_INNER      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_SPLITLIST')) >=0 
   BEGIN
      CLOSE CURSOR_SPLITLIST           
      DEALLOCATE CURSOR_SPLITLIST      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKUCC')) >=0 
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

   IF OBJECT_ID('tempdb..#UCCxLOTxLOCxID','u') IS NOT NULL
      DROP TABLE #UCCxLOTxLOCxID;

   IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
      DROP TABLE #NumPool;

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
      DROP TABLE #SplitList;

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRCAR02'  
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