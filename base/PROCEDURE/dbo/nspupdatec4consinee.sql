SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspUpdateC4consinee                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 14-Mar-2012  KHLim01       Update EditDate                           */       
/************************************************************************/

CREATE PROC [dbo].[nspUpdateC4consinee]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare  @c_storerkey NVARCHAR(15)
   ,        @c_Ucompany NVARCHAR(45)
   ,        @c_ConsigneeKey NVARCHAR(15)
   ,        @c_UAddress1 NVARCHAR(45)
   ,        @c_UAddress2 NVARCHAR(45)
   ,        @c_UAddress4 NVARCHAR(45)
   DECLARE cur_updateconsinee CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey,company,Address1,Address2,Address4
   FROM storer (NOLOCK)
   WHERE type = '2'
   OPEN cur_updateconsinee
   WHILE (1 = 1)
   BEGIN
      FETCH NEXT FROM cur_updateconsinee INTO @c_Storerkey,@c_Ucompany,@c_UAddress1,@c_UAddress2,@c_UAddress4
      IF @@FETCH_STATUS <> 0 BREAK
      UPDATE orders
      SET C_Company=@c_Ucompany,c_Address1=@c_UAddress1,c_Address2=@c_UAddress2,route=left(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_UAddress4)),2),
      EditDate = GETDATE(), -- KHLim01
      TrafficCop=NULL
      WHERE ConsigneeKey = @c_Storerkey
      and Storerkey Between 'C4LG000000' And 'C4LGZZZZZZ'
      and Sostatus='0'
   End   -- while
   close cur_updateconsinee
   deallocate cur_updateconsinee
END

GO