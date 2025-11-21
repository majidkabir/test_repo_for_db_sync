SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CheckPalletID_01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check validity of Pallet ID scanned (SOS160310)             */
/*                                                                      */
/* Called from: rdtfnc_NormalReceipt                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-Apr-2010 1.0  James       Created                                 */
/* 17-Dec-2012 1.1  James       SOS263772 - Enhancement (james01)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_CheckPalletID_01] (
   @cPalletID                 NVARCHAR( 18),
   @nValid                    INT          OUTPUT, 
   @nErrNo                    INT          OUTPUT, 
   @cErrMsg     				 NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   SET @nValid = 0

   -- Check if len of pallet id not equal 10 characters
   IF LEN(RTRIM(@cPalletID)) <> 10 
   BEGIN
      GOTO Quit
   END

   IF SUBSTRING(@cPalletID, 1, 2)  <> 'C4'
   BEGIN
      GOTO Quit
   END

   -- (james01)
   IF ISNUMERIC(RIGHT(RTRIM(@cPalletID), 8)) <> 1
   BEGIN
      GOTO Quit
   END

   SET @nValid = 1
   Quit:
END


GO