SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_638Finalize03                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-04-15 1.0  James   WMS-16668. Created                              */
/* 2022-09-23 1.1  YeeKung WMS-20820 Extended refno length (yeekung01)     */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_638Finalize03](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @bSuccess    INT
   DECLARE @nRowCount   INT
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cCode          NVARCHAR( 10)
   DECLARE @cColumn        NVARCHAR( 20)
   DECLARE @cData1         NVARCHAR( 60)
   DECLARE @cData2         NVARCHAR( 60)
   DECLARE @cData3         NVARCHAR( 60)
   DECLARE @cData4         NVARCHAR( 60)
   DECLARE @cData5         NVARCHAR( 60)


   CREATE TABLE #tReceipt
   (
      ReceiptKey NVARCHAR(10) NOT NULL
   )

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_638Finalize03

   -- Auto finalize upon receive
   DECLARE @cFinalizeRD NVARCHAR(1)
   SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetail', @cStorerKey)
   IF @cFinalizeRD IN ('', '0')
      SET @cFinalizeRD = '1' -- Default = 1

   -- Lookup multi columns
   DECLARE @curSearch CURSOR
   SET @curSearch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Code
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'REFNOLKUP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      ORDER BY Short
   OPEN @curSearch
   FETCH NEXT FROM @curSearch INTO @cColumnName
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check column valid
      IF NOT EXISTS( SELECT 1
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = 'Receipt'
            AND COLUMN_NAME = @cColumnName
            AND DATA_TYPE = 'nvarchar')
      BEGIN
         SET @nErrNo = 165451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
         GOTO Quit
      END

      -- Check column indexed
      IF NOT EXISTS( SELECT TOP 1 1
         FROM sys.index_columns (NOLOCK)
         WHERE OBJECT_ID = OBJECT_ID( 'Receipt')
            AND COLUMNPROPERTY( object_id, @cColumnName, 'ColumnId') = column_id)
      BEGIN
         SET @nErrNo = 165451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ColumnNoIndex
         GOTO Quit
      END

      SET @cSQL =
         ' INSERT INTO #tReceipt (ReceiptKey) ' +
         ' SELECT DISTINCT ReceiptKey ' +
         ' FROM dbo.Receipt WITH (NOLOCK) ' +
         ' WHERE Facility = @cFacility ' +
            ' AND StorerKey = @cStorerKey ' +
            ' AND Status <> ''9'' ' +
            ' AND ASNStatus NOT IN (''CANC'', ''9'') ' +
            ' AND ' + @cColumnName + ' = @cRefNo '  +
            ' SELECT @nRowCount = COUNT(1) FROM #tReceipt '

      SET @cSQLParam =
         ' @cFacility      NVARCHAR(5),  ' +
         ' @cStorerKey     NVARCHAR(15), ' +
         ' @cRefNo         NVARCHAR(20), ' +
         ' @nRowCount      INT OUTPUT '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cFacility,
         @cStorerKey,
         @cRefNo,
         @nRowCount OUTPUT

         IF @nRowCount > 0
            BREAK

      FETCH NEXT FROM @curSearch INTO @cColumnName
   END
   --SELECT ReceiptKey, '1' FROM #tReceipt
   -- Finalize ASN by line if no more variance
   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT RD.ReceiptKey, RD.ReceiptLineNumber
   FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
   JOIN #tReceipt t ON ( RD.ReceiptKey = t.ReceiptKey)
   WHERE RD.BeforeReceivedQTY > 0
   AND   RD.FinalizeFlag <> 'Y'
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cReceiptKey, @cReceiptLineNumber
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @cFinalizeRD = '1'
      BEGIN
         -- Bulk update (so that trigger fire only once, compare with row update that fire trigger each time)
         UPDATE dbo.ReceiptDetail SET
            QTYReceived = RD.BeforeReceivedQTY,
            FinalizeFlag = 'Y',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         FROM dbo.ReceiptDetail RD
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      IF @cFinalizeRD = '2'
      BEGIN
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @bSuccess   OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cReceiptLineNumber
         IF @nErrNo <> 0 OR @bSuccess = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM CUR_UPD INTO @cReceiptKey, @cReceiptLineNumber
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   IF rdt.RDTGetConfig( @nFunc, 'CloseASNUponFinalize', @cStorerKey) = '1'
      AND @cFinalizeRD > 0
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ReceiptKey
      FROM #tReceipt
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cReceiptKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                         WHERE ReceiptKey = @cReceiptKey
                         AND   FinalizeFlag = 'N'
                         AND   BeforeReceivedQty > 0)
         BEGIN
            -- Close Status and ASNStatus here. If turn on config at WMS side then all ASN will be affected,
            -- no matter doctype. This only need for ecom ASN only. So use rdt config to control
            UPDATE dbo.RECEIPT SET
               ASNStatus = '9',
               -- Status    = '9',  -- Should not overule Exceed trigger logic
               ReceiptDate = GETDATE(),
               FinalizeDate = GETDATE(),
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE ReceiptKey = @cReceiptKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM CUR_UPD INTO @cReceiptKey
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   SET @cSQL = ''
   SET @cSQLParam = ''

   -- Construct update columns TSQL
   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT Code, Long
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTExtUpd'
      AND Storerkey = @cStorerKey
      AND Code2 = @nFunc
   ORDER BY Code
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cCode, @cColumn
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Build update column TSQL
      IF ISNULL( @cColumn, '') <> ''
         SET @cSQL = @cSQL + @cColumn + ' = @cData' + @cCode + ', '

      FETCH NEXT FROM CUR_UPD INTO @cCode, @cColumn
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD

   IF @cSQL <> ''
   BEGIN
      SELECT
         @cData1 = V_String41,
         @cData2 = V_String42,
         @cData3 = V_String43,
         @cData4 = V_String44,
         @cData5 = V_String45
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SET @cSQL =
         ' UPDATE R SET ' +
            @cSQL +
            ' EditDate = GETDATE(), ' +
            ' EditWho = SUSER_SNAME() ' +
         ' FROM dbo.Receipt R WITH (NOLOCK) ' +
         ' JOIN #tReceipt t ON R.ReceiptKey = t.ReceiptKey ' +
         ' SET @nErrNo = @@ERROR '

      SET @cSQLParam =
         ' @cReceiptKey NVARCHAR(10), ' +
         ' @cData1      NVARCHAR(60), ' +
         ' @cData2      NVARCHAR(60), ' +
         ' @cData3      NVARCHAR(60), ' +
         ' @cData4      NVARCHAR(60), ' +
         ' @cData5      NVARCHAR(60), ' +
         ' @nErrNo      INT OUTPUT    '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         ,@cReceiptKey
         ,@cData1
         ,@cData2
         ,@cData3
         ,@cData4
         ,@cData5
         ,@nErrNo OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END
   END

   GOTO QUIT

   RollBackTran:
      ROLLBACK TRAN rdt_638Finalize03 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_638Finalize03


END

GO