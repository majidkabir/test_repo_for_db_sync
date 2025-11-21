SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtDSGPickExtVal                                    */
/* Purpose: Send command to Junheinrich direct equipment to location    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-06-10   Ung       1.0   SOS307606 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtDSGPickExtVal]
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

   IF @nFunc = 860 -- Pick SKU/UPC
   BEGIN
      IF @nStep = 2 -- DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check blank
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 89951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
            END
         END
      END
   END

   IF @nFunc = 862 -- Pick pallet
   BEGIN
      IF @nStep = 6 -- ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get SKU info
            DECLARE @cBUSR2 NVARCHAR(30)
            SELECT 
               CASE BUSR2
                  WHEN 'PALLET' THEN 'RM-PALLET' -- Raw material, pick by pallet
                  WHEN 'CRTID'  THEN 'RM-CASE'   -- Raw material, pick by case
                  ELSE 'FG'                      -- Finish good,  pick by pallet
               END
            FROM SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU

            -- RM carton, must provide drop ID
            IF @cBUSR2 = 'CRTID' AND @cDropID = ''
            BEGIN
               SET @nErrNo = 89952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
            END

            -- RM pallet, FG pallet, don't need drop ID
            IF @cBUSR2 IN ('RM-PALLET', 'FG') AND @cDropID <> ''
            BEGIN
               SET @nErrNo = 89953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DontNeedDropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
            END
         END
      END
   END
END

Quit:

GO