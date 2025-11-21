SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_PalletID                                       */
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


CREATE PROC [dbo].[nsp_PalletID] (
@c_receiptkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_linenumber NVARCHAR(5),
   @c_storerkey NVARCHAR(15),
   @c_sku NVARCHAR(20),
   @c_facility NVARCHAR(1),
   @c_palletid NVARCHAR(8),
   @b_success int,
   @n_err int,
   @c_errmsg NVARCHAR(255)

   select @c_linenumber = ''
   while(1=1)
   begin
      select @c_linenumber = min(receiptlinenumber)
      from receiptdetail (nolock)
      where receiptkey = @c_receiptkey
      and receiptlinenumber > @c_linenumber
      and (toid = '' or toid is null or toid = null)

      if @@rowcount = 0 or @c_linenumber is null or @c_linenumber = null
      break

      select @c_storerkey = storerkey,
      @c_sku = sku
      from receiptdetail (nolock)
      where receiptkey = @c_receiptkey
      and receiptlinenumber = @c_linenumber

      select @c_facility = left(dbo.fnc_LTrim(f.descr), 1)
      from receipt r (nolock) join Facility f (nolock)
      on r.facility = f.facility
      where receiptkey = @c_receiptkey

      execute nspg_getkey
      'PALLETID',
      8,
      @c_palletid OUTPUT,
      @b_success OUTPUT,
      @n_err OUTPUT,
      @c_errmsg OUTPUT

      update receiptdetail
      set trafficcop = null,
      toid = @c_facility + '-' + @c_palletid
      where receiptkey = @c_receiptkey
      and receiptlinenumber = @c_linenumber
   end
END

GO