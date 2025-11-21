SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPTD                                             */
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

CREATE PROC    [dbo].[nspPTD]
@c_ptracetype                   NVARCHAR(30)
,              @n_ptraceheadkey                NVARCHAR(10)
,              @c_pa_putawaystrategykey        NVARCHAR(10)
,              @c_pa_putawaystrategylinenmbr   NVARCHAR(10)
,              @n_ptracedetailkey              NVARCHAR(10)
,              @c_lockey                       NVARCHAR(10)
,              @c_reason                       NVARCHAR(80)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success     int,
   @n_err         int,
   @c_errmsg      NVARCHAR(250)
   -- select @c_lockey, @c_reason
   EXEC nspg_getkey 'PTRACEDETAILKEY', 10, @n_ptracedetailkey OUTPUT,
   @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, 0, 1
   IF @b_success = 1
   BEGIN
      INSERT INTO PTRACEDETAIL VALUES
      (@c_ptracetype, @n_ptraceheadkey, @c_pa_putawaystrategykey,
      @c_pa_putawaystrategylinenmbr, @n_ptracedetailkey,
      @c_lockey, @c_reason)
   END
ELSE
   BEGIN
      SELECT @n_ptracedetailkey = ""
   END
END

GO