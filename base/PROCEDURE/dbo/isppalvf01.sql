SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPALVF01                                         */    
/* Creation Date: 17-Sep-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Step 0a - Pick loose from Resale Zone (Retail ONLY)         */
/*                   UOM:7                                              */   
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
/* Date         Author  Ver.  Purposes                                  */    

/* 11-Dec-2019  NJOW01  1.0   WMS-10650 Include Ecom wave type check    */
/************************************************************************/    
CREATE PROC [dbo].[ispPALVF01]        
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
      @n_QtyAvailable      INT,
      @n_QtyLeftToFulfill  INT,
      @n_QtyToTake         INT,
      @n_PickQty           INT,
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
      @c_PickDetailKey     NVARCHAR(10),
      @c_PackKey           NVARCHAR(10),  
      @c_PickMethod        NVARCHAR(1),
      @n_SeqNo             INT,
      @c_WaveType          NVARCHAR(20),
      @c_ListName          NVARCHAR(10)

   SET @c_LocationType = 'OTHER'    
   SET @c_LocationCategory = 'RESALE'
   SET @c_PickMethod = '3'
   SET @c_ListName = 'ORDERGROUP'

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   -- Do not allow to process if already allocated (avoid multi Loose Pick Qty)
   IF EXISTS(SELECT 1
             FROM PickDetail PD WITH (NOLOCK)
             JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
             JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
             WHERE WD.WaveKey = @c_WaveKey)
   BEGIN  
      SET @n_Continue = 3
      SET @n_Err = 14000
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Wave#' + RTRIM(@c_WaveKey) + ' already allocated. (ispPALVF01)'
      GOTO Quit
   END 

   -- GET WaveType FROM WAVE
   SELECT @c_WaveType = UserDefine01
   FROM WAVE WITH (NOLOCK)
   WHERE WaveKey = @c_WaveKey 

   IF ISNULL(@c_WaveType,'') = ''
   BEGIN
      -- GET FROM ORDERS
      SELECT TOP 1 @c_WaveType = CODELKUP.Short
      FROM WAVEDETAIL WD WITH (NOLOCK) 
      JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = O.OrderGroup)
      WHERE WD.WaveKey = @c_WaveKey 
        AND CODELKUP.Listname = @c_ListName
   END

   -- Do not allow to process if found invalid wave type inserted
   IF ISNULL(@c_WaveType,'') NOT IN ('L', 'N', 'E')   --NJOW01
   BEGIN 
      SET @n_Continue = 3
      SET @n_Err = 14001
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                      ': Invalid Wave Type. (ispPALVF01)'
      GOTO Quit
   END 

   -- SKIP THIS STEP IF NO Retail Orders in Wave
   IF NOT EXISTS(SELECT 1 
                 FROM WAVEDETAIL WD WITH (NOLOCK) 
                 JOIN ORDERS O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey) 
                 WHERE WD.WaveKey = @c_WaveKey 
                   AND O.OrderGroup = 'RT')
      GOTO Quit

   /*****************************/
   /***   CREATE TEMP TABLE   ***/
   /*****************************/

   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   -- Store all OrderDetail in Wave
   CREATE TABLE #ORDERLINES ( 
      SeqNo             INT IDENTITY(1,1),
      OrderKey          NVARCHAR(10), 
      OrderLineNumber   NVARCHAR(5), 
      Qty               INT, 
      SKU               NVARCHAR(20),
      PackKey           NVARCHAR(10), 
      StorerKey         NVARCHAR(15), 
      Facility          NVARCHAR(5),  
      Lottable01        NVARCHAR(18), 
      Lottable02        NVARCHAR(18), 
      Lottable03        NVARCHAR(18) 
   )

   /*********************************/
   /***  GET ORDERLINES OF WAVE   ***/
   /*********************************/
   INSERT INTO #ORDERLINES 
   SELECT  
      OD.OrderKey,  
      OD.OrderLineNumber,   
      (OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),
      ISNULL(RTRIM(OD.Sku),''),
      ISNULL(RTRIM(SKU.PackKey),''),
      ISNULL(RTRIM(OD.Storerkey),''),
      ISNULL(RTRIM(O.Facility),''),
      ISNULL(RTRIM(OD.Lottable01),''),
      ISNULL(RTRIM(OD.Lottable02),''),
      ISNULL(RTRIM(OD.Lottable03),'')
   FROM ORDERDETAIL OD WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.Sku = OD.Sku  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey  
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
     AND O.Type NOT IN ( 'M', 'I' )   
     AND O.SOStatus <> 'CANC'   
     AND O.Status < '9'   
     AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
     AND O.OrderGroup = 'RT'

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #ORDERLINES WITH (NOLOCK)
   END

   DECLARE CURSOR_ORDERLINES CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT #ORDERLINES.StorerKey,  
          #ORDERLINES.SKU,
          SUM(#ORDERLINES.Qty),  
          #ORDERLINES.Facility,
          #ORDERLINES.Lottable01, 
          #ORDERLINES.Lottable02, 
          #ORDERLINES.Lottable03
   FROM #ORDERLINES WITH (NOLOCK)               
   GROUP BY #ORDERLINES.StorerKey,  
          #ORDERLINES.SKU,
          #ORDERLINES.Facility,
          #ORDERLINES.Lottable01, 
          #ORDERLINES.Lottable02, 
          #ORDERLINES.Lottable03

   OPEN CURSOR_ORDERLINES               
   FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13) +
               '  @c_StorerKey: ' + @c_StorerKey + CHAR(13) + 
               ', @c_SKU: ' +@c_SKU + CHAR(13) + 
               ', @n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR) + CHAR(13) +
               ', @c_Facility: ' + @c_Facility + CHAR(13) +
               ', @c_Lottable01: ' + @c_Lottable01 + CHAR(13) + 
               ', @c_Lottable02: ' + @c_Lottable02 + CHAR(13) + 
               ', @c_Lottable03: ' + @c_Lottable03 +' (' + CONVERT(NVARCHAR(24), GETDATE(), 121) + ')' + CHAR(13) +
               '--------------------------------------------' 
      END

      SET @c_SQL = N'    
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,    
             LOTxLOCxID.LOC,     
             LOTxLOCxID.ID,    
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)    
      FROM LOTxLOCxID (NOLOCK)     
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)    
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID AND ID.STATUS <> ''HOLD'')     
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT AND LOT.STATUS <> ''HOLD'')       
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT          
      WHERE LOC.LocationFlag <> ''HOLD''     
      AND LOC.LocationFlag <> ''DAMAGE''     
      AND LOC.Status <> ''HOLD''     
      AND LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen > 0
      AND LOC.Facility = @c_Facility        
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
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18)'

      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03

      OPEN CURSOR_AVAILABLE               
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable
             
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '--------------------------------------------' + CHAR(13) +
                  '  @c_Lot: ' + @c_Lot + CHAR(13) + 
                  ', @c_Loc: ' +@c_Loc + CHAR(13) + 
                  ', @c_ID: ' +@c_ID + CHAR(13) + 
                  ', @n_QtyAvailable: ' + CAST(@n_QtyAvailable AS NVARCHAR) + CHAR(13) + 
                  '--------------------------------------------' 
         END

         SET @c_SQL = N'
         DECLARE CURSOR_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT SeqNo, OrderKey, OrderLineNumber, Qty, PackKey
         FROM #ORDERLINES WITH (NOLOCK)
         WHERE Qty > 0
           AND SKU = @c_SKU 
           AND StorerKey = @c_StorerKey
           AND Facility = @c_Facility ' + CHAR(13) + 
           CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND Lottable01 = @c_Lottable01 ' + CHAR(13) END +      
           CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND Lottable02 = @c_Lottable02 ' + CHAR(13) END +      
           CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND Lottable03 = @c_Lottable03 ' END 

         SET @c_SQLParm =  N'@c_SKU NVARCHAR(20), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), ' +      
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18) ' 
         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03 

         OPEN CURSOR_PICKDETAIL               
         FETCH NEXT FROM CURSOR_PICKDETAIL INTO @n_SeqNo, @c_OrderKey, @c_OrderLineNumber, @n_PickQty, @c_PackKey

         WHILE (@@FETCH_STATUS <> -1) 
         BEGIN 
            IF @n_QtyAvailable = 0
               BREAK

            IF @n_QtyAvailable < @n_PickQty
               SET @n_PickQty = @n_QtyAvailable

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
               SET @n_Err = 14002
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Get PickDetailKey Failed. (ispPALVF01)'
               GOTO Quit
            END

            IF @b_Debug = 1
            BEGIN
               PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                     'OrderKey: ' + @c_OrderKey + CHAR(13) +
                     'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                     'PickQty: ' + CAST(@n_PickQty AS NVARCHAR) + CHAR(13) +
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
                @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_PickQty, @n_PickQty, 
                @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                '', NULL, 'U', @c_PickMethod  
            ) 

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 14003
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Insert PickDetail Failed. (ispPALVF01)'
               GOTO Quit
            END

            UPDATE #ORDERLINES  
               SET Qty = Qty - @n_PickQty  
            WHERE SeqNo = @n_SeqNo  

            SET @n_QtyAvailable = @n_QtyAvailable - @n_PickQty

            FETCH NEXT FROM CURSOR_PICKDETAIL INTO @n_SeqNo, @c_OrderKey, @c_OrderLineNumber, @n_PickQty, @c_PackKey
         END -- END WHILE FOR CURSOR_PICKDETAIL      
         CLOSE CURSOR_PICKDETAIL         
         DEALLOCATE CURSOR_PICKDETAIL

         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable
      END -- END WHILE FOR CURSOR_AVAILABLE      
      CLOSE CURSOR_AVAILABLE         
      DEALLOCATE CURSOR_AVAILABLE

      IF @b_Debug = 1
      BEGIN
         PRINT '--------------------------------------------' + CHAR(13)
      END

      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03
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

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_AVAILABLE')) >=0 
   BEGIN
      CLOSE CURSOR_AVAILABLE           
      DEALLOCATE CURSOR_AVAILABLE      
   END

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKDETAIL')) >=0 
   BEGIN
      CLOSE CURSOR_PICKDETAIL           
      DEALLOCATE CURSOR_PICKDETAIL      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPALVF01'  
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