SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP10                                        */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: Search multiple columns, lookup TOP 1 ASN                         */
/*          1 tracking no might have multiple ASN, and same SKU in each ASN   */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-07-20   1.0  Ung        WMS-22017 base on rdt_638RefNoLookup01        */
/* 2023-09-02   1.1  Ung        WMS-23480 Add CANC status                     */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_638RefNoLKUP10](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 60)  OUTPUT
   ,@cReceiptKey  NVARCHAR( 10)  OUTPUT
   ,@nBalQTY      INT            OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nRowCount      INT = 0

   IF @nStep = 1 OR  -- RefNo, ASN
      @nStep = 3     -- SKU
   BEGIN
      /*
         Physically the stock came under 1 tracking no, but belong to multiple ASN. This storer is receiving ASN by ASN 
         Operator print all SKU label under the tracking no, stick to SKU (eyeball matching), and arrange the stock based on the label print out sequence
         Once an ASN is fully receive, it will prompt for finalize ASN. Stock put on conveyor
         If current ASN not fully receive, and next SKU not in current ASN, need to prompt error
         Operator will then ESC to finalize ASN, chose option 9-No, and mark the ASN have error. That ASN is exclude from RefNo lookup. Physical stock put aside
      */

      -- Parent module had reset the @cReceiptKey. Need to get back the current ASN 
      IF @nStep = 3
         SELECT @cReceiptKey = V_ReceiptKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      -- Get lookup info
      SELECT @cColumnName = Code
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'REFNOLKUP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      SET @cSQL = 
         ' SELECT TOP 1 ' + 
            ' @cReceiptKey = R.ReceiptKey ' + 
         ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
            CASE WHEN @cSKU = '' THEN '' ELSE ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' END + 
         ' WHERE R.Facility = @cFacility ' + 
            ' AND R.StorerKey = @cStorerKey ' + 
            ' AND R.Status <> ''9'' ' + 
            ' AND R.ASNStatus <> ''CANC'' ' +
            ' AND R.UserDefine09 <> ''E''  ' + 
            ' AND R.' + @cColumnName + ' = @cRefNo ' + 
            CASE WHEN @cReceiptKey = '' 
               THEN '' 
               ELSE ' AND R.ReceiptKey = @cReceiptKey '
            END + 
            CASE WHEN @cSKU = '' 
               THEN '' 
               ELSE ' AND RD.SKU = @cSKU ' + 
                    ' AND RD.QTYExpected > BeforeReceivedQTY '
            END + 
            ' ORDER BY R.ReceiptKey ' + 
         ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
      SET @cSQLParam =
         ' @nMobile        INT, ' + 
         ' @cFacility      NVARCHAR(5),  ' + 
         ' @cStorerKey     NVARCHAR(15), ' + 
         ' @cSKU           NVARCHAR(20), ' + 
         ' @cRefNo         NVARCHAR(20) OUTPUT, ' + 
         ' @cReceiptKey    NVARCHAR(10) OUTPUT, ' + 
         ' @nRowCount      INT          OUTPUT, ' + 
         ' @nErrNo         INT          OUTPUT  '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @nMobile, 
         @cFacility, 
         @cStorerKey, 
         @cSKU, 
         @cRefNo      OUTPUT, 
         @cReceiptKey OUTPUT, 
         @nRowCount   OUTPUT, 
         @nErrNo      OUTPUT
      
      IF @nStep = 1 -- RefNo, ASN
      BEGIN
         -- Check RefNo in ASN
         IF @cReceiptKey = ''
         BEGIN
            SET @nErrNo = 199501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
            GOTO Quit
         END
         
         -- RefNoSKULookup turned on, after scanned SKU only decide which ASN
         SET @cReceiptKey = ''
      END
      
      ELSE IF @nStep = 3 -- SKU
      BEGIN
         -- Check SKU in ASN
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 199502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in ASN
            GOTO Quit
         END
         
         -- Balance for ASN
         SELECT @nBalQTY = SUM( QTYExpected - BeforeReceivedQTY)
         FROM dbo.Receipt R WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
      END
   END
   
   ELSE IF @nStep = 8 -- Finalize ASN
   BEGIN
      -- Get lookup info
      SELECT @cColumnName = Code
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'REFNOLKUP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      
      -- Balance for RefNo (multi ASN)
      SET @cSQL = 
         ' SELECT @nBalQTY = SUM( QTYExpected - BeforeReceivedQTY) ' + 
         ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
            ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' + 
         ' WHERE R.Facility = @cFacility ' + 
            ' AND R.StorerKey = @cStorerKey ' + 
            ' AND R.Status <> ''9'' ' + 
            ' AND R.ASNStatus <> ''CANC'' ' +
            ' AND R.UserDefine09 <> ''E'' ' + 
            ' AND R.' + @cColumnName + ' = @cRefNo '
      SET @cSQLParam =
         ' @cFacility  NVARCHAR(5),  ' + 
         ' @cStorerKey NVARCHAR(15), ' + 
         ' @cRefNo     NVARCHAR(20), ' + 
         ' @nBalQTY    INT OUTPUT    '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @cFacility, 
         @cStorerKey, 
         @cRefNo, 
         @nBalQTY OUTPUT
   END

Quit:

END

GO