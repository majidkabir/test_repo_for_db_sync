SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1653DecodeSP02                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_TrackNo_SortToPallet                             */
/*                                                                      */
/* Purpose: Decode tracking no and return orderkey                      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2021-08-24  1.0  James    WMS-17773. Created                         */
/* 2021-09-30  1.1  LZG      JSM-23695 - Initialize @nErrNo to avoid    */
/*                           misbehavior in parent script (ZG01)        */
/* 2022-01-03  1.2  James    WMS-18616 Enhance decode method (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_1653DecodeSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 100),
   @cTrackNo       NVARCHAR( 40)  OUTPUT,
   @cOrderKey      NVARCHAR( 10)  OUTPUT,
   @cLabelNo       NVARCHAR( 20)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cInTrackNo     NVARCHAR( 40) = ''

   DECLARE @cPrefix     NVARCHAR( 10)
   DECLARE @cUDF01       NVARCHAR( 10)
   DECLARE @cUDF02       NVARCHAR( 10)
   DECLARE @cUDF03       NVARCHAR( 10)
   
   IF @nStep = 1
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
         DECLARE @curDecode   CURSOR
         SET @curDecode = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Code, UDF01, UDF02, UDF03
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'TrackTrim'
         AND   Storerkey = @cStorerKey
         OPEN @curDecode
         FETCH NEXT FROM @curDecode INTO @cPrefix, @cUDF01, @cUDF02, @cUDF03
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF CHARINDEX( @cPrefix, @cBarcode) = 0 OR
               LEN( @cBarcode) <= CAST( @cUDF01 AS INT)
            BEGIN
               SET @cInTrackNo = ''
               GOTO FETCHNEXT
            END
            ELSE
            BEGIN
      	      SET @cInTrackNo = REPLACE( SUBSTRING( RTRIM( @cBarcode), CAST( @cUDF01 AS INT), CAST( @cUDF03 AS INT)), ' ', '')
      	      BREAK
            END
      
   	      FETCHNEXT:
   	      FETCH NEXT FROM @curDecode INTO @cPrefix, @cUDF01, @cUDF02, @cUDF03
         END

         IF @cInTrackNo = ''
            SET @cInTrackNo = @cBarcode
      
         SET @nErrNo = 0   -- ZG01
         SET @cOrderKey = ''
         SET @cLabelNo = '' -- ZG01
   
         SELECT @cLabelNo = LabelNo
         FROM dbo.CartonTrack WITH (NOLOCK)
         WHERE TrackingNo = @cInTrackNo
         AND   KeyName = @cStorerKey

         IF ISNULL( @cLabelNo, '') = ''
            GOTO Fail

         SELECT TOP 1 @cOrderKey = PH.OrderKey
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PD.LabelNo = @cLabelNo
         AND   PH.StorerKey = @cStorerKey
         ORDER BY 1

         SET @cTrackNo = @cInTrackNo
      END
   END

Fail:
END

GO