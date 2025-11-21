SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_731ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Display ID                                                        */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-08-06   James     1.0   WMS9996. Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_731ExtInfo01]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
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
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTtlQty  INT
   DECLARE @cID      NVARCHAR( 18)

   -- Variable mapping
   SELECT @cID = Value FROM @tVar WHERE Variable = '@cID'

   IF @nFunc = 731 -- Simple CC
   BEGIN
      IF @nStep IN ( 4, 9, 10) -- ID
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @cExtendedInfo = 'ID: ' + @cID
         END
      END
   END
   
   Quit:
END

GO