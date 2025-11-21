SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRNKP05                                         */    
/* Creation Date: 03-SEP-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: WMS-10156 NIKE - PH Allocation Strategy Enhancement         */
/*          Full Pallet from Pallet loc by Consolidate order            */
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */  
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */
/* 2019-10-04  Wan01    1.0   Fixed Getting Different ID issue          */
/* 2019-10-08  Wan02    1.0   Fixed wrong deduct orderqty               */
/* 2021-10-21  NJOW01   1.1   WMS-18109 Prepack qty restriction check   */
/* 2021-10-21  NJOW01   1.1   DEVOPS Combine script                     */
/* 2022-05-11  Wan03    1.2   WMS-19632 - TH-Nike-Wave Allocate         */
/************************************************************************/    
CREATE PROC [dbo].[ispPRNKP05]        
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
         , @n_QtyAvail              INT            = 0
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

         , @n_IDQty                 INT            = 0 
         , @n_SeqNo                 INT            = 0           

         , @CUR_ORDERLINES          CURSOR
         , @CUR_PICKID              CURSOR
         , @CUR_UCC                 CURSOR
         , @CUR_ORD                 CURSOR    
                
   -- FROM BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'BULK'
   SET @c_LocationHandling = '1'  --1=Pallet 2=Case
   SET @c_PickMethod = 'P'
   SET @c_UOM = '6'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue=1
   SET @b_Success=1
   SET @n_Err=0
   SET @c_ErrMsg=''

   IF EXISTS ( SELECT 1
               FROM WAVE WITH (NOLOCK)
               WHERE Wavekey = @c_Wavekey
               AND DispatchPiecePickMethod NOT IN ('INLINE', 'DTC')      
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

   IF OBJECT_ID('tempdb..#IDxLOCxLOT','u') IS NOT NULL
      DROP TABLE #IDxLOCxLOT;

   CREATE TABLE #IDxLOCxLOT 
      (  
         SeqNo             INT IDENTITY(1, 1)
      ,  ID                NVARCHAR(18) 
      ,  Loc               NVARCHAR(10)
      ,  Lot               NVARCHAR(10)
      ,  QtyAvailable      INT
      ,  IDQty             INT  
      )

   IF OBJECT_ID('tempdb..#IDxLOC','u') IS NOT NULL
      DROP TABLE #IDxLOC;

   CREATE TABLE #IDxLOC 
      (  
         SeqNo             INT IDENTITY(1, 1)
      ,  ID                NVARCHAR(18) 
      ,  Loc               NVARCHAR(10)
      ,  LogicalLocation   NVARCHAR(10)   
      ,  QtyAvailable      INT
      )

   /***************************************************************/
   /***  GET ORDERLINES OF WAVE Group By Ship To & Omnia Order# ***/
   /***************************************************************/
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
        --AND ISNULL(RTRIM(OD.Lottable01),'') <> ''                                                   -- (Wan03) - CR 1.3             
        AND NOT EXISTS (SELECT 1 FROM dbo.CODELKUP AS c WITH (NOLOCK) WHERE C.ListName = 'SKUGROUP'   -- (Wan03)
                        AND c.Code = SKU.BUSR7 AND c.Storerkey = SKU.Storerkey AND c.UDF04 ='0')      -- (Wan03)
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
        AND NOT EXISTS (SELECT 1 FROM dbo.CODELKUP AS c WITH (NOLOCK) WHERE C.ListName = 'SKUGROUP'      -- (Wan03)
                        AND c.Code = SKU.BUSR7 AND c.Storerkey = SKU.Storerkey AND c.UDF04 ='0')      -- (Wan03)            
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
   SELECT StorerKey,  SKU, Facility, Packkey                                                  
      , Lottable01, Lottable02, Lottable03, Lottable06 
      , Lottable07, Lottable08, Lottable09, Lottable10
      , Lottable11, Lottable12
      , OrderQty = SUM(CASE WHEN PackQtyIndicator > 1 THEN
                            FLOOR(OrderQty / PackQtyIndicator) * PackQtyIndicator
                       ELSE OrderQty END)  --NJOW01
      , PackQtyIndicator  --NJOW01                   
   FROM #ORDERLINES
   GROUP BY StorerKey,  SKU, Facility, Packkey                                                                     
         , Lottable01, Lottable02, Lottable03, Lottable06 
         , Lottable07, Lottable08, Lottable09, Lottable10
         , Lottable11, Lottable12
         , PackQtyIndicator  --NJOW01
   ORDER BY Lottable01 DESC                                                                           

   OPEN @CUR_ORDERLINES               
   FETCH NEXT FROM @CUR_ORDERLINES INTO @c_StorerKey,  @c_SKU, @c_Facility, @c_Packkey     
                                    ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06
                                    ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                    ,  @c_Lottable11, @c_Lottable12
                                    ,  @n_OrderQty, @n_PackQtyIndicator --NJOW01
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @@c_Packkey: ' + @c_Packkey + CHAR(13) + 
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
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
               ', @n_OrderQty: ' + CONVERT(NVARCHAR(5),@n_OrderQty) + CHAR(13) +
               ', @c_LocationTypeOverride: ' + @c_LocationTypeOverride + CHAR(13) + 
               '--------------------------------------------' 
      END

      /*****************************/
      /***  Clear TEMP Table     ***/
      /*****************************/
      TRUNCATE TABLE #IDxLOCxLOT
      TRUNCATE TABLE #IDxLOC
      /************************************************/
      /***  INSERT IDxLOCxLOT FOR CURRENT SKU       ***/
      /************************************************/
      -- ID with single Lot
      -- ID without qtyallocated, qtypicked or qtyreplen
      -- UCC ID without status between '2' and '9'  SET @c_SQL = 
   SET @c_SQL = N'INSERT INTO #IDxLOC (Loc, ID, LogicalLocation, QtyAvailable) '
   + CHAR(13) +  'SELECT LOC.Loc, LOTxLOCxID.ID, LOC.LogicalLocation '
   + CHAR(13) +  ',SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable '
   + CHAR(13) +  'FROM LOTxLOCxID WITH (NOLOCK) '     
   + CHAR(13) +  'JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC AND LOC.Status <> ''HOLD'') '     
   + CHAR(13) +  'JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'') '      
   + CHAR(13) +  'JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'') '         
   + CHAR(13) +  'JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LOT.LOT = LA.LOT) '           
   + CHAR(13) +  'WHERE LOC.LocationFlag <> ''HOLD'' '      
   + CHAR(13) +  'AND LOC.LocationFlag <> ''DAMAGE'' '      
   + CHAR(13) +  'AND LOC.Facility = @c_Facility '   
   + CHAR(13) +  'AND LOTxLOCxID.Storerkey = @c_StorerKey '
   + CHAR(13) +  'AND LOTxLOCxID.Sku = @c_SKU ' 
   + CHAR(13) +  'AND LOTxLOCxID.ID <> '''' '
   + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ' ' 
                     ELSE 'AND LOC.LocationType = ''' + @c_LocationType + ''' ' END      
   + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ' '       
                     ELSE 'AND LOC.LocationCategory = ''' + @c_LocationCategory + ''' '  END       
   + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_LocationHandling),'') = '' THEN ' '       
                     ELSE 'AND LOC.LocationHandling = ''' + @c_LocationHandling + ''' '  END      
   + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN ' AND LA.Lottable01 = @c_LocationTypeOverride ' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END    
              + CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END       
              + CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END  
              + CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END   
              + CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END  
   + CHAR(13) + 'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) > 0 '    
   + CHAR(13) + 'AND NOT EXISTS (SELECT 1 FROM UCC (NOLOCK) WHERE UCC.Lot = LOTxLOCxID.Lot AND UCC.Loc = LOTxLOCxID.Loc '  
   + CHAR(13) +                  'AND UCC.ID = LOTxLOCxID.ID AND ((UCC.Status > ''2'' AND UCC.Status < ''9'') '  
   + CHAR(13) +                  'OR (UCC.Status = ''1'' AND EXISTS (SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) '
   + CHAR(13) +                                                     'WHERE TD.CaseID = UCC.UCCNo AND TD.Status < ''9'' '  
   + CHAR(13) +                                                     '))) '  
   + CHAR(13) +                  ') '                         
   + CHAR(13) + 'AND (SELECT COUNT(DISTINCT SKU) FROM LotxLocxID ida1 (NOLOCK) WHERE ida1.ID = LOTxLOCxID.ID AND ida1.Qty > 0) = 1 '   
   + CHAR(13) + 'AND (SELECT SUM(ida2.QtyAllocated + ida2.QtyPicked + ida2.QtyReplen) FROM LOTxLOCxID ida2 (NOLOCK) '  
   + CHAR(13) +      'WHERE ida2.ID = LOTxLOCxID.ID) = 0 '  
   + CHAR(13) + 'GROUP BY LOC.Loc, LOTxLOCxID.ID, LOC.LogicalLocation ' 
   + CHAR(13) + 'ORDER BY LOC.LogicalLocation, LOC.Loc, LOTxLOCxID.ID'                             
                        

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
      
   
      IF NOT EXISTS (SELECT 1
                     FROM #IDxLOC
                    )
      BEGIN
         GOTO NEXT_ORDERLINES
      END

      -- Insert Inventory if matched total inventory allocated qty = Whole ID qty
      INSERT INTO #IDxLOCxLOT (Loc, ID, Lot, QtyAvailable, IDQty)
      SELECT LLI.Loc, LLI.ID, LLI.Lot
            ,LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen
            ,IL.QtyAvailable
      FROM #IDxLOC IL
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (IL.Loc = LLI.Loc)
                                        AND(IL.Id  = LLI.ID)
      WHERE LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0 --(Wan01)
      AND IL.QtyAvailable <= @n_OrderQty                                   --(Wan01)
      AND EXISTS (   SELECT 1                                              --(Wan01)   
                     FROM UCC U WITH (NOLOCK)                              --(Wan01)
                     WHERE U.Loc = IL.Loc                                  --(Wan01)
                     AND   U.ID = IL.ID                                    --(Wan01)       
                     AND   U.[Status] < '3'                                --(Wan01)
                     GROUP BY U.Loc, U.ID                                  --(Wan01)           
                     HAVING ISNULL(SUM(U.Qty),0) = IL.QtyAvailable         --(Wan01)
                )                                                          --(Wan01)
      --AND (SELECT SUM(Qty) FROM LOTxLOCxID ida3 (NOLOCK)                 --(Wan01) 
      --       WHERE ida3.ID = LLI.ID) = IL.QtyAvailable                   --(Wan01)
      --ORDER BY LLI.Lot, IL.LogicalLocation, LLI.Loc, LLI.ID              --(Wan01)
      ORDER BY IL.LogicalLocation, LLI.Loc, LLI.ID                         --(Wan01) 

      --Get Lower Bound to reduce loop size
      SET @n_LowerBound = 0
      SELECT @n_LowerBound = ISNULL(MIN(IDQty),0)     
      FROM #IDxLOCxLOT
      WHERE IDQty > 0

      SET @n_SeqNo = 0                                                     --(Wan01)
      WHILE @n_OrderQty >= @n_LowerBound AND @n_LowerBound > 0 AND @n_OrderQty > 0
      BEGIN 
         SET @c_Loc = ''
         SET @c_ID  = ''
         SET @n_IDQty = 0
         --(Wan01) - START
         --SELECT TOP 1 
         --       @c_Loc = Loc
         --      ,@c_ID  = ID
         --      ,@n_IDQty  = IDQty
         --FROM #IDxLOCxLOT
         --WHERE IDQty <= @n_OrderQty
         --AND QtyAvailable > 0
         --ORDER BY SeqNo
         SELECT TOP 1 
                @c_Loc = IL.Loc
               ,@c_ID  = IL.ID
               ,@n_IDQty= IL.QtyAvailable
               ,@n_SeqNo = IL.SeqNo
         FROM #IDxLOC IL
         WHERE IL.QtyAvailable <= @n_OrderQty
         AND IL.SeqNo > @n_SeqNo
         AND EXISTS ( SELECT 1 FROM #IDxLOCxLOT ILL
                      WHERE ILL.Loc = IL.Loc
                      AND   ILL.ID = IL.ID
                      AND   ILL.QtyAvailable > 0
                    )
         ORDER BY IL.SeqNo
         --(Wan01) - END

         IF @n_IDQty = 0 OR @n_SeqNo = 0           --(Wan01)
         BEGIN
            BREAK
         END

         --Allocate the order group
         SET @CUR_PICKID = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT ILL.Lot
               ,ILL.Loc
               ,ILL.ID
               ,ILL.QtyAvailable 
         FROM #IDxLOCxLOT ILL
         WHERE ILL.Loc = @c_Loc                                                              --(Wan01)
         AND ILL.ID = @c_ID                                                                  --(Wan01)
         AND ILL.QtyAvailable > 0
         ORDER BY SeqNo
            
         OPEN @CUR_PICKID               
         FETCH NEXT FROM @CUR_PICKID INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail 
         --Allocate the order group
         WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty >= @n_QtyAvail 
         BEGIN 
            SET @n_PickQty = @n_QtyAvail  
                
            SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT UCC_RowRef
                  ,UCCNo
                  ,Qty
            FROM UCC WITH (NOLOCK) 
            WHERE Lot = @c_Lot               
            AND   Loc = @c_Loc
            AND   ID  = @c_ID
            AND   Status < '3' 
            AND ( SELECT SUM(Qty) FROM UCC CTN WITH (NOLOCK) 
                  WHERE CTN.Lot = UCC.Lot
                  AND   CTN.Loc = UCC.Loc
                  AND   CTN.ID  = UCC.ID
                  AND   CTN.Status = UCC.Status) = @n_QtyAvail
                         
            OPEN @CUR_UCC
                  
            FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo, @n_UCCQty 
                                    
            WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0
            BEGIN 
               SET @n_CTNQty = @n_UCCQty
               SET @b_UpdateUCC = 1

               SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT OD.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty  
               FROM ORDERDETAIL OD (NOLOCK) 
               JOIN WAVEDETAIL  WD (NOLOCK) ON (OD.Orderkey = WD.Orderkey) 
               WHERE WD.WaveKey   = @c_Wavekey   
               AND OD.StorerKey = @c_StorerKey               
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
                  --NJOW01
                  IF @n_PackQtyIndicator > 1
                  BEGIN
                      SELECT @n_OrderLineQty = FLOOR(@n_OrderLineQty / @n_PackQtyIndicator) * @n_PackQtyIndicator
                  END
                  
                  IF @n_OrderLineQty <= @n_CTNQty 
                  BEGIN
                     SET @n_InsertQty = @n_OrderLineQty
                  END
                  ELSE
                  BEGIN
                     SET @n_InsertQty = @n_CTNQty
                  END

                  SET @n_CTNQty = @n_CTNQty - @n_InsertQty
                  SET @n_PickQty= @n_PickQty- @n_InsertQty
                  SET @n_OrderQty = @n_OrderQty - @n_InsertQty                   --(Wan01) Move Up --(Wan02)
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
                                    + ': Get PickDetailKey Failed. (ispPRNKP05)'
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
                                       + ': Insert PickDetail Failed. (ispPRNKP05)'
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
                                          + ': Update UCC Failed. (ispPRNKP05)'
                           GOTO QUIT_SP
                        END   

                        SET @b_UpdateUCC = 0
                     END                   
                  END -- IF @b_Success = 1 
                  FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty
               END
               CLOSE @CUR_ORD         
               DEALLOCATE @CUR_ORD  

               FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo, @n_UCCQty                                  
            END    
            CLOSE @CUR_UCC
            DEALLOCATE @CUR_UCC                       
            
            --SET @n_OrderQty = @n_OrderQty - @n_QtyAvail                                 --(Wan01)  
            FETCH NEXT FROM @CUR_PICKID INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail 
         END
         CLOSE @CUR_PICKID         
         DEALLOCATE @CUR_PICKID
      END -- END WHILE @n_OrderQty>=@n_LowerBound

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      NEXT_ORDERLINES:
      FETCH NEXT FROM @CUR_ORDERLINES INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey 
                                       ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06
                                       ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                       ,  @c_Lottable11, @c_Lottable12
                                       ,  @n_OrderQty, @n_PackQtyIndicator --NJOW01
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

QUIT_SP:
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRNKP05'  
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