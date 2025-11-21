SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_732CaptureID01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date        Author     Ver.  Purposes                                      */
/* 27-09-2018  Ung        1.0   WMS-6163 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732CaptureID01]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cCCKey         NVARCHAR( 10), 
   @cCCSheetNo     NVARCHAR( 10),
   @cCountNo       NVARCHAR( 1),  
   @cLOC           NVARCHAR( 10), 
   @cSKU           NVARCHAR( 20), 
   @nQty           INT, 
   @cOption        NVARCHAR( 1),  
   @tVar           VariableTable READONLY,
   @cCaptureID     NVARCHAR( 1)  OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 732 -- Simple CC
   BEGIN
      IF LEFT( @cCCKey, 1) = 'R' -- Return stock
         SET @cCaptureID = '1'
      ELSE
         SET @cCaptureID = '0'
   END
END

GO