SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1819ScnAttr01                                   */
/* Purpose: Add css styles for screen lines                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2025-01-02 1.0  CYU027     FCR-1545. Created                         */
/************************************************************************/
CREATE     PROC [RDT].[rdt_1819ScnAttr01] (
   @nMobile          INT,
   @nFunc            INT,
   @nScn             INT,
   @cY               NVARCHAR(  2),
   @cStorerKey       NVARCHAR( 15),
   @cSValueSP        NVARCHAR( MAX) OUTPUT
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

/** Screen Example
   Scn = 4111
   ,@cLine01 = 'FROM ID:'
   ,@cLine02 = '%20d01'
   ,@cLine03 = ''
   ,@cLine04 = 'SUGGESTED LOC: '
   ,@cLine05 = '%10d02'
   ,@cLine06 = ''
   ,@cLine07 = 'TO LOC: '
   ,@cLine08 = '%10i03'
   ,@cLine09 = ''
   ,@cLine10 = '%20d15'
 */
  
IF @nFunc = 1819
BEGIN

   DECLARE @suggestLoc     NVARCHAR(10)

   SELECT @suggestLoc = O_Field02 --SuggestLoc
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile


   IF @nScn = 4111
   BEGIN
      IF @cY = 5
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @suggestLoc
         GOTO QUIT
      END
   END

END
  
QUIT:  



GO