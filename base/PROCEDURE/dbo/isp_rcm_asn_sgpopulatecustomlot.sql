SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_SGPopulateCustomLot                    */
/* Creation Date: 24-Mar-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22095 THGSG Populate custom lot to lottable02           */
/*                                                                      */
/* Called By: ASN Dymaic RCM configure at listname 'RCMConfig'          */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_RCM_ASN_SGPopulateCustomLot]
   @c_Receiptkey NVARCHAR(10),
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int

   DECLARE @c_ReceiptLineNumber NVARCHAR(10),
           @dt_EffectiveDate DATETIME

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RD.ReceiptLineNumber, R.EffectiveDate
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   WHERE R.Receiptkey = @c_Receiptkey
   AND RD.FinalizeFlag <> 'Y'

   OPEN CUR_RD

   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @dt_EffectiveDate

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      SET Lottable02 = RTRIM(SKU) + CONVERT(NVARCHAR(6), @dt_EffectiveDate, 12),
          Trafficcop = NULL,
          EditWho = SUSER_SNAME(),
          EditDate = GETDATE()
      WHERE Receiptkey = @c_Receiptkey
      AND ReceiptLineNumber = @c_ReceiptLineNumber
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue=3
         SET @n_err = 62010
         SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Update RECEIPTDETAIL Failed. (ispPRREC04)'
                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC
      END      

      FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @dt_EffectiveDate
   END
   CLOSE CUR_RD
   DEALLOCATE CUR_RD

ENDPROC:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RD') in (0 , 1)
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END

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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_SGPopulateCustomLot'
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
END -- End PROC

GO