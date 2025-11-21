SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPRVSE02                                         */    
/* Creation Date: 08-Mar-2018                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-4004 - CN Mast - Pre-Allocation process to allocate     */
/*          full carton by wave                                         */ 
/*          For B2B only                                                */
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
CREATE PROC [dbo].[ispPRVSE02]        
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
      @n_Continue    INT,  
      @n_StartTCnt   INT,
      @c_SQL         NVARCHAR(MAX),    
      @c_SQLParm     NVARCHAR(MAX)

   DECLARE 
      @n_OrderQty          INT,
      @n_UCCQty            INT,
      @n_InsertQty         INT,
      @n_QtyAvailable      INT,
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
      @c_WaveType          NVARCHAR(10)

   -- FROM BULK Area 
   SET @c_LocationType = 'OTHER'      
   SET @c_LocationCategory = 'VNA'
   SET @c_PickMethod = '1'
   SET @c_UOM = '7'
   
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''
           
   SELECT @c_WaveType = WaveType
   FROM WAVE (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF ISNULL(@c_WaveType,'') <> 'B2B'
   BEGIN   
      GOTO Quit
   END                     
   
   IF OBJECT_ID('tempdb..#ORDERLINES','u') IS NOT NULL
      DROP TABLE #ORDERLINES;

   CREATE TABLE #ORDERLINES (  
      SeqNo             INT IDENTITY(1, 1),  
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
   )

   INSERT INTO #ORDERLINES (OrderQty,
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
                            
   SELECT SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked)),
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
   WHERE WD.WaveKey = @c_WaveKey
   AND O.Type NOT IN ( 'M', 'I' )   
   AND O.SOStatus <> 'CANC'   
   AND O.Status < '9'   
   AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0  
   GROUP BY ISNULL(RTRIM(OD.Sku),''),
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

   DECLARE CURSOR_SKULOT CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT SKU, StorerKey, Facility, Lottable01, Lottable02, Lottable03, Lottable06, 
                   Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, OrderQty
   FROM #ORDERLINES

   OPEN CURSOR_SKULOT               
   FETCH NEXT FROM CURSOR_SKULOT INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                      @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
          
   WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN (1,2)          
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
      
      SET @c_SQL = N'
      DECLARE CURSOR_LLI CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id, (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) AS QtyAvailable 
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
           ELSE ' AND LOC.LocationType = ''' + @c_LocationType + '''' + CHAR(13) END +      
      CASE WHEN ISNULL(RTRIM(@c_LocationCategory),'') = '' THEN ''       
           ELSE ' AND LOC.LocationCategory = ''' + @c_LocationCategory + '''' + CHAR(13) END +      
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
      'AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      ORDER BY LA.Lottable04, 4, Loc.LogicalLocation, LOC.LOC'
            
      SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +      
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' + 
                         '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), ' + 
                         '@c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' + 
                         '@c_Lottable12 NVARCHAR(30) ' 
         
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, 
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12  
                         
      OPEN CURSOR_LLI               

      FETCH NEXT FROM CURSOR_LLI INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable
             
      WHILE (@@FETCH_STATUS <> -1) AND @n_OrderQty > 0 AND @n_continue IN (1,2)
      BEGIN
      	  SET @n_UCCQty = 0
      	  SELECT @n_UCCQty = MAX(UCC.Qty)
         FROM UCC (NOLOCK) 
         WHERE UCC.StorerKey = @c_StorerKey 
         AND UCC.SKU = @c_Sku
         AND UCC.LOT = @c_Lot 
         AND UCC.LOC = @c_Loc 
         AND UCC.ID = @c_Id 
         AND UCC.Status < '3'
         
         IF ISNULL(@n_UCCQty,0) = 0
            GOTO NEXT_LLI
         
         SELECT @n_QtyAvailable =  FLOOR(@n_QtyAvailable / @n_UCCQty) * @n_UCCQty
         
         IF @n_OrderQty >= @n_QtyAvailable
            SET @n_InsertQty = @n_QtyAvailable
         ELSE
         	 SET @n_InsertQty = FLOOR(@n_OrderQty / @n_UCCQty) * @n_UCCQty

         DECLARE CUR_OrderLines CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT o.OrderKey, OD.OrderLineNumber, OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) 
            FROM   ORDERS O WITH (NOLOCK)
            JOIN   ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
            JOIN   SKU (NOLOCK) ON o.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
            JOIN   PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey   
            WHERE  o.StorerKey = @c_StorerKey
            AND OD.SKU = @c_SKU
            AND o.Facility = @c_Facility
            AND OD.OpenQty - (OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked) > 0
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
            AND O.Userdefine09 = @c_Wavekey                            
            ORDER BY O.Priority, 3 DESC 
            
         OPEN CUR_OrderLines

         FETCH NEXT FROM CUR_OrderLines INTO @c_Orderkey, @c_OrderLineNumber, @n_PickQty
         
         WHILE @@FETCH_STATUS <> -1 AND @n_InsertQty > 0
         BEGIN
                        
            IF @n_PickQty > @n_InsertQty
            BEGIN
               SET @n_PickQty = @n_InsertQty
            END

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
                               ': Get PickDetailKey Failed. (ispPRVSE02)'
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
                '', 'N', 'U', @c_PickMethod  
            ) 
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 13001
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                               ': Insert PickDetail Failed. (ispPRVSE02)'
            END
            
            SET @n_InsertQty = @n_InsertQty - @n_PickQty
            SET @n_OrderQty = @n_OrderQty - @n_PickQty

            FETCH NEXT FROM CUR_OrderLines INTO @c_Orderkey, @c_OrderLineNumber, @n_PickQty
         END
         CLOSE CUR_OrderLines
         DEALLOCATE CUR_OrderLines               
         
         NEXT_LLI:                   
         FETCH NEXT FROM CURSOR_LLI INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvailable
      END            
      CLOSE CURSOR_LLI
      DEALLOCATE CURSOR_LLI                 
                   
      FETCH NEXT FROM CURSOR_SKULOT INTO @c_SKU, @c_StorerKey, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable06,
                                         @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @n_OrderQty
   END             
   CLOSE CURSOR_SKULOT           
   DEALLOCATE CURSOR_SKULOT

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_SKULOT')) >=0 
   BEGIN
      CLOSE CURSOR_SKULOT           
      DEALLOCATE CURSOR_SKULOT      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_LLI')) >=0 
   BEGIN
      CLOSE CURSOR_LLI           
      DEALLOCATE CURSOR_LLI      
   END  
   
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_ORDERLINES')) >=0 
   BEGIN
      CLOSE CURSOR_ORDERLINES           
      DEALLOCATE CURSOR_ORDERLINES      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRVSE02'  
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