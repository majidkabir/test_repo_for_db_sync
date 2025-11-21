SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Display SKU pack configuration                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-05-15   James     1.0   WMS-9098 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtInfo01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPackKey       NVARCHAR( 10)
   DECLARE @cPackUOM3      NVARCHAR( 10)
   DECLARE @nPackUOM3Qty   INT

   -- Variable mapping
   SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'


   IF @nStep = 3 -- SKU
   BEGIN
      IF @nInputKey = 1 -- Enter
      BEGIN
         SELECT @cPackKey = PackKey
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo = @cPackKey
      END
   END

   IF @nStep = 5 -- To ID
   BEGIN
      IF @nInputKey = 0 -- Esc
      BEGIN
         SELECT @cPackKey = PackKey
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo = @cPackKey
      END
   END
END
GOTO Quit

Quit:


GO