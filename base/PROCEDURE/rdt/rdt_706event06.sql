SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Store procedure: rdt_706Event06                                          */
/*                                                                          */
/* Modifications log:                                                       */
/*                                                                          */
/* Date       Rev  Author    Purposes                                       */
/* 2023-08-17 1.0  yeekung   WMS-23281 Created                              */
/* 2023-09-18 1.1  Ung       WMS-23281 Change ListName (other SP is using)  */
/****************************************************************************/

CREATE   PROC [RDT].[rdt_706Event06] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cOption       NVARCHAR( 1),
   @cRetainValue  NVARCHAR( 10),
   @cTotalCaptr   INT           OUTPUT,
   @nStep         INT           OUTPUT,
   @nScn          INT           OUTPUT,
   @cLabel1       NVARCHAR( 20) OUTPUT,
   @cLabel2       NVARCHAR( 20) OUTPUT,
   @cLabel3       NVARCHAR( 20) OUTPUT,
   @cLabel4       NVARCHAR( 20) OUTPUT,
   @cLabel5       NVARCHAR( 20) OUTPUT,
   @cValue1       NVARCHAR( 60) OUTPUT,
   @cValue2       NVARCHAR( 60) OUTPUT,
   @cValue3       NVARCHAR( 60) OUTPUT,
   @cValue4       NVARCHAR( 60) OUTPUT,
   @cValue5       NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @cExtendedinfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSerialNo         NVARCHAR( 60)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cTrackingNo       NVARCHAR( 20)
   DECLARE @cUserName         NVARCHAR( 20)
   DECLARE @cTableName        NVARCHAR( 20)
   DECLARE @nRowRef           INT
   DECLARE @bSuccess          INT

   -- Parameter mapping
   SET @cSerialNo = @cValue1
   SET @cTrackingNo = @cValue2

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep =2
   BEGIN
      IF @nInputKey='1'
      BEGIN

         IF ISNULL(@cSerialNo,'')=''
         BEGIN
            SET @nErrNo = 205351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNONeeded
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SerialNo
            GOTO Quit
         END


         IF LEN(@cSerialNo)=24
         BEGIN
            DECLARE @CBinary NVARCHAR(2000)
            DECLARE @cDecimal INT
            DECLARE @cAltSKU  NVARCHAR(60)

            SET @CBinary = rdt.rdt_ConvertHexToBinary(trim(@cSerialNo))

            SET @cAltSKU = rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,15,24))
            SET @cAltSKU = @cAltSKU +  RIGHT ('0000'+ CAST (rdt.rdt_ConvertBinaryToDec(SUBSTRING(@CBinary,39,20)) AS NVARCHAR(60)),5)

            SELECT @cSKU = sku
            FROM SKU (NOLOCK)
            WHERE Storerkey = @cStorerkey
            and ALTSKU like @cAltSKU + '%'
            AND SerialNoCapture ='1'
         END
         ELSE
         BEGIN
            SET @cSKU = SUBSTRING(@cSerialNo,1,20)
            SET @cSerialNo = ''
         END

         IF NOT EXISTS ( SELECT 1
                     FROM SKU (NOLOCK)
                     WHERE SKU = @cSKU
                        AND Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 205353
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvSKU
            EXEC rdt.rdtSetFocusField @nMobile,2 -- SKU
            GOTO Quit
         END

         IF ISNULL(@cTrackingNo,'')=''
         BEGIN
            SET @nErrNo = 205354
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackingNeeded
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- TrackingNO
            GOTO Quit
         END

         --IF EXISTS ( SELECT 1 FROM rdt.rdtDataCapture (NOLOCK)
         --            WHERE Storerkey = @cStorerKey
         --               AND facility = @cFacility
         --               AND V_SKU = @cSKU
         --               AND SerialNo = @cSerialNo)
         --BEGIN
         --   SET @nErrNo = 205355
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateSNo
         --   EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
         --   GOTO Quit
         --END

         INSERT INTO rdt.rdtDataCapture( StorerKey, Facility, V_SKU, serialno, V_String1,V_String2, AddWho, AddDate) VALUES
         ( @cStorerKey, @cFacility, @cSKU, @cSerialNo, @cTrackingNo, '706', @cUserName, GETDATE())

         SELECT @nRowRef = SCOPE_IDENTITY()

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 205356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Rec Fail
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END

         SELECT @cTableName = ISNULL( Long, '')
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = 'RDTINSTL2A'
            AND StorerKey = @cStorerKey
            AND Code = @cFacility
            AND Code2 = @nFunc
            AND Short = 'EventCap'

         -- Interface
         IF @@ROWCOUNT > 0 AND @cTableName <> '' AND @cSerialNo <> ''
            EXEC ispGenTransmitLog2 @cTableName, @nRowRef, 0, @cStorerKey, ''
               ,@bSuccess OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
         SET @cTotalCaptr = @cTotalCaptr + 1

         SET @cValue1 = ''
         SET @cValue2 = ''
      END
   END

   Quit:

GO