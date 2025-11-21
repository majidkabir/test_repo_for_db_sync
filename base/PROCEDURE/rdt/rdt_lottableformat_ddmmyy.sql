SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LottableFormat_DDMMYY                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Key-in DDMMYY, default year 20                              */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 08-10-2018  1.0  Ung         WMS-6040 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableFormat_DDMMYY]
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

   IF LEN( @cFieldData) = 6
      SET @cFieldData = LEFT( @cFieldData, 4) + '20' + RIGHT( @cFieldData, 2)

Quit:

END -- End Procedure


GO