SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ScnAttr01                                   */
/* Purpose: Add css styles for screen lines                             */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2025-01-02 1.0  CYU027     FCR-1584. Created                         */
/************************************************************************/
CREATE     PROC [RDT].[rdt_839ScnAttr01] (
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
  
IF @nFunc = 839
BEGIN
   DECLARE @cLOCStep3        NVARCHAR(10)
   DECLARE @cLOCStep7        NVARCHAR(10)

   SELECT @cLOCStep3      = O_Field01,
          @cLOCStep7      = O_Field01
   FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

   /**
      Scn = 4642, step = 3
      ,@cLine01 = 'LOC: %10d01'
      ,@cLine02 = '%20d02'
      ,@cLine03 = '%20d03'
      ,@cLine04 = '%20d04'
      ,@cLine05 = 'SKU/UPC:'
      ,@cLine06 = '%120iV_Barcode'  -- WMS-22147
      ,@cLine07 = '%20d08'    -- Lottablenn (WMS5057)
      ,@cLine08 = '%20d09'    -- Lottablenn (WMS5057)
      ,@cLine09 = '%20d10'    -- Lottablenn (WMS5057)
      ,@cLine10 = '%20d11'    -- Lottablenn (WMS5057)
      ,@cLine11 = 'PICK: %05i07 ACT: %06d06'
      ,@cLine12 = 'BAL QTY: %12d13'    -- WMS10357(yeekung01)
      ,@cLine13 = '%20d12'    -- WMS10357
   */

   IF @nScn = 4642 or @nScn = 6445
   BEGIN
      IF @cY = 1 -- FROM LOC
      BEGIN
         SELECT TOP 1 @cSValueSP = Descr -- colorCode
         FROM LOC (NOLOCK ) WHERE LOC = @cLOCStep3
         GOTO QUIT
      END
   END

   /**
      Scn = 4646
      ,@cLine01 = 'LOC: %10d01'
      ,@cLine02 = 'LOC: %10i02'
      ,@cLine14 = '%e'
      ,@cWebGroup = '{"1":["1","2"]}'
      ,@nFunc = 839
   */

   IF @nScn = 4646
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