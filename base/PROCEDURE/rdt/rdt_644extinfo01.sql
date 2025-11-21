SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_644ExtInfo01                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Show station id & position                                  */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-03-24  1.0  James       WMS-12432. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_644ExtInfo01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cParentTrackID NVARCHAR( 20),
   @cChildTrackID  NVARCHAR( 1000),
   @cSKU           NVARCHAR( 10),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT     
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine02  NVARCHAR( 30) = ''
   DECLARE @cDeviceID      NVARCHAR( 20) = ''
   DECLARE @cPosition      NVARCHAR( 20) = ''

   SELECT @cUserDefine02 = UserDefine02
   FROM dbo.RECEIPT WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
         
   IF @nStep = 1 -- ASN, Ref no
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cUserDefine02, '') = ''
            GOTO Quit

         SELECT @cDeviceID = DeviceID
         FROM dbo.DeviceProfile WITH (NOLOCK)
         WHERE DeviceID = @cUserDefine02
         AND   StorerKey = @cStorerKey
         
         SET @cExtendedInfo = 'STATION: ' + @cDeviceID
      END
   END

   IF @nStep IN ( 3, 4)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cPosition = UserDefine01
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   SKU = @cSKU
         AND   UserDefine01 <> ''
         ORDER BY 1
         
         IF ISNULL( @cPosition, '') = ''
         BEGIN
            SELECT TOP 1 @cPosition = D.DevicePosition
            FROM dbo.DeviceProfile D WITH (NOLOCK)
            WHERE D.DeviceID = @cUserDefine02
            AND   D.StorerKey = @cStorerKey
            AND   NOT EXISTS ( SELECT 1 FROM dbo.TrackingID T WITH (NOLOCK)
                               WHERE T.ReceiptKey = @cReceiptKey
                               AND   T.UserDefine01 = D.DevicePosition
                               AND   T.UserDefine02 = '')
            ORDER BY 1
         END
         
         SET @cExtendedInfo = 'LOC: ' + @cPosition
      END
   END

Quit:
END

GO