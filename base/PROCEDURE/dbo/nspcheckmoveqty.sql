SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspCheckMoveQty                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspCheckMoveQty]
@c_storerkey    NVARCHAR(15)
,              @c_sku          NVARCHAR(20)
,              @c_lot          NVARCHAR(10)
,              @c_Loc          NVARCHAR(10)
,              @c_ID           NVARCHAR(18)
,              @n_qty          int
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_cnt int              ,
   @n_err2 int              -- For Additional Error Detection
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   /* #INCLUDE <SPCMQ1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      execute    nspLOTLOCIDUniqueRow
      @c_storerkey    =@c_storerkey OUTPUT
      ,              @c_sku          =@c_sku       OUTPUT
      ,              @c_lot          =@c_lot       OUTPUT
      ,              @c_Loc          =@c_loc       OUTPUT
      ,              @c_ID           =@c_id        OUTPUT
      ,              @b_Success      =@b_success   OUTPUT
      ,              @n_err          =@n_err       OUTPUT
      ,              @c_errmsg       =@c_errmsg    OUTPUT
      IF @b_success = 0
      BEGIN
         SELECT @n_continue =3
      END
   END
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_checkqty int
      SELECT @n_checkqty = QTY FROM LOTxLOCxID
      WHERE LOT = @c_lot and LOC = @c_loc and ID = @c_id and QTY > 0
      IF @n_checkqty IS NULL or @n_checkqty < @n_qty
      BEGIN
         SELECT @n_continue = 3 , @n_err = 84201
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Quantity Does Not Pass Test. (nspCheckMoveQty)"
      END
   END
   /* #INCLUDE <SPCMQ2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, "nspCheckMoveQty"
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
END


GO