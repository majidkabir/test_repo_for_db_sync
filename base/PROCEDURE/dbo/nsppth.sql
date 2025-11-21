SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPTH                                             */
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


CREATE PROC    [dbo].[nspPTH]
@c_ptracetype               NVARCHAR(30)
,              @c_userid                   NVARCHAR(20)
,              @c_storerkey                NVARCHAR(15)
,              @c_sku                      NVARCHAR(20)
,              @c_lot                      NVARCHAR(10)
,              @c_id                       NVARCHAR(10)
,              @c_packkey                  NVARCHAR(10)
,              @n_qty                      int
,              @b_pa_multiproduct          int
,              @b_pa_multilot              int
,              @d_starttime                datetime
,              @d_endtime                  datetime
,              @n_pa_locsreviewed          int
,              @c_pa_locfound              NVARCHAR(10)
,              @n_ptraceheadkey            NVARCHAR(10) OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     int,
   @n_err         int,
   @c_errmsg      NVARCHAR(250)
   EXEC nspg_getkey 'PTRACEHEADKEY', 10, @n_ptraceheadkey OUTPUT,
   @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, 0, 1
   IF @b_Success = 1
   BEGIN
      INSERT INTO PTRACEHEAD VALUES
      (@c_ptracetype, @n_ptraceheadkey, @c_userid, @c_storerkey,
      @c_sku, @c_lot, @c_id, @c_packkey, @n_qty,
      @b_pa_multiproduct, @b_pa_multilot,
      @d_starttime, @d_endtime, @n_pa_locsreviewed, @c_pa_locfound)
   END
ELSE
   BEGIN
      SELECT @n_ptraceheadkey = ""
   END
END

GO