SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtUpd06                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2021-12-02  1.0  James    WMS-18236. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtUpd06] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nAfterStep   INT,
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

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd06

   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cPalletLineNumber NVARCHAR( 5)
   DECLARE @cUserName         NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3    -- Case ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 @cOrderKey = PH.OrderKey
            FROM dbo.ORDERS O WITH (NOLOCK)
            JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON (O.ORDERKEY = PH.ORDERKEY)
            JOIN dbo.PACKDETAIL PD WITH (NOLOCK) ON (PH.PICKSLIPNO=PD.PICKSLIPNO)
            WHERE O.STORERKEY = @cStorerkey
            AND   PD.LabelNo = @cCaseID
            ORDER BY 1

            IF ISNULL( @cOrderKey, '') = ''
            BEGIN
               SET @nErrNo = 179601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No OrderKey'
               GOTO RollBackTran
            END

            DECLARE @curUpdPlt   CURSOR
            SET @curUpdPlt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PalletLineNumber
            FROM dbo.PALLETDETAIL WITH (NOLOCK)
            WHERE PalletKey = @cPalletKey
            AND   CaseId = @cCaseID
            AND   StorerKey = @cStorerkey
            AND   [Status] = '0'
            ORDER BY 1
            OPEN @curUpdPlt
            FETCH NEXT FROM @curUpdPlt INTO @cPalletLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PALLETDETAIL SET
                  UserDefine02 = @cOrderKey,
                  EditWho = 'rdt.' + @cUserName,
                  EditDate = GETDATE()
               WHERE PalletKey = @cPalletKey
               AND   PalletLineNumber = @cPalletLineNumber

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 179602
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PLTD Fail'
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curUpdPlt INTO @cPalletLineNumber
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1638ExtUpd06 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO