SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspInventoryHoldExpired_02 							  	*/
/* Creation Date: 04-Jun-2007                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
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


CREATE PROC [dbo].[nspInventoryHoldExpired]
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE   @n_continue	int
 ,	       @n_starttcnt	int -- bring forward tran count
 ,		    @b_debug 	int
 SELECT @n_continue = 1, @b_debug = 0
 SELECT @n_starttcnt = @@TRANCOUNT
 -- FBR049 IDSHK 16/08/2001 - Hold All the Lot when lottable04 was expired
 CREATE TABLE #LotByBatch
    ( LOT NVARCHAR(10),
      InventoryHoldKey NVARCHAR(10) )
 -- check is the lottables already been hold before?
 -- insert those not been hold yet in inventory hold 
 INSERT INTO	#LotByBatch (LOT, InventoryHoldKey)
 	SELECT 	LOTATTRIBUTE.LOT, '' InventoryHoldKey
 	FROM	   LOTATTRIBUTE(NOLOCK)
    JOIN SKU (NOLOCK) ON (LOTATTRIBUTE.StorerKey = SKU.StorerKey AND LOTATTRIBUTE.SKU = SKU.SKU )
    JOIN LOTxLOCxID (NOLOCK) ON (LOTATTRIBUTE.lot = LOTxLOCxID.lot AND LOTxLOCxID.qty > 0) -- SOS 10969
 	WHERE	LotAttribute.Lottable04 <= CAST( CONVERT( NVARCHAR(20), GetDate(), 106) AS Datetime ) 
    AND   LotAttribute.Lottable04 IS NOT NULL 
    AND   NOT EXISTS (SELECT LOT FROM InventoryHold (NOLOCK) WHERE Inventoryhold.Lot = LOTATTRIBUTE.Lot AND InventoryHold.HOLD = '1') -- Changed by June 3.May.02
    AND   SKU.Lottable04Label = 'EXP_DATE'
    	 
 if @b_debug = 1 
 begin
 	select * from #LotByBatch
 end
 IF NOT EXISTS( SELECT COUNT(1) FROM #LotByBatch WHERE LOT <> '' OR LOT IS NOT NULL)
 BEGIN
    DECLARE @b_Success int,
            @n_err     int,
            @c_errmsg  NVARCHAR(225),
            @c_Status  NVARCHAR(1)
 	SELECT @n_continue = 3
 	SELECT @b_Success = 0		
 	SELECT @n_err = 99999
 	SELECT @c_errmsg = 'No Lot found for the batch. [nspInventoryHoldWrapper]'
 END
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
 	DECLARE @lot NVARCHAR(10)
    SELECT @lot = SPACE(10)
 	WHILE 1=1
 	BEGIN
       if @b_debug = 1 
       begin
       	select '@lot: ' + @lot
       end
 		
      SELECT TOP 1 @lot = lot 
       FROM #LotByBatch 
       WHERE LOT > @LOT
       ORDER BY LOT
       IF @@ROWCOUNT = 0
          BREAK

       -- Start - Added by June 3.May.02
       IF EXISTS (SELECT 1 FROM InventoryHold (NOLOCK) WHERE lot = @lot) 
       BEGIN
          UPDATE Inventoryhold WITH (ROWLOCK)
          SET STATUS = '44' 
          WHERE lot = @lot
          SELECT @n_err = @@ERROR
          IF @n_err > 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=78400   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On InventoryHold.(nspInventoryHoldExpired)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          END
       END -- End - Added by June 3.May.02
 		EXECUTE nspInventoryHold @lot
 			,              ''
 			,              ''
 			,              '44'
 			,              '1'
 			,              @b_Success OUTPUT
 			,              @n_err OUTPUT
 			,              @c_errmsg OUTPUT
 				
 		IF @b_Success = 0 
 		BEGIN
 			SELECT @n_continue = 3
 		END
 	END
    SET ROWCOUNT 0
 END
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