SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_FolderExists                                   */
/* Creation Date: 10-Mar-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW   	                                                */
/*                                                                      */
/* Purpose:  Check Folder Exists                                        */
/*                                                                      */
/* Input Parameters:  @cFolderName                                      */
/*                    @nSuccess                                         */
/*                                                                      */
/* Notes: have to grant access to below object                          */
/* Create a database role called RDT under master db                    */
/* Grant exec on sp_OACreate to RDT                                     */
/* Grant exec on sp_OAMethod to RDT                                     */
/* Grant exec on sp_OAGetErrorInfo to RDT                               */
/* Grant exec on sp_OADestroy to RDT                                    */
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
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_FolderExists]
            (@cFolderName  NVARCHAR(215),
             @nFolderExists int OUTPUT,
             @nSuccess      int OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nFolder_Exists    int

   DECLARE @iObjFileSystem   int 
         , @iObjErrorObject  int 
         , @cErrorMessage    NVARCHAR(1000) 
         , @cCommand         NVARCHAR(1000) 
         , @iHr              int 
         , @cFileAndPath     NVARCHAR(80)

   SET NOCOUNT ON 
   SET @nSuccess = 1
   SET @nFolderExists = 0

   SET @cErrorMessage = 'Opening the File System Object'

   EXECUTE @iHr = sp_OACreate 'Scripting.FileSystemObject' , @iObjFileSystem OUT

   IF @iHr = 0 
   BEGIN 
      EXEC sp_OAMethod @iObjFileSystem, 'FolderExists', @nFolder_Exists out, @cFolderName

      IF @nFolder_Exists = 1 
      BEGIN 
      	 SET @nFolderExists = 1
      END    
   END 


EXIT_PROCEDURE:   
   IF @iHr <> 0
   BEGIN
      DECLARE @cSource      NVARCHAR(255) 
            , @cDescription NVARCHAR(255) 
            , @cHelpfile    NVARCHAR(255) 
            , @nHelpID      int 

      SET @nSuccess = 0

      EXECUTE sp_OAGetErrorInfo  @iObjErrorObject, 
                 @cSource OUTPUT, @cDescription OUTPUT, @cHelpfile OUTPUT, @nHelpID OUTPUT

      SELECT @cErrorMessage = 'Error whilst '
                           + COALESCE(ISNULL(RTRIM(@cErrorMessage),''),'doing something')
                   + ', ' + COALESCE(ISNULL(RTRIM(@cDescription),''),'')
      RAISERROR (@cErrorMessage,16,1)
   END

   EXECUTE sp_OADestroy @iObjFileSystem
END

GO