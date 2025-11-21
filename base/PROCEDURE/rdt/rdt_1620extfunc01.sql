SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1620ExtFunc01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update pickdetail.notes when picker hold/unhold picking     */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 08-Feb-2017  1.0  James       WMS1016 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtFunc01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @nFunctionKey     INT, 
   @cStorerkey       NVARCHAR( 15),
   @cWaveKey         NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cPutAwayZone     NVARCHAR( 10), 
   @cPickZone        NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cCartonType      NVARCHAR( 10), 
   @cLOC             NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT,           
   @nOutScn          INT               OUTPUT,
   @nOutStep         INT               OUTPUT,
   @nErrNo           INT               OUTPUT,
   @cErrMsg          NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cPickDetailKey   NVARCHAR( 10), 
            @cUserName        NVARCHAR( 18), 
            @cFacility        NVARCHAR( 5), 
            @cPickSlipNo      NVARCHAR( 10), 
            @cActionType      NVARCHAR( 30), 
            @nTranCount       INT, 
            @nRowRef          INT

   SELECT 
      @cUserName = USERNAME, 
      @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1620ExtFunc01

   IF NOT EXISTS ( SELECT 1 FROM rdt.StorerConfig WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey 
                   AND   CONFIGKEY = 'ExtendedFuncKeySP' 
                   AND   Function_ID = @nFunc 
                   AND   sValue <> '')
      GOTO Quit

   IF @nStep = 0
   BEGIN
      -- Check if user has unhold any picking
      -- Check user last action
      SELECT TOP 1 @cActionType = ActionType
      FROM rdt.rdtSTDEventLog WITH (NOLOCK)
      WHERE FunctionID = @nFunc
      AND   USERID = @cUserName
      ORDER BY EventDateTime DESC

      -- If last action was hold picking and pickdetail exists for hold picking
      IF @cActionType = '10' AND 
         EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE Storerkey = @cStorerkey
                  AND   [Status] < 4
                  AND   ISNULL( Notes, '') = @cUserName )
      BEGIN
         SET @nOutScn = 4790
         SET @nOutStep = 20
      END
      ELSE
      BEGIN
         SET @nOutScn = 1870
         SET @nOutStep = 1
      END

      GOTO Quit
   END

   IF @nStep = 7
   BEGIN
      IF @nInputKey = @nFunctionKey
      BEGIN
         SELECT TOP 1 
            @cOrderKey = OrderKey, 
            @cPutAwayZone = PutAwayZone,
            @cPickZone = PickZone,
            @cLOC = LOC,
            @cPickSlipNo = PickSlipNo
         FROM RDT.RDTPICKLOCK (NOLOCK)
         WHERE AddWho = @cUserName
         AND   [Status] = '1'

         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '10', -- Hold Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cLOC,
            @cRefNo1       = @cPutAwayZone,
            @cRefNo2       = @cPickZone,
            @cRefNo3       = @cOrderKey,
            @cRefNo4       = @cPickSlipNo

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN
            SET @nErrNo = 105951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EventLog Fail'
            GOTO RollBackTran
         END

         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT PickDetailKey FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         AND   LOC = @cLOC
         AND   [Status] < 4
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
               Notes = @cUserName,
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EventLog Fail'
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD

         SET @nOutScn = 4790
         SET @nOutStep = 20
         GOTO Quit
      END
   END

   IF @nStep = 20
   BEGIN
      IF @nInputKey = @nFunctionKey
      BEGIN
         SELECT TOP 1 
            @cOrderKey = OrderKey, 
            @cPutAwayZone = PutAwayZone,
            @cPickZone = PickZone,
            @cLOC = LOC,
            @cPickSlipNo = PickSlipNo
         FROM RDT.RDTPICKLOCK (NOLOCK)
         WHERE AddWho = @cUserName
         AND   [Status] = '1'

         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '11', -- Unhold Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cLOC,
            @cRefNo1       = @cPutAwayZone,
            @cRefNo2       = @cPickZone,
            @cRefNo3       = @cOrderKey,
            @cRefNo4       = @cPickSlipNo

         -- Check if already unhold from cluster pick
         SELECT TOP 1 @nRowRef = RowRef
         FROM rdt.rdtstdeventlog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserID = @cUserName
         AND   FunctionID = @nFunc
         AND   ActionType = '11'

         -- If already unhold
         IF @nRowRef > 0
         BEGIN
            DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickDetailKey FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   Notes = @cUserName
            AND   [Status] < 4
            OPEN CUR_UPD
            FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
                  Notes = '',
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 105953
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EventLog Fail'
                  GOTO RollBackTran
               END

               FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
         END

         SET @nOutScn = 4790
         SET @nOutStep = 20
         GOTO Quit
      END
   END


   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1620ExtFunc01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

END

GO