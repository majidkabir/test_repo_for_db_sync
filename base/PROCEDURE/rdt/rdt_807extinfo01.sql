SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_807ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Called from: rdtfnc_PACart                                           */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 2019-01-25 1.0  James      WMS-5639 Created (james01)                */
/************************************************************************/

CREATE PROC [RDT].[rdt_807ExtInfo01] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLOC  NVARCHAR(10)
   DECLARE @cMsg NVARCHAR(20)

   IF @nFunc = 807 -- PA Cart
   BEGIN
      IF @nAfterStep = 4 -- Qty
      BEGIN
         -- Variable mapping
         SELECT @cLOC = Value FROM @tVar WHERE Variable = '@cLOC'
            
         SET @cMsg = rdt.rdtgetmessage( 134001, @cLangCode, 'DSP') --LOC: 

        SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + @cLOC
      END
   END

Quit:

END

GO