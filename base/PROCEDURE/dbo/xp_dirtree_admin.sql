SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: xp_dirtree_admin                                   */
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

CREATE PROC [dbo].[xp_dirtree_admin]
(
    @c_Directory           NVARCHAR(500)
   ,@n_Depth               INT --subfolder levels to display.  The default of 0 will display all subfolders.           
   ,@n_file                Bit --This will either display files as well as each folder.  The default of 0 will not display any files        
)
WITH EXECUTE AS 'excel2wms'
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   --create TABLE #DirTree999 (
   --        Id int identity(1,1),
   --        SubDirectory nvarchar(255),
   --        Depth smallint,
   --        FileFlag bit  -- 0=folder 1=file
   --       )
   --INSERT INTO #DirTree999 (SubDirectory, Depth, FileFlag)
   EXEC master..xp_dirtree @c_Directory, 2, 1 

   --select @c_filenam = SubDirectory
   --FROM #DirTree999


   END -- Procedure

GO