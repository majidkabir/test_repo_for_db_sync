SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispASNConfirmPick                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Update PickDetail to Status 9 from backend                  */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Mar-2005  Shong         Performance Tunning                       */
/* 26-Feb-2007  Vicky         SOS#68978 - Update Order Header & Detail  */
/*                            after Picked if not being updated by      */
/*                            trigger                                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispASNConfirmPick]
         @cStorerKey     NVARCHAR(15),
         @cExternPOKey   NVARCHAR(20), -- For one storer, pass in the Storerkey; For All Storer, pass in '%'
      	@b_Success      int OUTPUT, 
      	@n_err          int OUTPUT,
      	@c_ErrMsg       NVARCHAR(215) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey  char (10),
           @n_Continue       int ,
           @f_Status         int

   -- Added for SOS#68978 (Start)
   DECLARE @c_PrevOrderkey   NVARCHAR(10),
           @c_PrevOrdLineNo  NVARCHAR(5),
           @c_Orderkey       NVARCHAR(10),
           @c_OrderLineNo    NVARCHAR(5) 
   -- Added for SOS#68978 (End)

   SELECT @n_continue=1
   SELECT @c_PrevOrderkey = ''
   SELECT @c_PrevOrdLineNo = ''

   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKDETAIL.PickDetailKey, PICKDETAIL.Orderkey, PICKDETAIL.OrderLineNumber -- SOS#68978
   FROM ORDERDETAIL (NOLOCK)
   JOIN PICKDETAIL (NOLOCK) ON  ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey AND   
                                ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
   WHERE PICKDETAIL.Status < '5'
   AND   ORDERDETAIL.ExternPOkey = @cExternPOKey
   ORDER BY PICKDETAIL.Orderkey, PICKDETAIL.OrderLineNumber, PICKDETAIL.PickDetailKey -- SOS#68978 

   OPEN CUR1

   SET @c_PickDetailKey = SPACE(10)

   FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNo
   
   SELECT @f_status = @@FETCH_STATUS

   WHILE @f_status <> -1
   BEGIN
      BEGIN TRAN

      UPDATE PICKDETAIL WITH (ROWLOCK)
         SET Status = '5'
      WHERE PickDetailKey = @c_PickDetailKey
      AND   Status < '5'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (ispASNConfirmPick)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      END

      -- Added for SOS#68978 (Start)
      BEGIN TRAN

       UPDATE ORDERDETAIL
          SET Status = '5', Trafficcop = NULL
       WHERE Orderkey = @c_Orderkey
       AND   OrderLineNumber = @c_OrderLineNo
       AND   Status < '5'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (ispASNConfirmPick)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      END
 
      BEGIN TRAN

       UPDATE ORDERS
          SET Status = '5', Trafficcop = NULL
       WHERE Orderkey = @c_Orderkey
       AND   Status < '5'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_err), @n_err=72809   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (ispASNConfirmPick)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      END
      -- Added for SOS#68978 (End)

      FETCH NEXT FROM CUR1 INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNo 
      SELECT @f_status = @@FETCH_STATUS
   END -- While PickDetail Key

   CLOSE CUR1
   DEALLOCATE CUR1

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_ErrMsg, 'ispASNConfirmPick'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END



GO