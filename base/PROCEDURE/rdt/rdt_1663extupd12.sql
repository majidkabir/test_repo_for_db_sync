SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd12                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Send interface RR2 when close pallet                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-08-09 1.0  James    WMS-19868. Created                                */
/* 2023-02-20 1.1  James    Bug fix (james01)                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd12](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20),
   @cPalletLOC    NVARCHAR( 10),
   @cMBOLKey      NVARCHAR( 10),
   @cTrackNo      NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @cShipperKey   NVARCHAR( 15),
   @cCartonType   NVARCHAR( 10),
   @cWeight       NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1663ExtUpd12 -- For rollback or commit only our own transaction

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 6 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = 1 -- YES
            BEGIN
               SELECT TOP 1 @cOrderKey = OrderKey
               FROM dbo.MBOLDETAIL WITH (NOLOCK)
               WHERE MBOLKey = @cMBOLKey
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
                     SET @nErrNo = 196001
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err
                     GOTO RollBackTran
                  END
               END

               UPDATE dbo.MBOL SET
                  STATUS = '5', 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE MbolKey = @cMBOLKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 196002 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close MBOL Err
                  GOTO Rollbacktran
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1663ExtUpd12
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO