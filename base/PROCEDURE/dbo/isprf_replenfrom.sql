SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[ispRF_ReplenFrom] 
    @c_BatchNo   NVARCHAR(10)
   ,@c_LOC       NVARCHAR(10)
   ,@c_UCCNo1    NVARCHAR(20) = NULL 
   ,@c_UCCNo2    NVARCHAR(20) 
   ,@c_UCCNo3    NVARCHAR(20) 
   ,@c_UCCNo4    NVARCHAR(20) 
   ,@c_UCCNo5    NVARCHAR(20) 
   ,@c_UCCNo6    NVARCHAR(20) 
   ,@c_UCCNo7    NVARCHAR(20) 
   ,@c_UCCNo8    NVARCHAR(20) 
   ,@c_UCCNo9    NVARCHAR(20) 
   ,@c_UCCNo10   NVARCHAR(20) 
   ,@b_Success   int        OUTPUT
   ,@n_err       int        OUTPUT
   ,@c_errmsg    NVARCHAR(250)  OUTPUT   
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @b_ByUCC     int,
        @n_continue  int,
        @n_starttcnt int,
        @n_cnt       int  

SELECT @b_ByUCC = 0,
       @n_continue = 1,
       @n_starttcnt = @@TRANCOUNT         

IF (dbo.fnc_RTrim(@c_UCCNo1) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo1) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo2) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo2) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo3) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo3) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo4) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo4) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo5) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo5) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo6) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo6) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo7) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo7) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo8) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo8) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo9) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo9) <> '') OR
   (dbo.fnc_RTrim(@c_UCCNo10) IS NOT NULL AND dbo.fnc_RTrim(@c_UCCNo10) <> '' )
BEGIN
   SELECT @b_ByUCC = 1
END 

BEGIN TRANSACTION

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @b_ByUCC = 1 
   BEGIN
      IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) 
                WHERE ReplenishmentGroup = @c_BatchNo 
                  AND ToLoc = 'PICK'
            		AND FromLoc = @c_LOC
   		         AND RefNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)
                  AND RefNo > '' ) 
      BEGIN
			-- Start : SOS32118
			/*		
			UPDATE PICKDETAIL
			SET   PICKDETAIL.Status = '5'
			FROM  PICKDETAIL 
         JOIN  UCC (NOLOCK) ON PICKDETAIL.PickDetailKey = UCC.PickDetailKey 
			WHERE PICKDETAIL.Status < '5'
         AND   UCC.UccNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)
			AND   PICKDETAIL.Loc = @c_LOC  -- SOS32118
			*/
			UPDATE PICKDETAIL
			SET   PICKDETAIL.Status = '5'
			FROM  PICKDETAIL
         JOIN  UCC (NOLOCK) ON PICKDETAIL.PickDetailKey = UCC.PickDetailKey 		
			JOIN  REPLENISHMENT R (NOLOCK) ON R.RefNo = UCC.UccNo 
			WHERE PICKDETAIL.Status < '5'
			AND   R.ReplenishmentGroup = @c_BatchNo
			AND   PICKDETAIL.Loc = R.FromLoc 
   		AND   R.FromLoc = @c_LOC
			AND   R.ToLoc = 'PICK'
         AND   UCC.UccNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)
			-- End : SOS32118

	      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to pickdetail table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

      END

		-- Start : SOS32118, move it down, after UPDATE REPLENISHMENT
		/*
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE UCC
   		SET UCC.Status = CASE REPLENISHMENT.ToLoc
   									WHEN 'PICK 'THEN '5' ELSE '6'
   							  END,
   			 UCC.EditDate = GetDate(),
   			 UCC.EditWho = sUser_sName() 
   		FROM UCC 
         JOIN REPLENISHMENT (NOLOCK) ON UCC.UCCNo = REPLENISHMENT.RefNo 
   		WHERE ReplenishmentGroup = @c_BatchNo
   		  AND REPLENISHMENT.FromLoc = @c_LOC
   		  AND REPLENISHMENT.Confirmed <> 'N'
   		  AND REPLENISHMENT.RefNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @n_continue = 1 OR @n_continue = 2
		*/
		-- End : SOS32118, move it down, after UPDATE REPLENISHMENT

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE REPLENISHMENT
   		SET Confirmed = CASE ToLoc
   								WHEN 'PICK' THEN 'Y' ELSE 'S'
   							 END,
   			 EditDate = GetDate(),
   			 EditWho = sUser_sName(),
   			 Remark = CASE ToLoc
   			 				WHEN 'PICK' THEN 'Success - FCP Replen.' ELSE 'Replen Started.'
	   					 END,
   			 ArchiveCop = NULL
   		WHERE ReplenishmentGroup = @c_BatchNo
   			AND FromLoc = @c_LOC
   			AND Confirmed = 'N'
   			AND RefNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @n_continue = 1 OR @n_continue = 2

		-- Start : SOS32118, move to here 
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE UCC
   		SET UCC.Status = CASE REPLENISHMENT.ToLoc
   									WHEN 'PICK 'THEN '5' ELSE '6'
   							  END,
   			 UCC.EditDate = GetDate(),
   			 UCC.EditWho = sUser_sName() 
   		FROM UCC 
         JOIN REPLENISHMENT (NOLOCK) ON UCC.UCCNo = REPLENISHMENT.RefNo 
   		WHERE ReplenishmentGroup = @c_BatchNo
   		  AND REPLENISHMENT.FromLoc = @c_LOC
   		  AND REPLENISHMENT.Confirmed <> 'N'
   		  AND REPLENISHMENT.RefNo IN (@c_UCCNo1,@c_UCCNo2,@c_UCCNo3,@c_UCCNo4,@c_UCCNo5,@c_UCCNo6,@c_UCCNo7,@c_UCCNo8,@c_UCCNo9,@c_UCCNo10)
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @n_continue = 1 OR @n_continue = 2
		-- End : SOS32118, move to here 
   END -- @b_ByUCC = 1 
   ELSE
   BEGIN
      IF EXISTS(SELECT 1 FROM REPLENISHMENT (NOLOCK) 
                WHERE ReplenishmentGroup = @c_BatchNo 
                  AND ToLoc = 'PICK'
            		AND FromLoc = @c_LOC
                  AND RefNo > '' ) 
      BEGIN
			-- Start : SOS32118
			/*		
			UPDATE PICKDETAIL
			SET PICKDETAIL.Status = '5'
			FROM PICKDETAIL 
         JOIN UCC (NOLOCK) ON PICKDETAIL.PickDetailKey = UCC.PickDetailKey 
			WHERE PICKDETAIL.Status < '5'
			*/
			UPDATE PICKDETAIL
			SET   PICKDETAIL.Status = '5'
			FROM  PICKDETAIL
         JOIN  UCC (NOLOCK) ON PICKDETAIL.PickDetailKey = UCC.PickDetailKey 		
			JOIN  REPLENISHMENT R (NOLOCK) ON R.RefNo = UCC.UccNo 
			WHERE PICKDETAIL.Status < '5'
			AND   R.ReplenishmentGroup = @c_BatchNo
			AND   PICKDETAIL.Loc = R.FromLoc 
   		AND   R.FromLoc = @c_LOC
			AND   R.ToLoc = 'PICK'
			-- End : SOS32118

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to pickdetail table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

      END

		-- Start : SOS32118, move it down, after UPDATE REPLENISHMENT
		/*
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE UCC
   		SET UCC.Status = CASE REPLENISHMENT.ToLoc
   									WHEN 'PICK 'THEN '5' ELSE '6'
   							  END,
   			 UCC.EditDate = GetDate(),
   			 UCC.EditWho = sUser_sName() 
   		FROM UCC 
         JOIN REPLENISHMENT (NOLOCK) ON UCC.UCCNo = REPLENISHMENT.RefNo 
   		WHERE ReplenishmentGroup = @c_BatchNo
   		  AND REPLENISHMENT.FromLoc = @c_LOC
   		  AND REPLENISHMENT.Confirmed <> 'N'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @n_continue = 1 OR @n_continue = 2
		*/
		-- End : SOS32118, move it down, after UPDATE REPLENISHMENT

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE REPLENISHMENT
   		SET Confirmed = CASE ToLoc
   								WHEN 'PICK' THEN 'Y' ELSE 'S'
   							 END,
   			 EditDate = GetDate(),
   			 EditWho = sUser_sName(),
   			 Remark = CASE ToLoc
   			 				WHEN 'PICK' THEN 'Success - FCP Replen.' ELSE 'Replen Started.'
   						END,
   			 ArchiveCop = NULL
   		WHERE ReplenishmentGroup = @c_BatchNo
   			AND FromLoc = @c_LOC
   			AND Confirmed = 'N'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
     END


		-- Start : SOS32118, move it here
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
   		UPDATE UCC
   		SET UCC.Status = CASE REPLENISHMENT.ToLoc
   									WHEN 'PICK 'THEN '5' ELSE '6'
   							  END,
   			 UCC.EditDate = GetDate(),
   			 UCC.EditWho = sUser_sName() 
   		FROM UCC 
         JOIN REPLENISHMENT (NOLOCK) ON UCC.UCCNo = REPLENISHMENT.RefNo 
   		WHERE ReplenishmentGroup = @c_BatchNo
   		  AND REPLENISHMENT.FromLoc = @c_LOC
   		  AND REPLENISHMENT.Confirmed <> 'N'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update to UCC table failed. (ispRF_ReplenFrom)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END -- IF @n_continue = 1 OR @n_continue = 2
		-- End : SOS32118
   END -- Else 
END -- @n_continue = 1

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRF_ReplenFrom'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END


GO