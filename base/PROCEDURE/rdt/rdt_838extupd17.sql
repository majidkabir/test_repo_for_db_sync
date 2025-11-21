SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ExtUpd17                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 27-05-2024 1.0  NLT013     FCR-388 Merge code to V2 branch,                */
/*                            original owner is Wojciech                      */
/******************************************************************************/

CREATE   PROC rdt.rdt_838ExtUpd17 (
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

   IF @nStep = 5 -- Print label
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get storer config
         DECLARE @cLOADKEY          NVARCHAR(20)
         DECLARE @cPICKSLIP         NVARCHAR(20)

         SELECT @cLOADKEY = ord.LoadKey 
         FROM ORDERS ord WITH(NOLOCK) 
         INNER JOIN PICKDETAIL pkd (NOLOCK)
            ON ord.StorerKey = pkd.StorerKey
            AND ord.OrderKey = pkd.OrderKey
         WHERE ISNULL(pkd.DropID, '') = @cFromDropID
            AND pkd.StorerKey = @cStorerKey

         SELECT @cPICKSLIP = ph.PickHeaderKey 
         FROM PICKHEADER ph WITH(NOLOCK)
         INNER JOIN PICKDETAIL pkd (NOLOCK)
            ON ph.StorerKey = pkd.StorerKey
            AND ph.OrderKey = pkd.OrderKey
         WHERE ISNULL(pkd.DropID, '') = @cFromDropID
            AND pkd.StorerKey = @cStorerKey

         IF @cOption = 1 -- Yes
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dropid WITH(NOLOCK) WHERE dropid = @cPackDtlDropID)
            BEGIN
               INSERT INTO Dropid(Dropid, Droploc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status
                  ,AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, Loadkey, PickSlipNo, UDF01, UDF02, UDF03, UDF04, UDF05)
               VALUES(@cPackDtlDropID, '', '', 0, 'Y', 0, 5
                  ,GETDATE(), SUSER_NAME(), GETDATE(), SUSER_NAME(), NULL, NULL, @cLOADKEY, @cPICKSLIP, '', '', '', '', '')
            END
            ELSE IF EXISTS (SELECT 1 FROM dropid WITH(NOLOCK) WHERE dropid = @cPackDtlDropID AND LabelPrinted = 'N')
            BEGIN
               UPDATE dropid WITH(ROWLOCK)
               SET LabelPrinted = 'Y'
               WHERE dropid = @cPackDtlDropID
            END
         END
         ELSE IF @cOption = 2
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dropid WITH(NOLOCK) WHERE dropid = @cPackDtlDropID)
            BEGIN
               INSERT INTO Dropid(Dropid, Droploc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status
                  ,AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, Loadkey, PickSlipNo, UDF01, UDF02, UDF03, UDF04, UDF05)
               VALUES(@cPackDtlDropID, '', '', 0, 'N', 0, 5
                  ,GETDATE(), SUSER_NAME(), GETDATE(), SUSER_NAME(), NULL, NULL, @cLOADKEY, @cPICKSLIP, '', '', '', '', '')
            END
         END
      END
   END

Quit:

END

GO