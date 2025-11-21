SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
      
/************************************************************************/              
/* Stored Procedure: ispPRNIK09                                         */              
/* Creation Date: 09-OCT-2017                                           */              
/* Copyright: LFL                                                       */              
/* Written by: YTWan                                                    */              
/*                                                                      */              
/* Purpose:WMS-1893 - CN-Nike SDC WMS Allocation Strategy CR            */          
/*                                                                      */              
/* Called By:                                                           */              
/*                                                                      */              
/* PVCS Version: 1.0                                                    */              
/*                                                                      */              
/* Data Modifications:                                                  */              
/*                                                                      */              
/* Updates:                                                             */              
/* Date        Author   Ver.  Purposes                                  */          
/* 18-JUL-2019 CSCHONG  1.1   WMS-9822-revised report condition (CS01)  */          
/* 08-AUG-2019 CSCHONG  1.2   WMS-10204 - add channel checking (CS01a)  */      
/* 28-NOV-2019 CSCHONG  1.45   WMS-10204 - Fix uom issue (CS01c)        */     
/************************************************************************/              
CREATE PROC [dbo].[ispPRNIK09]                  
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
          , @b_UpdateUCC         INT          
          
   DECLARE @n_SeqNo              INT          
         , @n_QtyLeftToFullFill  INT           
         , @n_QtyAvail           INT          
         , @n_QtyToTake          INT          
         , @n_RemainQty          INT            
         , @n_OrderQty           INT          
         , @n_QtyToInsert        INT          
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
         , @c_Lottable01         NVARCHAR(18)               
         , @c_Lottable02         NVARCHAR(18)               
         , @c_Lottable03         NVARCHAR(18)           
         , @c_Lottable06         NVARCHAR(30)           
         , @c_Lottable07         NVARCHAR(30)           
         , @c_Lottable08         NVARCHAR(30)           
         , @c_Lottable09         NVARCHAR(30)           
         , @c_Lottable10         NVARCHAR(30)           
         , @c_Lottable11         NVARCHAR(30)           
         , @c_Lottable12         NVARCHAR(30)           
         , @c_LocationType       NVARCHAR(10)               
         , @c_LocationCategory   NVARCHAR(10)           
         , @c_LocationHandling   NVARCHAR(10)       
         , @c_Channel            NVARCHAR(20)       --CS01a      
         , @c_PrevChannel        NVARCHAR(20)       --CS01a      
         , @c_ChannelInvMgmt     NVARCHAR(10)       --CS01a      
         , @n_Channel_ID         BIGINT             --CS01a      
         , @c_getloc             NVARCHAR(20)       --CS01a      
         , @c_logicallocation    NVARCHAR(30)       --CS01a      
         , @n_ChannelqtyAvail    INT                --CS01a      
          
         , @cur_ORDERLINES       CURSOR          
          
   -- FROM DPP & Shelving Area           
   SET @c_LocationType = 'DYNPPICK'              
   SET @c_LocationCategory = 'SHELVING'            
   SET @c_UOM = '7'          
          
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
   ,  Channel           NVARCHAR(20)      --CS01a      
   ,  ChannelInvMgmt    NVARCHAR(10)      --CS01a      
   )         
         
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
   /***  GET ORDERLINES OF WAVE                                 ***/          
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
         ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END       --CS01a        
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
            ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END       --CS01a        
            ,  ISNULL(SC.Authority,0)            --CS01a         
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
         ,  Channel                             --CS01a      
         ,  ChannelInvMgmt                      --CS01a      
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
         ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END       --CS01a        
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
            ,  CASE WHEN ISNULL(SC.Authority,0) = '1' THEN ISNULL(RTRIM(OD.Channel),'')  ELSE '' END       --CS01a        
            ,  ISNULL(SC.Authority,0)            --CS01a        
      ORDER BY O.Orderkey                   
   END      
         
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
   --CS01a END          
             
   IF @b_Debug = 1          
   BEGIN      
      SELECT 'ispPRNIK09'          
      SELECT * FROM #ORDERLINES WITH (NOLOCK)        
      SELECT 'Get #CHANNELINFO table '      
      SELECT * FROM #CHANNELINFO WITH (NOLOCK)    --CS01a        
   END          
          
   /**********************************/          
   /***  LOOP BY ORDERDETAIL SKU   ***/          
   /**********************************/          
          
   DECLARE CUR_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR           
   SELECT   StorerKey,  SKU, Facility, Packkey, QtyLeftToFullFill = SUM(OrderQty)          
         ,  Lottable01, Lottable02, Lottable03, Lottable06           
         ,  Lottable07, Lottable08, Lottable09, Lottable10          
         ,  Lottable11, Lottable12,ChannelInvMgmt                     --CS01a          
   FROM #ORDERLINES          
   GROUP BY StorerKey          
         ,  SKU          
         ,  Facility          
         ,  Packkey          
         ,  Lottable01, Lottable02, Lottable03, Lottable06           
         ,  Lottable07, Lottable08, Lottable09, Lottable10          
         ,  Lottable11, Lottable12,Channel,ChannelInvMgmt                  --CS01a          
   ORDER BY sku          
          
   OPEN CUR_ORDERLINES                         
   FETCH NEXT FROM CUR_ORDERLINES INTO  @c_StorerKey, @c_SKU, @c_Facility, @c_Packkey, @n_QtyLeftToFullFill          
                                    ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06          
                                    ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10          
                                    ,  @c_Lottable11, @c_Lottable12,@c_ChannelInvMgmt                --CS01a          
                    
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
               ', @c_LocationTypeOverride: ' + @c_LocationTypeOverride + CHAR(13) +           
               ', @n_QtyLeftToFullFill: ' + CAST( @n_QtyLeftToFullFill AS NVARCHAR(10)) + CHAR(13) +        
               ', @c_channel : ' + @c_channel +CHAR(13) +      
               ', @c_ChannelInvMgmt : ' + @c_ChannelInvMgmt + CHAR(13) +        
               '--------------------------------------------'           
      END        
               
      SET @c_SQL =           
              N'DECLARE CUR_INV CURSOR FAST_FORWARD READ_ONLY FOR '          
              + CHAR(13) +  'SELECT LOTxLOCxID.Lot, Loc.Loc, LOTxLOCxID.ID '          
              + CHAR(13) +  ',(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen) AS QtyAvailable '        
              + CHAR(13) +  ',0 as channel_id,'''','''' '                                                              -- CS01a      
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
              + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_LocationType),'') = '' THEN ' '           
                                ELSE 'AND LOC.LocationType = @c_LocationType ' END                
              + CHAR(13) + CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ' '                 
                                ELSE 'AND LOC.LocationCategory = @c_LocationCategory ' END                 
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
              + CHAR(13) + 'ORDER BY LOC.LogicalLocation, LOC.Loc, LOTxLOCxID.ID'           
         
 IF @b_Debug = 1      
             BEGIN      
               SELECT @c_SQL      
             END                          
                                  
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20) '           
                     +  ',@c_LocationType NVARCHAR(10), @c_LocationCategory NVARCHAR(10) '                  
                     +  ',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) '            
                     +  ',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30) '           
                     +  ',@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30) '            
                     +  ',@c_Lottable12 NVARCHAR(30) '           
                     +  ',@c_LocationTypeOverride NVARCHAR(10),@c_channel NVARCHAR(30) '       --CS01a        
             
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU          
                        ,@c_LocationType, @c_LocationCategory          
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03        
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08          
                        ,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12            
                        ,@c_LocationTypeOverride ,@c_channel                                      --CS01a                    
           
      OPEN CUR_INV                         
      FETCH NEXT FROM CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail,@n_Channel_ID,@c_getloc, @c_logicallocation         --CS01a       
          
      --Allocate the order group          
      WHILE (@@FETCH_STATUS <> -1) AND @n_QtyLeftToFullFill > 0           
      BEGIN            
         IF @b_Debug = 1          
         BEGIN          
            SELECT @c_SQL        
            select @c_Facility '@c_Facility',@c_SKU '@c_SKU',@c_LocationType '@c_LocationType',@c_LocationCategory '@c_LocationCategory',      
                   @n_QtyAvail '@n_QtyAvail',@n_Channel_ID   '@n_Channel_ID',@c_channel '@c_channel',@c_Lot '@c_Lot'      
            PRINT 'Orderkey: ' + @c_Orderkey + ', OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR)           
            --PRINT 'STEP 1: START - ' + CONVERT(NVARCHAR(24), GETDATE(), 121)          
         END                    
                
         IF @n_QtyAvail >= @n_QtyLeftToFullFill                
         BEGIN                
            SET @n_QtyToTake = @n_QtyLeftToFullFill                
         END                
         ELSE                
         BEGIN                
            SET @n_QtyToTake = @n_QtyAvail                
         END            
          
         IF @n_QtyToTake = 0          
         BEGIN          
            GOTO NEXT_INV          
         END          
          
         SET @c_PickMethod = ''          
         SELECT @c_PickMethod = UOM3PickMethod -- piece                
         FROM LOC  WITH (NOLOCK)          
         JOIN PUTAWAYZONE WITH (NOLOCK) ON (LOC.Putawayzone = PUTAWAYZONE.Putawayzone)            
         WHERE LOC.LOC = @c_Loc                
          
         SET @n_RemainQty = @n_QtyToTake          
          
         --NJOW         
         IF  @c_ChannelInvMgmt <> '1'   --CS01a       
         BEGIN       
         SET @c_SQL =      
                     --      N'SET @cur_ORDERLINES = CURSOR FAST_FORWARD READ_ONLY FOR   '       
                   N'DECLARE CUR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR'      
                      + CHAR(13) + ' SELECT OD.Orderkey, OD.OrderLineNumber, OrderQty = OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) '      
                      + CHAR(13) + '  ,'''' as Channel ,0 as channel_id'        
                      + CHAR(13) + ' FROM ORDERDETAIL OD WITH (NOLOCK) '       
                      + CHAR(13) + ' WHERE OD.Storerkey  = @c_Storerkey'       
                      + CHAR(13) + ' AND   OD.Sku        = @c_Sku '      
                      + CHAR(13) + ' AND   OD.Packkey    = @c_Packkey '         
                      + CHAR(13) + ' AND   OD.Lottable01 = @c_Lottable01'          
                      + CHAR(13) + ' AND   OD.Lottable02 = @c_Lottable02'         
                      + CHAR(13) + ' AND   OD.Lottable03 = @c_Lottable03'          
                      + CHAR(13) + ' AND   OD.Lottable06 = @c_Lottable06'         
                      + CHAR(13) + ' AND   OD.Lottable07 = @c_Lottable07'          
                      + CHAR(13) + ' AND   OD.Lottable08 = @c_Lottable08'          
                      + CHAR(13) + ' AND   OD.Lottable09 = @c_Lottable09'          
                      + CHAR(13) + ' AND   OD.Lottable10 = @c_Lottable10'          
                      + CHAR(13) + ' AND   OD.Lottable11 = @c_Lottable11'          
                      + CHAR(13) + ' AND   OD.Lottable12 = @c_Lottable12'          
                      + CHAR(13) + ' AND   OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) > 0'      
                      + CHAR(13) + ' AND   OD.Orderkey IN (SELECT Orderkey FROM #ORDERLINES)'       
                   -- + CHAR(13) + ' AND   OD.Channel = CASE WHEN @c_ChannelInvMgmt = '1' THEN @c_Channel ELSE OD.Channel END --CS01a       
                      + CHAR(13) + ' ORDER BY OD.Orderkey, OD.OrderLineNumber   '       
      END      
      ELSE      
      BEGIN      
      SET @c_SQL =      
                      --N'SET @cur_ORDERLINES = CURSOR FAST_FORWARD READ_ONLY FOR   '       
                  N'DECLARE CUR_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR'      
                   + CHAR(13) + ' SELECT OD.Orderkey, OD.OrderLineNumber, '      
                   + CHAR(13) + 'CASE WHEN (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) <  CA.CHANNELAVIQTY THEN '      
                   + CHAR(13) + '(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) ELSE CA.CHANNELAVIQTY END as OrderQty'      
                   + CHAR(13) + ' ,OD.channel,CA.Channel_ID'       
                   + CHAR(13) + ' FROM ORDERDETAIL OD WITH (NOLOCK) '       
                   + CHAR(13) + 'JOIN #CHANNELINFO CA WITH (NOLOCK) ON CA.Orderkey = OD.Orderkey AND CA.Storerkey = OD.Storerkey '      
                   + CHAR(13) + '                                   AND CA.SKU = OD.SKU AND CA.Channel = OD.Channel '      
                   + CHAR(13) + ' WHERE OD.Storerkey  = @c_Storerkey'       
                   + CHAR(13) + ' AND   OD.Sku        = @c_Sku '      
                   + CHAR(13) + ' AND   OD.Packkey    = @c_Packkey '         
                   + CHAR(13) + ' AND   OD.Lottable01 = @c_Lottable01'          
                   + CHAR(13) + ' AND   OD.Lottable02 = @c_Lottable02'         
                   + CHAR(13) + ' AND   OD.Lottable03 = @c_Lottable03'          
                   + CHAR(13) + ' AND   OD.Lottable06 = @c_Lottable06'         
                   + CHAR(13) + ' AND   OD.Lottable07 = @c_Lottable07'          
                   + CHAR(13) + ' AND   OD.Lottable08 = @c_Lottable08'          
                   + CHAR(13) + ' AND   OD.Lottable09 = @c_Lottable09'          
                   + CHAR(13) + ' AND   OD.Lottable10 = @c_Lottable10'          
                   + CHAR(13) + ' AND   OD.Lottable11 = @c_Lottable11'          
                   + CHAR(13) + ' AND   OD.Lottable12 = @c_Lottable12'          
                   + CHAR(13) + ' AND   OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) > 0'      
                   + CHAR(13) + ' AND   OD.Orderkey IN (SELECT Orderkey FROM #ORDERLINES)'       
                   + CHAR(13) + ' AND   CA.CHANNELAVIQTY > 0 '      
                  --AND   OD.Channel = CASE WHEN @c_ChannelInvMgmt = '1' THEN @c_Channel ELSE OD.Channel END --CS01a      
                   + CHAR(13) + 'ORDER BY CASE WHEN (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) <  CA.CHANNELAVIQTY THEN '      
                   + CHAR(13) + '(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) ELSE CA.CHANNELAVIQTY END desc'      
                   + CHAR(13) + '      , CASE WHEN OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked ) >= @n_RemainQty THEN 1 ELSE 0 END'      
         END  --CS01a END      
          
           --CS01a START      
           SET @c_SQLParm =  N'@c_WaveKey NVARCHAR(10), @c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Packkey NVARCHAR(10)'           
                              + ', @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18)'        
                              + ', @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30)'        
                              + ', @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30)'       
                              + ', @c_Lottable12 NVARCHAR(30), @n_RemainQty INT '                        
                        
                EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_WaveKey, @c_StorerKey ,@c_SKU, @c_Packkey       
                                 , @c_Lottable01, @c_Lottable02, @c_Lottable03      
                                 , @c_Lottable06, @c_Lottable07, @c_Lottable08      
                                 , @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,@n_RemainQty        
         --CS01a END      
      
      OPEN CUR_ORDLINE                     
      FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderQty,@c_Channel,@n_Channel_ID      --CS01a      
         --OPEN @cur_ORDERLINES          
                         
         --FETCH NEXT FROM @cur_ORDERLINES INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderQty          
                    
         WHILE (@@FETCH_STATUS = 0) AND @n_RemainQty > 0                   
         BEGIN           
          
            IF @n_OrderQty >= @n_RemainQty          
            BEGIN          
               SET @n_QtyToInsert = @n_RemainQty          
            END          
            ELSE          
            BEGIN          
               SET @n_QtyToInsert = @n_OrderQty          
            END          
      
            IF @b_Debug = 1          
            BEGIN       
               SELECT @n_QtyToInsert '@@n_QtyToInsert'--,@n_QtyToTake '@n_QtyToTake'      
            END      
      
            IF @c_ChannelInvMgmt = '1'   --CS01a      
            BEGIN      
    
                SET @n_ChannelqtyAvail = 0  --CS01c START    
                    
                SELECT top 1 @n_ChannelqtyAvail = CHANNELAVIQTY      
                          -- ,@n_Channel_id = Channel_ID      
                FROM #CHANNELINFO      
                WHERE Channel = @c_channel      
                AND SKU = @c_SKU    
                AND channel_id = @n_Channel_id      
                  
                  IF @b_Debug = 1          
                  BEGIN    
                    SELECT 'B4',@c_Orderkey '@c_Orderkey', @n_ChannelqtyAvail '@n_ChannelqtyAvail',@c_SKU '@c_SKU'    
                  END     
    
                 IF @n_ChannelqtyAvail > 0    
                 BEGIN    
                   
                    IF @n_QtyToInsert > @n_ChannelqtyAvail    
                    BEGIN    
                      SET @n_QtyToInsert = @n_ChannelqtyAvail    
                    END    
                 END    
                   
                 IF @b_Debug = 1          
                 BEGIN    
                   SELECT 'AFTER',@c_Orderkey '@c_Orderkey',@n_QtyToInsert '@n_QtyToInsert', @c_SKU '@c_SKU'    
                 END     
                    --CS01c END    
                  --   if @n_OrderQty < @n_RemainUCCQty --OR @n_OrderLineQty > @n_CHANNELAvaiQty   --CS01c    
                    --BEGIN    
                         
                    -- BREAK    
                          
                    --END    
                    
                    IF @b_Debug = 1          
                    BEGIN    
                     SELECT 'before update', @n_QtyToInsert '@n_QtyToInsert'    
                     SELECT *    
                     from #CHANNELINFO    
                     where Channel = @c_channel         --CS01c    
                        AND channel_id = @n_Channel_id    
                    END    
                    
            END --CS01a      
          
            SET @n_RemainQty= @n_RemainQty - @n_QtyToInsert          
          
            IF @b_Debug = 1          
            BEGIN          
               PRINT 'Orderkey: ' + @c_Orderkey + ', @n_QtyToTake: ' + CAST(@n_QtyToTake AS NVARCHAR)          
               PRINT 'Lot: ' + @c_Lot          
               PRINT 'Loc: ' + @c_Loc          
               PRINT 'ID: ' + @c_ID          
            END          
          
            -- INSERT #PickDetail     
         IF @n_QtyToInsert <= @n_ChannelqtyAvail   --CS01c start    
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
                              + ': Get PickDetailKey Failed. (ispPRNIK09)'          
               GOTO QUIT_SP          
            END          
            ELSE          
            BEGIN          
               IF @b_Debug = 1          
               BEGIN          
                  PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +          
                        'OrderKey: ' + @c_OrderKey + CHAR(13) +          
                        'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +          
                        '@n_QtyToTake: ' + CAST(@n_QtyToTake AS NVARCHAR) + CHAR(13) +          
                        'SKU: ' + @c_SKU + CHAR(13) +          
                        'PackKey: ' + @c_PackKey + CHAR(13) +          
                        'Lot: ' + @c_Lot + CHAR(13) +          
                        'Loc: ' + @c_Loc + CHAR(13) +          
                        'ID: ' + @c_ID + CHAR(13) +          
                        'UOM: ' + @c_UOM + CHAR(13)           
               END          
                                                    
               INSERT INTO PICKDETAIL (            
                     PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,            
                     Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,          
                     Loc, Id, PackKey, CartonGroup, DoReplenish,            
                     replenishzone, doCartonize, Trafficcop, PickMethod,          
                     Wavekey,channel_id                                         --CS01a           
               ) VALUES (            
                     @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,            
                     @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_QtyToInsert, @n_QtyToInsert, '',          
                     @c_Loc, @c_ID, @c_PackKey, '', 'N',            
                     '', NULL, 'U', @c_PickMethod,          
                     @c_Wavekey,@n_Channel_ID                                   --CS01a      
               )           
                            
               IF @@ERROR <> 0          
               BEGIN          
                  SET @n_Continue = 3          
                  SET @n_Err = 61020          
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))           
                                 + ': Insert PickDetail Failed. (ispPRNIK09)'          
                  GOTO QUIT_SP          
               END     
                
            --CS01c START    
    
            UPDATE #CHANNELINFO     
                SET CHANNELAVIQTY = CHANNELAVIQTY-@n_QtyToInsert      
                --, Allocated = CASE WHEN CHANNELAVIQTY-@n_OrderLineQty = 0 THEN 'Y' ELSE Allocated END      
                --WHERE Orderkey = @c_Orderkey      
                where Channel = @c_channel         --CS01c    
                AND channel_id = @n_Channel_id      
                AND SKU = @c_SKU    
    
              --CS01c END    
                     
            END          
          END  --CS01c     
         FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrderQty ,@c_Channel,@n_Channel_ID          
         END       
         CLOSE CUR_ORDLINE               
         DEALLOCATE CUR_ORDLINE             
                                    
         NEXT_INV:               
         SET @n_QtyLeftToFullFill = @n_QtyLeftToFullFill - @n_QtyToTake           
                                                              
         FETCH NEXT FROM CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvail , @n_Channel_ID ,@c_getloc, @c_logicallocation --CS01a       
      END          
      CLOSE CUR_INV                   
      DEALLOCATE CUR_INV          
          
      IF @b_Debug = 1          
      BEGIN          
         PRINT '--------------------------------------------' + CHAR(13)          
      END          
          
      NEXT_ORDERLINES:          
      FETCH NEXT FROM CUR_ORDERLINES INTO @c_StorerKey,  @c_SKU, @c_Facility, @c_Packkey, @n_QtyLeftToFullFill          
                                       ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06          
                                       ,  @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10          
                                       ,  @c_Lottable11, @c_Lottable12,@c_ChannelInvMgmt                --CS01a       
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
          
   IF CURSOR_STATUS( 'LOCAL', 'CUR_INV') in (0 , 1)            
   BEGIN          
      CLOSE CUR_INV                     
      DEALLOCATE CUR_INV                
   END          
              
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL          
      DROP TABLE #ORDERLINES;          
          
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRNIK09'            
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