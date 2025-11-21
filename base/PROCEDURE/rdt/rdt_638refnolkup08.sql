SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP08                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 26-08-2022  YeeKung    1.0   WMS-20616 Created                             */
/* 23-11-2022  YeeKung    1.1   WMS-21214 substring refno (yeekung02)         */
/* 23-09-2022  YeeKung    1.2   WMS-20820 Extended refno length (yeekung01)   */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RefNoLKUP08]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 60)  OUTPUT --(yeekung)
   ,@cReceiptKey  NVARCHAR( 10)  OUTPUT
   ,@nBalQTY      INT            OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nRowCount      INT
   DECLARE @cOperator      NVARCHAR( 10)
   DECLARE @cRefNoPattern  NVARCHAR( 22)
   DECLARE @cOrderkey      NVARCHAR( 20)
   DECLARE @cErrMsg01      NVARCHAR( 20)
   DECLARE @cErrMsg02      NVARCHAR( 20)
   DECLARE @cErrMsg03      NVARCHAR( 20)
   DECLARE @cErrMsg04      NVARCHAR( 20)
   DECLARE @cErrMsg05      NVARCHAR( 20)
   DECLARE @cTablename     NVARCHAR( 20)
   DECLARE @bSuccess       INT

   SET @nRowCount = 0

   IF LEN(@cRefNo)=19 and SUBSTRING(@cRefNo,1,1)='R'
      SET @cRefNo=Right(@cRefNo,15) --yeekung02

   SET @cRefNoPattern = '%' + TRIM( @cRefNo) + '%' -- To support LIKE operator

   DECLARE @curSearch CURSOR
   SET @curSearch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Code, Long
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'REFNOLKUP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      ORDER BY Short
   OPEN @curSearch
   FETCH NEXT FROM @curSearch INTO @cColumnName, @cOperator
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check column valid
      IF NOT EXISTS( SELECT 1
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = 'Receipt'
            AND COLUMN_NAME = @cColumnName
            AND DATA_TYPE = 'nvarchar')
      BEGIN
         SET @nErrNo = 190401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
         GOTO Quit
      END

      -- Check column indexed
      IF NOT EXISTS( SELECT TOP 1 1
         FROM sys.index_columns (NOLOCK)
         WHERE OBJECT_ID = OBJECT_ID( 'Receipt')
            AND COLUMNPROPERTY( object_id, @cColumnName, 'ColumnId') = column_id)
      BEGIN
         SET @nErrNo = 190402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ColumnNoIndex
         GOTO Quit
      END

      SET @cSQL =
         ' SELECT ' +
            ' @cReceiptKey = R.ReceiptKey, ' +
            ' @cRefNo = R.' + @cColumnName +
         ' FROM dbo.Receipt R WITH (NOLOCK) ' +
            CASE WHEN @cSKU = '' THEN '' ELSE ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' END +
         ' WHERE R.Facility = @cFacility ' +
            ' AND R.StorerKey = @cStorerKey ' +
            ' AND R.Status <> ''9'' ' +
            CASE WHEN @cOperator = ''
               THEN ' AND R.' + @cColumnName + ' = @cRefNo '
               ELSE ' AND R.' + @cColumnName + ' LIKE @cRefNoPattern '
            END +
            CASE WHEN @cSKU = '' THEN '' ELSE ' AND RD.SKU = @cSKU ' END +
         ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
      SET @cSQLParam =
         ' @nMobile        INT, ' +
         ' @cFacility      NVARCHAR(5),  ' +
         ' @cStorerKey     NVARCHAR(15), ' +
         ' @cRefNoPattern  NVARCHAR(22), ' +
         ' @cSKU           NVARCHAR(20), ' +
         ' @cRefNo         NVARCHAR(20) OUTPUT, ' +
         ' @cReceiptKey    NVARCHAR(10) OUTPUT, ' +
         ' @nRowCount      INT          OUTPUT, ' +
         ' @nErrNo         INT          OUTPUT  '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile,
         @cFacility,
         @cStorerKey,
         @cRefNoPattern,
         @cSKU,
         @cRefNo      OUTPUT,
         @cReceiptKey OUTPUT,
         @nRowCount   OUTPUT,
         @nErrNo      OUTPUT

      IF @cReceiptKey <> ''
         BREAK

      FETCH NEXT FROM @curSearch INTO @cColumnName, @cOperator
   END

   -- Check RefNo in ASN
   IF @cReceiptKey = ''
   BEGIN
      SELECT @cOrderkey=orderkey
      FROM orders (NOLOCK)
      WHERE trackingno=@cRefNo

      IF ISNULL(@cOrderkey,'')=''
      BEGIN
         SELECT @cOrderkey=orderkey
         FROM cnarchive.dbo.orders (NOLOCK)
         WHERE trackingno=@cRefNo

         IF ISNULL(@cOrderkey,'')=''
         BEGIN
            SET @cErrMsg01 = rdt.rdtgetmessage( 190403, @cLangCode, 'DSP') --TrackingNo
            SET @cErrMsg02 = rdt.rdtgetmessage( 190404, @cLangCode, 'DSP') --Not Exists

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg01, 
            @cErrMsg02, 
            @cErrMsg03, 
            @cErrMsg04, 
            @cErrMsg05  

            GOTO QUIT
         END
      END

      SET @bSuccess = 1    
      EXEC ispGenTransmitLog2     
      @c_TableName         = 'WSSORTNLOGQM'   
      ,@c_Key1             = @cOrderkey    
      ,@c_Key2             = ''    
      ,@c_Key3             = @cStorerkey    
      ,@c_TransmitBatch    = ''    
      ,@b_Success          = @bSuccess    OUTPUT    
      ,@n_err              = @nErrNo      OUTPUT    
      ,@c_errmsg           = @cErrMsg     OUTPUT  

      SET @cErrMsg01 = rdt.rdtgetmessage( 190405, @cLangCode, 'DSP') --TrackingNo
      SET @cErrMsg02 = rdt.rdtgetmessage( 190406, @cLangCode, 'DSP') --Not Exists


      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
         @cErrMsg01, 
         @cErrMsg02, 
         @cErrMsg03, 
         @cErrMsg04, 
         @cErrMsg05  
   END

Quit:

END

GO