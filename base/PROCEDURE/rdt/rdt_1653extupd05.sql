SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1653ExtUpd05                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_TrackNo_SortToPallet                             */
/*                                                                      */
/* Purpose: Insert into Transmitlog2 table                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2022-06-22  1.0  James    WMS-19868. Created                         */
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/* 2023-02-11  1.2  LZG      Skip MBOL update if triggers RR2, because  */
/*                           RR2 response will update MBOL.Status (ZG01)*/
/************************************************************************/
    
CREATE   PROC [RDT].[rdt_1653ExtUpd05] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT


   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1653ExtUpd05 -- For rollback or commit only our own transaction
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cOrderKey = UserDefine01
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE PalletKey = @cPalletKey
         AND   StorerKey = @cStorerKey
         AND   [Status] = '9'
         ORDER BY 1
         
         IF EXISTS ( SELECT 1
                     FROM dbo.Codelkup C WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON ( C.Code = O.[Type] AND C.Storerkey = O.StorerKey)
                     WHERE C.LISTNAME = 'MARKETPLAC'
                     AND   C.Short = 'HM'
                     AND   C.Storerkey = @cStorerKey
                     AND   O.OrderKey = @cOrderKey)
         BEGIN
            -- Insert transmitlog2 here
            EXECUTE ispGenTransmitLog2
               @c_TableName      = 'WSCRSOCLOSEMP',
               @c_Key1           = @cMBOLKey,
               @c_Key2           = '',
               @c_Key3           = @cStorerkey,
               @c_TransmitBatch  = '',
               @b_Success        = @bSuccess   OUTPUT,
               @n_err            = @nErrNo     OUTPUT,
               @c_errmsg         = @cErrMsg    OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 187701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.MBOL SET
               STATUS = '5',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE MbolKey = @cMBOLKey
       
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 187702
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close MBOL Err
               GOTO Rollbacktran
            END
         END
      END
   END
   
GOTO QUIT

RollBackTran:
   Rollback tran
   
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1653ExtUpd05
END

GO