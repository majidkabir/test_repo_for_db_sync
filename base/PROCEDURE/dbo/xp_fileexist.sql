SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: xp_fileexist                                       */
/* Creation Date: 29-MAR-2019                                           */
/* Copyright: LF                                                        */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: exec master..xp_dirtree with admin right                    */
/*                                                                      */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/
CREATE PROC [dbo].[xp_fileexist]
(
	 @c_FileName    VARCHAR(255)
   ,@n_FileExists  INT OUTPUT 
)
WITH EXECUTE AS 'excel2wms'
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   EXEC Master.dbo.xp_fileexist @c_FileName, @n_FileExists OUTPUT

END -- Procedure

GO