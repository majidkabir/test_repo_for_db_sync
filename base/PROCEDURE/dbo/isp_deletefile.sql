SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_DeleteFile                                     */  
/* Creation Date: 22-Jan-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                   */  
/*                                                                      */  
/* Purpose:  Delete File                                                */  
/*                                                                      */  
/* Input Parameters:  @cOldFileName                                     */  
/*                    @cNewFileName                                     */  
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
  
CREATE PROC [dbo].[isp_DeleteFile] (  
   @cFileName    NVARCHAR(215) OUTPUT,  
   @nSuccess     INT OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nFile_Exists      int  
  
   DECLARE @iObjFileSystem   int   
         , @iObjErrorObject  int   
         , @cErrorMessage    NVARCHAR(1000)   
         , @cCommand         NVARCHAR(1000)   
         , @iHr              int   
  
   SET NOCOUNT ON   
   SET @nSuccess = 1  
  
   SET @cErrorMessage = 'Opening the File System Object'  
  
   EXECUTE @iHr = sp_OACreate 'Scripting.FileSystemObject' , @iObjFileSystem OUT  
  
   IF @iHr = 0   
   BEGIN   
      EXEC sp_OAMethod @iObjFileSystem, 'FileExists', @nFile_Exists out, @cFileName  
  
      IF @nFile_Exists = 1   
      BEGIN   
         EXECUTE @iHr = sp_OAMethod @iObjFileSystem, 'DeleteFile', NULL, @cFileName, 1 --NJOW01  
  
         IF @iHr <> 0  
         BEGIN  
            SET @cErrorMessage = 'Delete File ' + ISNULL(RTRIM(@cFileName),'')   
            GOTO EXIT_PROCEDURE  
         END  
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