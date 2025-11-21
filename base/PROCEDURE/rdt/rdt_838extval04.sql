SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal04                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 04-04-2018 1.0  Ung         WMS-8134 Created                         */
/* 13-08-2019 1.1  James       WMS-10030 Add check packdl refno(james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_838ExtVal04] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED 
   )

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
         BEGIN
            -- 1 dropid only 1 refno
            IF EXISTS ( SELECT 1 
                        FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   RefNo = @cRefNo
                        GROUP BY RefNo
                        HAVING COUNT( DISTINCT DropID) > 1)
            BEGIN
               SET @nErrNo = 137402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --> 1 Refno
               EXEC rdt.rdtSetFocusField @nMobile, 4  -- REFNO
               GOTO Quit
            END
         END
      END

      IF @nStep = 10 -- Pack data
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check LOT# is blank
            IF @cPackData1 = ''
            BEGIN
               SET @nErrNo = 137401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOT#
               EXEC rdt.rdtSetFocusField @nMobile, 1  -- LOT#
               GOTO Quit
            END
         END
      END    
   END

Quit:

END

GO