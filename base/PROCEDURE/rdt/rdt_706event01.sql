SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_706Event01                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2019-05-15 1.0  Ung      WMS-9003 Created                               */
/* 2019-08-16 1.1  YeeKung  WMS10122 Update changed                        */
/* 2020-09-02 1.2  YeeKung  WMS-14828 Update the step (yeekung02)          */
/* 2021-03-18 1.3  YeeKung  WMS-16561 Add Rdtformat (yeekung03)            */
/* 2021-04-07 1.4  YeeKung  INC1469108 Fix error cannotlogout(yeekung04)   */
/* 2021-04-18 1.5  YeeKung  WMS-16782 Add Extendedinfo (yeekung05)         */
/* 2023-08-11 1.6  YeeKung  WMS-23137 Add Transmitlog2 (yeekung06)         */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_706Event01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cOption       NVARCHAR( 1),
   @cRetainValue  NVARCHAR( 10),
   @cTotalCaptr   INT           OUTPUT,
   @nStep         INT           OUTPUT,
   @nScn          INT           OUTPUT,
   @cLabel1       NVARCHAR( 20) OUTPUT,
   @cLabel2       NVARCHAR( 20) OUTPUT,
   @cLabel3       NVARCHAR( 20) OUTPUT,
   @cLabel4       NVARCHAR( 20) OUTPUT,
   @cLabel5       NVARCHAR( 20) OUTPUT,
   @cValue1       NVARCHAR( 60) OUTPUT,
   @cValue2       NVARCHAR( 60) OUTPUT,
   @cValue3       NVARCHAR( 60) OUTPUT,
   @cValue4       NVARCHAR( 60) OUTPUT,
   @cValue5       NVARCHAR( 60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @cExtendedinfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cEventCode     NVARCHAR( 20)
   DECLARE @cCarrier       NVARCHAR( 20)
   DECLARE @cPalletID      NVARCHAR( 20)
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cTableName     NVARCHAR( 30)
   DECLARE @nEventNum      INT
   DECLARE @cClosePallet   NVARCHAR( 1)
   DECLARE @cPrintlist     NVARCHAR( 1)
   DECLARE @cPaperPrinter  NVARCHAR(10)
   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)

   -- Parameter mapping
   SET @cEventCode = @cValue1
   SET @cCarrier = @cValue2
   SET @cPalletID = @cValue3
   SET @cCaseID = @cValue4

   SET @cClosePallet = rdt.rdtGetConfig( @nFunc, 'ClosePallet', @cStorerKey)
   IF @cClosePallet = '0'
      SET @cClosePallet = ''

   SET @cPrintlist = rdt.rdtGetConfig( @nFunc, 'Printlist', @cStorerKey)
   IF @cPrintlist = '0'
      SET @cPrintlist = ''

   IF  @nStep =2 AND @nInputKey='1'   --(yeekung04)
   BEGIN

      -- Check event code
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = 'EVENTCODE'
            AND StorerKey = @cStorerKey
            AND Long = @cEventCode)
      BEGIN
         SET @nErrNo = 139701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad EventCode
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- EventCode
         SET @cValue1 = ''
         GOTO Quit
      END

      -- Check carrier
      IF NOT EXISTS( SELECT 1
       FROM dbo.Codelkup WITH (NOLOCK)
       WHERE ListName = 'CARRIERCHK'
          AND Code = @cCarrier
          AND StorerKey = @cStorerKey )
      BEGIN
         SET @nErrNo = 139702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Carrier
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Carrier
         SET @cValue2 = ''
         GOTO Quit
      END

      -- Check pallet ID blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 139703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need pallet ID
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- PalletID
         GOTO Quit
      END

      -- Check case ID blank
      IF @cCaseID = ''
      BEGIN

         IF @cClosePallet <>''
         BEGIN
            IF EXISTS(SELECT 1 FROM palletdetail (NOLOCK)
                      WHERE palletkey=@cPalletID)
            BEGIN
               IF EXISTS(SELECT 1 FROM palletdetail (NOLOCK)
               WHERE palletkey=@cPalletID
               AND status=9) AND @cPrintlist ='1'
               BEGIN
                  SET @nStep =  @nStep+2
                  SET @nScn  =  @nScn +2
                  GOTO Quit
               END
               ELSE
               BEGIN
                  SET @nStep =  @nStep+1
                  SET @nScn  =  @nScn +1
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 139705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PD NoExists
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- CaseID
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 139704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need case ID
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- CaseID
            GOTO Quit
         END
      END

       -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CaseID', @cCaseID) = 0
      BEGIN
         SET @nErrNo = 139718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Quit
      END


      -- Insert event
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '14',
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cRefNo1       = @cEventCode,
         @cRefNo2       = @cCarrier,
         @cRefNo3       = @cPalletID,
         @cRefNo4       = @cCaseID,
         @nEventNum     = @nEventNum OUTPUT

      SELECT @cTotalCaptr=COUNT(*)
      FROM  palletdetail WITH  (NOLOCK)
      WHERE palletkey=@cPalletID
      AND Storerkey=@cStorerKey

      IF NOT EXISTS(SELECT 1 FROM pallet (NOLOCK)
                  WHERE palletkey=@cPalletID
                  AND Storerkey=@cStorerKey)
      BEGIN
         INSERT INTO PALLET (Palletkey,storerkey,status)
         VALUES(@cPalletID,@cStorerKey,0)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Plt Fail
            GOTO Quit
         END
      END

      IF EXISTS(SELECT 1 FROM palletdetail (NOLOCK)
            WHERE palletkey=@cPalletID
            AND Caseid=@cCaseID
            AND Storerkey=@cStorerKey)
      BEGIN
         SET @nErrNo = 139717
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Plt Fail
         GOTO Quit
      END

      INSERT INTO PALLETDETAIL (PalletKey,PalletLineNumber,Caseid,storerkey,sku,loc,QTY,status,userdefine01,userdefine02,userdefine03)
      VALUES(@cPalletID,CAST(@cTotalCaptr + 1 AS NVARCHAR(5)),@cCaseID,@cStorerKey,'VSCMS','VSCMS',0,0,@cEventCode,@cCarrier,@nEventNum)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 139707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PD Fail
         GOTO Quit
      END

      SELECT @cTotalCaptr=COUNT(*)
      FROM  palletdetail WITH  (NOLOCK)
      WHERE palletkey=@cPalletID
      AND Storerkey=@cStorerKey

      -- Get interface
      SELECT @cTableName = ISNULL( Long, '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = 'RDTINSTL2'
         AND StorerKey = @cStorerKey
         AND Code = @cFacility
         AND Code2 = @nFunc
         AND Short = 'EventCap'

      -- Interface
      IF @@ROWCOUNT > 0 AND @cTableName <> ''
         EXEC ispGenTransmitLog2 @cTableName, @nEventNum, 0, @cStorerKey, ''
            ,@bSuccess OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
      
      -- Get interface
      SELECT @cTableName = ISNULL( Long, '')
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = 'RDT2INSTL2'
         AND StorerKey = @cStorerKey
         AND Code = @cFacility
         AND Code2 = @nFunc
         AND Short = 'EventCap'

      -- Interface
      IF @@ROWCOUNT > 0 AND @cTableName <> ''
         EXEC ispGenTransmitLog2 @cTableName, @nEventNum, 0, @cStorerKey, ''
            ,@bSuccess OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT


      -- Position on CaseID field
      EXEC rdt.rdtSetFocusField @nMobile, 8 -- CaseID
   END

   IF  @nStep =3
   BEGIN

      -- Check invalid option
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 139713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 139714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF   @cOption = 1
      BEGIN

         UPDATE PALLET WITH (ROWLOCK)
         SET STATUS=9
         WHERE Palletkey= @cPalletID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Plt Fail
            GOTO Quit
         END

         UPDATE PALLETDETAIL WITH (ROWLOCK)
         SET STATUS=9
         WHERE Palletkey= @cPalletID

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 139709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PD Fail
            GOTO Quit
         END

         SET @nStep =  @nStep+1
         SET @nScn  =  @nScn +1
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nStep =  @nStep-1
         SET @nScn  =  @nScn -1
         GOTO Quit
      END
   END

   IF  @nStep =4
   BEGIN

      -- Check invalid option
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 139715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 139716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF   @cOption = 1
      BEGIN
         -- Get printer
         SELECT
            @cPaperPrinter = Printer
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Check paper printer blank
         IF @cPaperPrinter = ''
         BEGIN
            SET @nErrNo = 139710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
            EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label
            GOTO Quit
         END

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ReportType = 'PRINTLIST'

     -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 139711
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Quit
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 139712
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Quit
         END

         DECLARE @tPrintlist AS VariableTable

         INSERT INTO @tPrintlist (Variable, Value) VALUES ( '@cStorerkey',  @cStorerkey)
         INSERT INTO @tPrintlist (Variable, Value) VALUES ( '@cPalletID',  @cPalletID)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
            'PRINTLIST', -- Report type
            @tPrintlist, -- Report params
            'rdt_706Event01',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @nNoOfCopy = '1'

         IF @nErrNo <>''
         BEGIN
            GOTO Quit
         END

         SET @nStep =  @nStep-2
         SET @nScn  =  @nScn -2
         GOTO Quit
      END
      ELSE
      BEGIN
         SET @nStep =  @nStep-2
         SET @nScn  =  @nScn -2
         GOTO Quit
      END
   END

Quit:

GO