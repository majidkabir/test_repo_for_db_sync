SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_AssignID                                       */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_AssignID] AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @n_Count int
   declare @n_id int
   declare @c_Id NVARCHAR(20)
   select @n_Count = 0
   declare cursor_id cursor fast_forward read_only
   for select * from lotxlocxid where storerkey="locm" order by sku
   open cursor_id
   fetch next from cursor_id
   while (@@fetch_status = 0)
   begin
      select @n_id= len(dbo.fnc_RTrim(dbo.fnc_LTrim(str(@n_Count))))

      if @n_id=1
      select @c_Id = "C00000000" + dbo.fnc_RTrim(dbo.fnc_LTrim(str(@n_Count) ))
   else
      if @n_id=2
      select @c_Id = "C0000000" + dbo.fnc_RTrim(dbo.fnc_LTrim(str(@n_Count) ))
   else
      if  @n_id=3
      select @c_Id = "C000000" + dbo.fnc_RTrim(dbo.fnc_LTrim(str(@n_Count) ))
   else
      if @n_id=4
      select @c_Id="C00000" + dbo.fnc_RTrim(dbo.fnc_LTrim(str(@n_Count)))

      select @c_Id=""
      select @n_Count = @n_Count + 1
      fetch next from cursor_id
   end

   close cursor_id
   deallocate cursor_id
END

GO