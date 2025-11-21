SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573TrackCarton01                                */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 24-01-2022  1.0  Ung      WMS-18776 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_573TrackCarton01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR(3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR(15),
   @cFacility        NVARCHAR(5),
   @cReceiptKey1     NVARCHAR(20),
   @cReceiptKey2     NVARCHAR(20),
   @cReceiptKey3     NVARCHAR(20),
   @cReceiptKey4     NVARCHAR(20),
   @cReceiptKey5     NVARCHAR(20),
   @cLoc             NVARCHAR(20),
   @cID              NVARCHAR(18),
   @cUCC             NVARCHAR(20),
   @cTrackCartonType NVARCHAR(10)   OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR(1024) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 573
   BEGIN
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtConReceiveLog L WITH (NOLOCK)
            JOIN dbo.Receipt R WITH (NOLOCK) ON (L.ReceiptKey = R.ReceiptKey)
         WHERE L.Mobile = @nMobile
            AND R.RecType = 'CASEPACK')
         SET @cTrackCartonType = '1'
      ELSE
         SET @cTrackCartonType = '0'
   END
END


GO