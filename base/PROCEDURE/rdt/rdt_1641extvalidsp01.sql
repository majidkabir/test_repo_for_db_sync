SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtValidSP01                                */
/* Purpose: Validate Pallet DropID                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-02-10 1.2  ChewKP     SOS#293509 Created                        */
/* 2014-10-21 1.3  ChewKP     SOS#323750 Additional Validation(ChewKP01)*/
/* 2014-12-17 1.4  Ung        SOS325485 Move out custom code to here    */
/* 2015-06-11 1.5  ChewKP     Remove TraceInfo (ChewKP02)               */
/* 2015-07-06 1.6  ChewKP     Performance Tuning (ChewKP03)             */
/* 2016-08-07 1.7  Ung        Performance Tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1641
BEGIN
   IF @nStep = 3
   BEGIN
      DECLARE
           @cConsigneeKey       NVARCHAR(15)
         , @cPalletConsigneeKey NVARCHAR(15)
         , @cChildID            NVARCHAR(20)
         , @cUCCConsigneeKey    NVARCHAR(15)
         , @cOrderType          NVARCHAR(20)
         , @nCountConsigneeKey  INT
         , @cLoadKey            NVARCHAR(10)
     

      SET @nErrNo              = 0
      SET @cErrMSG             = ''
      SET @cConsigneeKey       = ''
      SET @cChildID            = ''
      SET @cPalletConsigneeKey = ''
      SET @cUCCConsigneeKey    = ''
      SET @cOrderType          = ''
      SET @nCountConsigneeKey  = 0
      SET @cUCCConsigneeKey    = Substring(@cUCCNo,2,5)

      IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK)
                INNER JOIN dbo.DropID D WITH (NOLOCK) ON D.DropID = DD.DropID
                WHERE D.DropID <> @cDropID
                AND DD.ChildID = @cUCCNo
                AND D.DropIDType = 'B' )
      BEGIN
         SET @nErrNo = 85352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC# Exists'
         GOTO QUIT
      END

      SELECT Top 1 @cConsigneeKey = OD.UserDefine02 -- (ChewKP03) 
           , @cOrderType    = O.Type
      FROM dbo.PickDetail PD WITH (NOLOCK)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.StorerKey = PD.StorerKey
      WHERE PD.CaseID = @cUCCNo
      AND PD.StorerKey = @cStorerKey
      AND PD.Status = '5'

      --(ChewKP01)
      IF @cOrderType = 'N'
      BEGIN
         SELECT @nCountConsigneeKey = COUNT( DISTINCT OD.UserDefine02 )
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.StorerKey = PD.StorerKey
         WHERE PD.CaseID = @cUCCNo
         AND PD.Status = '5'
         AND PD.StorerKey = @cStorerKey

         IF @nCountConsigneeKey > 1
         BEGIN
            SET @nErrNo = 85355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiConsignee'
            GOTO QUIT
         END

         IF ISNULL(RTRIM(SUBSTRING(@cConsigneeKey,4,5)),'') <> @cUCCConsigneeKey
         BEGIN
            SET @nErrNo = 85356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffConsignee'
            GOTO QUIT
         END
      END

      IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID )
      BEGIN
--         SELECT Top 1 @cConsigneeKey = OD.UserDefine02
--              , @cOrderType    = O.Type
--         FROM dbo.PickDetail PD WITH (NOLOCK)
--         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
--         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.StorerKey = PD.StorerKey
--         WHERE PD.CaseID = @cUCCNo
--         AND PD.Status = '5'


         SELECT Top 1 @cChildID = DD.ChildID
         FROM dbo.DropIDDetail DD WITH (NOLOCK)
         --INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = D.DropID
         WHERE DD.DropID = @cDropID
         
--         SELECT Top 1 @cLoadKey = LoadKey 
--         FROM dbo.DropID WITH (NOLOCK)
--         WHERE DropID = @cDropID

         SELECT Top 1 @cLoadKey = O.LoadKey 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         --INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.StorerKey = PD.StorerKey
         WHERE PD.StorerKey = @cStorerKey 
         AND PD.CaseID = @cChildID
         AND PD.Status = '5'
         

         SELECT Top 1 @cPalletConsigneeKey = OD.UserDefine02
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.StorerKey = PD.StorerKey
         WHERE PD.StorerKey = @cStorerKey
         AND PD.CaseID = @cChildID
         AND PD.Status = '5'
         AND O.LoadKey = @cLoadKey
         

         IF ISNULL(RTRIM(@cPalletConsigneeKey),'') <> ISNULL(RTRIM(@cConsigneeKey ),'' )
         BEGIN
            SET @nErrNo = 85351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffConsignee'
            GOTO QUIT
         END

         -- Valid If UCC ConsigneeKey = Orders ConsigneeKey --(ChewKP01)
         IF @cOrderType = 'N'
         BEGIN
             -- (ChewKP02) 
            --INSERT INTO TraceINFO (TraceName , TimeIN , Col1 , Col2 )
            --VALUES ( 'PalletBuild',Getdate(), @cUCCConsigneeKey ,SUBSTRING(@cConsigneeKey,4,5) )

            IF ISNULL(RTRIM(@cUCCConsigneeKey),'') <> ISNULL(RTRIM(SUBSTRING(@cConsigneeKey,4,5) ),'' )
            BEGIN
               SET @nErrNo = 85353
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCaseID'
               GOTO QUIT
            END

            SET @cPalletConsigneeKey = ''
            SET @cChildID = ''
            -- (ChewKP03) 
            DECLARE CursorDropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT DD.ChildID
               FROM dbo.DropID D WITH (NOLOCK) 
               INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = D.DropID
               WHERE  D.DropID = @cDropID
               AND D.LoadKey = @cLoadKey
            OPEN CursorDropID
            FETCH NEXT FROM CursorDropID INTO @cChildID
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @cPalletConsigneeKey = Substring(@cChildID ,2,5) 
               IF ISNULL(RTRIM(@cUCCConsigneeKey),'' )  <> ISNULL(RTRIM(@cPalletConsigneeKey),'' )
               BEGIN
                  SET @nErrNo = 85354
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffConsignee'
                  BREAK
               END
               FETCH NEXT FROM CursorDropID INTO @cChildID
            END
            CLOSE CursorDropID
            DEALLOCATE CursorDropID
         END
      END

      -- Get PickSlipNo
      DECLARE @cPickSlipNo NVARCHAR(10)
      SELECT TOP 1 @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE LabelNo = @cUCCNo

      -- Backup DropID to another field
      UPDATE dbo.PACKDETAIL WITH (ROWLOCK) SET
         RefNo = DropID -- Keep Track of Previous Carton ID
      WHERE PickSlipNo = @cPickSlipNo
         AND LabelNo = @cUCCNo
   END
END

QUIT:

GO