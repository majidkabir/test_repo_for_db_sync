SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1638ExtUpd08                                       */
/* Copyright: LFLogistics                                                  */
/*                                                                         */
/* Date        Rev  Author    Purposes                                     */
/* 2022-10-06  1.0  yeekung    WMS-20937. Created                          */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_1638ExtUpd08] (
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

   DECLARE @cCurrentTrackNo NVARCHAR(20)
   DECLARE @cPalletLineNumber NVARCHAR(5)
   DECLARE @cUserName      NVARCHAR(20)
   DECLARE @cMBOLKEY       NVARCHAR(20)
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd06
   
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN

       IF @nStep = 3    -- Case ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            
            SELECT @cCurrentTrackNo=I_Field03
                  ,@cUserName =username
            FROM  rdt.rdtmobrec (NOLOCK)
            WHERE mobile=@nMobile

            SELECT @cMBOLKEY=mbolkey
            FROM ORDERS (NOLOCK)
            WHERE StorerKey=@cStorerkey
               AND [Status] = '9'
               AND TrackingNo = @cCurrentTrackNo
               and doctype='e' 

            DECLARE @curUpdPlt   CURSOR
            SET @curUpdPlt = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PalletLineNumber
            FROM dbo.PALLETDETAIL WITH (NOLOCK)
            WHERE PalletKey = @cPalletKey
            AND   CaseId = @cCaseID
            AND   StorerKey = @cStorerkey
            AND   ISNULL(trackingno,'')=''
            AND   [Status] = '0'
            ORDER BY 1
            OPEN @curUpdPlt
            FETCH NEXT FROM @curUpdPlt INTO @cPalletLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PALLETDETAIL SET
                  trackingno = @cCurrentTrackNo,
                  EditWho = 'rdt.' + @cUserName,
                  UserDefine03 =  @cMBOLKEY,
                  EditDate = GETDATE()
               WHERE PalletKey = @cPalletKey
               AND   PalletLineNumber = @cPalletLineNumber

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 192702
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPltDtlFail'
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curUpdPlt INTO @cPalletLineNumber
            END

            IF NOT EXISTS ( SELECT 1
                           FROM MBOL (NOLOCK)
                           where mbolkey=@cMBOLKEY
                           AND [Status] = '9'
                           AND PlaceOfdischargeQualifier='THAILAND')
            BEGIN
               UPDATE MBOL WITH (ROWLOCK)
               SET PlaceOfLoadingQualifier='THAILAND',
                   TrafficCop = NULL
               where mbolkey=@cMBOLKEY
                  AND [Status] = '9'

               
               IF @@ERROR<>0
               BEGIN
                  SET @nErrNo = 192703 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdMBOLFail  
                  GOTO ROLLBACKTRAN
               END
            END
         END
      END
      IF @nStep = 4  -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN

            UPDATE pallet WITH (ROWLOCK)
            SET status='3'
            where palletkey=@cPalletKey

            IF @@ERROR<>0
            BEGIN
               SET @nErrNo = 192701 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPLTFail  
               GOTO ROLLBACKTRAN
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