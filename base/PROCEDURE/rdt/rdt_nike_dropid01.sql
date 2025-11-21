SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_NIKE_DropID01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Retrieve, update & delete dropid                            */
/*          Only work for 1 putawayzone + 1 orderkey                    */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 17-Nov-2015 1.0  James       Created                                 */
/* 25-Feb-2016 1.1  James       SOS364669 - Bug Fix. Get open dropid    */
/*                              based on orderkey + pazone (james01)    */
/* 21-Sep-2016 1.2  Leong       IN00143869 - Link with rdtPickLock.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_NIKE_DropID01] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @cStorerkey                NVARCHAR( 15),
   @cUserName                 NVARCHAR( 15),
   @cFacility                 NVARCHAR( 5),
   @cLoadKey                  NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20) OUTPUT,
   @cSKU                      NVARCHAR( 20),
   @cActionFlag               NVARCHAR( 1),
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount INT

   DECLARE @cCustomDropID_SP  NVARCHAR( 20), -- (james01)
           @cSQLStatement     NVARCHAR(2000),
           @cSQLParms         NVARCHAR(2000),
           @cPutawayZone      NVARCHAR(10),
           @cCurPutAwayZone   NVARCHAR(10),
           @cLoc              NVARCHAR(10),
           @nStep             INT,
           @nInputKey         INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_NIKE_DropID01

   SELECT @nStep = Step, @nInputKey = InputKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF ISNULL(@cLoadKey, '') = ''
      SELECT @cLoadKey = LoadKey
      FROM dbo.LoadPlanDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

   IF ISNULL( @cFacility, '') = ''
      SELECT @cFacility = Facility
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE UserName = @cUserName

   -- (james01)
   -- Retrieve DropID from same user + orderkey + putawayzone
   -- Return blank if 1st time user key in, system will generate
   -- LabelNo later
   SELECT TOP 1 @cLoc = Loc, @cCurPutAwayZone = PutAwayZone
   FROM RDT.RDTPICKLOCK WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   AddWho = @cUserName
   ORDER BY EditDate DESC

   SELECT @cPutawayZone = PutAwayZone
   FROM dbo.LOC WITH (NOLOCK)
   WHERE Facility = @cFacility
   AND   LOC = @cLoc

   IF @nInputKey = 0
   BEGIN
      IF @nStep = 8
      BEGIN
         SET @cDropID = ''

         IF @cCurPutAwayZone = 'ALL'
         BEGIN
            SELECT TOP 1 @cDropID = D.DropID,
                         @cCurPutAwayZone = UDF05
            FROM dbo.DROPIDDETAIL DD WITH (NOLOCK)
            JOIN dbo.DROPID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
            WHERE DD.ChildID = @cOrderKey
            AND   D.Status = '0'
         END
         ELSE
         BEGIN
            -- Get open drop id from same putawayzone
            SELECT TOP 1 @cDropID = D.DropID
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.DROPIDDETAIL DD WITH (NOLOCK) ON ( PD.dropid = DD.dropid and PD.orderkey = DD.ChildID)
            JOIN dbo.DROPID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
            WHERE LOC.PutawayZone = @cPutawayZone
            AND PD.OrderKey = @cOrderKey
            AND D.Status = '0'
         END

         GOTO Quit
      END
   END

   IF @cActionFlag = 'R'
   BEGIN
      SET @cDropID = ''

      -- Get open drop id from same putawayzone
      SELECT TOP 1 @cDropID = D.DropID
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.DROPIDDETAIL DD WITH (NOLOCK) ON ( PD.dropid = DD.dropid and PD.orderkey = DD.ChildID)
      JOIN dbo.DROPID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
      WHERE LOC.PutawayZone = @cPutawayZone
      AND PD.OrderKey = @cOrderKey
      AND D.Status = '0'

      -- If same putawayzone do not have dropid
      -- Then check if other putawayzone has any open dropid (same orders)
      IF ISNULL( @cDropID, '') = ''
      BEGIN
         -- If user select putawayzone ALL then can use same dropid
         -- to cross zone pick sku else user have to use diff dropid
         IF @cCurPutAwayZone = 'ALL'
         BEGIN
            SELECT TOP 1 @cDropID = D.DropID,
                         @cCurPutAwayZone = UDF05
            FROM dbo.DROPIDDETAIL DD WITH (NOLOCK)
            JOIN dbo.DROPID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
            WHERE DD.ChildID = @cOrderKey
            AND   D.Status = '0'
         END
      END

      DECLARE @nCartonNo int, @bsuccess int

      -- Don't generate label no @ step 6
      -- It will generate @ step 7
--      IF @nStep = 6
--         GOTO Quit

      IF ISNULL( @cDropID, '') = ''
      BEGIN
         IF @nStep = 15
            GOTO Quit

         SET @nCartonNo = 0

         SET @nErrNo = 0
         SET @cErrMsg = ''

         EXECUTE dbo.nsp_GenLabelNo
            '',
            @cStorerKey,
            @c_labelno     = @cDropID   OUTPUT,
            @n_cartonno    = @nCartonNo OUTPUT,
            @c_button      = '',
            @b_success     = @bsuccess  OUTPUT,
            @n_err         = @nErrNo    OUTPUT,
            @c_errmsg      = @cErrMsg   OUTPUT
      END

      GOTO Quit
   END

   IF @cActionFlag = 'I'
   BEGIN
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                 WHERE DropID = @cDropID
                 AND   [Status] = '0')
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'ClusterPickAllowReuseDropID', @cStorerKey) = '1'
         BEGIN
            -- Delete existing dropiddetail
            DELETE FROM dbo.DropIDDetail
            WHERE DropID = @cDropID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
               GOTO RollBackTran
            END

            -- Delete existing dropid
            DELETE FROM dbo.DropID
            WHERE DropID = @cDropID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81710
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 81701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
            GOTO RollBackTran
         END
      END

      INSERT INTO dbo.DropID
      (DropID, LabelPrinted, [Status], PickSlipNo, LoadKey, UDF05)
      VALUES
      (@cDropID, '0', '0', @cPickSlipNo, @cLoadKey, @cPutAwayZone)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'
         GOTO RollBackTran
      END

      INSERT INTO dbo.DropIDDetail
      (DropID, ChildID)
      VALUES
      (@cDropID, @cOrderKey)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'
         GOTO RollBackTran
      END
   END

   IF @cActionFlag = 'U'
   BEGIN
      -- Check other putawayzone for open pick task
      -- If got task still then don't auto close it
      -- Unless it is from step 15 Close Carton
      IF @nStep IN (8, 9, 10)
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   [Status] = '0')
            GOTO RollBackTran
      END

      IF ISNULL( @cDropID, '') = ''
         -- (james01)
         -- Retrieve DropID from same user + orderkey + putawayzone
         SELECT TOP 1 @cDropID = D.DropID
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.DROPIDDETAIL DD WITH (NOLOCK) ON ( PD.dropid = DD.dropid and PD.orderkey = DD.ChildID)
         JOIN dbo.DROPID D WITH (NOLOCK) ON ( DD.DropID = D.DropID)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
         WHERE LOC.PutawayZone = @cPutawayZone
         AND PD.OrderKey = @cOrderKey
         AND D.Status = '0'
         AND EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK PL WITH (NOLOCK)
                      WHERE PL.StorerKey = @cStorerKey
                      AND   PL.OrderKey = @cOrderKey
                      AND   PL.AddWho = @cUserName
                      AND   PL.PutAwayZone = CASE WHEN @cCurPutAwayZone = 'ALL' THEN PL.PutAwayZone ELSE @cPutawayZone END
                      AND   PL.Status <= '5'
                      AND   D.DropID = PL.DropID ) -- IN00143869

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                     WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 81704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
         GOTO RollBackTran
      END

      UPDATE dbo.DropID WITH (ROWLOCK) SET
         [Status] = '9'
      WHERE DropID = @cDropID
      AND   [Status] = '0'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DID FAIL'
         GOTO RollBackTran
      END

      SET @cDropID = ''
   END

   IF @cActionFlag = 'D'
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                     WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 81706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROPID'
         GOTO RollBackTran
      END

      DELETE FROM dbo.DropIDDetail
      WHERE DropID = @cDropID

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DDTL FAIL'
         GOTO RollBackTran
      END

      DELETE FROM dbo.DropID
      WHERE DropID = @cDropID

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DEL DID FAIL'
         GOTO RollBackTran
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_NIKE_DropID01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_NIKE_DropID01

END

GO