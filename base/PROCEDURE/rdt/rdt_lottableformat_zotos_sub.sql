SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_Zotos_Sub                              */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Generate expiry date base on code                                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 09-09-2017  Ung       1.0   WMS-2963 New decode logic                      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_Zotos_Sub]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cMonthYearCode   NVARCHAR( 2), 
   @cLottable        NVARCHAR( 60) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMonth NVARCHAR(2)
   DECLARE @cYear  NVARCHAR(4)

   -- Check valid length
   IF LEN( RTRIM( LTRIM( @cMonthYearCode))) <> 2
      GOTO Quit

   -- Get month, year
   SELECT 
      @cMonth = Short, 
      @cYear = Long
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTDecode'
      AND Code = 'ZETOS'
      AND Code2 = @cMonthYearCode
      AND StorerKey = @cStorerKey
   
   IF @@ROWCOUNT = 0
      GOTO Quit
      
   -- Generate date
   SET @cLottable = '01' + '/' + @cMonth +  '/' + @cYear
   
   -- Check date valid
   IF rdt.rdtIsValidDate( @cLottable) = 0
      SET @cLottable = ''

Quit:

END

GO