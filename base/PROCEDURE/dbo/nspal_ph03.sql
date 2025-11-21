SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspAL_PH03                                         */    
/* Creation Date: 08-AUG-2018                                           */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-5937 PH JTI allocation by FEFO                          */
/*          SkipPreallocation = '1'                                     */
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
/************************************************************************/    
CREATE PROC [dbo].[nspAL_PH03]        
   @c_Orderkey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,    
   @c_Lottable06 NVARCHAR(30),    
   @c_Lottable07 NVARCHAR(30),    
   @c_Lottable08 NVARCHAR(30),    
   @c_Lottable09 NVARCHAR(30),    
   @c_Lottable10 NVARCHAR(30),    
   @c_Lottable11 NVARCHAR(30),    
   @c_Lottable12 NVARCHAR(30),    
   @d_Lottable13 DATETIME,    
   @d_Lottable14 DATETIME,    
   @d_Lottable15 DATETIME,    
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @n_starttcnt   INT,
           @n_continue    INT,        
           @b_Success     INT,   
           @n_Err         INT,
           @c_ErrMsg      NVARCHAR(250),
           @c_SQL         NVARCHAR(MAX),    
           @c_SQLParm     NVARCHAR(MAX)    
          
   DECLARE @n_QtyAvailable     INT,  
           @c_LOT              NVARCHAR(10),
           @c_LOC              NVARCHAR(10),
           @c_ID               NVARCHAR(18), 
           @c_OtherValue       NVARCHAR(20),
           @n_QtyToTake        INT,           
           @c_OrderLineNumber  NVARCHAR(5),
           @c_Packkey          NVARCHAR(10),
           @c_TolType          NVARCHAR(30),
           @c_TolValue         NVARCHAR(10),
           @n_TolValue         INT,
           @n_TolQty           INT,
           @n_IncreaseQty      INT,
           @c_NewPickdetailKey NVARCHAR(10)

   SELECT @n_starttcnt = @@TRANCOUNT , @n_continue = 1
 
   SET @n_QtyAvailable = 0          
   SET @c_OtherValue = '1' 
   SET @n_QtyToTake = 0   
   
   SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
   SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
   
   SELECT TOP 1 @c_TolType = CL.Code, 
                @c_TolValue = CL.Short
   FROM STORERCONFIG SC (NOLOCK)
   JOIN CODELKUP CL (NOLOCK) ON SC.Storerkey = CL.Storerkey AND SC.Svalue = CL.Code AND CL.Listname = 'ALLOCTOL'
   AND SC.Storerkey = @c_Storerkey
   AND SC.Configkey = 'ALLOC_TOLERANCE'
   
   IF ISNULL(@c_TolType,'') IN ('PCT','QTY')
   BEGIN
   	  IF ISNUMERIC(@c_TolValue) = 1
   	     SET @n_TolValue = CAST(@c_TolValue AS INT)
   	  ELSE
   	     SET @n_TolValue = 0
   	  
   	  IF @c_TolType = 'PCT' 
   	     SET @n_TolQty = 0 --to be calculated based on id
   	  ELSE
   	     SET @n_TolQty = @n_TolValue   
   	     
   	  IF @@TRANCOUNT = 0
   	     BEGIN TRAN   
   END
      
   SET @c_SQL = N'   
      DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen),
             SKU.Packkey
      FROM LOTxLOCxID (NOLOCK)
      JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE LOC.LocationFlag <> ''HOLD''
      AND LOC.LocationFlag <> ''DAMAGE''
      AND LOC.Status <> ''HOLD''
      AND LOT.Status <> ''HOLD''
      AND ID.Status <> ''HOLD''
      AND LOC.Facility = @c_Facility
      AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU ' + 
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11 ' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12 ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
      CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
      ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) >= @n_UOMBase ' +
      ' ORDER BY LA.Lottable04, CASE WHEN (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) % ' + RTRIM(CAST(@n_QtyLeftToFulfill AS NVARCHAR)) + ' = 0 THEN 1 ELSE 2 END, LOC.LogicalLocation, LOC.LOC '

   SET @c_SQLParm =  N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), @c_SKU NVARCHAR(20), @n_QtyLeftToFulfill INT, @n_UOMBase INT, ' +
                      '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                      '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                      '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 

   EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Facility, @c_StorerKey, @c_SKU, @n_QtyLeftToFulfill, @n_UOMBase, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                      @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                      @d_Lottable13, @d_Lottable14, @d_Lottable15

   SET @c_SQL = ''

   OPEN CURSOR_AVAILABLE                    
   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_Packkey   
          
   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0) AND @n_continue IN(1,2)          
   BEGIN                        	                  
      IF @n_QtyLeftToFulfill >= @n_QtyAvailable
      BEGIN
         SET @n_QtyToTake = @n_QtyAvailable
      END
      ELSE
      BEGIN
      	 IF ISNULL(@c_TolType,'') IN ('PCT','QTY')
      	 BEGIN
            IF @c_TolType = 'PCT'
   	           SET @n_TolQty = (@n_TolValue * @n_QtyAvailable) / 100.00  --calculate tolerance qty by percentage      	 	
      	 	
      	    IF @n_QtyLeftToFulfill < @n_TolQty  --below tolerance qty no need proceed to take partial carton (one id one carton)
      	    BEGIN
      	    	 SET @n_QtyToTake = 0
      	    	 SET @n_QtyLeftToFulfill = 0
      	    END
      	    ELSE
      	    BEGIN
      	    	 --above tolerance qty have to increase order line qty to take new full carton (not allow take partial carton)
      	    	 SET @n_IncreaseQty = @n_QtyAvailable - @n_QtyLeftToFulfill 
      	    	 
      	    	 UPDATE ORDERDETAIL WITH (ROWLOCK)
      	    	 SET userdefine01 = CAST(OpenQty AS NVARCHAR),
      	    	     OriginalQty = OriginalQty + @n_IncreaseQty, 
      	    	     OpenQty = OpenQty + @n_IncreaseQty
      	    	 WHERE Orderkey = @c_Orderkey
      	    	 AND OrderLineNumber = @c_OrderLineNumber    
               
               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Table Failed. (nspAL_PH03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END          
               
               EXECUTE nspg_GetKey      
                  'PICKDETAILKEY',      
                  10,      
                  @c_NewPickdetailKey OUTPUT,         
                  @b_success OUTPUT,      
                  @n_err OUTPUT,      
                  @c_errmsg OUTPUT      
               
               IF NOT @b_success = 1      
               BEGIN
                  SELECT @n_continue = 3      
               END                  
               
       	       INSERT INTO PICKDETAIL
               	 (
               	 	PickDetailKey,          CaseID,            	 PickHeaderKey,
               	 	OrderKey,               OrderLineNumber,     Lot,
               	 	Storerkey,              Sku,            	 	 AltSku,
               	 	UOM,           		      UOMQty,            	 Qty,
               	 	QtyMoved,               [Status],            DropID,
               	 	Loc,            		    ID,            	     PackKey,
               	 	UpdateSource,           CartonGroup,         CartonType,
               	 	ToLoc,            	    DoReplenish,         ReplenishZone,
               	 	DoCartonize,            PickMethod,          WaveKey,
               	 	ShipFlag,               PickSlipNo,          TaskDetailKey,
               	 	TaskManagerReasonKey,   Notes,            	MoveRefKey    )
               	 VALUES
               	 (@c_NewPickDetailKey,    '',            		'',
               	 	@c_OrderKey,         @c_OrderLineNumber,  @c_LOT,
               	 	@c_StorerKey,        @c_SKU,           	'',
               	 	@c_UOM,             	@n_IncreaseQty,     @n_IncreaseQty,
               	 	0,            		   '0',            		'',
               	 	@c_LOC,              	@c_ID,            	@c_PackKey,
               	 	'0',            		   'STD',            		'',
               	 	'',            		   'N',            		'',
               	 	'N',            		  '3',            		'',
               	 	'N',            		  '',            		'',
               	 	'',            		    '',            		'' )      
               
               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (nspAL_PH03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                              	    	
      	    END      	 	
      	 END
      	 ELSE
      	    SET @n_QtyToTake = @n_QtyLeftToFulfill
      END      	 
      
      IF @n_QtyToTake > 0
      BEGIN           	        	       	
         IF ISNULL(@c_SQL,'') = ''
         BEGIN
            SET @c_SQL = N'   
                  DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR   
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + N'  
                  UNION ALL
                  SELECT '''  + @c_LOT + ''', ''' + @c_LOC + ''', ''' + @c_ID + ''', ''' + CAST(@n_QtyToTake AS NVARCHAR(10)) + ''', ''' + @c_OtherValue + '''
                  '
         END
         
         SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake       
      END
            
      FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable, @c_Packkey  
   END -- END WHILE FOR CURSOR_AVAILABLE          

   EXIT_SP:

   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLE') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_AVAILABLE          
      DEALLOCATE CURSOR_AVAILABLE          
   END    
   
   IF @n_continue IN(1,2) AND ISNULL(@c_SQL,'') <> '' 
   BEGIN
      EXEC sp_ExecuteSQL @c_SQL
   END
   ELSE
   BEGIN
      DECLARE  CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 0 NULL, NULL, NULL, NULL, NULL    
   END

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "nspAL_PH03"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END           
END -- Procedure

GO