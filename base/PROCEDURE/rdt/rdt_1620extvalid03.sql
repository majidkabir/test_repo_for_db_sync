SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid03                                  */
/* Purpose: Cluster Pick Extended Validate SP for MCD                   */
/*          Only can pick orders with full case or discrete pick        */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 19-Jul-2017 1.0  James      WMS2447 - Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid03] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cUOM           NVARCHAR( 10), 
           @cUserName      NVARCHAR( 18),
           @cLabelPrinter  NVARCHAR( 10),
           @cRPLUOM        NVARCHAR( 10),
           @cPrefUOM       NVARCHAR( 10)

   SET @nErrNo = 0

   SELECT @cUserName = UserName, @cPrefUOM = V_UOM 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         IF ISNULL( @cOrderKey, '') = ''
            GOTO Quit

         -- Only allow to pick pallet/case/loose
         IF @cPrefUOM NOT IN ( '1', '2', '6')
         BEGIN
            SET @nErrNo = 112551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Picker UOM
            GOTO QUIT
         END

         -- Picker can pick pallet/case at the same time but cannot pick loose together
         IF @cPrefUOM = '6' 
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   OrderKey = @cOrderKey
                        AND   [Status] = '0'
                        AND   UOM IN ( '1', '2'))
            BEGIN
               SET @nErrNo = 112552
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix UOM
               GOTO QUIT
            END

            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   OrderKey = @cOrderKey
                            AND   [Status] = '0'
                            AND   UOM = '6')
            BEGIN
               SET @nErrNo = 112553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UOM No Task
               GOTO QUIT
            END
         END

         -- Pallet/case picking need print dispatch label
         IF @cPrefUOM IN ( '1', '2')
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   OrderKey = @cOrderKey
                            AND   [Status] = '0'
                            AND   UOM IN ( '1', '2'))
            BEGIN
               SET @nErrNo = 112554
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UOM No Task
               GOTO QUIT
            END

            -- Get login info
            SELECT @cLabelPrinter = Printer
            FROM rdt.rdtMobrec WITH (NOLOCK) 
            WHERE Mobile = @nMobile

            -- Check label printer blank
            IF @cLabelPrinter = ''
            BEGIN
               SET @nErrNo = 112555
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
               GOTO Quit
            END
         END

         SELECT TOP 1 @cRPLUOM = PD.UOM
         FROM RDT.RDTPICKLOCK RPL (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( RPL.OrderKey = PD.OrderKey AND RPL.StorerKey = PD.StorerKey)
         WHERE RPL.AddWho = @cUserName
         AND   RPL.Status < '9'
         AND   RPL.StorerKey = @cStorerkey
         AND   PD.Status = '0'
         ORDER BY 1

         IF ISNULL( @cRPLUOM, '') <> ''   -- Not the 1st time key in orderkey
         BEGIN
            IF @cPrefUOM IN ( '1', '2') 
            BEGIN
               IF @cRPLUOM NOT IN ('1', '2')
               BEGIN
                  SET @nErrNo = 112556
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix UOM
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               IF @cRPLUOM <> '6'
               BEGIN
                  SET @nErrNo = 112557
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix UOM
                  GOTO Quit
               END
            END
         END
      END

      IF @nStep = 7
      BEGIN
         IF @cPrefUOM = '6' AND ISNULL( @cDropID, '') = ''
         BEGIN
            SET @nErrNo = 112558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Drop ID Req
            GOTO QUIT
         END

         IF @cPrefUOM IN ( '1', '2') AND ISNULL( @cDropID, '') <> ''
         BEGIN
            SET @nErrNo = 112559
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Drop ID Not Req
            GOTO QUIT
         END
      END
   END

QUIT:

GO