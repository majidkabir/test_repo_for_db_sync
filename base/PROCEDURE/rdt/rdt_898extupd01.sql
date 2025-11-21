SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_898ExtUpd01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 15-10-201$  1.0  Ung       SOS323106. Created                        */
/* 18-03-2016  1.1  ChewKP    SOS#366197 Changes (ChewKP01)             */
/* 24-02-2020  1.2  Leong     INC1049672 - Revise BT Cmd parameters.    */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtUpd01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cLOC         NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cUCC         NVARCHAR( 20)
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@cParam1      NVARCHAR( 20) OUTPUT
   ,@cParam2      NVARCHAR( 20) OUTPUT
   ,@cParam3      NVARCHAR( 20) OUTPUT
   ,@cParam4      NVARCHAR( 20) OUTPUT
   ,@cParam5      NVARCHAR( 20) OUTPUT
   ,@cOption      NVARCHAR( 1)
   ,@nErrNo       INT       OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine01 NVARCHAR(15)
          ,@cUserName     NVARCHAR(18)
          ,@cLabelPrinter NVARCHAR(10)
          ,@cPaperPrinter NVARCHAR(10)

   SET @cUserDefine01 = ''
   SET @cUserName     = ''
   SET @cLabelPrinter = ''
   SET @cPaperPrinter = ''

   IF @nStep = 12 -- Close pallet
   BEGIN
      IF @cOption = '1' -- No
         RETURN

      IF @cOption = '2' -- Yes
      BEGIN
         -- Get StorerKey
         DECLARE @cStorerKey NVARCHAR( 15)
         SELECT @cStorerKey = StorerKey FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

         -- Get printer info
         SELECT
            @cUserName = UserName,
            @cLabelPrinter = Printer,
            @cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Check label printer blank
         IF @cLabelPrinter = ''
         BEGIN
            SET @nErrNo = 50801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO Quit
         END

         -- (ChewKP01)
--         DECLARE CursorUserDefined CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--
--
--         --SELECT TOP 1 @cUserDefine01 = UserDefined01
--         SELECT Distinct UserDefined01
--         FROM dbo.UCC WITH (NOLOCK)
--         WHERE ID = @cToID
--         AND StorerKey  = @cStorerKey
--         AND ReceiptKey = @cReceiptKey
--         AND LOC        = @cLoc
--
--         OPEN CursorUserDefined
--
--         FETCH NEXT FROM CursorUserDefined INTO @cUserDefine01
--
--
--         WHILE @@FETCH_STATUS <> -1
--         BEGIN

--            INSERT INTO TRACEINFO (TraceName , TimeIn , Col1, col2 , Col3 , col4, col5, Step1)
--            VALUES ( 'RDTBAR', Getdate() , @cUserName , @cToID , @cUserDefine01 , @cStorerKey, @cReceiptKey, @cLoc)

            -- Print label
            EXEC dbo.isp_BT_GenBartenderCommand
               @cPrinterID     = @cLabelPrinter
             , @c_LabelType    = 'PALLETLABEL'
             , @c_userid       = @cUserName
             , @c_Parm01       = @cToID
             , @c_Parm02       = '' -- @cUserDefine01 -- OrderKey -- (ChewKP01)
             , @c_Parm03       = @cReceiptKey
             , @c_Parm04       = ''
             , @c_Parm05       = ''
             , @c_Parm06       = ''
             , @c_Parm07       = ''
             , @c_Parm08       = ''
             , @c_Parm09       = ''
             , @c_Parm10       = ''
             , @c_StorerKey    = @cStorerKey
             , @c_NoCopy       = '1'
             , @b_Debug        = '0'
             , @c_Returnresult = 'N'
             , @n_err          = @nErrNo  OUTPUT
--             FETCH NEXT FROM CursorUserDefined INTO @cUserDefine01
--         END
--
--         CLOSE CursorUserDefined
--         DEALLOCATE CursorUserDefined

      END

      IF @cOption = '3' -- Yes and putaway
      BEGIN
         SET @nErrNo = 50802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionNotAllow
         GOTO Quit
      END
   END

Quit:
END

GO