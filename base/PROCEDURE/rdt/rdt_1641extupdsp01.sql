SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtUpdSP01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ANF Update DropID Logic                                     */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2014-02-27  1.0  ChewKP   Created                                    */
/* 2023-02-10  1.1  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtUpdSP01] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cDROPID     NVARCHAR( 20),
   @cUCCNo      NVARCHAR( 20),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cUCC NVARCHAR(20)
          , @cLoadKey NVARCHAR(10)
          , @cDropLoc NVARCHAR(10)


   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @cUCC     = ''
   SET @cLoadKey = ''
   SET @cDropLoc = ''

--   SELECT @cUCC = ChildID
--   FROM dbo.DropIDDetail WITH (NOLOCK)
--   WHERE DropID = @cDropID

--   SELECT TOP 1 @cLoadKey = O.LoadKey
--   FROM dbo.PickDetail PD WITH (NOLOCK)
--   INNER JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
--   WHERE PD.CaseID = @cUCC
--   AND PD.Status = '5'
--
--   SELECT TOP 1 @cDropLoc = Loc
--   FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
--   WHERE LoadKey = @cLoadKey
--   AND LocationCategory = 'Pack&Hold'

   UPDATE dbo.DROPID WITH (ROWLOCK)
              SET LabelPrinted = 'Y',
              Status = '0',
              DropLoc = ''--ISNULL(RTRIM(@cDropLoc),'')
   WHERE DropID = @cDropID
   AND Status = '0'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 69208
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd DROPID Fail'
   	--ROLLBACK TRAN  -- (ChewKP01)
   	GOTO FAIL
   END



Fail:
END

GO