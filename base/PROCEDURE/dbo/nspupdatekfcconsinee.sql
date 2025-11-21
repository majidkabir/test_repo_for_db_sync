SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspUpdateKFCconsinee                               */
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

--EXEC nspUpDATEkfcconsinee
/*--EXEC nspUpdateGthconsinee */
CREATE PROC [dbo].[nspUpdateKFCconsinee]
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
   DECLARE cur_updateconsinee CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey,company,Address1,Address2
   FROM storer (NOLOCK)
   WHERE type = '2'
   OPEN cur_updateconsinee
   WHILE (1 = 1)
   BEGIN
      FETCH NEXT FROM cur_updateconsinee INTO @c_Storerkey,@c_Ucompany,@c_UAddress1,@c_UAddress2
      IF @@FETCH_STATUS <> 0 BREAK
      UPDATE orders
      SET C_Company=@c_Ucompany,c_Address1=@c_UAddress1,c_Address2=@c_UAddress2,route='99',Facility='BPI02'
      WHERE 'TRT'+ConsigneeKey = @c_Storerkey
      and Storerkey='TJNS'
      and Sostatus='0'
   End   -- while
   close cur_updateconsinee
   deallocate cur_updateconsinee
END

GO