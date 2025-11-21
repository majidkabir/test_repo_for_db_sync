SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRNKP02                                         */    
/* Creation Date: 03-SEP-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: WMS-10156 NIKE - PH Allocation Strategy Enhancement         */
/*          Full Case from Case Then Pallet Loc by single order         */
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author    Ver.  Purposes                                 */
/* 2021-10-21  NJOW01   1.0   WMS-18109 Prepack qty restriction check   */
/* 2021-10-21  NJOW01   1.0   DEVOPS Combine script                     */
/* 2022-05-30  Wan01    1.1   WMS-19632 - TH-Nike-Wave Allocate         */
/************************************************************************/    
CREATE PROC [dbo].[ispPRNKP02]        
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

   DECLARE  @n_Continue             INT            = 0 
          , @n_StartTCnt            INT            = 0 
          , @c_SQL                  NVARCHAR(MAX)  = ''   
          , @c_SQLParm              NVARCHAR(MAX)  = ''
          , @n_LowerBound           INT            = 0
          , @b_UpdateUCC            INT            = 0

   DECLARE @n_OrderQty              INT            = 0
         , @n_UCCQty                INT            = 0
         , @n_UCC_RowRef            INT            = 0
         , @n_PickQty               INT            = 0
         , @n_CTNQty                INT            = 0
         , @n_InsertQty             INT            = 0
         , @n_OrderLineQty          INT            = 0
         , @c_Loc                   NVARCHAR(10)   = ''
         , @c_Lot                   NVARCHAR(10)   = ''
         , @c_ID                    NVARCHAR(18)   = ''
         , @c_OrderKey              NVARCHAR(10)   = ''
         , @c_OrderLineNumber       NVARCHAR(5)    = ''
         , @c_PickDetailKey         NVARCHAR(10)   = ''
         , @c_Facility              NVARCHAR(5)    = ''  
         , @c_StorerKey             NVARCHAR(15)   = ''
         , @c_SKU                   NVARCHAR(20)   = ''
         , @c_PackKey               NVARCHAR(10)   = ''
         , @c_PickMethod            NVARCHAR(1)    = ''                     
         , @c_UCCNo                 NVARCHAR(20)   = ''
         , @c_Lottable01            NVARCHAR(18)   = ''  
         , @c_Lottable02            NVARCHAR(18)   = ''  
         , @c_Lottable03            NVARCHAR(18)   = ''
         , @c_Lottable06            NVARCHAR(30)   = ''
         , @c_Lottable07            NVARCHAR(30)   = ''
         , @c_Lottable08            NVARCHAR(30)   = ''
         , @c_Lottable09            NVARCHAR(30)   = ''
         , @c_Lottable10            NVARCHAR(30)   = ''
         , @c_Lottable11            NVARCHAR(30)   = ''
         , @c_Lottable12            NVARCHAR(30)   = ''
         , @c_LocationType          NVARCHAR(10)   = ''  
         , @c_LocationCategory      NVARCHAR(10)   = ''
         , @c_LocationHandling      NVARCHAR(10)   = ''
         , @n_PackQtyIndicator      INT            = 0  --NJOW01

         , @b_Found                 INT            = 0
         , @n_SeqNo                 INT            = 0
         , @n_Count                 INT            = 0
         , @n_AvailCTNCount         INT            = 0
         , @n_CTNCount              INT            = 0
         , @n_CTNNeeded             INT            = 0
         , @n_Sum                   INT            = 0
         , @n_Pos                   INT            = 0
         , @c_Subset                NVARCHAR(MAX)  = ''
         , @c_Result                NVARCHAR(MAX)  = ''

         , @CUR_ORDERLINES          CURSOR
         , @CUR_ORDERLINE_SKU       CURSOR
         , @CUR_COMBINATION         CURSOR
         , @CUR_COMBINATION_INNER   CURSOR
         , @CUR_SPLITLIST           CURSOR
         , @CUR_PICKCTN             CURSOR
         , @CUR_UCC                 CURSOR
         , @CUR_ORD                 CURSOR

   -- FROM BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'BULK'
   SET @c_LocationHandling = '2'  --1=Pallet 2=Case
   SET @c_PickMethod = 'C'
   SET @c_UOM = '2'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue=1
   SET @b_Success=1
   SET @n_Err=0
   SET @c_ErrMsg=''
        
   IF EXISTS ( SELECT 1
               FROM WAVE WITH (NOLOCK)
               WHERE Wavekey = @c_Wavekey
               AND DispatchPiecePickMethod NOT IN ('INLINE')
             )
   BEGIN   
      GOTO QUIT_SP
   END                     
   
   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES 
   (  
      SeqNo             INT IDENTITY(1, 1)  
   ,  Orderkey          NVARCHAR(10) 
   ,  OrderQty          INT  
   ,  SKU               NVARCHAR(20)
   ,  PackKey           NVARCHAR(10) 
   ,  StorerKey         NVARCHAR(15) 
   ,  Facility          NVARCHAR(5)  
   ,  Lottable01        NVARCHAR(18) 
   ,  Lottable02        NVARCHAR(18) 
   ,  Lottable03        NVARCHAR(18)
   ,  Lottable06        NVARCHAR(30)
   ,  Lottable07        NVARCHAR(30)
   ,  Lottable08        NVARCHAR(30)
   ,  Lottable09        NVARCHAR(30)
   ,  Lottable10        NVARCHAR(30)
   ,  Lottable11        NVARCHAR(30)
   ,  Lottable12        NVARCHAR(30)
   ,  PackQtyIndicator  INT  --NJOW01   
   )

   IF OBJECT_ID('tempdb..#UCCxLOTxLOCxID','u') IS NOT NULL
      DROP TABLE #UCCxLOTxLOCxID;

   -- Store Stock in Inventory (UCC & LOTxLOCxID info)
   CREATE TABLE #UCCxLOTxLOCxID 
      (  SeqNo             INT IDENTITY(1, 1)  
      ,  UCCQty            INT 
      ,  AvailCTNCount     INT 
      ,  Loc               NVARCHAR(10) 
      ,  LocationHandling  NVARCHAR(10) 
      ,  LogicalLocation   NVARCHAR(18) 
      ,  [Lot]             NVARCHAR(10) 
      ,  [ID]              NVARCHAR(18)
      ,  AllocFullPallet   INT DEFAULT 0
      ,  UCCNo             NVARCHAR(20)          
      )

   IF OBJECT_ID('tempdb..#NumPool','u') IS NOT NULL
      DROP TABLE #NumPool;

   -- For  Pre-Alloc UCC processing
   CREATE TABLE #NumPool 
      (  
         UCCQty        INT 
      ,  AvailCTNCount INT DEFAULT 0 
      ,  CTNAllocated  INT DEFAULT 0
      )

   IF OBJECT_ID('tempdb..#CombinationPool','u') IS NOT NULL
      DROP TABLE #CombinationPool;

   -- Store all possible combination numbers
   CREATE TABLE #CombinationPool 
      (
         [Sum]       INT  
      ,  CTNCount    INT
      ,  Subset      NVARCHAR(MAX)
      )

   IF OBJECT_ID('tempdb..#SplitList','u') IS NOT NULL
      DROP TABLE #SplitList;

   -- Store SPLIT of #CombinationPool.Subset
   CREATE TABLE #SplitList 
      (  
         UCCQty      INT 
      ,  CTNCount    INT
      )

   /***************************************************************/
   /***  GET ORDERLINES OF WAVE Group By Ship To & Omnia Order# ***/
   /***************************************************************/
   ALLOCATE_START:
   TRUNCATE TABLE #ORDERLINES

   IF @c_LocationTypeOverride = ''
   BEGIN
      INSERT INTO #ORDERLINES 
         (  Facility 
         ,  Orderkey 
         ,  StorerKey       
         ,  Sku 
         ,  PackKey 
         ,  OrderQty 
         ,  Lottable01  
         ,  Lottable02  
         ,  Lottable03  
         ,  Lottable06  
         ,  Lottable07  
         ,  Lottable08  
         ,  Lottable09  
         ,  Lottable10  
         ,  Lottable11  
         ,  Lottable12
         ,  PackQtyIndicator --NJOW01
         )
      SELECT  
            O.Facility
         ,  O.Orderkey
         ,  OD.Storerkey    
         ,  OD.Sku
         ,  SKU.PackKey
         ,  SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked))
         ,  ISNULL(RTRIM(OD.Lottable01),'')        
         ,  ISNULL(RTRIM(OD.Lottable02),'')
         ,  ISNULL(RTRIM(OD.Lottable03),'')
         ,  ISNULL(RTRIM(OD.Lottable06),'')
         ,  ISNULL(RTRIM(OD.Lottable07),'')
         ,  ISNULL(RTRIM(OD.Lottable08),'')
         ,  ISNULL(RTRIM(OD.Lottable09),'')
         ,  ISNULL(RTRIM(OD.Lottable10),'')
         ,  ISNULL(RTRIM(OD.Lottable11),'')
         ,  ISNULL(RTRIM(OD.Lottable12),'')
         ,  SKU.PackQtyIndicator  --NJOW01         
      FROM ORDERS      O   WITH (NOLOCK)        
      JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) 
      JOIN WAVEDETAIL  WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)  
      JOIN SKU         SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey)
                                         AND(SKU.Sku = OD.Sku)  
      WHERE WD.Wavekey = @c_WaveKey
        AND O.Type NOT IN ( 'M', 'I' )   
        AND O.SOStatus <> 'CANC'   
        AND O.Status < '9'   
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
        --AND ISNULL(RTRIM(OD.Lottable01),'') <> ''               --(Wan01) CR 1.3                
      GROUP BY O.Facility
            ,  O.Orderkey
            ,  OD.Storerkey         
            ,  OD.Sku         
            ,  SKU.PackKey
            ,  ISNULL(RTRIM(OD.Lottable01),'')                
            ,  ISNULL(RTRIM(OD.Lottable02),'') 
            ,  ISNULL(RTRIM(OD.Lottable03),'') 
            ,  ISNULL(RTRIM(OD.Lottable06),'') 
            ,  ISNULL(RTRIM(OD.Lottable07),'') 
            ,  ISNULL(RTRIM(OD.Lottable08),'') 
            ,  ISNULL(RTRIM(OD.Lottable09),'') 
            ,  ISNULL(RTRIM(OD.Lottable10),'') 
            ,  ISNULL(RTRIM(OD.Lottable11),'') 
            ,  ISNULL(RTRIM(OD.Lottable12),'')
            ,  SKU.PackQtyIndicator  --NJOW01           
      ORDER BY ISNULL(RTRIM(OD.Lottable01),'') DESC                                               
   END
   ELSE
   BEGIN
      INSERT INTO #ORDERLINES 
         (  Facility 
         ,  Orderkey 
         ,  StorerKey       
         ,  Sku 
         ,  PackKey 
         ,  OrderQty 
         ,  Lottable01  
         ,  Lottable02  
         ,  Lottable03  
         ,  Lottable06  
         ,  Lottable07  
         ,  Lottable08  
         ,  Lottable09  
         ,  Lottable10  
         ,  Lottable11  
         ,  Lottable12
         ,  PackQtyIndicator --NJOW01         
         )
      SELECT  
            O.Facility
         ,  O.Orderkey
         ,  OD.Storerkey    
         ,  OD.Sku
         ,  SKU.PackKey
         ,  SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked))
         ,  ISNULL(RTRIM(OD.Lottable01),'')        
         ,  ISNULL(RTRIM(OD.Lottable02),'')
         ,  ISNULL(RTRIM(OD.Lottable03),'')
         ,  ISNULL(RTRIM(OD.Lottable06),'')
         ,  ISNULL(RTRIM(OD.Lottable07),'')
         ,  ISNULL(RTRIM(OD.Lottable08),'')
         ,  ISNULL(RTRIM(OD.Lottable09),'')
         ,  ISNULL(RTRIM(OD.Lottable10),'')
         ,  ISNULL(RTRIM(OD.Lottable11),'')
         ,  ISNULL(RTRIM(OD.Lottable12),'')
         ,  SKU.PackQtyIndicator  --NJOW01         
      FROM ORDERS      O   WITH (NOLOCK)        
      JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) 
      JOIN WAVEDETAIL  WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)  
      JOIN SKU         SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey)
                                         AND(SKU.Sku = OD.Sku)  
      WHERE WD.Wavekey = @c_WaveKey
        AND O.Type NOT IN ( 'M', 'I' )   
        AND O.SOStatus <> 'CANC'   
        AND O.Status < '9'   
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
        AND ISNULL(RTRIM(OD.Lottable01),'') = ''              
      GROUP BY O.Facility
            ,  O.Orderkey
            ,  OD.Storerkey         
            ,  OD.Sku         
            ,  SKU.PackKey
            ,  ISNULL(RTRIM(OD.Lottable01),'')                
            ,  ISNULL(RTRIM(OD.Lottable02),'') 
            ,  ISNULL(RTRIM(OD.Lottable03),'') 
            ,  ISNULL(RTRIM(OD.Lottable06),'') 
            ,  ISNULL(RTRIM(OD.Lottable07),'') 
            ,  ISNULL(RTRIM(OD.Lottable08),'') 
            ,  ISNULL(RTRIM(OD.Lottable09),'') 
            ,  ISNULL(RTRIM(OD.Lottable10),'') 
            ,  ISNULL(RTRIM(OD.Lottable11),'') 
            ,  ISNULL(RTRIM(OD.Lottable12),'')
            ,  SKU.PackQtyIndicator  --NJOW01            
      ORDER BY O.Orderkey                                       
   END

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   /*******************************/
   /***  LOOP BY DISTINCT SKU   ***/
   /*******************************/

   SET @CUR_ORDERLINES = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT StorerKey,  SKU, Facility, Packkey                                  
                 , Lottable01, Lottable02, Lottable03, Lottable06 
                 , Lottable07, Lottable08, Lottable09, Lottable10
                 , Lottable11, Lottable12
   FROM #ORDERLINES
   ORDER BY Lottable01 DESC                                                                     

   OPEN @CUR_ORDERLINES               
   FETCH NEXT FROM @CUR_ORDERLINES INTO   @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey   
                                       ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06
                                       ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                       ,  @c_Lottable11, @c_Lottable12
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_PAckkey: ' + @c_Packkey + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable03: ' + @c_Lottable03 + CHAR(13) + 
               ', @c_Lottable06: ' + @c_Lottable06 + CHAR(13) + 
               ', @c_Lottable07: ' + @c_Lottable07 + CHAR(13) + 
               ', @c_Lottable08: ' + @c_Lottable08 + CHAR(13) + 
               ', @c_Lottable09: ' + @c_Lottable09 + CHAR(13) + 
               ', @c_Lottable10: ' + @c_Lottable10 + CHAR(13) + 
               ', @c_Lottable11: ' + @c_Lottable11 + CHAR(13) + 
               ', @c_Lottable12: ' + @c_Lottable12 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               ', @c_LocationTypeOverride: ' + @c_LocationTypeOverride + CHAR(13) + 
               '--------------------------------------------' 
      END

      /*****************************/
      /***  Clear TEMP Table     ***/
      /*****************************/
      TRUNCATE TABLE #UCCxLOTxLOCxID
      TRUNCATE TABLE #NumPool

      /************************************************/
      /***  INSERT IDxLOC FOR CURRENT SKU   ***/
      /************************************************/
      -- FIXED: Corrected number of carton (UCC) that can be allocated (UCC.Status does not update until pallet build)
      SET @c_SQL = 
                N'INSERT INTO #UCCxLOTxLOCxID (UCCQty, AvailCTNCount, Loc, LocationHandling, LogicalLocation, Lot, ID, UCCNo) '  
   + CHAR(13) +  'SELECT UCC.Qty, UCC.CTNCount - CEILING(LOTxLOCxID.QTYALLOCATED/(UCC.Qty * 1.0)) As CTNCount '
   + CHAR(13) +  ', LOC.Loc, LOC.LocationHandling, LOC.LogicalLocation, LOTxLOCxID.Lot, LOTxLOCxID.ID, UCC.UCCNo '               
   + CHAR(13) +  'FROM LOTxLOCxID WITH (NOLOCK) '     
   + CHAR(13) +  'JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC AND LOC.Status <> ''HOLD'') '     
   + CHAR(13) +  'JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'') '      
   + CHAR(13) +  'JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'') '         
   + CHAR(13) +  'JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LOT.LOT = LA.LOT) ' 
   + CHAR(13) +  'JOIN ( SELECT CS.QTY, CTNCount = COUNT(1), CS.Lot, CS.Loc, CS.ID, CS.UCCNo '                                    
   + CHAR(13) +         'FROM UCC CS WITH (NOLOCK) '
   + CHAR(13) +         'WHERE CS.Storerkey = @c_StorerKey '
   + CHAR(13) +         'AND CS.Sku = @c_SKU AND CS.Status < ''3'' '   
   + CHAR(13) +         'AND NOT EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) '   
   + CHAR(13) +                         'WHERE TD.CaseID = CS.UCCNo AND TD.Status < ''9'' '  
   + CHAR(13) +                         ') '     
   + CHAR(13) +         'GROUP BY CS.QTY, CS.Lot, CS.Loc, CS.ID, CS.UCCNo) UCC '                                                 
   + CHAR(13) +         'ON  (UCC.Lot = LOTXLOCXID.Lot) '   
   + CHAR(13) +         'AND (UCC.Loc = LOTXLOCXID.Loc) ' 
   + CHAR(13) +         'AND (UCC.ID  = LOTXLOCXID.ID) '                         
   + CHAR(13) +  'WHERE LOC.LocationFlag <> ''HOLD'' '      
   + CHAR(13) +  'AND LOC.LocationFlag <> ''DAMAGE'' '      
   + CHAR(13) +  'AND LOC.Facility = @c_Facility '   
   + CHAR(13) +  'AND LOTxLOCxID.Storerkey = @c_StorerKey '
   + CHAR(13) +  'AND LOTxLOCxID.Sku = @c_SKU ' 
   + CHAR(13) +  'AND UCC.CTNCount - CEILING(LOTxLOCxID.QTYALLOCATED/(UCC.Qty * 1.0)) > 0 '
              + CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ' ' 
                     ELSE 'AND LOC.LocationType = ''' + @c_LocationType + ''' ' END      
              + CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
                     ELSE 'AND LOC.LocationCategory = ''' + @c_LocationCategory + ''' '  END       
              + CASE WHEN ISNULL(RTRIM(@c_LocationHandling),'') = '' THEN ''       
                     ELSE 'AND LOC.LocationHandling IN (''1'',''2'') '  END   -- Get 2 then 1      
              + CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN ' AND LA.Lottable01 = @c_LocationTypeOverride ' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END       
              + CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END  
              + CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END  
   + CHAR(13) + 'ORDER BY Loc.LocationHandling DESC, LOC.LogicalLocation, LOC.Loc'                             

      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20) '      
                     +  ',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '  
                     +  ',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30) ' 
                     +  ',@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30) '  
                     +  ',@c_Lottable12 NVARCHAR(30) ' 
                     +  ',@c_LocationTypeOverride NVARCHAR(10) '   
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03 
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08
                        ,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12 
                        ,@c_LocationTypeOverride                   
      
      INSERT INTO #NumPool (UCCQty, AvailCTNCount)
      SELECT UCCQty, SUM(AvailCTNCount)
      FROM #UCCxLOTxLOCxID WITH (NOLOCK)
      GROUP BY UCCQty                                      

      --Get Lower Bound to reduce loop size
      SET @n_LowerBound = 0    
      SELECT top 1 @n_LowerBound = ISNULL(UCCQty,0)        
      FROM #UCCxLOTxLOCxID                                  
      WHERE AvailCTNCount > 0                               
      ORDER BY UCCQty                                       

      IF @b_debug = 1
      BEGIN
         print @c_SQL
         SELECT @n_LowerBound, * FROM #UCCxLOTxLOCxID
      END

      IF @n_LowerBound = 0
      BEGIN
         GOTO NEXT_ORDERLINES
      END
      /*****************************************************************************/
      /***  START PRE-ALLOC UCC (Get Combination of pool numbers for orderQty)   ***/
      /*****************************************************************************/
      SET @CUR_ORDERLINE_SKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey, OrderQty, PackQtyIndicator --NJOW01            
      FROM #ORDERLINES WITH (NOLOCK) 
      WHERE OrderQty >= @n_LowerBound  
      AND StorerKey = @c_StorerKey  
      AND SKU = @c_SKU                   
      AND Facility  = @c_Facility    
      AND Packkey   = @c_Packkey  
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
      ORDER BY Orderkey         
 
      OPEN @CUR_ORDERLINE_SKU               
      FETCH NEXT FROM @CUR_ORDERLINE_SKU INTO @c_Orderkey, @n_OrderQty, @n_PackQtyIndicator  --NJOW01
      
      --Retrieve all the orderkey of the sku      
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN
         /*****************************/
         /***  Clear TEMP Table     ***/
         /*****************************/
         TRUNCATE TABLE #CombinationPool
         TRUNCATE TABLE #SplitList

         --NJOW01
          IF @n_PackQtyIndicator > 1
          BEGIN
             SELECT @n_OrderQty = FLOOR(@n_OrderQty / @n_PackQtyIndicator) * @n_PackQtyIndicator
          END

         -- 1 = FOUND
         SET @b_Found = 0
         SET @c_Result = ''
 
         IF @b_Debug = 1
         BEGIN
            SELECT * from #UCCxLOTxLOCxID 
            PRINT 'Orderkey: ' + @c_Orderkey + ', OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) 
            PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END    

         /*********************************************************************************************/
         /***  STEP 1: Try MOD OrderQty with all number in NumPool = 0, GOTO STEP 2 IF no result   ***/
         /*********************************************************************************************/
         SET @n_UCCQty = 0

         SELECT TOP 1 @n_UCCQty = UCCQty
         FROM #NumPool WITH (NOLOCK)
         WHERE @n_OrderQty % UCCQty = 0
           AND @n_OrderQty/UCCQty <= AvailCTNCount
           AND AvailCTNCount > 0

         IF ISNULL(@n_UCCQty,0) > 0
         BEGIN
            SET @b_Found = 1
            SET @n_CTNNeeded = @n_OrderQty/@n_UCCQty
            SET @c_Result = CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_CTNNeeded AS NVARCHAR)

            INSERT INTO #SplitList VALUES (@n_UCCQty, @n_CTNNeeded) 
         END -- IF ISNULL(@n_UCCQty,'') <> ''

         IF @b_Debug = 1
         BEGIN
            PRINT 'STEP 1: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
         END

         /***************************************************************************************************/
         /***  STEP 2: Get all possible combination of numbers, GET Combination with least Remainder,     ***/
         /***  exit if no result                                                                          ***/
         /***************************************************************************************************/
         IF @b_Found = 0
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
            END

            /*********************************************************************/
            /***   START: Get all possible combination of NumPool (once only)  ***/
            /*********************************************************************/

            SET @CUR_COMBINATION = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT UCCQty, AvailCTNCount
            FROM #NumPool WITH (NOLOCK)
            WHERE AvailCTNCount > 0

            OPEN @CUR_COMBINATION               
            FETCH NEXT FROM @CUR_COMBINATION INTO @n_UCCQty, @n_AvailCTNCount
                      
            WHILE (@@FETCH_STATUS <> -1)          
            BEGIN
               SET @n_Count = 1

               WHILE (@n_Count <= @n_AvailCTNCount)
               BEGIN
                  IF (@n_UCCQty * @n_Count) > @n_OrderQty 
                  BEGIN
                     BREAK
                  END

                  INSERT INTO #CombinationPool ([Sum], CTNCount, SubSet)
                  VALUES (@n_UCCQty * @n_Count, @n_Count  
                         , CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))
    
                  SET @CUR_COMBINATION_INNER = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT [Sum], CTNCount, Subset
                  FROM #CombinationPool WITH (NOLOCK)
                  WHERE CHARINDEX(CAST(@n_UCCQty AS NVARCHAR) + ' * ', Subset) = 0 
                  AND [Sum] + (@n_UCCQty * @n_Count) <= @n_OrderQty

                  OPEN @CUR_COMBINATION_INNER               
                  FETCH NEXT FROM @CUR_COMBINATION_INNER INTO @n_Sum, @n_CTNCount, @c_Subset
                  WHILE (@@FETCH_STATUS <> -1)          
                  BEGIN
                     INSERT INTO #CombinationPool 
                     VALUES (@n_Sum + @n_UCCQty * @n_Count, (@n_CTNCount + @n_Count)
                            ,@c_Subset + ' + ' + CAST(@n_UCCQty AS NVARCHAR) + ' * ' + CAST(@n_Count AS NVARCHAR))

                     FETCH NEXT FROM @CUR_COMBINATION_INNER INTO @n_Sum, @n_CTNCount, @c_Subset
                  END -- END WHILE FOR @CUR_COMBINATION_INNER      
                  CLOSE @CUR_COMBINATION_INNER          
                  DEALLOCATE @CUR_COMBINATION_INNER 

                  SET @n_Count = @n_Count + 1
               END

               FETCH NEXT FROM @CUR_COMBINATION INTO @n_UCCQty, @n_AvailCTNCount
            END -- END WHILE FOR @CUR_COMBINATION      
            CLOSE @CUR_COMBINATION
            DEALLOCATE @CUR_COMBINATION  

            IF @b_Debug = 1
            BEGIN
               SELECT @n_OrderQty '@n_OrderQty', * 
               FROM #CombinationPool WITH (NOLOCK)
               WHERE [Sum] <= @n_OrderQty
               ORDER BY [Sum] DESC
                     ,  CTNCount 
            END   

            /*******************************************************************/
            /***   END: Get all possible combination of NumPool (once only)  ***/
            /*******************************************************************/
              
            SET @c_Result = ''
            -- GET Combination with least Remainder, least number combination
            SELECT TOP 1 @c_Result = Subset--, @n_Result = [Sum]
            FROM #CombinationPool WITH (NOLOCK)
            WHERE [Sum] <= @n_OrderQty
            ORDER BY [Sum] DESC
                  ,  CTNCount 

            IF ISNULL(@c_Result,'') <> ''
            BEGIN
               -- Convert Result string into #SplitList table
               WHILE CHARINDEX('+', @c_Result) > 0
               BEGIN
                  SET @n_Pos  = CHARINDEX('+', @c_Result)  
                  SET @c_Subset = SUBSTRING(@c_Result, 1, @n_Pos-2)
                  SET @c_Result = SUBSTRING(@c_Result, @n_Pos+2, LEN(@c_Result)-@n_Pos)

                  SET @n_Pos  = CHARINDEX('*', @c_Subset)
                  SET @n_UCCQty = CAST(SUBSTRING(@c_Subset, 1, @n_Pos-2) AS INT)
                  SET @n_CTNCount = CAST(SUBSTRING(@c_Subset, @n_Pos+2, LEN(@c_Subset) - @n_Pos+2) AS INT)

                  INSERT INTO #SplitList VALUES (@n_UCCQty, @n_CTNCount) 
               END -- WHILE CHARINDEX('+', @c_Result) > 0

               SET @n_Pos  = CHARINDEX('*', @c_Result)
               SET @n_UCCQty = CAST(SUBSTRING(@c_Result, 1, @n_Pos-2) AS INT)
               SET @n_CTNCount = CAST(SUBSTRING(@c_Result, @n_Pos+2, LEN(@c_Result) - @n_Pos+2) AS INT)

               INSERT INTO #SplitList VALUES (@n_UCCQty, @n_CTNCount) 
            END -- IF ISNULL(@c_Result,'') <> ''

            IF @b_Debug = 1
            BEGIN
               PRINT 'STEP 2: END - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)
               SELECT UCCQty, CTNCount 
               FROM #SplitList WITH (NOLOCK)
            END   
         END -- [STEP 2]


         SET @CUR_SPLITLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT UCCQty, CTNCount 
         FROM #SplitList WITH (NOLOCK)

         OPEN @CUR_SPLITLIST
         FETCH NEXT FROM @CUR_SPLITLIST INTO @n_UCCQty, @n_CTNNeeded

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SET @CUR_PICKCTN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT Seqno 
                  ,Lot
                  ,Loc
                  ,ID
                  ,AvailCTNCount
            FROM #UCCxLOTxLOCxID WITH (NOLOCK)
            WHERE UCCQty = @n_UCCQty
            AND AvailCTNCount > 0
            ORDER BY LocationHandling DESC, LogicalLocation, Loc, AvailCTNCount DESC
                  
            OPEN @CUR_PICKCTN 
                          
            FETCH NEXT FROM @CUR_PICKCTN INTO @n_SeqNo, @c_Lot, @c_Loc, @c_ID, @n_AvailCTNCount
                   
            --Retrieve all lots of the pallet
            WHILE (@@FETCH_STATUS <> -1) AND @n_CTNNeeded > 0        
            BEGIN 

               IF @n_CTNNeeded < @n_AvailCTNCount
               BEGIN
                  SET @n_CTNCount = @n_CTNNeeded
               END 
               ELSE
               BEGIN
                  SET @n_CTNCount = @n_AvailCTNCount
               END

               SET @n_PickQty = @n_UCCQty * @n_CTNCount

               -- Update #NumPool.CTNCount
               UPDATE #NumPool WITH (ROWLOCK)
               SET AvailCTNCount= AvailCTNCount - @n_CTNCount 
                  ,CTNAllocated = CTNAllocated  + @n_CTNCount
               WHERE UCCQty = @n_UCCQty

               -- UPDATE #UCCxLOTxLOCxID
               UPDATE #UCCxLOTxLOCxID WITH (ROWLOCK)
               SET AvailCTNCount = AvailCTNCount - @n_CTNCount
               WHERE SeqNo = @n_SeqNo

               SET @n_CTNNeeded = @n_CTNNeeded - @n_CTNCount

               SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT UCC_RowRef
                     ,UCCNo
               FROM UCC WITH (NOLOCK) 
               WHERE Qty = @n_UCCQty
               AND Lot = @c_Lot               
               AND Loc = @c_Loc
               AND ID  = @c_ID
               AND Status < '3'  
                  
               OPEN @CUR_UCC
                  
               FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo 
                                    
               WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0  
               BEGIN 
                  SET @n_CTNQty = @n_UCCQty
                  SET @b_UpdateUCC = 1

                  SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT OD.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty 
                  FROM ORDERDETAIL OD (NOLOCK)  
                  WHERE OD.ORderkey = @c_Orderkey                                  
                  AND OD.StorerKey  = @c_StorerKey                
                  AND OD.SKU = @c_SKU  
                  AND OD.Packkey = @c_Packkey   
                  AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0   
                  AND OD.Lottable01 = @c_Lottable01         
                  AND OD.Lottable02 = @c_Lottable02     
                  AND OD.Lottable03 = @c_Lottable03                      
                  AND OD.Lottable06 = @c_Lottable06        
                  AND OD.Lottable07 = @c_Lottable07        
                  AND OD.Lottable08 = @c_Lottable08        
                  AND OD.Lottable09 = @c_Lottable09       
                  AND OD.Lottable10 = @c_Lottable10        
                  AND OD.Lottable11 = @c_Lottable11        
                  AND OD.Lottable12 = @c_Lottable12   
                  AND EXISTS (SELECT 1 FROM #ORDERLINES OL (NOLOCK) WHERE OD.Orderkey = OL.Orderkey)   

                  OPEN @CUR_ORD               
                  FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
             
                  --Retrieve all order lines for the order group and create pickdetail
                  WHILE (@@FETCH_STATUS <> -1) AND @n_CTNQty > 0      
                  BEGIN 

                     IF @n_OrderLineQty <= @n_CTNQty 
                     BEGIN
                        SET @n_InsertQty = @n_OrderLineQty
                     END
                     ELSE
                     BEGIN
                        SET @n_InsertQty = @n_CTNQty
                     END
    
                     SET @n_CTNQty    = @n_CTNQty  - @n_InsertQty
                     SET @n_PickQty   = @n_PickQty - @n_InsertQty
    
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
                        SET @n_Err = 61010
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))   
                                       + ': Get PickDetailKey Failed. (ispPRNKP02)'
                        GOTO QUIT_SP
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
                                 'UOM: ' + @c_UOM + CHAR(13) +
                                 'UCCNo: ' + @c_UCCNo + CHAR(13) +
                                 'UCCQty: ' + CAST(@n_UCCQty AS NVARCHAR) + CHAR(13) 
                        END
                                             
                        INSERT INTO PICKDETAIL (  
                              PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                              Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,
                              Loc, Id, PackKey, CartonGroup, DoReplenish,  
                              replenishzone, doCartonize, Trafficcop, PickMethod,
                              Wavekey  
                        ) VALUES (  
                              @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                              @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UCCQty, @n_InsertQty, @c_UCCNo,
                              @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                              '', NULL, 'U', @c_PickMethod,
                              @c_Wavekey  
                        ) 
                     
                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 61020
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                          + ': Insert PickDetail Failed. (ispPRNKP02)'
                           GOTO QUIT_SP
                        END

                        IF @b_UpdateUCC = 1
                        BEGIN
                           UPDATE UCC WITH (ROWLOCK)
                              SET Status = '3'
                                 ,PickDetailKey = @c_PickDetailKey
                                 ,OrderKey = @c_OrderKey
                                 ,OrderLineNumber = @c_OrderLineNumber
                           WHERE UCC_RowRef = @n_UCC_RowRef
                        
                           IF @@ERROR <> 0
                           BEGIN
                              SET @n_Continue = 3
                              SET @n_Err = 61030
                              SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                             + ': Update UCC Failed. (ispPRNKP02)'
                              GOTO QUIT_SP
                           END
                           SET @b_UpdateUCC = 0 
                        END
                     END -- IF @b_Success = 1  
                   
                     FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
                  END
                  CLOSE @CUR_ORD         
                  DEALLOCATE @CUR_ORD    

                  FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo                              
               END    
               CLOSE @CUR_UCC
               DEALLOCATE @CUR_UCC    
               
               FETCH NEXT FROM @CUR_PICKCTN INTO @n_SeqNo, @c_Lot, @c_Loc, @c_ID, @n_AvailCTNCount  
            END 
            CLOSE @CUR_PICKCTN
            DEALLOCATE @CUR_PICKCTN

            FETCH NEXT FROM @CUR_SPLITLIST INTO @n_UCCQty, @n_CTNNeeded
         END -- END WHILE FOR @CUR_SPLITLIST      
         CLOSE @CUR_SPLITLIST          
         DEALLOCATE @CUR_SPLITLIST 

         IF @b_Debug = 1
         BEGIN
             PRINT 'RESULT FOR ' + CAST(@n_OrderQty AS NVARCHAR) + ': ' + @c_Result  
         END
       
         FETCH NEXT FROM @CUR_ORDERLINE_SKU INTO @c_Orderkey, @n_OrderQty,  @n_PackQtyIndicator  --NJOW01
      END -- END WHILE FOR @CUR_ORDERLINE_SKU              
      CLOSE @CUR_ORDERLINE_SKU
      DEALLOCATE @CUR_ORDERLINE_SKU

      /***************************/
      /***  END PRE-ALLOC UCC  ***/
      /***************************/

      IF @b_Debug = 2
      BEGIN
         SELECT * FROM #NumPool WITH (NOLOCK)
         SELECT * FROM #UCCxLOTxLOCxID WITH (NOLOCK)
      END

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END
      
      NEXT_ORDERLINES:
      FETCH NEXT FROM @CUR_ORDERLINES INTO   @c_StorerKey,  @c_SKU, @c_Facility, @c_Packkey      
                                          ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06
                                          ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                          ,  @c_Lottable11, @c_Lottable12
   END -- END WHILE FOR @CUR_ORDERLINES             
   CLOSE @CUR_ORDERLINES          
   DEALLOCATE @CUR_ORDERLINES

   IF @b_Debug = 1
   BEGIN
      SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber, PD.Qty, PD.SKU, PD.PackKey, PD.Lot, PD.Loc, PD.ID, PD.UOM
           , PD.UOMQty, PD.DropID, PD.PickMethod
      FROM PickDetail PD WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
      WHERE WD.Wavekey = @c_Wavekey
   END

   --IF @c_LocationHandling = '2' 
   --BEGIN
   --   SET @c_LocationHandling = '1'
   --   GOTO ALLOCATE_START
   --END
QUIT_SP:
      
   IF CURSOR_STATUS( 'LOCAL', '@CUR_ORD') in (0 , 1)  
   BEGIN
      CLOSE @CUR_ORD           
      DEALLOCATE @CUR_ORD      
   END  

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRNKP02'  
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