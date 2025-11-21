SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_860ExtValid01                                   */
/* Purpose: Validate Drop ID cannot be blank                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-06-30   James     1.0   SOS309001 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860ExtValid01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cSuggLOC        NVARCHAR( 10)
   ,@cLOC            NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cDropID         NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@nTaskQTY        INT
   ,@nPQTY           INT
   ,@cUCC            NVARCHAR( 20)
   ,@cOption         NVARCHAR( 1)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)

   -- For checking in 
   -- 860 (Pick SKU/UPC)
   -- 862 (Pick Pallet)
   -- No need check for 863 (Pick Drop ID) as already checked within rdtfnc_Pick
   IF @nFunc IN (860, 862) 
   BEGIN
      IF @nStep = 2 -- DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check blank
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 55251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
            END
         END
      END
   END
END

Quit:

GO