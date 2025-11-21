SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspInventoryHoldExpired_02 							  	*/
/* Creation Date: 04-Jun-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#77327 - Auto HOLD LOT for Inventory Less or Equal then  */
/*                      SKU.SUSR2 (MinOutgoingDays)              			*/
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25Oct2016    TLTING   1.1  Perfromance tune                          */
/************************************************************************/


CREATE PROC [dbo].[nspInventoryHoldExpired_02]
            @c_Storerkey NVARCHAR(15)
 AS
 BEGIN
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF	
SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE   @n_continue	int
 ,	        @n_starttcnt	int -- bring forward tran count
 ,		     @b_debug 	   int
 
 DECLARE   @c_lotitf     NVARCHAR(1)
          ,@c_Flag       NVARCHAR(1)
          ,@c_InvHoldKey NVARCHAR(10)
          ,@c_StreamCode NVARCHAR(10)
          ,@n_IDCnt      int
          ,@n_LocCnt     int

 SELECT @n_continue = 1, @b_debug = 0
 SELECT @n_starttcnt = @@TRANCOUNT

 -- Hold All the Lot when lottable04 was expired
 CREATE TABLE #LotByBatch02
    ( LOT NVARCHAR(10),
      InventoryHoldKey NVARCHAR(10),
      HOLD NVARCHAR(10) )

 -- check is the lottables already been hold before?
 -- insert those not been hold yet in inventory hold 
 INSERT INTO #LotByBatch02 ( LOT, InventoryHoldKey, HOLD )
 	SELECT DISTINCT LOTATTRIBUTE.LOT, '' InventoryHoldKey, '0' HOLD
 	FROM	 LOTATTRIBUTE WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON (LOTATTRIBUTE.StorerKey = SKU.StorerKey AND LOTATTRIBUTE.SKU = SKU.SKU )
   JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTATTRIBUTE.lot = LOTxLOCxID.lot AND 
                                     LOTATTRIBUTE.SKU = LOTxLOCxID.SKU AND 
                                     LOTATTRIBUTE.Storerkey = LOTxLOCxID.Storerkey AND 
                                     LOTxLOCxID.qty > 0)
   JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LOTxLOCxID.LOC)
   JOIN ID  WITH (NOLOCK) ON (ID.ID = LOTxLOCxID.ID)
   WHERE (LOTATTRIBUTE.Lottable04 - CAST(SKU.SUSR2 as int )) <= CONVERT(Char(20), Getdate(), 106)
    AND  LOTATTRIBUTE.Lottable04 IS NOT NULL 
    AND  NOT EXISTS (SELECT LOT FROM InventoryHold (NOLOCK) WHERE Inventoryhold.Lot = LOTATTRIBUTE.Lot AND InventoryHold.HOLD = '1')
    AND  SKU.Lottable04Label = 'EXP-DATE'
    AND  LOTATTRIBUTE.Storerkey = dbo.fnc_RTrim(@c_Storerkey)
    AND  ISNUMERIC(SKU.SUSR2) > 0
    AND  SKU.SUSR4 = 'TW01'
    AND  LOC.Status <> 'HOLD'
    AND  LOC.LocationFlag <> 'HOLD'
    AND  ID.Status <> 'HOLD'
   UNION ALL
 	SELECT DISTINCT LOTATTRIBUTE.LOT, '' InventoryHoldKey, '1' HOLD
 	FROM	 LOTATTRIBUTE WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON (LOTATTRIBUTE.StorerKey = SKU.StorerKey AND LOTATTRIBUTE.SKU = SKU.SKU )
   JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTATTRIBUTE.lot = LOTxLOCxID.lot AND 
                                     LOTATTRIBUTE.SKU = LOTxLOCxID.SKU AND 
                                     LOTATTRIBUTE.Storerkey = LOTxLOCxID.Storerkey AND 
                                     LOTxLOCxID.qty > 0)
   JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LOTxLOCxID.LOC)
   JOIN ID  WITH (NOLOCK) ON (ID.ID = LOTxLOCxID.ID)
   WHERE (LOTATTRIBUTE.Lottable04 - CAST(SKU.SUSR2 as int )) <= CONVERT(Char(20), Getdate(), 106)
    AND  LOTATTRIBUTE.Lottable04 IS NOT NULL 
    AND  EXISTS (SELECT LOT FROM InventoryHold (NOLOCK) WHERE Inventoryhold.Lot = LOTATTRIBUTE.Lot AND InventoryHold.HOLD = '1' AND Status <> 'LTS')
    AND  SKU.Lottable04Label = 'EXP-DATE'
    AND  LOTATTRIBUTE.Storerkey = dbo.fnc_RTrim(@c_Storerkey)
    AND  ISNUMERIC(SKU.SUSR2) > 0
    AND  SKU.SUSR4 = 'TW01'
    AND  LOC.Status <> 'HOLD'
    AND  LOC.LocationFlag <> 'HOLD'
    AND  ID.Status <> 'HOLD'
    	 
 IF @b_debug = 1 
 BEGIN
 	SELECT * FROM #LotByBatch02
 END
 IF NOT EXISTS( SELECT COUNT(1) FROM #LotByBatch02 WHERE LOT <> '' OR LOT IS NOT NULL)
 BEGIN
    DECLARE @b_Success int,
            @n_err     int,
            @c_errmsg  NVARCHAR(225),
            @c_Status  NVARCHAR(1)
 	SELECT @n_continue = 3
 	SELECT @b_Success = 0		
 	SELECT @n_err = 99999
 	SELECT @c_errmsg = 'No Lot found for the batch. [nspInventoryHoldExpired_02]'
 END

 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 	DECLARE @lot NVARCHAR(10), @chold NVARCHAR(10)
   SELECT @lot = SPACE(10)


   DECLARE C_HOLD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	   SELECT LOT, HOLD
	   FROM #LotByBatch02 
      ORDER BY LOT
	   
	OPEN C_HOLD 
	
	FETCH NEXT FROM C_HOLD INTO @lot, @chold
 	WHILE @@FETCH_STATUS <> -1 
 	BEGIN
       IF @b_debug = 1 
       BEGIN
       	SELECT '@lot: ' + @lot 
       	SELECT '@chold: ' + @chold 
       END
	      

      IF dbo.fnc_RTrim(@chold) = '1'
      BEGIN
          UPDATE Inventoryhold WITH (ROWLOCK)
          SET STATUS = 'LTS'
          WHERE lot = @lot
          AND   Hold = @chold
          SELECT @n_err = @@ERROR
          IF @n_err > 0
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=78400   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On InventoryHold.(nspInventoryHoldExpired_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_RTrim(@c_errmsg) + ' ) '
          END
      END
      ELSE 
      BEGIN
        IF EXISTS (SELECT 1 FROM InventoryHold WITH (NOLOCK) WHERE LOT = @lot AND HOLD = dbo.fnc_RTrim(@chold)) 
        BEGIN
          UPDATE Inventoryhold WITH (ROWLOCK)
          SET STATUS = 'LTS'
          WHERE lot = @lot
          AND   Hold = @chold
          SELECT @n_err = @@ERROR
          IF @n_err > 0
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=78400   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On InventoryHold.(nspInventoryHoldExpired_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_RTrim(@c_errmsg) + ' ) '
          END
        END
        
   	   EXECUTE nspInventoryHold @lot
	 			,              ''
	 			,              ''
	 			,              'LTS'
	 			,              '1'
	 			,              @b_Success OUTPUT
	 			,              @n_err OUTPUT
	 			,              @c_errmsg OUTPUT
	 				
	 		IF @b_Success = 0 
	 		BEGIN
	 			SELECT @n_continue = 3
	 		END
	      ELSE
         BEGIN
	    		SELECT @b_Success = 0
	   		SELECT @c_lotitf = '0'
	
	         EXECUTE nspGetRight 
				NULL,				-- Facility
				@c_StorerKey,	-- Storer
				NULL,				-- Sku
				'INVHOLDLOG',	-- ConfigKey
				@b_success		OUTPUT, 
				@c_lotitf   	OUTPUT, 
				@n_err			OUTPUT, 
				@c_errmsg		OUTPUT
	   
	   	   IF @b_Success <> 1
	   	   BEGIN
	            SELECT @n_continue = 3
	            SELECT @n_err = 60981
	   	      SELECT @c_errmsg = 'nspInventoryHoldExpired_02 :' + dbo.fnc_RTrim(@c_errmsg) 
	   	   END
	
	         IF @c_lotitf = '1'
	         BEGIN
	            BEGIN TRAN
	          
					SELECT @n_IDCnt = 0,  @n_LocCnt = 0
	
	            SELECT @n_IDCnt = COUNT(1)
	            FROM TRANSMITLOG3 T3 (NOLOCK)
	            JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
	            JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.ID = IH.ID AND 
	                                             LLI.Storerkey = @c_StorerKey AND 
	                                             LLI.LOT = @lot)
	            WHERE T3.Tablename = 'INVHOLDLOG-ID'
	            AND   T3.Transmitflag = '0'
	            AND   T3.Key2 = 'HOLD'
	
	            IF @n_IDCnt = 0
	            BEGIN
	               SELECT @n_LocCnt = COUNT(1)
	               FROM TRANSMITLOG3 T3 (NOLOCK)
	               JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
	               JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = IH.LOC AND 
	                                                LLI.Storerkey = @c_StorerKey AND 
	                                                LLI.LOT = @lot)
	               WHERE T3.Tablename = 'INVHOLDLOG-LOC'
	               AND   T3.Transmitflag = '0'
	               AND   T3.Key2 = 'HOLD'
	            END
	
	            IF (@n_IDCnt = 0) AND (@n_LocCnt = 0)
	            BEGIN

                  SELECT @c_InvHoldKey = InventoryholdKey
                  FROM InventoryHold WITH (NOLOCK)
                  WHERE LOT = @lot
                  AND   Status = 'LTS'
                  AND   HOLD = '1'
                   
				      SELECT @b_success = 1                                                             
				         EXEC ispGenTransmitLog3 'INVHOLDLOG-LOT', @c_InvHoldKey, 'HOLD', @c_StorerKey, ''
			         , @b_success OUTPUT
			         , @n_err OUTPUT
			         , @c_errmsg OUTPUT
	
	               IF @b_success <> 1
			         BEGIN
			            SELECT @n_continue = 3
			            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
			            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (nspInventoryHoldExpired_02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_RTrim(@c_errmsg) + ' ) '
			         END
	            END
			      COMMIT TRAN
             END --  @c_lotitf = '1'
            END -- ELSE if @b_success = 1
          END --  if Exits Hold <> 1

    FETCH NEXT FROM C_HOLD INTO @lot, @chold
   END
   CLOSE C_HOLD
   DEALLOCATE C_HOLD 
 END -- Continue = 1

 IF @n_continue = 3
 BEGIN
 	IF (@@TRANCOUNT = 1) AND (@@TRANCOUNT > @n_starttcnt)
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
 END --MAIN

GO