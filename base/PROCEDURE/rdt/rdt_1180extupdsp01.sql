SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1180ExtUpdSP01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: ANF Update DropID Logic                                     */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2015-12-04  1.0  AlanTan  Created                                    */
/* 08-08-2016  1.1  Leong    Change DB Name (Leong01)                   */
/* 08-11-2019  1.2  Ung      Fix SET option                             */
/* 24-Feb-2020 1.3  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1180ExtUpdSP01] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @cOption     NVARCHAR(1),
   @cPalletID   NVARCHAR( 20),
   @cTruckID    NVARCHAR( 20),
   @cShipmentNo NVARCHAR( 60),
   @cUserName   NVARCHAR( 15),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nCountTask INT
           ,@nTranCount INT
           ,@CartonMUID  NVARCHAR(20)
           ,@cLabelPrinter NVARCHAR( 10)
           ,@cLabelType    NVARCHAR( 20)
           ,@cStorerKey    NVARCHAR( 15)


   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @CartonMUID = ''


--   SET @nTranCount = @@TRANCOUNT
--
--   BEGIN TRAN
--   SAVE TRAN OTMUpdate


   IF @nFunc = 1180
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @cOption <> '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                        WHERE    CaseID = @cPalletID
                        AND     TruckID = @cTruckID  )
            BEGIN
               -- Insert Into OTMIDTrack --
               INSERT INTO dbo.OTMIDTrack (CaseID, Principal, MUStatus, OrderID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume,
                       TruckID, MUType, DropLoc, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )

               SELECT TOP 1 @cPalletID, Principal, '5', OrderID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume,
                       TruckID, MUType, DropLoc, ConsigneeKey, '', '', '1', UserDefine04, UserDefine05
               FROM dbo.OTMIDTrack WITH (NOLOCK)
               WHERE ShipmentID = @cShipmentNo
               --AND   TruckID = @cTruckID
               AND   MUStatus >= '0'
               ORDER BY MUID DESC

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 95352
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCartonFail'
                  EXEC rdt.rdtSetFocusField @nMobile, 8
                  GOTO RollBackTran
               END

               SELECT @cLabelPrinter = Printer
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Print Label
               SET @cLabelType = 'CARTONLBLGAP'

               EXEC dbo.isp_BT_GenBartenderCommand
                    @cPrinterID     = @cLabelPrinter
                  , @c_LabelType    = @cLabelType
                  , @c_userid       = ''
                  , @c_Parm01       = @cPalletID
                  , @c_Parm02       = ''
                  , @c_Parm03       = ''
                  , @c_Parm04       = ''
                  , @c_Parm05       = ''
                  , @c_Parm06       = ''
                  , @c_Parm07       = ''
                  , @c_Parm08       = ''
                  , @c_Parm09       = ''
                  , @c_Parm10       = ''
                  , @c_StorerKey    = ''
                  , @c_NoCopy       = '1'
                  , @b_Debug        = '0'
                  , @c_Returnresult = 'N'
                  , @n_err          = @nErrNo  OUTPUT
                  , @c_errmsg       = @cErrMsg OUTPUT

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 95358
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintLabelFail
                  GOTO RollBackTran
               END

               SET @nErrNo = 95351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CartonNotExist'
            END

            IF EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                        WHERE    CaseID = @cPalletID
                        AND   MUStatus  = '0' )
            BEGIN
               UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
               SET   TruckID = @cTruckID
               , ShipmentID  = @cShipmentNo
               ,   MUStatus  = '5'
               WHERE CaseID  = @cPalletID
               AND  MUStatus = '0'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 95353
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdCartonFail
                  GOTO RollBackTran
               END

               SELECT @cLabelPrinter = Printer
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               -- Print Label
               SET @cLabelType = 'CARTONLBLGAP'

               EXEC dbo.isp_BT_GenBartenderCommand
                    @cPrinterID     = @cLabelPrinter
                  , @c_LabelType    = @cLabelType
                  , @c_userid       = ''
                  , @c_Parm01       = @cPalletID
                  , @c_Parm02       = ''
                  , @c_Parm03       = ''
                  , @c_Parm04       = ''
                  , @c_Parm05       = ''
                  , @c_Parm06       = ''
                  , @c_Parm07       = ''
                  , @c_Parm08       = ''
                  , @c_Parm09       = ''
                  , @c_Parm10       = ''
                  , @c_StorerKey    = ''
                  , @c_NoCopy       = '1'
                  , @b_Debug        = '0'
                  , @c_Returnresult = 'N'
                  , @n_err          = @nErrNo  OUTPUT
                  , @c_errmsg       = @cErrMsg OUTPUT

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 95358
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintLabelFail
                  GOTO RollBackTran
               END
            END
         END

         IF @cOption <> ''
         BEGIN
            IF @cOption <> '1'
            BEGIN
               SET @nErrNo = 95354
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
               GOTO RollBackTran
            END

            IF @cOption = '1'
            BEGIN
               DECLARE C_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT MUID FROM dbo.OTMIDTrack WITH (NOLOCK)
               WHERE TruckID = @cTruckID
               AND   ShipmentID = @cShipmentNo
               AND   MUStatus = '5'
               ORDER BY MUID

               OPEN C_Carton
               FETCH NEXT FROM C_Carton INTO  @CartonMUID
               WHILE (@@FETCH_STATUS <> -1)
               BEGIN
                  UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
                  SET MUStatus = '8'
                  WHERE MUID = @CartonMUID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 95355
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdCartonFail
                     GOTO RollBackTran
                  END

                  Declare @cExecStatements  nvarchar(4000)
                         ,@nMUID INT

                  SET @nMUID = @CartonMUID

                  SET @cExecStatements = N' SET ANSI_NULLS ON ' + 'SET ANSI_WARNINGS ON '+
                                          ' INSERT link_local.CNEPOD.dbo.CartonScan (CartonID, EventStatus, ScanDate, Status, UID, AccountID)' + -- (Leong01)
                                          ' SELECT TOP 1 CaseID, ''02'', AddDate, ''0'', 0, ''RDT''  ' +
                                          ' FROM CNWMS.dbo.OTMIDTrack WITH (NOLOCK) ' +
                                          ' WHERE MUID = @nMUID  '+
                                          ' SET ANSI_NULLS OFF  ' +
                                          ' SET ANSI_WARNINGS OFF  '

                  EXEC sp_executesql @cExecStatements,
                  N'@nMUID INT',
                  @nMUID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 95356
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdePODFail
                     GOTO RollBackTran
                  END

                  UPDATE dbo.OTMIDTrack WITH (ROWLOCK)
                  SET MUStatus = '9'
                  WHERE MUID = @CartonMUID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 95357
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdCartonFail
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM C_Carton INTO  @CartonMUID
               END
               CLOSE C_Carton
               DEALLOCATE C_Carton
            END
         END
      END
   END



   GOTO QUIT


   RollBackTran:
--   ROLLBACK TRAN OTMUpdate

   Quit:
--   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
--          COMMIT TRAN OTMUpdate


Fail:
END



GO