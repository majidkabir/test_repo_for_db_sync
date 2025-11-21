SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal13                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2022-07-15 1.0  yeekung   WMS-19593 Created                          */
/* 2023-03-23 1.1  Ung       WMS-22076 Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtVal13] (
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

   DECLARE @cLoadKey NVARCHAR( 10)
   DECLARE @cUPC NVARCHAR(30)

   
   DECLARE @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20) 

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED 
   )

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 1 -- PSNO
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check site is blank
            IF @cPackDtlDropID = ''
            BEGIN
               SET @nErrNo = 188551
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need site
               EXEC rdt.rdtSetFocusField @nMobile, 3  -- ToDropID
               GOTO Quit
            END

            -- Check site valid
            IF NOT EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'Allsorting' AND Code = @cPackDtlDropID AND StorerKey = @cStorerKey)
            BEGIN
               SET @nErrNo = 188552
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid site
               EXEC rdt.rdtSetFocusField @nMobile, 3  -- ToDropID
               GOTO Quit
            END
        
            DECLARE @cOrderKey   NVARCHAR( 10)
            DECLARE @cZone       NVARCHAR( 18)
            DECLARE @cPickStatus NVARCHAR( 1)
            DECLARE @nPackQTY    INT
            DECLARE @nPickQTY    INT

            SET @cOrderKey = ''
            SET @cLoadKey = ''
            SET @cZone = ''
            SET @nPackQTY = 0
            SET @nPickQTY = 0
               
      -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            INSERT INTO @tPickZone (PickZone)
            SELECT DISTINCT code2
            FROM dbo.CodelkUp WITH (NOLOCK)
            WHERE ListName = 'ALLSorting'
               AND StorerKey = @cStorerKey
               AND Code = @cPackDtlDropID

            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
            BEGIN
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                     JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.DropID = @cFromDropID
                     AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 188554
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
                  EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
                  GOTO Quit
               END               
            END
                 
            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1
                  FROM dbo.PickDetail PD WITH (NOLOCK) 
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                     JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.StorerKey = @cStorerKey
                     AND PD.DropID = @cFromDropID
                     AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 188555
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
                  EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
                  GOTO Quit
               END
            END
            
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
            BEGIN
               -- Check SKU in PickSlipNo
               IF @cFromDropID = ''
               BEGIN
                  IF NOT EXISTS( SELECT TOP 1 1 
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                        JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                        JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
                     WHERE LPD.LoadKey = @cLoadKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.QTY > 0)
                  BEGIN
                     SET @nErrNo = 188556
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
                     EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
                     GOTO Quit
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS( SELECT TOP 1 1 
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                        JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                        JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
                     WHERE LPD.LoadKey = @cLoadKey
                        AND PD.StorerKey = @cStorerKey
                        AND PD.DropID = @cFromDropID
                        AND PD.QTY > 0)
                  BEGIN
                     SET @nErrNo = 188556
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
                     EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
                     GOTO Quit
                  END
               END
            END

            -- Custom PickSlip
            ELSE
            BEGIN
               -- Check SKU in PickSlipNo
               IF NOT EXISTS( SELECT TOP 1 1 
                  FROM dbo.PickDetail PD (NOLOCK) 
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                     JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND PD.DropID = @cFromDropID
                     AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 188557
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID NotInPS
                  EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
                  GOTO Quit
               END
            END
         END
      END    
      
      IF @nStep = 2 -- Statistics
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get user info
            DECLARE @cUserGroup NVARCHAR( 60)
            SELECT @cUserGroup = OPSPosition FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
            
            -- Check user allowed
            IF @cUserGroup = 'GROUP1' AND @cOption <> '1'
            BEGIN
               SET @nErrNo = 188562
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionNotAllow
               GOTO Quit
            END
         END
      END

      IF @nStep = 3 -- capture pack data
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN

            SELECT @cUPC=I_Field03
            FROM Rdt.rdtmobrec (nolock)
            where Mobile=@nMobile


            IF EXISTS (SELECT 1 FROM packdetail (NOLOCK)
                       where pickslipno=@cPickSlipNo
                       AND UPC <>''
                       AND storerkey=@cstorerkey
                       and cartonno=@nCartonNo) 
            BEGIN
               SET @nErrNo = 188561
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO QUIT
            END
            ELSE IF  EXISTS (SELECT 1 FROM packdetail (NOLOCK)
                       where pickslipno=@cPickSlipNo
                       AND UPC =''
                       AND storerkey=@cstorerkey
                       and cartonno=@nCartonNo)  AND
                     EXISTS (SELECT 1 from UPC (NOLOCK)
                              where UPC=@cUPC 
                              AND storerkey=@cStorerKey)
            BEGIN
               SET @nErrNo = 188562
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
               GOTO QUIT
            END
         END
      END

       IF @nStep = 6
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption = '1'
            BEGIN
               -- Get PackDetail info
               SELECT TOP 1 
                  @cPickSlipNo = PickSlipNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cFromDropID      

               SELECT @cLoadKey = LoadKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
            
               SELECT @cOrderKey = OrderKey
               FROM dbo.LoadPlanDetail WITH (NOLOCK)
               WHERE LoadKey = @cLoadKey
      
               IF EXISTS ( SELECT 1 FROM dbo.Storer ST WITH (NOLOCK)
                           JOIN dbo.Orders O WITH (NOLOCK) ON ( ST.StorerKey = O.ConsigneeKey)
                           WHERE O.OrderKey = @cOrderKey
                           AND   ST.[type] = '2'
                           AND   ST.SUSR3 = 'PL')
               BEGIN
                  SET @nErrNo = 0  
                  SET @cErrMsg1 = rdt.rdtgetmessage( 188559, @cLangCode, 'DSP') --Packing List,  
                  SET @cErrMsg2 = rdt.rdtgetmessage( 122310, @cLangCode, 'DSP') --Not Allow To Print  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
                  IF @nErrNo = 1  
                  BEGIN  
                     SET @cErrMsg1 = ''  
                     SET @cErrMsg2 = ''  
                  END  
                  SET @nErrNo = 122310
                  SET @cErrMsg = @cErrMsg2
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO