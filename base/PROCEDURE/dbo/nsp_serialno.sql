SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_serialno                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 09-Jul-2013  NJOW    1.0   315487-Extend serialno to char(30)        */
/************************************************************************/

CREATE PROCedure [dbo].[nsp_serialno]( @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20), @c_orderkey NVARCHAR(10), @c_orderlineno NVARCHAR(5))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_serialno NVARCHAR(30), @c_sum_serialno NVARCHAR(200)
   declare serial_cur cursor fast_forward read_only
   for
   SELECT SerialNo
   FROM SerialNo
   WHERE storerkey = @c_storerkey
   and sku = @c_sku
   and orderkey = @c_orderkey
   and orderlinenumber = @c_orderlineno
   open serial_cur
   fetch next from serial_cur into @c_serialno
   while (@@fetch_status=0)
   begin
      select @c_sum_serialno = @c_sum_serialno + dbo.fnc_RTrim(@c_serialno) + ", "
      fetch next from serial_cur into @c_serialno
   end
   select @c_sum_serialno = substring(@c_sum_serialno,1,len(@c_sum_serialno)-1)
   select @c_sum_serialno
   close serial_cur
   deallocate serial_cur
END


GO