SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_WriteStringToFile					 			      */
/* Creation Date: 22-Jan-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong  	                                                */
/*                                                                      */
/* Purpose:  Move File                                                  */
/*                                                                      */
/* Input Parameters:  @cString			     						            */
/*							 @cPath															*/
/*							 @cFilename													   */
/*							 @nIOMode														*/
/*																								*/
/* Notes: have to grant access to below object                          */
/* Create a database role called RDT under master db                    */
/* Grant exec on sp_OACreate to RDT                                     */
/* Grant exec on sp_OAMethod to RDT                                     */
/* Grant exec on sp_OAGetErrorInfo to RDT                               */
/* Grant exec on sp_OADestroy to RDT                                    */
/* Called By:						                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 24-Apr-2009  James     1.1   Change the variable @cFileAndPath from  */
/*                              80 to 255 (james01)                     */
/* 05-Dec-2011  NJOW01    1.2   determine the '\' in file path          */
/* 15-Apr-2013  Ung       1.3   SOS275627 Write to Unicode file (ung01) */
/* 15-Aug-2018  CSCHONG   1.4   Add optional parameter (CS01)           */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_WriteStringToFile]  (
   @cString   nvarchar(max), -- 8000 in SQL Server 2000
   @cPath     NVARCHAR(255),
   @cFilename NVARCHAR(100),
   @nIOMode   int = 2, -- 2 = ForWriting ,8 = ForAppending 
   @nSuccess  int OUTPUT,
	@nFileMode int = ''          --(CS01)
)
AS
DECLARE  @iObjFileSystem   int,
         @iObjTextStream   int,
		   @iObjErrorObject  int,
		   @cErrorMessage    NVARCHAR(1000),
	      @cCommand         NVARCHAR(1000),
	      @iHr              int,
--		   @cFileAndPath     NVARCHAR(80)
		   @cFileAndPath     NVARCHAR(255)  --(james01)
		 --  @nFileMode        int --(ung01)          --(CS01)

SET NOCOUNT ON
SET @nSuccess = 1

SET @cErrorMessage='Opening the File System Object'

EXECUTE @iHr = sp_OACreate  'Scripting.FileSystemObject' , @iObjFileSystem OUT
 --SET @nFileMode = -1        --(CS01) --Start
 IF @nFileMode = ''
	BEGIN
	  SET @nFileMode = -1
	END

--(CS01) End

IF SUBSTRING(@cPath, LEN(@cPath), 1) <> '\'  --NJOW01
   SELECT @cFileAndPath = @cPath + '\' + @cFilename
ELSE
   SELECT @cFileAndPath = @cPath + @cFilename   
   
IF @iHr = 0 
BEGIN
   IF @nIOMode = 2
   BEGIN
      SELECT @iObjErrorObject = @iObjFileSystem, 
             @cErrorMessage='Creating file N''' + @cFileAndPath + ''''
   END
END
IF @iHr = 0 
   EXECUTE @iHr = sp_OAMethod @iObjFileSystem, 'OpenTextFile'
	               ,@iObjTextStream OUT, @cFileAndPath, @nIOMode, True, @nFileMode --(ung01)

IF @iHr = 0 
   SELECT @iObjErrorObject = @iObjTextStream, 
	       @cErrorMessage = 'Writing to the file "' + @cFileAndPath + '"'

IF @iHr = 0 
   EXECUTE @iHr = sp_OAMethod @iObjTextStream, 'WriteLine', Null, @cString

IF @iHr = 0 
   SELECT @iObjErrorObject = @iObjTextStream, @cErrorMessage = 'closing the file "'+ @cFileAndPath + '"'

IF @iHr = 0 
   EXECUTE @iHr = sp_OAMethod  @iObjTextStream, 'Close'


IF @iHr <> 0
BEGIN
	Declare 
		@cSource      NVARCHAR(255),
		@cDescription NVARCHAR(255),
		@cHelpfile    NVARCHAR(255),
		@nHelpID      int

   SET @nSuccess = 0
	
	EXECUTE sp_OAGetErrorInfo  @iObjErrorObject, 
		     @cSource OUTPUT, @cDescription OUTPUT, @cHelpfile OUTPUT, @nHelpID OUTPUT

	SELECT @cErrorMessage='Error whilst '
			+ coalesce(@cErrorMessage,'doing something')
			+ ', ' + coalesce(@cDescription,'')
	RAISERROR (@cErrorMessage,16,1)
	
END

EXECUTE @iHr = sp_OADestroy @iObjTextStream
IF @iHr <> 0
BEGIN
	EXECUTE sp_OAGetErrorInfo  @iObjErrorObject, 
		     @cSource OUTPUT, @cDescription OUTPUT, @cHelpfile OUTPUT, @nHelpID OUTPUT

	SELECT @cErrorMessage='Error whilst '
			+ 'Destroy object'
			+ ', ' + coalesce(@cDescription,'')
	RAISERROR (@cErrorMessage,16,1)
END

EXECUTE @iHr = sp_OADestroy @iObjFileSystem
IF @iHr <> 0
BEGIN
	EXECUTE sp_OAGetErrorInfo  @iObjErrorObject, 
		     @cSource OUTPUT, @cDescription OUTPUT, @cHelpfile OUTPUT, @nHelpID OUTPUT

	SELECT @cErrorMessage='Error whilst '
			+ 'Destroy object'
			+ ', ' + coalesce(@cDescription,'')
	RAISERROR (@cErrorMessage,16,1)
END

GO