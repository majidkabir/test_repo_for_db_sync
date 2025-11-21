SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal15                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Validate pallet closed, validate duplicate refno,           */
/*          not allow close pallet if not all case id scanned           */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2022-06-22  1.0  James     WMS-19694 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal15] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cRefNo      NVARCHAR( 20)
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cChkCaseId  NVARCHAR( 20)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cOption     NVARCHAR( 1)
   DECLARE @nCanClosePlet  INT = 0
   DECLARE @nActTtLCaseId  INT = 0
   DECLARE @nScannedCaseId INT = 0
   DECLARE @nTtLCaseId     INT = 0
      
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
   	IF @nStep = 1
   	BEGIN
   		IF @nInputKey = 1
   		BEGIN
   			IF EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) 
   			            WHERE StorerKey = @cStorerkey 
   			            AND   PalletKey = @cPalletKey 
   			            AND   [Status] = '9')
            BEGIN
               SET @nErrNo = 187451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PALLET CLOSED
               GOTO Quit
            END
   		END
   	END
   	
      IF @nStep = 6 -- Packinfo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cRefNo = I_Field04
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF ISNULL( @cRefNo, '') = ''
            BEGIN
               SET @nErrNo = 187452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NEED TRACKNO
               GOTO Quit
            END
            
            -- Retrieve current pickslipno
            SELECT TOP 1 @cPickSlipNo = PickSlipNo
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   LabelNo = @cCaseID
            ORDER BY 1

            IF EXISTS ( SELECT 1 FROM dbo.PackInfo PIF WITH (NOLOCK) 
                        WHERE TrackingNo = @cRefNo
                        AND   EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                                       WHERE PIF.PickSlipNo = PD.PickSlipNo 
                                       AND   PD.StorerKey = @cStorerkey))
            BEGIN
               SET @nErrNo = 187453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --TRACKNO EXIST
               GOTO Quit
            END
         END
      END
      
      IF @nStep = 7
      BEGIN
      	IF @nInputKey = 1
      	BEGIN
      		SELECT @cOption = I_Field01
      		FROM rdt.RDTMOBREC WITH (NOLOCK)
      		WHERE Mobile = @nMobile
      		
      		IF @cOption <> '1'
      		   GOTO Quit

            DECLARE @tOrd TABLE
            (
               Seq       INT IDENTITY(1,1) NOT NULL,
               OrderKey  NVARCHAR( 10)
            )
   
      		DECLARE @curChk CURSOR
      		SET @curChk = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      		SELECT DISTINCT CaseId 
      		FROM dbo.PALLETDETAIL WITH (NOLOCK)
      		WHERE PalletKey = @cPalletKey
      		AND   StorerKey = @cStorerkey
      		OPEN @curChk
      		FETCH NEXT FROM @curChk INTO @cChkCaseId
      		WHILE @@FETCH_STATUS = 0
      		BEGIN
               -- Retrieve current pickslipno
               SELECT TOP 1 @cPickSlipNo = PickSlipNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   LabelNo = @cChkCaseId
               ORDER BY 1

               SELECT @cOrderKey = OrderKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               
               IF NOT EXISTS ( SELECT 1 FROM @tOrd WHERE OrderKey = @cOrderKey)
               BEGIN
                  -- Retrieve how many case need to scan
                  SELECT @nTtLCaseId = COUNT( DISTINCT LABELNO)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
               	
               	SET @nActTtLCaseId = @nActTtLCaseId + @nTtLCaseId
               	
               	INSERT INTO @tOrd	(OrderKey) VALUES	( @cOrderKey)
               END
      
      			FETCH NEXT FROM @curChk INTO @cChkCaseId
      		END
      		
            -- Retrieve scanned how many case so far
            SELECT @nScannedCaseId = COUNT( DISTINCT CASEID)
            FROM dbo.PALLETDETAIL WITH (NOLOCK)
            WHERE PalletKey = @cPalletKey

            -- Check if scanned + current to be scanned equal to actual case needed
            IF @nScannedCaseId <> @nActTtLCaseId 
            BEGIN
               SET @nErrNo = 187454
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SCAN ALL CASE
               GOTO Quit
            END
      	END
      END
   END
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO