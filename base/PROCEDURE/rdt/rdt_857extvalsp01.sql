SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_857ExtValSP01                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Call From rdtfnc_Driver_CheckIn                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author    Purposes                                  */
/* 2020-10-22  1.0  Chermaine WMS-15495 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_857ExtValSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cStorerKey     NVARCHAR(15),
   @cContainerNo   NVARCHAR(20),
   @cAppointmentNo NVARCHAR(20),
   @nInputKey      INT,
   @cActionType    NVARCHAR( 10),
   @cInField04     NVARCHAR( 20),
   @cInField06     NVARCHAR( 20),
   @cInField08     NVARCHAR( 20),
   @cInField10     NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   IF @nFunc = 857
   BEGIN
      IF @nStep = 1  -- Display Information
      BEGIN
         IF NOT EXISTS (SELECT TOP 1 1 FROM Booking_out WITH (NOLOCK) WHERE AltReference = @cAppointmentNo OR BookingNo = @cAppointmentNo )
         BEGIN
            SET @nErrNo = 160301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidApptNo
            GOTO Quit
         END
      END
    END
    
Quit:
END
SET QUOTED_IDENTIFIER OFF

GO