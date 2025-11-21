SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_Lottable02chk_VLT                                 */
/*                                                                        */
/* Purpose: Creates IVAS AND adds to a SKU. Checks if pal type is valid.  */
/*                                                                        */
/*                                                                        */
/* Date        Author                                                     */
/* 4/23/2024   Vikas + PPA374                                             */
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Lottable02chk_VLT]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cYearCode   NVARCHAR(2)
   DECLARE @cWeekCode   NVARCHAR(2)
   DECLARE @cDayCode    NVARCHAR(1)
   DECLARE @nShelfLife  INT
   DECLARE @nYearNum    INT
   DECLARE @nWeekNum    INT
   DECLARE @nDayNum     INT
   DECLARE @cYear       NVARCHAR(4)
   DECLARE @cMonth      NVARCHAR(2)
   DECLARE @cProdDate   NVARCHAR(30)
   DECLARE @dProdDate   DATETIME
   DECLARE @cTempLottable04   NVARCHAR( 60)
   DECLARE @cTempLottable13   NVARCHAR( 60)
   DECLARE @cSUSR2            NVARCHAR( 18)
   DECLARE @cErrMessage       NVARCHAR( 20)
   DECLARE @IVASCode        NVARCHAR( MAX)
   DECLARE @IVAS           NVARCHAR( MAX)

   SET @nErrNo = 0

   SELECT TOP 1 @IVAS = IVAS FROM sku WITH (NOLOCK) WHERE SKU = @cSKU AND StorerKey = @cStorerKey

   SELECT TOP 1 @IVASCode = cast(Pallet as NVARCHAR(max))+' EA on PALLET' FROM PACK WITH (NOLOCK) WHERE PackKey = (SELECT TOP 1 PackKey FROM sku WITH (NOLOCK) WHERE sku = @cSKU AND StorerKey = @cStorerKey)

   IF NOT EXISTS (SELECT TOP 1 1 FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'IVAS' AND Code = @IVASCode) AND @cStorerKey = 'HUSQ'
   BEGIN
      INSERT INTO CODELKUP (LISTNAME, code, description, short, long, notes, AddDate, AddWho, EditDate, EditWho, TrafficCop, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, code2)
      VALUES ('IVAS',@IVASCode,@IVASCode,'','','',getdate(),   SUSER_NAME(),getdate(),SUSER_NAME(),NULL,'','HUSQ','','','','','','')
   END

   IF @cStorerKey = 'HUSQ' AND isnull(@IVAS,'')='' 
      UPDATE SKU
      SET IVAS = @IVASCode
      WHERE sku = @cSKU
      AND storerkey = @cStorerKey

   IF @cType = 'PRE' AND @cStorerKey = 'HUSQ'
   BEGIN
      SET @cLottable02 = ''

      GOTO Quit
   END

   IF ISNULL( @cLottable02Value , '') <> '' AND @cStorerKey = 'HUSQ'
   BEGIN
      SET @cLottable02 = @cLottable02Value
   END

   IF @nLottableNo = 2 AND ISNULL( @cLottable02Value, '') NOT in 
      (SELECT Code FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'HUSQPALTYP' AND Storerkey = @cStorerKey) 
      AND @cStorerKey = 'HUSQ'
   BEGIN
      IF @cLottable02Value = ''
      BEGIN
         SET @nErrNo = 217947
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValueNeeded
         SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
      END
     
      ELSE
      BEGIN
         SET @nErrNo = 217948
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidType
         SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
      END
   END

   Validate_Lottable:

   Quit:

END -- End Procedure

GO