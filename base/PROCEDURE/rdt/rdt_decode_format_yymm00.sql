SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Decode_Format_YYMM00                            */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: format input value                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 15-04-2016  1.0  Ung       SOS368437 Created                         */
/* 20-05-2016  1.1  Ung       SOS370219 Migrate to Exceed               */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Decode_Format_YYMM00]
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT, 
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cDecodeCode         NVARCHAR( 30), 
   @cDecodeLineNumber   NVARCHAR( 5), 
   @cFormatSP           NVARCHAR( 50), 
   @cFieldData          NVARCHAR( 60) OUTPUT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDate NVARCHAR( 10)
   DECLARE @dDate DATETIME
   DECLARE @cLastDayOfMonth NVARCHAR(1)

   -- Backup to temp
   SET @cDate = @cFieldData

   -- YYMMDD
   IF LEN( @cDate) = 6
   BEGIN
      -- Last day of month
      IF RIGHT( @cDate, 2) = '00' -- When DD=00
      BEGIN
         SET @cLastDayOfMonth = 'Y'
         SET @cDate = LEFT( @cDate, 4) + '01'
      END
      
      -- Convert to date
      BEGIN TRY
         SET @dDate = CONVERT( DATETIME, @cDate, 12) -- YYMMDD
      END TRY
      BEGIN CATCH
         SET @nErrNo = 98951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
         GOTO Quit
      END CATCH
      
      -- Last day of month
      IF @cLastDayOfMonth = 'Y'
         SET @dDate = DATEADD( d, -1, DATEADD( m, DATEDIFF( m, 0, @dDate) + 1, 0))

      SET @cDate = rdt.rdtFormatDate( @dDate)
   END

   -- Save formatted date in YYYYMMDD
   SET @cFieldData = @cDate

Quit:

END -- End Procedure


GO