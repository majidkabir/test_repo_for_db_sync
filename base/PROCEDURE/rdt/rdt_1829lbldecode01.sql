SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1829LblDecode01                                 */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Trim 1st 2 chars and read the rest string                   */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-01-30 1.0  James    WMS3653. Created                            */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1829LblDecode01]    
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cParam1      NVARCHAR( 20),
   @cParam2      NVARCHAR( 20),
   @cParam3      NVARCHAR( 20),
   @cParam4      NVARCHAR( 20),
   @cParam5      NVARCHAR( 20),
   @cBarcode     NVARCHAR( 60),
   @cUCCNo       NVARCHAR( 20)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   -- Nothing scanned return original value
   IF ISNULL( @cBarcode, '') = ''
      GOTO Quit

   -- < 18 no need trim. Return scanned value.
   IF LEN( RTRIM( @cBarcode)) <= 18
      SET @cUCCNo = RTRIM( @cBarcode)
   ELSE   
      --SET @cUCCNo = SUBSTRING( @cBarcode, 3, LEN( RTRIM( @cBarcode)) - 2)
      SET @cUCCNo = RIGHT( RTRIM( @cBarcode), 18)

QUIT:

END -- End Procedure  

GO