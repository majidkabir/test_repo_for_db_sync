SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_logerror                                       */
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

CREATE PROC         [dbo].[nsp_logerror]
@n_err        int
,              @c_errmsg     NVARCHAR(250)
,              @c_module     NVARCHAR(250)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   BEGIN TRANSACTION
      INSERT         errlog
      (
      ErrorID
      ,         Module
      ,         ErrorText
      )
      VALUES         (
      @n_err
      ,         @c_module
      ,         @c_errmsg
      )
      COMMIT TRAN
   END

GO