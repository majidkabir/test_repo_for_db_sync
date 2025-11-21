SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRNKP03                                         */    
/* Creation Date: 15-OCT-2019                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: WMS-10156 NIKE - PH Allocation Strategy Enhancement         */
/*        : Allocate piece From DPBULK, Shelving, loseid, loseucc by    */    
/*          order                                                       */
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver.  Purposes                                  */
/* 2021-10-21  NJOW01   1.0   WMS-18109 Prepack qty restriction check   */
/* 2021-10-21  NJOW01   1.0   DEVOPS Combine script                     */
/* 2022-05-11  Wan01    1.1   WMS-19632 - TH-Nike-Wave Allocate         */
/************************************************************************/    
CREATE PROC [dbo].[ispPRNKP03]        
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

   DECLARE  @n_Continue          INT   
          , @n_StartTCnt         INT 
          , @c_SQL               NVARCHAR(MAX)     
          , @c_SQLParm           NVARCHAR(MAX) 

         --, @n_UCC_RowRef         BIGINT = 0
         --, @b_UpdateUCC          BIT = 0

   DECLARE @n_SeqNo              INT          = 0
         , @n_QtyAvailable       INT          = 0
         , @n_RemainingQty       INT          = 0
         , @n_CaseCnt            INT          = 0
         , @n_QtyAvail           INT          = 0
         , @n_QtyToTake          INT          = 0
         , @n_OrderQty           INT          = 0
         , @n_QtyToInsert        INT          = 0
         , @n_UOMQty             INT          = 0
         , @c_Loc                NVARCHAR(10) = ''
         , @c_Lot                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @c_OrderKey           NVARCHAR(10) = ''
         , @c_OrderLineNumber    NVARCHAR(5)  = ''
         , @c_PickDetailKey      NVARCHAR(10) = ''
         , @c_Facility           NVARCHAR(5)  = ''    
         , @c_StorerKey          NVARCHAR(15) = ''
         , @c_SKU                NVARCHAR(20) = '' 
         , @c_PackKey            NVARCHAR(10) = ''  
         , @c_PickMethod         NVARCHAR(1)  = ''                       
         , @c_Lottable01         NVARCHAR(18) = ''    
         , @c_Lottable02         NVARCHAR(18) = ''    
         , @c_Lottable03         NVARCHAR(18) = ''
         , @c_Lottable06         NVARCHAR(30) = ''
         , @c_Lottable07         NVARCHAR(30) = ''
         , @c_Lottable08         NVARCHAR(30) = ''
         , @c_Lottable09         NVARCHAR(30) = ''
         , @c_Lottable10         NVARCHAR(30) = ''
         , @c_Lottable11         NVARCHAR(30) = ''
         , @c_Lottable12         NVARCHAR(30) = ''
         , @c_LocationType       NVARCHAR(10) = ''    
         , @c_LocationCategory   NVARCHAR(10) = ''
         , @c_LocationHandling   NVARCHAR(10) = ''
         
         , @c_Status             NVARCHAR(10) = '0'
         , @c_TaskDetailkey      NVARCHAR(10) = ''
         , @n_PackQtyIndicator   INT          = 0  --NJOW01
         
         , @c_PickZone_RTV       NVARCHAR(10) = ''                                     --(Wan01)

         , @CUR_ORDERLINES       CURSOR
         , @CUR_ORD              CURSOR
         , @CUR_INV              CURSOR      
         
   SET @c_LocationType = 'DPBULK'      
   SET @c_LocationCategory = 'SHELVING'    
   SET @c_UOM = '7'
   SET @c_PickZone_RTV = 'NIKE-M3'
   
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

 
   IF OBJECT_ID('tempdb..#LOTxLOCxID','u') IS NOT NULL
      DROP TABLE #LOTxLOCxID;

   CREATE TABLE #LOTxLOCxID
   (  
      SeqNo             INT IDENTITY(1, 1) PRIMARY KEY
   ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT ('') 
   ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT ('') 
   ,  ID                NVARCHAR(20)   NOT NULL DEFAULT ('') 
   ,  QtyAvailable      INT            NOT NULL DEFAULT (0) 
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT ('') 
   ,  UCCQty            INT            NOT NULL DEFAULT (0)
   ,  UCC_RowRef        BIGINT         NOT NULL DEFAULT (0) 
   )
   
   /***************************************************************/
   /***  GET ORDERLINES OF WAVE Group By Ship To & Omnia Order# ***/
   /***************************************************************/

   --(Wan01) - START
   SET @c_SQL = N'SELECT' 
               + ' O.Facility'
               + ',O.Orderkey'
               + ',OD.Storerkey'   
               + ',OD.Sku'
               + ',SKU.PackKey'
               + ',SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked))'
               + ',ISNULL(RTRIM(OD.Lottable01),'''')'                                           
               + ',ISNULL(RTRIM(OD.Lottable02),'''')'
               + ',ISNULL(RTRIM(OD.Lottable03),'''')'
               + ',ISNULL(RTRIM(OD.Lottable06),'''')'
               + ',ISNULL(RTRIM(OD.Lottable07),'''')'
               + ',ISNULL(RTRIM(OD.Lottable08),'''')'
               + ',ISNULL(RTRIM(OD.Lottable09),'''')'
               + ',ISNULL(RTRIM(OD.Lottable10),'''')'
               + ',ISNULL(RTRIM(OD.Lottable11),'''')'
               + ',ISNULL(RTRIM(OD.Lottable12),'''')'
               + ',SKU.PackQtyIndicator'                                                   
               + ' FROM ORDERS      O   WITH (NOLOCK)'       
               + ' JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)'
               + ' JOIN WAVEDETAIL  WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)' 
               + ' JOIN SKU         SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey)'
               +                                    ' AND(SKU.Sku = OD.Sku)'
               + ' LEFT OUTER JOIN dbo.STORER AS s WITH (NOLOCK) ON s.StorerKey = o.ConsigneeKey AND o.ConsigneeKey <> '''' AND s.[Secondary] = ''RTV''' 
               + ' WHERE WD.Wavekey = @c_WaveKey'
               + ' AND O.Type NOT IN ( ''M'', ''I'' )'  
               + ' AND O.SOStatus <> ''CANC'''  
               + ' AND O.Status < ''9'''  
               + ' AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0'
               +  CASE WHEN @c_LocationTypeOverride = '' THEN ''              --CR 1.3 ' AND ISNULL(RTRIM(OD.Lottable01),'''') <> ''''' 
                        ELSE ' AND ISNULL(RTRIM(OD.Lottable01),'''') = ''''' 
                        END
               +  CASE WHEN @c_LocationTypeOverRideStripe = 'RTV' THEN ' AND s.[Secondary] IS NOT NULL'                       
                        ELSE ' AND s.[Secondary] IS NULL' END
               + ' GROUP BY O.Facility'
               +         ', O.Orderkey'
               +         ', OD.Storerkey'        
               +         ', OD.Sku'       
               +         ', SKU.PackKey'
               +         ', ISNULL(RTRIM(OD.Lottable01),'''')'                                      
               +         ', ISNULL(RTRIM(OD.Lottable02),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable03),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable06),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable07),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable08),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable09),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable10),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable11),'''')'
               +         ', ISNULL(RTRIM(OD.Lottable12),'''')'
               +         ', SKU.PackQtyIndicator '               
               + ' ORDER BY ISNULL(RTRIM(OD.Lottable01),'''') DESC' 
                
   SET @c_SQLParm = N'@c_Wavekey NVARCHAR(10)' 
   
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
      ,  PackQtyIndicator
      )      
   EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParm
                     ,@c_WaveKey                        
   --(Wan01) - END
   /*Wan01 - START
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
        AND ISNULL(RTRIM(OD.Lottable01),'') <> '' 
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
   */
   
   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   /*********************************/
   /***  LOOP BY ORDERDETAIL SKU  ***/
   /*********************************/

   SET @CUR_ORDERLINES = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT   OL.StorerKey,  OL.SKU, OL.Facility, OL.Packkey 
         ,  OL.Lottable01, OL.Lottable02, OL.Lottable03, OL.Lottable06 
         ,  OL.Lottable07, OL.Lottable08, OL.Lottable09, OL.Lottable10
         ,  OL.Lottable11, OL.Lottable12
   FROM #ORDERLINES OL
   GROUP BY OL.StorerKey
         ,  OL.SKU
         ,  OL.Facility
         ,  OL.Packkey
         ,  OL.Lottable01, OL.Lottable02, OL.Lottable03, OL.Lottable06 
         ,  OL.Lottable07, OL.Lottable08, OL.Lottable09, OL.Lottable10
         ,  OL.Lottable11, OL.Lottable12
   ORDER BY OL.StorerKey
         ,  OL.SKU

   OPEN @CUR_ORDERLINES               
   FETCH NEXT FROM @CUR_ORDERLINES INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey 
                                    ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06
                                    ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                    ,  @c_Lottable11, @c_Lottable12
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @c_StorerKey: '  + @c_StorerKey + CHAR(13) + 
               ', @c_Facility: '   + @c_Facility + CHAR(13) +
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
               ', @c_LocationCategory: ' + @c_LocationCategory + CHAR(13) + 
               ', @c_LocationType: ' + @c_LocationType+ CHAR(13) + 
               ', @c_PickZone_RTV: ' + @c_PickZone_RTV+ CHAR(13) + 
               '--------------------------------------------' 
      END
      
    
      ----------------------------------------------
      -- Insert DPBULK Available Inventory
      ----------------------------------------------
      TRUNCATE TABLE #LOTxLOCxID;
      SET @c_SQL = 
                N'INSERT INTO #LOTxLOCxID ( Lot, Loc, ID, QtyAvailable) '
   + CHAR(13) +  'SELECT LOTxLOCxID.Lot, Loc.Loc, LOTxLOCxID.ID '
   + CHAR(13) +  ',(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) AS QtyAvailable '
   + CHAR(13) +  'FROM LOTxLOCxID WITH (NOLOCK) '     
   + CHAR(13) +  'JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC AND LOC.Status <> ''HOLD'') '     
   + CHAR(13) +  'JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'') '      
   + CHAR(13) +  'JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'') '         
   + CHAR(13) +  'JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LOT.LOT = LA.LOT) ' 
   + CHAR(13) +  'JOIN SKUxLOC WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKUxLOC.Storerkey '
   + CHAR(13) +                             'AND LOTxLOCxID.Sku = SKUxLOC.Sku AND LOTxLOCxID.Loc = SKUxLOC.LOC) '
   + CHAR(13) +  'WHERE LOC.LocationFlag NOT IN ( ''HOLD'', ''DAMAGE'') '      
   + CHAR(13) +  'AND LOC.Facility = @c_Facility '   
   + CHAR(13) +  'AND LOTxLOCxID.Storerkey = @c_StorerKey '
   + CHAR(13) +  'AND LOTxLOCxID.Sku = @c_SKU ' 
   + CHAR(13) +  'AND LOC.LocationType = @c_LocationType '        
   + CHAR(13) +  'AND LOC.LocationCategory = @c_LocationCategory '    
   + CHAR(13) + CASE WHEN @c_LocationTypeOverRideStripe   = '' THEN ' AND LOC.PickZone <> @c_PickZone_RTV ' ELSE ' AND LOC.PickZone = @c_PickZone_RTV ' END              --(Wan01)   
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
   + CHAR(13) + 'AND (LOTxLOCxID.QTY - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked) > 0 '  
   + CHAR(13) + 'ORDER BY LOC.LogicalLocation, LOC.Loc, LOTxLOCxID.ID'                             
                        
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20) '  
                     +  ',@c_LocationType NVARCHAR(10), @c_LocationCategory NVARCHAR(10) '    
                     +  ',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '  
                     +  ',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30) ' 
                     +  ',@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30) '  
                     +  ',@c_Lottable12 NVARCHAR(30) '
                     +  ',@c_LocationTypeOverride NVARCHAR(10) ' 
                     +  ',@c_PickZone_RTV NVARCHAR(10) '                                                --(Wan01)          
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU
                        ,@c_LocationType, @c_LocationCategory 
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03 
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08
                        ,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12
                        ,@c_LocationTypeOverride
                        ,@c_PickZone_RTV                                                                  --(Wan01) 
 PRINT @c_SQL                                                       
      /*****************************************************************************/
      /***  START ALLOC BY ORDER Key                                             ***/
      /*****************************************************************************/
      SET @CUR_INV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT LLI.Lot
            ,LLI.Loc
            ,LLI.ID
            ,LLI.QtyAvailable
      FROM #LOTxLOCxID LLI
      ORDER BY LLI.SeqNo

      OPEN @CUR_INV               
      FETCH NEXT FROM @CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail

      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         SET @n_RemainingQty = @n_QtyAvail

         --NJOW01
          IF @n_PackQtyIndicator > 1
          BEGIN
             SELECT @n_RemainingQty = FLOOR(@n_RemainingQty / @n_PackQtyIndicator) * @n_PackQtyIndicator
          END

         SET @c_PickMethod = ''  
         SELECT @c_PickMethod = UOM3PickMethod -- piece        
         FROM LOC  WITH (NOLOCK)  
         JOIN PUTAWAYZONE WITH (NOLOCK) ON (LOC.Putawayzone = PUTAWAYZONE.Putawayzone)    
         WHERE LOC.LOC = @c_Loc   
                      
         SET @CUR_ORD = CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT OD.Orderkey, OD.OrderLineNumber, OrderQty = OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)
         FROM (SELECT DISTINCT Orderkey FROM #ORDERLINES ) t 
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON t.Orderkey = OD.Orderkey
         WHERE OD.Storerkey  = @c_Storerkey
         AND   OD.Sku        = @c_Sku
         AND   OD.Packkey    = @c_Packkey
         AND   OD.Lottable01 = @c_Lottable01
         AND   OD.Lottable02 = @c_Lottable02
         AND   OD.Lottable03 = @c_Lottable03
         AND   OD.Lottable06 = @c_Lottable06
         AND   OD.Lottable07 = @c_Lottable07
         AND   OD.Lottable08 = @c_Lottable08
         AND   OD.Lottable09 = @c_Lottable09
         AND   OD.Lottable10 = @c_Lottable10
         AND   OD.Lottable11 = @c_Lottable11
         AND   OD.Lottable12 = @c_Lottable12
         AND   OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) > 0
         ORDER BY OD.Orderkey, OD.OrderLineNumber

         OPEN @CUR_ORD
               
         FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderQty
          
         WHILE (@@FETCH_STATUS = 0) AND @n_RemainingQty > 0         
         BEGIN 
            --NJOW01
             IF @n_PackQtyIndicator > 1
             BEGIN
                SELECT @n_OrderQty = FLOOR(@n_OrderQty / @n_PackQtyIndicator) * @n_PackQtyIndicator
             END
            
            IF @n_OrderQty >= @n_RemainingQty
            BEGIN
               SET @n_QtyToInsert = @n_RemainingQty
            END
            ELSE
            BEGIN
               SET @n_QtyToInsert = @n_OrderQty
            END

            SET @n_RemainingQty = @n_RemainingQty - @n_QtyToInsert

            IF @n_QtyToInsert > 0
            BEGIN
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
                                 + ': Get PickDetailKey Failed. (ispPRNKP03)'
                  GOTO QUIT_SP
               END
               ELSE
               BEGIN
                  SET @n_UOMQty = @n_QtyToInsert
                  IF @b_Debug = 1
                  BEGIN
                     PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                           'OrderKey: ' + @c_OrderKey + CHAR(13) +
                           'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                           'OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) + CHAR(13) +
                           'QtyToTake: ' + CAST(@n_QtyToTake AS NVARCHAR) + CHAR(13) +
                           'QtyToInsert: ' + CAST(@n_QtyToInsert AS NVARCHAR) + CHAR(13) +
                           'RemainingQty: ' + CAST(@n_RemainingQty AS NVARCHAR) + CHAR(13) +
                           'SKU: ' + @c_SKU + CHAR(13) +
                           'PackKey: ' + @c_PackKey + CHAR(13) +
                           'Lot: ' + @c_Lot + CHAR(13) +
                           'Loc: ' + @c_Loc + CHAR(13) +
                           'ID: '  + @c_ID  + CHAR(13) +
                           'UOM: ' + @c_UOM + CHAR(13) +
                           'UOMQty: '+ CAST(@n_UOMQty AS NVARCHAR) + CHAR(13) +
                           'ispPRNKP03' 
                  END
                  
                  INSERT INTO PICKDETAIL (  
                        PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                        Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,
                        Loc, Id, PackKey, CartonGroup, DoReplenish,  
                        replenishzone, doCartonize, Trafficcop, PickMethod,
                        Wavekey, TaskDetailkey
                  ) VALUES (  
                        @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                        @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UOMQty, @n_QtyToInsert, '',
                        @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                        '', NULL, 'U', @c_PickMethod,
                        @c_Wavekey, @c_TaskDetailkey 
                  ) 
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 61020
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                    + ': Insert PickDetail Failed. (ispPRNKP03)'
                     GOTO QUIT_SP
                  END
               END
            END
            FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderQty
         END

         NEXT_INV:   

         FETCH NEXT FROM @CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail 
      END
      CLOSE @CUR_INV         
      DEALLOCATE @CUR_INV

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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRNKP03'  
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