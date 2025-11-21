SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtValidateStorernFacility                         */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Check whether the Storer Key and Facility code is correct   */
/*          or not.                                                     */
/*                                                                      */
/* Input Parameters: Mobile No                                          */
/*                                                                      */
/* Output Parameters: Error No and Error Message                        */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/* Called By: rdtHandle                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 10-Aug-2007  Vicky         Add Printer Validation                    */
/* 22-Jul-2010  Vicky         Add Paper Printer field (Vicky01)         */
/* 19-Nov-2012  James         Fix nVARCHAR length (james01)             */
/* 08-Mar-2013  Ung           SOS271256 Add device ID (ung02)           */
/* 05-Aug-2015  Ung           Support storer group                      */
/* 15-Aug-2016  Ung           Update rdtMobRec with EditDate            */
/* 06-Jul-2012  Ung           SOS247127 Add printer group (ung01)       */
/************************************************************************/
CREATE PROC [RDT].[rdtValidateStorernFacility] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT ,
   @nFunction  int OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nFunc int,
          @nScn  int,
          @nStep int,
          @cStorer   NVARCHAR(15),
          @cStorerGroup NVARCHAR(20),
          @cFacility NVARCHAR(5),
          @cUOM      NVARCHAR(10),
          @cUserName NVARCHAR(18),
          @cPrinter  NVARCHAR(10), -- Added on 10-Aug-2007
          @cPrinter_Paper  NVARCHAR(10), -- (Vicky01)
          @cDeviceID NVARCHAR(20) -- (ung02)

   DECLARE @nInputKey   int

   SELECT @nErrNo = 1, @cErrMsg =''
   SELECT @cStorer  = I_Field01,  @cFacility = I_Field02,
          @cUOM     = I_Field03,  @cUserName = UserName,
          @nInputKey  = InputKey,
          @cPrinter = I_Field04,  -- Added on 10-Aug-2007
          @cPrinter_Paper = I_Field05,  -- (Vicky01)
          @cDeviceID = I_Field06 -- (ung02)
   FROM RDT.RDTMOBREC (NOLOCK)
   WHERE Mobile = @nMobile

   IF @@ROWCOUNT = 0
   BEGIN
      SELECT @nErrNo = -1,
             @cErrMsg = 'Retrieve Mobile Record Failed, Mobile# ' + RTRIM( CAST(@nMobile as NVARCHAR(4)) )  -- (james01)
      GOTO RETURN_SP
   END

   IF NOT EXISTS(SELECT 1 FROM DBO.STORER (NOLOCK) WHERE StorerKey = @cStorer)
   BEGIN
      SELECT @nErrNo = -1,
             @cErrMsg = rdt.rdtgetmessage(2,'ENG','DSP')
   END
   ELSE IF NOT EXISTS(SELECT 1 FROM DBO.FACILITY (NOLOCK) WHERE Facility = @cFacility)
   BEGIN
      SELECT @nErrNo = -1,
             @cErrMsg = rdt.rdtgetmessage(3,'ENG','DSP')
   END
   -- Added on 10-Aug-2007
   ELSE
   BEGIN
      IF ISNULL(@cPrinter, '') <> '' -- (Vicky01)
      BEGIN
         IF NOT EXISTS(SELECT TOP 1 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPrinter))
         BEGIN
            IF NOT EXISTS(SELECT TOP 1 1 FROM RDT.RDTPrinterGroup (NOLOCK) WHERE PrinterGroup = RTRIM(@cPrinter))
            BEGIN
               SELECT @nErrNo = -1,
                      @cErrMsg = rdt.rdtgetmessage(50,'ENG','DSP')
            END
         END
      END

      -- (Vicky01) - Start
      IF ISNULL(@cPrinter_Paper, '') <> ''
      BEGIN
         IF NOT EXISTS(SELECT TOP 1 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPrinter_Paper))
         BEGIN
   	      IF NOT EXISTS(SELECT TOP 1 1 FROM RDT.RDTPrinterGroup (NOLOCK) WHERE PrinterGroup = RTRIM(@cPrinter_Paper)) --(ung01)
            BEGIN
               SELECT @nErrNo = -1,
                      @cErrMsg = rdt.rdtgetmessage(50,'ENG','DSP')
            END
         END
      END
      -- (Vicky01) - End

      -- (ung02)
      IF @cDeviceID <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cDeviceID)
         BEGIN
	         SET @nErrNo = -1
	         SET @cErrMsg = rdt.rdtgetmessage( 49, 'ENG', 'DSP') --Bad DeviceID
	         EXEC rdt.rdtSetFocusField @nMobile, 6 -- DeviceID
         END
      END

      -- Get storer group
      SET @cStorerGroup = ''
      SELECT @cStorerGroup = DefaultStorerGroup FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

      -- Storer group is setup
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer in storer group
         IF NOT EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE @cStorerGroup = StorerGroup AND StorerKey = @cStorer)
         BEGIN
             SET @nErrNo = -1
             SET @cErrMsg = rdt.rdtgetmessage(53,'ENG','DSP') --Bad StorerGrp
         END
      END
   END

   IF @nErrNo < 0
   BEGIN
      -- Update RDTMOBREC, set Error Message
      BEGIN TRAN

      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
         EditDate = GETDATE(),
         O_Field01 = @cStorer, O_Field02 = @cFacility ,
             ErrMsg = @cErrMsg,    Func = 1,
             O_Field03 = CASE V_UOM WHEN '1' THEN 'Pallet'
                                  WHEN '2' THEN 'Carton'
                                  WHEN '3' THEN 'Inner Pack'
                                  WHEN '4' THEN 'Other Unit 1'
                                  WHEN '5' THEN 'Other Unit 2'
                                  WHEN '6' THEN 'Each'
                                  ELSE 'Each'
                         END,
             O_Field04 = RTRIM(@cPrinter),  -- Added on 10-Aug-2007
             O_Field05 = RTRIM(@cPrinter_Paper),  --(Vicky01)
             O_Field06 = RTRIM(@cDeviceID) -- (ung02)
      WHERE Mobile = @nMobile

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END
   ELSE
   BEGIN
      DECLARE @nDefaultMenu int

      SELECT @nDefaultMenu = 5

      SELECT @nDefaultMenu = ISNULL(DefaultMenu, 5)
      FROM   RDT.rdtUser (NOLOCK)
      WHERE  UserName = @cUserName

      set @nFunction = @nDefaultMenu

      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
         EditDate = GETDATE(),
         StorerKey = @cStorer,
         StorerGroup = @cStorerGroup,
         Facility = @cFacility,
         Func = @nDefaultMenu,
         scn = @nDefaultMenu,
         menu = @nDefaultMenu,
         Step = 0 ,
         ErrMsg = @cErrMsg,
         Printer = RTRIM(@cPrinter), -- Added on 10-Aug-2007
         Printer_Paper = RTRIM(@cPrinter_Paper), -- (Vicky01)
         DeviceID = RTRIM( @cDeviceID), -- (ung02)
         I_Field01 = '',       I_Field02 = '',
         O_Field01 = '',       O_Field02 = '',        O_Field03 = '',
         I_Field03 = '',       I_Field04 = '',        O_Field04 = '',
         I_Field05 = '',       O_Field05 = '' -- (Vicky01)
      WHERE Mobile = @nMobile

   END
RETURN_SP:


GO