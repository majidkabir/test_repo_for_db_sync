SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_521ScnAttr01                                   */
/* Purpose: Add css styles for screen lines                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2025-01-02 1.0  CYU027     FCR-1584. Created                         */
/************************************************************************/
CREATE     PROC [RDT].[rdt_521ScnAttr01] (
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
   Scn = 927
    @cLine01 = 'UCC:'
   ,@cLine02 = '%20d01'
   ,@cLine04 = 'FROM LOC:'
   ,@cLine05 = '%10d02'
   ,@cLine07 = 'SUGGESTED LOC:'
   ,@cLine08 = '%10d03'
   ,@cLine10 = 'FINAL LOC:'
   ,@cLine11 = '%20i04'
   ,@cLine12 = '%20d05' -- SOS373949 (james03)/WMS-17795
   ,@cLine13 = '%20d06' -- SOS373949 (james03)
 */
  
IF @nFunc = 521
BEGIN
   DECLARE @fromLoc        NVARCHAR(10)
   DECLARE @suggestLoc     NVARCHAR(10)

   SELECT @fromLoc      = O_Field02,
          @suggestLoc   = O_Field03
   FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile


   IF @nScn = 927
   BEGIN

      IF @cY = 5 -- FROM LOC
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @fromLoc
         GOTO QUIT
      END

      IF @cY = 8 -- SuggestLoc
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode LOC.colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @suggestLoc
         GOTO QUIT
      END
   END

END
  
QUIT:  



GO