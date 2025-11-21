SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Decode_Format_YYYYMMDD                          */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: format input value                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 17-08-2023  1.0  Ung       WMS-23172 Created                         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Decode_Format_YYYYMMDD]
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

   -- YYYYMMDD
   IF LEN( @cDate) = 8
   BEGIN
      -- Convert to date
      SET @dDate = TRY_CONVERT( DATETIME, @cDate, 112) -- YYYYMMDD
      
      IF @dDate IS NULL
      BEGIN
         SET @nErrNo = 205451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
         GOTO Quit
      END

      SET @cFieldData = rdt.rdtFormatDate( @dDate)
   END

Quit:

END -- End Procedure


GO