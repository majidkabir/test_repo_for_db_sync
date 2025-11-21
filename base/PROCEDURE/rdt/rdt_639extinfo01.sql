SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Show sku packkey                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2020-02-21   James     1.0   WMS-12070. Created                            */
/* 2023-02-17   Ung       1.1   WMS-21506 Add AfterStep, Lottables param      */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_639ExtInfo01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR(3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR(15),
   @cFacility       NVARCHAR(5),
   @cToLOC          NVARCHAR(10),
   @cToID           NVARCHAR(18),
   @cFromLOC        NVARCHAR(10),
   @cFromID         NVARCHAR(18),
   @cSKU            NVARCHAR(20),
   @nQTY            INT,
   @cUCC            NVARCHAR(20),
   @cLottable01     NVARCHAR(18),
   @cLottable02     NVARCHAR(18),
   @cLottable03     NVARCHAR(18),
   @dLottable04     DATETIME,
   @dLottable05     DATETIME,
   @cLottable06     NVARCHAR(18),
   @cLottable07     NVARCHAR(18),
   @cLottable08     NVARCHAR(18),
   @cLottable09     NVARCHAR(18),
   @cLottable10     NVARCHAR(18),
   @cLottable11     NVARCHAR(18),
   @cLottable12     NVARCHAR(18),
   @dLottable13     DATETIME,
   @dLottable14     DATETIME,
   @dLottable15     DATETIME,
   @tExtInfoVar     VariableTable READONLY,
   @cExtendedInfo   NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPackKey    NVARCHAR( 10)

   IF @nStep IN ( 5, 6) -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ESC
      BEGIN
         SELECT @cPackKey = PackKey
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   Sku = @cSKU

         SET @cExtendedInfo = 'PACKKEY: ' + @cPackKey
      END
   END

Quit:

END

GO