SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/        
/* Stored Procedure: ispPRNIK05                                         */        
/* Creation Date: 30-Jun-2017                                           */        
/* Copyright: LFL                                                       */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: WMS-2295 - CN-Nike SDC WMS Allocation Strategy CR           */    
/*                                                                      */        
/* Called By:                                                           */        
/*                                                                      */        
/* PVCS Version: 1.1                                                    */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver.  Purposes                                  */    
/* 09-OCT-2017 Wan01    1.1   WMS-1893 - CN-Nike SDC WMS Allocation     */    
/*                            Strategy CR                               */    
/* 11-JAN-2018 Wan03    1.3   Fixed. Partial allocate UCC from Pallet   */    
/* 18-JUL-2019 CSCHONG  1.4   WMS-9822-revised report condition (CS01)  */    
/* 08-AUG-2019 CSCHONG  1.5   WMS-10204 - add channel checking (CS01a)  */    
/* 11-MAR-2020 CSCHONG  1.6   Fix execute SP Error (CS02)               */
/************************************************************************/        
CREATE  PROC [dbo].[ispPRNIK05]            
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
          , @n_LowerBound        INT    
          , @b_UpdateUCC         INT    
    
   DECLARE @n_OrderQty           INT     
         , @n_UCCQty             INT      
         , @n_UCC_RowRef         INT               
         , @n_PickQty            INT     
         , @n_QtyAvail           INT     
         , @n_CTNQty             INT    
         , @n_InsertQty          INT    
         , @n_OrderLineQty       INT      
         , @c_Loc                NVARCHAR(10)     
         , @c_Lot                NVARCHAR(10)     
         , @c_ID                 NVARCHAR(18)     
         , @c_OrderKey           NVARCHAR(10)     
         , @c_OrderLineNumber    NVARCHAR(5)      
         , @c_PickDetailKey      NVARCHAR(10)     
         , @c_Facility           NVARCHAR(5)          
         , @c_StorerKey          NVARCHAR(15)     
         , @c_SKU                NVARCHAR(20)      
         , @c_PackKey            NVARCHAR(10)       
         , @c_PickMethod         NVARCHAR(1)                             
         , @c_UCCNo              NVARCHAR(20)    
         , @c_Lottable01         NVARCHAR(18)         
         , @c_Lottable02         NVARCHAR(18)         
         , @c_Lottable03         NVARCHAR(18)     
         , @c_Lottable06         NVARCHAR(30)     
         , @c_Lottable07         NVARCHAR(30)     
         , @c_Lottable08         NVARCHAR(30)     
         , @c_Lottable09         NVARCHAR(30)     
         , @c_Lottable10      NVARCHAR(30)     
         , @c_Lottable11         NVARCHAR(30)     
         , @c_Lottable12         NVARCHAR(30)     
         , @c_LocationType      NVARCHAR(10)         
         , @c_LocationCategory   NVARCHAR(10)     
         , @c_LocationHandling   NVARCHAR(10)    
    
         , @n_IDQty              INT            --(Wan03)    
         , @c_Channel            NVARCHAR(20)       --CS01a    
         , @c_PrevChannel        NVARCHAR(20)       --CS01a    
         , @c_ChannelInvMgmt     NVARCHAR(10)       --CS01a    
         , @n_Channel_ID         BIGINT             --CS01a    
         , @c_getloc             NVARCHAR(20)       --CS01a    
         , @c_logicallocation    NVARCHAR(30)       --CS01a    
         , @n_CHANNELAvaiQty     INT                --CS01a    
         , @n_TTLCHANNELAvaiQty  INT                --CS01a    
         , @n_cntOrder           INT                --CS01a    
         , @n_ttlordqty          INT                --CS01a    
         , @n_lineCtn            INT                --CS01a    
         , @c_PrevOrderKey       NVARCHAR(10)       --CS01a    
    
   -- FROM BULK Area     
   SET @c_LocationType = 'OTHER'          
   SET @c_LocationCategory = 'BULK'    
   SET @c_LocationHandling = '1'  --1=Pallet 2=Case    
   SET @c_PickMethod = 'P'    
   SET @c_UOM = '2'    
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue=1    
   SET @b_Success=1    
   SET @n_Err=0    
   SET @c_ErrMsg=''    
    
   IF EXISTS ( SELECT 1    
               FROM WAVE WITH (NOLOCK)    
               WHERE Wavekey = @c_Wavekey    
               AND DispatchPiecePickMethod NOT IN ('DTC')    
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
   ,  Channel           NVARCHAR(20)      --CS01a    
   ,  ChannelInvMgmt    NVARCHAR(10)      --CS01a    
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
      ,  Channel_id        BIGINT                 --CS01      
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
      ,  channel_id        BIGINT                  --CS01a    
      )    
    
   /*CS01a START*/    
   IF OBJECT_ID('tempdb..#IDxLOCxChannel','u') IS NOT NULL      
   DROP TABLE #IDxLOCxChannel;      
      
   CREATE TABLE #IDxLOCxChannel       
      (        
         SeqNo             INT IDENTITY(1, 1)      
      ,  ID                NVARCHAR(18)       
      ,  Loc      NVARCHAR(10)      
      ,  LogicalLocation   NVARCHAR(10)         
      ,  QtyAvailable      INT      
      ,  channel_id        BIGINT                       
      ,  C_IDQtyAvailable  INT        
      )      
    
   /*CS01a End*/    
    
   --CS01a START    
   IF OBJECT_ID('tempdb..#CHANNELINFO','u') IS NOT NULL    
      DROP TABLE #CHANNELINFO;    
    
    CREATE TABLE #CHANNELINFO     
      ( SeqNo             INT IDENTITY(1, 1)      
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
     ,  Channel           NVARCHAR(20)         
     ,  Channel_ID        NVARCHAR(30)     
     ,  CHANNELAVIQTY     INT    
     ,  Allocated         NVARCHAR(5)    
      )    
   --CS01a END     
    
   /***************************************************************/    
   /***  GET ORDERLINES OF WAVE Group By Ship To & Omnia Order# ***/    
   /***************************************************************/    
   --(Wan01) - START    
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
         ,  Channel                 --CS01a    
         ,  ChannelInvMgmt          --CS01a    
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
         ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END      --CS01a      
         ,  ISNULL(SC.Authority,0)            --CS01a    
      FROM ORDERS      O   WITH (NOLOCK)            
      JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)     
      JOIN WAVEDETAIL  WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)      
      JOIN SKU         SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey)    
                                         AND(SKU.Sku = OD.Sku)      
      CROSS APPLY fnc_SelectGetRight (O.Facility, O.Storerkey, '', 'ChannelInventoryMgmt') SC--(CS01a)    
      WHERE WD.Wavekey = @c_WaveKey    
        AND O.Type NOT IN ( 'M', 'I' )       
        AND O.SOStatus <> 'CANC'       
        AND O.Status < '9'       
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0      
        AND O.DocType = 'E'    
        AND OD.OpenQty= 1    
        AND 1 = ( SELECT COUNT(1)     
                  FROM  ORDERDETAIL WITH (NOLOCK)    
                  WHERE ORDERDETAIl.Orderkey = O.Orderkey    
                )    
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
            ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END      --CS01a      
            ,  ISNULL(SC.Authority,0)            --CS01a    
      ORDER BY ISNULL(RTRIM(OD.Lottable01),'') DESC            --(Wan01)    
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
         ,  Channel                 --CS01a    
         ,  ChannelInvMgmt          --CS01a    
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
         ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END      --CS01a      
         ,  ISNULL(SC.Authority,0)            --CS01a    
      FROM ORDERS      O   WITH (NOLOCK)            
      JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)     
      JOIN WAVEDETAIL  WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)      
      JOIN SKU         SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey)    
                                         AND(SKU.Sku = OD.Sku)      
      CROSS APPLY fnc_SelectGetRight (O.Facility, O.Storerkey, '', 'ChannelInventoryMgmt') SC--(CS01a)    
      WHERE WD.Wavekey = @c_WaveKey    
        AND O.Type NOT IN ( 'M', 'I' )       
        AND O.SOStatus <> 'CANC'       
        AND O.Status < '9'       
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0      
        AND O.DocType = 'E'    
        AND OD.OpenQty= 1    
        AND 1 = ( SELECT COUNT(1)     
                  FROM  ORDERDETAIL WITH (NOLOCK)    
                  WHERE ORDERDETAIl.Orderkey = O.Orderkey    
                )    
      AND ISNULL(RTRIM(OD.Lottable01),'') = ''  --(Wan01)     
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
            ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END      --CS01a      
            ,  ISNULL(SC.Authority,0)            --CS01a    
      ORDER BY O.Orderkey                          --(Wan01)    
   END    
   --(Wan01) - END    
   --CS01a START    
   INSERT INTO #CHANNELINFO(Facility     
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
      ,  Channel    
      ,  Channel_ID    
      ,  CHANNELAVIQTY    
      ,  Allocated)    
   SELECT tp.facility,tp.orderkey as Orderkey,tp.storerkey as storerkey,tp.sku as sku,    
          tp.packkey as packkey,tp.OrderQty as ordqty,tp.lottable01 as lottable01,    
          tp.lottable02 as lottable02,tp.lottable03 as lottable03,tp.lottable06 as lottable06,tp.lottable07 as lottable07,    
          tp.lottable08 as lottable08,tp.lottable09 as lottable09,tp.lottable10 as lottable10,tp.lottable11 as lottable11,    
          tp.lottable12 as lottable12,tp.Channel,    
          ci.Channel_ID,(ci.Qty-ci.QtyAllocated-ci.QtyOnHold) as qtyavail ,'N'    
   FROM ChannelInv AS ci WITH(NOLOCK)     
   JOIN #ORDERLINES tp on tp.storerkey = ci.storerkey    
                    and tp.sku = ci.sku    
                    and tp.channel = ci.channel    
                    and tp.lottable07 = ci.c_attribute01    
                    and tp.facility = ci.facility     
      where (ci.Qty-ci.QtyAllocated-ci.QtyOnHold) > 0    
   --CS01a END    
    
   IF @b_Debug = 1    
   BEGIN    
    
      SELECT 'ispPRNIK05', 'Check #ORDERLINES '    
      SELECT * FROM #ORDERLINES WITH (NOLOCK)    
      SELECT 'Get #CHANNELINFO table '    
      SELECT * FROM #CHANNELINFO WITH (NOLOCK)    --CS01a    
   END    
    
   /*******************************/    
   /***  LOOP BY DISTINCT SKU   ***/    
   /*******************************/    
    
   DECLARE CUR_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR     
   SELECT StorerKey,  SKU, Facility, Packkey                                               
      , Lottable01, Lottable02, Lottable03, Lottable06     
      , Lottable07, Lottable08, Lottable09, Lottable10    
      , Lottable11, Lottable12    
      , OrderQty = SUM(OrderQty)    
      , ChannelInvMgmt                     --CS01a      
   FROM #ORDERLINES    
   GROUP BY StorerKey,  SKU, Facility, Packkey                                               
         , Lottable01, Lottable02, Lottable03, Lottable06     
         , Lottable07, Lottable08, Lottable09, Lottable10    
         , Lottable11, Lottable12,ChannelInvMgmt                     --CS01a      
   ORDER BY Lottable01 DESC                                                                  --(Wan01)    
    
   OPEN CUR_ORDERLINES                   
   FETCH NEXT FROM CUR_ORDERLINES INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey     
                                    ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06    
                                    ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10    
                                    ,  @c_Lottable11, @c_Lottable12    
                                    ,  @n_OrderQty,@c_ChannelInvMgmt                  --CS01a    
              
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
               ', @c_channel : ' + @c_channel +CHAR(13) +    
               ', @c_ChannelInvMgmt : ' + @c_ChannelInvMgmt + CHAR(13) +    
               '--------------------------------------------'     
      END    
    
      /*****************************/    
      /***  Clear TEMP Table     ***/    
      /*****************************/    
      TRUNCATE TABLE #IDxLOCxLOT    
      TRUNCATE TABLE #IDxLOC    
      TRUNCATE TABLE #IDxLOCxChannel       --CS01a    
      /************************************************/    
      /***  INSERT IDxLOCxLOT FOR CURRENT SKU       ***/    
      /************************************************/    
      -- ID with single Lot    
      -- ID without qtyallocated, qtypicked or qtyreplen    
      -- UCC ID without status between '2' and '9'  SET @c_SQL =     
      SET @n_Channel_ID = 0           --CS01a    
             
   --IF @c_ChannelInvMgmt <> '1'     --CS01a    
   --BEGIN    
   SET @c_SQL = N'INSERT INTO #IDxLOC (Loc, ID, LogicalLocation, QtyAvailable,channel_id) '         --CS01a    
   + CHAR(13) +  'SELECT LOC.Loc, LOTxLOCxID.ID, LOC.LogicalLocation '    
   + CHAR(13) +  ',SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable '    
   + CHAR(13) +  ',0 '    
   + CHAR(13) +  'FROM LOTxLOCxID WITH (NOLOCK) '         
   + CHAR(13) +  'JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC AND LOC.Status <> ''HOLD'') '         
   + CHAR(13) +  'JOIN ID  WITH (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'') '          
   + CHAR(13) +  'JOIN LOT WITH (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'') '             
   + CHAR(13) +  'JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LOT.LOT = LA.LOT) '               
   --+ CHAR(13) +  'WHERE LOC.LocationFlag <> ''HOLD'' '         --CS01    
   --+ CHAR(13) +  'AND LOC.LocationFlag <> ''DAMAGE'' '         --CS01     
   + CHAR(13) +  ' WHERE LOC.LocationFlag = ''NONE'' '           --CS01    
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
   + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN ' AND LA.Lottable01 = @c_LocationTypeOverride ' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END   --(Wan01)    
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
   + CHAR(13) + 'AND (SELECT COUNT(1) FROM UCC (NOLOCK) WHERE UCC.Lot = LOTxLOCxID.Lot AND UCC.Loc = LOTxLOCxID.Loc '      
   + CHAR(13) +      'AND UCC.ID = LOTxLOCxID.ID AND UCC.Status > ''2'' AND  UCC.Status < ''9'') = 0 '                               
   + CHAR(13) + 'AND (SELECT COUNT(DISTINCT SKU) FROM LotxLocxID ida1 (NOLOCK) WHERE ida1.ID = LOTxLOCxID.ID) = 1 '       
   + CHAR(13) + 'AND (SELECT SUM(ida2.QtyAllocated + ida2.QtyPicked + ida2.QtyReplen) FROM LOTxLOCxID ida2 (NOLOCK) '      
   + CHAR(13) +      'WHERE ida2.ID = LOTxLOCxID.ID) = 0 '      
   + CHAR(13) + 'GROUP BY LOC.Loc, LOTxLOCxID.ID, LOC.LogicalLocation '     
   + CHAR(13) + 'ORDER BY LOC.LogicalLocation, LOC.Loc, LOTxLOCxID.ID'     
                              
                             
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20) '          
                     +  ',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '      
                     +  ',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30) '     
                     +  ',@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30) '      
                     +  ',@c_Lottable12 NVARCHAR(30) '     
                     +  ',@c_LocationTypeOverride NVARCHAR(10) '  --(Wan01)   --CS01a    --CS02
           
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU    
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03     
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08    
                        ,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12      
                        ,@c_LocationTypeOverride                   --(Wan01)      
          
    
      IF NOT EXISTS (SELECT 1    
                     FROM #IDxLOC    
                    )    
      BEGIN    
         GOTO NEXT_ORDERLINES    
      END    
    
      -- Insert Inventory if matched total inventory allocated qty = Whole ID qty    
      INSERT INTO #IDxLOCxLOT (Loc, ID, Lot, QtyAvailable, IDQty,channel_id)  --CS01a    
      SELECT LLI.Loc, LLI.ID, LLI.Lot    
            ,LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen    
            ,IL.QtyAvailable    
            ,IL.Channel_id                    --CS01a    
      FROM #IDxLOC IL    
      JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (IL.Loc = LLI.Loc)    
                                        AND(IL.Id  = LLI.ID)    
      WHERE (SELECT SUM(Qty) FROM LOTxLOCxID ida3 (NOLOCK)      
             WHERE ida3.ID = LLI.ID) = IL.QtyAvailable    
      ORDER BY LLI.Lot, IL.LogicalLocation, LLI.Loc, LLI.ID    
    
      --Get Lower Bound to reduce loop size    
      SET @n_LowerBound = 0    
      SELECT @n_LowerBound = ISNULL(MIN(IDQty),0)         
      FROM #IDxLOCxLOT    
      WHERE IDQty > 0    
    
      --(Wan03) - END    
      WHILE @n_OrderQty >= @n_LowerBound AND @n_LowerBound > 0 AND @n_OrderQty > 0    
      BEGIN     
         SET @c_Loc = ''    
         SET @c_ID  = ''    
         SET @n_IDQty = 0    
    
         SELECT TOP 1     
                @c_Loc = Loc    
               ,@c_ID  = ID    
               ,@n_IDQty  = IDQty    
         FROM #IDxLOCxLOT    
         WHERE IDQty <= @n_OrderQty    
         AND QtyAvailable > 0    
         ORDER BY SeqNo    
    
         IF @n_IDQty = 0    
         BEGIN    
            BREAK    
         END    
    
         --Allocate the order group    
         DECLARE CUR_PICKID CURSOR FAST_FORWARD READ_ONLY FOR     
         SELECT Lot    
               ,Loc    
               ,ID    
               ,QtyAvailable     
         FROM #IDxLOCxLOT    
         WHERE Loc = @c_Loc                                             --(Wan03)    
         AND   ID  = @c_ID                                              --(Wan03)    
         --WHERE IDQty <= @n_OrderQty                                   --(Wan03)    
         AND QtyAvailable > 0    
         ORDER BY SeqNo    
                
         OPEN CUR_PICKID                   
         FETCH NEXT FROM CUR_PICKID INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail          --CS01a    
         --Allocate the order group    
         WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty >= @n_QtyAvail    
         BEGIN     
            SET @n_PickQty = @n_QtyAvail      
                           
            DECLARE CUR_UCC CURSOR FAST_FORWARD READ_ONLY FOR     
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
                             
            OPEN CUR_UCC    
                      
            FETCH NEXT FROM CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo, @n_UCCQty     
                                        
            WHILE (@@FETCH_STATUS <> -1) AND @n_PickQty > 0    
            BEGIN     
               SET @n_CTNQty = @n_UCCQty    
               SET @b_UpdateUCC = 1    
               SET @n_CHANNELAvaiQty = 1       --CS01a    
               SET @c_PrevOrderKey  = ''       --CS01a    
               SET @c_PrevChannel  = ''        --CS01a    
    
               IF @c_ChannelInvMgmt <> '1'   --CS01a    
               BEGIN     
                        SET @c_SQL =N'DECLARE CUR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR '     
                        + CHAR(13) + 'SELECT OD.Orderkey, OD.OrderLineNumber, OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty '    
                        + CHAR(13) + ','''' as channel,0 as channel_id '    
                        + CHAR(13) + 'FROM ORDERDETAIL OD (NOLOCK) '    
                        + CHAR(13) + 'JOIN WAVEDETAIL  WD (NOLOCK) ON (OD.Orderkey = WD.Orderkey) '    
                        + CHAR(13) + 'WHERE WD.WaveKey = @c_Wavekey '       
                        + CHAR(13) + 'AND OD.StorerKey = @c_StorerKey '                  
                        + CHAR(13) + 'AND OD.SKU = @c_SKU '    
                        + CHAR(13) + 'AND OD.Packkey = @c_Packkey '     
                        + CHAR(13) + 'AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0 '    
                        + CHAR(13) + 'AND OD.Lottable01 = @c_Lottable01 '             
                        + CHAR(13) + 'AND OD.Lottable02 = @c_Lottable02 '         
                        + CHAR(13) + 'AND OD.Lottable03 = @c_Lottable03 '                          
                        + CHAR(13) + 'AND OD.Lottable06 = @c_Lottable06 '            
                        + CHAR(13) + 'AND OD.Lottable07 = @c_Lottable07 '            
                        + CHAR(13) + 'AND OD.Lottable08 = @c_Lottable08 '            
                        + CHAR(13) + 'AND OD.Lottable09 = @c_Lottable09 '           
                        + CHAR(13) + 'AND OD.Lottable10 = @c_Lottable10 '            
                        + CHAR(13) + 'AND OD.Lottable11 = @c_Lottable11 '            
                        + CHAR(13) + 'AND OD.Lottable12 = @c_Lottable12 '     
                        + CHAR(13) + 'AND EXISTS (SELECT 1 FROM #ORDERLINES OL (NOLOCK) WHERE OD.Orderkey = OL.Orderkey) '      
               --+ CHAR(13) + 'AND OD.Channel = CASE WHEN @c_ChannelInvMgmt = ''1'' THEN @c_Channel ELSE OD.Channel END'                   --CS01a    
               END    
               ELSE    
               BEGIN    
               SET @c_SQL =N'DECLARE CUR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR '     
                        + CHAR(13) + 'SELECT OD.Orderkey, OD.OrderLineNumber, '--OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) AS Qty '    
                        + CHAR(13) + 'CASE WHEN (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) <  CA.CHANNELAVIQTY THEN '    
                        + CHAR(13) + '(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) ELSE CA.CHANNELAVIQTY END as OrderQty'    
                        + CHAR(13) + ',OD.channel ,CA.Channel_ID'    
                        + CHAR(13) + 'FROM ORDERDETAIL OD (NOLOCK) '    
                        + CHAR(13) + 'JOIN WAVEDETAIL  WD (NOLOCK) ON (OD.Orderkey = WD.Orderkey) '    
                        + CHAR(13) + 'JOIN #CHANNELINFO CA WITH (NOLOCK) ON CA.Orderkey = OD.Orderkey AND CA.Storerkey = OD.Storerkey '    
                        + CHAR(13) + '        AND CA.SKU = OD.SKU AND CA.Channel = OD.Channel '    
                        + CHAR(13) + 'WHERE WD.WaveKey = @c_Wavekey '       
                        + CHAR(13) + 'AND OD.StorerKey = @c_StorerKey '                  
                        + CHAR(13) + 'AND OD.SKU = @c_SKU '    
                        + CHAR(13) + 'AND OD.Packkey = @c_Packkey '     
                        + CHAR(13) + 'AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) > 0 '    
                        + CHAR(13) + 'AND OD.Lottable01 = @c_Lottable01 '             
                        + CHAR(13) + 'AND OD.Lottable02 = @c_Lottable02 '         
                        + CHAR(13) + 'AND OD.Lottable03 = @c_Lottable03 '                          
                        + CHAR(13) + 'AND OD.Lottable06 = @c_Lottable06 '            
                        + CHAR(13) + 'AND OD.Lottable07 = @c_Lottable07 '            
                        + CHAR(13) + 'AND OD.Lottable08 = @c_Lottable08 '            
                        + CHAR(13) + 'AND OD.Lottable09 = @c_Lottable09 '           
                        + CHAR(13) + 'AND OD.Lottable10 = @c_Lottable10 '            
                        + CHAR(13) + 'AND OD.Lottable11 = @c_Lottable11 '            
                        + CHAR(13) + 'AND OD.Lottable12 = @c_Lottable12 '     
                        + CHAR(13) + 'AND EXISTS (SELECT 1 FROM #ORDERLINES OL (NOLOCK) WHERE OD.Orderkey = OL.Orderkey) '     
                        + CHAR(13) + 'AND CA.CHANNELAVIQTY > 0 '    
                        + CHAR(13) + 'AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) >= @n_CTNQty '    
                        + CHAR(13) + ' ORDER BY CASE WHEN (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) <  CA.CHANNELAVIQTY THEN (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) ELSE CA.CHANNELAVIQTY END desc '    
                     -- + CHAR(13) + ' ORDER BY CASE WHEN OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) <= @n_CTNQty THEN 1 ELSE 0 END'    
                        + CHAR(13) + ' , CASE WHEN OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) >= @n_CTNQty THEN 1 ELSE 0 END'    
               
                        END  --CS01 END    
                 
                        SET @c_SQLParm =  N'@c_Wavekey NVARCHAR(10),@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Packkey NVARCHAR(10)'         
                                       + ', @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18)'      
                                       + ', @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30)'      
                                       + ', @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30)'     
                                       + ', @c_Lottable12 NVARCHAR(30) , @n_CTNQty INT '                   --CS01a      
                               
                        EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Wavekey, @c_StorerKey ,@c_SKU, @c_Packkey      
                                          , @c_Lottable01, @c_Lottable02, @c_Lottable03    
                                          , @c_Lottable06, @c_Lottable07, @c_Lottable08    
                                          , @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,@n_CTNQty        --CS01a    
                                     
                        OPEN CUR_ORDLINE                   
                        FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty,@c_channel,@n_Channel_id   --CS01a    
                   
               --Retrieve all order lines for the order group and create pickdetail    
               WHILE (@@FETCH_STATUS <> -1) AND @n_CTNQty > 0             
               BEGIN     
            
                IF @n_OrderLineQty >= @n_CTNQty     --CS01d   
                BEGIN        
                 SET @n_InsertQty = @n_CTNQty        
                END        
                ELSE        
                BEGIN        
                 SET @n_InsertQty = @n_OrderLineQty        
                END        
    
                IF @b_Debug ='1'    
                BEGIN    
                    SELECT @c_SQL    
                    SELECT @c_Orderkey '@c_Orderkey', @n_OrderLineQty 'ordqty',@c_channel '@c_channel' ,@n_CHANNELAvaiQty '@n_CHANNELAvaiQty' ,@n_InsertQty '@n_InsertQty',@n_CTNQty '@n_CTNQty'  
                    SELECT * from ORDERDETAIL WITH (NOLOCK) WHERE Orderkey = @c_Orderkey AND OrderLineNumber =  @c_OrderLineNumber and sku in('928484010M')  
                    SELECT 'ChannelInv',* FROM ChannelInv AS ci WITH(NOLOCK)    
                       WHERE ci.Channel_ID = @n_channel_id --and ci.sku = @c_SKU  
                END   
            
                --CS01a    
                IF  @c_ChannelInvMgmt = '1'    
                BEGIN    
                  IF @c_PrevOrderKey <> @c_Orderkey and @c_channel <> @c_PrevChannel    
                  BEGIN    
                     SELECT @n_cntOrder = COUNT(1)    
                           ,@n_ttlordqty = SUM( OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ))    
                     FROM ORDERDETAIL OD WITH (NOLOCK)    
                     JOIN WAVEDETAIL  WD (NOLOCK) ON (OD.Orderkey = WD.Orderkey)  
                     --WHERE Orderkey = @c_Orderkey    
                     --AND Channel = @c_channel    
                WHERE OD.SKU = @c_sku   
                AND WD.WaveKey = @c_WaveKey  
                
                     --SELECT @n_CHANNELAvaiQty = CHANNELAVIQTY    
                     --      --,@n_Channel_id = Channel_ID    
                     --FROM #CHANNELINFO    
                     --WHERE Orderkey = @c_Orderkey    
                     --AND Channel = @c_channel    
                     --AND channel_id = @n_Channel_id    
                 END    
                
                  IF @n_cntOrder = 1    
                  BEGIN    
                     IF @n_ttlordqty > @n_CHANNELAvaiQty    
                     BEGIN    
                       SET @n_OrderLineQty = @n_CHANNELAvaiQty    
                     END    
                  END    
                 ELSE    
                 BEGIN    
                     IF @n_OrderLineQty > @n_CHANNELAvaiQty    
                     BEGIN    
                       SET @n_OrderLineQty = @n_CHANNELAvaiQty    
                     END    
                  END    
                END    
    
              --CS01a End    
              
               --IF @n_OrderLineQty <= @n_CTNQty     
               --BEGIN    
               --   SET @n_InsertQty = @n_OrderLineQty    
               --END    
               --ELSE    
               --BEGIN    
               --   SET @n_InsertQty = @n_CTNQty    
               --END    
    
               IF @c_ChannelInvMgmt = '1'   --CS01a    
               BEGIN    
             
                
             
                 SET @c_PrevOrderKey = @c_Orderkey    
                 SET @c_PrevChannel = @c_channel    
                -- SET @n_CHANNELAvaiQty = @n_CHANNELAvaiQty - @n_InsertQty    
             
              IF @b_Debug ='1'    
              BEGIN    
                 SELECT @c_UCCNo '@c_UCCNo'    
                 SELECT * FROM #CHANNELINFO    
                 WHERE Allocated = 'N'    
              END    
    
            END --CS01a    
    
                  SET @n_CTNQty = @n_CTNQty - @n_InsertQty    
                  SET @n_PickQty= @n_PickQty- @n_InsertQty    
                        
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
                                    + ': Get PickDetailKey Failed. (ispPRNIK05)'    
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
                                              
                     INSERT PICKDETAIL (      
                           PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,      
                           Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,    
                           Loc, Id, PackKey, CartonGroup, DoReplenish,      
                           replenishzone, doCartonize, Trafficcop, PickMethod,    
                           Wavekey  ,channel_id                     --CS01a     
                     ) VALUES (      
                           @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,      
                           @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UCCQty, @n_InsertQty, @c_UCCNo,    
                           @c_Loc, @c_ID, @c_PackKey, '', 'N',      
                           '', NULL, 'U', @c_PickMethod,    
                           @c_Wavekey ,@n_channel_id             --CS01a    
                     )     
                      
                     IF @@ERROR <> 0    
                     BEGIN    
                        SET @n_Continue = 3    
                        SET @n_Err = 61020    
                        SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))      
                                       + ': Insert PickDetail Failed. (ispPRNIK05)'    
                        GOTO QUIT_SP    
                     END    
  
                     UPDATE #CHANNELINFO    
                     SET CHANNELAVIQTY = CASE WHEN (CHANNELAVIQTY-@n_InsertQty) > 0 THEN (CHANNELAVIQTY-@n_InsertQty) ELSE 0 END    
                     --, Allocated = CASE WHEN CHANNELAVIQTY-@n_OrderLineQty = 0 THEN 'Y' ELSE Allocated END    
                     WHERE Orderkey = @c_Orderkey    
                     AND Channel = @c_channel    
                     AND channel_id = @n_Channel_id    
    
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
                                          + ': Update UCC Failed. (ispPRNIK05)'    
                           GOTO QUIT_SP    
                        END       
    
                        SET @b_UpdateUCC = 0    
                     END                       
                  END -- IF @b_Success = 1     
                  FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderLineQty,@c_channel,@n_Channel_id  --CS01a    
               END    
               CLOSE CUR_ORDLINE             
               DEALLOCATE CUR_ORDLINE      
    
               FETCH NEXT FROM CUR_UCC INTO @n_UCC_RowRef, @c_UCCNo, @n_UCCQty                                      
            END        
            CLOSE CUR_UCC    
            DEALLOCATE CUR_UCC                           
                 
            SET @n_OrderQty = @n_OrderQty - @n_QtyAvail                                      
                
            FETCH NEXT FROM CUR_PICKID INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail    
         END    
         CLOSE CUR_PICKID             
         DEALLOCATE CUR_PICKID    
      END -- END WHILE @n_OrderQty>=@n_LowerBound    
    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '--------------------------------------------' + CHAR(13)    
      END    
    
      NEXT_ORDERLINES:    
      FETCH NEXT FROM CUR_ORDERLINES INTO @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey     
                                       ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06    
                                       ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10    
                                       ,  @c_Lottable11, @c_Lottable12    
                                       ,  @n_OrderQty,@c_ChannelInvMgmt                  --CS01a    
   END -- END WHILE FOR CUR_ORDERLINES                 
   CLOSE CUR_ORDERLINES              
   DEALLOCATE CUR_ORDERLINES    
    
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
    
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORDERLINES') in (0 , 1)      
   BEGIN    
      CLOSE CUR_ORDERLINES               
      DEALLOCATE CUR_ORDERLINES          
   END      
    
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORDERLINE_SKU') in (0 , 1)      
   BEGIN    
      CLOSE CUR_ORDERLINE_SKU               
      DEALLOCATE CUR_ORDERLINE_SKU          
   END      
    
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PICKID') in (0 , 1)      
   BEGIN    
      CLOSE CUR_PICKID               
      DEALLOCATE CUR_PICKID          
   END    
       
   IF CURSOR_STATUS( 'LOCAL', 'CUR_UCC') in (0 , 1)      
   BEGIN    
      CLOSE CUR_UCC               
      DEALLOCATE CUR_UCC          
   END       
    
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORDLINE') in (0 , 1)      
   BEGIN    
      CLOSE CUR_ORDLINE               
      DEALLOCATE CUR_ORDLINE          
   END      
       
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL    
      DROP TABLE #ORDERLINES;    
    
   IF OBJECT_ID('tempdb..#IDxLOCxLOT','u') IS NOT NULL    
      DROP TABLE #IDxLOCxLOT;    
    
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRNIK05'      
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