SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPALCULP                                         */    
/* Creation Date: 13-Nov-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Rev  Purposes                                  */    
/* 13-Apr-2017  Shong    1.0  UNILEVER Post Allocate Process            */
/* 23-Apr-2020  NJOW01   1.1  WMS-13036 add lottable filtering by config*/
/************************************************************************/    
CREATE PROC [dbo].[ispPALCULP]      
     @c_OrderKey    NVARCHAR(10) = ''   
   , @c_LoadKey     NVARCHAR(10) = ''
   , @b_Success     INT           = 1  OUTPUT      
   , @n_Err         INT           = 0  OUTPUT      
   , @c_ErrMsg      NVARCHAR(250) = '' OUTPUT      
   , @b_debug       INT = 0      
   , @b_ChildFlag   INT = 0     
   , @c_TrackingNo  NVARCHAR(20) = '' OUTPUT    
AS      
BEGIN      
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
      
   DECLARE  @n_Continue                   INT,      
            @n_StartTCnt                  INT, -- Holds the current transaction count  
            @n_Retry                      INT,        
            @c_SKU                        NVARCHAR(20),   
            @n_QtyPreallocated            INT,   
            @c_StorerKey                  NVARCHAR(15),  
            @c_LOT                        NVARCHAR(10),  
            @c_SuggestLOT                 NVARCHAR(10),
            @c_PreAllocatePickDetailKey   NVARCHAR(10),  
            @c_Facility                   NVARCHAR(5),
            @c_PickDetailKey              NVARCHAR(10),
            @c_OrderLineNumber            NVARCHAR(5),
            @c_Loc                        NVARCHAR(10),
            @c_ID                         NVARCHAR(18),
            @c_UOM                        NVARCHAR(10),
            @c_Packkey                    NVARCHAR(10),
            @n_QtyToInsert                INT,
            @n_QtyAvailable               INT, 
            --@c_Lottable01                 NVARCHAR(18) = '',
            @c_ReplValidationRules        NVARCHAR(10)   = '', 
            @n_CaseCnt                    INT,
            @c_Lottable01                 NVARCHAR(18),    --NJOW01
            @c_Lottable02                 NVARCHAR(18),    
            @c_Lottable03                 NVARCHAR(18),    
            @d_Lottable04                 DATETIME,    
            @d_Lottable05                 DATETIME,    
            @c_Lottable06                 NVARCHAR(30),    
            @c_Lottable07                 NVARCHAR(30),    
            @c_Lottable08                 NVARCHAR(30),    
            @c_Lottable09                 NVARCHAR(30),    
            @c_Lottable10                 NVARCHAR(30),    
            @c_Lottable11                 NVARCHAR(30),    
            @c_Lottable12                 NVARCHAR(30),    
            @d_Lottable13                 DATETIME,    
            @d_Lottable14                 DATETIME,    
            @d_Lottable15                 DATETIME,             
            @c_LottableList               NVARCHAR(1000)  
  
  DECLARE @t_ExcludeLot TABLE (LOT NVARCHAR(10))
  
  IF ISNULL(@c_LoadKey,'') <> ''
  BEGIN
  	 SELECT @c_Facility = Facility
     FROM LoadPlan AS lp WITH(NOLOCK)
     WHERE lp.LoadKey=@c_LoadKey
  	  
     DECLARE CUR_PreAllocateSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT papd.OrderKey, papd.Storerkey, papd.Sku, papd.Lot, papd.PreAllocatePickDetailKey, papd.UOM, papd.Qty, papd.Packkey, papd.OrderLineNumber,
            ord.Lottable01, ord.Lottable02, ord.Lottable03, ord.Lottable04, ord.Lottable05, ord.Lottable06, ord.Lottable07, ord.Lottable08, ord.Lottable09, --NJOW01
            ord.Lottable10, ord.Lottable11, ord.Lottable12, ord.Lottable13, ord.Lottable14, ord.Lottable15
     FROM PreAllocatePickDetail AS papd WITH(NOLOCK) 
     JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = papd.OrderKey
     JOIN Orderdetail AS ord WITH(NOLOCK) ON papd.Orderkey = ord.Orderkey AND papd.OrderLineNumber = ord.OrderLineNumber
     WHERE papd.UOM = '2'
     AND  lpd.LoadKey = @c_LoadKey 
     AND  EXISTS(SELECT 1 
                 FROM SKUxLOC AS sl WITH(NOLOCK) 
                 JOIN LOC AS l WITH(NOLOCK) ON l.Loc = sl.Loc 
                 WHERE sl.StorerKey = papd.Storerkey 
                 AND sl.Sku = papd.Sku 
                 AND (sl.LocationType = 'CASE' OR L.LocationType = 'CASE')
                 AND l.Facility = @c_Facility 
                 AND sl.Qty - sl.QtyAllocated - sl.QtyPicked > 0)  	
  END
  ELSE IF ISNULL(@c_OrderKey,'') <> ''
  BEGIN
     SELECT @c_Facility = Facility
     FROM ORDERS WITH (NOLOCK)
     WHERE OrderKey = @c_OrderKey
       	
     DECLARE CUR_PreAllocateSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT papd.OrderKey, papd.Storerkey, papd.Sku, papd.Lot, papd.PreAllocatePickDetailKey, papd.UOM, papd.Qty, papd.Packkey, papd.OrderLineNumber, 
            ord.Lottable01, ord.Lottable02, ord.Lottable03, ord.Lottable04, ord.Lottable05, ord.Lottable06, ord.Lottable07, ord.Lottable08, ord.Lottable09, --NJOW01
            ord.Lottable10, ord.Lottable11, ord.Lottable12, ord.Lottable13, ord.Lottable14, ord.Lottable15
     FROM PreAllocatePickDetail AS papd WITH(NOLOCK)
     JOIN Orderdetail AS ord WITH(NOLOCK) ON papd.Orderkey = ord.Orderkey AND papd.OrderLineNumber = ord.OrderLineNumber
     WHERE papd.UOM = '2'
     AND   papd.OrderKey = @c_OrderKey 
     AND   EXISTS(SELECT 1 
                  FROM SKUxLOC AS sl WITH(NOLOCK) 
                  JOIN LOC AS l WITH(NOLOCK) ON l.Loc = sl.Loc 
                  WHERE sl.StorerKey = papd.Storerkey 
                  AND sl.Sku = papd.Sku 
                  AND (sl.LocationType = 'CASE' OR L.LocationType = 'CASE')
                  AND l.Facility = @c_Facility 
                  AND sl.Qty - sl.QtyAllocated - sl.QtyPicked > 0)
  	 
  END 
  ELSE 
  BEGIN
  	  RETURN 
  END 	
                     
  OPEN CUR_PreAllocateSKU
  FETCH NEXT FROM CUR_PreAllocateSKU INTO @c_OrderKey, @c_StorerKey, @c_SKU, @c_LOT, @c_PreAllocatePickDetailKey, @c_UOM, 
                  @n_QtyPreallocated, @c_Packkey, @c_OrderLineNumber, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                  @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                  @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

  --NJOW01
  SET @c_LottableList = ''  
  SELECT @c_LottableList = @c_LottableList + code + ' '   
  FROM CODELKUP(NOLOCK)   
  WHERE listname = 'AllocLot'  
  AND Storerkey = @c_Storerkey  
                  
  WHILE @@FETCH_STATUS = 0 
  BEGIN	   
  	  WHILE @n_QtyPreallocated > 0 
  	  BEGIN
  	  	 SET @n_CaseCnt = 0 
  	  	 SELECT @n_CaseCnt = p.CaseCnt 
  	  	 FROM PACK AS p WITH(NOLOCK)
  	  	 WHERE p.PackKey = @c_Packkey
  	  	 
  	  	 SET @n_QtyAvailable = 0 
         
  	     SELECT TOP 1 
  	          @c_SuggestLOT = LOTxLOCxID.Lot,
  	          @c_LOC = LOTxLOCxID.LOC, 
  	          @c_ID = LOTxLOCxID.ID,
              @n_QtyAvailable = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) 
         FROM LOTxLOCxID (NOLOCK)         
         JOIN LOT (NOLOCK) ON LOT.Lot = LOTxLOCxID.Lot 
         JOIN LOTATTRIBUTE AS LA WITH(NOLOCK) ON LA.Lot = LOT.Lot  
         JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC
         JOIN SKUxLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUxLOC.Storerkey AND LOTxLOCxID.Sku = SKUxLOC.Sku
                                 AND LOTxLOCxID.Loc = SKUxLOC.Loc
         JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
         WHERE LOTxLOCxID.StorerKey = @c_StorerKey
         AND LOTxLOCxID.Sku = @c_SKU
         AND LOC.Facility = @c_Facility
         AND LOC.Locationflag <>'HOLD'
         AND LOC.Locationflag <> 'DAMAGE'
         AND LOC.Status <> 'HOLD'
         AND ID.Status = 'OK'
         AND (SKUxLOC.Locationtype = 'CASE' OR LOC.LocationType = 'CASE') 
         AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) >= @n_CaseCnt 
  	  	 AND (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QtyPreAllocated) >= @n_CaseCnt
  	  	 AND LA.Lottable01 = CASE WHEN CHARINDEX('LOTTABLE01', @c_LottableList) > 0  THEN @c_Lottable01 ELSE LA.Lottable01 END --NJOW01
  	  	 AND LA.Lottable02 = CASE WHEN CHARINDEX('LOTTABLE02', @c_LottableList) > 0  THEN @c_Lottable02 ELSE LA.Lottable02 END 
  	  	 AND LA.Lottable03 = CASE WHEN CHARINDEX('LOTTABLE03', @c_LottableList) > 0  THEN @c_Lottable03 ELSE LA.Lottable03 END 
  	  	 AND LA.Lottable06 = CASE WHEN CHARINDEX('LOTTABLE06', @c_LottableList) > 0  THEN @c_Lottable06 ELSE LA.Lottable06 END 
  	  	 AND LA.Lottable07 = CASE WHEN CHARINDEX('LOTTABLE07', @c_LottableList) > 0  THEN @c_Lottable07 ELSE LA.Lottable07 END 
  	  	 AND LA.Lottable08 = CASE WHEN CHARINDEX('LOTTABLE08', @c_LottableList) > 0  THEN @c_Lottable08 ELSE LA.Lottable08 END 
  	  	 AND LA.Lottable09 = CASE WHEN CHARINDEX('LOTTABLE09', @c_LottableList) > 0  THEN @c_Lottable09 ELSE LA.Lottable09 END 
  	  	 AND LA.Lottable10 = CASE WHEN CHARINDEX('LOTTABLE10', @c_LottableList) > 0  THEN @c_Lottable10 ELSE LA.Lottable10 END 
  	  	 AND LA.Lottable11 = CASE WHEN CHARINDEX('LOTTABLE11', @c_LottableList) > 0  THEN @c_Lottable11 ELSE LA.Lottable11 END 
  	  	 AND LA.Lottable12 = CASE WHEN CHARINDEX('LOTTABLE12', @c_LottableList) > 0  THEN @c_Lottable12 ELSE LA.Lottable12 END 
  	  	 AND NOT EXISTS(SELECT 1 FROM @t_ExcludeLot EL WHERE EL.LOT =  LOTxLOCxID.Lot)   
                 
  	     IF @n_QtyAvailable = 0
  	  	     BREAK 
         
         SELECT @c_ReplValidationRules = SC.sValue
         FROM STORERCONFIG SC (NOLOCK)
         JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
         WHERE SC.StorerKey = @c_StorerKey
         AND SC.Configkey = 'ReplenValidation'
         
         IF ISNULL(@c_ReplValidationRules,'') <> ''
         BEGIN
            EXEC isp_REPL_ExtendedValidation @c_fromlot = @c_SuggestLOT
                                          ,  @c_FromLOC = @c_LOC
                                          ,  @c_fromid  = @c_ID
                                          ,  @c_ReplValidationRules=@c_ReplValidationRules
                                          ,  @b_Success = @b_Success OUTPUT
                                          ,  @c_ErrMsg  = @c_ErrMsg OUTPUT
            IF @b_Success = 0
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM @t_ExcludeLot WHERE LOT = @c_SuggestLOT)
               BEGIN
               	INSERT INTO @t_ExcludeLot (LOT) VALUES (@c_SuggestLOT) 
               END 
               CONTINUE  
            END
         END
         
         SELECT @n_QtyAvailable = FLOOR(@n_QtyAvailable/p.CaseCnt) * p.CaseCnt 
  	     FROM PACK AS p WITH(NOLOCK)
  	     WHERE p.PackKey = @c_Packkey
         
  	  	  IF @n_QtyAvailable > 0
  	  	  BEGIN
            SET @n_QtyToInsert = 0       	
            IF @n_QtyAvailable < @n_QtyPreallocated 
               SET @n_QtyToInsert = @n_QtyAvailable  
            ELSE 
        	     SET @n_QtyToInsert = @n_QtyPreallocated  	   		
  	  	  END
  	  	  ELSE 
  	  	  BEGIN
  	  	  	 SET @n_QtyToInsert = 0 
  	  	  END               
         
         IF @n_QtyToInsert > 0 
         BEGIN
            SELECT @b_success = 0  
            EXECUTE   nspg_getkey  
            'PickDetailKey'  
            , 10  
            , @c_PickDetailKey OUTPUT  
            , @b_Success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT
         
            IF @b_success = 1  
            BEGIN
               PRINT 'OrderKey: ' + @c_OrderKey
            	 PRINT 'OrderLineNumber: ' + @c_OrderLineNumber
            	
         	     UPDATE PreAllocatePickDetail
         	     SET Qty = Qty - @n_QtyToInsert         	      
         	     WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey
         
         	
               INSERT PICKDETAIL (PickDetailKey,PickHeaderKey,OrderKey,OrderLineNumber,  
                                  Lot,Storerkey,Sku,Qty, Loc, Id, UOMQty,  
                                  UOM, CaseID, PackKey, CartonGroup, DoReplenish, replenishzone,  
                                  docartonize,Trafficcop,PickMethod, Channel_ID, DropID)    
               VALUES ( @c_PickDetailKey, '', @c_Orderkey, @c_OrderLineNumber,  
                        @c_SuggestLOT, @c_StorerKey, @c_SKU, @n_QtyToInsert, @c_Loc, @c_ID, @n_QtyToInsert,  
                        @c_UOM, '', @c_PackKey, '', 'N', '', 'N', 'U', '1', '', '')                       
                           
               SET  @n_QtyPreallocated = @n_QtyPreallocated - @n_QtyToInsert                                         	  
            END  -- IF @b_success = 1       	         	
         END	-- IF @n_QtyToInsert > 0   
  	  END
  	   
  	  FETCH NEXT FROM CUR_PreAllocateSKU INTO @c_OrderKey, @c_StorerKey, @c_SKU, @c_LOT, @c_PreAllocatePickDetailKey, @c_UOM, 
                      @n_QtyPreallocated, @c_Packkey, @c_OrderLineNumber, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                      @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11,
                      @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
  END
  CLOSE CUR_PreAllocateSKU
  DEALLOCATE CUR_PreAllocateSKU 
     
EXIT_SP:  
      
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPALCULP'      
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