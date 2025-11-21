SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtSetFocusField_V1                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [RDT].[rdtSetFocusField_V1] (
   @nMobile    int  ,
   @nField     int 
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   
   BEGIN TRAN
    
   UPDATE RDT.RDTXML_Root WITH (ROWLOCK) set focus = 'Field' + RIGHT('0' + RTRIM(Cast(@nField as NVARCHAR(2))), 2) 
   WHERE mobile = @nMobile

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END


GO