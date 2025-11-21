SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[isp_update_UCC_Status](
@c_uccno NVARCHAR(20),
@c_sku NVARCHAR(20),
@c_storerkey NVARCHAR(15)
)
AS
BEGIN

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   Declare  @c_uccpack NVARCHAR(1),
            @c_uccstatus NVARCHAR(1),
            @b_Success   int,
            @n_err       int,
            @n_err2      int,
            @c_errmsg    NVARCHAR(250),
            @n_continue  int ,
            @n_starttcnt int , -- Holds the current transaction count
            @n_cnt       int   -- Holds @@ROWCOUNT after certain operations


   SELECT @n_continue=1
   SELECT @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN 

   IF @n_continue=1 or @n_continue=2
   BEGIN
      SELECT @c_uccstatus = Status
      FROM UCC (NOLOCK)
      WHERE Uccno = @c_uccno
      AND Sku = @c_sku
      AND Storerkey = @c_storerkey

      SELECT @b_success = 0
      Execute nspGetRight null,	-- facility
            @c_storerKey, 	-- Storerkey
            null,				-- Sku
            'UCCPACK',		   -- Configkey
            @b_success		output,
            @c_uccpack 	output,
            @n_err			output,
            @c_errmsg		output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'isp_update_UCC_Status' + dbo.fnc_RTRIM(@c_errmsg)
      END
      ELSE
      IF @c_uccpack = '1'
      BEGIN
         IF @c_uccstatus >= '2' and @c_uccstatus < '5'
         BEGIN
            UPDATE UCC WITH (ROWLOCK)
            SET Status = '6', EditDate = GetDate(), EditWho = sUser_sName() 
            WHERE Uccno = @c_uccno
            AND Sku = @c_sku
            AND Storerkey = @c_storerkey

      		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      		IF @n_err <> 0
      		BEGIN
      			SELECT @n_continue = 3
      			SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65101   
      			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed.(isp_update_UCC_Status)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
      		END
         END
         ELSE IF @c_uccstatus >= '5'
         BEGIN
            SELECT @n_continue = 3, @n_err = 50000
            SELECT @c_errmsg = 'The UCC is Replenished or Packed'
         END
      END -- @c_uccpack = '1'
      ELSE
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET Status = '6', EditDate = GetDate(), EditWho = sUser_sName() 
         WHERE Uccno = @c_uccno
         AND Sku = @c_sku
         AND Storerkey = @c_storerkey

   		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   		IF @n_err <> 0
   		BEGIN
   			SELECT @n_continue = 3
   			SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 65101   
   			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed.(isp_update_UCC_Status)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
   		END
      END
   END -- If continue 1 or 2

   /* #INCLUDE <SPTPA01_2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_update_UCC_Status'
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
END -- procedure

GO