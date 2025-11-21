SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispReplenishmentReverse]
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE
 @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err        int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2       int              -- For Additional Error Detection
 ,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue   int                 
 ,         @n_starttcnt  int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int                  
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBOA1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
    DECLARE	@c_storerkey NVARCHAR(15),
 				@c_sku	 NVARCHAR(20),
 				@c_lot	 NVARCHAR(10),
 				@c_id		   NVARCHAR(18),
 				@c_loc	 NVARCHAR(10),
 				@c_toloc	   NVARCHAR(10),
 				@n_qty		int,
 				@c_packkey NVARCHAR(10),
 				@c_uom	 NVARCHAR(10),
 				@c_ReplenishmentKey NVARCHAR(10),
 				@n_InvQty       int,
 				@c_ToId         NVARCHAR(18)
     SELECT @c_ReplenishmentKey = SPACE(10)
     WHILE 1=1
     BEGIN   
        SET ROWCOUNT 1
        SELECT @c_ReplenishmentKey = Replenishment.ReplenishmentKey, 
 				@c_storerkey = Replenishment.StorerKey,
 				@c_sku = Replenishment.Sku,
 				@c_lot = Replenishment.Lot,
 				@c_id  = ITRN.ToId,
 				@c_ToId = ITRN.FromID,
 				@c_loc = ITRN.ToLoc,
 				@c_toloc = Replenishment.FromLoc,
 				@n_qty = ITRN.Qty - Replenishment.Qty,
 				@c_packkey = Replenishment.Packkey,
 				@c_uom = Replenishment.Uom
          FROM itrn (nolock), Replenishment (nolock)
 			where ReplenishmentKey > @c_ReplenishmentKey
          and SourceType = 'nsp_replenishment'
 			and Replenishment.replenishmentkey = itrn.sourcekey
 			and confirmed = 'Y'
 			and ITRN.Qty > Replenishment.Qty
          ORDER BY Replenishment.ReplenishmentKey
          IF @@ROWCOUNT = 0
          BEGIN
             BREAK
          END
          SET ROWCOUNT 0
          EXECUTE nspItrnAddMove
 			NULL,
 			@c_storerkey,
 			@c_sku,
 			@c_lot,
 			@c_loc,
 			@c_id,
 			@c_toloc,
 			@c_ToID,
 			"",
 			"",
			"",
 			"",
 			NULL,
 			NULL,
 			0,
 			0,
 			@n_qty,
 			0,
 			0,
 			0,
 			0,
 			0,
 			0,
 			@c_ReplenishmentKey,
 			'ispReplenishmentReverse',
 			@c_packkey,
 			@c_uom,
 			1,
 			NULL,
 			"",
 			@b_Success  OUTPUT,
 			@n_err      OUTPUT,
 			@c_errmsg   OUTPUT
    END -- While
 END
      /* #INCLUDE <TRMBOHA2.SQL> */
 IF @n_continue = 3  -- Error Occured - Process And Return
 BEGIN
    IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrReplenishmentUpdate"
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
 END


GO