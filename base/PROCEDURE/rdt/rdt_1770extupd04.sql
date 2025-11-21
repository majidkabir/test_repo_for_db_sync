SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtUpd04                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: For VLT                                                     */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-10-12   Dennis    1.0   FCR-775 Created                         */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1770ExtUpd04]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nQTY            INT
   ,@cToLOC          NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   -- Get storer
   DECLARE @cUserID NVARCHAR(18),
   @cOrderKey NVARCHAR(10),
   @cStorerKey NVARCHAR(15),
   @cFacility  NVARCHAR(5),
   @cLoadKey NVARCHAR(20),
   @cPickSlipNo NVARCHAR(20),
   @cHUSQGRPPICK NVARCHAR(1),
   @cGroupKey NVARCHAR(10)

   SELECT @cFacility = Facility,@cUserID = USERNAME, @cStorerKey = StorerKey,@cHUSQGRPPICK = V_STRING44 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE  Mobile = @nMobile       
   SELECT @cOrderKey = OrderKey,@cLoadKey = LOADKEY,@cGroupKey = GroupKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nStep = 0
      BEGIN
         IF @cHUSQGRPPICK = '1'
         BEGIN
            UPDATE dbo.TASKDETAIL SET 
            USERKEY          = @cUserID
            ,StartTime       = CURRENT_TIMESTAMP
            ,EditDate        = CURRENT_TIMESTAMP
            ,EditWho         = @cUserID
            ,TrafficCop      = NULL
            WHERE GroupKey = @cGroupKey AND STATUS = '0' AND TaskType = 'FPK'
         END
      END
      IF @nStep = 4
      BEGIN
         IF @cHUSQGRPPICK = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM LOC WITH(NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC AND LocationType = 'STAGEOB')
            BEGIN
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE orderkey = @cOrderKey
               INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,TrafficCop,ArchiveCop,Loadkey,PickSlipNo)
               VALUES(@cDropID,'','',0,'N',0,5,null,null,@cLoadKey,@cPickSlipNo)

               EXEC rdt.rdt_FPKTaskDetailCheck_VLT
               @nMobile = @nMobile
               ,@nFunc  = @nFunc
               ,@cLangCode = @cLangCode
               ,@nStep  = @nStep 
               ,@nInputKey = @nInputKey
               ,@cTaskdetailKey = @cTaskDetailKey
               ,@cID = ''
               ,@cFromLoc = ''
               ,@nErrNo = @nErrNo OUTPUT 
               ,@cErrMsg = @cErrMsg OUTPUT
            END
         END
      END
      IF @nStep = 5
      BEGIN
         IF @nInputKey = 0
         BEGIN
            IF @cHUSQGRPPICK = '1'
            BEGIN
               --Unassign task
               UPDATE dbo.TASKDETAIL SET
                  USERKEY = ''
               WHERE UserKey = @cUserID AND Status = '0' AND TaskType = 'FPK'
            END
         END
      END
   END

Quit:

END

GO