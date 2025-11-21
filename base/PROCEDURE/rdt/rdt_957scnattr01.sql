SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_957ScnAttr01                                   */
/* Purpose: Add css styles for screen lines                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2025-01-02 1.0  CYU027     FCR-1584. Created                         */
/************************************************************************/
CREATE     PROC [RDT].[rdt_957ScnAttr01] (
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
  
IF @nFunc = 957
BEGIN
   DECLARE @cLOCStep3        NVARCHAR(10)

   SELECT @cLOCStep3      = O_Field01
   FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

   /**
      Scn = 5292, step = 3
      ,@cLine01 = 'LOC: %10d01'
      ,@cLine02 = 'ID:'
      ,@cLine03 = '%18d08'
      ,@cLine04 = 'SKU:'
      ,@cLine05 = '%20d02'
      ,@cLine06 = '%20d03'
      ,@cLine07 = '%20d04'
      ,@cLine08 = 'UCC:'
      ,@cLine09 = '%20d09'
      ,@cLine10 = '%60i05'
      ,@cLine11 = 'TOTAL CASE: %05d06'
      ,@cLine12 = 'TOTAL SCAN: %05d07'
      ,@cLine14 = '%e'
   */

   IF @nScn = 5292
   BEGIN

      IF @cY = 1 -- FROM LOC
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @cLOCStep3
         GOTO QUIT
      END
   END

   IF @nScn = 6443
   BEGIN

      IF @cY = 1 -- FROM LOC
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @cLOCStep3
         GOTO QUIT
      END
   END


END
  
QUIT:  



GO