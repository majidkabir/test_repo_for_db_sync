SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
    
/***************************************************************************/    
/* Store procedure: rdt_638ExtValid05                                      */    
/* Purpose: Validate TO ID                                                 */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author     Purposes                                     */    
/* 2020-08-26 1.0  Ung        WMS-14691 Created                            */    
/* 2021-01-26 1.1  James      WMS-16163 Add Refno check (james01)          */  
/* 03-03-2021 1.2  Ung        WMS-16466 WarehouseReference to CarrierName  */  
/* 26-03-2021 1.3  James      WMS-16506 Add check if ASN locked (james02)  */  
/* 26-03-2021 1.3  James      WMS-16735 Add RDTL.UDF02 checking (james03)  */  
/* 02-07-2021 1.4  James      WMS-17405 Change one of the blacklist check  */  
/*                            to prompt error instead of msgqueue (james04)*/  
/* 02-08-2022 1.5  James      WMS-20356 Change logic on checking time-out  */
/*                            period (james04)                             */
/* 23-09-2022 1.6  YeeKung    WMS-20820 Extended refno length (yeekung01)  */
/* 18-01-2023 1.7  James      WMS-21480 Add NFC sku check (james05)        */
/*                            Bug fix on blacklist checking                */
/***************************************************************************/    
    
CREATE   PROC [RDT].[rdt_638ExtValid05] (    
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cReceiptKey   NVARCHAR( 10),  
   @cRefNo        NVARCHAR( 60), --(yeekung01)
   @cID           NVARCHAR( 18),  
   @cLOC          NVARCHAR( 10),  
   @cSKU          NVARCHAR( 20),  
   @nQTY          INT,  
   @cLottable01   NVARCHAR( 18),  
   @cLottable02   NVARCHAR( 18),  
   @cLottable03   NVARCHAR( 18),  
   @dLottable04   DATETIME,  
   @dLottable05   DATETIME,  
   @cLottable06   NVARCHAR( 30),  
   @cLottable07   NVARCHAR( 30),  
   @cLottable08   NVARCHAR( 30),  
   @cLottable09   NVARCHAR( 30),  
   @cLottable10   NVARCHAR( 30),  
   @cLottable11   NVARCHAR( 30),  
   @cLottable12   NVARCHAR( 30),  
   @dLottable13   DATETIME,  
   @dLottable14   DATETIME,  
   @dLottable15   DATETIME,  
   @cData1        NVARCHAR( 60),  
   @cData2        NVARCHAR( 60),  
   @cData3        NVARCHAR( 60),  
   @cData4        NVARCHAR( 60),  
   @cData5        NVARCHAR( 60),  
   @cOption       NVARCHAR( 1),  
   @dArriveDate   DATETIME,  
   @tExtUpdateVar VariableTable READONLY,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT   
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @nisValidLoc    INT = 1  
   DECLARE @cUserDefine08       NVARCHAR(30)  
   DECLARE @cCarrierName        NVARCHAR(30)  
   DECLARE @cSellerPhone1       NVARCHAR(18)  
   DECLARE @cBlackList          NVARCHAR(1) = ''  
   DECLARE @dUserDefine07       DATETIME  
   DECLARE @cUserDefine02       NVARCHAR( 30)  
   DECLARE @cOtherUserName      NVARCHAR( 18)  
   DECLARE @cUserName           NVARCHAR( 18)  
   DECLARE @cGroupList          NVARCHAR( 1) = ''  
   DECLARE @cErrMsg1            NVARCHAR( 20)  
   DECLARE @cErrMsg2            NVARCHAR( 20)  
   DECLARE @cUDF02              NVARCHAR( 60) = ''  
   DECLARE @nPromtUDF02         INT = 0  
   DECLARE @cUserDefine04        NVARCHAR( 30)  
   DECLARE @cSellerCity         NVARCHAR( 45) = ''
   DECLARE @cUserDefine10       NVARCHAR( 30) = ''
   DECLARE @nUpdErrNo           INT = 0
   
   SET @nErrNo = 0    
    
   IF @nFunc = 638 -- ECOM return  
   BEGIN  
      IF @nStep = 1 -- RefNo, ASN    
      BEGIN    
         IF @nInputKey = 1    
         BEGIN  
            SELECT @cUserName = UserName  
            FROM RDT.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
            -- Get ASN info  
            SELECT   
               @cUserDefine02 = UserDefine02,  
               @cUserDefine08 = UserDefine08,   
               @cCarrierName = ISNULL( CarrierName, ''),   
               @cSellerPhone1 = ISNULL( SellerPhone1, ''),  
               @dUserDefine07 = UserDefine07, 
               @cSellerCity = SellerCity, 
               @cUserDefine10 = UserDefine10    
            FROM Receipt WITH (NOLOCK)   
            WHERE ReceiptKey = @cReceiptKey    

            IF @cUserDefine10 = 'NFC' AND ISNULL( @cUserDefine08, '') = ''
            BEGIN  
               SET @nErrNo = 158367  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NFC ASN  
               GOTO Quit  
            END  

            IF @cUserDefine10 = 'NFC' AND ISNULL( @cUserDefine08, '') = 'RFID'
            BEGIN  
               SET @nErrNo = 158368  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NFC RFID ASN  
               GOTO Quit  
            END  

            -- Directly key-in ASN  
            IF @cRefNo = ''  
            BEGIN  
               -- (james03)  
               IF @cUserDefine02 IN ('2', '21')  
               BEGIN  
                  SET @cErrMsg1 = rdt.rdtgetmessage( 158360, @cLangCode, 'DSP') --Program Order  
                  SET @cErrMsg2 = rdt.rdtgetmessage( 158361, @cLangCode, 'DSP') --Must Receive  
                 
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
                                   
                  SET @nErrNo = 0   -- prompt only, still need goto next screen  
                  SET @cErrMsg = ''  
                  SET @nPromtUDF02 = 1  
               END  

               -- Check RFID ASN  
               IF @cUserDefine08 = 'RFID'  
               BEGIN  
                  SET @nErrNo = 158351  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RFID ASN  
                  GOTO Quit  
               END  
                 
               -- Check black list (platform order no)  
               IF @cCarrierName <> ''  
                  SELECT TOP 1   
                     @cBlackList = 'Y'  
                  FROM DocInfo WITH (NOLOCK)  
                  WHERE TableName = 'CHECKLIST'  
                     AND StorerKey = @cStorerKey  
                     AND Key2 = LEFT( @cCarrierName, 20)  
  
               -- Check black list (phone no)  
               IF @cSellerPhone1 <> ''  
                  SELECT TOP 1   
                     @cBlackList = 'Y'  
                  FROM DocInfo WITH (NOLOCK)  
                  WHERE TableName = 'CHECKLIST'  
                     AND StorerKey = @cStorerKey  
                     AND Key3 = @cSellerPhone1  
  
               -- Check black list (tracking no)  
               SELECT TOP 1   
                  @cBlackList = 'Y'  
               FROM DocInfo WITH (NOLOCK)  
               WHERE TableName = 'CHECKLIST'  
                  AND StorerKey = @cStorerKey  
                  AND Key1 IN (  
                     SELECT Key3  
                     FROM DocInfo WITH (NOLOCK)  
                     WHERE StorerKey = @cStorerKey  
                        AND TableName = 'RECEIPT'  
                        AND Key1 = @cReceiptKey  
                        AND Key2 = 'TRACKINGNO'  
                        AND Key3 IS NOT NULL  
                        AND Key3 <> '')  
  
               -- (james04)  
               IF @@ROWCOUNT = 1  
               BEGIN  
                  SET @nErrNo = 158364  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Black List  
                  --GOTO Quit  -- commented due to need stamp ASNReason below (james05)
               END  
                 
               SELECT TOP 1   
                  @cGroupList = 'Y'   
               FROM DocInfo WITH (NOLOCK)   
               WHERE TABLENAME IN ('GROUPLIST')   
               AND   Key2 IN (  
                        SELECT CarrierName  
                        FROM dbo.RECEIPT WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)  
  
               -- Prompt black list  
               IF @cBlackList = 'Y' OR @cGroupList = 'Y'  
               BEGIN  
                  DECLARE @cMsg NVARCHAR(20)  
                  --IF @cBlackList = 'Y'  
                  --   SET @cMsg = rdt.rdtgetmessage( 158352, @cLangCode, 'DSP') --BLACK LIST  
                  --ELSE  
                  --   SET @cMsg = rdt.rdtgetmessage( 158359, @cLangCode, 'DSP') --BLACK LIST  
                  -- (james05)
                  IF @cBlackList <> 'Y' AND @cGroupList = 'Y'
                  BEGIN
                     SET @cMsg = rdt.rdtgetmessage( 158359, @cLangCode, 'DSP') --GROUP LIST  
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, '', @cMsg  
                     SET @nErrNo = 158359 -- For remain in RefNo screen
                  END
                  
                  DECLARE @nTranCount INT  
                  SET @nTranCount = @@TRANCOUNT  
                  BEGIN TRAN  -- Begin our own transaction  
                  SAVE TRAN rdt_638ExtValid05 -- For rollback or commit only our own transaction  
                 
                  -- Mark ASN as black list  
                  UPDATE Receipt SET  
                     ASNReason = 'CHECKLIST',   
                     EditDate = GETDATE(),   
                     EditWho = SUSER_SNAME()  
                  WHERE ReceiptKey = @cReceiptKey  
                  SET @nUpdErrNo = @@ERROR   -- Not to overwrite existing error no if any
                  IF @nUpdErrNo <> 0  
                  BEGIN  
                     ROLLBACK TRAN rdt_638ExtValid05  
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                        COMMIT TRAN  
                       
                     SET @cErrMsg = rdt.rdtgetmessage( @nUpdErrNo, @cLangCode, 'DSP') --RFID ASN                       
                     GOTO Quit  
                  END  
  
                  COMMIT TRAN rdt_638ExtValid05  
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                     COMMIT TRAN  

                  -- SET @nErrNo = -1 -- For remain in RefNo screen  
               END  
            END  
  
            IF @dUserDefine07 IS NOT NULL  AND ISNULL( @cSellerCity, '') <> ''  
            BEGIN  
               SELECT @cUDF02 = UDF02  
               FROM dbo.CODELKUP WITH (NOLOCK)  
               WHERE LISTNAME = 'RCITY'  
               AND   Storerkey = @cStorerKey  
               AND   Long = @cSellerCity
               AND   code2 = @cFacility
                    
               IF ISNULL( @cUDF02, '') <> '' AND rdt.rdtIsValidQTY( @cUDF02, 0) = 1  
               BEGIN  
                  IF DATEDIFF( d, @dUserDefine07, GETDATE() ) > CAST( @cUDF02 AS INT)  
                  BEGIN  
                     SET @nErrNo = 158357  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER 14 DAYS  
                     GOTO Quit  
                  END  
               END  
            END  
  
            -- Check if same ASN used by more than 1 user      
            SET @cOtherUserName = ''      
            SELECT TOP 1 @cOtherUserName = UserName  -- (james01)    
            FROM rdt.rdtMobRec WITH (NOLOCK)      
            WHERE  Func = @nFunc      
            AND    StorerKey = @cStorerKey      
            AND    V_ReceiptKey = @cReceiptKey      
            AND    UserName <> @cUserName      
            AND    Step > 1      
            ORDER BY EditDate DESC      
  
            IF @cOtherUserName <> ''      
            BEGIN  
               SET @nErrNo = 158358  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN In Progress  
               GOTO Quit  
            END  
  
            -- (james03)  
            IF @cUserDefine02 IN ('2', '21') AND @cRefNo = '' AND @nPromtUDF02 = 0  
            BEGIN  
               SET @cErrMsg1 = rdt.rdtgetmessage( 158362, @cLangCode, 'DSP') --Program Order  
               SET @cErrMsg2 = rdt.rdtgetmessage( 158363, @cLangCode, 'DSP') --Must Receive  
                 
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
                                   
               SET @nErrNo = 0   -- prompt only, still need goto next screen  
               SET @cErrMsg = ''  
               GOTO Quit  
            END  
         END  
      END  
        
      IF @nStep = 3 -- SKU    
      BEGIN    
         IF @nInputKey = 1    
         BEGIN    
            -- Get SKU info  
            DECLARE @cExtendedField01 NVARCHAR( 30)  
            DECLARE @cExtendedField02 NVARCHAR( 30)  
            DECLARE @cExtendedField03 NVARCHAR( 30)  
            DECLARE @cExtendedField04 NVARCHAR( 30)  
            SELECT   
               @cExtendedField01 = ISNULL( ExtendedField01, ''),  
               @cExtendedField02 = ISNULL( ExtendedField02, ''),  
               @cExtendedField03 = ISNULL( ExtendedField03, ''),  
               @cExtendedField04 = ISNULL( ExtendedField04, '')  
            FROM SKUInfo WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
               AND SKU = @cSKU  
              
            DECLARE @cMsg1 NVARCHAR( 20) = ''  
            DECLARE @cMsg2 NVARCHAR( 20) = ''  
            DECLARE @cMsg3 NVARCHAR( 20) = ''  
            DECLARE @cMsg4 NVARCHAR( 20) = ''  
            DECLARE @cMsg5 NVARCHAR( 20) = ''
            
            -- Check SKU warning  
            IF @cExtendedField01 = 'BP1'  SET @cMsg1 = rdt.rdtgetmessage( 158353, @cLangCode, 'DSP') --BP#1 SKU  
            IF @cExtendedField02 = 'BP2'  SET @cMsg2 = rdt.rdtgetmessage( 158354, @cLangCode, 'DSP') --BP#2 SKU  
            IF @cExtendedField03 = 'RFID' SET @cMsg3 = rdt.rdtgetmessage( 158355, @cLangCode, 'DSP') --RFID SKU  
            IF @cExtendedField04 = 'SET'  SET @cMsg4 = rdt.rdtgetmessage( 158356, @cLangCode, 'DSP') --SET SKU  

            -- (james05)
            IF @cExtendedField03 = 'NFC'   
               SET @cMsg5 = rdt.rdtgetmessage( 158366, @cLangCode, 'DSP')  --Cannot Rcv NFC SKU

            -- Popup warning  
            IF @cMsg1 <> '' OR   
               @cMsg2 <> '' OR  
               @cMsg3 <> '' OR  
               @cMsg4 <> '' OR  
               @cMsg5 <> ''   
            BEGIN  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, '', @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5  
            END  
         END    
      END   
        
      IF @nStep = 8 -- Finalize ASN  
      BEGIN  
         IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
                     WHERE ReceiptKey = @cReceiptKey  
                     GROUP BY ReceiptKey  
                     HAVING SUM( QtyReceived) > 0)     
         BEGIN  
            IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)   
                        WHERE ReceiptKey = @cReceiptKey   
                        AND   ISNULL( UserDefine02, '') = ''  
                        AND   ISNULL( UserDefine04, '') = '')  
            BEGIN  
               SET @nErrNo = 158365  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank RDT UDF  
               GOTO Quit  
            END  
         END  
      END  
   END  
     
Quit:  


GO