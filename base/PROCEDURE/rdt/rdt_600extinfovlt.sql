SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_600ExtInfoVLT                                  */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 01/05/2024   PPA374  1.0   Predict putaway zone                      */
/* 15/07/2024   PPA374  2.0   Predict putaway zone with new logic       */
/* 18/10/2024   PPA374  2.1   Formatted                                 */
/************************************************************************/
CREATE   PROC [RDT].[rdt_600ExtInfoVLT]
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nAfterStep         INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @cReceiptKey        NVARCHAR( 10),
   @cPOKey             NVARCHAR( 10),
   @cLOC               NVARCHAR( 10),
   @cID                NVARCHAR( 18),
   @cSKU               NVARCHAR( 20),
   @cLottable01        NVARCHAR( 18),
   @cLottable02        NVARCHAR( 18),
   @cLottable03        NVARCHAR( 18),
   @dLottable04        DATETIME,
   @dLottable05        DATETIME,
   @cLottable06        NVARCHAR( 30),
   @cLottable07        NVARCHAR( 30),
   @cLottable08        NVARCHAR( 30),
   @cLottable09        NVARCHAR( 30),
   @cLottable10        NVARCHAR( 30),
   @cLottable11        NVARCHAR( 30),
   @cLottable12        NVARCHAR( 30),
   @dLottable13        DATETIME,
   @dLottable14        DATETIME,
   @dLottable15        DATETIME,
   @nQTY               INT,
   @cReasonCode        NVARCHAR( 10),
   @cSuggToLOC         NVARCHAR( 10),
   @cFinalLOC          NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @cExtendedInfo      NVARCHAR(20)  OUTPUT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nstep = 5
   BEGIN
      --Establish an LPN type
      DECLARE 
         @LPNPATYPE NVARCHAR(20),
         @ABC       NVARCHAR(3)

     SELECT TOP 1 @ABC = ABC FROM dbo.SKU (NOLOCK) WHERE sku = @cSKU AND StorerKey = @cStorerKey

      --Shelf
      IF (SELECT TOP 1 Style FROM dbo.sku (NOLOCK) WHERE sku = @cSKU AND StorerKey = @cStorerKey) = 'SHLV'
      BEGIN
         SET @LPNPATYPE = 'Shelf'
         SET @cExtendedInfo = 'PA Target: Trolley'
         GOTO Quit
      END

      --Battery
      IF (SELECT TOP 1 Style FROM dbo.SKU (NOLOCK) WHERE sku = @cSKU AND StorerKey = @cStorerKey) = 'B'
      BEGIN
         SET @LPNPAType = 'Battery' 
         GOTO BatterySkip
      END

      --VelocityA
      ELSE IF @ABC = 'A'
      BEGIN
         SET @LPNPAType = 'VelocityA' 
      END

      --VelocityB
      ELSE IF @ABC = 'B'
      BEGIN
         SET @LPNPAType = 'VelocityB' 
      END

      --VelocityC
      ELSE IF @ABC = 'C'
      BEGIN
         SET @LPNPAType = 'VelocityC' 
      END
   
      --VelocityE
      ELSE IF @ABC = 'E'
      BEGIN
         SET @LPNPAType = 'VelocityE' 
      END

      ELSE --If LPN type could not be established
      BEGIN
         SET @LPNPATYPE ='UNKNOWN'
      END

     BatterySkip:
      --Giving predicted area for the putaway based on the SKU.
      SET @cExtendedInfo = 
      (SELECT TOP 1 CASE WHEN 'VNA' IN (SELECT Short FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'HUSQLPNTYP' AND UDF01 = @LPNPATYPE AND Storerkey = @cStorerKey) 
      AND 'WA' IN (SELECT Short FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'HUSQLPNTYP' AND UDF01 = @LPNPATYPE AND Storerkey = @cStorerKey) 
      THEN 'PA target: VNA or WA'
      WHEN 'WA' IN (SELECT Short FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'HUSQLPNTYP' AND UDF01 = @LPNPATYPE AND Storerkey = @cStorerKey) 
      THEN 'PA target: WA'
      WHEN 'VNA' IN (SELECT Short FROM dbo.CODELKUP (NOLOCK) WHERE LISTNAME = 'HUSQLPNTYP' AND UDF01 = @LPNPATYPE AND Storerkey = @cStorerKey) 
      THEN 'PA target: VNA' ELSE 'Unknown PA target' END)
   END
Quit:
END

GO