SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_608RefNoLKUP06                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Reference LookUP customize for triple(04->06)                     */  
/*                                                                            */  
/* Date        Author   Ver.  Purposes                                        */  
/* 27-07-2020  YeeKung  1.0   WMS-14409 Created                               */  
/* 08-09-2022  Ung      1.1   WMS-20348 Expand RefNo to 60 chars              */
/* 06-06-2023  YeeKung  1.2   WMS-22699 Add criteria (yeekung01)              */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_608RefNoLKUP06]  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @cFacility    NVARCHAR( 5),     
   @cStorerGroup NVARCHAR( 20),   
   @cStorerKey   NVARCHAR( 15),   
   @cRefNo       NVARCHAR( 60),   
   @cReceiptKey  NVARCHAR( 10)  OUTPUT,   
   @nErrNo       INT            OUTPUT,   
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_err          INT  
   DECLARE @bSuccess       INT  
   DECLARE @nTranCount     INT  
   DECLARE @nRowCount      INT  
   DECLARE @cSQL           NVARCHAR( MAX)  
   DECLARE @cSQLParam      NVARCHAR( MAX)  
   DECLARE @cDataType      NVARCHAR( 128)  
     
   DECLARE @cOrderKey      NVARCHAR(10)  
   DECLARE @cLOC           NVARCHAR(10)  
   DECLARE @cColumnName    NVARCHAR(30)  
   DECLARE @nReceiptField  INT  
   DECLARE @nOrderField    INT  
   DECLARE @curColumn      CURSOR  
     
   SET @nTranCount = @@TRANCOUNT  
   SET @nReceiptField = 0  
   SET @nOrderField = 0  
     
   IF @cStorerGroup <> ''   
      SET @curColumn = CURSOR FOR  
         SELECT Code   
         FROM CodeLKUP C WITH (NOLOCK)   
         WHERE ListName = 'RefReceipt'   
            AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = C.StorerKey)  
            AND Code2 = @nFunc  
         ORDER BY Short  
   ELSE  
      SET @curColumn = CURSOR FOR  
         SELECT Code   
         FROM CodeLKUP WITH (NOLOCK)   
         WHERE ListName = 'RefReceipt'   
            AND StorerKey = @cStorerKey   
            AND Code2 = @nFunc  
         ORDER BY Short  
     
   OPEN @curColumn  
   FETCH NEXT FROM @curColumn INTO @cColumnName  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Check max lookup field (for performance, ref field might not indexed)  
      SET @nReceiptField = @nReceiptField + 1  
      IF @nReceiptField > 2  
      BEGIN  
         SET @nErrNo = 155751  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Max 2 RefField 
         GOTO Quit  
      END  
  
      -- Get lookup field data type  
      SET @cDataType = ''  
      SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName  
        
      IF @cDataType <> ''  
      BEGIN  
         IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE  
         IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE   
         IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE   
         IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)  
                             
         -- Check data type  
         IF @n_Err = 0  
         BEGIN  
            SET @nErrNo = 155752  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo  
            GOTO Quit  
         END  
           
         SET @cSQL =   
            ' SELECT @cReceiptKey = ReceiptKey ' +   
            ' FROM dbo.Receipt WITH (NOLOCK) ' +   
            ' WHERE Facility = @cFacility ' +   
               ' AND Status NOT IN (''9'', ''CANC'') ' +   
               ' AND ASNStatus <> ''CANC'' ' +   
               CASE WHEN @cDataType IN ('int', 'float')   
                    THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '   
                    ELSE ' AND ISNULL( ' + @cColumnName + ', '''')  like ''' + @cRefNo+ '%'''
               END +   
               CASE WHEN @cStorerGroup = ''   
                    THEN ' AND StorerKey = @cStorerKey '   
                    ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = Receipt.StorerKey) '   
               END +   
            ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '   
         SET @cSQLParam =  
            ' @nMobile      INT, ' +   
            ' @cFacility    NVARCHAR(5),  ' +   
            ' @cStorerGroup NVARCHAR(20), ' +   
            ' @cStorerKey   NVARCHAR(15), ' +   
            ' @cColumnName  NVARCHAR(20), ' +    
            ' @cRefNo       NVARCHAR(30), ' +   
            ' @cReceiptKey  NVARCHAR(10) OUTPUT, ' +   
            ' @nRowCount    INT          OUTPUT, ' +   
            ' @nErrNo       INT          OUTPUT  '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
            @nMobile,   
            @cFacility,   
            @cStorerGroup,   
            @cStorerKey,   
            @cColumnName,   
            @cRefNo,   
            @cReceiptKey OUTPUT,   
            @nRowCount   OUTPUT,   
            @nErrNo      OUTPUT  

            print  @cSQL
           select @cSQL

         IF @nErrNo <> 0  
            GOTO Quit  
     
         -- Check RefNo in ASN  
         IF @nRowCount > 1  
         BEGIN  
            SET @nErrNo = 155753  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi ASN  
            GOTO Quit  
         END  
  
         IF @cReceiptKey <> ''  
            BREAK              
      END  
              
      FETCH NEXT FROM @curColumn INTO @cColumnName  
   END  
  
   -- Receipt not found  
   IF @cReceiptKey = ''  
   BEGIN  
      SET @nErrNo = 155754  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN NotFound  
      GOTO Quit  
   END  
   GOTO Quit  
  
RollBackTran:    
   ROLLBACK TRAN rdt_608RefNoLKUP06   
Fail:    
Quit:
 
   IF @nErrNo<>0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- Sign-in
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cRefNo1     = @cErrMsg,
         @ctrackingno = @cRefNo
   END   

   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN      
END  

GO