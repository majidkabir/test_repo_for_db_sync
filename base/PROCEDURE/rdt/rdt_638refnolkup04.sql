SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_638RefNoLKUP04                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose:                                                                   */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 28-08-2020   Ung       1.0   WMS-14691 Created                             */  
/* 03-03-2021   Ung       1.1   WMS-16466 WarehouseReference to CarrierName   */  
/* 26-03-2021   James     1.2   WMS-16506 Add Gouplist check (james01)        */  
/* 26-03-2021   James     1.3   WMS-16735 Add RDTL.UDF02 checking (james02)   */  
/* 02-07-2021   James     1.4   WMS-17405 Change one of the blacklist check   */  
/*                              to prompt error instead of msgqueue (james03) */  
/* 02-08-2022   James     1.5   WMS-20356 Change logic on checking time-out   */
/*                              period (james04)                              */
/* 11-11-2022   James     1.6   Perf tuning (james05)                         */
/* 23-09-2022   YeeKung   1.7   WMS-20820 Extended refno length (yeekung01)   */
/* 03-02-2023   James     1.8   WMS-21480 Add NFC sku check (james06)         */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_638RefNoLKUP04]  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR( 5)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU  
   ,@cRefNo       NVARCHAR( 60)  OUTPUT --(yeekung01)
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
  
   DECLARE @cUserDefine08       NVARCHAR(30)  
   DECLARE @cCarrierName        NVARCHAR(30)  
   DECLARE @cSellerPhone1       NVARCHAR(18)  
   DECLARE @cBlackList          NVARCHAR(1) = ''  
   DECLARE @cPlatformOrderNo    NVARCHAR( 50)  
   DECLARE @cExternOrderKey     NVARCHAR( 50)  
   DECLARE @cGroupList          NVARCHAR(1) = ''  
   DECLARE @dUserDefine07       DATETIME  
   DECLARE @cUserDefine02       NVARCHAR( 30)     
   DECLARE @cErrMsg1            NVARCHAR( 20)  
   DECLARE @cErrMsg2            NVARCHAR( 20)  
   DECLARE @cUDF02              NVARCHAR( 60) = ''  
   DECLARE @cSellerCity         NVARCHAR( 45) = ''
   DECLARE @cUserDefine10       NVARCHAR( 30) = ''
   
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
     
   -- Receipt not yet found  
   IF @cRefNo <> '' AND @cReceiptKey = ''  
   BEGIN  
      /*  
      -- Lookup tracking no  
         NIKE is using one of the older interface model to Bao Jun where:  
            1 ASN could have multiple tracking no  
            1st tracking no, came with all SKU  
            Subsequence tracking no, came without SKU  
            So tracking no does not belong to either header or detail, it is store in DocInfo  
      */  
      SELECT @cReceiptKey = D.Key1  
      FROM DocInfo D WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND TableName = 'RECEIPT'  
         AND Key2 = 'TRACKINGNO'  
         AND Key3 = @cRefNo  
         AND EXISTS ( SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)   
                      WHERE D.Key1 = R.ReceiptKey   
                      AND   R.ASNStatus NOT IN ('9', 'CANC'))  
      GROUP BY D.Key1  
        
      IF @@ROWCOUNT > 1  
      BEGIN  
         SET @nErrNo = 158401  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Found MultiASN  
         GOTO Quit  
      END  
      /*  
      -- Lookup platform order no  
         There are 3 order no:  
            Platform order no (Receipt.CarrierName, ExternOrders.PlatformOrderNo), order no of Alibaba, JD.com etc.   
            OMS order no      (Orders.ExternOrderKey), like Bao Jun  
            WMS order no      (Orders.OrderKey)  
      */  
      --IF @cReceiptKey = ''  
      --BEGIN  
      --   SELECT @cReceiptKey = ReceiptKey  
      --   FROM Receipt WITH (NOLOCK)  
      --   WHERE StorerKey = @cStorerKey  
      --      AND CarrierName = @cRefNo   
      --      AND ASNStatus NOT IN ('9', 'CANC')  
  
      --   IF @@ROWCOUNT > 1  
      --   BEGIN  
      --      SET @nErrNo = 158402  
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Found MultiASN  
      --      GOTO Quit  
      --   END  
      --END  
  
      -- Scan PlatformOrderNo  
      IF @cReceiptKey = ''  
      BEGIN  
         SELECT TOP 1 @cReceiptKey = R.ReceiptKey  
         FROM dbo.RECEIPT R WITH (NOLOCK)  
         JOIN dbo.ExternOrders EO WITH (NOLOCK) ON ( R.CarrierName = EO.PlatformOrderNo)           
         WHERE R.StorerKey = @cStorerKey  
         AND   R.CarrierName = @cRefNo  
         AND   ASNStatus NOT IN ('9', 'CANC')  
         ORDER BY EO.ShippedDate DESC   
      END  
        
      -- Lookup QR code  
      IF @cReceiptKey = ''  
      BEGIN  
         --SELECT @cReceiptKey = ReceiptKey  
         --FROM ExternOrdersDetail EOD WITH (NOLOCK)  
         --   JOIN Receipt R WITH (NOLOCK) ON (EOD.ExternOrderKey = R.CarrierName )  
         --WHERE EOD.StorerKey = @cStorerKey  
         --   AND EOD.QRCode = @cRefNo   
         --   AND R.StorerKey = @cStorerKey  
  
         SELECT @cPlatformOrderNo = EO.PlatformOrderNo  
         FROM ExternOrdersDetail EOD (NOLOCK)   
         JOIN dbo.ExternOrders EO WITH (NOLOCK) ON ( EO.ExternOrderKey = EOD.ExternOrderKey)  
         WHERE QRCode = @cRefNo   
           
         IF @@ROWCOUNT = 1  
            --SELECT TOP 1 @cReceiptKey = R.ReceiptKey  
            --FROM dbo.RECEIPT R WITH (NOLOCK)  
            --JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON ( R.ReceiptKey = RD.ReceiptKey)  
            --JOIN dbo.ExternOrders EO WITH (NOLOCK)  ON ( R.CarrierName = EO.PlatformOrderNo)  
            --JOIN dbo.ExternOrdersDetail EOD WITH (NOLOCK) ON ( EO.ExternOrderKey = EOD.ExternOrderKey AND RD.Sku = EOD.SKU)  
            --WHERE EOD.StorerKey = @cStorerKey  
            --AND   EOD.QRCode = @cRefNo   
            --AND   R.StorerKey = @cStorerKey  
            --AND   R.ASNStatus NOT IN ('1', '9', 'CANC')  
            --ORDER BY R.AddDate DESC  

            SELECT TOP 1 @cReceiptKey = R.ReceiptKey  
            FROM dbo.ExternOrdersDetail EOD WITH (NOLOCK)
            JOIN dbo.ExternOrders EO WITH (NOLOCK)  ON ( EO.ExternOrderKey = EOD.ExternOrderKey  )
            JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON ( RD.StorerKey = EOD.StorerKey AND RD.Sku = EOD.SKU )
            JOIN dbo.RECEIPT R WITH (NOLOCK)  ON  ( R.ReceiptKey = RD.ReceiptKey )
            WHERE R.CarrierName = EO.PlatformOrderNo
            AND   EOD.StorerKey = @cStorerKey  
            AND   EOD.QRCode = @cRefNo   
            AND   R.StorerKey = @cStorerKey  
            AND   R.ASNStatus NOT IN ('1', '9', 'CANC')  
            ORDER BY R.AddDate DESC

         ELSE  
         BEGIN  
            SELECT @cPlatformOrderNo = EO.PlatformOrderNo  
            FROM ExternOrdersDetail EOD (NOLOCK)   
            JOIN dbo.ExternOrders EO WITH (NOLOCK) ON ( EO.ExternOrderKey = EOD.ExternOrderKey)  
            WHERE QRCode = @cRefNo    
            GROUP BY EO.PlatformOrderNo  
  
            IF @@ROWCOUNT = 1           
               SELECT @cReceiptKey = R.ReceiptKey  
               FROM dbo.ExternOrdersDetail EOD WITH (NOLOCK)   
               LEFT JOIN dbo.ExternOrders EO WITH (NOLOCK) ON EOD.ExternOrderKey = EO.ExternOrderKey  
               LEFT JOIN dbo.RECEIPT R WITH (NOLOCK) ON EO.PlatformOrderNo = R.CarrierName  
               INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND EOD.SKU = RD.SKU  
               WHERE EOD.QRCode = @cRefNo   
            ELSE  
            BEGIN  
               SELECT TOP 1 @cExternOrderKey = EO.ExternOrderKey  
               FROM dbo.ExternOrders EO WITH (NOLOCK)    
               JOIN dbo.ExternOrdersDetail EOD WITH (NOLOCK) ON ( EO.ExternOrderKey = EOD.ExternOrderKey)  
               WHERE EOD.StorerKey = @cStorerKey  
               AND   EOD.QRCode = @cRefNo   
               ORDER BY EO.ShippedDate DESC  
  
               SELECT TOP 1 @cReceiptKey = R.ReceiptKey  
               FROM dbo.RECEIPT R WITH (NOLOCK)  
               JOIN dbo.ExternOrders EO WITH (NOLOCK)  ON ( R.CarrierName = EO.PlatformOrderNo)  
               JOIN dbo.ExternOrdersDetail EOD WITH (NOLOCK) ON ( EO.ExternOrderKey = EOD.ExternOrderKey)  
               WHERE EOD.StorerKey = @cStorerKey  
               AND   EOD.ExternOrderKey = @cExternOrderKey   
               AND   R.StorerKey = @cStorerKey  
               AND   R.ASNStatus NOT IN ('1', '9', 'CANC')  
               ORDER BY R.AddDate DESC  
            END     
         END  
      END  

      IF @cReceiptKey = ''  
      BEGIN  
         SELECT @cReceiptKey = ReceiptKey  
         FROM Receipt WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND CarrierName = @cRefNo   
            AND ASNStatus NOT IN ('9', 'CANC')  
  
         IF @@ROWCOUNT > 1  
         BEGIN  
            SET @nErrNo = 158402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Found MultiASN  
            GOTO Quit  
         END  
      END  

      -- Scan cs return orders  
      IF @cReceiptKey = ''  
      BEGIN  
         SELECT @cReceiptKey = ReceiptKey  
         FROM Receipt WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   CarrierAddress2 = @cRefNo   
         AND   ASNStatus NOT IN ('9', 'CANC')  
        
         IF @@ROWCOUNT > 1  
         BEGIN  
            SET @nErrNo = 158402  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Found MultiASN  
            GOTO Quit  
         END  
      END  
  
      -- Check ASN populated  
      IF @cReceiptKey = ''  
      BEGIN  
         SET @nErrNo = 158403  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN NotFound  
         GOTO Quit  
      END  
        
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
  
      -- (james02)  
      IF @cUserDefine02 IN ('2', '21')  
      BEGIN  
         SET @cErrMsg1 = rdt.rdtgetmessage( 158408, @cLangCode, 'DSP') --Program Order  
         SET @cErrMsg2 = rdt.rdtgetmessage( 158409, @cLangCode, 'DSP') --Must Receive  
                 
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
                                   
         SET @nErrNo = 0 -- Promopt only, still need goto next screen  
         SET @cErrMsg = ''  
      END  

      IF @cUserDefine10 = 'NFC' AND ISNULL( @cUserDefine08, '') = ''
      BEGIN  
         SET @nErrNo = 158411  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NFC ASN  
         SET @cReceiptKey = ''
         GOTO Quit  
      END  

      IF @cUserDefine10 = 'NFC' AND ISNULL( @cUserDefine08, '') = 'RFID'
      BEGIN  
         SET @nErrNo = 158412  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NFC RFID ASN  
         SET @cReceiptKey = ''
         GOTO Quit  
      END  
            
      -- Check RFID ASN  
      IF @cUserDefine08 = 'RFID'  
      BEGIN  
         SET @nErrNo = 158404  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RFID ASN  
         SET @cReceiptKey = ''  
         GOTO Quit  
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
               SET @nErrNo = 158407  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER 14 DAYS  
               SET @cReceiptKey = ''  
               GOTO Quit  
            END  
         END  
      END  
                    
      -- Check black list (platform order no)  
      IF @cCarrierName <> ''  
      BEGIN  
         SELECT TOP 1   
            @cBlackList = 'Y'  
         FROM DocInfo WITH (NOLOCK)  
         WHERE TableName = 'CHECKLIST'  
            AND StorerKey = @cStorerKey  
            AND Key2 = LEFT( @cCarrierName, 20)  
  
         IF @cBlackList <> 'Y'  
            SELECT TOP 1   
               @cGroupList = 'Y'  
            FROM DocInfo WITH (NOLOCK)  
            WHERE TableName = 'GOUPLIST'  
               AND StorerKey = @cStorerKey  
               AND Key2 = LEFT( @cCarrierName, 20)  
      END  
        
      -- Check black list (phone no)  
      IF @cSellerPhone1 <> ''  
      BEGIN  
         SELECT TOP 1   
            @cBlackList = 'Y'  
         FROM DocInfo WITH (NOLOCK)  
         WHERE TableName = 'CHECKLIST'  
            AND StorerKey = @cStorerKey  
            AND Key3 = @cSellerPhone1  
  
         IF @cBlackList <> 'Y'  
            SELECT TOP 1   
               @cGroupList = 'Y'  
            FROM DocInfo WITH (NOLOCK)  
            WHERE TableName = 'GOUPLIST'  
               AND StorerKey = @cStorerKey  
               AND Key3 = @cSellerPhone1  
      END  
        
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
  
      -- (james03)  
      IF @@ROWCOUNT = 1  
      BEGIN  
         SET @nErrNo = 158410  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Black List  
         SET @cReceiptKey = ''  
         GOTO Quit  
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
         IF @cBlackList = 'Y'  
            SET @cMsg = rdt.rdtgetmessage( 158405, @cLangCode, 'DSP') --BLACK LIST  
         ELSE  
            SET @cMsg = rdt.rdtgetmessage( 158406, @cLangCode, 'DSP') --GROUP LIST  
              
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, '', @cMsg  
           
         BEGIN TRAN  -- Begin our own transaction  
         SAVE TRAN rdt_638RefNoLKUP04 -- For rollback or commit only our own transaction  
        
         -- Mark ASN as black list  
         UPDATE Receipt SET  
            ASNReason = 'CHECKLIST',   
            EditDate = GETDATE(),   
            EditWho = SUSER_SNAME()  
         WHERE ReceiptKey = @cReceiptKey  
         SET @nErrNo = @@ERROR   
         IF @nErrNo <> 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RFID ASN  
            GOTO RollBackTran  
         END  
  
         COMMIT TRAN rdt_638RefNoLKUP04  
  
         SET @nErrNo = -1 -- For remain in RefNo screen  
         SET @cReceiptKey = ''  
      END  
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_638RefNoLKUP04  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO