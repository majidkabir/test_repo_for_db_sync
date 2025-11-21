SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtHandle_SetUser                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Dynamic lottable                                            */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-11-2014  1.0  Ung         Created                                 */
/* 02-11-2016  1.1  Ung         Fix recompile due to SET DATEFORMAT     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtHandle_SetUser]
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @cUserName        NVARCHAR(18), 
   @cStoredProcName  NVARCHAR( 1024), 
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR(125) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- SETUSER             -- Reset back to original sql login (i.e. RDT)
   -- SETUSER @cUserName  -- Set it as the sql login that user key-in
   EXECUTE AS LOGIN = @cUserName
   
   -- Change to user date format
   -- DECLARE @cDateFormat NVARCHAR( 3)
   -- SET @cDateFormat = RDT.rdtGetDateFormat( @cUserName)      
   -- SET DATEFORMAT @cDateFormat
   
   SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)      
   SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @nMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'      
   EXEC sp_executesql @cStoredProcName , N'@nMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',      
      @nMobile,      
      @nErrNo OUTPUT,      
      @cErrMsg OUTPUT          
                              
   REVERT                  -- Need DB compatible level 9.0 (SQL 2005)
   -- SETUSER              -- Reset back to original sql login (i.e. RDT)  
   
END -- End Procedure

GO